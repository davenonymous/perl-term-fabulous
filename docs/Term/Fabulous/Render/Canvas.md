# NAME

Term::Fabulous::Render::Canvas - Paint canvas widgets, only their
changed cells when possible

# SYNOPSIS

```perl
# What Term::Fabulous::Render::draw does with canvases:
my @kept_rects = $ui->plan_canvases($frame);         # before begin_frame
$ui->cell_target->begin_frame(@kept_rects);
$ui->render_custom( $command, $canvas, $buffer );     # for each canvas command
$ui->cell_target->end_frame;
$ui->finish_canvases;                                 # after a complete frame
```

# DESCRIPTION

Most programs never use this module directly, and neither do widgets
of your own: a widget built on [Term::Fabulous::Widget::Canvas](../Widget/Canvas.md) is
painted by this role without any help (see
["A widget that draws itself" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#a-widget-that-draws-itself)).
Read it if you write your own UI class or want to know when a canvas is
repainted. It is one of the roles [Term::Fabulous::Render](../Render.md) is made of,
and it paints
[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md) widgets (and everything built on them:
[Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md) and the input widgets).

A canvas asks Clay for a _custom_ render command. This role paints the
canvas's cell buffer into the canvas's content box (its box without
border and padding), clipped like every other command.

## Painting only the changes

Repainting a large canvas every frame is wasteful when only a few of
its cells changed. Since termbox2 keeps the cells of the previous frame
in its back buffer, a canvas can often leave them there and paint only
the cells that changed. This is safe when all of the following hold:

- the canvas has the same position, the same visible part and the same
background as in the last frame that was painted completely;
- no command painted after the canvas (a border, a child widget, a
floating widget such as an open dropdown list) touches its visible part,
neither in this frame nor in that previous frame;
- the viewport has the same size.

Such a canvas is called _intact_. Its visible rectangle is handed to
the target's `begin_frame` as a _kept_ rectangle, which protects it
from the background painted below it; then the canvas releases the
rectangle and paints only its changed cells. Every other canvas paints
all of its visible cells.

# METHODS

## plan\_canvases

```perl
my @kept_rects = $ui->plan_canvases($frame);
```

Called before a frame is painted, with the frame's
[Term::Fabulous::Render::Frame](Frame.md). For every canvas command it:

- records where the canvas's content box starts
(["content\_origin" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#content_origin)) and resizes the
canvas buffer to the content box, which fires
[Term::Fabulous::Event::CanvasResize](../Event/CanvasResize.md) when the size changed;
- lets the canvas bring its cells up to date
(["refresh" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#refresh)): input widgets paint
themselves here;
- decides whether the canvas is intact (see ["Painting only the changes"](#painting-only-the-changes)).

Returns the visible rectangles (`[x0, y0, x1, y1]`) of the intact
canvases, for the target's `begin_frame`. Canvases that are not visible
at all are skipped and keep their pending changes. Dies with
`Term::Fabulous::Render::Canvas: a custom render command needs a Term::Fabulous::Widget::Canvas`
when a custom command belongs to another kind of widget.

## render\_custom

```perl
$ui->render_custom( $command, $canvas, $buffer );
```

The render command handler for canvases. An intact canvas releases its
kept rectangle and paints the cells that changed since it was last
painted; any other canvas paints all of its visible cells. Unset cells,
and cells without a background color, are painted as the canvas
background: the `background_color` of the canvas, or of its nearest
ancestor that has one, or else the screen background of the frame
(["SCREEN BACKGROUND" in Term::Fabulous::Render](../Render.md#screen-background)). A translucent
background color is used opaque here; only the widget's own background
rectangle, painted before the cells, is blended. A wide glyph that
would cross the visible right edge is painted as spaces. Every painted
cell records its background in `$buffer`, so text drawn over the canvas
later in the frame keeps it.

## finish\_canvases

```perl
$ui->finish_canvases;
```

Called after a frame was painted completely: remembers it as the frame
the next ["plan\_canvases"](#plan_canvases) compares with. A frame that died before this
call is never remembered, so the next frame paints every canvas in full.

## invalidate\_canvases

```perl
$ui->invalidate_canvases;
```

Forgets the previous frame, so that the next frame paints every canvas
in full. Call it whenever the target lost its cells. [Term::Fabulous](../../../../README.md)
calls it when it opens the terminal, because `tb_init` starts with an
empty back buffer.

# REQUIRED METHODS

The consuming class provides `widget_for` (from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI)) and
`cell_target`, which returns the cell target the canvases are painted
into (its `set_cell`, `extend_cell` and `release_rect` are called;
see ["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target)).

# SEE ALSO

[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md), [Term::Fabulous::Render](../Render.md),
[Term::Fabulous::Render::Frame](Frame.md), [Term::Fabulous::Render::Target::Mask](Target/Mask.md).
