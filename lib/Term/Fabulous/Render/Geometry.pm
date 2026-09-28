package Term::Fabulous::Render::Geometry;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(cell_rect visible_cell_rect);

use List::Util qw(min max);
use POSIX qw(floor);

sub cell_rect ($bbox) {
	my ( $x, $y ) = @{$bbox}{qw(x y)};
	return ( floor($x), floor($y), floor( $x + $bbox->{width} ), floor( $y + $bbox->{height} ) );
}

sub visible_cell_rect ( $bbox, $viewport_width, $viewport_height ) {
	my ( $x0, $y0, $x1, $y1 ) = cell_rect($bbox);
	$x0 = max( $x0, 0 );
	$y0 = max( $y0, 0 );
	$x1 = min( $x1, $viewport_width );
	$y1 = min( $y1, $viewport_height );
	return if $x0 >= $x1 || $y0 >= $y1;
	return ( $x0, $y0, $x1, $y1 );
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Geometry - Map Clay bounding boxes to terminal cells

=head1 SYNOPSIS

	use Term::Fabulous::Render::Geometry qw(cell_rect visible_cell_rect);

	my ($x0, $y0, $x1, $y1) = cell_rect($command->{boundingBox});
	my @visible = visible_cell_rect($command->{boundingBox}, $width, $height);

=head1 DESCRIPTION

Clay bounding boxes are floating point and may be negative or extend
past the viewport. These functions snap them to integer cell bounds the
same way everywhere: C<x0 = floor(x)>, C<x1 = floor(x + width)>, with
C<x1> / C<y1> exclusive.

=head1 FUNCTIONS

=head2 cell_rect

	my ($x0, $y0, $x1, $y1) = cell_rect($bbox);

Unclipped cell bounds of a C<{ x, y, width, height }> box.

=head2 visible_cell_rect

	my ($x0, $y0, $x1, $y1) = visible_cell_rect($bbox, $viewport_width, $viewport_height);

L</cell_rect> intersected with C<[0, width) x [0, height)>. Returns the
empty list when nothing is visible.

=cut
