# NAME

Term::Fabulous - Terminal UIs from Clay layouts, drawn with termbox2

# SYNOPSIS

```perl
     use Term::Fabulous;
     use Term::Fabulous::Widget::Box;
     use Term::Fabulous::Widget::Text;
     use Clay::XS qw(sizing_grow);

     my $root = Term::Fabulous::Widget::Box->new(
             background_color => [20, 25, 35, 255],
             layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
     );
     $root->add_child( Term::Fabulous::Widget::Text->new(text => 'Hello', text_color => [255, 255, 255, 255]) );
     $root->on( KeyPress => sub ($event) { ... } );

     my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
     $ui->run;   # returns after Ctrl+C, SIGINT or SIGTERM
```

# DESCRIPTION

A [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) subclass that composes [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender): it lays
out a widget tree with Clay and draws it into the terminal through
termbox2, redrawing continuously at 30 frames per second while
["run"](#run) is active. termbox2 writes only the cells that changed to the
terminal, and a [Term::Fabulous::Widget::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ACanvas) sends only its changed
cells to termbox2 while nothing moves or covers it.

To render the same widget tree once, as text for a pipe or a report,
use [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic) instead; it paints with the same render
roles but never opens the terminal.

# CONSTRUCTOR

## new

```perl
     my $ui = Term::Fabulous->new(%params);
```

Unknown parameters die.

- `root` (required)

    The root widget. It must consume [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter)
    (for example [Term::Fabulous::Widget::Box](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABox)), otherwise the constructor
    dies, because unhandled input events are delivered to it.

- `width`, `height` (required)

    Initial layout size in cells. ["run"](#run) replaces them with the terminal
    size, and resizes keep them in sync.

- `output_mode`

    Must be `TB_OUTPUT_TRUECOLOR` (the default); see
    [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender).

- `mouse`

    Boolean, default 1. Enables termbox2 mouse input (clicks, releases,
    wheel and drag motion).

- `memory_size`, `error_handler`

    Passed to [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI). The measure-text callback is always the
    terminal-cell measurement installed by [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender).

# METHODS

## run

Opens the terminal, runs the event loop until it is stopped, and closes
the terminal again. The terminal is initialized here, not in the
constructor: `tb_init` and every terminal setup call are checked and
die with termbox2's error message. Once the terminal is open, it is
always restored (`tb_shutdown`) and every watcher this object added to
the [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) singleton is removed, whether the loop stops
normally, an exception escapes from a timer or an event handler, or an
event handler calls `exit`. An exception is rethrown after the terminal
has been restored, so its message appears on the normal screen. `run`
can therefore be called again later, and other code can keep using the
loop.

When the locale's character set is not UTF-8, `run` warns once before
opening the terminal: termbox2 then cannot place wide characters.

Input is read when the terminal (or termbox2's resize pipe) becomes
readable; there is no polling timer.

## pointer\_state

`undef` until the first mouse event, then `{ x => ..., y => ..., down => 0|1 }`.
A left-button press sets `down`, a release clears it, wheel and other
buttons keep it. `draw` passes it to Clay, which drives hover and
press state of [Clay::UI::Role::Interaction::Hoverable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AHoverable) and
[Clay::UI::Role::Interaction::Pressable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3APressable) widgets.

## loop

The [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) used by the last ["run"](#run).

## mouse, termbox\_draw\_interval, termbox\_resize\_debounce\_interval

Readers. The intervals are 1/30 s (redraw) and 1/10 s (resize debounce).

# EVENTS

Every dispatch fires a freshly built event, which then bubbles up the
parent chain as described in [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter).

- [Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress)

    Fired on the focused widget (`$ui->interaction->get_focused_widget`),
    or on the root when nothing has focus.

- [Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse)

    Fired on the topmost event emitter painted at the pointer's cell in the
    last frame (a widget's background, text or canvas, or the edge cells of
    its border), or on the root when there is none. Content scrolled out of a
    scroll container is not painted, so it never receives the event.

- [Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize)

    Always fired on the root, twice per debounced terminal resize: once
    before the new size is applied (`is_pre_event`) and once after it.
    Resizes to a zero width or height are ignored.

Ctrl+C fires a KeyPress (key 3) and then stops the loop, so ["run"](#run)
returns.

# KEYBOARD FOCUS AND SCROLLING

Tab and Shift-Tab fire their KeyPress like any key and then move the
focus to the next or previous focusable widget
(`$ui->interaction->focus_next` / `focus_previous`, which wrap
around), for example a [Term::Fabulous::Widget::Button](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AButton). Listeners see
the key but cannot keep the focus from moving.

Every mouse-wheel notch scrolls the scroll container under the pointer,
for example a [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox), by three rows. The
notches since the last frame are applied together when the next frame
is drawn (["draw" in Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender#draw)), and the Mouse event for each
notch is fired as usual.

# SEE ALSO

[Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic), [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender), [Term::Fabulous::Layout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ALayout), [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox), [Term::Fabulous::Widget::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ACanvas), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI), [Termbox](https://metacpan.org/pod/Termbox).

# AUTHOR

davenonymous <perl@davenonymous.com>

# COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
