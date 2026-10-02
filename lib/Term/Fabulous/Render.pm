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
use Term::Fabulous::Render::Canvas;

role Term::Fabulous::Render
	:does(Term::Fabulous::Render::Rectangle)
	:does(Term::Fabulous::Render::Border)
	:does(Term::Fabulous::Render::Text)
	:does(Term::Fabulous::Render::Canvas)
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
	use Term::Fabulous::Termbox qw(TB_OUTPUT_TRUECOLOR);
	use Term::Fabulous::Unicode qw(string_columns);

	my %handler_by_command_type = (
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE()     => 'render_rectangle',
		CLAY_RENDER_COMMAND_TYPE_BORDER()        => 'render_border',
		CLAY_RENDER_COMMAND_TYPE_TEXT()          => 'render_text',
		CLAY_RENDER_COMMAND_TYPE_CUSTOM()        => 'render_custom',
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
	method painted_cell;
	method release_rect;

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

	# Clay emits an element's custom command before its background
	# rectangle; paint the background first, below the custom content.
	sub _backgrounds_first (@commands) {
		foreach my $index ( 0 .. $#commands - 1 ) {
			my ( $custom, $next ) = @commands[ $index, $index + 1 ];
			next unless $custom->{commandType} == CLAY_RENDER_COMMAND_TYPE_CUSTOM
				&& $next->{commandType} == CLAY_RENDER_COMMAND_TYPE_RECTANGLE
				&& $next->{id} == $custom->{id};
			@commands[ $index, $index + 1 ] = ( $next, $custom );
		}
		return @commands;
	}

	# Clay counts the right and bottom edges of a box as inside it, so a
	# cell's corner would also lie in the boxes left of and above it; its
	# center lies in the box of the cell only.
	sub _clay_pointer ($pointer) {
		return { %$pointer, x => $pointer->{x} + 0.5, y => $pointer->{y} + 0.5 };
	}

	method draw (%args) {
		my @unknown = grep { $_ ne 'scroll_cells' } sort keys %args;
		die "Term::Fabulous::Render: draw got unknown argument(s): @unknown" if @unknown;

		my $pointer  = $self->pointer_state;
		my $commands = $self->render(
			( defined $pointer            ? ( pointer_state => _clay_pointer($pointer) )                     : () ),
			( defined $args{scroll_cells} ? ( scroll_delta  => _clay_scroll_delta( $args{scroll_cells} ) ) : () ),
		);
		@last_commands   = _backgrounds_first(@$commands);
		@last_clip_rects = ();

		$self->begin_frame( $self->plan_canvases( \@last_commands ) );
		$buffer = [];
		$self->close_scissors;
		$self->_dispatch_command($_) foreach @last_commands;
		$self->end_frame;
		$self->finish_canvases;
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render - Role that paints Clay render commands into
terminal cells

=head1 SYNOPSIS

	use Object::Pad 0.825;
	use Clay::UI;
	use Term::Fabulous::Render;
	use Term::Fabulous::Render::Target::Grid;

	# A UI class that paints into memory and never sees a pointer.
	class My::Snapshot
		:isa(Clay::UI)
		:does(Term::Fabulous::Render)
		:does(Term::Fabulous::Render::Target::Grid)
	{
		method pointer_state () { return undef }
	}

	my $ui = My::Snapshot->new( root => $root, width => 10, height => 2 );
	$ui->draw;
	my ( $glyph, $fg, $bg ) = @{ $ui->cell( 0, 0 ) };

=head1 DESCRIPTION

Most programs never use this module directly. L<Term::Fabulous> (for
the terminal) and L<Term::Fabulous::Static> (for text output) already
compose it. Read on if you want to write your own UI class, for example
one that paints into a different kind of output.

Term::Fabulous::Render is an L<Object::Pad> role for a subclass of
L<Clay::UI>. It turns a laid-out widget tree into terminal cells:
L</draw> asks Clay::UI for the frame's render commands (rectangles,
borders, text, clipping and canvases) and paints each of them, cell by
cell. Where the cells go is decided by a second role, the I<cell
target>, which the class composes as well (see L</CELL TARGET>).

The role is composed of smaller roles, one per kind of render command:
L<Term::Fabulous::Render::Rectangle>, L<Term::Fabulous::Render::Border>,
L<Term::Fabulous::Render::Text>, L<Term::Fabulous::Render::Canvas> and
L<Term::Fabulous::Render::Clip>.

When it is constructed, the role checks C<output_mode> and installs its
own measure-text callback in Clay::UI (C<measure_text>), which reports
text widths in terminal columns (see L<Term::Fabulous::Unicode>). Any
C<measure_text> given to the constructor is replaced.

Loading this module dies if the termbox2 library was built without
truecolor support; see L<Term::Fabulous::Render::Attr>.

=head1 REQUIREMENTS OF THE CONSUMING CLASS

The class that composes this role must provide:

=over

=item * the methods of L<Clay::UI>: C<render>, C<widget_for>, C<measure_text>, C<width> and C<height> (subclass Clay::UI);

=item * C<pointer_state> (see L</pointer_state>);

=item * the cell target methods (compose one of the target roles; see L</CELL TARGET>).

=back

=head1 CONSTRUCTOR PARAMETERS

=over

=item C<output_mode>

The termbox2 output mode. It must be C<TB_OUTPUT_TRUECOLOR> (from
L<Term::Fabulous::Termbox>), which is also the default, because Term::Fabulous always
paints 24-bit colors. Any other value dies with
C<Term::Fabulous::Render: output_mode must be TB_OUTPUT_TRUECOLOR>.
There is no reason to pass it.

=back

=head1 METHODS

=head2 draw

	$ui->draw;
	$ui->draw( scroll_cells => [ $columns, $rows ] );

Lays out and paints one frame:

=over

=item 1.

Calls Clay::UI's C<render>, passing the pointer from L</pointer_state>
(when it is defined) and the scroll amount. Clay::UI fires its pointer
events (hover, press, scroll) during this call.

=item 2.

Sizes every canvas to its new content box and decides which canvases
can keep the cells of the previous frame
(L<Term::Fabulous::Render::Canvas/plan_canvases>). Canvases fire
C<CanvasResize> here.

=item 3.

Calls the target's C<begin_frame>, paints every render command in order
and calls C<end_frame>.

=item 4.

Calls L<Term::Fabulous::Render::Canvas/finish_canvases>, which
remembers this completely painted frame for the comparison in step 2 of
the next frame. If painting died, this step is skipped and the next
frame paints every canvas in full.

=back

C<scroll_cells> scrolls the scroll container under the pointer (see
L<Term::Fabulous::Widget::ScrollBox>) by C<[$columns, $rows]> cells
before the layout is computed. Positive values reveal content
above and to the left (the content moves down and right on screen), as
turning a mouse wheel up does; negative values reveal content below and
to the right. Clay keeps
the result within the content. L<Term::Fabulous> passes the wheel
notches since the last frame here.

Any other argument dies. Render command types other than rectangle,
border, text, scissor (clipping) and custom (canvas) die; Term::Fabulous
widgets produce only these. With the termbox2 target, the terminal must
have been opened (L<Term::Fabulous/run> does that); otherwise termbox2
ignores the drawing.

=head2 get_last_commands

	my @commands = $ui->get_last_commands;

The render commands of the last L</draw>, in the order they were
painted, as hash references in the format of L<Clay::XS/RENDER COMMANDS>.
L<Term::Fabulous> uses them to find the widget under the mouse pointer.
Use C<< $ui->widget_for( $command->{userData} ) >> to get the widget a
command belongs to.

=head2 get_last_clip_rects

	my @clip_rects = $ui->get_last_clip_rects;

For each command of L</get_last_commands>, in the same order, the
C<[x0, y0, x1, y1]> rectangle of cells it was allowed to paint into
(see L<Term::Fabulous::Render::Clip/clip_rect>). A command that lies
outside its rectangle, such as content scrolled out of a scroll
container, was not drawn. If painting the frame died, the list ends at
the command that failed.

=head2 pointer_state

	method pointer_state () { return { x => 12, y => 3, down => 0 } }

Required from the consuming class: C<undef> when there is no pointer,
or a hash reference with the pointer's cell C<x> and C<y> (from 0) and
whether the left button is held (C<down>, 0 or 1).

L</draw> gives Clay the center of that cell (C<x + 0.5>, C<y + 0.5>),
not its corner: Clay counts the right and bottom edge of a box as part
of the box, so the corner of a cell would also be "over" the widgets to
the left of and above it. As a consequence, the C<x> and C<y> of
Clay::UI's C<OnPress> and C<OnRelease> events are cell centers, such
as C<12.5>.

=head1 HOW COMMANDS ARE PAINTED

Clay positions boxes in fractional layout units. They are snapped to
whole cells (see L<Term::Fabulous::Render::Geometry/cell_rect>) and
clipped to the viewport (C<width> x C<height>) and to the innermost
open scissor (see L<Term::Fabulous::Render::Clip>). Nothing outside
these limits is painted. Colors are turned into termbox2 attributes as
described in L<Term::Fabulous::Render::Attr>; alpha 0 means "no color",
and only a background with an alpha from 1 to 254 is blended.

=over

=item Rectangles

A widget's background. Its cells are filled with spaces in the
background color. A translucent background is blended with what lies
below it, covering the glyphs there or letting them show through as the
widget's C<glyphs_show_through> says. See
L<Term::Fabulous::Render::Rectangle>.

=item Text

One line of a Text widget. It starts at the top-left cell of its box;
every grapheme cluster takes as many columns as termbox2 will use for
it. A cluster that would cross the right edge of the box or of the clip
area ends the line. The background of each cell is whatever was painted
there before. See L<Term::Fabulous::Render::Text>.

=item Canvases

The cells of a L<Term::Fabulous::Widget::Canvas>, painted into its
content box. Clay emits a canvas's background rectangle after the
canvas's own command; the renderer swaps the two, so the background is
painted first. See L<Term::Fabulous::Render::Canvas>.

=item Borders

The border of a widget composing L<Term::Fabulous::Role::HasBorderStyle>,
in its border styles. See L<Term::Fabulous::Render::Border>.

=item Scissors

Start and end of a clipping area, for example around the content of a
scroll container. See L<Term::Fabulous::Render::Clip>.

=back

=head1 CELL TARGET

The paint roles do not write to the terminal themselves. They compute a
glyph and two termbox2 attributes per cell and hand them to the
following methods, which the consuming class gets by composing a target
role:

=over

=item L<Term::Fabulous::Render::Target::Termbox>

Draws into the terminal through termbox2. Used by L<Term::Fabulous>.

=item L<Term::Fabulous::Render::Target::Grid>

Keeps the cells in memory. Used by L<Term::Fabulous::Static> and by
tests.

=back

Both build on L<Term::Fabulous::Render::Target::Mask>, which implements
the methods below on top of a few primitives; write your own target the
same way. All coordinates are cells, counted from 0 at the top-left, and
always lie inside the viewport and the open clip area: clipping happens
before a target method is called.

=head2 begin_frame

	$ui->begin_frame(@kept_rects);

Called once before the commands of a frame are painted. Resets every
cell outside the given C<[x0, y0, x1, y1]> rectangles (all cells when
none are given). The cells inside them must keep what the previous
frame painted there, and writes into them are ignored until the
rectangle is released with L</release_rect>.

=head2 end_frame

	$ui->end_frame;

Called once after all commands of a frame are painted. Releases all
kept rectangles and shows the frame.

=head2 release_rect

	$ui->release_rect($rect);

Stops protecting one of the rectangles given to L</begin_frame>
(identified by being the same array reference). The canvas that owns it
then paints its changed cells into it.

=head2 set_cell

	$ui->set_cell( $x, $y, $glyph, $fg, $bg );

Paints one cell: C<$glyph> is a character string with one character
(the base character of a grapheme cluster), C<$fg> and C<$bg> are
termbox2 attributes.

=head2 extend_cell

	$ui->extend_cell( $x, $y, $character );

Appends a combining character (a character string of length one) to the
cell set last at that position, to complete a grapheme cluster.

=head2 fill_row

	$ui->fill_row( $x, $y, $columns, $bg );

Paints C<$columns> cells of spaces with the background attribute C<$bg>,
starting at C<($x, $y)> and going right.

=head2 painted_cell

	my ( $glyph, $fg, $bg ) = $ui->painted_cell( $x, $y );

Reads back what the frame holds at a cell so far: the glyph (a
character string, the base character plus any combining characters),
its foreground and its background attribute. Returns an empty list when
nothing was painted there. The cell to the right of a wide glyph is
not written for it, so reading it gives what was painted there before
the glyph. Kept rectangles do not affect reading.

=head1 SEE ALSO

L<Term::Fabulous>, L<Term::Fabulous::Static>, L<Clay::UI>,
L<Term::Fabulous::Render::Target::Mask>, L<Term::Fabulous::Render::Attr>.

=cut
