package Term::Fabulous::Render::Rectangle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Clip;

role Term::Fabulous::Render::Rectangle :does(Term::Fabulous::Render::Clip) {
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);
	use Term::Fabulous::Render::Geometry qw(visible_cell_rect);

	method fill_row;

	# Fills the visible (clipped) part of the box with spaces in the background color
	# and records that background in the shadow buffer.
	method render_rectangle ( $command, $widget, $buffer ) {
		my ( $x0, $y0, $x1, $y1 ) = visible_cell_rect( $command->{boundingBox}, $self->clip_rect );
		return unless defined $x0;

		my $bg_attr = color_attr( clay_color( $command->{renderData}{backgroundColor} ) );
		my $columns = $x1 - $x0;

		foreach my $y ( $y0 .. $y1 - 1 ) {
			my $row = $buffer->[$y] //= [];
			@{$row}[ $x0 .. $x1 - 1 ] = ($bg_attr) x $columns;
			$self->fill_row( $x0, $y, $columns, $bg_attr );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Rectangle - Paint widget backgrounds

=head1 SYNOPSIS

	# Composed by Term::Fabulous::Render; called from draw for every
	# rectangle render command:
	$ui->render_rectangle( $command, $widget, $buffer );

=head1 DESCRIPTION

Most programs never use this module directly. It is one of the roles
L<Term::Fabulous::Render> is made of, and it paints the rectangle render
commands Clay emits for widget backgrounds (C<background_color>).

=head1 METHODS

=head2 render_rectangle

	$ui->render_rectangle( $command, $widget, $buffer );

Fills the cells of the command's bounding box that lie inside the
current clip area (see L<Term::Fabulous::Render::Clip/clip_rect>) with
spaces in the command's background color, using the target's
C<fill_row>. It also records that background color for every filled
cell in C<$buffer>, an array reference of rows of attributes indexed
C<< $buffer->[$y][$x] >>, so that text and borders drawn on top later in
the frame know the background below them.

C<$command> is a Clay render command hash (see
L<Clay::XS/RENDER COMMANDS>); C<$widget> is the widget it belongs to
and is not used.

=head1 REQUIRED METHODS

The consuming class provides C<fill_row> (from a cell target, see
L<Term::Fabulous::Render/CELL TARGET>) and C<width> and C<height> (for
L<Term::Fabulous::Render::Clip>).

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Render::Clip>.

=cut
