# NAME

Term::Fabulous::Examples - The example programs of the distribution,
with pictures

# DESCRIPTION

This page lists every example program that comes with Term::Fabulous,
each with a picture of it running. An entry names the program, says
what it shows and which classes it uses, lists the keys it reacts to,
and links to the pages that explain the features it demonstrates.
["RUNNING THE EXAMPLES"](#running-the-examples) shows how to run the programs.

The programs are in three directories, and this page has one section
for each:

- ["THE DEMO PROGRAMS"](#the-demo-programs)

    `examples`: demo programs, each showing one area of Term::Fabulous
    (layout, text and colors, events and forms, KDL layouts, tables,
    charts, output without a terminal).

- ["THE WIDGET GALLERY"](#the-widget-gallery)

    `examples/widgets`: one small program per widget, showing it in its
    typical states. The widget's class page shows the same picture.

- ["THE COOKBOOK PROGRAMS"](#the-cookbook-programs)

    `examples/cookbook`: the complete programs of the recipes in
    [Term::Fabulous::Cookbook](Cookbook.md), grouped like the cookbook pages, and the
    first program of [Term::Fabulous::Manual](Manual.md).

["PICTURES OF YOUR OWN PROGRAMS"](#pictures-of-your-own-programs) shows how to take pictures like these
of your own programs.

The explanations are elsewhere: [Term::Fabulous::Manual](Manual.md) explains the
concepts, [Term::Fabulous::Cookbook](Cookbook.md) explains the cookbook programs
line by line, and every class has a reference page of its own.

Every picture shows a program running in a terminal, taken from the
shipped file after the input that is described next to it. The
pictures are taken again whenever a program changes, so they always
show what the code does.

# RUNNING THE EXAMPLES

The programs need a terminal that uses a UTF-8 locale and supports
24-bit colors (see ["REQUIREMENTS" in Term::Fabulous::Manual](Manual.md#requirements)). Interactive
programs take over the whole terminal; Ctrl+C ends any of them.

To get the files, unpack the distribution, for example with
`cpanm --look Term::Fabulous`. Once Term::Fabulous is installed, run a
program from the unpacked directory:

```sh
perl examples/form.pl
```

Without installing it, build the distribution first and run the
programs with the built copy:

```sh
perl Makefile.PL && make
perl -Mblib examples/form.pl
```

# THE DEMO PROGRAMS

The programs in `examples` show one area of Term::Fabulous each. They
are grouped by topic below.

## A tour of Term::Fabulous

### examples/showcase.pl

A tour on one screen: a form with every input widget and two buttons,
a live chart on a pixel canvas, a log that grows from a timer in a
scroll box, a translucent notification that Save shows for a few
seconds, and text in several scripts. Tab and Shift+Tab move between
the inputs, the mouse works too.

The picture shows it after typing a name and an e-mail address and
pressing Save.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/overview.svg" alt="A Term::Fabulous program: a sign-up form with text fields, radio buttons, a dropdown, a slider, a check box and buttons, a chart of requests per second with a translucent notification, an event log and text in several scripts"></p>
</div>

## Layout

### examples/layout-direction.pl

The four layout directions side by side, each in a bordered panel:
numbered boxes placed left to right, top to bottom, left to right with
wrapping onto a new line, and on top of each other. See
["Direction" in Term::Fabulous::Manual::Layout](Manual/Layout.md#direction).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-layout-direction.svg" alt="Four panels: three boxes side by side, three boxes in a column, seven boxes wrapped onto two lines, and three boxes of different sizes on top of each other"></p>
</div>

### examples/layout-sizing.pl

The sizing rules side by side: every row is a track as wide as the
terminal, and the colored boxes in it are sized with the rule named on
the left (`sizing_fit`, `sizing_fixed`, `sizing_percent`,
`sizing_grow`, with minimums and maximums, and combinations). The
labels share a width group, so the tracks line up. See
["Sizing" in Term::Fabulous::Manual::Layout](Manual/Layout.md#sizing).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-layout-sizing.svg" alt="Eight rows, each a track with colored boxes sized by fit, fit with a minimum, fixed, percent, grow, grow with a maximum, fixed plus grow, and two grow boxes"></p>
</div>

### examples/layout-padding.pl

Padding, the gap between children and the space a border takes: the
same three children in three boxes with different settings. The boxes
have a background, so their padding and gaps are visible. See
["Padding" in Term::Fabulous::Manual::Layout](Manual/Layout.md#padding),
["Gap between children" in Term::Fabulous::Manual::Layout](Manual/Layout.md#gap-between-children) and
["Borders take space" in Term::Fabulous::Manual::Layout](Manual/Layout.md#borders-take-space).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-layout-padding.svg" alt="Three boxes with the same three children: without padding and gap, with padding and a gap of one row, and with a border and one cell of padding"></p>
</div>

### examples/layout-alignment.pl

`child_alignment`: nine boxes of the same size, each with one child,
aligned with every combination of x (left, center, right) and y (top,
center, bottom). See
["Aligning and centering children" in Term::Fabulous::Manual::Layout](Manual/Layout.md#aligning-and-centering-children).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-layout-alignment.svg" alt="Nine boxes in a grid, each with one child placed at a different combination of left, center, right and top, center, bottom"></p>
</div>

### examples/flow.pl

Colored tags in a box with the flow layout: they are placed from left
to right and wrap onto a new line when the row is full, so they rewrap
whenever the terminal is resized. See
["Flow layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#flow-layout).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-flow.svg" alt="Twenty colored tags in a rounded box, wrapped onto several lines"></p>
</div>

### examples/stack.pl

Cards with a badge over their top right corner, and a message centered
over a log, each built from a box with the stack layout: its children
share one box and later ones are drawn on top. See
["Stack layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#stack-layout).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-stack.svg" alt="Three bordered cards with colored badges in their top right corners above a log with a bordered message centered over it"></p>
</div>

### examples/layout-floating.pl

Floating widgets: a menu attached below a button, a badge on the corner
of a panel and a message in the bottom row of the screen. They are drawn
on top of the other widgets and take no space in the layout. The File
button (a click, or Tab and Enter) opens and closes the menu, which is
open when the program starts. See
["Floating widgets" in Term::Fabulous::Manual::Layout](Manual/Layout.md#floating-widgets).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-layout-floating.svg" alt="A File menu open below its button over a panel, a red badge on the panel's top right corner and a green message in the bottom row of the screen"></p>
</div>

### examples/scroll-box.pl

Two [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md) widgets with more lines than
fit, scrolled with the mouse wheel, each with a scrollbar. See
["Scrolling content" in Term::Fabulous::Manual::Layout](Manual/Layout.md#scrolling-content).

The picture shows the boxes after five notches of the wheel on the left
box and two on the right one.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-scroll-box.svg" alt="Two framed boxes scrolled down, one with numbered lines, one with squares, each with a scrollbar in its last column whose thumb shows the visible part"></p>
</div>

## Text, colors and borders

### examples/text-features.pl

[Term::Fabulous::Widget::Text](Widget/Text.md) in detail: the two wrap modes, line
height, bold, italic and underlined text, wide characters, emoji and
combining marks lined up in columns, and control characters made
harmless. See [the text chapter](Manual/Looks.md#text).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-text-features.svg" alt="Text wrapped at spaces in a narrow panel and text broken only at newlines; a two-line text with line height 2; plain, bold, italic, underlined and combined styles; Latin, Japanese, emoji and combining accents ending in the same column; a tab shown as a space and control characters shown as replacement characters"></p>
</div>

### examples/text-sizing.pl

Text in Japanese, Korean, Thai and German with emoji, wrapped to the
width of its box. Wide characters take two columns, and clusters with
combining marks one. See
["Wide characters and emoji" in Term::Fabulous::Manual::Looks](Manual/Looks.md#wide-characters-and-emoji).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-text-sizing.svg" alt="Four boxes with Japanese, Korean, Thai and German text and emoji"></p>
</div>

### examples/colors.pl

[Term::Fabulous::Color](Color.md): one orange written in six formats, colors
derived with `darken`, `lighten` and `blend`, translucent
backgrounds over a light panel, and the terminal's default text color
(alpha 0). See ["Color formats" in Term::Fabulous::Manual::Looks](Manual/Looks.md#color-formats) and
["Working with colors" in Term::Fabulous::Manual::Looks](Manual/Looks.md#working-with-colors).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-colors.svg" alt="Six orange swatches written in different formats; a blue darkened, lightened and blended with white in steps; red swatches with alpha 255, 192, 128, 64 and 0 over a light panel; a line in the terminal's default text color"></p>
</div>

### examples/themes.pl

[Term::Fabulous::Theme](Theme.md): a panel with a text field, a check box, a
progress bar and two buttons under the built-in `dark` and `light`
themes and under `examples/ocean.kdl`, a theme file; F2 switches to
the next theme. The Save button has the class `primary`, which the
ocean theme draws in its accent, and the Cancel button keeps its own
border color under every theme. See
["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-themes.svg" alt="A panel in the ocean theme: teal accents on a deep blue background, a text field holding Ada, a checked check box, a progress bar at 65 percent, a Save button in the accent and a Cancel button with a red border"></p>
</div>

### examples/web-colors.pl

All colors of [Term::Fabulous::Enum::WebColor](Enum/WebColor.md) in a grid that adapts
its columns to the terminal width and scrolls. A dropdown sorts them by
hue, brightness, saturation or name. The mouse wheel and the arrow
keys scroll; Tab focuses the dropdown; q quits while the dropdown does
not have the focus. See ["Named colors" in Term::Fabulous::Manual::Looks](Manual/Looks.md#named-colors).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-web-colors.svg" alt="A grid of color swatches with their hex values and names, and a dropdown to sort them"></p>
</div>

### examples/translucency.pl

Three boxes with translucent backgrounds orbit over a screen of text.
Their backgrounds are blended with the text below them, which shows
through, tinted, or is covered, depending on `glyphs_show_through`.
Space pauses the orbit and g switches `glyphs_show_through` on every
box. See ["Alpha and the terminal default color" in Term::Fabulous::Manual::Looks](Manual/Looks.md#alpha-and-the-terminal-default-color).

The picture shows the orbit after a few seconds.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-translucency.svg" alt="A green, a red and a blue translucent box over a screen of text; the text shows through the green and the blue one"></p>
</div>

### examples/border-showcase.pl

Every border style of [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md), one box
each. See ["Border styles" in Term::Fabulous::Manual::Looks](Manual/Looks.md#border-styles).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-border-showcase.svg" alt="Twenty boxes, one in each border style, labeled with the style's name"></p>
</div>

### examples/border-options.pl

Borders beyond a single style: a border on some sides only, a style per
side, a wider border, a hidden side, two boxes that share one line
through `border_corners`, and a border drawn on the parent's
background with `outer_border_sides`. See
["Border width and space" in Term::Fabulous::Manual::Looks](Manual/Looks.md#border-width-and-space),
["Joining borders" in Term::Fabulous::Manual::Looks](Manual/Looks.md#joining-borders) and
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-border-options.svg" alt="Six bordered panels: a border on the left and top only; a solid border with a double top and a thick left side; a round border of width 2 with an empty cell inside; a round border with a hidden bottom side; a title box and a body box sharing one line; a round border drawn on the parent's background"></p>
</div>

## Events, keys and forms

### examples/event-monitor.pl

Shows the events Term::Fabulous fires: a listener on the root widget
logs every event that bubbles up to it, with the widget it was fired on
(the target). Type into the field, press Tab, Enter, Space, function
keys or Ctrl combinations, and click the widgets: the log shows the key
names, the clicks, the focus moving and the events of the widgets. The
hover events do not bubble, so listeners on the widgets themselves log
them. The line at the bottom follows the mouse pointer. Run it to find
the name of a key on your terminal. See
["Listening to events" in Term::Fabulous::Manual::Events](Manual/Events.md#listening-to-events) and
["Key names" in Term::Fabulous::Manual::Events](Manual/Events.md#key-names).

The picture shows it after Tab, typing `Ada`, Enter, F5, Tab and a
click on the OK button.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-event-monitor.svg" alt="The event monitor after Tab, typing Ada, Enter, F5, Tab and a click on the OK button: the log lists KeyPress, OnFocus, Change, Submit, OnBlur, Mouse, OnHoverStart, OnPress, Activate and OnRelease events with their targets"></p>
</div>

### examples/buttons-and-keys.pl

Buttons that react to the mouse and to the keyboard, with focus, hover
and press styling, application key bindings and a clock updated by a
timer. Tab focuses a button, Enter or Space presses it; `+`, `-` and
`r` change the counter; q, Escape or Ctrl+Q quits. It is the program
of
["Add buttons for the mouse and the keyboard (Button)" in Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button).

The picture shows it after Tab and three presses of `+`, with the mouse
pointer over the Reset button.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-buttons-and-keys.svg" alt="Three buttons, the first focused and the last under the mouse pointer, a counter at 3 and a clock"></p>
</div>

### examples/form.pl

Every input widget in one form, built in Perl: text fields (one masked),
a text area, a dropdown, radio buttons, a slider and check boxes, with
labels of equal width. A status line shows every change; checking
"I accept the terms" enables the password field. Tab and Shift+Tab move
between the inputs. See
["FORMS AND INPUT WIDGETS" in Term::Fabulous::Manual::Forms](Manual/Forms.md#forms-and-input-widgets).

The picture shows it after typing a name and a note and choosing a
color from the dropdown.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-form.svg" alt="A form with name, password, notes, color, size, volume, newsletter and terms, and the status line color changed to: Yellow"></p>
</div>

### examples/custom-widget.pl

A widget of your own: an on/off switch built on
[Term::Fabulous::Widget::Input](Widget/Input.md), used from a KDL layout. It takes the
focus, reacts to keys and clicks and fires `Change` events. Tab moves
the focus; Space, Enter, Left, Right or a click switches. It is the
program of
["Write a custom input widget (a toggle switch)" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch).

The picture shows it after Tab and Space switched Bluetooth on.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-custom-widget.svg" alt="Three toggle switches, Bluetooth focused and switched on, and the status line"></p>
</div>

## KDL layout files

### examples/kdl-layout.pl

A screen described in a KDL layout file, `examples/kdl-layout.kdl`: a
title bar, a sidebar of server buttons, a main panel and a status line.
The program loads the file with [Term::Fabulous::Layout](Layout.md), finds
widgets by their ids and attaches the behavior: a click on a server
button, or Enter on it, shows that server in the main panel. It is the
complete program of ["A complete program" in Term::Fabulous::Manual::KDL](Manual/KDL.md#a-complete-program).

The picture shows it after Tab, Tab and Enter chose the db server.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-kdl-layout.svg" alt="A title bar, a sidebar with the buttons web, db and mail with db focused, and a main panel showing the details of the db server"></p>
</div>

### examples/kdl-form.pl

A form described in a KDL layout instead of Perl code. The program finds
the inputs by their ids, shows every change, shows all values on F2 and
prints them when it ends. It is the program of
["Build a form from a KDL file (text fields, radio buttons, dropdown, slider, checkbox)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox).

The picture shows the form filled in, after F2.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-kdl-form.svg" alt="The KDL form filled in, with all values shown in the status line after F2"></p>
</div>

## Tables

### examples/table-directory.pl

A staff directory in a [Term::Fabulous::Widget::Table](Widget/Table.md): a search box
above the table, rows grouped by team under headers with a payroll sum,
multiple selection, formatted dates and numbers, salaries over 100,000
in yellow, people on leave in gray italics, pages, a details panel that
follows the cursor, and a column chooser on F2. F3 switches the
grouping off and on. In the table, Space selects a row, Left and Right
close and open a group, and Up on the first row reaches the column
titles, where Enter sorts. See [Term::Fabulous::Manual::Tables](Manual/Tables.md).

The picture shows it after two rows were selected with Space and the
cursor moved on.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-table-directory.svg" alt="A staff table grouped by team with two selected rows, a pager, and a details panel for the person under the cursor"></p>
</div>

### examples/table-files.pl

A file browser in a [Term::Fabulous::Widget::Table](Widget/Table.md) with nested rows
(a tree): folders with sizes summed from their contents, dates and
kinds, sorted folders first, a filter row that keeps the folders of
every match, single selection, and a folder whose contents are loaded
only when it is opened for the first time. Right or `+` opens a
folder, Left or `-` closes it, `e` opens every folder and `c` closes
them all; Tab reaches the filter fields. See
["TREES" in Term::Fabulous::Manual::TableRows](Manual/TableRows.md#trees).

The first picture shows it after the cursor moved to the `vendor`
folder and Right opened it, which loaded its two files.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-table-files.svg" alt="A file tree in a table: open and closed folders in blue, indented files with sizes, dates and kinds, and the vendor folder just loaded"></p>
</div>

The second picture shows it in a shorter terminal, after `e` opened
every folder and the cursor moved down past the last visible row: the
rows scroll, while the column titles and the filter row stay in place.
See ["SIZE AND SCROLLING" in Term::Fabulous::Manual::TableStyles](Manual/TableStyles.md#size-and-scrolling).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-table-files-scrolling.svg" alt="A file tree table with all folders open, scrolled down: the column titles and the filter row stay at the top, and the scrollbar right of the frame shows a thumb in its middle"></p>
</div>

## Charts and canvases

### examples/chart-gallery.pl

Every chart widget side by side, each with a little data of the kind it
suits: values over time as lines, areas and bars, pairs of numbers as
points, a distribution as a histogram, shares as a pie and a donut,
counts around a circle as a polar area chart, profiles as a radar
chart, and trends as sparklines. See
["Which chart for which data" in Term::Fabulous::Manual::Charts](Manual/Charts.md#which-chart-for-which-data).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-chart-gallery.svg" alt="A gallery of ten small charts: a line chart, a stacked area chart, a bar chart, a scatter plot, a histogram, a pie chart, a donut chart, a polar area chart, a radar chart, and line, area and bar sparklines"></p>
</div>

### examples/canvas.pl

Waves plotted with half blocks on a [Term::Fabulous::Widget::Canvas](Widget/Canvas.md)
and animated by a timer. Only the cells whose pixels moved are redrawn
in each frame. See ["CANVASES" in Term::Fabulous::Manual::Charts](Manual/Charts.md#canvases).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-canvas.svg" alt="Three waves in red, blue and green on a canvas, drawn with half blocks"></p>
</div>

### examples/pixel-paint.pl

A paint program on a [Term::Fabulous::Widget::PixelCanvas](Widget/PixelCanvas.md): the left
mouse button paints, the right one erases, keys 1 to 6 pick a color and
c clears. It starts with a few shapes drawn by the program. See
["Drawing pixels" in Term::Fabulous::Manual::Charts](Manual/Charts.md#drawing-pixels).

The picture shows a red wave painted with the mouse over the shapes.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-pixel-paint.svg" alt="A pixel canvas with a frame, a line, a circle, a filled rectangle and a red wave painted with the mouse"></p>
</div>

## Output without a terminal

### examples/static-report.pl

Renders bordered panels with non-ASCII text once, with
[Term::Fabulous::Static](Static.md), and prints them: colored when the output is a
terminal, plain text in a pipe. See
["RENDERING WITHOUT A TERMINAL" in Term::Fabulous::Manual::Programs](Manual/Programs.md#rendering-without-a-terminal).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-static-report.svg" alt="Three panels with double, heavy and round borders, printed to the terminal"></p>
</div>

# THE WIDGET GALLERY

The programs in `examples/widgets` show one widget each, in its
typical states. Their pictures are also on the widget's class page,
which the entry links. Tab moves the focus between the widgets, Ctrl+C
quits. In the chart programs, moving the mouse over a series, a slice
or a legend entry emphasizes it.

## Containers and text

### examples/widgets/box.pl

[Term::Fabulous::Widget::Box](Widget/Box.md): a card with a border, a background,
padding and a gap between its children, and boxes sized to their
content, to the room left over and to a fixed width.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-box.svg" alt="A card with a title and body text, and three boxes labeled fit, grow and fixed(14)"></p>
</div>

### examples/widgets/text.pl

[Term::Fabulous::Widget::Text](Widget/Text.md): text in colors, wrapped and aligned
in boxes, and in several scripts.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text.svg" alt="Colored words, a sentence wrapped left-aligned, centered and right-aligned, and text in five scripts"></p>
</div>

### examples/widgets/divider.pl

[Term::Fabulous::Widget::Divider](Widget/Divider.md): a plain line, lines with a text at
the start, in the center and at the end, lines in other styles and
colors, and a vertical divider with a text between two columns.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-divider.svg" alt="Dividers: a plain line, texts at the start, the center and the end, double and heavy lines in colors, and a vertical divider with a text between two columns"></p>
</div>

### examples/widgets/accordion.pl

[Term::Fabulous::Widget::Accordion](Widget/Accordion.md): a settings accordion with one
section open at a time and a disabled section, and a bordered one
with the toggles at the end of the headers and several sections open
at once. Up and Down move between the headers, Enter or Space opens
and closes the focused section.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-accordion.svg" alt="Two accordions: one with the Network section open under General and a disabled Licenses section, one with borders, the toggles at the end and two sections open at once"></p>
</div>

### examples/widgets/tabs.pl

[Term::Fabulous::Widget::Tabs](Widget/Tabs.md): tabs along the top of a settings page
with a disabled tab, a bar at the bottom in the Heavy style with the
tabs in the center, tabs along the left side as a sidebar, and tabs
with downward labels without a border around the page. Left and Right
(or Up and Down, Home and End) choose a tab, so does a click, and
Ctrl+PageUp and Ctrl+PageDown turn the pages from anywhere inside.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-tabs.svg" alt="Four Tabs widgets: tabs along the top with the Network page shown and a disabled Licenses tab, a sidebar of tabs along the left side, a tab bar at the bottom in the Heavy style with the tabs in the center, and tall tabs with downward labels without a page border"></p>
</div>

## Buttons, inputs and dialogs

### examples/widgets/button.pl

[Term::Fabulous::Widget::Button](Widget/Button.md): four buttons that take the focus
(shown by the border color) and react to clicks and to Enter or Space.
The Archive button is disabled: it is drawn gray, Tab skips it and
clicks do nothing. The picture shows it after Enter pressed Save.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-button.svg" alt="Save, Cancel, Delete and Archive buttons: Save focused with a blue border, Archive disabled and drawn in gray, and the line Save was pressed"></p>
</div>

### examples/widgets/checkbox.pl

[Term::Fabulous::Widget::Checkbox](Widget/Checkbox.md): focused, unchecked, checked,
indeterminate and disabled. Space or Enter toggles the focused box.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-checkbox.svg" alt="Five check boxes: focused, unchecked, checked, indeterminate and disabled"></p>
</div>

### examples/widgets/radio.pl

[Term::Fabulous::Widget::RadioGroup](Widget/RadioGroup.md) and
[Term::Fabulous::Widget::RadioButton](Widget/RadioButton.md): a group in a row (focused), a
group in a column and a disabled group. The arrow keys choose a button
in the focused group.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-radio.svg" alt="Radio buttons in a row with Medium chosen, in a column with Express shipping chosen, and a disabled group"></p>
</div>

### examples/widgets/dropdown.pl

[Term::Fabulous::Widget::Dropdown](Widget/Dropdown.md): one showing its placeholder, one
with a selected option, and one whose list is open. Enter, Space,
Alt+Down or F4 open the list, Up and Down move in it, Enter chooses and
Escape closes it. The picture shows it after Enter opened the list and
Down moved the highlight.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-dropdown.svg" alt="Three dropdowns: a placeholder, France selected, and an open list of colors with Blue highlighted"></p>
</div>

### examples/widgets/slider.pl

[Term::Fabulous::Widget::Slider](Widget/Slider.md): a focused slider with a percentage,
one that formats its value with code, and a disabled one. Left and
Right (or PageUp, PageDown, Home and End) change the value.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-slider.svg" alt="Three sliders: focused at 65 percent, a temperature of 21.5 degrees, and a disabled one"></p>
</div>

### examples/widgets/star-rating.pl

[Term::Fabulous::Widget::StarRating](Widget/StarRating.md): a focused rating, one with half
stars that shows its value, a read-only one, one out of ten without
gaps, and a disabled one. Left and Right, the digits, Home and End
change the value; so does a click on a star.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-star-rating.svg" alt="Star ratings: a focused one with three of five stars, one with half stars and its value, a read-only one, one out of ten with a gap of zero, and a disabled one"></p>
</div>

### examples/widgets/segmented-control.pl

[Term::Fabulous::Widget::SegmentedControl](Widget/SegmentedControl.md): a focused control, one
stretched to the full width, one with a disabled segment, a vertical
one and a disabled one. Left and Right, the digits, Home and End choose
a segment; so does a click.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-segmented-control.svg" alt="Segmented controls: a focused one with Week selected, one stretched to the full width, one with a disabled segment, a vertical one, and a disabled one"></p>
</div>

### examples/widgets/text-field.pl

[Term::Fabulous::Widget::TextField](Widget/TextField.md): a focused field to type in, an
empty one showing its placeholder, a masked password and a disabled
field. Shift with the arrow keys selects text. The picture shows it
after typing and selecting a word.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text-field.svg" alt="Four text fields: a focused field with Ada Lovelace typed and Lovelace selected, a placeholder, a masked password and a disabled field"></p>
</div>

### examples/widgets/text-area.pl

[Term::Fabulous::Widget::TextArea](Widget/TextArea.md): a shopping list whose long line
wraps at a space; the text is taller than the area, so a scrollbar shows
the position. Shift with the arrow keys selects text, Ctrl+Z undoes.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text-area.svg" alt="A text area with a shopping list, a wrapped long line and a scrollbar"></p>
</div>

### examples/widgets/dialog.pl

[Term::Fabulous::Widget::Dialog](Widget/Dialog.md): a dialog centered over a list of
files, behind a translucent backdrop that dims them. The dialog keeps
the focus inside itself: Tab moves between its two buttons, and the
focused one has a blue border. Escape or a button closes it, d opens it
again.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-dialog.svg" alt="A Delete 3 files? dialog with Delete and Cancel buttons over a dimmed list of files; Delete has the focus and a blue border"></p>
</div>

## Progress and feedback

### examples/widgets/progress-bar.pl

[Term::Fabulous::Widget::ProgressBar](Widget/ProgressBar.md): a block bar with its
percentage, one with the percentage inside, a thin line bar with a
label of its own, a striped bar whose stripes move, a bar of three
colored segments, an indeterminate bar with its runner, and a two-row
ASCII bar. The bars fill up from a timer.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-progress-bar.svg" alt="Progress bars: a block bar at 42 percent, one with the value inside, a thin line bar, a striped bar, a bar of three colored segments, an indeterminate bar with its runner, and a two-row ASCII bar"></p>
</div>

### examples/widgets/toast.pl

[Term::Fabulous::Widget::Toast](Widget/Toast.md): toasts of every kind stacked in the
top right corner, a filled (important) one that stays in the bottom
right corner, and one used as an alert box inside a form. The keys 1
to 4 show a toast of each kind, i an important one; the picture shows
it after 1, 2, 3 and i.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-toast.svg" alt="Toasts stacked in the top right corner: an info, a success and a warning toast with titles, messages and close marks, a filled danger toast in the bottom right corner, and an alert box inside the form"></p>
</div>

### examples/widgets/spinner.pl

[Term::Fabulous::Widget::Spinner](Widget/Spinner.md): every ready-made style with its
name as the label, one-cell styles in the first column and wider and
taller ones in the second, then a stopped spinner and one with frames
of its own. The picture shows the frames of one moment; the program
animates them.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-spinner.svg" alt="Spinners in every style, each with its name: dots, line, arc, circle, arrow, box, pulse and bar in one cell, dots3, bounce and wave in several, and the three-row ring; a stopped one and one with frames of its own"></p>
</div>

## Tables

### examples/widgets/table.pl

[Term::Fabulous::Widget::Table](Widget/Table.md): a list of staff with a filter row,
multiple selection with check boxes, rows sorted by the start date,
formatted dates and numbers, striped rows and a pager. Space selects a
row, Shift with an arrow key selects a range, Ctrl+A selects all, a
click on a column title sorts, and Ctrl+PageDown and Ctrl+PageUp turn
the pages. The picture shows it after Space, Down, Down and Space
selected two rows.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-table.svg" alt="A table of staff with a filter row, sorted by the start date, two rows selected with check boxes and a pager below"></p>
</div>

## Charts

### examples/widgets/chart.pl

[Term::Fabulous::Widget::Chart](Widget/Chart.md), what every chart has, shown on four
bar charts of the same data: titles aligned left, center and right, the
legend at the top, the bottom, the right and the left, two palettes, a
series emphasized with `highlight`, and a chart on a light panel that
picks light-theme colors by itself. See
["Titles and legends" in Term::Fabulous::Manual::Charts](Manual/Charts.md#titles-and-legends).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-chart.svg" alt="Four bar charts of the same data: the legend at the top, at the bottom under a centered title, at the right with the iOS series highlighted and the others faded, and at the left of a chart on a light panel with a right-aligned title"></p>
</div>

### examples/widgets/line-chart.pl

[Term::Fabulous::Widget::LineChart](Widget/LineChart.md): three series of monthly figures
with smooth `monotone` curves and a title on the y axis.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-line-chart.svg" alt="A line chart of monthly active users on web, iOS and Android with smooth curves, a legend at the top and the y axis titled thousands"></p>
</div>

### examples/widgets/area-chart.pl

[Term::Fabulous::Widget::AreaChart](Widget/AreaChart.md): the visits of a website by
source, stacked, with `monotone` curves.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-area-chart.svg" alt="Stacked areas of visits from search, social and direct over twelve months, with smooth edges and a legend at the top"></p>
</div>

### examples/widgets/bar-chart.pl

[Term::Fabulous::Widget::BarChart](Widget/BarChart.md): the revenue per quarter of two
years as grouped bars, each with its value above it.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-bar-chart.svg" alt="Grouped bars of the revenue per quarter in 2025 and 2026 with the value above each bar"></p>
</div>

### examples/widgets/scatter-plot.pl

[Term::Fabulous::Widget::ScatterPlot](Widget/ScatterPlot.md): the engine power and fuel use
of two kinds of cars, each kind with its trend line.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-scatter-plot.svg" alt="Points of petrol and hybrid cars by engine power and fuel use, each kind with a dashed trend line"></p>
</div>

### examples/widgets/histogram.pl

[Term::Fabulous::Widget::Histogram](Widget/Histogram.md): how long 2000 requests to two
servers took, binned automatically. The two histograms are drawn over
each other, translucent.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-histogram.svg" alt="Two overlapping, translucent histograms of the response times of the eu-west and us-east servers"></p>
</div>

### examples/widgets/histogram-measures.pl

[Term::Fabulous::Widget::Histogram](Widget/Histogram.md): the same observations measured
four ways: the count per bin, the percent of all observations, the
density (the area under the bars is 1), and cumulative percentages,
which rise to 100% at the last bin. See
["Measures" in Term::Fabulous::Widget::Histogram](Widget/Histogram.md#measures).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-histogram-measures.svg" alt="Four histograms of the same response times: counts per bin, percent per bin, density per bin, and cumulative percentages rising to 100%"></p>
</div>

### examples/widgets/sparkline.pl

[Term::Fabulous::Widget::Sparkline](Widget/Sparkline.md): a list of servers, each with its
load of the last minute as a line, an area and bars, which move on
every second. The picture shows it after three seconds.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-sparkline.svg" alt="Four servers, each with its current load and three sparklines of the last minute: a line, an orange area and green bars"></p>
</div>

### examples/widgets/pie-chart.pl

[Term::Fabulous::Widget::PieChart](Widget/PieChart.md): the browsers of a website's
visitors, largest first, with the small ones folded into Other.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-pie-chart.svg" alt="A pie chart of visitors by browser, largest first, with Opera, Vivaldi and Lynx folded into Other, and percentages on the slices and in the legend"></p>
</div>

### examples/widgets/pie-chart-styles.pl

[Term::Fabulous::Widget::PieChart](Widget/PieChart.md): one set of slices drawn four ways:
with the characters of four markers, with gaps between the slices,
with the labels or the values on the slices, sorted and with a start
angle. See ["Styles" in Term::Fabulous::Widget::PieChart](Widget/PieChart.md#styles).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-pie-chart-styles.svg" alt="Four pies of the same budget: in quadrant blocks with percentages, in sextants with gaps between the slices, in Braille dots with the slice labels, and in half blocks with the values, sorted ascending and starting at 3 o'clock"></p>
</div>

### examples/widgets/donut-chart.pl

[Term::Fabulous::Widget::DonutChart](Widget/DonutChart.md): a monthly budget with the total
in the middle and the amounts and shares in the legend. While the mouse
pointer is on a slice, the middle shows its share.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-donut-chart.svg" alt="A donut chart of a monthly budget with the total in the middle and amounts and percentages in the legend"></p>
</div>

### examples/widgets/donut-chart-centers.pl

[Term::Fabulous::Widget::DonutChart](Widget/DonutChart.md): what the hole of a donut shows:
by default the total; the share and label of the emphasized slice
(under the mouse pointer, or chosen with `highlight`); or a
`center_text` of your own. See
["The text in the hole" in Term::Fabulous::Widget::DonutChart](Widget/DonutChart.md#the-text-in-the-hole).

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-donut-chart-centers.svg" alt="Three donuts of the same budget: the total 2170 euros in the middle of the first, 21% Food in the middle of the second with the other slices faded, and a text of its own, 2170 euros per month, in the third"></p>
</div>

### examples/widgets/polar-area-chart.pl

[Term::Fabulous::Widget::PolarAreaChart](Widget/PolarAreaChart.md): commits per weekday as
slices of equal angle that reach as far out as their value, with rings
for the scale.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-polar-area-chart.svg" alt="Seven slices of equal angle for the weekdays, reaching as far out as their number of commits, over rings with their values"></p>
</div>

### examples/widgets/radar-chart.pl

[Term::Fabulous::Widget::RadarChart](Widget/RadarChart.md): the ratings of two laptops in
six categories, as filled shapes on a web of axes.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-radar-chart.svg" alt="Two translucent shapes on a web of six axes: the ratings of two laptops for speed, battery, screen, keyboard, weight and price, with a dot on every value"></p>
</div>

# THE COOKBOOK PROGRAMS

The programs in `examples/cookbook` are the complete programs of the
recipes in [Term::Fabulous::Cookbook](Cookbook.md), where each is explained line by
line. They are grouped below like the cookbook pages, in the order of
the recipes on each page. Three recipes use a program of `examples`;
their entries point to it. A program that prints its result and ends
is shown with its output; `custom-events.pl` and `test-a-widget.pl`
have no picture.

## The first program of the manual

- `first-program.pl`

    The program of ["YOUR FIRST PROGRAM" in Term::Fabulous::Manual](Manual.md#your-first-program): a greeting
    in a bordered box, centered on the screen, and a key listener that
    quits on q or Escape.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-first-program.svg" alt="The first program: a greeting in a box with a rounded blue border, centered on a dark blue screen"></p>
    </div>

## Getting started

The programs of [Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md).

- `minimal-program.pl`

    ["A minimal program to start from" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#a-minimal-program-to-start-from):
    a line of text, and q, Escape or Ctrl+C to quit.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-minimal-program.svg" alt="The minimal program: one line of text on a dark background"></p>
    </div>

- `non-ascii-text.pl`

    ["Show non-ASCII text (umlauts, CJK, combining accents)" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#show-non-ascii-text-umlauts-cjk-combining-accents):
    German, Japanese and a combining accent lined up in columns; prints
    the result and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-non-ascii-text.svg" alt="German, Japanese and a combining accent, each line aligned in its columns"></p>
    </div>

- `wrap-and-align-text.pl`

    ["Wrap, align and space text" in Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md#wrap-align-and-space-text):
    the wrap modes, alignment and line height of text in framed boxes;
    prints the boxes and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-wrap-and-align-text.svg" alt="Six framed samples: wrapped text aligned left, centered and right, text broken only at line breaks, two rows per line, and a centered label"></p>
    </div>

## Keyboard and mouse

The programs of [Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md).

- `key-bindings.pl`

    ["Bind a key to an action" in Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md#bind-a-key-to-an-action):
    application key bindings that show the name of every key pressed. The
    picture shows it after Ctrl+R.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-key-bindings.svg" alt="The key bindings program after Ctrl+R: the help line says reloaded and the second line shows the key name"></p>
    </div>

- `examples/buttons-and-keys.pl`

    The program of
    ["Add buttons for the mouse and the keyboard (Button)" in Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button);
    see [its entry among the demo programs](#examples-buttons-and-keys-pl).

## Timers and live data

The programs of [Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md).

- `clock.pl`

    ["Update the screen from a timer (a clock)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#update-the-screen-from-a-timer-a-clock):
    a clock that a timer updates once per second.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-clock.svg" alt="A clock in the middle of the terminal"></p>
    </div>

- `scrolling-log.pl`

    ["Add lines to a scrolling log (ScrollBox)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#add-lines-to-a-scrolling-log-scrollbox):
    a timer adds a line to a log in a scroll box. The picture shows it
    after a few seconds.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-scrolling-log.svg" alt="A framed log with ten timestamped lines"></p>
    </div>

- `follow-log.pl`

    ["Scroll a ScrollBox from code (keep a log at the newest line)" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#scroll-a-scrollbox-from-code-keep-a-log-at-the-newest-line):
    a log that keeps its newest line in view. The mouse wheel or Up and
    Down scroll, Left and Right scroll sideways, Home goes to the top and
    End follows the newest line again. The picture shows it after a few
    seconds.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-follow-log.svg" alt="A log that shows its newest lines; every fifth line is wider than the box and cut at its edge"></p>
    </div>

- `show-output.pl`

    ["Show the output of a running command" in Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md#show-the-output-of-a-running-command):
    runs the command given on the command line and shows its newest lines
    of output and its exit status. The picture shows it running
    `seq -f 'Line %g' 1 40`.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-show-output.svg" alt="The last lines of the output of seq and the exit status in a framed box"></p>
    </div>

## Forms

The programs of [Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md).

- `login-form.pl`

    ["A login form (centered dialog, masked password)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#a-login-form-centered-dialog-masked-password):
    a user name, a masked password and a check box in a centered box;
    Enter in a field logs in. The picture shows it after logging in.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-login-form.svg" alt="A centered login dialog with a user name, a masked password, a checked box and the welcome message"></p>
    </div>

- `confirm-dialog.pl`

    ["Ask a question in a dialog (Dialog widget)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget):
    a notes area; Ctrl+Q asks in a dialog before quitting. The picture
    shows the open dialog, after typing a note and Ctrl+Q.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-confirm-dialog.svg" alt="The Really quit? dialog with Quit and Cancel buttons over the dimmed notes; Quit has the focus and a blue border"></p>
    </div>

- `inline-prompt.pl`

    ["Ask for input below the shell's output (inline mode)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#ask-for-input-below-the-shell-s-output-inline-mode):
    a question that draws into three rows below the shell's output instead
    of the whole screen. Enter answers, Escape cancels. The picture shows
    it after typing a name.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-inline-prompt.svg" alt="The inline prompt in the three rows below a shell's earlier output: the question, a text field holding Ada Lovelace and a help line"></p>
    </div>

- `choose-options.pl`

    ["Choose from options in Perl (Dropdown, RadioGroup, Slider)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#choose-from-options-in-perl-dropdown-radiogroup-slider):
    a dropdown, a radio group and a slider built in Perl, with a status
    line. The picture shows it after choosing Express shipping and raising
    the tip.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-choose-options.svg" alt="A dropdown showing France, radio buttons with Express chosen, a slider at 15 percent and the status line"></p>
    </div>

- `examples/kdl-form.pl`

    The program of
    ["Build a form from a KDL file (text fields, radio buttons, dropdown, slider, checkbox)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox);
    see [its entry among the demo programs](#examples-kdl-form-pl).

- `disable-inputs.pl`

    ["Disable inputs until a checkbox is checked" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked):
    a field that is disabled until a check box is checked.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-disable-inputs.svg" alt="An unchecked check box and the grayed out VAT number field below it"></p>
    </div>

- `focus-help-line.pl`

    ["Show a status line that follows the focus (OnFocus)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#show-a-status-line-that-follows-the-focus-onfocus):
    a help line that describes the focused input. The picture shows it
    while the notes have the focus.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-focus-help-line.svg" alt="A title, notes being typed, a slider and the help line for the notes"></p>
    </div>

- `tab-order.pl`

    ["Change the Tab order (HasFocusOrder)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#change-the-tab-order-hasfocusorder):
    three fields whose Tab order differs from their order on the screen.
    The picture shows it after typing a street, Tab and a zip code: Tab
    went from Street straight to Zip.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-tab-order.svg" alt="Three text fields side by side: Street filled in, City still empty, and the Zip field focused with 12345 typed, because Tab went from Street straight to Zip"></p>
    </div>

## Layout and looks

The programs of [Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md).

- `width-group.pl`

    ["Line up labels with equal widths (width\_group)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#line-up-labels-with-equal-widths-width_group):
    labels in a width group, so their values line up; prints the result
    and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-width-group.svg" alt="Three label and value rows whose values start in the same column"></p>
    </div>

- `border-sides.pl`

    ["Use a different border style on each side" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#use-a-different-border-style-on-each-side):
    rules above and below, a heavy top edge and a thick left edge; prints
    the result and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-border-sides.svg" alt="Three boxes: double and single rules above and below, a heavy top edge, and a thick left edge"></p>
    </div>

- `theme-switch.pl`

    ["Switch themes at run time (built-in themes and a theme file)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#switch-themes-at-run-time-built-in-themes-and-a-theme-file):
    the built-in `dark` and `light` themes and the theme file
    `examples/ocean.kdl`; F2 switches to the next one. The picture shows
    the ocean theme, after typing a line and two presses of F2.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-theme-switch.svg" alt="The ocean theme after two presses of F2: teal text on a dark blue background, a text field holding Light and readable, and a Save button with a teal border"></p>
    </div>

- `states-and-classes.pl`

    ["Mark widgets with states and classes" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#mark-widgets-with-states-and-classes):
    a menu whose items take their colors from their states, followed by
    the states and classes of each item; prints the result and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-states-and-classes.svg" alt="A menu of three items with Save in the selected color, followed by the states and classes of each item"></p>
    </div>

- `resize-aware-layout.pl`

    ["Change the layout with the terminal size (Start and Resize events)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#change-the-layout-with-the-terminal-size-start-and-resize-events):
    two panes side by side on a wide terminal and above each other on a
    narrow one. The pictures show it 80 and 60 columns wide.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-resize-aware-layout.svg" alt="The Inbox and Message panes side by side on a terminal 80 columns wide"></p>
    </div>

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-resize-aware-layout-narrow.svg" alt="The Inbox and Message panes above each other on a terminal 60 columns wide"></p>
    </div>

## Tables

The programs of [Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md).

- `table-basics.pl`

    ["Show a list of hashes in a table (sort, select, open a row)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-basics.svg" alt="A table of user accounts sorted by name, two rows selected with check boxes, and two status lines below: the selected logins and the account opened with Enter"></p>
    </div>

- `table-format.pl`

    ["Format cells: dates, numbers, sizes and flags (mutators)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#format-cells-dates-numbers-sizes-and-flags-mutators).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-format.svg" alt="A table of backup jobs with formatted times, durations, sizes, file counts, percentages, transfer rates and check marks, sorted by size, and a line that shows the raw value and the display text of one size"></p>
    </div>

- `table-edit.pl`

    ["Edit the data of a table (widget cells, add and remove rows and columns)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#edit-the-data-of-a-table-widget-cells-add-and-remove-rows-and-columns):
    a to-do list with check boxes and buttons in its cells. `a` adds a
    task, Delete removes the selected tasks, `h` gives the task under the
    cursor one more hour, and `n` shows or hides the notes column.
    The picture shows it after `n`, two selections with Space, `a`, a
    click on the check box of the third task and `h`.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-edit.svg" alt="A to-do table with check boxes, delete buttons and a note column, two tasks selected, a new task added and the status line below"></p>
    </div>

- `table-columns.pl`

    ["Let the user choose the visible columns (column chooser)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#let-the-user-choose-the-visible-columns-column-chooser).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-columns.svg" alt="A staff table with the column chooser open over its top right corner: City unchecked, E-mail checked, and the status line with the columns to save"></p>
    </div>

- `table-kdl.pl`

    ["Describe a table in a KDL layout (columns, lines, sort, groups)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#describe-a-table-in-a-kdl-layout-columns-lines-sort-groups).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-kdl.svg" alt="A stock table built from KDL: grouped by category, sorted by quantity, two rows selected and the Displays group closed"></p>
    </div>

- `table-report.pl`

    ["Print a table as a report (Static)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#print-a-table-as-a-report-static);
    prints the report and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-report.svg" alt="The printed sales report: products sorted by revenue, units and amounts formatted, shares in percent and a bold totals row under a double line"></p>
    </div>

## Table rows

The programs of [Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md).

- `table-sort.pl`

    ["Sort rows, also with your own comparison" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#sort-rows-also-with-your-own-comparison).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-sort.svg" alt="A table of tickets sorted by version in natural order and then by priority, with numbered sort markers in the column titles and a line that names the sort"></p>
    </div>

- `table-filter.pl`

    ["Let the user filter rows (filter row and search box)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#let-the-user-filter-rows-filter-row-and-search-box).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-filter.svg" alt="A table of staff with a search field above it and a filter row under the column titles holding the expressions >=2019 and >=80000, four matching rows and the line 4 of 12 rows"></p>
    </div>

- `table-filter-perl.pl`

    ["Filter rows from Perl (numbers, dates, text, raw or shown values)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#filter-rows-from-perl-numbers-dates-text-raw-or-shown-values).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-filter-perl.svg" alt="A table of invoices filtered to three rows by the fourth of five filters, with a line that names the active filter and counts the rows"></p>
    </div>

- `table-groups.pl`

    ["Group rows by a column (collapsible group headers)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#group-rows-by-a-column-collapsible-group-headers).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-groups.svg" alt="A table of staff grouped by team: group headers with the team name, the number of people and their total salary, the Network group closed"></p>
    </div>

- `table-tree.pl`

    ["Show nested data as a tree (expand and collapse rows)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#show-nested-data-as-a-tree-expand-and-collapse-rows).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-tree.svg" alt="A file tree in a table: folders with open and closed markers, indented files, sizes and dates"></p>
    </div>

- `table-pages.pl`

    ["Split many rows into pages (pager and page sizes)" in Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md#split-many-rows-into-pages-pager-and-page-sizes).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-pages.svg" alt="A table of orders on page 3 of 30, with the pager below it and the status line naming the orders on the page"></p>
    </div>

## Table styles

The programs of [Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md).

- `table-widths.pl`

    ["Size, align and wrap columns (widths, wrapping, widget titles)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#size-align-and-wrap-columns-widths-wrapping-widget-titles):
    fixed, growing and percentage column widths, wrapped cells, rows of
    two lines, alignment and a widget as a column title. Resize the
    terminal to see the widths change.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-widths.svg" alt="An order table with a fixed number column, a growing Item column, a Notes column that takes a third of the width and wraps, an address column of two lines per row, a centered quantity, prices with a left-aligned title, and a Rating title with a star"></p>
    </div>

- `table-lines.pl`

    ["Lines and colors per row, column and cell (conditional formatting)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#lines-and-colors-per-row-column-and-cell-conditional-formatting).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-lines.svg" alt="A budget table: a heavy line and dashed lines in the Left column, negative amounts in red, a cancelled row in gray italics and a bold totals row under a double line"></p>
    </div>

- `table-colors.pl`

    ["A table with colored rows and titles (block frame, no grid lines)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#a-table-with-colored-rows-and-titles-block-frame-no-grid-lines).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-colors.svg" alt="A table of planets with an Outer block frame, no inner lines, colored column titles, striped rows and the cursor row highlighted up to the frame"></p>
    </div>

- `table-line-styles.pl`

    ["Compare the line options of a table (frames, grid lines, block frames)" in Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md#compare-the-line-options-of-a-table-frames-grid-lines-block-frames):
    the same small table with nine different settings of its lines.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-table-line-styles.svg" alt="Nine small tables with different lines: the default round frame, a full grid, no lines, a double frame with a heavy title line, a heavy frame with dashed row lines, ASCII lines, and Outer, Inner and Thick block frames"></p>
    </div>

## Charts

The programs of [Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md), one for each kind
of chart.

- `chart-line.pl`

    ["Draw a line chart with labels and points (LineChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#draw-a-line-chart-with-labels-and-points-linechart).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-line.svg" alt="A line chart of the average monthly temperatures of Lisbon, Berlin and Oslo, with a dot on every month, a legend at the top and degree labels on the y axis"></p>
    </div>

- `chart-bars.pl`

    ["Grouped, stacked and horizontal bars (BarChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#grouped-stacked-and-horizontal-bars-barchart).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-bars.svg" alt="Three bar charts: orders of the shop and the app per weekday as grouped bars with their values, support tickets per weekday as stacked bars, and the views of four pages as horizontal bars with their values"></p>
    </div>

- `chart-pie.pl`

    ["Show shares as a pie or donut (PieChart, DonutChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#show-shares-as-a-pie-or-donut-piechart-donutchart).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-pie.svg" alt="A pie chart of disk usage with percentages on the slices and the legend below it, and a donut chart of sales by region with percentages on its slices, the small regions folded into Rest of world, amounts in the legend and 1150k orders in the middle"></p>
    </div>

- `chart-scatter.pl`

    ["A scatter plot with trend lines (ScatterPlot)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#a-scatter-plot-with-trend-lines-scatterplot).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-scatter.svg" alt="A scatter plot of petal length and width of three species as three clusters of dots, the largest flowers drawn as diamonds, with a dashed trend line through the two larger species and dotted vertical grid lines"></p>
    </div>

- `chart-stacked-areas.pl`

    ["Stacked areas and shares of 100% (AreaChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#stacked-areas-and-shares-of-100-areachart).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-stacked-areas.svg" alt="Two stacked area charts of electricity from coal, gas, wind and solar from 2016 to 2026: the amounts in TWh on the left, each source's share of 100 percent on the right"></p>
    </div>

- `chart-histogram.pl`

    ["How values are distributed (Histogram)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#how-values-are-distributed-histogram).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-histogram.svg" alt="Two histograms of exam scores: counts in automatic bins on the left, and the cumulative share in bins of 10 points from 0 to 100 on the right, rising to 100 percent"></p>
    </div>

- `chart-radar.pl`

    ["Compare profiles on radar and polar area charts (RadarChart, PolarAreaChart)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#compare-profiles-on-radar-and-polar-area-charts-radarchart-polarareachart).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-radar.svg" alt="A radar chart comparing a striker, a defender and a dashed gray average over six skills on circular rings, and a polar area chart of rain per season with Spring at the top"></p>
    </div>

- `chart-sparklines.pl`

    ["Show sparklines in table cells (Sparkline)" in Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md#show-sparklines-in-table-cells-sparkline).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-sparklines.svg" alt="A table of four stocks with symbol, name, last price and the change over 30 days, and a Trend column of area sparklines that span the month's prices, green for rising and red for falling stocks"></p>
    </div>

## Chart techniques

The programs of [Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md): time
axes, live data, transforms, KDL layouts and printed reports.

- `chart-time-series.pl`

    ["Plot values over time (time axis, from and to, a dashed forecast)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#plot-values-over-time-time-axis-from-and-to-a-dashed-forecast).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-time-series.svg" alt="Hourly temperatures over four days on a time axis: a solid measured line, a dashed forecast from noon of June 3rd on, and a red shaded area under the measurements from June 2nd to that noon"></p>
    </div>

- `chart-live.pl`

    ["A live chart that follows new data (append, max\_points, span)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#a-live-chart-that-follows-new-data-append-max_points-span);
    the picture shows it after 30 seconds.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-live.svg" alt="A live chart of network traffic: received traffic as a filled area with a line on top and sent traffic as a line fill the right half of a one-minute time axis after 30 seconds, with a status line of the newest values below"></p>
    </div>

- `chart-log-scale.pl`

    ["Show values of very different sizes (logarithmic axis)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#show-values-of-very-different-sizes-logarithmic-axis).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-log-scale.svg" alt="The same two series twice: on a linear axis the issues and the early downloads lie flat on the bottom, on a logarithmic axis both rise as nearly straight lines"></p>
    </div>

- `chart-transform.pl`

    ["Smooth noisy data and index it to 100 (transforms)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#smooth-noisy-data-and-index-it-to-100-transforms).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-transform.svg" alt="Daily visits as a dim raw line with a 7-day moving average and a dashed exponentially smoothed line over it, and below it share and bond prices both indexed to 100 at day 1"></p>
    </div>

- `chart-kdl.pl`

    ["Describe charts in a KDL layout (series, slices, transforms)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#describe-charts-in-a-kdl-layout-series-slices-transforms).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-kdl.svg" alt="A bar chart of sold and returned units per quarter with value labels and a dashed trend line, built from KDL, next to a donut chart of sales by channel that includes the Web slice added from Perl"></p>
    </div>

- `chart-report.pl`

    ["Print charts in a report (Static)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#print-charts-in-a-report-static);
    prints the report and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-report.svg" alt="The printed report: horizontal bars of the disk usage of four file systems with their percentages, and a line with the load of the last 18 hours as a bar sparkline"></p>
    </div>

## Chart styles

The programs of [Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md): curves,
markers, colors, line styles and hover.

- `chart-curves.pl`

    ["Connect points with curves and easings (curve)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#connect-points-with-curves-and-easings-curve).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-curves.svg" alt="Six small charts of the same seven points connected linear, step, monotone, catmull-rom, ease-in-out-sine and ease-out-bounce"></p>
    </div>

- `chart-styles.pl`

    ["Draw with Braille, blocks or box lines (marker)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#draw-with-braille-blocks-or-box-lines-marker).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-styles.svg" alt="Nine small charts of one wave: lines in Braille, half blocks, quadrants, sextants and box drawing lines, an area in eighth blocks, and bars in quadrants, blocks and Braille"></p>
    </div>

- `chart-colors.pl`

    ["Light backgrounds, palettes and colors of your own" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#light-backgrounds-palettes-and-colors-of-your-own).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-colors.svg" alt="A line chart on a light background with dark text, dotted grid lines and the legend below, next to a bar chart with a rounded frame, colors of its own and a dashed red target line"></p>
    </div>

- `chart-options.pl`

    ["Line styles, gaps, bar widths, stack groups and grid lines" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#line-styles-gaps-bar-widths-stack-groups-and-grid-lines):
    six small charts, one for each group of options.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-options.svg" alt="Six small charts: a solid, a dashed and a dotted line; a line with a gap next to one drawn across the gap; an area with a line and a mark on every point; narrow bars; bars of 2025 and 2026 in two stacks per quarter; a line over dashed vertical and solid horizontal grid lines"></p>
    </div>

- `chart-hover.pl`

    ["Show details of the point under the pointer (SeriesHover, highlight)" in Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md#show-details-of-the-point-under-the-pointer-serieshover-highlight);
    the picture shows it with the mouse pointer over the chart.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-hover.svg" alt="A stacked area chart of closed issues per team with the area under the mouse pointer emphasized, the others faded, and a status line that names the team, the week and the number of issues"></p>
    </div>

## Canvases

The programs of [Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md).

- `paint-with-the-mouse.pl`

    ["Paint with the mouse (Canvas, clicks and drags)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#paint-with-the-mouse-canvas-clicks-and-drags):
    the left button draws, the right one erases, and a drag draws a line.
    The picture shows a drag and three clicks.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-paint-with-the-mouse.svg" alt="A wave of stars drawn by dragging the mouse over a canvas, with an o where the drag started and at three clicked cells"></p>
    </div>

- `pixel-canvas-plot.pl`

    ["Plot data on a pixel canvas (PixelCanvas)" in Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md#plot-data-on-a-pixel-canvas-pixelcanvas).

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-pixel-canvas-plot.svg" alt="A line chart of temperatures on a pixel canvas, red above 20 degrees"></p>
    </div>

## Output without a terminal

The programs of [Term::Fabulous::Cookbook::Output](Cookbook/Output.md).

- `report-to-file.pl`

    ["Render a report to a file or pipe (Static)" in Term::Fabulous::Cookbook::Output](Cookbook/Output.md#render-a-report-to-a-file-or-pipe-static);
    prints the report and also writes it to `report.txt` in the current
    directory.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-report-to-file.svg" alt="The sales report: a rounded box with a title and three regions"></p>
    </div>

- `test-a-widget.pl`

    ["Test a widget without a terminal" in Term::Fabulous::Cookbook::Output](Cookbook/Output.md#test-a-widget-without-a-terminal); a test
    script, run it with `prove`.

## Your own widgets and events

The programs of [Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md).

- `examples/custom-widget.pl`

    The program of
    ["Write a custom input widget (a toggle switch)" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch);
    see [its entry among the demo programs](#examples-custom-widget-pl).

- `kdl-panel.pl` and `lib/My/Panel.pm`

    ["Make a widget usable from KDL" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#make-a-widget-usable-from-kdl):
    a panel class of your own, used from a KDL layout; prints the result
    and ends.

    <div>
            <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-kdl-panel.svg" alt="The Network panel in a rounded frame and the Disk panel in a double frame"></p>
    </div>

- `custom-events.pl`

    ["Fire your own events" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#fire-your-own-events); prints what the
    listeners hear.

# PICTURES OF YOUR OWN PROGRAMS

The pictures on this page are taken with `tools/screenshot` from the
distribution, which takes one of any Term::Fabulous program, as SVG or
PNG. It runs the program in a pseudo terminal of a given size, sends it
the keys, text and mouse actions you give, and records what the
terminal shows. Time is simulated, so animations and clocks come out
the same on every run. From a built copy of the distribution:

```sh
perl -Mblib tools/screenshot --size 100x30 --output form.svg examples/form.pl
perl -Mblib tools/screenshot --steps 'type "Ada"; key "Tab"' --output form.png my-program.pl
```

`perl -Mblib tools/screenshot --help` lists the options. PNG output
needs [Imager](https://metacpan.org/pod/Imager) with PNG and FreeType support; `tools/README.md`
describes the tools.

# SEE ALSO

[Term::Fabulous](../../../README.md), [Term::Fabulous::Manual](Manual.md),
[Term::Fabulous::Cookbook](Cookbook.md).
