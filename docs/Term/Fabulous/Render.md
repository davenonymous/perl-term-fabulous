# NAME

Term::Fabulous::Render - Role that paints Clay render commands into
terminal cells

# SYNOPSIS

```perl
use Object::Pad 0.825;
use Clay::UI;
use Term::Fabulous::Render;
use Term::Fabulous::Render::Target::Grid;

# A UI class that paints into memory and never sees a pointer.
class My::Snapshot :isa(Clay::UI) :does(Term::Fabulous::Render) {
        field $cell_target :reader = Term::Fabulous::Render::Target::Grid->new;

        method pointer_state () { return undef }
}

my $ui = My::Snapshot->new( root => $root, width => 10, height => 2 );
$ui->draw;
my ( $glyph, $fg, $bg ) = @{ $ui->cell_target->cell( 0, 0 ) };
```

# DESCRIPTION

Most programs never use this module directly. [Term::Fabulous](../../../README.md) (for
the terminal) and [Term::Fabulous::Static](Static.md) (for text output) already
compose it. Read on if you want to write your own UI class, for example
one that paints into a different kind of output, or want to know
exactly how a frame is painted. To write a widget of your own you do not
need this module: build it on the existing widgets as
[Term::Fabulous::Manual::CustomWidgets](Manual/CustomWidgets.md) explains (a widget that draws
itself is a [Term::Fabulous::Widget::Canvas](Widget/Canvas.md)).

Term::Fabulous::Render is an [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) role for a subclass of
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI). It turns a laid-out widget tree into terminal cells:
["draw"](#draw) asks Clay::UI for the frame's render commands (rectangles,
borders, text, clipping and canvases) and paints each of them, cell by
cell. Where the cells go is decided by an object the class provides,
the _cell target_ (see ["CELL TARGET"](#cell-target)).

The role is composed of smaller roles, one per kind of render command:
[Term::Fabulous::Render::Rectangle](Render/Rectangle.md), [Term::Fabulous::Render::Border](Render/Border.md),
[Term::Fabulous::Render::Text](Render/Text.md) and [Term::Fabulous::Render::Canvas](Render/Canvas.md).
What a frame paints where is worked out once per frame, before any
painting, by [Term::Fabulous::Render::Frame](Render/Frame.md).

When it is constructed, the role checks `output_mode` and installs its
own measure-text callback in Clay::UI (`measure_text`), which reports
text widths in terminal columns (see [Term::Fabulous::Unicode](Unicode.md)). The
constructors of [Term::Fabulous](../../../README.md) and [Term::Fabulous::Static](Static.md) die
when given a `measure_text` of their own.

# REQUIREMENTS OF THE CONSUMING CLASS

The class that composes this role must provide:

- the methods of [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI): `render`, `widget_for`, `measure_text`, `width` and `height` (subclass Clay::UI);
- `pointer_state` (see ["pointer\_state"](#pointer_state));
- `cell_target`, which returns the object the frames are painted into (see ["CELL TARGET"](#cell-target)).

# CONSTRUCTOR PARAMETERS

- `output_mode`

    The termbox2 output mode. It must be `TB_OUTPUT_TRUECOLOR` (from
    [Term::Fabulous::Termbox](Termbox.md)), which is also the default, because Term::Fabulous always
    paints 24-bit colors. Any other value dies with
    `Term::Fabulous::Render: output_mode must be TB_OUTPUT_TRUECOLOR`.
    There is no reason to pass it.

- `theme`

    The [Term::Fabulous::Theme](Theme.md) the widgets draw with: a theme object or
    the name of a built-in theme (`dark`, `light`). Default: `dark`.
    See ["theme"](#theme).

# METHODS

## theme

```perl
my $theme = $ui->theme;
$ui->theme('light');
$ui->theme( Term::Fabulous::Theme->from_file('ocean.kdl') );
```

Accessor for the theme. Without an argument it returns the
[Term::Fabulous::Theme](Theme.md) object; with one it sets the theme (an object
or a built-in name; anything else dies), makes every widget read its
looks again, calls `theme_changed` on every widget of the tree that
has such a method (see ["theme\_changed" in Term::Fabulous::Role::Themed](Role/Themed.md#theme_changed))
and draws a frame. Widgets that were given a color or a border style
explicitly keep it; see ["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes).

## draw

```perl
$ui->draw;
$ui->draw( scroll_cells => [ $columns, $rows ] );
```

Lays out and paints one frame:

1. Calls Clay::UI's `render`, passing the pointer from ["pointer\_state"](#pointer_state)
(when it is defined) and the scroll amount. Clay::UI fires its pointer
events (hover, press, scroll) during this call.
2. Builds the [Term::Fabulous::Render::Frame](Render/Frame.md) of the commands: their
paint order, the clip rect of each and the cells each paints.
["last\_frame"](#last_frame) returns it from now on.
3. Sizes every canvas to its new content box and decides which canvases
can keep the cells of the previous frame
(["plan\_canvases" in Term::Fabulous::Render::Canvas](Render/Canvas.md#plan_canvases)). Canvases fire
`CanvasResize` here.
4. Calls the cell target's `begin_frame`, paints every render command in
paint order and calls `end_frame`.
5. Calls ["finish\_canvases" in Term::Fabulous::Render::Canvas](Render/Canvas.md#finish_canvases), which
remembers this completely painted frame for the comparison in step 3 of
the next frame. If painting died, this step is skipped and the next
frame paints every canvas in full.
6. Calls the code references queued with ["after\_draw"](#after_draw), in the order
they were queued. If painting died, they stay queued for the next
frame.

`scroll_cells` scrolls the scroll container under the pointer (see
[Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md)) by `[$columns, $rows]` cells
before the layout is computed. Positive values reveal content
above and to the left (the content moves down and right on screen), as
turning a mouse wheel up does; negative values reveal content below and
to the right. Clay keeps
the result within the content. [Term::Fabulous](../../../README.md) passes the wheel
notches since the last frame here.

Any other argument dies. Render command types other than rectangle,
border, text, scissor (clipping) and custom (canvas) die (see
["new" in Term::Fabulous::Render::Frame](Render/Frame.md#new)); Term::Fabulous widgets produce
only these. With the termbox2 cell target, the terminal must have been
opened (["run" in Term::Fabulous](../../../README.md#run) and ["step" in Term::Fabulous](../../../README.md#step) do that);
otherwise termbox2 ignores the drawing.

## after\_draw

```perl
$ui->after_draw( sub {
        my $box = $ui->bounding_box($row) // return;
        ...;    # the geometry of the frame just drawn
} );
```

Queues a code reference that ["draw"](#draw) calls once, with no arguments,
after the next frame has been painted completely. Use it for work that
needs the layout of a frame that has not been drawn yet, for example to
scroll a row into view that was only just added: Clay::UI's
`bounding_box` and `scroll_state` then answer for that frame. A
change the callback makes (a scroll position, a widget property) shows
in the frame after it, which is due at once. A callback may queue
another one; it runs after the following frame. Anything but a code
reference dies. Returns the UI object. An exception from a callback
leaves `draw` with it; the callbacks queued after it are dropped.

## last\_frame

```perl
my $frame = $ui->last_frame;
my @indices = $frame->topmost_at( $x, $y );
```

The [Term::Fabulous::Render::Frame](Render/Frame.md) of the last ["draw"](#draw): its render
commands in paint order, the clip rect of each and the cells each
painted. [Term::Fabulous](../../../README.md) hit-tests every mouse report with it. Before
the first frame, an empty Frame of the current size. The Frame is
complete even when painting the frame died partway, so it always
describes one whole layout. Use
`$ui->widget_for( $command->{userData} )` to get the widget a
command belongs to.

## clip\_rect

```perl
my ( $x0, $y0, $x1, $y1 ) = @{ $ui->clip_rect };
```

The rectangle of cells the render command being painted may touch, as
a new array reference (see ["clip\_rect" in Term::Fabulous::Render::Frame](Render/Frame.md#clip_rect)).
The paint roles call it from their render command handlers; it dies
when no command is being painted
(`Term::Fabulous::Render: clip_rect is only known while a render command is painted`).

## pointer\_state

```perl
method pointer_state () { return { x => 12, y => 3, down => 0 } }
```

Required from the consuming class: `undef` when there is no pointer,
or a hash reference with the pointer's cell `x` and `y` (from 0) and
whether the left button is held (`down`, 0 or 1).

["draw"](#draw) gives Clay the center of that cell (`x + 0.5`, `y + 0.5`),
not its corner: Clay counts the right and bottom edge of a box as part
of the box, so the corner of a cell would also be "over" the widgets to
the left of and above it. As a consequence, the `x` and `y` of
Clay::UI's `OnPress` and `OnRelease` events are cell centers, such
as `12.5`.

# HOW COMMANDS ARE PAINTED

Clay positions boxes in fractional layout units. They are snapped to
whole cells (see ["cell\_rect" in Term::Fabulous::Render::Geometry](Render/Geometry.md#cell_rect)) and
clipped to the viewport (`width` x `height`) and to the innermost
scissor around the command (see [Term::Fabulous::Render::Frame](Render/Frame.md)). Nothing outside
these limits is painted. Colors are turned into termbox2 attributes as
described in [Term::Fabulous::Render::Attr](Render/Attr.md); alpha 0 means "no color",
and only a background with an alpha from 1 to 254 is blended.

- Rectangles

    A widget's background. Its cells are filled with spaces in the
    background color. A translucent background is blended with what lies
    below it, covering the glyphs there or letting them show through as the
    widget's `glyphs_show_through` says. A widget whose `reverse_video`
    is true (a pressed [Term::Fabulous::Widget::Button](Widget/Button.md)) adds reverse
    video to its background, so everything painted on it later swaps its
    colors. See
    [Term::Fabulous::Render::Rectangle](Render/Rectangle.md).

- Text

    One line of a Text widget, in its text color plus its bold, italic and
    underline style bits. It starts at the top-left cell of its box;
    every grapheme cluster takes as many columns as termbox2 will use for
    it. A cluster that would cross the right edge of the box or of the clip
    area ends the line. The background of each cell is whatever was painted
    there before. See [Term::Fabulous::Render::Text](Render/Text.md).

- Canvases

    The cells of a [Term::Fabulous::Widget::Canvas](Widget/Canvas.md), painted into its
    content box. Clay carries a canvas's background in the canvas's own
    command; the frame paints it as a rectangle before the canvas, so the
    background lies below the cells. See [Term::Fabulous::Render::Canvas](Render/Canvas.md).

- Borders

    The border of a widget composing [Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md),
    in its border styles. See [Term::Fabulous::Render::Border](Render/Border.md).

- Scissors

    Start and end of a clipping area, for example around the content of a
    scroll container. They paint nothing themselves; the Frame turns them
    into the clip rects of the commands between them. See
    [Term::Fabulous::Render::Frame](Render/Frame.md).

# CELL TARGET

```perl
method cell_target () { return $grid }
```

The paint roles do not write to the terminal themselves. They compute a
glyph and two termbox2 attributes per cell and hand them to the _cell
target_, the object the consuming class returns from `cell_target`.
The renderer asks for it once per render command, so `cell_target`
should return a stored object, not build one. The distribution has two:

- [Term::Fabulous::Terminal::Termbox::Cells](Terminal/Termbox/Cells.md)

    Draws into the terminal through termbox2. [Term::Fabulous](../../../README.md) paints into
    the cell target of its terminal
    (["cell\_target" in Term::Fabulous::Role::Terminal](Role/Terminal.md#cell_target)), which is this one for
    the real terminal.

- [Term::Fabulous::Render::Target::Grid](Render/Target/Grid.md)

    Keeps the cells in memory. Used by [Term::Fabulous::Static](Static.md) and by
    [Term::Fabulous::Terminal::Memory](Terminal/Memory.md).

Both compose [Term::Fabulous::Render::Target::Mask](Render/Target/Mask.md), which implements
all methods below except `painted_cell` on top of a few primitives;
write your own target the same way, and give it a `painted_cell` of its
own. All coordinates are cells, counted from 0 at the top-left, and
always lie inside the viewport and the clip rect of the command:
clipping happens before a target method is called.

## begin\_frame

```perl
$target->begin_frame(@kept_rects);
```

Called once before the commands of a frame are painted. Resets every
cell outside the given `[x0, y0, x1, y1]` rectangles (all cells when
none are given). The cells inside them must keep what the previous
frame painted there, and writes into them are ignored until the
rectangle is released with ["release\_rect"](#release_rect).

## end\_frame

```perl
$target->end_frame;
```

Called once after all commands of a frame are painted. Releases all
kept rectangles and shows the frame.

## release\_rect

```perl
$target->release_rect($rect);
```

Stops protecting one of the rectangles given to ["begin\_frame"](#begin_frame)
(identified by being the same array reference). The canvas that owns it
then paints its changed cells into it.

## set\_cell

```perl
$target->set_cell( $x, $y, $glyph, $fg, $bg );
```

Paints one cell: `$glyph` is a character string with one character
(the base character of a grapheme cluster), `$fg` and `$bg` are
termbox2 attributes.

## extend\_cell

```perl
$target->extend_cell( $x, $y, $character );
```

Appends a combining character (a character string of length one) to the
cell set last at that position, to complete a grapheme cluster.

## fill\_row

```perl
$target->fill_row( $x, $y, $columns, $bg );
```

Paints `$columns` cells of spaces with the background attribute `$bg`,
starting at `($x, $y)` and going right.

## painted\_cell

```perl
my ( $glyph, $fg, $bg ) = $target->painted_cell( $x, $y );
```

Not part of [Term::Fabulous::Render::Target::Mask](Render/Target/Mask.md): every target
provides it itself. [Term::Fabulous::Render::Rectangle](Render/Rectangle.md) calls it to
repaint the glyphs below a translucent background. Reads back what the frame holds at a cell so far: the glyph (a
character string, the base character plus any combining characters),
its foreground and its background attribute. Returns an empty list when
nothing was painted there. The cell to the right of a wide glyph is
not written for it, so reading it gives what was painted there before
the glyph. Kept rectangles do not affect reading.

# SEE ALSO

[Term::Fabulous](../../../README.md), [Term::Fabulous::Static](Static.md), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI),
[Term::Fabulous::Render::Frame](Render/Frame.md), [Term::Fabulous::Render::Target::Mask](Render/Target/Mask.md),
[Term::Fabulous::Render::Attr](Render/Attr.md).
