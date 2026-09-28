package Term::Fabulous::Render::Rectangle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Rectangle {
	use Termbox 2 qw(tb_print TB_DEFAULT);
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);
	use Term::Fabulous::Render::Geometry qw(visible_cell_rect);

	method width;
	method height;

	# Fills the visible part of the box with spaces in the background color
	# and records that background in the shadow buffer.
	method render_rectangle ( $command, $widget, $buffer ) {
		my ( $x0, $y0, $x1, $y1 ) = visible_cell_rect( $command->{boundingBox}, $self->width, $self->height );
		return unless defined $x0;

		my $bg_attr = color_attr( clay_color( $command->{renderData}{backgroundColor} ) );
		my $columns = $x1 - $x0;
		my $fill    = ' ' x $columns;

		foreach my $y ( $y0 .. $y1 - 1 ) {
			my $row = $buffer->[$y] //= [];
			@{$row}[ $x0 .. $x1 - 1 ] = ($bg_attr) x $columns;
			tb_print( $x0, $y, TB_DEFAULT, $bg_attr, $fill );
		}
		return;
	}
}

1;
