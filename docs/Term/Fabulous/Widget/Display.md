# NAME

Term::Fabulous::Widget::Display - Common base class of the widgets that
paint themselves from their own state

# SYNOPSIS

```perl
use Object::Pad 0.825;
use Term::Fabulous::Widget::Display;

class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
        field $fraction :param = 0;

        method fraction (@new) {
                return $fraction unless @new;
                $fraction = $new[0];
                $self->mark_changed;    # the next frame paints it
                return $fraction;
        }

        method natural_size () { return ( 20, 1 ) }    # columns, rows

        method paint () {
                my $filled = int( $self->columns * $fraction + 0.5 );
                $self->fill_attrs( 0,       0, $filled,                  "\x{2588}", $self->color_attr('#61afef'), undef );
                $self->fill_attrs( $filled, 0, $self->columns - $filled, "\x{2591}", $self->color_attr('#3a3f4b'), undef );
                return;
        }
}

my $gauge = My::Gauge->new( fraction => 0.25 );
$gauge->fraction(0.5);    # from a timer, a listener, ...
```

# DESCRIPTION

`Term::Fabulous::Widget::Display` is the abstract base class of the
widgets that are drawn from their own state whenever a frame needs
them, and of the input widgets, which add the focus, the mouse and the
keyboard to it ([Term::Fabulous::Widget::Input](Input.md)):

- [Term::Fabulous::Widget::Divider](Divider.md) - a line between widgets, with an
optional text
- [Term::Fabulous::Widget::ProgressBar](ProgressBar.md) - how much of a task is done
- [Term::Fabulous::Widget::Spinner](Spinner.md) - that something is going on
- [Term::Fabulous::Widget::Chart](Chart.md) and the charts built on it - data as
lines, bars, slices and more
- [Term::Fabulous::Widget::Scrollbar](Scrollbar.md) - how far a scroll container is
scrolled

You do not create a `Display` directly (the class is abstract and
`new` dies); this page describes what these widgets have in common and
how to write one of your own. Every such widget is a
[Term::Fabulous::Widget::Canvas](Canvas.md), so it takes the parameters of a Box
(`id`, `layout`, `background_color`, the border parameters, ...) and
can be built from a KDL layout file.

## Painting

A widget of this class never paints in its setters: they record the
new value and call `mark_changed`
(["mark\_changed" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#mark_changed)), so a frame becomes
due. When the frame is drawn, the renderer calls the widget's
`refresh` (["refresh" in Term::Fabulous::Widget::Canvas](Canvas.md#refresh)), which compares
the widget's _paint key_ (see ["paint\_key"](#paint_key)) with the one it last
painted for: the size of its buffer, how often it was marked changed,
and what a subclass adds. Only when the key differs does it clear the
buffer and call ["paint"](#paint). So the cells always show the state of the
frame they are drawn in, also when the state was changed by a timer or
another widget, and a frame that changes nothing about the widget
paints nothing of it. Anything you draw into such a widget with the
canvas methods (`put`, `put_text`, ...) is lost the next time it
paints.

## Size

Every widget of this class has a natural content size, for example one
row and as many columns as its text needs. When the `layout` gives no
`sizing` for an axis, the widget is given its natural size on that
axis: a fixed size of the natural cells plus the padding and border
width, or the sizing the widget asks for (a
[Term::Fabulous::Widget::Divider](Divider.md) grows along its line). A `sizing` in
the `layout` always wins:

```perl
# 20 columns wide, one row high:
Term::Fabulous::Widget::ProgressBar->new;

# As wide as the parent allows, still one row high:
Term::Fabulous::Widget::ProgressBar->new( layout => { sizing => { width => sizing_grow() } } );
```

A fixed natural size takes no part in a `width_group` or
`height_group` (["new" in Term::Fabulous::Widget](../Widget.md#new)), which line up `fit`
and `grow` sizings only; give the widget a `fit` sizing with its
natural size as the minimum to line it up with others.

# ANIMATION

A widget that moves by itself, such as a [Term::Fabulous::Widget::Spinner](Spinner.md)
or an indeterminate [Term::Fabulous::Widget::ProgressBar](ProgressBar.md), needs no
timer: it reads the time from the application's clock (["now"](#now)) and
asks for a frame when its next frame is due
(["request\_frame\_at"](#request_frame_at)). [Term::Fabulous](../../../../README.md) draws that frame at the first
tick of its frame timer at or after the time, the widget's `paint_key`
then differs, and it paints the next frame and asks again. Nothing is
drawn in between, and the widget stops asking as soon as it stops
animating.

Because the time comes from the clock of ["new" in Term::Fabulous](../../../../README.md#new), a test
can move an animation on with a clock of its own, and the screenshot
tools run it on a virtual clock. In a [Term::Fabulous::Static](../Static.md) page the
widget shows the frame of the moment it is rendered.

The helper ["animation\_frame"](#animation_frame) does the arithmetic:

```perl
method paint_key :override () {
        return ( $self->SUPER::paint_key, $running ? $self->animation_frame( 0.1, scalar @frames ) : -1 );
}

method paint () {
        my $frame = $running ? $self->animation_frame( 0.1, scalar @frames ) : 0;
        $self->paint_text( 0, 0, $frames[$frame], $self->color_attr($color), undef );
        return;
}
```

# METHODS

The methods of [Term::Fabulous::Widget::Canvas](Canvas.md) and
[Term::Fabulous::Widget](../Widget.md), plus:

## mark\_changed

```perl
$widget->mark_changed;
```

Marks the widget changed: a frame becomes due, and that frame paints the
widget again from its current state and sizes it again. The setters
call it, so you only need it after changing state behind the widget's
back. Returns the widget.

# SUBCLASS INTERFACE

To write a widget that paints itself, subclass
`Term::Fabulous::Widget::Display` with [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) (see the
["SYNOPSIS"](#synopsis)); for a widget the user edits, subclass
[Term::Fabulous::Widget::Input](Input.md) instead, which adds the focus, the
keys and the mouse. You must implement `natural_size` and `paint`.
Paint with `put_attrs` (["put\_attrs" in Term::Fabulous::Widget::Canvas](Canvas.md#put_attrs))
and the helpers below, which take termbox2 attributes (the integers
`color_attr` returns) instead of colors.

Term::Fabulous draws a frame only when something changed, and the frame
paints the widget (see ["Painting"](#painting)). Whenever your widget changes
state that `paint` or `natural_size` uses, call
`$self->mark_changed` and do not paint: the next frame calls
`paint`. When `paint` also reads state of other objects that change
without telling your widget, add that state to ["paint\_key"](#paint_key). Without
either, the change shows only when something else makes the widget
paint.

## natural\_size

```perl
method natural_size () { return ( $columns, $rows ) }
method natural_size () { return ( sizing_grow(), 1 ) }
```

Required. The content size the widget wants when the layout does not
size it (see ["Size"](#size)): for each axis a number of cells, or a sizing
hash from [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) (`sizing_grow`, `sizing_fit`, ...) whose
limits are the content's; the padding and border are added to them.
Called for every frame.

## paint

```perl
method paint () { ... }
```

Required. Draws the widget into its buffer. It is called while a frame
is drawn, when the ["paint\_key"](#paint_key) changed, with a cleared buffer that
has at least one cell; use `$self->columns` and `$self->rows`
for its size. Cell writes made here belong to the frame being drawn and
make no further frame due.

## paint\_key

```perl
method paint_key :override () {
        return ( $self->SUPER::paint_key, $self->frame_index );
}
```

The list of values ["paint"](#paint) depends on; the widget paints again when
any of them changed since it last painted. The default holds the size
of the buffer and a count of the widget's `mark_changed` calls. Extend
it with what `paint` reads from other objects, which do not mark this
widget changed. The values are compared as strings; keep them cheap to
compute, since the key is computed for every frame.

## color\_attr

```perl
my $attr = $self->color_attr('#ff0000');
```

The termbox2 attribute of any color the canvas accepts, `undef` for
`undef` or a color with alpha 0 (no color of its own).

## paint\_text

```perl
my $next_x = $self->paint_text( $x, $y, $text, $fg, $bg, $limit );
```

Paints a character string from cell (`$x`, `$y`) with the attributes
`$fg` and `$bg` (either may be `undef`). `$limit` defaults to
`$self->columns`; a grapheme cluster that would reach past it ends
the text. Returns the column after the last cluster painted.

## fill\_attrs

```perl
$self->fill_attrs( $x, $y, $width, $glyph, $fg, $bg );
```

Puts a one-column glyph into `$width` cells of row `$y`, starting at
`$x`.

## now

```perl
my $seconds = $self->now;
```

The current time in seconds: ["now" in Term::Fabulous](../../../../README.md#now) when the widget is
part of a [Term::Fabulous](../../../../README.md), otherwise `Time::HiRes::time`.

## request\_frame\_at

```perl
$self->request_frame_at( $self->now + 0.25 );
```

Asks the widget's [Term::Fabulous](../../../../README.md) for a frame at a time on the clock
(see ["request\_frame\_at" in Term::Fabulous](../../../../README.md#request_frame_at)); does nothing when the widget
is not part of one, or part of a [Term::Fabulous::Static](../Static.md). Returns
the widget.

## animation\_frame

```perl
my $index = $self->animation_frame( $interval, $count );
```

The frame, from 0 to `$count - 1`, of an animation whose frames last
`$interval` seconds each, at the current time, counted from the
start of the clock so that every widget with the same interval moves
in step. Also asks for a frame when the next one is due, so call it
from ["paint\_key"](#paint_key) only while the widget animates (see ["ANIMATION"](#animation)).

# SEE ALSO

[Term::Fabulous::Widget::Canvas](Canvas.md), [Term::Fabulous::Widget::Input](Input.md),
["A widget that draws itself" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#a-widget-that-draws-itself).
