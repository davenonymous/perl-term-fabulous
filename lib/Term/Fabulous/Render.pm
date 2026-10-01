package Term::Fabulous::Render;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

# Loaded first: dies with a clear message when termbox2 lacks truecolor,
# before the TB_OUTPUT_TRUECOLOR import below could fail obscurely.
use Term::Fabulous::Render::Attr ();

use Term::Fabulous::Render::Rectangle;
use Term::Fabulous::Render::Border;
use Term::Fabulous::Render::Text;

role Term::Fabulous::Render
	:does(Term::Fabulous::Render::Rectangle)
	:does(Term::Fabulous::Render::Border)
	:does(Term::Fabulous::Render::Text)
{
	use Clay::XS qw(
		CLAY_RENDER_COMMAND_TYPE_NONE
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE
		CLAY_RENDER_COMMAND_TYPE_BORDER
		CLAY_RENDER_COMMAND_TYPE_TEXT
		CLAY_RENDER_COMMAND_TYPE_IMAGE
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_START
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_END
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_START
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_END
		CLAY_RENDER_COMMAND_TYPE_CUSTOM
	);
	use Encode qw(decode);
	use Scalar::Util qw(looks_like_number);
	use Termbox 2 qw(TB_OUTPUT_TRUECOLOR);
	use Term::Fabulous::Unicode qw(string_columns);

	my %handler_by_command_type = (
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE()     => 'render_rectangle',
		CLAY_RENDER_COMMAND_TYPE_BORDER()        => 'render_border',
		CLAY_RENDER_COMMAND_TYPE_TEXT()          => 'render_text',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_START() => 'render_scissor_start',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_END()   => 'render_scissor_end',
	);

	# Clay_UpdateScrollContainers moves a scroll container by ten layout
	# units, here cells, per unit of scroll delta.
	use constant CELLS_PER_CLAY_SCROLL_UNIT => 10;

	my %command_type_name = (
		CLAY_RENDER_COMMAND_TYPE_NONE()                => 'NONE',
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE()           => 'RECTANGLE',
		CLAY_RENDER_COMMAND_TYPE_BORDER()              => 'BORDER',
		CLAY_RENDER_COMMAND_TYPE_TEXT()                => 'TEXT',
		CLAY_RENDER_COMMAND_TYPE_IMAGE()               => 'IMAGE',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_START()       => 'SCISSOR_START',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_END()         => 'SCISSOR_END',
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_START() => 'OVERLAY_COLOR_START',
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_END()   => 'OVERLAY_COLOR_END',
		CLAY_RENDER_COMMAND_TYPE_CUSTOM()              => 'CUSTOM',
	);

	field $output_mode :param :reader = TB_OUTPUT_TRUECOLOR;

	# Background attribute of every cell painted this frame, indexed [y][x].
	field $buffer = [];
	field @last_commands;

	# The clip rect each of @last_commands was painted under; shorter than
	# @last_commands when painting the frame died.
	field @last_clip_rects;

	# Provided by Clay::UI.
	method render;
	method widget_for;
	method measure_text;

	# Provided by the consumer: undef, or { x, y, down } of the pointer.
	method pointer_state;

	# Provided by a cell target role (Term::Fabulous::Render::Target::*).
	method begin_frame;
	method end_frame;
	method set_cell;
	method extend_cell;
	method fill_row;

	ADJUST {
		die "Term::Fabulous::Render: output_mode must be TB_OUTPUT_TRUECOLOR (" . TB_OUTPUT_TRUECOLOR . "), got '$output_mode'"
			unless looks_like_number($output_mode) && $output_mode == TB_OUTPUT_TRUECOLOR;

		$self->measure_text( \&_measure_text );
	}

	# Clay measures single words and single lines, so the height is one cell.
	sub _measure_text ( $text, $config, $userdata ) {
		return { width => string_columns( decode( 'UTF-8', $text, Encode::FB_DEFAULT ) ), height => 1 };
	}

	method get_last_commands () {
		return @last_commands;
	}

	method get_last_clip_rects () {
		return @last_clip_rects;
	}

	method _dispatch_command ($command) {
		my $type    = $command->{commandType};
		my $handler = $handler_by_command_type{$type}
			// die sprintf( "Term::Fabulous::Render: unhandled render command type %s", $command_type_name{$type} // $type );
		push @last_clip_rects, $self->clip_rect;
		$self->$handler( $command, $self->widget_for( $command->{userData} ), $buffer );
		return;
	}

	sub _clay_scroll_delta ($scroll_cells) {
		die "Term::Fabulous::Render: scroll_cells must be [columns, rows] of numbers"
			unless ref $scroll_cells eq 'ARRAY' && @$scroll_cells == 2 && !grep { !looks_like_number($_) } @$scroll_cells;
		my ( $columns, $rows ) = @$scroll_cells;
		return { x => $columns / CELLS_PER_CLAY_SCROLL_UNIT, y => $rows / CELLS_PER_CLAY_SCROLL_UNIT };
	}

	method draw (%args) {
		my @unknown = grep { $_ ne 'scroll_cells' } sort keys %args;
		die "Term::Fabulous::Render: draw got unknown argument(s): @unknown" if @unknown;

		my $pointer  = $self->pointer_state;
		my $commands = $self->render(
			( defined $pointer            ? ( pointer_state => $pointer )                                    : () ),
			( defined $args{scroll_cells} ? ( scroll_delta  => _clay_scroll_delta( $args{scroll_cells} ) ) : () ),
		);
		@last_commands   = @$commands;
		@last_clip_rects = ();

		$self->begin_frame;
		$buffer = [];
		$self->close_scissors;
		$self->_dispatch_command($_) foreach @$commands;
		$self->end_frame;
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render - Draw Clay render commands with termbox2

=head1 SYNOPSIS

	class My::UI :isa(Clay::UI) :does(Term::Fabulous::Render) :does(Term::Fabulous::Render::Target::Termbox) {
		method pointer_state () { return undef }
	}

	$ui->draw;   # after tb_init(); Term::Fabulous->run does this for you

=head1 DESCRIPTION

Role for a L<Clay::UI> subclass (usually L<Term::Fabulous>). On
construction it validates C<output_mode> and installs a measure-text
callback that reports terminal columns (L<Term::Fabulous::Unicode>).
The role decides which cells to paint; where they go is up to a cell
target role the consumer composes as well (see L</CELL TARGET>).

=head2 output_mode

Constructor parameter; must be C<TB_OUTPUT_TRUECOLOR> (the default),
because colors are always emitted as 24-bit values. Anything else dies.

=head2 draw

	$ui->draw;
	$ui->draw( scroll_cells => [ $columns, $rows ] );

Renders the layout (passing the consumer's C<pointer_state>, when
defined, to C<render>), calls the target's C<begin_frame>, paints every
render command through the target and calls C<end_frame>. Rectangle,
border, text and scissor commands are supported; any other command type
dies.

C<scroll_cells> scrolls the scroll container under the pointer (see
L<Clay::UI::Role::Layout::HasScroll>) by that many cells before the
layout pass. Positive values scroll toward the top and left, as a mouse
wheel turned up does; Clay clamps the result to the content. Any other
argument dies.
With the termbox2 target the terminal must be initialized
(L<Term::Fabulous/run> does that); otherwise termbox2 ignores the
drawing calls.

=head2 get_last_commands

The render commands of the most recent C<draw>.

=head2 get_last_clip_rects

The clip rect (L<Term::Fabulous::Render::Clip/clip_rect>) each of
L</get_last_commands> was painted under, in the same order. A command
outside its clip rect, such as content scrolled out of a scroll
container, was not drawn. When painting the frame died, the list ends
at the command that failed.

=head1 RENDERING

Bounding boxes are snapped to cells with C<floor> and clipped to the
viewport (C<width> x C<height>) and to the innermost open scissor
(L<Term::Fabulous::Render::Clip>); nothing outside them is drawn. Clay
opens a scissor around the content of a scroll container. Colors map
to termbox2 attributes as described in L<Term::Fabulous::Render::Attr>.

=over

=item Rectangles

Fill their cells with spaces in the background color.

=item Text

Starts at the top-left cell of its box. Control characters are replaced
(L<Term::Fabulous::Unicode/sanitize_text>) and every grapheme cluster
advances by the columns termbox2 will use, so measuring and drawing
agree. A cluster that would cross the right edge of the box or the
viewport ends the line. The background is the one already painted below
the text.

=item Borders

Drawn for widgets composing L<Term::Fabulous::Role::HasBorderStyle>. A
side is drawn when its Clay border width is positive, as one line of
glyphs on the outermost cells; corners appear where two drawn sides
meet. Each glyph is colored by its style's location code: 0 draws the
border color over the widget's background, 1 over the parent's
background (the cell just outside the box), and 2 and 3 are 1 and 0 in
reverse video, which also inverts terminal-default colors correctly.

=back

=head2 pointer_state

Required from the consumer: C<undef> or C<< { x => ..., y => ..., down => 0|1 } >>.

=head1 CELL TARGET

The render roles compute glyphs and termbox2 attributes
(L<Term::Fabulous::Render::Attr>) and hand them to these methods, which
the consumer must provide by composing a target role:
L<Term::Fabulous::Render::Target::Termbox> draws into the terminal,
L<Term::Fabulous::Render::Target::Grid> collects the cells in memory
(used by L<Term::Fabulous::Static> and by tests).

=over

=item C<begin_frame>, C<end_frame>

Called once before and once after the commands of a frame are painted.

=item C<< set_cell($x, $y, $glyph, $fg, $bg) >>

One cell: a base character and its foreground and background attributes.

=item C<< extend_cell($x, $y, $codepoint) >>

Appends a combining codepoint to the cell set last at that position.

=item C<< fill_row($x, $y, $columns, $bg) >>

C<$columns> cells of spaces in the background C<$bg>, starting at C<$x>.

=back

Coordinates are always inside the viewport and the open scissors;
clipping happens before a target method is called.

=cut
