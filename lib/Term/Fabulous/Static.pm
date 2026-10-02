package Term::Fabulous::Static;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI;
use Term::Fabulous::Render;
use Term::Fabulous::Render::Target::Grid;

class Term::Fabulous::Static
	:isa(Clay::UI)
	:does(Term::Fabulous::Render)
	:does(Term::Fabulous::Render::Target::Grid)
	:strict(params)
{
	use Encode qw(encode);
	use Scalar::Util qw(openhandle);
	use Term::Fabulous::Termbox qw(TB_DEFAULT TB_HI_BLACK TB_REVERSE TB_BOLD TB_UNDERLINE);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant DEFAULT_MAX_HEIGHT => 4096;
	use constant RESET              => "\e[0m";

	# Term::Fabulous::Render::Attr packs the color into the low 24 bits and
	# the flags above them.
	use constant COLOR_MASK => 0xFFFFFF;

	field $trim_trailing_whitespace :param :reader = 1;

	# Clay::UI needs a height, and content is expected to end far before it.
	sub BUILDARGS ( $class, %params ) {
		die "Term::Fabulous::Static: measure_text cannot be replaced; text is always measured in terminal columns" if exists $params{measure_text};
		$params{height} //= DEFAULT_MAX_HEIGHT;
		return %params;
	}

	sub _checked_options ( $method, $options, @known ) {
		my %is_known = map { $_ => 1 } @known;
		my @unknown  = sort grep { !$is_known{$_} } keys %$options;
		die "Term::Fabulous::Static: $method does not accept " . join( ', ', @unknown ) . " (known options: " . join( ', ', @known ) . ")" if @unknown;
		return;
	}

	method pointer_state () {
		return undef;
	}

	method render_lines ( %options ) {
		_checked_options( render_lines => \%options, 'colors' );
		my $colors = $options{colors} // 1;
		$self->draw;
		return map { $self->_format_row( $_, $colors ) } 0 .. $self->grid_height - 1;
	}

	method render_string ( %options ) {
		_checked_options( render_string => \%options, 'colors' );
		return join '', map { "$_\n" } $self->render_lines(%options);
	}

	method print ( %options ) {
		_checked_options( print => \%options, qw(fh colors) );
		my $fh = $options{fh} // \*STDOUT;
		die "Term::Fabulous::Static: fh must be an open file handle" unless openhandle($fh);
		my $colors = $options{colors} // ( -t $fh ? 1 : 0 );
		print {$fh} encode( 'UTF-8', $self->render_string( colors => $colors ) );
		return;
	}

	method _format_row ( $y, $colors ) {
		my $cells = $self->grid_row($y);
		my $last  = $self->width - 1;
		if ($trim_trailing_whitespace) {
			$last = $#$cells if $#$cells < $last;
			$last-- while $last >= 0 && _is_blank( $cells->[$last] );
		}

		my ( $line, $style ) = ( '', '' );
		my $x = 0;
		while ( $x <= $last ) {
			my $cell = $cells->[$x];
			my ( $glyph, $fg, $bg ) = defined $cell ? @$cell : ( ' ', TB_DEFAULT, TB_DEFAULT );
			if ($colors) {
				my $wanted = _sgr( $fg, $bg );
				if ( $wanted ne $style ) {
					$line .= RESET if length $style;
					$line .= $wanted;
					$style = $wanted;
				}
			}
			$line .= $glyph;
			$x += defined $cell ? string_columns($glyph) : 1;
		}
		$line .= RESET if length $style;
		return $line;
	}

	# A cell that would print as a plain space: never painted, or a space in
	# the terminal's default background.
	sub _is_blank ($cell) {
		return 1 unless defined $cell;
		my ( $glyph, $fg, $bg ) = @$cell;
		return $glyph eq ' ' && $bg == TB_DEFAULT && !( $fg & TB_REVERSE );
	}

	sub _sgr ( $fg, $bg ) {
		my @codes;
		push @codes, 1 if $fg & TB_BOLD;
		push @codes, 4 if $fg & TB_UNDERLINE;
		push @codes, 7 if ( $fg | $bg ) & TB_REVERSE;
		push @codes, _color_codes( 38, $fg );
		push @codes, _color_codes( 48, $bg );
		return @codes ? "\e[" . join( ';', @codes ) . 'm' : '';
	}

	# The terminal default needs no code; opaque black carries its own flag
	# because termbox2 reads 0x000000 as the default color.
	sub _color_codes ( $base, $attr ) {
		return () if $attr == TB_DEFAULT;
		my $rgb = $attr & TB_HI_BLACK ? 0 : $attr & COLOR_MASK;
		return () if !( $attr & TB_HI_BLACK ) && $rgb == 0;
		return ( $base, 2, ( $rgb >> 16 ) & 0xFF, ( $rgb >> 8 ) & 0xFF, $rgb & 0xFF );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Static - Render a widget tree to text once, without a terminal

=head1 SYNOPSIS

	use Term::Fabulous::Static;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

	my $root = Term::Fabulous::Widget::Box->new(
		layout => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_fit() },
			padding          => { left => 1, right => 1 },
		},
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Round,
		border_color => [ 180, 200, 220, 255 ],
	);
	$root->add_child( Term::Fabulous::Widget::Text->new( text => 'Hello', text_color => [ 255, 255, 255, 255 ] ) );

	my $page = Term::Fabulous::Static->new( root => $root, width => 40 );
	$page->print;                                      # colored if STDOUT is a terminal
	my @lines = $page->render_lines( colors => 0 );    # plain text, one string per row

=head1 DESCRIPTION

Term::Fabulous::Static lays out and paints a widget tree exactly like
L<Term::Fabulous> does, but into memory instead of the terminal. The
result is text: one string per row, optionally with 24-bit ANSI color
sequences. No terminal is opened and no event loop runs, so you can
print the result, write it to a file, pipe it to another program or
compare it in a test.

Use it for:

=over

=item *

reports and other one-off output of command line tools, with the same
boxes, borders and colors as an interactive program;

=item *

tests of widgets and layouts (see L<Term::Fabulous::Manual/TESTING>);

=item *

previews of a layout in a non-interactive environment.

=back

Every widget works: text, borders, colors, canvases and input widgets
are painted as on screen. Cells that nothing painted are spaces in the
terminal's default colors. Since there is no pointer, nothing is ever
hovered or pressed.

Term::Fabulous::Static is a L<Clay::UI> subclass composing
L<Term::Fabulous::Render> and L<Term::Fabulous::Render::Target::Grid>,
so their methods (C<draw>, C<cell>, C<grid_row>, C<interaction>, ...)
are available too.

=head1 CONSTRUCTOR

=head2 new

	my $page = Term::Fabulous::Static->new( root => $root, width => 80 );

Unknown parameters die, and so does C<measure_text>: text is always
measured in terminal columns.

=over

=item C<root>

Required. The root widget of the tree to render. It must not have a
parent (see L<Term::Fabulous::Manual/WIDGETS AND THE WIDGET TREE>).
A widget tree can belong to only one live Term::Fabulous::Static or
L<Term::Fabulous> object at a time: a second C<new> with the same root
dies with C<Clay::UI: widget already bound to a Clay::UI controller>.
Once the first object is gone, the root can be used again. To render
the same tree repeatedly, keep one object and call L</render_lines>
again.

=item C<width>

Required. The number of columns the layout may use, a positive number.
A root widget sized with C<grow> fills it.

=item C<height>

The number of rows the layout may use. Default: 4096. Rows below the
last painted one are not part of the output, so a root widget sized
with C<fit> produces exactly as many rows as its content needs. A root
with a C<grow> height fills all C<height> rows: give such a root an
explicit C<height>, or you get 4096 lines.

=item C<trim_trailing_whitespace>

A boolean. Default: 1. When true, cells at the end of each row that
would print as plain spaces are left out: cells nothing painted, and
spaces in the terminal's default background. Spaces on a colored
background are kept. When false, every row is padded with spaces to
C<width> columns.

=item C<output_mode>

Accepted for symmetry with L<Term::Fabulous>; it must be
C<TB_OUTPUT_TRUECOLOR>, the default (see
L<Term::Fabulous::Render/CONSTRUCTOR PARAMETERS>). Leave it out.

=item C<memory_size>

Passed to L<Clay::UI>: the bytes Clay reserves for a layout. Rarely
needed; it does not raise the limit on the number of widgets (see
L<Term::Fabulous/LIMITATIONS>).

=item C<error_handler>

Passed to L<Clay::UI>; see there.

=back

=head1 METHODS

=head2 render_lines

	my @lines = $page->render_lines;
	my @plain = $page->render_lines( colors => 0 );

Lays the tree out, paints it and returns one character string per row,
from the first row to the last row anything was painted in. The strings
contain no newlines. Each call renders the tree again, so changes to the
widgets show in the next call. C<colors> is the only option; any other
option name dies (so does C<colour>).

C<colors> is a boolean, default 1. When true, every run of cells with
the same colors and attributes is preceded by one SGR escape sequence
that combines C<38;2;r;g;b> for the foreground, C<48;2;r;g;b> for the
background, C<7> for reverse video (used by some border styles and the
text cursor), and C<1> (bold) and C<4> (underline) when a cell carries
those termbox2 flags (only canvas cells written with C<put_attrs> can).
Terminal default colors produce no code. Where the style changes in the
middle of a row, C<ESC [ 0 m> resets the previous style first, so a run
in default colors is preceded by just C<ESC [ 0 m>. Every row that
contains a sequence ends with C<ESC [ 0 m>. When false, the strings
contain only the characters. Other options are ignored.

The strings are Perl character strings; encode them (for example with
C<Encode::encode('UTF-8', ...)>) before writing them to a handle that
has no encoding layer, or use L</print>.

=head2 render_string

	my $text = $page->render_string( colors => 0 );

The rows of L</render_lines> joined into one character string, each row
followed by C<"\n">. Takes the same C<colors> option.

=head2 print

	$page->print;
	$page->print( fh => \*STDERR, colors => 0 );
	$page->print( fh => $file_handle );

Writes L</render_string>, encoded as UTF-8, to a file handle. Any
option other than the two below dies.

=over

=item C<fh>

The handle to write to. Default: C<STDOUT>. Dies with
C<Term::Fabulous::Static: fh must be an open file handle> if it is not
one. Do not put an C<:encoding> or C<:utf8> layer on the handle, since
the text is encoded already.

=item C<colors>

A boolean. Default: true if C<fh> is connected to a terminal (C<-t>),
false otherwise, so piping the output into a file or another program
gives plain text.

=back

=head1 EXAMPLES

Write a report to a file, without colors:

	open my $out, '>', 'report.txt' or die "report.txt: $!";
	Term::Fabulous::Static->new( root => $root, width => 72 )->print( fh => $out, colors => 0 );
	close $out;

Check what a widget shows, in a test:

	use Test2::V0;

	my $page = Term::Fabulous::Static->new( root => $root, width => 20 );
	is [ $page->render_lines( colors => 0 ) ], [ 'Hello' ], 'the greeting is shown';

The script F<examples/static-report.pl> in the distribution renders
several bordered panels with non-ASCII text.

=begin html

<p><img src="/screenshots/example-static-report.svg" alt="Three panels with double, heavy and round borders, printed to the terminal"></p>

=end html

=head1 SEE ALSO

L<Term::Fabulous::Manual/RENDERING WITHOUT A TERMINAL>,
L<Term::Fabulous::Manual/TESTING>, L<Term::Fabulous>,
L<Term::Fabulous::Render>, L<Term::Fabulous::Render::Target::Grid>.

=cut
