# NAME

Term::Fabulous::Manual - The Term::Fabulous user guide

# HOW TO READ THIS MANUAL

This manual explains how Term::Fabulous works and how you use it. This
page is its starting point: it introduces the library, shows a first
program and ends with the ["FEATURE INDEX"](#feature-index), which maps tasks to the
sections, recipes and class pages that describe them. The topics
themselves are on pages of their own, listed under ["CONTENTS"](#contents).

- To learn Term::Fabulous

    Read ["INTRODUCTION"](#introduction) and ["YOUR FIRST PROGRAM"](#your-first-program) on this page, then the
    topic pages in the order of ["CONTENTS"](#contents). Every topic page links to the
    previous and the next page at its top and bottom, so you can read the
    whole manual from start to end.

- To find something

    Look the task up in the ["FEATURE INDEX"](#feature-index). Every topic has its own
    heading, so you can also search a page: with `/` in `perldoc`, or with
    the table of contents on MetaCPAN. Terms the manual uses are defined in
    [Term::Fabulous::Manual::Glossary](Manual/Glossary.md).

The manual is one of four kinds of documentation:

- The manual (this page and its topic pages)

    Explains the concepts: layout, text and colors, events, the keyboard,
    the mouse and the focus, forms, tables, charts, KDL layout files, the
    event loop, testing and writing widgets of your own.

- [Term::Fabulous::Cookbook](Cookbook.md)

    Recipes: complete, runnable programs for common tasks, each with a
    picture and notes on the lines that matter. Its index page lists every
    recipe; the recipes themselves are on fourteen topic pages, from
    [Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md) to
    [Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md).

- [Term::Fabulous::Examples](Examples.md)

    The example programs of the distribution, each with a picture: demo
    programs, one program per widget, and the programs of the cookbook.

- The class pages

    One reference page per class, such as [Term::Fabulous](../../../README.md) (the
    application object), [Term::Fabulous::Widget::Box](Widget/Box.md) or
    [Term::Fabulous::Widget::TextField](Widget/TextField.md). A class page lists every
    constructor parameter, method, event, key, mouse action and KDL
    property of the class. The
    [list of modules](../../../README.md#modules) on the main page names all of
    them, grouped by purpose.

## Conventions

Every example uses subroutine signatures. A complete program starts
with this header, which works on every Perl that Term::Fabulous
supports (5.32.1 and later):

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
```

Shorter snippets leave the header out. A snippet may use variables from
an earlier snippet of the same section, and usually `$root` (the root
widget) and `$ui` (the [Term::Fabulous](../../../README.md) object).

Code in these documents is indented. When you copy an example that
contains a here-document (`<<'KDL'`), remove the indentation from
the line that ends it (`KDL`): Perl recognizes the terminator only at
the start of a line.

# CONTENTS

The manual has these pages, in reading order:

- This page

    ["INTRODUCTION"](#introduction): what Term::Fabulous does, the libraries it builds on,
    and how a frame is drawn. ["REQUIREMENTS"](#requirements), ["YOUR FIRST PROGRAM"](#your-first-program) and
    the ["FEATURE INDEX"](#feature-index).

- [Term::Fabulous::Manual::Layout](Manual/Layout.md)

    The widgets and the widget tree, widget ids, and how the layout engine
    sizes and places widgets: direction, sizing, padding, gaps, alignment,
    flow and stack layouts, floating widgets and equal sizes across the
    tree. Dividers between widgets, accordions whose sections open and
    close, and tabs.

- [Term::Fabulous::Manual::Looks](Manual/Looks.md)

    Text (character strings, wrapping, alignment, wide characters and
    emoji), colors (formats, alpha, the terminal's default colors, lighter
    and darker colors), borders and themes.

- [Term::Fabulous::Manual::Events](Manual/Events.md)

    Events and listeners, bubbling, the keyboard and key names, the focus,
    the mouse, hover and press, and scrolling.

- [Term::Fabulous::Manual::Forms](Manual/Forms.md)

    The input widgets (text fields, text areas, check boxes, radio
    buttons, dropdowns, sliders, star ratings, segmented controls), what
    they have in common, editing text, the clipboard, undo, and complete
    forms.

- [Term::Fabulous::Manual::Feedback](Manual/Feedback.md)

    The widgets that show what the program is doing: progress bars, with
    and without a known extent, spinners, toasts that appear in a corner
    and go away by themselves, and how widgets animate without timers.

- [Term::Fabulous::Manual::Charts](Manual/Charts.md)

    Canvases you draw on yourself, and the chart widgets that draw
    themselves from data.

- [Term::Fabulous::Manual::Tables](Manual/Tables.md)

    The table widget: how it works, rows, columns, display text and
    mutators, widgets in cells, and the feature index of the table.

- [Term::Fabulous::Manual::TableRows](Manual/TableRows.md)

    Tables, continued: sorting, filtering, groups, trees, pages, the
    cursor and the selection.

- [Term::Fabulous::Manual::TableStyles](Manual/TableStyles.md)

    Tables, continued: colors, styles, lines, padding, size, scrolling and
    printing a table.

- [Term::Fabulous::Manual::KDL](Manual/KDL.md)

    Describing the widget tree in a KDL layout file instead of Perl code.

- [Term::Fabulous::Manual::Programs](Manual/Programs.md)

    The event loop, timers and other asynchronous work, quitting, errors,
    output without a terminal, and testing.

- [Term::Fabulous::Manual::CustomWidgets](Manual/CustomWidgets.md)

    Writing widgets of your own.

- [Term::Fabulous::Manual::Troubleshooting](Manual/Troubleshooting.md)

    Solutions to common problems.

- [Term::Fabulous::Manual::Glossary](Manual/Glossary.md)

    The terms used in this documentation.

# INTRODUCTION

Term::Fabulous builds terminal user interfaces in Perl: forms,
dashboards, log viewers, data browsers, editors, games. You describe
the screen as a tree of _widgets_: boxes, text, buttons, input fields,
tables, charts, scrollable areas and canvases. Term::Fabulous sizes and
positions the widgets, draws them, and turns key presses, mouse clicks
and terminal resizes into _events_ that your code reacts to.

A program usually takes over the whole terminal while it runs and gives
it back unchanged when it ends. It can also draw into a few rows below
the shell's output instead, like a prompt (see
["INLINE MODE" in Term::Fabulous](../../../README.md#inline-mode)), or print a widget tree once as text,
without any interaction (see
["RENDERING WITHOUT A TERMINAL" in Term::Fabulous::Manual::Programs](Manual/Programs.md#rendering-without-a-terminal)).

The parts of a program are always the same:

- The widget tree

    The widgets, built in Perl with `new` and `add_child`, or read from a
    KDL layout file. The top of the tree is the _root widget_. See
    [Term::Fabulous::Manual::Layout](Manual/Layout.md).

- Listeners

    Code references registered with `$widget->on( EventName => sub {...} )`
    that run when an event happens: a key press, a click, a changed value.
    See [Term::Fabulous::Manual::Events](Manual/Events.md).

- The application object

    A [Term::Fabulous](../../../README.md) object that holds the tree. Its `run` method opens
    the terminal, runs the event loop and returns when the program should
    end.

Three libraries do the heavy lifting:

- Clay

    A layout engine (used through [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) and [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI)). It decides
    the position and size of every widget from rules such as "fill the
    remaining width" or "be as tall as the content". Term::Fabulous
    measures in terminal cells, so for Clay one unit is one cell.

- termbox2

    A small C library, compiled into [Term::Fabulous::Termbox](Termbox.md), that
    switches the terminal into full-screen mode, reads keys and mouse
    input, and writes characters with 24-bit colors.

- IO::Async

    The event loop ([IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop)). It waits for input, draws the
    screen when something changed, and runs your timers, sockets and child
    processes in the same loop.

You do not need to know these libraries in detail. The manual explains
everything you need from them and links to their documentation for the
rest.

## How a frame is drawn

A _frame_ is one complete layout and drawing of the screen. While [run](../../../README.md#run) is active, Term::Fabulous checks 30 times per
second whether anything changed since the last frame: a widget was
changed through one of its methods, input arrived, the terminal was
resized, or the program asked for a frame with
[invalidate](../../../README.md#invalidate). When nothing changed, nothing is drawn.
When something changed, a frame is drawn in three steps:

1. Clay lays out the widget tree for the current terminal size.
2. Term::Fabulous draws every widget into termbox2's screen buffer:
backgrounds, borders, text and canvases.
3. termbox2 compares the buffer with what the terminal already shows and
sends only the cells that changed.

Because the whole screen is laid out again in every frame, there is no
"redraw" method to call. Change a widget (its text, color, size or
children), and the change is visible in the next frame, at most 1/30
second later. The widget methods tell Term::Fabulous that a frame is
needed; only a widget of your own that draws from state it keeps itself
has to say so (see
[telling Term::Fabulous that something changed](Manual/CustomWidgets.md#telling-term-fabulous-that-something-changed)).

Pointer movement is the one exception to "drawn at the next check":
when frames take long to draw, a frame that only shows the pointer at a
new position is drawn at most at every other check, so that moving the
mouse cannot keep the program busy with nothing but redrawing.

# REQUIREMENTS

- Perl 5.32.1 or later.
- A C compiler. termbox2 ships with the distribution and is compiled into
[Term::Fabulous::Termbox](Termbox.md) when Term::Fabulous is installed, with
truecolor and grapheme cluster support always on; there is no separate
library to install or find.
- A terminal that understands 24-bit ("truecolor") colors. Most modern
terminals do (xterm, GNOME Terminal, Konsole, kitty, iTerm2, Windows
Terminal), and so does tmux with truecolor enabled (see
["Colors are wrong or look washed out" in Term::Fabulous::Manual::Troubleshooting](Manual/Troubleshooting.md#colors-are-wrong-or-look-washed-out)).
In a terminal without truecolor support, the colors come out wrong.
- A UTF-8 locale, for example `LANG=C.UTF-8` or `LANG=en_US.UTF-8`
(`locale -a` lists the installed ones). Without it, wide characters
such as CJK text and emoji cannot be placed correctly, and [run](../../../README.md#run) warns about
it when it starts.
- For mouse support, a terminal that reports mouse events. Nearly all do;
see ["MOUSE" in Term::Fabulous::Manual::Events](Manual/Events.md#mouse) for what is reported.
- Optional: [Imager](https://metacpan.org/pod/Imager), for pictures in [Term::Fabulous::Widget::Image](Widget/Image.md),
with the image libraries (libpng, libjpeg, ...) of the formats you
want to show. Installing Term::Fabulous does not require it; without
it, an image widget shows a notice in its place.

# YOUR FIRST PROGRAM

This program shows a dark blue screen with a framed greeting in the
middle and ends when you press `q`, `Escape` or `Ctrl+C`. It is
shipped as `examples/cookbook/first-program.pl`; run it with
`perl examples/cookbook/first-program.pl` (see
["RUNNING THE EXAMPLES" in Term::Fabulous::Examples](Examples.md#running-the-examples)).

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_grow CLAY_ALIGN_X_CENTER CLAY_ALIGN_Y_CENTER);
use Term::Fabulous;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;

# The root widget fills the whole terminal and centers its child.
my $root = Term::Fabulous::Widget::Box->new(
        background_color => [ 20, 25, 45, 255 ],
        layout           => {
                sizing          => { width => sizing_grow(),       height => sizing_grow() },
                child_alignment => { x     => CLAY_ALIGN_X_CENTER, y      => CLAY_ALIGN_Y_CENTER },
        },
);

# A box with a rounded border, one cell of space left and right of the text.
my $frame = Term::Fabulous::Widget::Box->new(
        border_width => 1,
        border_style => Term::Fabulous::Enum::BorderStyle->Round,
        border_color => [ 120, 170, 255, 255 ],
        layout       => { padding => { left => 1, right => 1 } },
);
$frame->add_child(
        Term::Fabulous::Widget::Text->new(
                text       => 'Hello, terminal! Press q to quit.',
                text_color => [ 255, 255, 255, 255 ],
        )
);
$root->add_child($frame);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

# Nothing has the keyboard focus, so key presses go to the root widget.
$root->on(
        KeyPress => sub ($event) {
                my $name = $event->key_name // '';
                $ui->loop->stop if $name eq 'q' || $name eq 'Escape';
                return;
        }
);

$ui->run;    # returns when the loop stops
say 'Bye!';
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-first-program.svg" alt="The first program: a greeting in a box with a rounded blue border, centered on a dark blue screen"></p>
</div>

What happens here:

- [Term::Fabulous::Widget::Box](Widget/Box.md) is the general container. It can have a
background color, a border and any number of children.
- The `layout` hash tells Clay how to size and arrange the box and its
children (see ["LAYOUT" in Term::Fabulous::Manual::Layout](Manual/Layout.md#layout)).
`sizing_grow()` means "take all the room the parent offers"; a box
without `sizing` is as big as its content. `child_alignment` centers
the children (see
["Aligning and centering children" in Term::Fabulous::Manual::Layout](Manual/Layout.md#aligning-and-centering-children)).
- [Term::Fabulous::Widget::Text](Widget/Text.md) shows one piece of text. Colors are
`[red, green, blue, alpha]` arrays with values from 0 to 255; color
strings such as `'#78aaff'` work too (see
["COLORS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#colors)). The border style comes from
[Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) (see
["BORDERS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#borders)).
- `Term::Fabulous->new` takes the root widget and an initial size.
`width` and `height` are required, but `run` replaces them with the
real terminal size.
- `$root->on( KeyPress => sub { ... } )` registers a _listener_:
code that runs when the event happens (see
["EVENTS" in Term::Fabulous::Manual::Events](Manual/Events.md#events)). Key presses go to the widget
that has the keyboard focus, or to the root widget when no widget has
it, as here. `key_name` returns a readable name of the key, such as
`q`, `Escape` or `Ctrl+Left` (see
["KEYBOARD" in Term::Fabulous::Manual::Events](Manual/Events.md#keyboard)).
- `$ui->run` opens the terminal, handles input and draws frames until
the loop stops: when a listener calls `$ui->loop->stop`, when the
user presses `Ctrl+C`, or when the process receives `SIGINT`,
`SIGTERM` or `SIGHUP`. Then it restores the terminal and returns, and
the program prints `Bye!` on the normal screen.
- Quitting on `Escape` does not catch `Alt` plus a letter: terminals
send that as `Escape` followed by the letter, in one write, and
Term::Fabulous names it `Alt+x` (see
["Key names" in Term::Fabulous::Manual::Events](Manual/Events.md#key-names)).

Where to go next: [Term::Fabulous::Manual::Layout](Manual/Layout.md) explains the widget
tree and the layout, and
the recipe
[A minimal program to start from](Cookbook/GettingStarted.md#a-minimal-program-to-start-from)
is a program to start your own from.

# FEATURE INDEX

Where to find what, by task. Each entry names the section of the manual
that explains the feature, the recipes that show it in a complete
program, and the class pages with the reference.

## Programs and the event loop

- Start a full-screen application

    ["YOUR FIRST PROGRAM"](#your-first-program), ["run" in Term::Fabulous](../../../README.md#run),
    ["A minimal program to start from" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#a-minimal-program-to-start-from).

- Quit the program on a key

    ["Quitting" in Term::Fabulous::Manual::Programs](Manual/Programs.md#quitting),
    ["Quit with q or Escape" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#quit-with-q-or-escape).

- Ask for input below the shell's output instead of taking the whole screen (inline mode)

    ["INLINE MODE" in Term::Fabulous](../../../README.md#inline-mode),
    ["Ask for input below the shell's output (inline mode)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#ask-for-input-below-the-shell-s-output-inline-mode).

- Timers, animation, background work, sockets, child processes

    ["Timers and other asynchronous work" in Term::Fabulous::Manual::Programs](Manual/Programs.md#timers-and-other-asynchronous-work),
    ["Update the screen from a timer (a clock)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#update-the-screen-from-a-timer-a-clock),
    ["Show the output of a running command" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#show-the-output-of-a-running-command).

- React to the terminal size and to resizes

    ["Event reference" in Term::Fabulous::Manual::Events](Manual/Events.md#event-reference) (`Start`, `Resize`),
    [Term::Fabulous::Event::Start](Event/Start.md), [Term::Fabulous::Event::Resize](Event/Resize.md),
    ["Change the layout with the terminal size (Start and Resize events)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#change-the-layout-with-the-terminal-size-start-and-resize-events).

- Errors, crashes, restoring the terminal

    ["Errors and terminal restore" in Term::Fabulous::Manual::Programs](Manual/Programs.md#errors-and-terminal-restore).

- Draw a frame now, or after the next frame

    ["invalidate" in Term::Fabulous](../../../README.md#invalidate), ["after\_draw" in Term::Fabulous::Render](Render.md#after_draw).

## Widgets, layout and the widget tree

- Which widgets there are

    ["The widgets" in Term::Fabulous::Manual::Layout](Manual/Layout.md#the-widgets), ["MODULES" in Term::Fabulous](../../../README.md#modules).

- Build, change and search the widget tree; widget ids

    ["Building the tree" in Term::Fabulous::Manual::Layout](Manual/Layout.md#building-the-tree),
    ["Widget ids" in Term::Fabulous::Manual::Layout](Manual/Layout.md#widget-ids),
    ["Changing the tree" in Term::Fabulous::Manual::Layout](Manual/Layout.md#changing-the-tree),
    ["Find widgets by id" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#find-widgets-by-id),
    [Term::Fabulous::Widget](Widget.md).

- Arrange widgets in rows and columns; sizes, padding and gaps

    ["LAYOUT" in Term::Fabulous::Manual::Layout](Manual/Layout.md#layout), [Term::Fabulous::Widget::Box](Widget/Box.md).

- Center something

    ["Aligning and centering children" in Term::Fabulous::Manual::Layout](Manual/Layout.md#aligning-and-centering-children),
    ["Alignment" in Term::Fabulous::Manual::Looks](Manual/Looks.md#alignment).

- Let widgets wrap onto the next line, or stack them on top of each other

    ["Flow layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#flow-layout),
    ["Stack layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#stack-layout).

- Place a widget over the others (floating widgets, overlays)

    ["Floating widgets" in Term::Fabulous::Manual::Layout](Manual/Layout.md#floating-widgets),
    ["floating" in Term::Fabulous::Widget](Widget.md#floating).

- Give widgets in different places the same width or height

    ["Equal sizes across the tree" in Term::Fabulous::Manual::Layout](Manual/Layout.md#equal-sizes-across-the-tree),
    ["Line up labels with equal widths (width\_group)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#line-up-labels-with-equal-widths-width_group).

- Change the layout while the program runs

    ["Changing the layout at run time" in Term::Fabulous::Manual::Layout](Manual/Layout.md#changing-the-layout-at-run-time).

- Scroll content that is larger than its box; scroll it from code

    ["Scrolling content" in Term::Fabulous::Manual::Layout](Manual/Layout.md#scrolling-content),
    ["SCROLLING" in Term::Fabulous::Manual::Events](Manual/Events.md#scrolling),
    [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md),
    ["bounding\_box, scroll\_state, scroll\_to" in Term::Fabulous](../../../README.md#bounding_box-scroll_state-scroll_to),
    ["Add lines to a scrolling log (ScrollBox)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#add-lines-to-a-scrolling-log-scrollbox),
    ["Scroll a ScrollBox from code (keep a log at the newest line)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#scroll-a-scrollbox-from-code-keep-a-log-at-the-newest-line).

- Mark widgets with states and classes and style them by those

    ["add\_state" in Term::Fabulous::Widget](Widget.md#add_state),
    ["Mark widgets with states and classes" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#mark-widgets-with-states-and-classes).

- Draw a line between widgets, with a heading on it

    ["DIVIDERS" in Term::Fabulous::Manual::Layout](Manual/Layout.md#dividers), [Term::Fabulous::Widget::Divider](Widget/Divider.md).

- Sections that open and close under their headers (an accordion)

    ["ACCORDIONS" in Term::Fabulous::Manual::Layout](Manual/Layout.md#accordions),
    [Term::Fabulous::Widget::Accordion](Widget/Accordion.md), [Term::Fabulous::Event::Select](Event/Select.md).

- Pages behind a row of tabs, on any side of the page

    ["TABS" in Term::Fabulous::Manual::Layout](Manual/Layout.md#tabs), [Term::Fabulous::Widget::Tabs](Widget/Tabs.md),
    [Term::Fabulous::Widget::Tabs::Page](Widget/Tabs/Page.md), [Term::Fabulous::Event::Select](Event/Select.md).

## Text, colors and borders

- Show text; wrap, align and space it; bold, italic and underlined text

    ["TEXT" in Term::Fabulous::Manual::Looks](Manual/Looks.md#text),
    ["Bold, italic and underline" in Term::Fabulous::Manual::Looks](Manual/Looks.md#bold-italic-and-underline),
    [Term::Fabulous::Widget::Text](Widget/Text.md),
    ["Wrap, align and space text" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#wrap-align-and-space-text).

- Non-ASCII text, wide characters, emoji, combining characters

    ["Text is character strings" in Term::Fabulous::Manual::Looks](Manual/Looks.md#text-is-character-strings),
    ["Wide characters and emoji" in Term::Fabulous::Manual::Looks](Manual/Looks.md#wide-characters-and-emoji),
    [Term::Fabulous::Unicode](Unicode.md),
    ["Show non-ASCII text (umlauts, CJK, combining accents)" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#show-non-ascii-text-umlauts-cjk-combining-accents).

- Colors and color strings; lighter, darker and mixed colors

    ["COLORS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#colors), [Term::Fabulous::Color](Color.md).

- Themes: colors and border styles for every widget, theme files, variants, switching at run time

    ["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes), [Term::Fabulous::Theme](Theme.md),
    ["Switch themes at run time (built-in themes and a theme file)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#switch-themes-at-run-time-built-in-themes-and-a-theme-file),
    ["theme" in Term::Fabulous](../../../README.md#theme).

- Named colors (Tomato, SteelBlue, ...)

    [Term::Fabulous::Enum::WebColor](Enum/WebColor.md).

- Transparent and translucent backgrounds; the terminal's default colors

    ["Alpha and the terminal default color" in Term::Fabulous::Manual::Looks](Manual/Looks.md#alpha-and-the-terminal-default-color).

- Borders on all or some sides, border styles, a different style per side

    ["BORDERS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#borders),
    ["Border width and space" in Term::Fabulous::Manual::Looks](Manual/Looks.md#border-width-and-space),
    [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md),
    [Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md),
    ["Use a different border style on each side" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#use-a-different-border-style-on-each-side).

## Events, keyboard, focus and mouse

- Listen to events; stop an event from reaching the parent widgets

    ["Listening to events" in Term::Fabulous::Manual::Events](Manual/Events.md#listening-to-events),
    ["Return values and bubbling" in Term::Fabulous::Manual::Events](Manual/Events.md#return-values-and-bubbling).

- The list of all events

    ["Event reference" in Term::Fabulous::Manual::Events](Manual/Events.md#event-reference), ["EVENTS" in Term::Fabulous](../../../README.md#events).

- Fire events of your own

    ["Firing your own events" in Term::Fabulous::Manual::Events](Manual/Events.md#firing-your-own-events),
    ["Fire your own events" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#fire-your-own-events).

- React to keys; key bindings and shortcuts

    ["KEYBOARD" in Term::Fabulous::Manual::Events](Manual/Events.md#keyboard),
    ["KEY NAMES" in Term::Fabulous::Event::KeyPress](Event/KeyPress.md#key-names),
    ["Bind a key to an action" in Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md#bind-a-key-to-an-action).

- Keys that only some terminals can tell apart (Ctrl+I and Tab, Super, F13 and up)

    ["THE KITTY KEYBOARD PROTOCOL" in Term::Fabulous::Event::KeyPress](Event/KeyPress.md#the-kitty-keyboard-protocol),
    ["new" in Term::Fabulous](../../../README.md#new) (`kitty_keyboard`).

- Move or set the keyboard focus; react to focus changes

    ["FOCUS" in Term::Fabulous::Manual::Events](Manual/Events.md#focus),
    ["KEYBOARD AND FOCUS" in Term::Fabulous](../../../README.md#keyboard-and-focus),
    ["Show a status line that follows the focus (OnFocus)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#show-a-status-line-that-follows-the-focus-onfocus).

- Change the Tab order

    ["Custom focus order" in Term::Fabulous::Manual::Events](Manual/Events.md#custom-focus-order),
    ["Change the Tab order (HasFocusOrder)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#change-the-tab-order-hasfocusorder).

- Buttons, clicks, hover and press

    ["Clicks, hover and press" in Term::Fabulous::Manual::Events](Manual/Events.md#clicks-hover-and-press),
    [Term::Fabulous::Widget::Button](Widget/Button.md),
    ["Add buttons for the mouse and the keyboard (Button)" in Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button).

- Low-level mouse handling: buttons, dragging, pointer movement

    ["MOUSE" in Term::Fabulous::Manual::Events](Manual/Events.md#mouse), [Term::Fabulous::Event::Mouse](Event/Mouse.md),
    [Term::Fabulous::Event::MouseMove](Event/MouseMove.md),
    ["Paint with the mouse (Canvas, clicks and drags)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#paint-with-the-mouse-canvas-clicks-and-drags).

- Mouse wheel

    ["SCROLLING" in Term::Fabulous::Manual::Events](Manual/Events.md#scrolling),
    ["MOUSE WHEEL SCROLLING" in Term::Fabulous](../../../README.md#mouse-wheel-scrolling).

- Let the terminal keep the mouse, so the user can select and copy text

    ["new" in Term::Fabulous](../../../README.md#new) (`mouse`),
    ["Let the terminal handle the mouse (select and copy text)" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#let-the-terminal-handle-the-mouse-select-and-copy-text).

- Dialogs and modal windows

    [Term::Fabulous::Widget::Dialog](Widget/Dialog.md),
    ["Ask a question in a dialog (Dialog widget)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget).

## Forms and input

- The input widgets and what they have in common

    ["FORMS AND INPUT WIDGETS" in Term::Fabulous::Manual::Forms](Manual/Forms.md#forms-and-input-widgets),
    [Term::Fabulous::Widget::Input](Widget/Input.md).

- Text input, password fields, multi-line text

    ["Text fields" in Term::Fabulous::Manual::Forms](Manual/Forms.md#text-fields),
    ["Password fields" in Term::Fabulous::Manual::Forms](Manual/Forms.md#password-fields),
    ["Text areas" in Term::Fabulous::Manual::Forms](Manual/Forms.md#text-areas),
    [Term::Fabulous::Widget::TextField](Widget/TextField.md), [Term::Fabulous::Widget::TextArea](Widget/TextArea.md),
    ["A login form (centered dialog, masked password)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#a-login-form-centered-dialog-masked-password).

- Check boxes, radio buttons, dropdowns, sliders, star ratings, segmented controls

    ["THE INPUT WIDGETS ONE BY ONE" in Term::Fabulous::Manual::Forms](Manual/Forms.md#the-input-widgets-one-by-one),
    ["Choose from options in Perl (Dropdown, RadioGroup, Slider)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#choose-from-options-in-perl-dropdown-radiogroup-slider),
    [Term::Fabulous::Widget::StarRating](Widget/StarRating.md), [Term::Fabulous::Widget::SegmentedControl](Widget/SegmentedControl.md).

- Read the values of a form; react to changes and to Enter

    ["Values" in Term::Fabulous::Manual::Forms](Manual/Forms.md#values),
    ["The Change and Submit events" in Term::Fabulous::Manual::Forms](Manual/Forms.md#the-change-and-submit-events),
    ["Read all values of a form" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#read-all-values-of-a-form).

- Disable inputs, make text read-only

    ["Disabled inputs" in Term::Fabulous::Manual::Forms](Manual/Forms.md#disabled-inputs),
    ["Read-only text" in Term::Fabulous::Manual::Forms](Manual/Forms.md#read-only-text),
    ["Disable inputs until a checkbox is checked" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked).

- Editing keys, selection, clipboard, undo

    ["EDITING TEXT" in Term::Fabulous::Manual::Forms](Manual/Forms.md#editing-text),
    ["KEYS OF THE INPUT WIDGETS" in Term::Fabulous::Manual::Forms](Manual/Forms.md#keys-of-the-input-widgets),
    [Term::Fabulous::Editor](Editor.md),
    ["Copy and paste through the clipboard" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#copy-and-paste-through-the-clipboard).

- Check what the user typed

    ["Checking input" in Term::Fabulous::Manual::Forms](Manual/Forms.md#checking-input).

## Progress and feedback

- Show how much of a task is done; a bar for a task of unknown extent

    ["PROGRESS BARS" in Term::Fabulous::Manual::Feedback](Manual/Feedback.md#progress-bars),
    [Term::Fabulous::Widget::ProgressBar](Widget/ProgressBar.md).

- Show that the program is busy (a spinner)

    ["SPINNERS" in Term::Fabulous::Manual::Feedback](Manual/Feedback.md#spinners),
    [Term::Fabulous::Widget::Spinner](Widget/Spinner.md).

- Show a notification that goes away by itself (a toast); an alert box

    ["TOASTS AND ALERTS" in Term::Fabulous::Manual::Feedback](Manual/Feedback.md#toasts-and-alerts),
    [Term::Fabulous::Widget::Toast](Widget/Toast.md).

- Animate a widget without a timer

    ["ANIMATION" in Term::Fabulous::Manual::Feedback](Manual/Feedback.md#animation),
    ["ANIMATION" in Term::Fabulous::Widget::Display](Widget/Display.md#animation),
    ["request\_frame\_at" in Term::Fabulous](../../../README.md#request_frame_at).

## Tables

- Show rows of data in a table

    ["TABLES" in Term::Fabulous::Manual::Tables](Manual/Tables.md#tables),
    [Term::Fabulous::Widget::Table](Widget/Table.md),
    ["Show a list of hashes in a table (sort, select, open a row)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row).

- Every table feature, by task

    The table's own feature index: ["FEATURE INDEX" in Term::Fabulous::Manual::Tables](Manual/Tables.md#feature-index).

- Columns: widths, alignment, wrapping, computed columns, the visible columns

    ["COLUMNS" in Term::Fabulous::Manual::Tables](Manual/Tables.md#columns),
    [Term::Fabulous::Widget::Table::Column](Widget/Table/Column.md),
    ["Size, align and wrap columns (widths, wrapping, widget titles)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#size-align-and-wrap-columns-widths-wrapping-widget-titles),
    ["Let the user choose the visible columns (column chooser)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#let-the-user-choose-the-visible-columns-column-chooser).

- Format dates, numbers and sizes in cells

    ["DISPLAY TEXT AND MUTATORS" in Term::Fabulous::Manual::Tables](Manual/Tables.md#display-text-and-mutators),
    [Term::Fabulous::Widget::Table::Mutator](Widget/Table/Mutator.md),
    ["Format cells: dates, numbers, sizes and flags (mutators)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#format-cells-dates-numbers-sizes-and-flags-mutators).

- Widgets in cells; edit the data of a table

    ["CELL WIDGETS" in Term::Fabulous::Manual::Tables](Manual/Tables.md#cell-widgets),
    ["Changing the data" in Term::Fabulous::Manual::Tables](Manual/Tables.md#changing-the-data),
    ["Edit the data of a table (widget cells, add and remove rows and columns)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#edit-the-data-of-a-table-widget-cells-add-and-remove-rows-and-columns).

- Sort and filter rows

    ["SORTING" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#sorting),
    ["FILTERING" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#filtering),
    [Term::Fabulous::Widget::Table::Filter](Widget/Table/Filter.md),
    ["Sort rows, also with your own comparison" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#sort-rows-also-with-your-own-comparison),
    ["Let the user filter rows (filter row and search box)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#let-the-user-filter-rows-filter-row-and-search-box),
    ["Filter rows from Perl (numbers, dates, text, raw or shown values)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#filter-rows-from-perl-numbers-dates-text-raw-or-shown-values).

- Group rows, trees of nested rows, pages

    ["GROUPING" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#grouping),
    ["TREES" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#trees),
    ["PAGES" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#pages),
    ["Group rows by a column (collapsible group headers)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#group-rows-by-a-column-collapsible-group-headers),
    ["Show nested data as a tree (expand and collapse rows)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#show-nested-data-as-a-tree-expand-and-collapse-rows),
    ["Split many rows into pages (pager and page sizes)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#split-many-rows-into-pages-pager-and-page-sizes).

- The cursor, selecting rows, opening a row

    ["SELECTION AND CURSOR" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#selection-and-cursor).

- Colors, striped rows, lines and styles of rows, columns and cells

    ["STYLES AND BORDERS" in Term::Fabulous::Manual::TableStyles](Manual/TableStyles.md#styles-and-borders),
    ["Lines and colors per row, column and cell (conditional formatting)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#lines-and-colors-per-row-column-and-cell-conditional-formatting),
    ["A table with colored rows and titles (block frame, no grid lines)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#a-table-with-colored-rows-and-titles-block-frame-no-grid-lines),
    ["Compare the line options of a table (frames, grid lines, block frames)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#compare-the-line-options-of-a-table-frames-grid-lines-block-frames).

- Print a table as a report

    ["PRINTING A TABLE" in Term::Fabulous::Manual::TableStyles](Manual/TableStyles.md#printing-a-table),
    ["Print a table as a report (Static)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#print-a-table-as-a-report-static).

## Canvases and charts

- Draw freely in character cells or pixels

    ["CANVASES" in Term::Fabulous::Manual::Charts](Manual/Charts.md#canvases),
    [Term::Fabulous::Widget::Canvas](Widget/Canvas.md), [Term::Fabulous::Widget::PixelCanvas](Widget/PixelCanvas.md),
    ["Plot data on a pixel canvas (PixelCanvas)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#plot-data-on-a-pixel-canvas-pixelcanvas).

- Show a picture (PNG, JPEG, GIF, ...)

    [Term::Fabulous::Widget::Image](Widget/Image.md),
    ["Show a picture file (Image, fit)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#show-a-picture-file-image-fit),
    ["Embed a logo in the program (Image, base64)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#embed-a-logo-in-the-program-image-base64).

- Charts that draw themselves from data

    ["CHARTS" in Term::Fabulous::Manual::Charts](Manual/Charts.md#charts), [Term::Fabulous::Widget::Chart](Widget/Chart.md).

- Chart titles and legends

    ["Titles and legends" in Term::Fabulous::Manual::Charts](Manual/Charts.md#titles-and-legends),
    ["Title and legend" in Term::Fabulous::Widget::Chart](Widget/Chart.md#title-and-legend).

- Line, area, bar and scatter charts

    [Term::Fabulous::Widget::XYChart](Widget/XYChart.md),
    ["Draw a line chart with labels and points (LineChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#draw-a-line-chart-with-labels-and-points-linechart),
    ["Grouped, stacked and horizontal bars (BarChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#grouped-stacked-and-horizontal-bars-barchart),
    ["A scatter plot with trend lines (ScatterPlot)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#a-scatter-plot-with-trend-lines-scatterplot).

- Axes: ranges, ticks, titles and number or date formats of the labels

    ["AXES" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#axes),
    ["Axis keys" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#axis-keys),
    [Term::Fabulous::Chart::Format](Chart/Format.md).

- Stacked bars and areas, shares of 100% (percent stacking)

    ["STACKING" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#stacking),
    ["Grouped, stacked and horizontal bars (BarChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#grouped-stacked-and-horizontal-bars-barchart),
    ["Stacked areas and shares of 100% (AreaChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#stacked-areas-and-shares-of-100-areachart),
    ["Line styles, gaps, bar widths, stack groups and grid lines" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#line-styles-gaps-bar-widths-stack-groups-and-grid-lines).

- Time axes and logarithmic axes

    ["Time axes" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#time-axes),
    ["Logarithmic axes" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#logarithmic-axes),
    ["Plot values over time (time axis, from and to, a dashed forecast)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#plot-values-over-time-time-axis-from-and-to-a-dashed-forecast),
    ["Show values of very different sizes (logarithmic axis)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#show-values-of-very-different-sizes-logarithmic-axis).

- Pie, donut, polar area and radar charts

    [Term::Fabulous::Widget::PieChart](Widget/PieChart.md), [Term::Fabulous::Widget::DonutChart](Widget/DonutChart.md),
    [Term::Fabulous::Widget::PolarAreaChart](Widget/PolarAreaChart.md), [Term::Fabulous::Widget::RadarChart](Widget/RadarChart.md),
    ["Show shares as a pie or donut (PieChart, DonutChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#show-shares-as-a-pie-or-donut-piechart-donutchart),
    ["Compare profiles on radar and polar area charts (RadarChart, PolarAreaChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#compare-profiles-on-radar-and-polar-area-charts-radarchart-polarareachart).

- Histograms and sparklines

    [Term::Fabulous::Widget::Histogram](Widget/Histogram.md), [Term::Fabulous::Widget::Sparkline](Widget/Sparkline.md),
    ["How values are distributed (Histogram)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#how-values-are-distributed-histogram),
    ["Show sparklines in table cells (Sparkline)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#show-sparklines-in-table-cells-sparkline).

- Live charts; smoothing and other transforms of chart data

    ["DATA" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#data), [Term::Fabulous::Chart::Transform](Chart/Transform.md),
    ["A live chart that follows new data (append, max\_points, span)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#a-live-chart-that-follows-new-data-append-max_points-span),
    ["Smooth noisy data and index it to 100 (transforms)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#smooth-noisy-data-and-index-it-to-100-transforms).

- Curves, markers, line styles, palettes and light backgrounds

    ["LOOKS" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#looks), [Term::Fabulous::Chart::Curve](Chart/Curve.md),
    [Term::Fabulous::Chart::Marker](Chart/Marker.md), [Term::Fabulous::Chart::Palette](Chart/Palette.md),
    ["Connect points with curves and easings (curve)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#connect-points-with-curves-and-easings-curve),
    ["Draw with Braille, blocks or box lines (marker)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#draw-with-braille-blocks-or-box-lines-marker),
    ["Light backgrounds, palettes and colors of your own" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#light-backgrounds-palettes-and-colors-of-your-own),
    ["Line styles, gaps, bar widths, stack groups and grid lines" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#line-styles-gaps-bar-widths-stack-groups-and-grid-lines).

- Show what the pointer is on in a chart (hover)

    ["Hover and emphasis" in Term::Fabulous::Widget::Chart](Widget/Chart.md#hover-and-emphasis),
    [Term::Fabulous::Event::SeriesHover](Event/SeriesHover.md),
    ["Show details of the point under the pointer (SeriesHover, highlight)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#show-details-of-the-point-under-the-pointer-serieshover-highlight).

## Layout files

- Describe the screen in a KDL file

    ["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](Manual/KDL.md#kdl-layout-files), [Term::Fabulous::Layout](Layout.md),
    ["Build a form from a KDL file (text fields, radio buttons, dropdown, slider, checkbox)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox).

- The KDL properties of each widget

    The KDL PROPERTIES section of every class page, for example
    ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Widget/Box.md#kdl-properties);
    the [list of node types](Layout.md#node-types) links to all
    of them.

- Tables and charts in a KDL file

    ["Describe a table in a KDL layout (columns, lines, sort, groups)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#describe-a-table-in-a-kdl-layout-columns-lines-sort-groups),
    ["Describe charts in a KDL layout (series, slices, transforms)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#describe-charts-in-a-kdl-layout-series-slices-transforms).

## Output without a terminal, tests and pictures

- Print boxes, tables and charts to STDOUT or a file (reports)

    ["RENDERING WITHOUT A TERMINAL" in Term::Fabulous::Manual::Programs](Manual/Programs.md#rendering-without-a-terminal),
    [Term::Fabulous::Static](Static.md),
    ["Render a report to a file or pipe (Static)" in Term::Fabulous::Cookbook::Output](Cookbook/Output.md#render-a-report-to-a-file-or-pipe-static),
    ["Print a table as a report (Static)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#print-a-table-as-a-report-static),
    ["Print charts in a report (Static)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#print-charts-in-a-report-static).

- Test a program or a widget without a terminal

    ["TESTING" in Term::Fabulous::Manual::Programs](Manual/Programs.md#testing),
    [Term::Fabulous::Terminal::Memory](Terminal/Memory.md), ["step" in Term::Fabulous](../../../README.md#step),
    ["Test a widget without a terminal" in Term::Fabulous::Cookbook::Output](Cookbook/Output.md#test-a-widget-without-a-terminal).

- Take a screenshot of your program

    ["PICTURES OF YOUR OWN PROGRAMS" in Term::Fabulous::Examples](Examples.md#pictures-of-your-own-programs).

## Extending Term::Fabulous

- Write widgets of your own

    ["WRITING YOUR OWN WIDGETS" in Term::Fabulous::Manual::CustomWidgets](Manual/CustomWidgets.md#writing-your-own-widgets),
    [Term::Fabulous::Widget::Input](Widget/Input.md),
    ["Write a custom input widget (a toggle switch)" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch).

- Use your own widgets in KDL layout files

    [Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md),
    ["Make a widget usable from KDL" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#make-a-widget-usable-from-kdl).

- Check property values the way the built-in widgets do

    [Term::Fabulous::Check](Check.md).

- Run on another terminal, or write a terminal of your own

    ["new" in Term::Fabulous](../../../README.md#new) (`terminal`), [Term::Fabulous::Terminal::Termbox](Terminal/Termbox.md),
    [Term::Fabulous::Role::Terminal](Role/Terminal.md).

- Use termbox2 directly

    [Term::Fabulous::Termbox](Termbox.md).

## Help

- Something does not work

    ["TROUBLESHOOTING" in Term::Fabulous::Manual::Troubleshooting](Manual/Troubleshooting.md#troubleshooting).

- A term in the documentation is unclear

    [Term::Fabulous::Manual::Glossary](Manual/Glossary.md).

- What Term::Fabulous cannot do

    ["LIMITATIONS" in Term::Fabulous](../../../README.md#limitations).

# SEE ALSO

Next page: [Term::Fabulous::Manual::Layout](Manual/Layout.md).

[Term::Fabulous](../../../README.md), [Term::Fabulous::Cookbook](Cookbook.md),
[Term::Fabulous::Examples](Examples.md), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI), [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS),
[Term::Fabulous::Termbox](Termbox.md), [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync), [Object::Pad](https://metacpan.org/pod/Object%3A%3APad).
