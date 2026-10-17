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

Term::Fabulous::Widget::CodeBlock - Unwrapped code on its own background, clipped and scrolled sideways

=head1 SYNOPSIS

	use Term::Fabulous::Widget::CodeBlock;

	my $code = Term::Fabulous::Widget::CodeBlock->new(
		code     => "my \$x = 1;\nsay \$x;",
		language => 'perl',
	);

	# Style the keyword "my" (characters 0 to 2):
	$code->spans( [ [ 0, 2, 'bold #c678dd' ] ] );

	# Syntax highlighting: a function that turns the code into spans.
	$code->highlighter( sub ( $text, $language ) { return [ my_highlighter( $text, $language ) ] } );

	# Scroll the code eight columns to the left.
	$code->offset(8);

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.03/screenshots/widget-code-block.svg" alt="Three code blocks on a darker background: a short Perl snippet with a highlighted keyword and a colored variable, a block whose long lines are cut at the right edge with a mark, and the same block scrolled sideways with marks on both sides"></p>

=end html

The program is F<examples/widgets/code-block.pl>.

=head1 DESCRIPTION

A code block shows lines of code, such as a verbatim paragraph of a
document. The lines never wrap, and the block draws them on a
background of their own that sets them apart from the surrounding
prose. L<Term::Fabulous::Widget::DocumentView> shows every verbatim
block of a document with a code block; a program can also use the
widget on its own.

The block is a L<Term::Fabulous::Widget::Display>, a widget that paints
its cells itself (see
L<Term::Fabulous::Manual::CustomWidgets/A widget that draws itself>),
for two reasons:

=over

=item *

Code must not wrap, and a line that is wider than the block must end at
the block's edge instead of running into the border of the surrounding
view. A Display paints only its own cells, so nothing it draws can
spill outside. A clipped line shows a mark in the margin: C<›> on the
right where the line continues beyond the right edge, and C<‹> on the
left of every non-empty line while the code is scrolled sideways. A
wide character that an edge would cut in half is left out.

=item *

Every character can have a style of its own, from the highlighter and
from the program's spans, and Clay does not have to lay out the text.

=back

The block is as many rows tall as its code has lines, and as wide as
its parent allows (C<natural_size> requests C<sizing_grow> for the
width). One column on each side is a margin, where the clip marks
appear. The colors are the C<code_block> and C<clipped> styles of
L<Term::Fabulous::Document::Look> in the theme the block draws with.

The block shows its code shifted to the left by L</offset> columns. It
does not react to keys or the mouse itself: the widget that contains it
decides when to scroll, so that several blocks can move together.
L<Term::Fabulous::Widget::DocumentView>, for example, scrolls all its
code blocks sideways together with the C<Left> and C<Right> keys and
the horizontal mouse wheel.

=head1 CONSTRUCTOR

=head2 new

	my $code = Term::Fabulous::Widget::CodeBlock->new( code => $text, %parameters );

Creates a code block. It takes all parameters of
L<Term::Fabulous::Widget::Display> (C<id>, C<layout> and so on), plus
the following. Unknown parameters die, and so do invalid values, with a
message that names the parameter.

=over

=item C<code>

The code, a string, with lines separated by C<"\n">. Default: the empty
string. Expand tabs before passing the code: the block shows each tab
as a single space.

=item C<language>

C<undef> (the default) or a non-empty string that names the language
of the code, such as C<perl>. The block does not use it except to pass
it to the C<highlighter>.

=item C<highlighter>

C<undef> (the default) or a code reference that computes the syntax
highlighting. The block calls it as
C<< $highlighter->( $code, $language ) >> the first time it paints
after the code, the language or the highlighter changed, and keeps the
result until one of them changes again.

The highlighter returns an array reference of spans
C<[ $start, $end, $style ]>. C<$start> and C<$end> are character
offsets into the code (C<$end> is the offset after the last character
of the span), and C<$style> is a style string or style hash of
L<Term::Fabulous::Text::Style>, such as C<'bold #c678dd'>. This is the
same format as the spans of a L<Term::Fabulous::Widget::RichText>. A
result in any other format, or a span that does not lie within the
code, dies when the block is painted. See L</SYNTAX HIGHLIGHTING>.

=item C<spans>

An array reference of spans in the same format, for styles that come
from the program rather than from the language, such as search
matches. They are applied on top of the highlighter's spans: where both
style a character, the program's span overrides the colors and style
bits it sets, so a search match stays visible in highlighted code.
Default: no spans.

=item C<offset>

A non-negative integer, default 0: the number of columns by which the
code is scrolled to the left. The block keeps the value as given, but
paints with at most the offset that brings the end of its widest line
into view (see L</shown_offset>).

=back

=head1 METHODS

The block has all methods of L<Term::Fabulous::Widget::Display>, plus
the following. The accessors of the parameters return the current value
when called without an argument. With an argument, they check the new
value as L</new> does (an invalid value dies), set it, and return it;
the change shows in the next frame.

=head2 code

	$code->code("print 42;\n");

Gets or sets the code. Setting it also removes the program's spans
(L</spans>), because their offsets refer to the old code, and makes the
highlighter run again at the next paint.

=head2 language

	$code->language('perl');

Gets or sets the language. Setting it makes the highlighter run again
at the next paint.

=head2 highlighter

	$code->highlighter( \&highlight );

Gets or sets the highlighter. Setting it discards the stored result of
the previous highlighter; the new one runs at the next paint.

=head2 spans

	my $spans = $code->spans;    # [ [ 0, 2, { set => ..., clear => ..., color => ..., background => ... } ], ... ]

Gets or sets the program's spans. Both the getter and the setter return
a copy of the spans, in which each style is normalized to a style hash
of L<Term::Fabulous::Text::Style>. Setting the spans does not run the
highlighter again.

=head2 offset

	$code->offset(8);

Gets or sets the offset, in columns. The block repaints only when the
change affects what it shows, that is, when L</shown_offset> changes.

=head2 shown_offset

	my $columns = $code->shown_offset;

Returns the offset the block paints with: L</offset>, but no more than
L</max_offset>.

=head2 max_offset

	my $columns = $code->max_offset;

Returns how many columns the code can be scrolled: the width of its
widest line minus the number of columns the block showed of it in the
last frame (its width less the two margin columns), or 0 if every line
fits. Before the first frame, when the block has no width yet, this is
the width of the widest line.

=head2 line_count

	my $lines = $code->line_count;

Returns the number of lines of the code, which is at least 1: empty
code counts as one empty line, and a trailing C<"\n"> adds an empty
last line.

=head2 widest_line_columns

	my $columns = $code->widest_line_columns;

Returns the width of the widest line, in terminal columns; a wide
character, such as a CJK character, counts as two.

=head1 SYNTAX HIGHLIGHTING

The block knows no programming language. A highlighter is any function
that maps the code and a language name to spans, so syntax highlighting
is supplied from outside. Pass the highlighter to the C<highlighter>
parameter of L<Term::Fabulous::Widget::DocumentView/new>, which hands
it to every code block of the view, or set it on a single block. A
highlighter that does not know the language returns an empty array
reference, C<[]>.

A highlighter for Perl could use L<PPI> to find the tokens and give
each kind of token a style. The following one only marks a few Perl
keywords:

	my $highlighter = sub ( $code, $language ) {
		return [] unless defined $language && $language eq 'perl';
		my @spans;
		while ( $code =~ /\b(?:my|our|sub|return|if|elsif|else|unless|foreach|while)\b/g ) {
			push @spans, [ $-[0], $+[0], 'bold #c678dd' ];
		}
		return \@spans;
	};

	$code->highlighter($highlighter);

L<Term::Fabulous::Cookbook::Documents> has a recipe for adding syntax
highlighting to a document view.

=head1 KDL PROPERTIES

The block accepts the properties of
L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus C<code>,
C<language> and C<offset>:

=for highlighter language=kdl

	use Term::Fabulous::Widget::CodeBlock as CodeBlock

	CodeBlock "example" {
		code "my $x = 1;\nsay $x;"
		language "perl"
	}

=head1 SEE ALSO

L<Term::Fabulous::Cookbook::Documents>,
L<Term::Fabulous::Document::Block::Verbatim>,
L<Term::Fabulous::Widget::DocumentView>,
L<Term::Fabulous::Widget::Display>, L<Term::Fabulous::Text::Style>.

=cut
