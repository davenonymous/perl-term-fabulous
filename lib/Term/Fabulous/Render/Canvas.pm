package Term::Fabulous::Render::Canvas;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Clip;

role Term::Fabulous::Render::Canvas :does(Term::Fabulous::Render::Clip) {
	use Clay::XS qw(
		CLAY_RENDER_COMMAND_TYPE_BORDER
		CLAY_RENDER_COMMAND_TYPE_CUSTOM
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_START
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_END
	);
	use List::Util qw(any max min);
	use Scalar::Util qw(refaddr);
	use Termbox 2 qw(TB_DEFAULT);
	use Term::Fabulous::Color;
	use Term::Fabulous::Render::Attr qw(color_attr);
	use Term::Fabulous::Render::Geometry qw(cell_rect intersect_cell_rects rects_overlap);

	method widget_for;
	method set_cell;
	method extend_cell;
	method release_rect;

	# By canvas refaddr: { canvas, origin => [x, y], visible => [x0, y0, x1, y1],
	# background, covered, intact } for the frame being painted, and for the
	# last frame that was painted completely.
	field %_plan_by_canvas;
	field %_painted_by_canvas;
	field $_painted_viewport = '';

	# The cells a command may paint: borders paint their edges only.
	sub _painted_rects ( $command, $clip ) {
		my $type = $command->{commandType};
		return () if $type == CLAY_RENDER_COMMAND_TYPE_SCISSOR_START || $type == CLAY_RENDER_COMMAND_TYPE_SCISSOR_END;

		my ( $x0, $y0, $x1, $y1 ) = cell_rect( $command->{boundingBox} );
		return intersect_cell_rects( [ $x0, $y0, $x1, $y1 ], $clip ) unless $type == CLAY_RENDER_COMMAND_TYPE_BORDER;

		my $widths = $command->{renderData}{width} // {};
		my %edge   = (
			top    => [ $x0,     $y0,     $x1,     $y0 + 1 ],
			bottom => [ $x0,     $y1 - 1, $x1,     $y1 ],
			left   => [ $x0,     $y0,     $x0 + 1, $y1 ],
			right  => [ $x1 - 1, $y0,     $x1,     $y1 ],
		);
		return map { intersect_cell_rects( $edge{$_}, $clip ) } grep { ( $widths->{$_} // 0 ) > 0 } sort keys %edge;
	}

	# The background of the canvas, or of its nearest ancestor that has one.
	sub _background_attr ($widget) {
		for ( my $node = $widget; defined $node; $node = $node->parent ) {
			next unless $node->can('background_color') && defined $node->background_color;
			my $color = Term::Fabulous::Color->new( color => $node->background_color );
			return color_attr($color) if $color->alpha > 0;
		}
		return TB_DEFAULT;
	}

	sub _same_place ( $before, $now ) {
		return "@{ $before->{origin} } @{ $before->{visible} } $before->{background}" eq "@{ $now->{origin} } @{ $now->{visible} } $now->{background}";
	}

	method _clip_rects_of ($commands) {
		$self->close_scissors;
		my @clip_rects;
		foreach my $command (@$commands) {
			push @clip_rects, $self->clip_rect;
			my $type = $command->{commandType};
			$self->render_scissor_start( $command, undef, [] ) if $type == CLAY_RENDER_COMMAND_TYPE_SCISSOR_START;
			$self->render_scissor_end( $command, undef, [] )   if $type == CLAY_RENDER_COMMAND_TYPE_SCISSOR_END;
		}
		$self->close_scissors;
		return @clip_rects;
	}

	# Sizes the canvas to its content box; undef when nothing of it is visible.
	method _plan_canvas ( $command, $clip ) {
		my $canvas = $self->widget_for( $command->{userData} );
		die "Term::Fabulous::Render::Canvas: a custom render command needs a Term::Fabulous::Widget::Canvas, got " . ( ref $canvas || 'no widget' )
			unless defined $canvas && $canvas->isa('Term::Fabulous::Widget::Canvas');

		my ( $x0, $y0, $x1, $y1 ) = cell_rect( $command->{boundingBox} );
		my ( $left, $top, $right, $bottom ) = $canvas->content_insets;
		my @content = ( $x0 + $left, $y0 + $top );
		push @content, max( $content[0], $x1 - $right ), max( $content[1], $y1 - $bottom );
		$canvas->fit_to( $content[2] - $content[0], $content[3] - $content[1] );

		my $visible = intersect_cell_rects( \@content, $clip );
		return undef unless rects_overlap( $visible, $visible );
		return { canvas => $canvas, origin => [ @content[ 0, 1 ] ], visible => $visible, background => _background_attr($canvas) };
	}

	method plan_canvases ($commands) {
		my $viewport = join 'x', $self->width, $self->height;
		my %painted  = $viewport eq $_painted_viewport ? %_painted_by_canvas : ();
		%_painted_by_canvas = ();
		%_plan_by_canvas    = ();
		$_painted_viewport  = $viewport;

		my @custom_indices = grep { $commands->[$_]{commandType} == CLAY_RENDER_COMMAND_TYPE_CUSTOM } 0 .. $#$commands;
		return () unless @custom_indices;

		my @clip_rects    = $self->_clip_rects_of($commands);
		my @painted_rects = map { [ _painted_rects( $commands->[$_], $clip_rects[$_] ) ] } 0 .. $#$commands;
		foreach my $index (@custom_indices) {
			my $plan = $self->_plan_canvas( $commands->[$index], $clip_rects[$index] ) // next;
			my $before = $painted{ refaddr $plan->{canvas} };

			$plan->{covered} = any { rects_overlap( $_, $plan->{visible} ) } map {@$_} @painted_rects[ $index + 1 .. $#$commands ];
			$plan->{intact}  = !$plan->{covered} && defined $before && !$before->{covered} && _same_place( $before, $plan );
			$_plan_by_canvas{ refaddr $plan->{canvas} } = $plan;
		}
		return map { $_->{visible} } grep { $_->{intact} } values %_plan_by_canvas;
	}

	method finish_canvases () {
		%_painted_by_canvas = %_plan_by_canvas;
		%_plan_by_canvas    = ();
		return;
	}

	method invalidate_canvases () {
		%_painted_by_canvas = ();
		$_painted_viewport  = '';
		return;
	}

	method render_custom ( $command, $widget, $buffer ) {
		my $plan = $_plan_by_canvas{ refaddr $widget } // return;
		$self->release_rect( $plan->{visible} ) if $plan->{intact};

		my $changed_spans = $widget->take_changed_spans;
		my ( $origin_x, $origin_y ) = @{ $plan->{origin} };
		my ( $x0, $y0, $x1, $y1 ) = @{ $plan->{visible} };
		foreach my $y ( $y0 .. $y1 - 1 ) {
			my ( $row, $from, $to ) = ( $y - $origin_y, $x0 - $origin_x, $x1 - $origin_x );
			if ( $plan->{intact} ) {
				my $span = $changed_spans->[$row] // next;
				( $from, $to ) = ( max( $from, $span->[0] ), min( $to, $span->[1] ) );
			}
			$self->_paint_canvas_row( $plan, $row, $from, $to, $buffer );
		}
		return;
	}

	# Paints the canvas columns [from, to) of one row. A glyph that would
	# cross the visible right edge is painted as spaces, like the covered
	# cells of a wide glyph whose first cell is not painted here.
	method _paint_canvas_row ( $plan, $row, $from, $to, $buffer ) {
		my ( $glyphs, $fgs, $bgs ) = $plan->{canvas}->cell_row($row);
		my ( $origin_x, $origin_y ) = @{ $plan->{origin} };
		my $y           = $origin_y + $row;
		my $limit       = $plan->{visible}[2] - $origin_x;
		my $shade       = $buffer->[$y] //= [];
		my $drawn_until = $from;

		foreach my $column ( $from .. $to - 1 ) {
			my ( $glyph, $x ) = ( $glyphs->[$column], $origin_x + $column );
			my $bg = $bgs->[$column] // $plan->{background};
			$shade->[$x] = $bg;

			if ( ref $glyph && $column + $glyph->[1] <= $limit ) {
				my ( undef, $width, $base, @extenders ) = @$glyph;
				$self->set_cell( $x, $y, $base, $fgs->[$column] // TB_DEFAULT, $bg );
				$self->extend_cell( $x, $y, $_ ) foreach @extenders;
				$drawn_until = $column + $width;
				next;
			}
			next if $column < $drawn_until;
			$self->set_cell( $x, $y, ' ', TB_DEFAULT, $bg );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Canvas - Paint canvas widgets, only their changes when possible

=head1 SYNOPSIS

	my @kept_rects = $ui->plan_canvases( \@commands );   # before begin_frame
	$ui->begin_frame(@kept_rects);
	$ui->render_custom( $command, $canvas, $buffer );     # for each CUSTOM command
	$ui->end_frame;
	$ui->finish_canvases;                                 # after a complete frame

=head1 DESCRIPTION

Composed by L<Term::Fabulous::Render>, which calls these methods from
C<draw>. A L<Term::Fabulous::Widget::Canvas> asks Clay for a custom
render command; this role paints its buffer into the canvas's content
box (its box without the border and padding), clipped like every other
command.

=head1 METHODS

=head2 plan_canvases

	my @kept_rects = $ui->plan_canvases( \@commands );

Before a frame is painted: resizes every canvas buffer to its content
box (which may fire L<Term::Fabulous::Event::CanvasResize>) and decides
for every visible canvas whether the cells of the previous frame can
stay. That is the case when the canvas has the same origin, visible
rect and background as in the last completely painted frame and no
later command paints into its visible rect, neither in this frame nor
in that one. The visible rects of those canvases are returned as the
kept rects for the target's C<begin_frame>
(L<Term::Fabulous::Render::Target::Mask>). A change of the viewport
size forgets the previous frame. Dies when a custom render command does
not belong to a canvas.

=head2 render_custom

The render command handler. A canvas whose cells are kept releases its
rect and paints only the cells that changed since it was last painted;
any other canvas paints every visible cell. Unset cells are painted as
spaces in the canvas background. Every painted cell records its
background in the shadow buffer, so text drawn over the canvas keeps
it. Canvases that are not visible are skipped and keep their changes.

=head2 finish_canvases

After a frame has been painted completely: remembers it for the next
C<plan_canvases>. A frame that died before is never remembered, so the
next one paints every canvas in full.

=head2 invalidate_canvases

Forgets the previous frame, so the next one paints every canvas in
full. Needed when the target lost its cells, as termbox2 does in
C<tb_init>.

=cut
