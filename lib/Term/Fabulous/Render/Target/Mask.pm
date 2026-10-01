package Term::Fabulous::Render::Target::Mask;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Target::Mask {
	use Scalar::Util qw(refaddr);
	use Term::Fabulous::Render::Geometry qw(row_spans_outside);

	# Provided by the target: reset every cell outside the given rects, show
	# the frame, and write cells unconditionally.
	method clear_cells;
	method present_cells;
	method put_cell;
	method put_extension;
	method put_row;

	# Rects whose cells this frame must leave alone, until they are released.
	field @_kept_rects;

	sub _is_kept ( $x, $y, $rects ) {
		foreach my $rect (@$rects) {
			return 1 if $x >= $rect->[0] && $x < $rect->[2] && $y >= $rect->[1] && $y < $rect->[3];
		}
		return 0;
	}

	method begin_frame (@kept_rects) {
		@_kept_rects = @kept_rects;
		$self->clear_cells(@kept_rects);
		return;
	}

	method end_frame () {
		@_kept_rects = ();
		$self->present_cells;
		return;
	}

	method release_rect ($rect) {
		@_kept_rects = grep { refaddr($_) != refaddr($rect) } @_kept_rects;
		return;
	}

	method set_cell ( $x, $y, $glyph, $fg, $bg ) {
		return if @_kept_rects && _is_kept( $x, $y, \@_kept_rects );
		$self->put_cell( $x, $y, $glyph, $fg, $bg );
		return;
	}

	method extend_cell ( $x, $y, $codepoint ) {
		return if @_kept_rects && _is_kept( $x, $y, \@_kept_rects );
		$self->put_extension( $x, $y, $codepoint );
		return;
	}

	method fill_row ( $x, $y, $columns, $bg ) {
		if ( !@_kept_rects ) {
			$self->put_row( $x, $y, $columns, $bg );
			return;
		}
		foreach my $span ( row_spans_outside( $y, $x, $x + $columns, @_kept_rects ) ) {
			my ( $from, $to ) = @$span;
			$self->put_row( $from, $y, $to - $from, $bg );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Target::Mask - Keep cells of a frame untouched

=head1 SYNOPSIS

	role My::Target :does(Term::Fabulous::Render::Target::Mask) {
		method clear_cells (@kept_rects) { ... }
		method present_cells ()          { ... }
		method put_cell ( $x, $y, $glyph, $fg, $bg ) { ... }
		method put_extension ( $x, $y, $codepoint )  { ... }
		method put_row ( $x, $y, $columns, $bg )     { ... }
	}

=head1 DESCRIPTION

Implements the cell target methods of L<Term::Fabulous::Render/CELL TARGET>
on top of five primitives a target role provides. It lets the renderer
keep rects of the previous frame: a canvas that has not moved and that
nothing covers stays on screen without being painted again (see
L<Term::Fabulous::Render::Canvas>).

C<begin_frame(@kept_rects)> asks the target to reset every cell outside
the C<[x0, y0, x1, y1]> rects (C<clear_cells>). Until a rect is
released with C<release_rect($rect)> (the same array reference), every
C<set_cell>, C<extend_cell> and C<fill_row> inside it is dropped, so the
commands painted below a kept canvas do not overwrite it. C<end_frame>
releases every rect and calls C<present_cells>.

Both cell targets, L<Term::Fabulous::Render::Target::Termbox> and
L<Term::Fabulous::Render::Target::Grid>, compose this role.

=cut
