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

Term::Fabulous::Render::Target::Grid - Collect render cells in memory

=head1 SYNOPSIS

	class My::Canvas :does(Term::Fabulous::Render::Text) :does(Term::Fabulous::Render::Target::Grid) {
		field $width  :param :reader;
		field $height :param :reader;
	}

	my $canvas = My::Canvas->new( width => 20, height => 5 );
	$canvas->render_text( $command, $widget, [] );
	my ( $glyph, $fg, $bg ) = @{ $canvas->cell( 0, 0 ) };

=head1 DESCRIPTION

A cell target (see L<Term::Fabulous::Render/CELL TARGET>) that keeps the
painted cells in memory instead of drawing them. L<Term::Fabulous::Static>
uses it to render a layout to text; tests use it to inspect what a render
role painted.

=head2 cell

	my $cell = $target->cell( $x, $y );

C<[ $glyph, $fg, $bg ]> for a painted cell, C<undef> for one nothing has
touched. C<$glyph> is a character string: the base character plus any
codepoints added with C<extend_cell>. The C<$fg> and C<$bg> values are the
termbox2 attributes the render roles computed (see
L<Term::Fabulous::Render::Attr>); C<fill_row> stores C<TB_DEFAULT> (0) as
the foreground. A wide cluster is stored in the cell it starts in only.

=head2 grid_height

Number of rows up to and including the last row anything was painted in.

=head2 grid_row

	my $cells = $target->grid_row($y);

The arrayref of cells of one row (possibly sparse), an empty arrayref for a
row nothing was painted in.

=head2 begin_frame

	$target->begin_frame(@kept_rects);

Forgets every cell outside the kept C<[x0, y0, x1, y1]> rects (all of
them without rects); see L<Term::Fabulous::Render::Target::Mask>.
C<end_frame> only releases the kept rects.

=cut
