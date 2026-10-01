package Term::Fabulous::Render::Geometry;

use v5.22;
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

=head2 cell_coordinate

	my $column = cell_coordinate( x => $x );

A coordinate or size given to the canvas drawing methods, rounded down
to a whole cell. Dies when it is not a finite number (C<NaN> and
infinities included); C<$what> names the argument in the error.

=head2 rects_overlap

	my $overlap = rects_overlap([$x0, $y0, $x1, $y1], [$x0, $y0, $x1, $y1]);

True when two C<[x0, y0, x1, y1]> rects share at least one cell.

=head2 row_spans_outside

	my @spans = row_spans_outside($y, $x0, $x1, @rects);

The cells C<$x0 .. $x1 - 1> of row C<$y> that none of the
C<[x0, y0, x1, y1]> rects covers, as C<[from, to]> pairs (C<to>
exclusive) from left to right. Without rects it is the whole span.

=cut
