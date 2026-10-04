# NAME

Term::Fabulous::Event::MouseMove - The mouse pointer moved with no
button held

# SYNOPSIS

```perl
$canvas->on( MouseMove => sub ($event) {
        my ( $column, $row ) = $canvas->cell_at($event);
        $status->text("pointer over $column,$row");
        return;
} );
```

# DESCRIPTION

[Term::Fabulous](../../../../README.md) fires a `MouseMove` event every time the terminal
reports that the pointer moved while no mouse button was held, while
["run" in Term::Fabulous](../../../../README.md#run) is active and mouse input is enabled (the
`mouse` parameter of ["new" in Term::Fabulous](../../../../README.md#new), on by default except in
inline mode). Moves
with a button held are drags and fire `Mouse`
([Term::Fabulous::Event::Mouse](Mouse.md)) instead.

Like `Mouse`, the event is fired on the topmost widget that painted
the cell under the pointer in the last frame (see
["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse)), or on the root widget when there is
none, and then bubbles up to the ancestors. Term::Fabulous also records
the new pointer position before it fires the event, so the hover state
of the widgets (`OnHoverStart`, `OnHoverStopped`, `is_hovered`)
follows the pointer with the next frame.

Terminals report moves generously, often for every cell the pointer
crosses, so keep `MouseMove` listeners cheap.

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'MouseMove'` unless given to the
constructor) and `bubble_mode` (`IF_CONTINUE`) are available as well.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::MouseMove->new( x => 10, y => 3 );
```

Programs rarely build these events themselves; it is useful in tests.
Unknown parameters die. Besides the parameters below, the `name` and
`bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

- `x`

    Required. The column of the pointer, counted from 0 at the left edge of
    the terminal.

- `y`

    Required. The row of the pointer, counted from 0 at the top edge of the
    terminal.

- `modifiers`

    Optional. A bit mask of `TB_MOD_SHIFT`, `TB_MOD_ALT`, `TB_MOD_CTRL`
    and `TB_MOD_MOTION`. Default: `0`.

## of

```perl
my $event = Term::Fabulous::Event::MouseMove->of($termbox_event);
```

Builds an event from a `Term::Fabulous::Termbox::Event`: `x`, `y`
and `modifiers` from its `x`, `y` and `mod`. Called by
[Term::Fabulous](../../../../README.md); class method.

# METHODS

## x

```perl
my $column = $event->x;
```

The column of the cell under the pointer, from 0 at the left edge of
the terminal. To get a position inside a canvas, use
["cell\_at" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#cell_at) or
["pixel\_at" in Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md#pixel_at); both accept this event.

## y

```perl
my $row = $event->y;
```

The row of the cell under the pointer, from 0 at the top edge of the
terminal.

## modifiers

```perl
my $with_shift = $event->modifiers & TB_MOD_SHIFT;
```

A bit mask of the modifier keys held while the pointer moved:
`TB_MOD_SHIFT`, `TB_MOD_ALT`, `TB_MOD_CTRL` from
[Term::Fabulous::Termbox](../Termbox.md). `TB_MOD_MOTION` is always set for an
event [Term::Fabulous](../../../../README.md) fires, since the pointer moved.

# SEE ALSO

["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse), [Term::Fabulous::Event::Mouse](Mouse.md),
[Term::Fabulous](../../../../README.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).
