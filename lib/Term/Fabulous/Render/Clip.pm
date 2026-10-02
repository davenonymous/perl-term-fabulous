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

Term::Fabulous::Render::Clip - Keep painting inside the viewport and
Clay's clipping areas

=head1 SYNOPSIS

	use Object::Pad 0.825;
	use Term::Fabulous::Render::Rectangle;
	use Term::Fabulous::Render::Target::Grid;

	class My::Painter
		:does(Term::Fabulous::Render::Rectangle)
		:does(Term::Fabulous::Render::Target::Grid)
	{
		field $width  :param :reader;
		field $height :param :reader;
	}

	my $painter = My::Painter->new( width => 10, height => 5 );
	$painter->render_scissor_start( { boundingBox => { x => 2, y => 1, width => 5, height => 3 } }, undef, [] );
	my ( $x0, $y0, $x1, $y1 ) = @{ $painter->clip_rect };    # (2, 1, 7, 4)

=head1 DESCRIPTION

Most programs never use this module directly. It is composed by the
paint roles (L<Term::Fabulous::Render::Rectangle>,
L<Term::Fabulous::Render::Text>, L<Term::Fabulous::Render::Border> and
L<Term::Fabulous::Render::Canvas>), which paint only inside
L</clip_rect>.

Clay surrounds the content of a clipping element, such as a
L<scroll box|Term::Fabulous::Widget::ScrollBox>, with a pair of
I<scissor> render commands: everything between C<SCISSOR_START> and
C<SCISSOR_END> may only be painted inside the start command's bounding
box. Scissors can be nested; a nested scissor is narrowed to the one
around it. This role keeps the stack of open scissors.

The consuming class provides C<width> and C<height>, the size of the
viewport in cells.

=head1 METHODS

=head2 clip_rect

	my ( $x0, $y0, $x1, $y1 ) = @{ $ui->clip_rect };

The rectangle of cells painting may touch right now, as a new array
reference C<[x0, y0, x1, y1]>: the viewport (C<[0, 0, width, height]>),
narrowed to the innermost open scissor. C<x1> and C<y1> are exclusive,
so the rectangle covers the columns C<x0 .. x1 - 1> and the rows
C<y0 .. y1 - 1>. When the scissor lies outside the viewport, the
rectangle is empty (C<x1 == x0> or C<y1 == y0>).

=head2 render_scissor_start

	$ui->render_scissor_start( $command, $widget, $buffer );

Opens a scissor at the command's bounding box, snapped to whole cells
like every other box (see L<Term::Fabulous::Render::Geometry/cell_rect>)
and narrowed to the scissor already open. The arguments are those of
every render command handler; only C<< $command->{boundingBox} >> is
used.

=head2 render_scissor_end

	$ui->render_scissor_end( $command, $widget, $buffer );

Closes the innermost open scissor. Dies with
C<Term::Fabulous::Render::Clip: scissor end without an open scissor>
when none is open.

=head2 close_scissors

	$ui->close_scissors;

Closes all open scissors. L<Term::Fabulous::Render/draw> calls it
before each frame, so a frame that died halfway does not clip the next
one.

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Render::Geometry>,
L<Term::Fabulous::Widget::ScrollBox>.

=cut
