# NAME

Term::Fabulous::Event::CanvasResize - A canvas got a new size

# SYNOPSIS

```perl
$canvas->on( CanvasResize => sub ($event) {
        $canvas->clear;
        $canvas->put_text( 0, 0, sprintf( '%d x %d cells', $event->columns, $event->rows ) );
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Canvas](../Widget/Canvas.md) (and every widget built on it, such
as [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md), the charts and the input
widgets) fires
`CanvasResize` on itself when the layout gives its content box a new
size. The canvas buffer has already been resized when the event fires,
and the frame that shows the new size is painted right after the
listeners return, so a listener is the right place to draw content that
depends on the size.

A `CanvasResize` event bubbles like other events (its bubble mode is
`IF_CONTINUE`): a listener on an ancestor, for example on the root,
also sees the resizes of every canvas, pixel canvas and input widget
below it, as long as the listeners on the way return
`Clay::UI::Enum::Result->CONTINUE` (the built-in widgets add no
`CanvasResize` listeners of their own, so they pass it on). Check
`$event->target` in such a listener:

```perl
$root->on( CanvasResize => sub ($event) {
        return Clay::UI::Enum::Result->CONTINUE unless $event->target == $chart;
        redraw_chart();
        return;
} );
```

The first event comes with the first frame that lays the canvas out:
before that, the buffer has 0 x 0 cells. Cells that still fit keep
their content; see ["Buffer size" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#buffer-size).

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'CanvasResize'` unless given to the
constructor) and `bubble_mode` (`IF_CONTINUE`) are available as well.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::CanvasResize->new( columns => 40, rows => 10 );
```

Built by the canvas itself; there is rarely a reason to build one. Both
parameters below are required, and unknown parameters die. The `name`
and `bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are
accepted as well.

- `columns`

    The new width of the canvas buffer in columns.

- `rows`

    The new height of the canvas buffer in rows.

# METHODS

## columns

```perl
my $width = $event->columns;
```

The new width of the canvas buffer in columns (the same as
`$canvas->columns`).

## rows

```perl
my $height = $event->rows;
```

The new height of the canvas buffer in rows (the same as
`$canvas->rows`).

# SEE ALSO

[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md), [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md),
["CANVASES" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#canvases),
["Plot data on a pixel canvas (PixelCanvas)" in Term::Fabulous::Cookbook::Canvases](../Cookbook/Canvases.md#plot-data-on-a-pixel-canvas-pixelcanvas).
