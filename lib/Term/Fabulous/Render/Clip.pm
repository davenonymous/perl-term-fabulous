package Term::Fabulous::Render::Clip;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Clip {
	use Term::Fabulous::Render::Geometry qw(cell_rect intersect_cell_rects);

	method width;
	method height;

	# Cell rects of the open scissors, innermost last; each one already lies
	# inside the one before it.
	field @_scissors;

	method clip_rect () {
		my $viewport = [ 0, 0, $self->width, $self->height ];
		return $viewport unless @_scissors;
		return intersect_cell_rects( $viewport, $_scissors[-1] );
	}

	method render_scissor_start ( $command, $widget, $buffer ) {
		my $scissor = [ cell_rect( $command->{boundingBox} ) ];
		push @_scissors, @_scissors ? intersect_cell_rects( $_scissors[-1], $scissor ) : $scissor;
		return;
	}

	method render_scissor_end ( $command, $widget, $buffer ) {
		die "Term::Fabulous::Render::Clip: scissor end without an open scissor" unless @_scissors;
		pop @_scissors;
		return;
	}

	method close_scissors () {
		@_scissors = ();
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Clip - Clip drawing to the viewport and Clay's scissors

=head1 SYNOPSIS

	class My::Canvas :does(Term::Fabulous::Render::Rectangle) :does(Term::Fabulous::Render::Target::Grid) {
		field $width  :param :reader;
		field $height :param :reader;
	}

	$canvas->render_scissor_start( { boundingBox => { x => 2, y => 1, width => 5, height => 3 } }, undef, [] );
	my ( $x0, $y0, $x1, $y1 ) = @{ $canvas->clip_rect };    # (2, 1, 7, 4)

=head1 DESCRIPTION

Composed by the render roles (L<Term::Fabulous::Render::Rectangle>,
L<Term::Fabulous::Render::Text>, L<Term::Fabulous::Render::Border>);
they draw only inside L</clip_rect>. The consumer provides C<width> and
C<height>, the viewport size in cells.

Clay emits a scissor pair around the content of a clipping element such
as a scroll container: everything between C<SCISSOR_START> and
C<SCISSOR_END> is drawn only inside the start command's bounding box.
Scissors nest; a nested one is narrowed to the one around it.

=head1 METHODS

=head2 clip_rect

The C<[x0, y0, x1, y1]> cells drawing may touch (C<x1> and C<y1>
exclusive): the viewport, narrowed to the innermost open scissor. It is
empty (C<x1 == x0> or C<y1 == y0>) when the scissor lies outside the
viewport.

=head2 render_scissor_start, render_scissor_end

Render command handlers with the signature of the other render roles:
C<($command, $widget, $buffer)>. The start opens a scissor at the
command's bounding box, snapped to cells like every other box
(L<Term::Fabulous::Render::Geometry/cell_rect>); the end closes the
innermost one and dies when none is open.

=head2 close_scissors

Closes every open scissor. L<Term::Fabulous::Render/draw> calls it
before each frame, so a frame that died halfway does not clip the next.

=cut
