package Term::Fabulous::Render::Attr;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(color_attr clay_color cell_color_attr);

use Scalar::Util qw(blessed);
use Termbox 2 qw(TB_DEFAULT);

BEGIN {
	die "Term::Fabulous::Render::Attr: the termbox2 library was built without truecolor support (TB_OPT_TRUECOLOR); Term::Fabulous needs 24-bit colors\n"
		unless $Termbox::TRUECOLOR;
}

use Termbox 2 qw(TB_TRUECOLOR_BLACK);

use Term::Fabulous::Color;

use constant CACHE_LIMIT => 4096;
use constant MAX_RGB     => 0xFFFFFF;

my %attr_by_rgba;
my %color_by_clay_rgba;

sub color_attr ($color) {
	my $rgba = $color->rgba_int;
	my $attr = $attr_by_rgba{$rgba};
	return $attr if defined $attr;

	%attr_by_rgba = () if keys(%attr_by_rgba) >= CACHE_LIMIT;
	return $attr_by_rgba{$rgba} = _termbox_attr($color);
}

sub clay_color ($clay_rgba) {
	die "Term::Fabulous::Render::Attr: a Clay color must be a hash reference with r, g, b, a"
		unless ref $clay_rgba eq 'HASH';

	my $key   = join ',', map { $_ // '' } @{$clay_rgba}{qw(r g b a)};
	my $color = $color_by_clay_rgba{$key};
	return $color if defined $color;

	%color_by_clay_rgba = () if keys(%color_by_clay_rgba) >= CACHE_LIMIT;
	return $color_by_clay_rgba{$key} = Term::Fabulous::Color->new( color => $clay_rgba );
}

# undef, and colors with alpha 0, leave a cell without a color of its own.
sub cell_color_attr ( $what, $color ) {
	return undef unless defined $color;
	if ( !ref $color && $color =~ /\A[0-9]+\z/ ) {
		die "Term::Fabulous::Render::Attr: $what must be a packed 0xRRGGBB value, got $color" if $color > MAX_RGB;
		return $color == 0 ? TB_TRUECOLOR_BLACK : $color + 0;
	}
	my $object = blessed $color && $color->isa('Term::Fabulous::Color') ? $color : Term::Fabulous::Color->new( color => $color );
	my $attr   = color_attr($object);
	return $attr == TB_DEFAULT ? undef : $attr;
}

# termbox2 in truecolor mode reads 0x000000 as "terminal default", so opaque
# black needs its dedicated flag; alpha 0 means "no color" and maps to the
# terminal default on purpose.
sub _termbox_attr ($color) {
	return TB_DEFAULT if $color->alpha == 0;

	my $rgb = $color->rgb_int;
	return $rgb == 0 ? TB_TRUECOLOR_BLACK : $rgb;
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Attr - Turn colors into termbox2 truecolor attributes

=head1 SYNOPSIS

	use Term::Fabulous::Render::Attr qw(color_attr clay_color cell_color_attr);
	use Term::Fabulous::Color;

	my $fg = color_attr( Term::Fabulous::Color->rgb( 0, 0, 0 ) );               # TB_TRUECOLOR_BLACK
	my $bg = color_attr( clay_color( { r => 20, g => 25, b => 35, a => 255 } ) );  # 0x141923
	my $cell_fg = cell_color_attr( fg => '#ffcc00' );                             # 0xFFCC00

=head1 DESCRIPTION

Most programs never use this module directly. It is used by the render
roles and the canvas widgets, and it explains what the color values
returned by L<Term::Fabulous::Widget::Canvas/cell> and
L<Term::Fabulous::Widget::PixelCanvas/pixel> mean.

termbox2 describes the colors of a cell with an integer I<attribute>. In
truecolor mode, the one Term::Fabulous uses, an attribute holds a
24-bit color C<0xRRGGBB> in its low bits and flags such as reverse video
in its high bits. Two values are special:

=over

=item C<TB_DEFAULT> (0)

The terminal's default color. This is what a color with alpha 0 ("no
color") becomes.

=item C<TB_TRUECOLOR_BLACK>

Opaque black. termbox2 would read the color C<0x000000> as the default
color, so black needs this flag of its own.

=back

Alpha values from 1 to 254 are treated as fully opaque; terminals cannot
blend colors.

Loading this module dies if the installed termbox2 library was built
without truecolor support (C<TB_OPT_TRUECOLOR>), because Term::Fabulous
needs 24-bit colors:

	Term::Fabulous::Render::Attr: the termbox2 library was built without truecolor support (TB_OPT_TRUECOLOR); Term::Fabulous needs 24-bit colors

=head1 FUNCTIONS

Nothing is exported by default. Import the functions you need by name.

=head2 color_attr

	my $attr = color_attr($color);

Takes a L<Term::Fabulous::Color> object and returns its attribute:
C<TB_DEFAULT> when its alpha is 0, C<TB_TRUECOLOR_BLACK> for black, and
the packed C<0xRRGGBB> value otherwise. Results are cached (the cache is
emptied when it reaches 4096 entries).

=head2 clay_color

	my $color = clay_color( $command->{renderData}{backgroundColor} );

Takes a color as it appears in Clay render commands, a hash reference
with the keys C<r>, C<g>, C<b> and C<a>, and returns the matching
L<Term::Fabulous::Color> object. Results are cached, so a frame does not
parse colors it has seen before (the cache is emptied when it reaches
4096 entries). Dies unless the argument is a hash reference; invalid
channels die in L<Term::Fabulous::Color>.

=head2 cell_color_attr

	my $attr = cell_color_attr( fg => $color );

Converts the color argument of the canvas drawing methods (see
L<Term::Fabulous::Widget::Canvas/Colors>) into an attribute:

=over

=item *

C<undef> returns C<undef> ("no color of its own").

=item *

A non-negative integer is taken as a packed C<0xRRGGBB> color as it is;
C<0> becomes C<TB_TRUECOLOR_BLACK>. Integers above C<0xFFFFFF> die.

=item *

A L<Term::Fabulous::Color> object, or anything
C<< Term::Fabulous::Color->new >> accepts (C<[r, g, b, a]>, C<'#rrggbb'>,
C<'hsl(...)'>, ...), goes through L</color_attr>. A color with alpha 0
returns C<undef>.

=back

The first argument names the color in error messages, for example
C<Term::Fabulous::Render::Attr: fg must be a packed 0xRRGGBB value, got 16777216>.
Invalid colors die in L<Term::Fabulous::Color>.

=head1 SEE ALSO

L<Term::Fabulous::Color>, L<Term::Fabulous::Render>,
L<Term::Fabulous::Manual/COLORS>.

=cut
