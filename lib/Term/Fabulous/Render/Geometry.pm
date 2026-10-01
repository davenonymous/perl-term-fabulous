package Term::Fabulous::Render::Geometry;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(cell_rect intersect_cell_rects visible_cell_rect);

use List::Util qw(min max);
use POSIX qw(floor);

sub cell_rect ($bbox) {
	my ( $x, $y ) = @{$bbox}{qw(x y)};
	return ( floor($x), floor($y), floor( $x + $bbox->{width} ), floor( $y + $bbox->{height} ) );
}

sub intersect_cell_rects ( $first, $second ) {
	my $x0 = max( $first->[0], $second->[0] );
	my $y0 = max( $first->[1], $second->[1] );
	my $x1 = max( $x0, min( $first->[2], $second->[2] ) );
	my $y1 = max( $y0, min( $first->[3], $second->[3] ) );
	return [ $x0, $y0, $x1, $y1 ];
}

sub visible_cell_rect ( $bbox, $clip ) {
	my ( $x0, $y0, $x1, $y1 ) = @{ intersect_cell_rects( [ cell_rect($bbox) ], $clip ) };
	return if $x0 >= $x1 || $y0 >= $y1;
	return ( $x0, $y0, $x1, $y1 );
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Geometry - Map Clay bounding boxes to terminal cells

=head1 SYNOPSIS

	use Term::Fabulous::Render::Geometry qw(cell_rect intersect_cell_rects visible_cell_rect);

	my ($x0, $y0, $x1, $y1) = cell_rect($command->{boundingBox});
	my $clip    = intersect_cell_rects([0, 0, $width, $height], [cell_rect($scissor_box)]);
	my @visible = visible_cell_rect($command->{boundingBox}, $clip);

=head1 DESCRIPTION

Clay bounding boxes are floating point and may be negative or extend
past the viewport. These functions snap them to integer cell bounds the
same way everywhere: C<x0 = floor(x)>, C<x1 = floor(x + width)>, with
C<x1> / C<y1> exclusive.

=head1 FUNCTIONS

=head2 cell_rect

	my ($x0, $y0, $x1, $y1) = cell_rect($bbox);

Unclipped cell bounds of a C<{ x, y, width, height }> box.

=head2 intersect_cell_rects

	my $both = intersect_cell_rects([$x0, $y0, $x1, $y1], [$x0, $y0, $x1, $y1]);

The cells two C<[x0, y0, x1, y1]> rects have in common, as a new rect.
When they do not overlap, the result is empty: C<x1 == x0> or
C<y1 == y0>.

=head2 visible_cell_rect

	my ($x0, $y0, $x1, $y1) = visible_cell_rect($bbox, $clip);

L</cell_rect> intersected with the C<[x0, y0, x1, y1]> rect C<$clip>
(usually L<Term::Fabulous::Render::Clip/clip_rect>). Returns the empty
list when nothing is visible.

=cut
