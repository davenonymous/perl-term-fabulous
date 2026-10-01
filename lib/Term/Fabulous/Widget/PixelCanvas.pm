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

Term::Fabulous::Widget::PixelCanvas - Canvas of half-block pixels

=head1 SYNOPSIS

	use Term::Fabulous::Widget::PixelCanvas;
	use Clay::XS qw(sizing_grow);
	use Termbox 2 qw(TB_KEY_MOUSE_LEFT);

	my $image = Term::Fabulous::Widget::PixelCanvas->new(
		background_color => [0, 0, 0, 255],
		layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	$image->on( CanvasResize => sub ($event) {
		my ( $width, $height ) = ( $image->pixel_width, $image->pixel_height );
		$image->clear;
		$image->draw_line( 0, $height - 1, $width - 1, 0, 0x00FF00 );
		$image->draw_circle( $width / 2, $height / 2, $height / 3, '#ff8800' );
		$image->fill_rect( 2, 2, 6, 4, [ 40, 80, 200 ] );
	} );

	$image->on( Mouse => sub ($event) {
		return unless $event->key == TB_KEY_MOUSE_LEFT;
		my ( $x, $y ) = $image->pixel_at($event) or return;
		$image->set_pixel( $x, $y, 0xFFFFFF )->set_pixel( $x, $y + 1, 0xFFFFFF );
	} );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Canvas> drawn in pixels: every cell shows
two of them on top of each other, as an upper half block (U+2580) in
the color of the top pixel over the color of the bottom one, or a lower
half block (U+2584) when only the bottom pixel is set. The image is
C<columns> pixels wide and twice C<rows> pixels high, and a terminal
cell is about twice as high as wide, so pixels come out roughly square.
Unknown constructor parameters die.

Everything else works as in the canvas: the buffer follows the layout
(and fires C<CanvasResize>), only changed cells are painted, and unset
pixels show the background of the canvas or its nearest ancestor.

The pixels are the cells: a pixel is read back from the half block in
its cell. The inherited cell methods (C<put>, C<put_text>, C<fill>,
C<erase>, C<clear>) therefore work for text over the image, and a cell
written that way shows no pixels until a pixel is set in it again; this
also unsets the other pixel of that cell.

=head2 Coordinates and colors

C<$x> counts pixels from the left, C<$y> from the top, both from 0.
Coordinates, sizes and the radius must be finite numbers and are
rounded down; anything else dies. Pixels outside the image are dropped,
so shapes may extend past its edges. Colors are given as for the
canvas (L<Term::Fabulous::Widget::Canvas/Colors>); C<undef>, or a color
with alpha 0, unsets the pixels instead.

The drawing methods return the pixel canvas, so calls chain.

=head1 METHODS

=head2 set_pixel, unset_pixel

	$image->set_pixel( $x, $y, $color );
	$image->unset_pixel( $x, $y );

=head2 pixel

	my $attr = $image->pixel( $x, $y );

The termbox2 attribute of a pixel (see
L<Term::Fabulous::Render::Attr>), C<undef> when it is unset or outside
the image.

=head2 fill_rect, draw_rect

	$image->fill_rect( $x, $y, $width, $height, $color );
	$image->draw_rect( $x, $y, $width, $height, $color );

All pixels of the rect, or only its one-pixel outline. Nothing for a
width or height below 1.

=head2 draw_line

	$image->draw_line( $from_x, $from_y, $to_x, $to_y, $color );

Every pixel from one end point to the other (Bresenham), both included.
The number of pixels visited grows with the length of the line, also
outside the image.

=head2 draw_circle

	$image->draw_circle( $center_x, $center_y, $radius, $color );

The one-pixel outline of a circle (midpoint algorithm); radius 0 is a
single pixel. A negative radius dies.

=head2 pixel_at

	my ( $x, $y ) = $image->pixel_at($mouse_event);

The upper pixel of the cell under a L<Term::Fabulous::Event::Mouse>
(see L<Term::Fabulous::Widget::Canvas/cell_at>); the terminal reports
the pointer per cell, so the pixel below it, C<$y + 1>, is under the
pointer as well. The empty list when the pointer is outside the image.

=head2 pixel_width, pixel_height

The size of the image in pixels: C<columns> and C<2 * rows>.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Box/KDL PROPERTIES>.

=cut
