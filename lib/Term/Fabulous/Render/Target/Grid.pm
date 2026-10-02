package Term::Fabulous::Render::Target::Grid;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Target::Mask;

role Term::Fabulous::Render::Target::Grid :does(Term::Fabulous::Render::Target::Mask) {

	# Painted cells, indexed [y][x]; a cell is [ $glyph, $fg, $bg ] or undef
	# when nothing has been painted there. A wide cluster occupies only the
	# cell it starts in; its continuation cells stay undef.
	field @rows;

	method clear_cells (@kept_rects) {
		my @kept_rows;
		foreach my $rect (@kept_rects) {
			my ( $x0, $y0, $x1, $y1 ) = @$rect;
			foreach my $y ( $y0 .. $y1 - 1 ) {
				my $row = $rows[$y] // next;
				( $kept_rows[$y] //= [] )->[$_] = $row->[$_] foreach $x0 .. $x1 - 1;
			}
		}
		@rows = @kept_rows;
		return;
	}

	method present_cells () {
		return;
	}

	method put_cell ( $x, $y, $glyph, $fg, $bg ) {
		( $rows[$y] //= [] )->[$x] = [ $glyph, $fg, $bg ];
		return;
	}

	method put_extension ( $x, $y, $codepoint ) {
		my $cell = $rows[$y][$x] // die "Term::Fabulous::Render::Target::Grid: extend_cell($x, $y) on a cell that was never set";
		$cell->[0] .= $codepoint;
		return;
	}

	method put_row ( $x, $y, $columns, $bg ) {
		my $row = $rows[$y] //= [];
		$row->[$_] = [ ' ', 0, $bg ] foreach $x .. $x + $columns - 1;
		return;
	}

	method cell ( $x, $y ) {
		return $rows[$y][$x];
	}

	method grid_height () {
		return scalar @rows;
	}

	method grid_row ($y) {
		return $rows[$y] // [];
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Target::Grid - Cell target that keeps the
painted cells in memory

=head1 SYNOPSIS

	use Object::Pad 0.825;
	use Clay::UI;
	use Term::Fabulous::Render;
	use Term::Fabulous::Render::Target::Grid;

	class My::Snapshot
		:isa(Clay::UI)
		:does(Term::Fabulous::Render)
		:does(Term::Fabulous::Render::Target::Grid)
	{
		method pointer_state () { return undef }
	}

	my $ui = My::Snapshot->new( root => $root, width => 20, height => 5 );
	$ui->draw;
	my ( $glyph, $fg, $bg ) = @{ $ui->cell( 0, 0 ) };

=head1 DESCRIPTION

Most programs never use this module directly: L<Term::Fabulous::Static>
composes it and turns the cells into text. Use it directly to inspect
exactly what was painted into each cell, for example in tests.

This is a cell target (see L<Term::Fabulous::Render/CELL TARGET>) that
stores every painted cell instead of drawing it, built on
L<Term::Fabulous::Render::Target::Mask>. Each frame starts from an
empty grid, except for the kept rectangles of unchanged canvases.

=head1 METHODS

=head2 cell

	my $cell = $ui->cell( $x, $y );
	my ( $glyph, $fg, $bg ) = @$cell if $cell;

The cell at column C<$x>, row C<$y> (from 0) as an array reference
C<[ $glyph, $fg, $bg ]>, or C<undef> if nothing painted it in the last
frame.

=over

=item *

C<$glyph> is a character string: the base character plus any combining
characters of its grapheme cluster.

=item *

C<$fg> and C<$bg> are the termbox2 attributes the render roles computed
(see L<Term::Fabulous::Render::Attr>): C<0xRRGGBB>, C<TB_DEFAULT> (0) for
the terminal default color, C<TB_TRUECOLOR_BLACK> for black, possibly
combined with flags such as C<TB_TRUECOLOR_REVERSE>. Background fills
store C<TB_DEFAULT> as the foreground.

=item *

A wide cluster (two columns) is stored in the cell it starts in only.
The cell to its right is not written for it: it holds whatever was
painted there earlier in the frame (usually the background fill, a
space) or C<undef>. When you read a row cell by cell, skip as many cells
after a glyph as L<Term::Fabulous::Unicode/cluster_columns> reports for
it, as L<Term::Fabulous::Static> does.

=back

=head2 grid_height

	my $rows = $ui->grid_height;

The number of rows up to and including the last row anything was
painted in.

=head2 grid_row

	my $cells = $ui->grid_row($y);

The cells of row C<$y> as an array reference of the values L</cell>
returns, which may contain C<undef> holes; an empty array reference for
a row nothing was painted in.

=head2 clear_cells

	$ui->clear_cells(@kept_rects);

Primitive for L<Term::Fabulous::Render::Target::Mask>: forgets every
cell outside the given C<[x0, y0, x1, y1]> rectangles (all cells
without rectangles).

=head2 present_cells

Primitive for L<Term::Fabulous::Render::Target::Mask>. Does nothing.

=head2 put_cell

	$ui->put_cell( $x, $y, $glyph, $fg, $bg );

Primitive for L<Term::Fabulous::Render::Target::Mask>: stores one cell.

=head2 put_extension

	$ui->put_extension( $x, $y, $character );

Primitive for L<Term::Fabulous::Render::Target::Mask>: appends a
combining character to a stored cell. Dies if nothing was stored there.

=head2 put_row

	$ui->put_row( $x, $y, $columns, $bg );

Primitive for L<Term::Fabulous::Render::Target::Mask>: stores
C<$columns> spaces with the background C<$bg>.

=head1 SEE ALSO

L<Term::Fabulous::Static>, L<Term::Fabulous::Render/CELL TARGET>,
L<Term::Fabulous::Render::Target::Mask>.

=cut
