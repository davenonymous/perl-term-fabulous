# NAME

Term::Fabulous - Full-screen terminal user interfaces with layouts,
widgets, keyboard and mouse

# SYNOPSIS

```perl
     use v5.24;
     use warnings;
     use feature 'signatures';
     no warnings 'experimental::signatures';

     use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
     use Term::Fabulous;
     use Term::Fabulous::Widget::Box;
     use Term::Fabulous::Widget::Text;
     use Term::Fabulous::Widget::TextField;

     my $root = Term::Fabulous::Widget::Box->new(
             background_color => [ 20, 25, 35, 255 ],
             layout           => {
                     layout_direction => CLAY_TOP_TO_BOTTOM,
                     sizing           => { width => sizing_grow(), height => sizing_grow() },
                     padding          => { left => 2, right => 2, top => 1, bottom => 1 },
                     child_gap        => 1,
             },
     );

     my $greeting = Term::Fabulous::Widget::Text->new(
             text       => 'What is your name? (Enter to greet, Ctrl+C to quit)',
             text_color => [ 230, 230, 230, 255 ],
     );
     my $name = Term::Fabulous::Widget::TextField->new( placeholder => 'Your name' );
     $root->add_child( $greeting, $name );

     $name->on(
             Submit => sub ($event) {
                     $greeting->text( 'Hello, ' . $event->value . '!' );
                     return;
             }
     );

     my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
     $ui->interaction->set_focused_widget($name);
     $ui->run;    # returns after Ctrl+C, SIGINT, SIGTERM or SIGHUP
```

The picture shows `examples/showcase.pl`, a demo program of the
distribution (see [Term::Fabulous::Examples](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AExamples)):

<div>
    <p><img src="/screenshots/overview.svg" alt="A Term::Fabulous program: a sign-up form with text fields, radio buttons, a dropdown, a slider, a check box and buttons, a chart of requests per second with a translucent notification, an event log and text in several scripts"></p>
</div>

# DESCRIPTION

Term::Fabulous builds full-screen terminal applications in Perl. You
describe the screen as a tree of widgets (boxes, text, buttons, input
fields, tables, charts, scrollable areas and canvases), in Perl code or
in a layout file written in KDL, a small configuration language
([https://kdl.dev](https://kdl.dev)).
Term::Fabulous sizes and positions the widgets with the Clay layout
engine, draws them with 24-bit colors through the termbox2 library, and
turns key presses, mouse clicks and terminal resizes into events your
code reacts to.

Highlights:

- Flexible layout: rows and columns, growing, fitting, fixed and
percentage sizes, padding, gaps, alignment, borders in 20 styles.
- Input widgets for forms: single- and multi-line text with selection,
undo and a clipboard shared by all text fields of the program; check
boxes; radio buttons; dropdowns; sliders; star ratings; segmented
controls.
- A table widget for rows of data: sorting by one or several columns,
filtering (also by the user, in a filter row), groups and trees that
open and close, pages, single and multiple selection, any widget as a
cell, and lines and colors per column, row and cell.
- Chart widgets that draw themselves from data: line, area, bar and
scatter charts with category, numeric, logarithmic and time axes,
stacking, curves, transforms and live data; histograms; sparklines;
pie, donut, polar area and radar charts; a legend, hover with a
`SeriesHover` event, and palettes for dark and light backgrounds.
- Keyboard focus with Tab and mouse clicks, readable key names for key
bindings (`Ctrl+S`, `Shift+Left`), the kitty keyboard protocol for
keys older terminals cannot tell apart, mouse wheel scrolling.
- Dialogs that open over the screen and keep the keyboard focus inside.
- Dividers between widgets, horizontal or vertical, with a text on the
line; accordions whose sections open and close under their headers.
- Progress bars in several styles, with labels, stripes, stacked
segments and an indeterminate runner, and spinners in twelve styles,
animated on the application's clock without timers; toasts that
appear in a corner and go away by themselves.
- Canvases for free drawing, including a half-block pixel canvas with
lines, rectangles and circles.
- Correct handling of Unicode: wide CJK characters, emoji, combining
characters.
- A prompt of a few rows below the shell's output instead of the whole
screen (["INLINE MODE"](#inline-mode)).
- The same widget tree can be printed once as text (with or without
colors) for reports and tests, through [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic).
- Whole programs can be tested without a terminal: a terminal in memory
([Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory)) takes keys, clicks and resizes,
and ["step"](#step) handles them as ["run"](#run) would.
- Runs on [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync), so timers, sockets and child processes work
alongside the user interface.

This class is the application object: it owns the widget tree, opens the
terminal, runs the event loop, draws a frame whenever something changed
(checking 30 times per second) and dispatches input events. It is a
subclass of [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI). It reaches the terminal through a _terminal_
object ([Term::Fabulous::Role::Terminal](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3ATerminal)): the real one by default, or
[Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory) in tests, which ["step"](#step) drives
without an event loop.

# DOCUMENTATION

The documentation has four parts. If you are new to Term::Fabulous,
start with the manual's first page and its first program.

- The manual: [Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual)

    The user guide. Its first page introduces the library, shows a first
    program, lists the topic pages and ends with a
    [FEATURE INDEX](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#FEATURE-INDEX) that maps tasks
    to the sections, recipes and class pages that describe them. The topic
    pages explain the concepts, with examples throughout:
    [Term::Fabulous::Manual::Layout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ALayout) (widgets, the widget tree and
    layout), [Term::Fabulous::Manual::Looks](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ALooks) (text, colors, borders),
    [Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents) (events, keyboard, focus, mouse,
    scrolling), [Term::Fabulous::Manual::Forms](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AForms) (input widgets),
    [Term::Fabulous::Manual::Feedback](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AFeedback) (progress bars, spinners and
    toasts), [Term::Fabulous::Manual::Charts](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ACharts) (canvases and charts),
    [Term::Fabulous::Manual::Tables](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ATables), [Term::Fabulous::Manual::TableRows](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ATableRows)
    and [Term::Fabulous::Manual::TableStyles](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ATableStyles) (the table widget),
    [Term::Fabulous::Manual::KDL](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AKDL) (layout files),
    [Term::Fabulous::Manual::Programs](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3APrograms) (event loop, output without a
    terminal, testing), [Term::Fabulous::Manual::CustomWidgets](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ACustomWidgets),
    [Term::Fabulous::Manual::Troubleshooting](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ATroubleshooting) and
    [Term::Fabulous::Manual::Glossary](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AGlossary).

- The cookbook: [Term::Fabulous::Cookbook](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook)

    Recipes: complete, runnable programs for common tasks, each with a
    picture and notes on the lines that matter. Its first page lists every
    recipe; the recipes are on topic pages such as
    [Term::Fabulous::Cookbook::GettingStarted](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3AGettingStarted),
    [Term::Fabulous::Cookbook::Forms](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3AForms), [Term::Fabulous::Cookbook::Tables](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3ATables)
    and [Term::Fabulous::Cookbook::Charts](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3ACharts).

- The examples: [Term::Fabulous::Examples](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AExamples)

    The example programs of the distribution, with a picture of each: demo
    programs, a gallery with one program per widget, and the complete
    programs of the cookbook.

- The class pages

    One reference page per class, listed by purpose under ["MODULES"](#modules).
    This page is the reference of the application object: ["new"](#new),
    ["run"](#run), ["step"](#step) and the other methods, the events it fires, the keys
    it handles itself, inline mode and wheel scrolling.

# REQUIREMENTS

Perl 5.24 or later, a C compiler to build [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox)
(termbox2 is compiled into the distribution), a terminal with 24-bit
colors and a UTF-8 locale. See ["REQUIREMENTS" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#REQUIREMENTS).

# CONSTRUCTOR

## new

```perl
     my $ui = Term::Fabulous->new(
             root   => $root_widget,
             width  => 80,
             height => 24,
             mouse  => 1,
     );
```

Creates the application object. The terminal is not touched until
["run"](#run) (or ["step"](#step)), so you can create the object, set the focus and
add timers first. Unknown parameters die
(`Unrecognised parameters for Term::Fabulous constructor: 'colour'`).

- `root`

    Required. The root widget, the top of the widget tree, usually a
    [Term::Fabulous::Widget::Box](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABox). It receives every event that no other
    widget receives: key presses while nothing has the focus, mouse events
    where no widget is drawn, and every `Start` and `Resize`. It must
    therefore be able to fire events (compose
    [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter), as all Term::Fabulous widgets
    except Text do); otherwise `new` dies
    (`Term::Fabulous: root must consume Clay::UI::Role::Events::Emitter to receive input events, got ...`).
    The root must not have a parent (`new` dies with
    `Clay::UI: 'root' must not have a parent; ...`); a widget that was
    removed from its parent can be a root. A widget tree belongs to one
    application object (or [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic)) at a time: a second
    object with the same root dies with
    `Clay::UI: 'root' is already the root of another Clay::UI`, as long as
    the first one exists.

- `width`

    Required. A positive number: the width of the layout in columns until
    the terminal is opened (["run"](#run) or ["step"](#step)). It is then replaced with
    the terminal's width, and kept up to date when the terminal is resized.

- `height`

    Required. A positive number: the height of the layout in rows until
    the terminal is opened, then the terminal's height (in inline mode, the
    rows of the inline region).

- `inline`

    Optional. A whole number of rows, at least 1, or `undef`, the default.
    With a number, ["run"](#run) does not take over the screen: the user
    interface is drawn into that many rows below the shell's output and
    stays there when `run` returns, like a prompt. See ["INLINE MODE"](#inline-mode).
    Anything else dies
    (`Term::Fabulous: inline must be a whole number of rows of at least 1, got '0'`).

- `mouse`

    A boolean. Default: 1, or 0 in inline mode. With 1, the terminal
    reports mouse clicks, drags, movement and the wheel to the program (see
    ["MOUSE" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#MOUSE)). With 0, the terminal keeps the mouse
    for itself, so the user can select and copy text as usual, and no
    `Mouse` or `MouseMove` events are fired. Inline mode has no mouse
    support: `mouse` with a true value and `inline` together die.

- `kitty_keyboard`

    A boolean. Default: 1. With 1, ["run"](#run) asks the terminal whether it
    speaks the
    [kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
    and, if it does, switches the protocol on until `run` returns. The
    terminal then reports keys the legacy encodings cannot tell apart
    (Ctrl+I and Tab, Ctrl+Shift+W and Ctrl+W, Escape and the start of Alt
    plus a key), the Super, Hyper and Meta modifiers, and keys such as F13
    to F35, the keypad and media keys; see
    ["THE KITTY KEYBOARD PROTOCOL" in Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress#THE-KITTY-KEYBOARD-PROTOCOL). A
    terminal without the protocol answers that it has none, and the keys
    are read as before. The question costs one exchange with the terminal
    when `run` starts, at most half a second for a terminal that does not
    answer at all. With 0, the terminal is not asked and the protocol stays
    off. ["kitty\_keyboard\_active"](#kitty_keyboard_active) tells whether `run` uses it.

- `terminal`

    Optional. The terminal to run on: an object composing
    [Term::Fabulous::Role::Terminal](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3ATerminal). Default: a new
    [Term::Fabulous::Terminal::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3ATermbox), the real terminal. Pass a
    [Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory) to test a program without a
    terminal (see ["step"](#step) and ["TESTING" in Term::Fabulous::Manual::Programs](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3APrograms#TESTING)). Anything
    else dies (`Term::Fabulous: terminal must consume Term::Fabulous::Role::Terminal`).

- `clock`

    Optional, for tests. A code reference that returns the current time in
    seconds, default `Time::HiRes::time`. Frame pacing reads it: how long
    a frame took and when it ended (see ["run"](#run)), and so do ["now"](#now) and
    the widgets that animate (see ["request\_frame\_at"](#request_frame_at)). A test gives it a
    clock it controls to check the pacing with `step( paced => 1 )`
    or to move an animation on. Anything but a code reference dies.

- `output_mode`

    Optional, and only one value is allowed: `TB_OUTPUT_TRUECOLOR` from
    [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox), the default. Any other value dies. Term::Fabulous always draws
    with 24-bit colors.

- `memory_size`

    Optional, rarely needed. The number of bytes Clay reserves for laying out
    a frame: an integer of at least what `Clay::XS::Clay_MinMemorySize()`
    reports for the UI's `max_element_count` (about 6 MB for the default
    count), which is also the default. It does not raise the limit on the
    number of widgets; `max_element_count` does.

- `max_element_count`

    Optional. The number of Clay elements a frame may hold: a positive
    integer, default 8192. Every widget is one element and Clay keeps two
    elements for itself, so the default allows 8190 widgets on the screen
    at once; a larger tree dies with
    `Clay::UI: the widget tree has more elements than max_element_count (8192) allows ...`.
    Raise it for very large trees; the memory Clay reserves grows with it.
    See ["new" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#new).

- `error_handler`

    Optional. A code reference Clay calls when it reports an error during
    layout (for example two widgets with the same id). The default dies with
    `Clay error: ...`. See ["new" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#new).

- `measure_text`

    Not accepted, although [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) has it: Term::Fabulous always
    measures text in terminal columns itself, so passing `measure_text`
    dies.

# METHODS

## run

```perl
     $ui->run;
```

Opens the terminal in full-screen mode (or inline, see
["INLINE MODE"](#inline-mode)), runs the event loop until it is stopped, and
restores the terminal. It returns nothing. A terminal that ["step"](#step)
opened is used as it is, without a second `Start`, and closed when
`run` returns.

While it runs:

- a `Start` event is fired on the root widget as soon as the terminal is
open, with its size: from inside the running loop, before the first
frame and before any input is read, so a `Start` listener can use
["loop"](#loop). Timers and other work the program queued on the loop before
`run` may run before it;
- every 1/30 second (see ["termbox\_draw\_interval"](#termbox_draw_interval)) the screen is laid
out and drawn again, using the real terminal size, if anything changed
since the last frame: a widget was changed, input arrived, the terminal
was resized, ["invalidate"](#invalidate) was called, or the time a widget asked for
a frame at has come (["request\_frame\_at"](#request_frame_at), how spinners and progress
bars animate). Nothing is drawn while nothing happens. A pointer that only moved gets a frame of its own at
most every other check when frames take long to draw (longer than the
time since the last one ended), so moving the mouse cannot keep the
loop busy with nothing but redrawing; clicks, keys and changed widgets
are always drawn at the next check;
- terminal input is read as soon as it arrives and dispatched as
`KeyPress`, `Mouse` and `MouseMove` events (see ["EVENTS"](#events));
- terminal resizes fire `Resize` on the root widget;
- everything else you added to the [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) (IO::Async calls
these objects _notifiers_: timers, sockets, child processes, ...) runs
as usual.

The loop stops, and `run` returns, when:

- your code calls `$ui->loop->stop`;
- the user presses `Ctrl+C` (after its `KeyPress` was fired);
- the process receives `SIGINT`, `SIGTERM` or `SIGHUP`.

While `run` is active it handles these three signals itself; when it
returns or dies, `%SIG` holds again what the program had set for them
before, except for a signal that an [IO::Async::Signal](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ASignal) the program
added to the loop still watches.

If code running inside the loop dies (a listener, a timer), `run`
restores the terminal first and then dies with the same error, so the
message is readable on the normal screen. The terminal is also restored
when code inside the loop calls `exit`. When the terminal input ends
without a `SIGHUP` reaching the process (a terminal that went away
while the process is not in its session, or input from a pipe), `run`
dies with `Term::Fabulous: the terminal was closed`.
After `run` has returned or died, the object can be used again and
`run` can be called again.

`run` dies with the terminal's error when the terminal cannot be
opened. For the real terminal, these start with
`Term::Fabulous::Terminal::Termbox:`, for example when the process has
no controlling terminal (`tb_init failed: No such device or address`,
or `tf_init_inline failed: ...` in inline mode), when the terminal
reports a size of 0 columns or rows, and in inline mode when the
terminal does not report its cursor position within a second
(`the terminal did not report its cursor position; ...`); see
["open" in Term::Fabulous::Terminal::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3ATermbox#open).

When the locale's character set is not UTF-8, `run` warns (at every
call): `Term::Fabulous: the locale's character set is not UTF-8; wide
characters will be misaligned`.

## step

```perl
     my $frames = $ui->step;
     my $frames = $ui->step( paced => 1 );
```

One turn of ["run"](#run) without an event loop, for tests: usually with a
[Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory) as the ["terminal"](#terminal), whose input
methods queue keys, clicks and resizes. `step`

1. opens the terminal if it is not open yet, sets ["width"](#width) and ["height"](#height)
to its size and fires `Start`, as `run` does (but there is no loop:
["loop"](#loop) is the one of the last `run`, or `undef`);
2. reads every event that waits and dispatches it exactly as `run` does:
a key to the focused widget (after which Tab and Shift+Tab also move
the focus), a mouse event to the widget under the pointer (a press
focuses it first), a wheel notch to the scroll box under the pointer;
see ["EVENTS"](#events) and ["KEYBOARD AND FOCUS"](#keyboard-and-focus). `Ctrl+C` fires its
`KeyPress` but has no loop to stop;
3. applies a resize at once, firing the `Resize` pair, instead of waiting
for the size to settle;
4. draws frames as long as one is due: for a click, one frame for the
press and one for the release, and another one when a frame changed
widgets (hover and press events fire while a frame is drawn). Without
`paced`, a frame that only shows pointer motion is drawn at once; with
`paced => 1`, it waits like in `run` (see there), measured with
the `clock` of ["new"](#new).

Returns the number of frames it drew, 0 when nothing was due. The
terminal stays open; `run` closes it, or close it with
`$ui->terminal->close`. Unknown options die, and so does a call
from inside `run`. When frames keep being due after 100 rounds,
because a widget changes in every frame, `step` dies. When the
terminal input has ended (["end\_input" in Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory#end_input)),
`step` dies like `run`.

## terminal

```perl
     my $terminal = $ui->terminal;
     $ui->terminal->press_key('Enter');
```

Returns the terminal object given to ["new"](#new), or the
[Term::Fabulous::Terminal::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3ATermbox) created by default. Read only.

## loop

```perl
     my $loop = $ui->loop;
     $ui->loop->stop;
```

Returns the [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) of the most recent ["run"](#run), or `undef`
before the first `run`; it is set before the `Start` event fires.
Call `$ui->loop->stop` from a listener or timer to end `run`. The loop is IO::Async's process-wide loop: the same
object that `IO::Async::Loop->new` returns, which is why notifiers
added to `IO::Async::Loop->new` before `run` run inside it.

## interaction

```perl
     my $tracker = $ui->interaction;
     $ui->interaction->set_focused_widget($widget);
     my $focused = $ui->interaction->get_focused_widget;
```

Returns the [Clay::UI::Interaction](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AInteraction) object of this UI. It holds the
keyboard focus and the hover and press state of the widgets. Use it to
move the focus from code (`set_focused_widget`, `focus_next`,
`focus_previous`) and to ask which widget has it
(`get_focused_widget`). See ["FOCUS" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#FOCUS). Inherited
from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

## root

```perl
     my $root = $ui->root;
```

Returns the root widget given to ["new"](#new). Read only.

## width

```perl
     my $columns = $ui->width;
     $ui->width(100);
```

Accessor. Returns the current layout width in columns: the terminal width
while ["run"](#run) is active. Writing sets the layout width from the next frame
on and returns the new value; a value that is not a positive number dies.
`run` sets the width to the terminal width when it starts and after every
terminal resize, so a written value lasts only until then. Inherited from
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

## height

```perl
     my $rows = $ui->height;
     $ui->height(40);
```

Accessor. Returns the current layout height in rows: the terminal height
while ["run"](#run) is active, or the rows of the inline region in inline mode.
Writing works like for ["width"](#width). Inherited from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

## inline

```perl
     my $rows = $ui->inline;    # undef for the full screen
```

Returns the `inline` constructor parameter. Read only.

## mouse

```perl
     my $enabled = $ui->mouse;
```

Returns whether the mouse is reported: the `mouse` constructor
parameter, or its default (1, or 0 in inline mode). Read only.

## kitty\_keyboard

```perl
     my $wanted = $ui->kitty_keyboard;
```

Returns the `kitty_keyboard` constructor parameter, or its default
(1). Read only.

## kitty\_keyboard\_active

```perl
     my $in_use = $ui->kitty_keyboard_active;
```

Returns 1 while the open terminal uses the kitty keyboard protocol:
from the start of ["run"](#run) (or the first ["step"](#step)), before `Start`
fires, until the terminal is closed, when the terminal speaks the
protocol and `kitty_keyboard` is 1. Returns 0 otherwise, and always
while the terminal is closed. Read only.

## output\_mode

```perl
     my $mode = $ui->output_mode;    # TB_OUTPUT_TRUECOLOR
```

Returns the `output_mode` constructor parameter, always
`TB_OUTPUT_TRUECOLOR`. Read only.

## pointer\_state

```perl
     my $pointer = $ui->pointer_state;    # { x => 12, y => 3, down => 0 } or undef
```

Returns where the mouse pointer was last reported: a new hash reference
with the cell coordinates `x` and `y` and `down`, which is 1 while the
left button is held and 0 otherwise. Returns `undef` until the first
mouse report. The terminal reports every move, so this is the live
mouse position as of the last report. Term::Fabulous passes it to Clay
with every frame, which derives the hover and press state of the
widgets from it. When the button went down and up again between two
frames, each state gets a frame of its own, so a click is never too
fast to press a widget. `down` follows the left button only: the
release of another button does not end a press.

## invalidate

```perl
     $ui->invalidate;
```

Asks for a frame: the screen is laid out and drawn again at the next
tick of the frame timer, even if Term::Fabulous saw no change. Returns
the object. Frames are drawn by themselves whenever a widget was
changed through its methods, input arrived or the terminal was resized,
so most programs never need this; call it when something the frame
depends on changed behind Term::Fabulous's back, for example state a
custom widget reads while it draws without calling `mark_changed`
(see [telling Term::Fabulous that something changed](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ACustomWidgets#Telling-Term::Fabulous-that-something-changed)).

## now

```perl
     my $seconds = $ui->now;
```

The current time in seconds on the application's clock: the `clock`
of ["new"](#new), by default `Time::HiRes::time`. Widgets that animate read
it instead of the system clock, so a test or the screenshot harness
can move it; see ["request\_frame\_at"](#request_frame_at).

## request\_frame\_at

```perl
     $ui->request_frame_at( $ui->now + 0.1 );
```

Asks for a frame at a time on the clock (see ["now"](#now)): at the first
tick of the frame timer at or after it, a frame is drawn as if
["invalidate"](#invalidate) had been called, and `step` draws one when the time
has come. Several requests keep the earliest time. Every frame forgets
the request, so something that animates asks again from the frame it
is drawn in. Returns the object. Dies unless the argument is a number.

This is how the widgets that move by themselves (a
[Term::Fabulous::Widget::Spinner](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ASpinner), an indeterminate
[Term::Fabulous::Widget::ProgressBar](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AProgressBar)) are drawn without timers of
their own; see ["ANIMATION" in Term::Fabulous::Widget::Display](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADisplay#ANIMATION) to write
one.

## find\_by\_id

```perl
     my $field = $ui->find_by_id('name');
```

Returns the widget with the given id, searching the whole tree from the
root, or `undef` when there is none; see
["find\_by\_id" in Term::Fabulous::Widget](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget#find_by_id). Dies when the root widget has no
`find_by_id` method (every Term::Fabulous widget has one).

## termbox\_draw\_interval

```perl
     my $seconds = $ui->termbox_draw_interval;    # 1/30
```

Returns the time between two checks for a due frame in seconds: 1/30.
A frame is drawn at a tick only when something changed since the last
one. Read only.

## termbox\_resize\_debounce\_interval

```perl
     my $seconds = $ui->termbox_resize_debounce_interval;    # 1/10
```

Returns how long, in seconds, the terminal size must stay unchanged
before a resize is applied and the `Resize` events are fired: 1/10.
While a resize is pending, no frames are drawn. Read only.

## draw

```perl
     $ui->draw;
```

Lays out and draws one frame immediately, into the cell target of the
["terminal"](#terminal). `run` calls it whenever a frame is due, so programs do
not need it; see ["invalidate"](#invalidate) to ask for a frame instead. With the
real terminal, it only has a visible effect while the terminal is open.
See ["draw" in Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender#draw).

## bounding\_box, scroll\_state, scroll\_to

```perl
     my $box   = $ui->bounding_box($widget);       # { x, y, width, height } in cells, or undef
     my $state = $ui->scroll_state($scroll_box);   # { position, viewport, content }
     $ui->scroll_to( $scroll_box, { y => -10 } );  # ten rows down from the top
```

`bounding_box` returns where the last frame placed a widget.
`scroll_state` and `scroll_to` read and set the scroll position of a
scroll container such as a [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox), in
cells: 0 at the top and left, negative when scrolled down or right.
Inherited from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI); see ["bounding\_box" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#bounding_box),
["scroll\_state" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#scroll_state) and ["scroll\_to" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#scroll_to), and the recipe
[Scroll a ScrollBox from code](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3ALiveData#Scroll-a-ScrollBox-from-code-keep-a-log-at-the-newest-line).

## after\_draw

```perl
     $ui->after_draw( sub { ... } );
```

Queues a code reference to call once after the next frame has been
drawn, for work that needs the layout of that frame. See
["after\_draw" in Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender#after_draw).

## Other inherited methods

The class inherits further methods from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) (`render`,
`widget_for`, `measure_text`, `max_element_count`,
`laid_out_revision`), from [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender) (`last_frame`,
the [Term::Fabulous::Render::Frame](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AFrame) of the last frame, and
`clip_rect`) and from [Term::Fabulous::Render::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ACanvas)
(`invalidate_canvases`). `cell_target` returns the cell target of the
["terminal"](#terminal). Applications rarely need them; they are documented on
those pages.

# EVENTS

["run"](#run) and ["step"](#step) fire these events. Each one bubbles from the
widget it is fired on to the root, as described in
["Return values and bubbling" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#Return-values-and-bubbling).

- `KeyPress` ([Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress))

    For every key press, on the focused widget, or on the root widget when
    nothing has the focus.

- `Mouse` ([Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse))

    For every mouse report with a button or the wheel (button press,
    release, drag, wheel), on the topmost widget that drew something in the
    cell under the pointer in the last frame: its background, its border or
    its canvas. Text widgets are skipped, and so are widgets that draw
    nothing there. When no widget qualifies, the event is fired on the root
    widget. Content that is scrolled out of view in a
    [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox) is not drawn and never receives
    the event.

- `MouseMove` ([Term::Fabulous::Event::MouseMove](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouseMove))

    For every report of the pointer moving with no button held, on the same
    widget a `Mouse` event would go to. The hover state of the widgets
    follows these moves.

- `Start` ([Term::Fabulous::Event::Start](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AStart))

    On the root widget, once each time the terminal is opened (by ["run"](#run),
    or by the first ["step"](#step)), after `width` and `height` hold its size and
    before the first frame.

- `Resize` ([Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize))

    On the root widget, twice per resize: first with `is_pre_event` true,
    before the new size is applied, then with `is_post_event` true, after
    it. Resizes are debounced (see ["termbox\_resize\_debounce\_interval"](#termbox_resize_debounce_interval)),
    and a size with zero columns or rows is ignored. The starting size
    fires `Start` instead; see [Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize).

Widgets fire further events themselves: `Change` from the input
widgets, `Submit` from [Term::Fabulous::Widget::TextField](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextField),
`Activate` from [Term::Fabulous::Widget::Button](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AButton), `Close` from
[Term::Fabulous::Widget::Dialog](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADialog), `CanvasResize` from canvases,
`SeriesHover` from charts, the table events (`CursorMove`,
`SelectionChange`, `RowActivate`, `SortChange`, `FilterChange`,
`PageChange`, `Expand`, `Collapse`, `ColumnsChange`) from
[Term::Fabulous::Widget::Table](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable), and Clay::UI's `OnPress`,
`OnRelease`, `OnHoverStart`, `OnHoverStopped`, `OnFocus`, `OnBlur`
and `OnScroll`. The complete list is in
["Event reference" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#Event-reference).

# KEYBOARD AND FOCUS

Three keys have a fixed meaning. Their `KeyPress` is fired first, like
for any other key, and then:

- `Ctrl+C`

    stops the loop, so ["run"](#run) returns.

- `Tab`

    moves the focus to the next widget that can take it, in tree order,
    wrapping around at the end. An open [Term::Fabulous::Widget::Dialog](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADialog)
    keeps the focus among its own widgets, and a container can set an order
    of its own (see ["Custom focus order" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#Custom-focus-order)).

- `Shift+Tab` (key name `BackTab`)

    moves the focus to the previous one, in the same order.

Listeners cannot prevent these actions.

When the left mouse button is pressed (not dragged), the widget under
the pointer gets the focus, or its nearest ancestor that can take it.
When there is none, the focus is cleared; so clicking an empty area
leaves a text field and closes an open dropdown. This happens before the
`Mouse` event is fired.

See ["KEYBOARD" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#KEYBOARD) and
["FOCUS" in Term::Fabulous::Manual::Events](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3AEvents#FOCUS).

# INLINE MODE

```perl
     my $ui = Term::Fabulous->new( root => $root, width => 80, height => 3, inline => 3 );
     $ui->run;
     say 'Done.';    # printed below the region
```

<div>
    <p><img src="/screenshots/cookbook-inline-prompt.svg" alt="An inline prompt in the three rows below a shell's earlier output: a question, a text field holding Ada Lovelace and a help line"></p>
</div>

The picture shows the recipe
[Ask for input below the shell's output](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook%3A%3AForms#Ask-for-input-below-the-shells-output-inline-mode),
a complete program that asks for a name in three rows below the
shell's output.

With `inline` set to a number of rows, ["run"](#run) leaves the screen as it
is and draws the user interface into that many rows, starting at the
line of the cursor (the line below it when text precedes the cursor
on its line). The layout is as wide as the terminal and as high as
the region; ["height"](#height) and the `Start` and `Resize` events report the
region's rows. A region taller than the terminal gets the terminal's
height.

- When the region does not fit below the cursor, the terminal scrolls up
first, as if lines had been printed. The rows of the region are erased
before the first frame.
- When `run` returns, it first draws a frame if one is due, so a change
made by the listener that stopped the loop is shown. That frame stays
on the screen (when `run` dies, the last frame drawn before), and the
cursor goes to the line below it, where the shell or the program's own
output continues.
- When the terminal is resized, Term::Fabulous asks the terminal where
the region is now (between frames the hidden cursor waits at the start
of its first row), erases from there down and draws the region again.
- The mouse is not available (see ["new"](#new)).
- The terminal must answer the cursor position query `ESC [ 6 n`, as
xterm-compatible terminals do; Term::Fabulous asks when `run` starts
and after every resize.

Like in full-screen mode, printing to STDOUT while `run` is active
writes over the user interface.

# MOUSE WHEEL SCROLLING

Each notch of the mouse wheel scrolls the scroll box under the
pointer (for example a [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox)) by three
rows, and each notch of a horizontal wheel (or a sideways tilt of the
wheel) by three columns. Notches that arrive between two frames are
added up and applied when the next frame is drawn. A `Mouse` event is
fired for every notch, before the notch is counted: when a listener
calls `use_wheel` on it (["use\_wheel" in Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse#use_wheel)),
the notch scrolls no scroll box; what the listener returns does not
matter for this. Widgets that scroll themselves, like
[Term::Fabulous::Widget::TextArea](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextArea), use the notches they scroll by, so
the scroll box around them stays put while they can still scroll.

# MODULES

Every module has its own page. They are grouped here by purpose; the
modules marked "used internally" are documented for people who extend
Term::Fabulous, and programs do not use them directly.

## Application

- [Term::Fabulous](https://metacpan.org/pod/Term%3A%3AFabulous)

    The interactive application object, described on this page.

- [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic)

    Renders a widget tree once, as text, without opening the terminal; for
    reports, command-line output and tests.

- [Term::Fabulous::Layout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ALayout)

    Builds a widget tree from a KDL layout file, and documents the layout
    file format.

- [Term::Fabulous::Terminal::Memory](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3AMemory)

    A terminal in memory: test a whole program, keys, clicks and what the
    screen shows, with ["step"](#step).

## Widgets

- [Term::Fabulous::Widget::Box](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABox)

    The general container, with layout options, a background and a border.

- [Term::Fabulous::Widget::Text](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AText)

    Shows text in one color; wraps and aligns it.

- [Term::Fabulous::Widget::Button](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AButton)

    A box that can take the keyboard focus, shows when it is focused or
    pressed, and fires `Activate` for a click, Enter or Space.

- [Term::Fabulous::Widget::Dialog](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADialog)

    A box that opens over the whole screen, keeps the keyboard focus inside
    itself and closes on Escape.

- [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox)

    A box whose content can be larger than the box and scrolls with the
    mouse wheel.

- [Term::Fabulous::Widget::Divider](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADivider)

    A horizontal or vertical line between widgets, with an optional text at
    its start, center or end.

- [Term::Fabulous::Widget::Accordion](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AAccordion), [Term::Fabulous::Widget::Accordion::Item](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AAccordion%3A%3AItem)

    Sections with headers that open and close, one at a time or several,
    with the keyboard and the mouse.

- [Term::Fabulous::Widget::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ACanvas)

    A box with a grid of character cells that you draw into.

- [Term::Fabulous::Widget::PixelCanvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3APixelCanvas)

    A canvas that draws pixels, two per cell, with lines, rectangles and
    circles.

- [Term::Fabulous::Widget](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget)

    The abstract base class of all widgets except Text. Its page describes
    the constructor parameters and methods they all share.

- [Term::Fabulous::Widget::Display](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADisplay)

    The abstract base class of the widgets that paint themselves from their
    own state (the divider, the progress bar, the input widgets), with the
    animation helpers; derive from it to write your own.

- [Term::Fabulous::Widget::Element](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AElement), [Term::Fabulous::Widget::TextNode](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextNode)

    The [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) roles behind Term::Fabulous::Widget and
    Term::Fabulous::Widget::Text. Used internally.

- [Term::Fabulous::Widget::Dialog::Backdrop](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADialog%3A%3ABackdrop)

    The layer behind an open dialog. Used internally by the dialog.

## Input widgets

- [Term::Fabulous::Widget::TextField](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextField)

    A single line of text input, optionally masked for passwords.

- [Term::Fabulous::Widget::TextArea](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextArea)

    Text input of several lines, wrapped or scrolled sideways.

- [Term::Fabulous::Widget::Checkbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ACheckbox)

    A box the user checks and unchecks.

- [Term::Fabulous::Widget::RadioGroup](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ARadioGroup)

    A group of radio buttons of which one is selected; it takes the focus
    for its buttons.

- [Term::Fabulous::Widget::RadioButton](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ARadioButton)

    One choice inside a radio group.

- [Term::Fabulous::Widget::Dropdown](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADropdown)

    One choice from a list that opens over the other widgets.

- [Term::Fabulous::Widget::Slider](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ASlider)

    A number from a range, chosen by moving a thumb.

- [Term::Fabulous::Widget::StarRating](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AStarRating)

    A number of stars, whole or half, chosen with the keys or a click, or
    read-only.

- [Term::Fabulous::Widget::SegmentedControl](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ASegmentedControl)

    One choice of a few options shown side by side as one bar.

- [Term::Fabulous::Widget::Input](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AInput)

    The base class of the input widgets; derive from it to write your own.

- [Term::Fabulous::Widget::TextInput](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextInput)

    The base class of TextField and TextArea, with the editing keys and mouse
    selection.

- [Term::Fabulous::Editor](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEditor)

    The text, cursor, selection, undo history and clipboard behind the text
    inputs, without any drawing.

- [Term::Fabulous::TextView](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATextView)

    How the text inputs lay an editor's text out in rows: wrapping,
    scrolling, the cell of the cursor and the text under a click.

- [Term::Fabulous::Widget::Dropdown::List](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADropdown%3A%3AList)

    The list an open dropdown shows. Used internally by the dropdown.

## Feedback widgets

- [Term::Fabulous::Widget::ProgressBar](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AProgressBar)

    How much of a task is done: a bar in several styles, with a label,
    stripes, segments, or a runner for a task of unknown extent.

- [Term::Fabulous::Widget::Spinner](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ASpinner)

    That something is going on: frames cycling next to a label, in twelve
    styles of one cell to three rows, or frames of your own.

- [Term::Fabulous::Widget::Toast](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AToast)

    A notification of a kind (info, success, warning, danger) that appears
    in a corner, stacks with the others there and goes away by itself; in
    the layout, an alert box.

- [Term::Fabulous::Widget::Toast::Stack](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AToast%3A%3AStack)

    The column of toasts in one corner. Used internally by the toast.

## Tables

- [Term::Fabulous::Widget::Table](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable)

    Rows and columns of data, with sorting, filtering, grouping, trees,
    pages, selection and widgets as cells. The guide to tables starts at
    [Term::Fabulous::Manual::Tables](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual%3A%3ATables), which has a feature index of its
    own.

- [Term::Fabulous::Widget::Table::Column](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AColumn)

    What a table column shows and how: its parameters in full.

- [Term::Fabulous::Widget::Table::Mutator](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AMutator)

    Ready-made mutators that format cell values: dates, numbers, sizes,
    durations, flags, lookups.

- [Term::Fabulous::Widget::Table::Filter](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AFilter)

    Filter conditions on numbers, dates and text, their combinations, and
    the notation of the filter row.

- [Term::Fabulous::Widget::Table::Value](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AValue)

    How tables read numbers and dates; natural sorting.

- [Term::Fabulous::Widget::Table::Model](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AModel)

    The rows of a table and the lines it shows, without widgets.

- [Term::Fabulous::Widget::Table::Style](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AStyle), [Term::Fabulous::Widget::Table::Borders](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3ABorders)

    How a table checks its style hashes and works out its grid lines. Used
    internally by the table.

- [Term::Fabulous::Widget::Table::Cell](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3ACell), [Term::Fabulous::Widget::Table::Toggle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AToggle), [Term::Fabulous::Widget::Table::Grid](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AGrid), [Term::Fabulous::Widget::Table::HeaderView](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AHeaderView), [Term::Fabulous::Widget::Table::Scrollbar](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AScrollbar), [Term::Fabulous::Widget::Table::Pager](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3APager), [Term::Fabulous::Widget::Table::ColumnChooser](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATable%3A%3AColumnChooser)

    The widgets a table is built of: cells, the open and close markers,
    the grids, the header, the scrollbar, the page controls and the column
    chooser. Used internally by the table.

## Charts

- [Term::Fabulous::Widget::Chart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AChart)

    What all charts share: title, legend, palettes and themes, colors,
    hover and the `SeriesHover` event.

- [Term::Fabulous::Widget::XYChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AXYChart)

    The reference for charts with an x and a y axis: series and their data
    forms, axes, stacking, curves, rendering styles, transforms, live data.

- [Term::Fabulous::Widget::LineChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ALineChart), [Term::Fabulous::Widget::AreaChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AAreaChart), [Term::Fabulous::Widget::BarChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABarChart), [Term::Fabulous::Widget::ScatterPlot](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScatterPlot)

    The XY charts, each with its default series type: lines, filled areas,
    bars, and points with trend lines.

- [Term::Fabulous::Widget::Histogram](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AHistogram)

    How values are distributed: counts in bins.

- [Term::Fabulous::Widget::Sparkline](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ASparkline)

    A chart without axes, one row high.

- [Term::Fabulous::Widget::PieChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3APieChart), [Term::Fabulous::Widget::DonutChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADonutChart), [Term::Fabulous::Widget::PolarAreaChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3APolarAreaChart)

    Parts of a whole as slices.

- [Term::Fabulous::Widget::RadarChart](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ARadarChart)

    Several values per series on axes around a center.

- [Term::Fabulous::Role::HasSeries](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3AHasSeries)

    Adding, changing and removing the series of a chart and their data.

- [Term::Fabulous::Chart::Transform](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ATransform), [Term::Fabulous::Chart::Curve](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ACurve), [Term::Fabulous::Chart::Easing](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AEasing)

    Steps that prepare the data of a series; the curves between points and
    their easing functions.

- [Term::Fabulous::Chart::Palette](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3APalette), [Term::Fabulous::Chart::Format](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AFormat), [Term::Fabulous::Chart::Marker](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AMarker)

    Palettes and ink colors; number and date labels; the character sets
    charts draw with.

- [Term::Fabulous::Chart::Scale](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AScale), [Term::Fabulous::Chart::Scale::Linear](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AScale%3A%3ALinear), [Term::Fabulous::Chart::Scale::Log](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AScale%3A%3ALog), [Term::Fabulous::Chart::Scale::Time](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AScale%3A%3ATime), [Term::Fabulous::Chart::Scale::Category](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3AScale%3A%3ACategory)

    The scales of chart axes: what they have in common, and numeric,
    logarithmic, date and time, and category axes.

- [Term::Fabulous::Chart::Raster](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ARaster), [Term::Fabulous::Chart::Surface](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ASurface), [Term::Fabulous::Chart::Radial](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ARadial), [Term::Fabulous::Chart::Series](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AChart%3A%3ASeries)

    The machinery behind the charts: subpixel drawing, the cells of a chart
    while it is drawn, the geometry of round charts and the series object;
    for charts of your own.

## Events

- [Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress)

    A key was pressed. Provides readable key names for key bindings.

- [Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse)

    A mouse button was pressed or released, the mouse was dragged, or the
    wheel was turned.

- [Term::Fabulous::Event::MouseMove](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouseMove)

    The mouse pointer moved with no button held.

- [Term::Fabulous::Event::Start](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AStart)

    The terminal is open and its size is known.

- [Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize)

    The terminal changed size.

- [Term::Fabulous::Event::CanvasResize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ACanvasResize)

    A canvas got a new size from the layout.

- [Term::Fabulous::Event::Change](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AChange)

    The user changed the value of an input widget.

- [Term::Fabulous::Event::Submit](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASubmit)

    The user pressed Enter in a text field.

- [Term::Fabulous::Event::Activate](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AActivate)

    The user activated a button, by click or key.

- [Term::Fabulous::Event::Close](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AClose)

    A dialog was closed, or a toast went away.

- [Term::Fabulous::Event::Select](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASelect)

    The user opened or closed an item of an accordion.

- [Term::Fabulous::Event::SeriesHover](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASeriesHover)

    The pointer moved onto another series, point or slice of a chart.

- [Term::Fabulous::Event::CursorMove](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ACursorMove)

    The cursor of a table moved to another line.

- [Term::Fabulous::Event::SelectionChange](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASelectionChange)

    The user changed which rows of a table are selected.

- [Term::Fabulous::Event::RowActivate](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ARowActivate)

    The user pressed Enter on a table row or double-clicked it.

- [Term::Fabulous::Event::SortChange](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASortChange)

    The user changed how a table is sorted.

- [Term::Fabulous::Event::FilterChange](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AFilterChange)

    The user typed into a filter field of a table.

- [Term::Fabulous::Event::PageChange](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3APageChange)

    The user turned the page of a table or chose another page size.

- [Term::Fabulous::Event::Expand](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AExpand), [Term::Fabulous::Event::Collapse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ACollapse)

    The user opened or closed a tree row or a group of a table.

- [Term::Fabulous::Event::ColumnsChange](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AColumnsChange)

    The user showed or hid a table column in the column chooser.

## Colors, borders and text

- [Term::Fabulous::Color](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AColor)

    Color values: parsing color strings, converting between RGB and HSL,
    making colors lighter, darker or mixed.

- [Term::Fabulous::Enum::WebColor](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEnum%3A%3AWebColor)

    The 148 CSS named colors (`Tomato`, `SteelBlue`, ...) as
    Term::Fabulous::Color objects.

- [Term::Fabulous::Enum::BorderStyle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEnum%3A%3ABorderStyle)

    The 20 border styles and their characters.

- [Term::Fabulous::Role::HasBorderStyle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3AHasBorderStyle)

    The per-side border styles of a widget and how borders take space.

- [Term::Fabulous::Unicode](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AUnicode)

    How many terminal columns a piece of text takes, and how text is made
    safe for the terminal.

## Extending Term::Fabulous

These modules matter only if you write widget classes that can be built
from layout files, or your own terminal or output class.

- [Term::Fabulous::Role::CanParseLayout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3ACanParseLayout)

    Makes a widget class usable in KDL layout files.

- [Term::Fabulous::Check](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACheck)

    Checks the values of widget properties, with one wording for each kind
    of value.

- [Term::Fabulous::Role::Terminal](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3ATerminal)

    What the application object needs from a terminal; write your own
    terminal with it.

- [Term::Fabulous::Terminal::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3ATermbox)

    The real terminal, through termbox2: the default terminal.

- [Term::Fabulous::Terminal::Termbox::Cells](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATerminal%3A%3ATermbox%3A%3ACells)

    Sends the drawn cells to the terminal. Used internally by the real
    terminal.

- [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox)

    The termbox2 library itself, compiled into the distribution: the
    `tb_*` functions and `TB_*` constants, and the width functions
    [Term::Fabulous::Unicode](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AUnicode) measures with.

- [Term::Fabulous::Termbox::Event](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox%3A%3AEvent)

    One termbox2 input event, as `tb_peek_event` fills it.

- [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender)

    The role that draws a laid-out widget tree; composed by Term::Fabulous
    and Term::Fabulous::Static.

- [Term::Fabulous::Render::Frame](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AFrame)

    What one frame paints: the paint order, the clip rect of every command
    (the visible part of scroll containers) and the cells every command
    paints, for drawing and for finding the widget under the mouse.

- [Term::Fabulous::Render::Target::Grid](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ATarget%3A%3AGrid)

    Collects the drawn cells in memory.

- [Term::Fabulous::Render::Target::Mask](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ATarget%3A%3AMask)

    The base role of the cell targets: lets a frame keep cells of the
    previous frame, so unchanged canvases are not drawn again.

- [Term::Fabulous::Render::Rectangle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ARectangle), [Term::Fabulous::Render::Border](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ABorder), [Term::Fabulous::Render::Text](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AText), [Term::Fabulous::Render::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ACanvas)

    Draw backgrounds, borders, text and canvases; the canvas painter sends
    only the changed cells when possible.

- [Term::Fabulous::Render::Attr](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AAttr)

    Converts colors into termbox2 color values.

- [Term::Fabulous::Render::Geometry](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AGeometry)

    Converts Clay's layout boxes into terminal cells.

# LIMITATIONS

- A frame lays out and draws the whole screen, whatever changed. Only the
cells that changed are sent to the terminal, but a very large widget
tree costs CPU time on every frame it needs.
- Without the kitty keyboard protocol (see ["new"](#new)), `Alt` plus a key is
recognized when the terminal sends the Escape and the key in one write,
which terminals do. `Escape` followed quickly by a key that arrives in
the same read looks like `Alt` plus that key. `Alt+[` and `Alt+O`
cannot be bound: they begin the escape sequences of other keys. A
terminal that speaks the protocol reports all of these keys without
ambiguity.
- Mouse reports with the buttons 8 to 11 (extra buttons of some mice)
are decoded by termbox2 as the left, middle or right button.
- In inline mode, a terminal that rewraps its lines when it gets narrower
rewraps the region too. Term::Fabulous erases the rewrapped rows it
still finds on the screen, but when they are more than the screen
holds, the terminal pushes the first of them into the scrollback (tmux
does), and the scrollback cannot be erased without erasing the user's
history too: copies of the old region stay there. Output that other
programs write to the terminal while `run` is active also moves the
region away from where Term::Fabulous draws it.
- Clay lays out at most `max_element_count` elements per frame (8192 by
default); every widget is one element and Clay keeps two for
itself. A larger tree makes drawing die with a message that names the
limit; raise `max_element_count` in ["new"](#new).

# SEE ALSO

[Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual), [Term::Fabulous::Cookbook](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook),
[Term::Fabulous::Examples](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AExamples), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI), [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS),
[Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox), [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync), [Object::Pad](https://metacpan.org/pod/Object%3A%3APad).

# BUGS

Please report bugs at
[https://github.com/davenonymous/perl-term-fabulous/issues](https://github.com/davenonymous/perl-term-fabulous/issues).

# AUTHOR

davenonymous <perl@davenonymous.com>

# COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
