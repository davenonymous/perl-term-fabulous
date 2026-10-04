# NAME

Term::Fabulous::Cookbook::Canvases - Recipes: draw on a canvas

# DESCRIPTION

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::ChartStyles](ChartStyles.md). Next page: [Term::Fabulous::Cookbook::Output](Output.md).

This page shows how to draw freely, without a chart widget: on a
[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md), which holds a character in every
cell, with the mouse, and on a [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md),
which has two pixels per cell, from data. Canvases, their size and the
`CanvasResize` event are explained in
[the canvases chapter of the manual](../Manual/Charts.md#canvases); the mouse events in
[the mouse section of the events chapter](../Manual/Events.md#mouse). For charts that draw
themselves from data, see [Term::Fabulous::Cookbook::Charts](Charts.md).

The recipes on this page:

- ["Paint with the mouse (Canvas, clicks and drags)"](#paint-with-the-mouse-canvas-clicks-and-drags)
- ["Plot data on a pixel canvas (PixelCanvas)"](#plot-data-on-a-pixel-canvas-pixelcanvas)

# Paint with the mouse (Canvas, clicks and drags)

Goal: let the user draw on a canvas by clicking and dragging.

This program is shipped as `examples/cookbook/paint-with-the-mouse.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Canvas;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RIGHT TB_MOD_MOTION);
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $root = Term::Fabulous::Widget::Box->new(
        background_color => [ 20, 25, 35, 255 ],
        layout           => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_grow() },
                padding          => { left => 2, right => 2, top => 1, bottom => 1 },
                child_gap        => 1,
        },
);
my $help = Term::Fabulous::Widget::Text->new( text => 'Left button draws, right button erases. Drag to draw lines.', text_color => [ 230, 230, 230, 255 ] );
my $canvas = Term::Fabulous::Widget::Canvas->new(
        background_color => [ 10, 12, 20, 255 ],
        border_width     => 1,
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
        border_color     => [ 120, 160, 220, 255 ],
        layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);
$root->add_child( $help, $canvas );

$canvas->on(
        Mouse => sub ($event) {
                my $key = $event->key;
                return unless $key == TB_KEY_MOUSE_LEFT || $key == TB_KEY_MOUSE_RIGHT;

                # cell_at turns the pointer position into a cell of the canvas, or
                # the empty list when the pointer is on the border.
                my ( $x, $y ) = $canvas->cell_at($event) or return;
                my $dragging = $event->modifiers & TB_MOD_MOTION;

                if ( $key == TB_KEY_MOUSE_RIGHT ) {
                        $canvas->erase( $x, $y );
                }
                else {
                        $canvas->put( $x, $y, $dragging ? '*' : 'o', $dragging ? 0xFFC832 : 0x50DC64 );
                }
                return;
        }
);

Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-paint-with-the-mouse.svg" alt="A wave of stars drawn by dragging the mouse over a canvas, with an o where the drag started and at three clicked cells"></p>
</div>

- The [Term::Fabulous::Event::Mouse](../Event/Mouse.md) event is fired on the topmost
widget under the pointer that painted something there, here the
canvas. `key` says what happened: `TB_KEY_MOUSE_LEFT`,
`TB_KEY_MOUSE_RIGHT`, `TB_KEY_MOUSE_MIDDLE`, `TB_KEY_MOUSE_RELEASE`,
`TB_KEY_MOUSE_WHEEL_UP`, `TB_KEY_MOUSE_WHEEL_DOWN`,
`TF_KEY_MOUSE_WHEEL_LEFT` or `TF_KEY_MOUSE_WHEEL_RIGHT` (constants of
[Term::Fabulous::Termbox](../Termbox.md)).
- While a button is held and the mouse moves, the terminal repeats the
button's key with `TB_MOD_MOTION` set in `modifiers`; that is how a
drag is recognized.
- `$canvas->cell_at($event)` converts the event's terminal position
into a cell of the canvas. It returns the empty list when the pointer
is outside the drawing area, for example on the border, hence
`or return`. See ["cell\_at" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#cell_at).
- For pixels instead of cells, use a [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md)
and its `pixel_at`; `examples/pixel-paint.pl` is a complete paint
program with a color palette.

# Plot data on a pixel canvas (PixelCanvas)

Goal: draw a line chart of a series of numbers, filling whatever room
the terminal gives.

This program is shipped as `examples/cookbook/pixel-canvas-plot.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::PixelCanvas;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

# Some data: one value per pixel column is plotted, so any number of
# points works.
my @temperatures = map { 12 + 8 * sin( $_ / 9 ) + 3 * sin( $_ / 2.3 ) } 0 .. 199;

my $root = Term::Fabulous::Widget::Box->new(
        background_color => [ 20, 25, 35, 255 ],
        layout           => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_grow() },
                padding          => { left => 2, right => 2, top => 1, bottom => 1 },
                child_gap        => 1,
        },
);
$root->add_child( Term::Fabulous::Widget::Text->new( text => 'Temperature over 200 hours', text_color => [ 230, 230, 230, 255 ] ) );

my $plot = Term::Fabulous::Widget::PixelCanvas->new(
        background_color => [ 10, 12, 20, 255 ],
        border_width     => 1,
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
        border_color     => [ 120, 160, 220, 255 ],
        layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);
$root->add_child($plot);

# The pixel size is known only once the layout has sized the canvas, and
# it changes with the terminal: draw whenever it is (re)sized.
$plot->on(
        CanvasResize => sub ($event) {
                my ( $width, $height ) = ( $plot->pixel_width, $plot->pixel_height );
                return if $width < 2 || $height < 2;
                my ( $low, $high ) = ( -5, 30 );
                my $y_of = sub ($value) { ( $height - 1 ) * ( $high - $value ) / ( $high - $low ) };

                $plot->clear;
                $plot->draw_line( 0, $y_of->(0), $width - 1, $y_of->(0), 0x404860 );    # the zero line

                my $previous;
                foreach my $x ( 0 .. $width - 1 ) {
                        my $value = $temperatures[ int( $x * @temperatures / $width ) ];
                        my @point = ( $x, $y_of->($value) );
                        $plot->draw_line( @$previous, @point, $value > 20 ? '#ff6e6e' : '#6ec8ff' ) if $previous;
                        $previous = \@point;
                }
                $plot->put_text( 1, 0, "$high C", 0x9098B0 );
                $plot->put_text( 1, $plot->rows - 1, "$low C", 0x9098B0 );
                return;
        }
);

Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-pixel-canvas-plot.svg" alt="A line chart of temperatures on a pixel canvas, red above 20 degrees"></p>
</div>

- A [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md) has two pixels per cell, one
above the other, so a 70 x 20 cell canvas is 70 x 40 pixels. Its size
comes from the layout and is known only after the first layout; the
`CanvasResize` event is fired whenever it changes, before the frame is
drawn. Draw in its listener. See ["The canvas size" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#the-canvas-size).
- `draw_line`, `draw_rect`, `fill_rect`, `draw_circle` and
`set_pixel` take pixel coordinates from the top-left corner. Fractions
are rounded down, so computed coordinates can be passed directly.
Pixels outside the canvas are dropped.
- Colors on a canvas may be packed integers (`0x404860`), color strings
(`'#ff6e6e'`), arrays or [Term::Fabulous::Color](../Color.md) objects.
- `put_text` writes text over the image in cells (character strings,
not bytes). A cell with text shows no pixels.
- To draw characters instead of pixels, use
[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md) and its `put`, `put_text` and
`fill`; `examples/canvas.pl` animates a plot with a timer and redraws
only the cells that changed.

# SEE ALSO

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::ChartStyles](ChartStyles.md). Next page: [Term::Fabulous::Cookbook::Output](Output.md).
