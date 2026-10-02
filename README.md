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
     use Encode qw(encode);
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
                     # Text widgets take UTF-8 bytes; the field's value is a character string.
                     $greeting->text( encode( 'UTF-8', 'Hello, ' . $event->value . '!' ) );
                     return;
             }
     );

     my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
     $ui->interaction->set_focused_widget($name);
     $ui->run;    # returns after Ctrl+C, SIGINT or SIGTERM
```

# DESCRIPTION

Term::Fabulous builds full-screen terminal applications in Perl. You
describe the screen as a tree of widgets (boxes, text, buttons, input
fields, scrollable areas and canvases), in Perl code or in a layout file
written in KDL, a small configuration language ([https://kdl.dev](https://kdl.dev)).
Term::Fabulous sizes and positions the widgets with the Clay layout
engine, draws them with 24-bit colors through the termbox2 library, and
turns key presses, mouse clicks and terminal resizes into events your
code reacts to.

Highlights:

- Flexible layout: rows and columns, growing, fitting, fixed and
percentage sizes, padding, gaps, alignment, borders in 21 styles.
- Input widgets for forms: single- and multi-line text with selection,
undo and a clipboard shared by all text fields of the program; check
boxes; radio buttons; dropdowns; sliders.
- Keyboard focus with Tab and mouse clicks, readable key names for key
bindings (`Ctrl+S`, `Shift+Left`), mouse wheel scrolling.
- Canvases for free drawing, including a half-block pixel canvas with
lines, rectangles and circles.
- Correct handling of Unicode: wide CJK characters, emoji, combining
characters.
- The same widget tree can be printed once as text (with or without
colors) for reports and tests, through [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic).
- Runs on [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync), so timers, sockets and child processes work
alongside the user interface.

This class is the application object: it owns the widget tree, opens the
terminal, runs the event loop, draws the screen 30 times per second and
dispatches input events. It is a subclass of [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

# DOCUMENTATION

- [Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual)

    The user guide. Start here: it explains layout, text, colors, events,
    the keyboard and the mouse, focus, forms, KDL layout files, the event
    loop and writing your own widgets, with examples throughout. Its
    [FEATURE INDEX](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#FEATURE-INDEX) maps tasks to the
    documentation.

- [Term::Fabulous::Cookbook](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook)

    Complete programs for common tasks.

- This page

    The reference for `new`, `run` and the other methods of the
    application object.

- The module pages

    One page per class, listed under ["MODULES"](#modules).

- The `examples` directory of the distribution

    Runnable demo programs.

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
["run"](#run), so you can create the object, set the focus and add timers
first. Unknown parameters die
(`Unrecognised parameters for Term::Fabulous constructor: 'colour'`).

- `root`

    Required. The root widget, the top of the widget tree, usually a
    [Term::Fabulous::Widget::Box](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABox). It receives every event that no other
    widget receives: key presses while nothing has the focus, mouse events
    where no widget is drawn, and every `Resize`. It must therefore be able
    to fire events (compose [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter), as all
    Term::Fabulous widgets except Text do); otherwise `new` dies. A widget
    that was ever attached to another widget cannot be the root.

- `width`

    Required. A positive number: the width of the layout in columns until
    ["run"](#run) starts. `run` replaces it with the terminal's width, and keeps
    it up to date when the terminal is resized.

- `height`

    Required. A positive number: the height of the layout in rows until
    ["run"](#run) starts, then the terminal's height.

- `mouse`

    A boolean. Default: 1. With 1, the terminal reports mouse clicks, drags
    and the wheel to the program (see ["MOUSE" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#MOUSE)). With
    0, the terminal keeps the mouse for itself, so the user can select and
    copy text as usual, and no `Mouse` events are fired.

- `output_mode`

    Optional, and only one value is allowed: `TB_OUTPUT_TRUECOLOR` from
    [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox), the default. Any other value dies. Term::Fabulous always draws
    with 24-bit colors.

- `memory_size`

    Optional, rarely needed. The number of bytes Clay reserves for laying out
    a frame: an integer of at least `Clay::XS::Clay_MinMemorySize()` (about
    6 MB), which is also the default. It does not raise the limit on the
    number of widgets; see ["LIMITATIONS"](#limitations).

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

Opens the terminal in full-screen mode, runs the event loop until it is
stopped, and restores the terminal. It returns nothing.

While it runs:

- the screen is laid out and drawn every 1/30 second (see
["termbox\_draw\_interval"](#termbox_draw_interval)), using the real terminal size;
- terminal input is read as soon as it arrives and dispatched as
`KeyPress` and `Mouse` events (see ["EVENTS"](#events));
- terminal resizes fire `Resize` on the root widget;
- everything else you added to the [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) (IO::Async calls
these objects _notifiers_: timers, sockets, child processes, ...) runs
as usual.

The loop stops, and `run` returns, when:

- your code calls `$ui->loop->stop`;
- the user presses `Ctrl+C` (after its `KeyPress` was fired);
- the process receives `SIGINT` or `SIGTERM`.

If code running inside the loop dies (a listener, a timer), `run`
restores the terminal first and then dies with the same error, so the
message is readable on the normal screen. The terminal is also restored
when code inside the loop calls `exit`. After `run` has returned or
died, the object can be used again and `run` can be called again.

`run` dies with a message starting with `Term::Fabulous:` when the
terminal cannot be opened, for example when the process has no
controlling terminal (`tb_init failed: No such device or address`), or
when the terminal reports a size of 0 columns or rows.

When the locale's character set is not UTF-8, `run` warns (at every
call): `Term::Fabulous: the locale's character set is not UTF-8; wide
characters will be misaligned`.

## loop

```perl
     my $loop = $ui->loop;
     $ui->loop->stop;
```

Returns the [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) of the most recent ["run"](#run), or `undef`
before the first `run`. Call `$ui->loop->stop` from a listener or
timer to end `run`. The loop is IO::Async's process-wide loop: the same
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
(`get_focused_widget`). See ["FOCUS" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#FOCUS). Inherited
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
while ["run"](#run) is active. Writing works like for ["width"](#width). Inherited from
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

## mouse

```perl
     my $enabled = $ui->mouse;
```

Returns the `mouse` constructor parameter. Read only.

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
mouse event. The pointer is reported only on button presses, releases,
drags and wheel turns (see ["What the terminal reports" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#What-the-terminal-reports)),
so this is not the live mouse position. Term::Fabulous
passes it to Clay with every frame, which derives the hover and press
state of the widgets from it.

## termbox\_draw\_interval

```perl
     my $seconds = $ui->termbox_draw_interval;    # 1/30
```

Returns the time between two frames in seconds: 1/30. Read only.

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

Lays out and draws one frame immediately. `run` calls it 30 times per
second, so programs do not need it. It only has a visible effect while
the terminal is open. See ["draw" in Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender#draw).

## Other inherited methods

The class inherits further methods from [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) (`render`,
`widget_for`, `measure_text`) and from [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender)
(`get_last_commands`, `get_last_clip_rects`). Applications rarely need
them; they are documented on those pages.

# EVENTS

`run` fires these events. Each one bubbles from the widget it is fired
on to the root, as described in
["Return values and bubbling" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#Return-values-and-bubbling).

- `KeyPress` ([Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress))

    For every key press, on the focused widget, or on the root widget when
    nothing has the focus.

- `Mouse` ([Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse))

    For every mouse report (button press, release, drag, wheel), on the
    topmost widget that drew something in the cell under the pointer in the
    last frame: its background, its border or its canvas. Text widgets are
    skipped, and so are widgets that draw nothing there. When no widget
    qualifies, the event is fired on the root widget. Content that is
    scrolled out of view in a [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox) is not
    drawn and never receives the event.

- `Resize` ([Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize))

    On the root widget, twice per resize: first with `is_pre_event` true,
    before the new size is applied, then with `is_post_event` true, after
    it. Resizes are debounced (see ["termbox\_resize\_debounce\_interval"](#termbox_resize_debounce_interval)),
    and a size with zero columns or rows is ignored. No `Resize` is fired
    when `run` starts and adopts the terminal's size; see
    [Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize).

Widgets fire further events themselves: `Change` from the input
widgets, `Submit` from [Term::Fabulous::Widget::TextField](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextField),
`CanvasResize` from canvases, and Clay::UI's `OnPress`, `OnRelease`,
`OnHoverStart`, `OnHoverStopped`, `OnFocus`, `OnBlur` and
`OnScroll`. The complete list is in
["Event reference" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#Event-reference).

# KEYBOARD AND FOCUS

Three keys have a fixed meaning. Their `KeyPress` is fired first, like
for any other key, and then:

- `Ctrl+C`

    stops the loop, so ["run"](#run) returns.

- `Tab`

    moves the focus to the next widget that can take it, in tree order,
    wrapping around at the end.

- `Shift+Tab` (key name `BackTab`)

    moves the focus to the previous one.

Listeners cannot prevent these actions.

When the left mouse button is pressed (not dragged), the widget under
the pointer gets the focus, or its nearest ancestor that can take it.
When there is none, the focus is cleared; so clicking an empty area
leaves a text field and closes an open dropdown. This happens before the
`Mouse` event is fired.

See ["KEYBOARD" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#KEYBOARD) and
["FOCUS" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#FOCUS).

# MOUSE WHEEL SCROLLING

Each notch of the mouse wheel scrolls the scroll box under the
pointer (for example a [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox)) by three
rows. Notches that arrive between two frames are added up and applied
when the next frame is drawn. A `Mouse` event is fired for every notch
termbox2 reports (see ["LIMITATIONS"](#limitations) for reports it loses). Widgets that
scroll themselves, like [Term::Fabulous::Widget::TextArea](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextArea), use those
`Mouse` events. Only vertical scrolling is driven by the wheel; there is
no horizontal wheel input.

# MODULES

Every module has its own page. They are grouped here by purpose.

## Application

- [Term::Fabulous](https://metacpan.org/pod/Term%3A%3AFabulous)

    The interactive application object, described on this page.

- [Term::Fabulous::Static](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AStatic)

    Renders a widget tree once, as text, without opening the terminal; for
    reports, command-line output and tests.

- [Term::Fabulous::Layout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ALayout)

    Builds a widget tree from a KDL layout file and documents the layout
    file format.

## Widgets

- [Term::Fabulous::Widget::Box](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ABox)

    The general container, with layout options, a background and a border.

- [Term::Fabulous::Widget::Text](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AText)

    Shows text in one color; wraps and aligns it.

- [Term::Fabulous::Widget::Button](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AButton)

    A box that can take the keyboard focus and reports mouse clicks.

- [Term::Fabulous::Widget::ScrollBox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AScrollBox)

    A box whose content can be larger than the box and scrolls with the
    mouse wheel.

- [Term::Fabulous::Widget::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ACanvas)

    A box with a grid of character cells that you draw into.

- [Term::Fabulous::Widget::PixelCanvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3APixelCanvas)

    A canvas that draws pixels, two per cell, with lines, rectangles and
    circles.

- [Term::Fabulous::Widget](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget)

    The abstract base class of all widgets except Text. Its page describes
    the constructor parameters and methods they all share.

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

- [Term::Fabulous::Widget::Input](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AInput)

    The base class of the input widgets; derive from it to write your own.

- [Term::Fabulous::Widget::TextInput](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ATextInput)

    The base class of TextField and TextArea, with the editing keys and mouse
    selection.

- [Term::Fabulous::Editor](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEditor)

    The text, cursor, selection, undo history and clipboard behind the text
    inputs, without any drawing.

- [Term::Fabulous::Widget::Dropdown::List](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3ADropdown%3A%3AList)

    The list an open dropdown shows. Used internally by the dropdown.

## Events

- [Term::Fabulous::Event::KeyPress](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AKeyPress)

    A key was pressed. Provides readable key names for key bindings.

- [Term::Fabulous::Event::Mouse](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AMouse)

    A mouse button was pressed or released, the mouse was dragged, or the
    wheel was turned.

- [Term::Fabulous::Event::Resize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AResize)

    The terminal changed size.

- [Term::Fabulous::Event::CanvasResize](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ACanvasResize)

    A canvas got a new size from the layout.

- [Term::Fabulous::Event::Change](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3AChange)

    The user changed the value of an input widget.

- [Term::Fabulous::Event::Submit](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEvent%3A%3ASubmit)

    The user pressed Enter in a text field.

## Colors, borders and text

- [Term::Fabulous::Color](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AColor)

    Color values: parsing color strings, converting between RGB and HSL,
    making colors lighter, darker or mixed.

- [Term::Fabulous::Enum::BorderStyle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEnum%3A%3ABorderStyle)

    The 21 border styles and their characters.

- [Term::Fabulous::Role::HasBorderStyle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3AHasBorderStyle)

    The per-side border styles of a widget and how borders take space.

- [Term::Fabulous::Unicode](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AUnicode)

    How many terminal columns a piece of text takes, and how text is made
    safe for the terminal.

- [Term::Fabulous::Enum::WebColor](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AEnum%3A%3AWebColor)

    The 148 CSS named colors (`Tomato`, `SteelBlue`, ...) as
    Term::Fabulous::Color objects.

## Extending Term::Fabulous

These modules matter only if you write widget classes that can be built
from layout files, or your own application or output class.

- [Term::Fabulous::Role::CanParseLayout](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARole%3A%3ACanParseLayout)

    Makes a widget class usable in KDL layout files.

- [Term::Fabulous::Render](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender)

    The role that draws a laid-out widget tree; composed by Term::Fabulous
    and Term::Fabulous::Static.

- [Term::Fabulous::Render::Target::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ATarget%3A%3ATermbox)

    Sends the drawn cells to the terminal.

- [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox)

    The termbox2 library itself, compiled into the distribution: the
    `tb_*` functions and `TB_*` constants, and the width functions
    [Term::Fabulous::Unicode](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AUnicode) measures with.

- [Term::Fabulous::Termbox::Event](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox%3A%3AEvent)

    One termbox2 input event, as `tb_peek_event` fills it.

- [Term::Fabulous::Render::Target::Grid](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ATarget%3A%3AGrid)

    Collects the drawn cells in memory.

- [Term::Fabulous::Render::Target::Mask](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ATarget%3A%3AMask)

    Lets a frame keep cells of the previous frame, so unchanged canvases are
    not drawn again.

- [Term::Fabulous::Render::Rectangle](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ARectangle)

    Draws backgrounds.

- [Term::Fabulous::Render::Border](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ABorder)

    Draws borders.

- [Term::Fabulous::Render::Text](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AText)

    Draws text.

- [Term::Fabulous::Render::Canvas](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3ACanvas)

    Draws canvases, only their changed cells when possible.

- [Term::Fabulous::Render::Clip](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AClip)

    Restricts drawing to the visible part of scroll containers.

- [Term::Fabulous::Render::Attr](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AAttr)

    Converts colors into termbox2 color values.

- [Term::Fabulous::Render::Geometry](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ARender%3A%3AGeometry)

    Converts Clay's layout boxes into terminal cells.

# LIMITATIONS

- The whole screen is laid out and drawn 30 times per second, also when
nothing changed. Only the cells that changed are sent to the terminal,
but very large widget trees cost CPU time.
- termbox2 asks the terminal to report mouse buttons, drags and the wheel,
but not movement without a pressed button, so hover effects follow
clicks, drags and the wheel only.
- The press and release state of the mouse is passed to Clay once per
frame. A click whose press and release both arrive within one frame
(1/30 second), such as a quick touchpad tap, fires its two `Mouse`
events but no `OnPress` and `OnRelease`. Buttons, checkboxes and radio
buttons do not react to it; text inputs, sliders and dropdowns do,
because they act on the `Mouse` event itself.
- When the terminal sends several mouse reports at once (for example
during fast wheel scrolling), termbox2 delivers only the first, so some
wheel notches and fast releases are lost.
- `Alt` plus a printable key cannot be told apart from `Escape` followed
by that key.
- Text widgets take UTF-8 encoded byte strings, while everything else
takes character strings; see ["TEXT" in Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual#TEXT).
- There are no floating windows or dialogs for application use yet; only
the dropdown list floats over other widgets.
- Clay lays out at most 8192 elements per frame; every widget is one
element and Term::Fabulous uses two more, so at most 8190 widgets can
be shown. A larger tree makes drawing die with a misleading Clay error
(`There were still open layout elements when EndLayout was called`).
`memory_size` does not change this limit.

# SEE ALSO

[Term::Fabulous::Manual](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AManual), [Term::Fabulous::Cookbook](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ACookbook), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI),
[Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS), [Term::Fabulous::Termbox](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ATermbox), [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync), [Object::Pad](https://metacpan.org/pod/Object%3A%3APad).

# BUGS

Please report bugs at
[https://github.com/davenonymous/perl-term-fabulous/issues](https://github.com/davenonymous/perl-term-fabulous/issues).

# AUTHOR

davenonymous <perl@davenonymous.com>

# COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
