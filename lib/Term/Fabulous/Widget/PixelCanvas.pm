package Term::Fabulous::Widget::PixelCanvas;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Canvas;

our $VERSION = '0.01';

class Term::Fabulous::Widget::PixelCanvas
	:isa(Term::Fabulous::Widget::Canvas)
	:strict(params)
{
	use List::Util qw(max min);
	use Term::Fabulous::Render::Attr qw(cell_color_attr);
	use Term::Fabulous::Render::Geometry qw(cell_coordinate);

	use constant UPPER_HALF => "\x{2580}";
	use constant LOWER_HALF => "\x{2584}";

	method pixel_width () {
		return $self->columns;
	}

	method pixel_height () {
		return 2 * $self->rows;
	}

	# The (top, bottom) pixel attributes a cell shows; a cell that holds
	# anything but a half block shows no pixels.
	method _pixels_of_cell ( $x, $row ) {
		my ( $glyphs, $fgs, $bgs ) = $self->cell_row($row);
		my $glyph = $glyphs->[$x];
		return ( undef, undef ) unless ref $glyph;
		return ( $fgs->[$x], $bgs->[$x] ) if $glyph->[0] eq UPPER_HALF;
		return ( $bgs->[$x], $fgs->[$x] ) if $glyph->[0] eq LOWER_HALF;
		return ( undef, undef );
	}

	# Sets one pixel of whole coordinates to an attribute (undef unsets
	# it); pixels outside the buffer are dropped.
	method _paint_pixel ( $x, $y, $attr ) {
		return if $x < 0 || $y < 0 || $x >= $self->columns || $y >= 2 * $self->rows;

		my $row = int( $y / 2 );
		my ( $top, $bottom ) = $self->_pixels_of_cell( $x, $row );
		if   ( $y % 2 ) { $bottom = $attr }
		else            { $top    = $attr }

		return $self->put_attrs( $x, $row, undef, undef, undef ) if !defined $top && !defined $bottom;
		return $self->put_attrs( $x, $row, LOWER_HALF, $bottom, undef ) if !defined $top;
		return $self->put_attrs( $x, $row, UPPER_HALF, $top, $bottom );
	}

	method set_pixel ( $x, $y, $color ) {
		$self->_paint_pixel( cell_coordinate( x => $x ), cell_coordinate( y => $y ), cell_color_attr( color => $color ) );
		return $self;
	}

	method unset_pixel ( $x, $y ) {
		$self->_paint_pixel( cell_coordinate( x => $x ), cell_coordinate( y => $y ), undef );
		return $self;
	}

	method pixel ( $x, $y ) {
		my ( $column, $y_pixel ) = ( cell_coordinate( x => $x ), cell_coordinate( y => $y ) );
		return undef if $column < 0 || $y_pixel < 0 || $column >= $self->columns || $y_pixel >= 2 * $self->rows;

		my ( $top, $bottom ) = $self->_pixels_of_cell( $column, int( $y_pixel / 2 ) );
		return $y_pixel % 2 ? $bottom : $top;
	}

	method fill_rect ( $x, $y, $width, $height, $color ) {
		my ( $x0, $y0 ) = ( cell_coordinate( x => $x ), cell_coordinate( y => $y ) );
		my ( $x1, $y1 ) = ( $x0 + cell_coordinate( width => $width ), $y0 + cell_coordinate( height => $height ) );
		my $attr = cell_color_attr( color => $color );

		foreach my $y_pixel ( max( $y0, 0 ) .. min( $y1, $self->pixel_height ) - 1 ) {
			$self->_paint_pixel( $_, $y_pixel, $attr ) foreach max( $x0, 0 ) .. min( $x1, $self->pixel_width ) - 1;
		}
		return $self;
	}

	method draw_rect ( $x, $y, $width, $height, $color ) {
		my ( $x0, $y0 ) = ( cell_coordinate( x => $x ), cell_coordinate( y => $y ) );
		my ( $x1, $y1 ) = ( $x0 + cell_coordinate( width => $width ) - 1, $y0 + cell_coordinate( height => $height ) - 1 );
		my $attr = cell_color_attr( color => $color );
		return $self if $x1 < $x0 || $y1 < $y0;

		foreach my $column ( max( $x0, 0 ) .. min( $x1, $self->pixel_width - 1 ) ) {
			$self->_paint_pixel( $column, $_, $attr ) foreach $y0, $y1;
		}
		foreach my $y_pixel ( max( $y0 + 1, 0 ) .. min( $y1 - 1, $self->pixel_height - 1 ) ) {
			$self->_paint_pixel( $_, $y_pixel, $attr ) foreach $x0, $x1;
		}
		return $self;
	}

	# Bresenham: every pixel the line passes, both end points included.
	method draw_line ( $from_x, $from_y, $to_x, $to_y, $color ) {
		my ( $x, $y )         = ( cell_coordinate( x => $from_x ), cell_coordinate( y => $from_y ) );
		my ( $end_x, $end_y ) = ( cell_coordinate( x => $to_x ),   cell_coordinate( y => $to_y ) );
		my $attr = cell_color_attr( color => $color );

		my ( $dx, $dy ) = ( abs( $end_x - $x ), -abs( $end_y - $y ) );
		my ( $step_x, $step_y ) = ( $x < $end_x ? 1 : -1, $y < $end_y ? 1 : -1 );
		my $error = $dx + $dy;
		while (1) {
			$self->_paint_pixel( $x, $y, $attr );
			last if $x == $end_x && $y == $end_y;
			my $doubled = 2 * $error;
			if ( $doubled >= $dy ) { $error += $dy; $x += $step_x }
			if ( $doubled <= $dx ) { $error += $dx; $y += $step_y }
		}
		return $self;
	}

	# Midpoint circle: the outline, one pixel wide.
	method draw_circle ( $center_x, $center_y, $radius, $color ) {
		my ( $cx, $cy, $r ) = ( cell_coordinate( x => $center_x ), cell_coordinate( y => $center_y ), cell_coordinate( radius => $radius ) );
		die "Term::Fabulous::Widget::PixelCanvas: radius must not be negative, got $radius" if $r < 0;
		my $attr = cell_color_attr( color => $color );

		my ( $x, $y, $error ) = ( $r, 0, 1 - $r );
		while ( $x >= $y ) {
			foreach my $offset ( [ $x, $y ], [ $y, $x ] ) {
				my ( $ox, $oy ) = @$offset;
				$self->_paint_pixel( $cx + $_->[0], $cy + $_->[1], $attr ) foreach [ $ox, $oy ], [ -$ox, $oy ], [ $ox, -$oy ], [ -$ox, -$oy ];
			}
			$y++;
			if ( $error < 0 ) {
				$error += 2 * $y + 1;
			}
			else {
				$x--;
				$error += 2 * ( $y - $x ) + 1;
			}
		}
		return $self;
	}

	method pixel_at ($event) {
		my ( $column, $row ) = $self->cell_at($event);
		return () unless defined $column;
		return ( $column, 2 * $row );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::PixelCanvas - A canvas of square-ish pixels, two
per cell

=head1 SYNOPSIS

	use Clay::XS qw(sizing_grow);
	use Termbox 2 qw(TB_KEY_MOUSE_LEFT);
	use Term::Fabulous::Widget::PixelCanvas;

	my $image = Term::Fabulous::Widget::PixelCanvas->new(
		background_color => [ 0, 0, 0, 255 ],
		layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	# Draw when the size is known, and again after every resize.
	$image->on( CanvasResize => sub ($event) {
		my ( $width, $height ) = ( $image->pixel_width, $image->pixel_height );
		$image->clear;
		$image->draw_line( 0, $height - 1, $width - 1, 0, 0x00FF00 );
		$image->draw_circle( $width / 2, $height / 2, $height / 3, '#ff8800' );
		$image->fill_rect( 2, 2, 6, 4, [ 40, 80, 200 ] );
		return;
	} );

	# Paint with the left mouse button.
	$image->on( Mouse => sub ($event) {
		return unless $event->key == TB_KEY_MOUSE_LEFT;
		my ( $x, $y ) = $image->pixel_at($event) or return;
		$image->set_pixel( $x, $y, 0xFFFFFF )->set_pixel( $x, $y + 1, 0xFFFFFF );
		return;
	} );

=head1 DESCRIPTION

A PixelCanvas is a L<Term::Fabulous::Widget::Canvas> that you draw on
in pixels instead of characters. Every terminal cell shows two pixels
stacked on top of each other, using the half block characters U+2580
(UPPER HALF BLOCK) and U+2584 (LOWER HALF BLOCK): the top pixel is the
character's color, the bottom pixel its background. A terminal cell is
about twice as high as it is wide, so the pixels come out roughly
square. An image is C<columns> pixels wide and C<2 * rows> pixels high.

Everything else works as for a Canvas: the layout decides the size,
C<CanvasResize> tells you when it changes (draw then), only changed
cells are sent to the terminal, and unset pixels show the canvas's
background (or that of its nearest ancestor with one).

=head2 Pixels and cells

The pixels are stored in the cells themselves. The inherited cell
methods (C<put>, C<put_text>, C<fill>, C<erase>, C<clear>) therefore
still work, for example to write text over an image. A cell written
that way shows no pixels any more: both of its pixels count as unset
until a pixel is set in it again, and setting one leaves the other
unset.

=head2 Coordinates and colors

C<$x> counts pixels from the left, C<$y> pixels from the top, both
from 0. Coordinates, sizes and the radius may be any finite numbers and
are rounded down to whole pixels; C<undef>, non-numbers, C<NaN> and
infinities die. Pixels outside the image are silently dropped, so
shapes may extend past its edges.

Colors are given as for the canvas (see
L<Term::Fabulous::Widget::Canvas/Colors>): a packed C<0xRRGGBB>
integer, a L<Term::Fabulous::Color>, or anything
C<< Term::Fabulous::Color->new >> accepts. C<undef>, or a color with
alpha 0, unsets the pixels instead of coloring them.

=head1 CONSTRUCTOR

=head2 new

	my $image = Term::Fabulous::Widget::PixelCanvas->new(%parameters);

Takes exactly the parameters of L<Term::Fabulous::Widget::Canvas> (the
Box parameters, see L<Term::Fabulous::Widget/new>). Unknown parameters
die. Give it a C<sizing>, otherwise the image has no pixels.

=head1 METHODS

The drawing methods return the pixel canvas, so calls chain. A
PixelCanvas also has every method of L<Term::Fabulous::Widget::Canvas>.

=head2 set_pixel

	$image->set_pixel( $x, $y, $color );

Colors one pixel. C<undef> as the color unsets it.

=head2 unset_pixel

	$image->unset_pixel( $x, $y );

Unsets one pixel, so it shows the background.

=head2 pixel

	my $attr = $image->pixel( $x, $y );

Reads one pixel back: the termbox2 attribute number of its color (see
L<Term::Fabulous::Render::Attr>; compare it with
C<Term::Fabulous::Render::Attr::cell_color_attr( color => $color )>),
or C<undef> when the pixel is unset or outside the image.

=head2 fill_rect

	$image->fill_rect( $x, $y, $width, $height, $color );

Colors every pixel of the rectangle that starts at C<($x, $y)> and is
C<$width> pixels wide and C<$height> pixels high. A width or height
below 1 draws nothing.

=head2 draw_rect

	$image->draw_rect( $x, $y, $width, $height, $color );

Colors the one-pixel outline of the same rectangle as C<fill_rect>.

=head2 draw_line

	$image->draw_line( $from_x, $from_y, $to_x, $to_y, $color );

Colors every pixel on the straight line between the two points, both
end points included (Bresenham's algorithm). The time this takes grows
with the length of the line, including the part outside the image.

=head2 draw_circle

	$image->draw_circle( $center_x, $center_y, $radius, $color );

Colors the one-pixel outline of a circle (midpoint algorithm). Radius 0
is a single pixel; a negative radius dies.

=head2 pixel_at

	my ( $x, $y ) = $image->pixel_at($mouse_event);

The pixel under a L<Term::Fabulous::Event::Mouse> (see
L<Term::Fabulous::Widget::Canvas/cell_at>). The terminal reports the
mouse per cell, not per pixel, so this is always the B<upper> pixel of
the cell; the pixel below it, C<$y + 1>, is under the pointer as well.
Returns the empty list when the pointer is outside the image (on the
border or padding, for example) or before the first frame.

=head2 pixel_width

	my $width = $image->pixel_width;

The width of the image in pixels: the same as C<columns>. 0 before the
first frame.

=head2 pixel_height

	my $height = $image->pixel_height;

The height of the image in pixels: C<2 * rows>. 0 before the first
frame.

=head1 EVENTS

The events of L<Term::Fabulous::Widget::Canvas/EVENTS>: C<CanvasResize>
when the size changes (its C<columns> and C<rows> are in cells; use
L</pixel_width> and L</pixel_height> for pixels) and C<Mouse>.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>:

	use Term::Fabulous::Widget::PixelCanvas as PixelCanvas

	PixelCanvas "image" {
		sizing width=grow height=grow
		background_color "#000000"
	}

=head1 SEE ALSO

L<Term::Fabulous::Widget::Canvas>, L<Term::Fabulous::Manual/CANVASES>,
the example program F<examples/pixel-paint.pl>.

=cut
