package Term::Fabulous::Render::Geometry;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(cell_rect intersect_cell_rects visible_cell_rect rects_overlap row_spans_outside cell_coordinate);

use List::Util qw(min max);
use POSIX qw(floor);
use Scalar::Util qw(looks_like_number);

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

# Rounds down; int() and a comparison are much cheaper than POSIX::floor.
sub cell_coordinate ( $what, $value ) {
	die "Term::Fabulous::Render::Geometry: $what must be a finite number, got " . ( defined $value ? "'$value'" : 'undef' )
		unless looks_like_number($value) && $value == $value && $value - $value == 0;
	my $whole = int $value;
	return $whole <= $value ? $whole : $whole - 1;
}

sub rects_overlap ( $first, $second ) {
	my ( $x0, $y0, $x1, $y1 ) = @{ intersect_cell_rects( $first, $second ) };
	return $x0 < $x1 && $y0 < $y1;
}

sub row_spans_outside ( $y, $x0, $x1, @rects ) {
	my @holes = sort { $a->[0] <=> $b->[0] } map { [ max( $x0, $_->[0] ), min( $x1, $_->[2] ) ] } grep { $y >= $_->[1] && $y < $_->[3] && $_->[0] < $x1 && $_->[2] > $x0 } @rects;

	my ( @spans, $from );
	$from = $x0;
	foreach my $hole (@holes) {
		push @spans, [ $from, $hole->[0] ] if $hole->[0] > $from;
		$from = max( $from, $hole->[1] );
	}
	push @spans, [ $from, $x1 ] if $x1 > $from;
	return @spans;
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Geometry - Snap Clay's layout boxes to terminal cells

=head1 SYNOPSIS

	use Term::Fabulous::Render::Geometry qw(cell_rect intersect_cell_rects visible_cell_rect);

	my ( $x0, $y0, $x1, $y1 ) = cell_rect( { x => 1.7, y => 2, width => 3.6, height => 2 } );    # (1, 2, 5, 4)
	my $both    = intersect_cell_rects( [ 0, 0, 10, 5 ], [ 8, 3, 12, 9 ] );                      # [8, 3, 10, 5]
	my @visible = visible_cell_rect( $command->{boundingBox}, $ui->clip_rect );

=head1 DESCRIPTION

Most programs never use this module directly. It is used by the render
roles and the canvas widgets.

Clay places boxes at fractional positions, which may be negative or
reach past the viewport. Terminal output needs whole cells. These
functions convert boxes to cells the same way everywhere: the left edge
is C<floor(x)>, the right edge C<floor(x + width)>, and likewise for the
top and bottom.

Cell rectangles are written C<[x0, y0, x1, y1]>: C<x0>, C<y0> is the
top-left cell, and C<x1>, C<y1> are I<exclusive>, so the rectangle
covers the columns C<x0 .. x1 - 1> and the rows C<y0 .. y1 - 1>. A
rectangle with C<x1 == x0> or C<y1 == y0> is empty.

=head1 FUNCTIONS

Nothing is exported by default. Import the functions you need by name.

=head2 cell_rect

	my ( $x0, $y0, $x1, $y1 ) = cell_rect($bbox);

The cell rectangle of a Clay bounding box, a hash reference with C<x>,
C<y>, C<width> and C<height>, as a list. It is not clipped, so it may
lie partly or fully outside the viewport.

=head2 intersect_cell_rects

	my $common = intersect_cell_rects( $first, $second );

The cells two rectangles have in common, as a new array reference
C<[x0, y0, x1, y1]>. When they do not overlap, the result is an empty
rectangle (C<x1 == x0> or C<y1 == y0>).

=head2 visible_cell_rect

	my ( $x0, $y0, $x1, $y1 ) = visible_cell_rect( $bbox, $clip );

L</cell_rect> of C<$bbox>, intersected with the rectangle C<$clip>
(usually L<Term::Fabulous::Render::Clip/clip_rect>), as a list. Returns
the empty list when nothing of the box is visible.

=head2 rects_overlap

	if ( rects_overlap( $first, $second ) ) { ... }

True if the two rectangles share at least one cell. Rectangles that
only touch (one ends where the other starts) do not overlap.

=head2 row_spans_outside

	my @spans = row_spans_outside( $y, $x0, $x1, @rects );

The parts of row C<$y> between the columns C<$x0> (inclusive) and
C<$x1> (exclusive) that none of the rectangles C<@rects> covers, as a
list of C<[from, to]> pairs (C<to> exclusive), from left to right.
Without rectangles it returns the whole span C<[$x0, $x1]>.

	row_spans_outside( 1, 0, 10, [ 2, 0, 4, 3 ], [ 6, 1, 8, 2 ] );    # ([0, 2], [4, 6], [8, 10])

=head2 cell_coordinate

	my $column = cell_coordinate( x => $x );

A coordinate or size given to a canvas drawing method, rounded down to
a whole cell: C<3.9> becomes 3, C<-0.5> becomes -1. Dies unless the
value is a finite number (NaN and infinities die); the first argument
names the value in the message:

	Term::Fabulous::Render::Geometry: x must be a finite number, got 'inf'

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Render::Clip>.

=cut
