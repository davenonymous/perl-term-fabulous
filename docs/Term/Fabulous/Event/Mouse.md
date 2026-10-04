# NAME

Term::Fabulous::Event::Mouse - A mouse click, release, drag or wheel
turn from the terminal

# SYNOPSIS

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RIGHT TB_KEY_MOUSE_WHEEL_UP TB_MOD_MOTION);

$panel->on( Mouse => sub ($event) {
        my ( $x, $y ) = ( $event->x, $event->y );    # terminal cell, from 0
        if ( $event->key == TB_KEY_MOUSE_LEFT ) {
                if ( $event->modifiers & TB_MOD_MOTION ) {
                        drag_to( $x, $y );                   # moved with the left button held
                }
                else {
                        start_at( $x, $y );                  # left button pressed
                }
        }
        return;
} );
```

# DESCRIPTION

[Term::Fabulous](../../../../README.md) fires a `Mouse` event for every mouse report the
terminal sends while ["run" in Term::Fabulous](../../../../README.md#run) is active and mouse input is
enabled (the `mouse` parameter of ["new" in Term::Fabulous](../../../../README.md#new), on by
default except in inline mode, which has no mouse support). The event is fired on the topmost widget that painted the
cell under the pointer in the last frame (see
["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse) for the exact rules), or on the root
widget when there is none, and then bubbles up to the ancestors.

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'Mouse'` unless given to the constructor)
and `bubble_mode` (`IF_CONTINUE`) are available as well.

## What the terminal reports

Terminals report the mouse only in these cases:

- a button is pressed: `key` is `TB_KEY_MOUSE_LEFT`,
`TB_KEY_MOUSE_MIDDLE` or `TB_KEY_MOUSE_RIGHT`;
- a button is released: `key` is `TB_KEY_MOUSE_RELEASE`, and
`released_button` says which button it was when the terminal reports
it (SGR mouse reports, which [Term::Fabulous](../../../../README.md) asks for, do);
- the pointer moves while a button is held (a drag): `key` is the
held button's key again and `modifiers` has `TB_MOD_MOTION` set;
- the wheel turns: `key` is `TB_KEY_MOUSE_WHEEL_UP` or
`TB_KEY_MOUSE_WHEEL_DOWN`, one event per notch; a horizontal wheel
(or a sideways tilt of the wheel) gives `TF_KEY_MOUSE_WHEEL_LEFT` or
`TF_KEY_MOUSE_WHEEL_RIGHT`.

The pointer moving without a button held is reported as well, but it
is not a `Mouse` event: it fires `MouseMove`
([Term::Fabulous::Event::MouseMove](MouseMove.md)) instead.

Terminals encode Shift, Ctrl and Alt in their mouse reports;
`modifiers` carries them as `TB_MOD_SHIFT`, `TB_MOD_CTRL` and
`TB_MOD_ALT`, so a Shift+click can be told from a click.

# CONSTRUCTOR

## new

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_MOD_MOTION);

my $press   = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_LEFT, x => 10, y => 3 );
my $drag    = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_LEFT, x => 12, y => 3, modifiers => TB_MOD_MOTION );
my $release = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_RELEASE, x => 12, y => 3 );

$canvas->fire_event($press);
```

Programs rarely build mouse events themselves; [Term::Fabulous](../../../../README.md) does it
for every report. Building one by hand is useful in tests of one
widget's `Mouse` listeners; the
[`click`](../Terminal/Memory.md#click) method of
Term::Fabulous::Terminal::Memory clicks like a real mouse (see ["TESTING" in Term::Fabulous::Manual::Programs](../Manual/Programs.md#testing)). Note
that firing a hand-built event
on a widget only runs the listeners. For a real left press,
[Term::Fabulous](../../../../README.md) records the pointer position and moves the keyboard
focus (see ["FOCUS" in Term::Fabulous::Manual::Events](../Manual/Events.md#focus)) before it fires the
`Mouse` event. Clay::UI's `OnPress` and `OnRelease`
events ([Clay::UI::Role::Interaction::Pressable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3APressable)) come later, during
the next frame (within 1/30 second), when the recorded pointer is
handed to Clay. A hand-built `Mouse` event does none of this. Unknown
parameters die. Besides the parameters below, the `name` and
`bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

- `key`

    Required. One of the `TB_KEY_MOUSE_*` constants listed under ["key"](#key).

- `x`

    Required. The column of the pointer, counted from 0 at the left edge of
    the terminal.

- `y`

    Required. The row of the pointer, counted from 0 at the top edge of the
    terminal.

- `modifiers`

    Optional. A bit mask of `TB_MOD_MOTION`, `TB_MOD_SHIFT`, `TB_MOD_ALT`
    and `TB_MOD_CTRL`. Default: `0`.

- `released_button`

    Optional. With `key` `TB_KEY_MOUSE_RELEASE` only: the button that was
    released, `TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE` or
    `TB_KEY_MOUSE_RIGHT`. Default: `undef`, the terminal did not say.
    Anything else dies.

An event object can be fired only once. Build a new one for every
`fire_event` call.

## of

```perl
my $event = Term::Fabulous::Event::Mouse->of($termbox_event);
```

Builds an event from a `Term::Fabulous::Termbox::Event`: `key`, `x`, `y` and
`modifiers` from its `key`, `x`, `y` and `mod`, and for a release
`released_button` from its `ch` (see
["tf\_install\_input\_parser" in Term::Fabulous::Termbox](../Termbox.md#tf_install_input_parser)). Called by
[Term::Fabulous](../../../../README.md); class method.

# METHODS

## key

```perl
my $key = $event->key;
```

Which button or wheel direction the event is about. Import the
constants from [Term::Fabulous::Termbox](../Termbox.md):

```perl
use Term::Fabulous::Termbox qw(
        TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_MIDDLE TB_KEY_MOUSE_RIGHT
        TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN
        TF_KEY_MOUSE_WHEEL_LEFT TF_KEY_MOUSE_WHEEL_RIGHT
        TB_MOD_MOTION
);

Constant                  Meaning
------------------------  ------------------------------------------
TB_KEY_MOUSE_LEFT         left button pressed (or dragged)
TB_KEY_MOUSE_MIDDLE       middle button pressed (or dragged)
TB_KEY_MOUSE_RIGHT        right button pressed (or dragged)
TB_KEY_MOUSE_RELEASE      a button was released (see released_button)
TB_KEY_MOUSE_WHEEL_UP     wheel turned up (away from the user) one notch
TB_KEY_MOUSE_WHEEL_DOWN   wheel turned down one notch
TF_KEY_MOUSE_WHEEL_LEFT   horizontal wheel turned left one notch
TF_KEY_MOUSE_WHEEL_RIGHT  horizontal wheel turned right one notch
```

The `TF_KEY_*` constants are Term::Fabulous additions; termbox2 has no
codes for a horizontal wheel.

## x

```perl
my $column = $event->x;
```

The column of the cell under the pointer, an integer from 0 at the left
edge of the terminal, also on terminals wider than 255 columns. To get a
position inside a canvas, use ["cell\_at" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#cell_at)
or ["pixel\_at" in Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md#pixel_at).

## y

```perl
my $row = $event->y;
```

The row of the cell under the pointer, an integer from 0 at the top
edge of the terminal.

## modifiers

```perl
my $dragging = $event->modifiers & TB_MOD_MOTION;
my $shifted  = $event->modifiers & TB_MOD_SHIFT;
```

A bit mask. `TB_MOD_MOTION` is set when the event reports a move with
a button held (a drag); `TB_MOD_SHIFT`, `TB_MOD_ALT` and `TB_MOD_CTRL`
are set for the modifier keys held at the time.

## released\_button

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_RIGHT);

if ( $event->key == TB_KEY_MOUSE_RELEASE && ( $event->released_button // 0 ) == TB_KEY_MOUSE_RIGHT ) {
        close_context_menu();
}
```

For a `TB_KEY_MOUSE_RELEASE`: the key of the button that was released,
`TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE` or `TB_KEY_MOUSE_RIGHT`;
`undef` when the terminal did not say. [Term::Fabulous](../../../../README.md) takes a
release that names no button for a release of the left button. For
every other key: `undef`.

## use\_wheel

```perl
$event->use_wheel if $self->scroll_down_one_notch;
```

For a widget that scrolls itself with the wheel: marks the wheel notch
of this event as used. [Term::Fabulous](../../../../README.md) scrolls the scroll containers
around the pointer ([Term::Fabulous::Widget::ScrollBox](../Widget/ScrollBox.md)) by every notch
no widget used, so call it only when the notch moved something; a
widget that is already at its end leaves the notch to its scroll box.
Whether the event bubbles on is up to the return value of the listener,
as for any event. Returns the event.

## wheel\_used

```perl
my $scrolled_itself = $event->wheel_used;
```

1 after ["use\_wheel"](#use_wheel), otherwise 0.

# SEE ALSO

["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse), [Term::Fabulous](../../../../README.md),
[Term::Fabulous::Event::MouseMove](MouseMove.md), [Term::Fabulous::Event::KeyPress](KeyPress.md),
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), [Term::Fabulous::Termbox](../Termbox.md),
["Paint with the mouse (Canvas, clicks and drags)" in Term::Fabulous::Cookbook::Canvases](../Cookbook/Canvases.md#paint-with-the-mouse-canvas-clicks-and-drags).
