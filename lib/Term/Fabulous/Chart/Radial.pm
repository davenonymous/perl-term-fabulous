package Term::Fabulous::Chart::Radial;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(CELL_ASPECT TAU circle_frame polar_of point_at);

use List::Util qw(min);

# A terminal cell is about twice as high as it is wide; round charts
# measure in cell widths and stretch rows by this factor.
use constant CELL_ASPECT => 2;
use constant TAU         => 8 * atan2( 1, 1 );

# The largest circle that fits an area of cells: its center in cells
# (continuous) and its radius in cell widths. $margin cell widths stay
# free around it.
sub circle_frame ( $x, $y, $width, $height, $margin = 0 ) {
	my $radius = min( $width / 2, $height * CELL_ASPECT / 2 ) - $margin;
	return { center_x => $x + $width / 2, center_y => $y + $height / 2, radius => $radius > 0 ? $radius : 0 };
}

# The polar coordinates of a point in cells: the distance from the
# center in cell widths and the angle in turns (0 to 1) clockwise from
# $start (in turns; 0 is 12 o'clock).
sub polar_of ( $frame, $x, $y, $start = 0 ) {
	my $dx = $x - $frame->{center_x};
	my $dy = ( $y - $frame->{center_y} ) * CELL_ASPECT;
	my $angle = atan2( $dx, -$dy ) / TAU - $start;
	$angle -= int($angle);
	$angle += 1 if $angle < 0;
	return ( sqrt( $dx**2 + $dy**2 ), $angle );
}

# The point in cells at a distance (cell widths) and an angle (turns
# clockwise from 12 o'clock, after $start).
sub point_at ( $frame, $distance, $angle, $start = 0 ) {
	my $radians = ( $angle + $start ) * TAU;
	return ( $frame->{center_x} + $distance * sin($radians), $frame->{center_y} - $distance * cos($radians) / CELL_ASPECT );
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Chart::Radial - Geometry of round charts in terminal
cells

=head1 SYNOPSIS

	use Term::Fabulous::Chart::Radial qw(circle_frame polar_of point_at);

	my $circle = circle_frame( 0, 0, 40, 20 );          # center (20, 10), radius 20
	my ( $distance, $angle ) = polar_of( $circle, 30, 10 );    # 10, 0.25 (3 o'clock)
	my ( $x, $y ) = point_at( $circle, 10, 0.5 );          # (20, 15): 6 o'clock

=head1 DESCRIPTION

Pie, donut, polar area and radar charts are round, but terminal cells are
not square: a cell is about twice as high as it is wide. These functions
measure distances in cell widths and count a row as C<CELL_ASPECT> (2) of
them, so circles come out round. Angles are in turns (1 is a full circle),
clockwise from 12 o'clock.

=head1 FUNCTIONS

=head2 circle_frame

	my $circle = circle_frame( $x, $y, $width, $height, $margin );

The largest circle in an area of cells, less C<$margin>: a hash with
C<center_x>, C<center_y> (cells) and C<radius> (cell widths).

=head2 polar_of

	my ( $distance, $angle ) = polar_of( $circle, $x, $y, $start );

=head2 point_at

	my ( $x, $y ) = point_at( $circle, $distance, $angle, $start );

=head1 SEE ALSO

L<Term::Fabulous::Widget::PieChart>, L<Term::Fabulous::Widget::RadarChart>.

=cut
