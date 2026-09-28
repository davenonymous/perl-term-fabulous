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
	use Termbox 2 qw(TB_DEFAULT TB_TRUECOLOR_BLACK TB_TRUECOLOR_REVERSE TB_TRUECOLOR_BOLD TB_TRUECOLOR_UNDERLINE);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant DEFAULT_MAX_HEIGHT => 4096;
	use constant RESET              => "\e[0m";

	# Term::Fabulous::Render::Attr packs the color into the low 24 bits and
	# the flags above them.
	use constant COLOR_MASK => 0xFFFFFF;

	field $trim_trailing_whitespace :param :reader = 1;

	# Clay::UI needs a height, and content is expected to end far before it.
	sub BUILDARGS ( $class, %params ) {
		$params{height} //= DEFAULT_MAX_HEIGHT;
		return %params;
	}

	method pointer_state () {
		return undef;
	}

	method render_lines ( %options ) {
		my $colors = $options{colors} // 1;
		$self->draw;
		return map { $self->_format_row( $_, $colors ) } 0 .. $self->grid_height - 1;
	}

	method render_string ( %options ) {
		return join '', map { "$_\n" } $self->render_lines(%options);
	}

	method print ( %options ) {
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
		return $glyph eq ' ' && $bg == TB_DEFAULT && !( $fg & TB_TRUECOLOR_REVERSE );
	}

	sub _sgr ( $fg, $bg ) {
		my @codes;
		push @codes, 1 if $fg & TB_TRUECOLOR_BOLD;
		push @codes, 4 if $fg & TB_TRUECOLOR_UNDERLINE;
		push @codes, 7 if ( $fg | $bg ) & TB_TRUECOLOR_REVERSE;
		push @codes, _color_codes( 38, $fg );
		push @codes, _color_codes( 48, $bg );
		return @codes ? "\e[" . join( ';', @codes ) . 'm' : '';
	}

	# The terminal default needs no code; opaque black carries its own flag
	# because termbox2 reads 0x000000 as the default color.
	sub _color_codes ( $base, $attr ) {
		return () if $attr == TB_DEFAULT;
		my $rgb = $attr & TB_TRUECOLOR_BLACK ? 0 : $attr & COLOR_MASK;
		return () if !( $attr & TB_TRUECOLOR_BLACK ) && $rgb == 0;
		return ( $base, 2, ( $rgb >> 16 ) & 0xFF, ( $rgb >> 8 ) & 0xFF, $rgb & 0xFF );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Static - Render a Clay layout to text instead of a terminal

=head1 SYNOPSIS

	use Term::Fabulous::Static;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

	my $root = Term::Fabulous::Widget::Box->new(
		layout       => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_fit() }, padding => { left => 1, right => 1 } },
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Round,
		border_color => [180, 200, 220, 255],
	);
	$root->add_child( Term::Fabulous::Widget::Text->new( text => 'Hello', text_color => [255, 255, 255, 255] ) );

	my $page = Term::Fabulous::Static->new( root => $root, width => 40 );
	$page->print;                                   # colors when STDOUT is a terminal
	my @lines = $page->render_lines( colors => 0 ); # plain character strings

=head1 DESCRIPTION

A L<Clay::UI> subclass that lays out a widget tree exactly like
L<Term::Fabulous> does and paints it with the same render roles, but into
memory (L<Term::Fabulous::Render::Target::Grid>) instead of termbox2. The
result is text: one string per terminal row, optionally with 24-bit ANSI
color sequences. No terminal is opened and no event loop runs, so the output
can be printed, piped or compared in tests.

Text widgets, border styles and colors behave as on screen. Cells nothing
painted are spaces in the terminal's default colors.

=head1 CONSTRUCTOR

=head2 new

	my $page = Term::Fabulous::Static->new( root => $root, width => 80 );

Takes the L<Clay::UI> parameters. C<width> is the number of columns the
layout may use and is required. C<height> is the layout height in rows and
defaults to 4096: rows below the last painted one are not part of the
output, so a root with a C<fit> height produces exactly as many rows as its
content needs, while a root with a C<grow> height fills the whole
C<height>. Unknown parameters die.

=over

=item C<trim_trailing_whitespace>

Boolean, default 1. Drops cells at the end of a row that would print as
plain spaces: cells nothing painted and spaces in the terminal's default
background. Spaces in a colored background are kept. When off, every row
is padded with spaces to C<width> columns.

=back

=head1 METHODS

=head2 render_lines

	my @lines = $page->render_lines( colors => 0 );

Lays the tree out, paints it and returns one character string per row, up
to the last row anything was painted in. With C<colors> true (the default)
each run of cells with the same foreground and background is wrapped in a
truecolor SGR sequence (C<ESC [ 38;2;r;g;b m>, C<48;2;...>, plus C<7> for
reverse video as used by some border styles), and every colored row ends
with C<ESC [ 0 m>. Terminal-default colors emit no sequence. With C<colors>
false the strings contain only the glyphs.

=head2 render_string

The lines of L</render_lines> joined with newlines, each row ending in one.

=head2 print

	$page->print;
	$page->print( fh => \*STDERR, colors => 0 );

Writes L</render_string> as UTF-8 to C<fh> (default C<STDOUT>). C<colors>
defaults to whether the handle is a terminal.

=head1 SEE ALSO

L<Term::Fabulous>, L<Term::Fabulous::Render>, L<Term::Fabulous::Render::Target::Grid>.

=cut
