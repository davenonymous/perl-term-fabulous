package Term::Fabulous::Widget::CodeBlock;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Display;

our $VERSION = '0.03';

class Term::Fabulous::Widget::CodeBlock
	:isa(Term::Fabulous::Widget::Display)
	:strict(params)
{
	use Clay::XS qw(sizing_grow);
	use List::Util qw(max min uniqnum);
	use Scalar::Util qw(refaddr);
	use Term::Fabulous::Check qw(describe non_negative_integer string);
	use Term::Fabulous::Document::Look;
	use Term::Fabulous::Termbox qw(TB_DEFAULT);
	use Term::Fabulous::Text::Style qw(apply_style);
	use Term::Fabulous::Unicode qw(cluster_columns grapheme_clusters);

	# One column on either side of the code, in the code's background,
	# where the marks of clipped lines go.
	use constant MARGIN        => 1;
	use constant CLIPPED_LEFT  => "\x{2039}";
	use constant CLIPPED_RIGHT => "\x{203A}";

	field $code        :param = '';
	field $language    :param = undef;
	field $highlighter :param = undef;
	field $spans       :param = [];
	field $offset      :param = 0;

	# Per line, its clusters as [ cluster, columns, offset in the code ],
	# and its width in columns. The highlighter's spans until the code,
	# the language or the highlighter change; the runs to paint with (see
	# _runs) until anything they are made of changes, the look among it.
	field @lines;
	field $highlighted;
	field $runs;
	field $runs_look;

	ADJUST {
		$code        = string( $self, code => $code );
		$language    = _checked_language( $self, $language );
		$highlighter = _checked_highlighter( $self, $highlighter );
		$spans       = $self->_checked_spans( spans => $spans );
		$offset      = non_negative_integer( $self, offset => $offset );
		$self->_split_lines;
	}

	sub _checked_language ( $owner, $value ) {
		return undef unless defined $value;
		$value = string( $owner, language => $value );
		die ref($owner) . ": language must not be empty" unless length $value;
		return $value;
	}

	sub _checked_highlighter ( $owner, $value ) {
		die ref($owner) . ": highlighter must be a code reference or undef, got " . describe($value) if defined $value && ref $value ne 'CODE';
		return $value;
	}

	# Spans as [ start, end, style ] within the code, each style
	# normalized to a style hash of Term::Fabulous::Text::Style.
	method _checked_spans ( $what, $given ) {
		die ref($self) . ": $what must be an array reference of [start, end, style], got " . describe($given) unless ref $given eq 'ARRAY';
		my $length = length $code;
		return [
			map {
				die ref($self) . ": $what must be [start, end, style], got " . describe($_) unless ref $_ eq 'ARRAY' && @$_ == 3;
				my ( $start, $end, $style ) = @$_;
				$start = non_negative_integer( $self, "$what start", $start );
				$end   = non_negative_integer( $self, "$what end",   $end );
				die ref($self) . ": $what span [$start, $end] does not lie within the code ($length characters)" if $start > $end || $end > $length;
				[ $start, $end, Term::Fabulous::Text::Style::style($style) ];
			} @$given
		];
	}

	method _split_lines () {
		my $position = 0;
		@lines = map {
			my $line = $_;
			my @clusters;
			my $columns = 0;
			foreach my $cluster ( grapheme_clusters($line) ) {
				my $width = cluster_columns($cluster);
				push @clusters, [ $cluster, $width, $position ];
				$position += length $cluster;
				$columns  += $width;
			}
			$position++;    # the line break
			+{ clusters => \@clusters, columns => $columns };
		} split /\n/, $code, -1;
		@lines = ( { clusters => [], columns => 0 } ) unless @lines;
		$self->_forget_highlighting;
		return;
	}

	method _forget_highlighting () {
		$highlighted = undef;
		$runs        = undef;
		return;
	}

	# ---------------------------------------------------------------------
	# Accessors
	# ---------------------------------------------------------------------

	method code (@new) {
		return $code unless @new;
		$code  = string( $self, code => $new[0] );
		$spans = [];
		$self->_split_lines;
		$self->mark_changed;
		return $code;
	}

	method language (@new) {
		return $language unless @new;
		$language = _checked_language( $self, $new[0] );
		$self->_forget_highlighting;
		$self->mark_changed;
		return $language;
	}

	method highlighter (@new) {
		return $highlighter unless @new;
		$highlighter = _checked_highlighter( $self, $new[0] );
		$self->_forget_highlighting;
		$self->mark_changed;
		return $highlighter;
	}

	method spans (@new) {
		return [ map { [ $_->[0], $_->[1], { %{ $_->[2] } } ] } @$spans ] unless @new;
		$spans = $self->_checked_spans( spans => $new[0] );
		$runs  = undef;
		$self->mark_changed;
		return $self->spans;
	}

	# A new offset paints again only when it changes what shows.
	method offset (@new) {
		return $offset unless @new;
		my $shown_before = $self->shown_offset;
		$offset = non_negative_integer( $self, offset => $new[0] );
		$self->mark_changed if $self->shown_offset != $shown_before;
		return $offset;
	}

	method line_count () {
		return scalar @lines;
	}

	method widest_line_columns () {
		return max map { $_->{columns} } @lines;
	}

	# ---------------------------------------------------------------------
	# Scrolling sideways
	# ---------------------------------------------------------------------

	method _visible_columns () {
		return max( 0, $self->columns - 2 * MARGIN );
	}

	method max_offset () {
		return max( 0, $self->widest_line_columns - $self->_visible_columns );
	}

	method shown_offset () {
		return min( $offset, $self->max_offset );
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method natural_size () {
		return ( sizing_grow(), scalar @lines );
	}

	method _highlighted_spans () {
		return $highlighted //= $highlighter ? $self->_checked_spans( 'highlighter result' => $highlighter->( $code, $language ) ) : [];
	}

	# The runs of the code in the current look, made again only when the
	# look (a theme switch) or the spans changed.
	method _runs_in ($look) {
		return $runs if defined $runs && refaddr($runs_look) == refaddr($look);
		my $base = $look->style('code_block');
		$runs = [ map { +{ %$_, fg => $self->_fg_attr( $_->{look} ), bg => $self->color_attr( $_->{look}{background} ) } }
				_runs( length $code, { attrs => 0, color => $base->{color}, background => $base->{background} }, @{ $self->_highlighted_spans }, @$spans ) ];
		$runs_look = $look;
		return $runs;
	}

	method paint () {
		my $look       = Term::Fabulous::Document::Look->of($self);
		my $background = $self->color_attr( $look->style('code_block')->{background} );
		$self->fill_attrs( 0, $_, $self->columns, ' ', undef, $background ) foreach 0 .. $self->rows - 1;

		my $visible = $self->_visible_columns;
		return unless $visible;
		my $shift  = $self->shown_offset;
		my $runs   = $self->_runs_in($look);
		my $marker = $look->style('clipped');
		my ( $marker_fg, $marker_bg ) = ( $self->color_attr( $marker->{color} ), $self->color_attr( $marker->{background} ) );

		my $run_index = 0;
		foreach my $y ( 0 .. min( $self->rows, scalar @lines ) - 1 ) {
			my $line   = $lines[$y];
			my $column = 0;
			foreach my $cluster_info ( @{ $line->{clusters} } ) {
				my ( $cluster, $width, $position ) = @$cluster_info;
				my $from = $column;
				$column += $width;
				next if $from < $shift;
				last if $column > $shift + $visible;
				$run_index++ while $runs->[$run_index]{to} <= $position;
				$self->put_attrs( MARGIN + $from - $shift, $y, $cluster, @{ $runs->[$run_index] }{qw(fg bg)} );
			}
			$self->put_attrs( 0,                  $y, CLIPPED_LEFT,  $marker_fg, $marker_bg ) if $shift > 0 && $line->{columns} > 0;
			$self->put_attrs( $self->columns - 1, $y, CLIPPED_RIGHT, $marker_fg, $marker_bg ) if $line->{columns} > $shift + $visible;
		}
		return;
	}

	method _fg_attr ($look) {
		return ( $self->color_attr( $look->{color} ) // TB_DEFAULT ) | $look->{attrs};
	}

	# The code cut at every span boundary, each piece with the look its
	# spans give it, applied in their order over the base look:
	# { to, look }, and a last run past the end. One sweep over the
	# boundaries keeps the spans that cover the piece at hand.
	sub _runs ( $length, $base, @spans ) {
		my ( %starting_at, %ending_at );
		foreach my $index ( grep { $spans[$_][0] < $spans[$_][1] } 0 .. $#spans ) {
			push @{ $starting_at{ $spans[$index][0] } }, $index;
			push @{ $ending_at{ $spans[$index][1] } },   $index;
		}
		my @boundaries = sort { $a <=> $b } uniqnum 0, $length, keys %starting_at, keys %ending_at;

		my ( %covering, @runs );
		foreach my $index ( 1 .. $#boundaries ) {
			my ( $from, $to ) = @boundaries[ $index - 1, $index ];
			delete @covering{ @{ $ending_at{$from} // [] } };
			$covering{$_} = 1 foreach @{ $starting_at{$from} // [] };
			my $look = $base;
			$look = apply_style( $look, $spans[$_][2] ) foreach sort { $a <=> $b } keys %covering;
			push @runs, { to => $to, look => $look };
		}
		return ( @runs, { to => $length + 1, look => $base } );
	}

	# ---------------------------------------------------------------------
	# KDL
	# ---------------------------------------------------------------------

	method layout_properties :common () {
		return ( $class->SUPER::layout_properties, code => 'scalar', language => 'scalar', offset => 'scalar' );
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::CodeBlock - Code on a background of its own, clipped and scrolled sideways

=head1 SYNOPSIS

	use Term::Fabulous::Widget::CodeBlock;

	my $code = Term::Fabulous::Widget::CodeBlock->new(
		code     => "my \$x = 1;\nsay \$x;",
		language => 'perl',
	);

	# Color the keyword "my":
	$code->spans( [ [ 0, 2, 'bold #c678dd' ] ] );

	# Syntax highlighting: a function from the code to spans.
	$code->highlighter( sub ( $text, $language ) { return [ my_highlighter( $text, $language ) ] } );

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.03/screenshots/widget-code-block.svg" alt="Three code blocks on a darker background: a short Perl snippet with a highlighted keyword and a colored variable, a block whose long lines are cut at the right edge with a mark, and the same block scrolled sideways with marks on both sides"></p>

=end html

The program is F<examples/widgets/code-block.pl>.

=head1 DESCRIPTION

A code block shows a verbatim paragraph: lines of code, never wrapped,
on a background that sets them apart from the prose around them. It is
a L<Term::Fabulous::Widget::Display>, a widget that paints its cells
itself (see L<Term::Fabulous::Manual::CustomWidgets/A widget that draws itself>),
for two reasons:

=over

=item *

Code must not wrap, and a line that is wider than the block must end
at the block's edge, not run on into the border of the document
around it. A Display owns exactly its cells, so nothing it paints can
leave them. Clipped lines show a mark in the margin: C<›> where a line
goes on to the right, C<‹> where it is scrolled to the left.

=item *

Every character can be painted in a look of its own, from the
highlighter and from the program's spans, without asking Clay to lay
the text out.

=back

The block is as tall as its code has lines and as wide as its parent
allows (C<natural_size> asks for C<sizing_grow> in width). Its colors
are the C<code_block> and C<clipped> styles of
L<Term::Fabulous::Document::Look>, taken from the theme; one column on
either side is margin.

The block shows its code shifted to the left by L</offset> columns. It
does not scroll by itself: the widget it is shown in decides, so that
several blocks can move together.
L<Term::Fabulous::Widget::DocumentView> scrolls all its code blocks
sideways with the keys and the horizontal wheel.

=head1 CONSTRUCTOR

=head2 new

	my $code = Term::Fabulous::Widget::CodeBlock->new( code => $text, %parameters );

All parameters of L<Term::Fabulous::Widget::Display> (C<id>,
C<layout>, ...) plus the following. Unknown parameters die, and so do
invalid values, with a message that names the parameter.

=over

=item C<code>

The code, a string; lines are separated by C<"\n">. Default: empty.
Tabs should be expanded beforehand (a tab is shown as one space).

=item C<language>

C<undef> (the default) or a non-empty string: the language the code is
written in. The block itself does nothing with it but pass it to the
C<highlighter>.

=item C<highlighter>

C<undef> (the default) or a code reference, called as
C<< $highlighter->( $code, $language ) >> when the block is painted
for the first time after the code, the language or the highlighter
changed. It returns an array reference of spans
C<[ $start, $end, $style ]>: character offsets into the code and a
style string or hash of L<Term::Fabulous::Text::Style>
(C<'bold #c678dd'>), the format of the spans of a
L<Term::Fabulous::Widget::RichText>. The result is kept until one of
the three changes. A result that is not such an array dies when the
block is painted. See L</SYNTAX HIGHLIGHTING>.

=item C<spans>

An array reference of spans in the same format, applied after the
highlighter's, so they win where both style a character: a search
match stays visible in highlighted code. Default: none.

=item C<offset>

A non-negative integer, default 0: how many columns the code is
scrolled to the left. It is kept as given; the block shows at most the
offset that brings its widest line's end into view (L</shown_offset>).

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Display>, plus the accessors
of the parameters, which return the value without an argument and set
it with one, check it like the constructor and show the change in the
next frame:

=head2 code

	$code->code("print 42;\n");

Setting the code drops the spans, which pointed into the old code.

=head2 language

	$code->language('perl');

=head2 highlighter

	$code->highlighter( \&highlight );

=head2 spans

	my $spans = $code->spans;    # [ [ 0, 2, { set => ..., clear => ..., color => ..., background => ... } ], ... ]

Reading returns a copy, with each style normalized to a style hash.

=head2 offset

	$code->offset(8);

=head2 shown_offset

	my $columns = $code->shown_offset;

The offset the block is painted with: L</offset>, but no more than
L</max_offset>.

=head2 max_offset

	my $columns = $code->max_offset;

How far the code can scroll: the width of its widest line less the
columns the last frame showed of it, or 0. Before the first frame, when
the block has no columns yet, it is the width of the widest line.

=head2 line_count

	my $lines = $code->line_count;

The number of lines of the code (at least 1).

=head2 widest_line_columns

	my $columns = $code->widest_line_columns;

The width of the widest line, in terminal columns.

=head1 SYNTAX HIGHLIGHTING

The block does not know any programming language. A highlighter is any
function from code and a language name to spans, so syntax
highlighting plugs in from outside: through the C<highlighter>
parameter of L<Term::Fabulous::Widget::DocumentView/new>, which hands
it to every code block of the view, or to a single block. A highlighter
for Perl could use L<PPI> to find the tokens and give each kind of
token a style; one that does not know the language returns C<[]>.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<code>, C<language> and C<offset>:

=for highlighter language=kdl

	use Term::Fabulous::Widget::CodeBlock as CodeBlock

	CodeBlock "example" {
		code "my $x = 1;\nsay $x;"
		language "perl"
	}

=head1 SEE ALSO

L<Term::Fabulous::Document::Block::Verbatim>, L<Term::Fabulous::Widget::DocumentView>,
L<Term::Fabulous::Widget::Display>, L<Term::Fabulous::Text::Style>.

=cut
