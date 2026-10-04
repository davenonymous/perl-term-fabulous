# NAME

Term::Fabulous::Manual::Glossary - The terms used in the Term::Fabulous documentation

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Troubleshooting](Troubleshooting.md).

The terms the Term::Fabulous documentation uses, in alphabetical order,
each with a link to the section that explains it. A term with several
meanings lists them all; a word in parentheses names the area a term
belongs to, such as (table) or (KDL).

# GLOSSARY

- alias (KDL)

    The short name a KDL layout gives a widget class in its `use`
    instructions (`use Term::Fabulous::Widget::Box as Box`); widget nodes
    use it as their name. See
    ["Declaring widget classes" in Term::Fabulous::Manual::KDL](KDL.md#declaring-widget-classes).

- ancestor

    A widget's parent, the parent's parent, and so on up to the root.

- application object

    The [Term::Fabulous](../../../../README.md) object of a program: it holds the widget tree,
    opens the terminal and runs the event loop ([`run`](../../../../README.md#run)).

- bubbling

    An event, after the listeners of its target ran, is passed on to the
    target's ancestors. See ["Return values and bubbling" in Term::Fabulous::Manual::Events](Events.md#return-values-and-bubbling).

- canvas

    A widget you draw into yourself: a [Term::Fabulous::Widget::Canvas](../Widget/Canvas.md)
    cell by cell, a [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md) pixel by pixel.
    See ["CANVASES" in Term::Fabulous::Manual::Charts](Charts.md#canvases). A canvas that paints
    itself from its own state is a [Term::Fabulous::Widget::Display](../Widget/Display.md).

- cell

    The word has three meanings, which the context tells apart:

    1. One character position of the terminal. Wide characters take two
    cells. Sizes, padding and positions are counted in cells.
    2. On a canvas, one position of its buffer: a character with a
    foreground and a background color. See
    ["Drawing cells" in Term::Fabulous::Manual::Charts](Charts.md#drawing-cells).
    3. In a table, the place where a row and a column meet, with the value
    the column takes from the row. See
    ["Table terms" in Term::Fabulous::Manual::Tables](Tables.md#table-terms).

- cell context (table)

    The hash reference a table passes to a column's `cell`,
    `update_cell` and `cell_style` code: the raw value, the display
    text, a copy of the row, the row id, the column and the table. See
    ["CELL WIDGETS" in Term::Fabulous::Manual::Tables](Tables.md#cell-widgets).

- character string

    Decoded Perl text, where each character is one Unicode code point.
    Compare "UTF-8 byte string".

- chart

    A canvas that draws itself from data: line, area, bar, scatter,
    histogram, sparkline, pie, donut, polar area and radar charts. See
    ["CHARTS" in Term::Fabulous::Manual::Charts](Charts.md#charts).

- Clay

    The layout engine Term::Fabulous uses; see [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) and [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).

- column, row
    1. The horizontal and vertical position of a terminal cell or a canvas
    cell, counted from 0 at the top-left corner.
    2. In a table, a row is one hash reference of your data, shown as one
    line, and a column is one [Term::Fabulous::Widget::Table::Column](../Widget/Table/Column.md)
    object, which picks a value out of each row. See
    ["Table terms" in Term::Fabulous::Manual::Tables](Tables.md#table-terms).
- column chooser (table)

    A list with a check box per column that lets the user show and hide
    the columns of a table. See
    ["Choosing the visible columns" in Term::Fabulous::Manual::Tables](Tables.md#choosing-the-visible-columns).

- content box

    The area of a widget inside its border and padding, where its children
    (or a canvas's cells) are placed.

- contributor

    A method of a widget whose name starts with `contribute_`. Clay::UI
    calls all of them, in alphabetical order, to build the widget's
    configuration (colors, border, layout) for a frame. See
    ["A box that takes the focus and reacts to the mouse" in Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md#a-box-that-takes-the-focus-and-reacts-to-the-mouse).

- cursor (table)

    The line of a [Term::Fabulous::Widget::Table](../Widget/Table.md) the keyboard works on,
    highlighted while the table has the focus. Not the same as the
    selection. See ["The cursor" in Term::Fabulous::Manual::TableRows](TableRows.md#the-cursor).

- debounced

    Delayed until the input has stopped changing for a short time; used for
    terminal resizes, see ["Event reference" in Term::Fabulous::Manual::Events](Events.md#event-reference).

- display text (table)

    The text a table cell shows: its raw value after the column's mutators.
    See ["DISPLAY TEXT AND MUTATORS" in Term::Fabulous::Manual::Tables](Tables.md#display-text-and-mutators).

- event

    Something that happened, as an object: a key press, a click, a changed
    value. Events are fired on a widget, run its listeners and then bubble.
    See ["EVENTS" in Term::Fabulous::Manual::Events](Events.md#events).

- event loop

    The [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) that [`$ui->run`](../../../../README.md#run)
    runs: it waits for input, draws frames and runs timers. See
    ["THE EVENT LOOP" in Term::Fabulous::Manual::Programs](Programs.md#the-event-loop).

- family (theme)

    The kind of a widget as the theme sees it: `button`, `input`, `table`, ... Each family has slots. See ["What a theme colors" in Term::Fabulous::Manual::Looks](Looks.md#what-a-theme-colors).

- filter expression (table)

    The text in a field of a table's filter row, such as `>=2019` or
    `!ann`; its notation depends on the column's type. See
    ["The filter row" in Term::Fabulous::Manual::TableRows](TableRows.md#the-filter-row).

- focus

    Which widget receives key presses. See ["FOCUS" in Term::Fabulous::Manual::Events](Events.md#focus).

- frame
    1. One complete layout and drawing of the screen. [Term::Fabulous](../../../../README.md) checks
    30 times per second whether a frame is needed and draws one when
    something changed, so a change "shows in the next frame" within 1/30
    second.
    2. Of a table, the lines around it, set with its `border` parameter. See
    ["Lines between and around the cells" in Term::Fabulous::Manual::TableStyles](TableStyles.md#lines-between-and-around-the-cells).
- grapheme cluster

    What a reader sees as one character, even if it consists of several
    Unicode code points (a letter with combining accents, a flag emoji).
    Cursor movement and canvas cells work with clusters.

- group, group header (table)

    The rows of a table that share the value of a group column
    (`group_by`), and the line above them that shows the value and the
    number of rows; the user opens and closes a group there. See
    ["GROUPING" in Term::Fabulous::Manual::TableRows](TableRows.md#grouping).

- hoverable, pressable, focusable

    Widgets that track whether the pointer is over them, whether they are
    pressed, and whether they can take the keyboard focus. They compose the
    [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) roles of these names: Button and the input widgets all
    three, Table and RadioGroup focusable (Table also hoverable), charts
    hoverable. See
    ["A box that takes the focus and reacts to the mouse" in Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md#a-box-that-takes-the-focus-and-reacts-to-the-mouse).

- inline mode, inline region

    A way to run a program in a few rows below the shell's output instead
    of the whole screen; the rows are the inline region. See
    ["INLINE MODE" in Term::Fabulous](../../../../README.md#inline-mode).

- interaction tracker

    The [Clay::UI::Interaction](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AInteraction) object of the UI, `$ui->interaction`:
    it knows which widget has the focus, which is hovered and which is
    pressed, and moves the focus from code. See
    ["Moving the focus" in Term::Fabulous::Manual::Events](Events.md#moving-the-focus).

- KDL

    A configuration language ([https://kdl.dev](https://kdl.dev)) in which widget trees can
    be written. See ["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](KDL.md#kdl-layout-files).

- key name

    The readable name of a key press, such as `q`, `Enter` or
    `Ctrl+Left`, as the method
    [`key_name`](../Event/KeyPress.md#key_name) of a KeyPress
    event returns it. See ["Key names" in Term::Fabulous::Manual::Events](Events.md#key-names).

- kitty keyboard protocol

    A way for terminals to report keys that the older encodings cannot
    tell apart. See ["THE KITTY KEYBOARD PROTOCOL" in Term::Fabulous::Event::KeyPress](../Event/KeyPress.md#the-kitty-keyboard-protocol).

- layout

    The sizes and positions of the widgets, which Clay works out for every
    frame from each widget's `layout` hash. See
    ["LAYOUT" in Term::Fabulous::Manual::Layout](Layout.md#layout).

- line (table)

    One entry of a table's view: a data row or a group header. Pages count
    lines. See ["Table terms" in Term::Fabulous::Manual::Tables](Tables.md#table-terms).

- listener

    A code reference registered with `$widget->on( $event_name => $code )`.
    See ["Listening to events" in Term::Fabulous::Manual::Events](Events.md#listening-to-events).

- mutator

    A code reference that turns a table cell's raw value into its display
    text, for example epoch seconds into a date; see
    [Term::Fabulous::Widget::Table::Mutator](../Widget/Table/Mutator.md).

- node (KDL)

    One element of a KDL document: a name, optional values and an optional
    block of child nodes in braces. In a layout, a node whose name starts
    with an uppercase letter is a widget, any other node a property. See
    ["Widget nodes and ids" in Term::Fabulous::Manual::KDL](KDL.md#widget-nodes-and-ids).

- notifier

    [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync)'s word for anything that runs in its event loop: timers,
    sockets, child processes, signal handlers.

- padding

    Empty space inside a widget, between its edge (or border) and its
    children, in cells per side; in a table, `cell_padding` is the space
    inside every cell. See ["Padding" in Term::Fabulous::Manual::Layout](Layout.md#padding).

- pager (table)

    The bar below a table with pages: buttons to turn the pages, the page
    number, a list of page sizes and a count of the lines. See
    ["PAGES" in Term::Fabulous::Manual::TableRows](TableRows.md#pages).

- palette (chart)

    The list of colors a chart gives its series or slices in turn:
    `default`, `classic`, `pastel`, `vivid` or colors of your own. See
    ["Colors, palettes and themes" in Term::Fabulous::Manual::Charts](Charts.md#colors-palettes-and-themes).

- pixel (PixelCanvas)

    Half a terminal cell: a [Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md) shows two
    pixels per cell, one above the other. See
    ["Drawing pixels" in Term::Fabulous::Manual::Charts](Charts.md#drawing-pixels).

- property (KDL)

    A node inside a widget node that sets one property of that widget,
    such as `sizing` or `text`. See
    ["Properties" in Term::Fabulous::Manual::KDL](KDL.md#properties).

- raw value (table)

    The value a table column reads from a row (or computes from it). Tables
    sort by it and filter by it unless told otherwise. See
    ["How a table works" in Term::Fabulous::Manual::Tables](Tables.md#how-a-table-works).

- root widget

    The widget passed as `root` to `Term::Fabulous->new`; the top of the
    widget tree.

- row id (table)

    The name of a row of a [Term::Fabulous::Widget::Table](../Widget/Table.md), used by every
    method and event. See ["Row ids" in Term::Fabulous::Manual::Tables](Tables.md#row-ids).

- selection (table)

    The set of rows of a table that the user or the program marked; not the
    same as the cursor. See ["Selection" in Term::Fabulous::Manual::TableRows](TableRows.md#selection).

- series (chart)

    A named list of data points a chart draws in one color: a line, an area,
    a group of bars or a set of points. Pie charts have slices instead. See
    ["Series and data" in Term::Fabulous::Manual::Charts](Charts.md#series-and-data).

- sizing

    The rule for a widget's width or height in its `layout`: `fit` (as
    small as the content), `grow` (take the room left over), `fixed` (a
    number of cells) or `percent` (a share of the parent). See
    ["Sizing" in Term::Fabulous::Manual::Layout](Layout.md#sizing).

- sizing group

    Widgets with the same `width_group` (or `height_group`) number get the
    same width (or height); see ["Equal sizes across the tree" in Term::Fabulous::Manual::Layout](Layout.md#equal-sizes-across-the-tree).

- slice (chart)

    One part of a pie, donut or polar area chart: a unique label and a
    value. The slices are the chart's series. See
    ["Series and data" in Term::Fabulous::Manual::Charts](Charts.md#series-and-data).

- slot (theme)

    One colored or styled part of a widget family in a theme: `button.border.color`, `input.placeholder`, `divider.line.style`. A slot has a value for the normal state and may have one for each state the widget shows (`focused`, `disabled`, ...). It defaults to a token. See ["Families, slots and states" in Term::Fabulous::Theme](../Theme.md#families-slots-and-states).

- style hash (table)

    A hash reference of looks and lines for a column, a row or a cell of a
    table, such as `{ text_color => '#ff0000', bold => 1 }`. See
    ["Style hashes" in Term::Fabulous::Manual::TableStyles](TableStyles.md#style-hashes).

- subpixel (chart)

    One of the dots or blocks a chart draws per terminal cell, for example
    the 2 x 4 Braille dots of a line or the eighth blocks of a bar. See
    ["How a chart is drawn" in Term::Fabulous::Manual::Charts](Charts.md#how-a-chart-is-drawn).

- target

    The widget an event was fired on.

- termbox2

    The C library that controls the terminal; see [Term::Fabulous::Termbox](../Termbox.md).

- terminal (object)

    The object through which [Term::Fabulous](../../../../README.md) reads input and draws: the
    real terminal ([Term::Fabulous::Terminal::Termbox](../Terminal/Termbox.md)) or a terminal in
    memory for tests ([Term::Fabulous::Terminal::Memory](../Terminal/Memory.md)). See
    [Term::Fabulous::Role::Terminal](../Role/Terminal.md).

- terminal default color

    The text and background color the terminal uses when a program does not
    set one. Colors with alpha 0 select it.

- theme

    The colors and border styles every widget draws with when it is not given its own: a palette of tokens and the slots of every widget family, with variants. Set per UI (`Term::Fabulous->new( theme => ... )`) and switched at run time; built-in: `dark` and `light`; written in theme files or in Perl. See ["THEMES" in Term::Fabulous::Manual::Looks](Looks.md#themes) and [Term::Fabulous::Theme](../Theme.md).

- theme (chart)

    Whether a chart draws its text, axes and grid with a `dark` or a
    `light` ink, and which steps of its palette it uses; `auto` (the
    default) chooses by the background. See
    ["Colors, palettes and themes" in Term::Fabulous::Manual::Charts](Charts.md#colors-palettes-and-themes).

- theme file

    A KDL file that describes a theme: a `theme` node, a `palette` node and one node per widget family. Loaded with ["from\_file" in Term::Fabulous::Theme](../Theme.md#from_file). See ["THEME FILES" in Term::Fabulous::Theme](../Theme.md#theme-files).

- token (theme)

    A named color of a theme's palette, such as `accent`, `surface` or `text`, which the slots default to. See ["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens).

- tree row, child row (table)

    In a table with `children_key`, a row can have child rows, shown
    indented below it while it is open. See
    ["TREES" in Term::Fabulous::Manual::TableRows](TableRows.md#trees).

- UTF-8 byte string

    Text encoded as UTF-8, where non-ASCII characters take several bytes, as
    produced by `encode('UTF-8', $text)`.

- variant (theme)

    Slots of a widget family that apply to the widgets whose `classes` name the variant: a `primary` variant of `button` styles the buttons with `classes => ['primary']`. See ["Variants and classes" in Term::Fabulous::Manual::Looks](Looks.md#variants-and-classes).

- view (table)

    The lines a table shows: its rows after filtering, grouping, sorting and
    flattening. See ["How a table works" in Term::Fabulous::Manual::Tables](Tables.md#how-a-table-works).

- widget

    An object that is drawn on the screen and can react to events: a box,
    text, a button, an input, a table, a chart. See
    ["The widgets" in Term::Fabulous::Manual::Layout](Layout.md#the-widgets).

- widget id

    The optional `id` string of a widget, unique in its tree. Clay keeps
    per-widget state (such as a scroll position) by it, and `find_by_id`
    finds the widget by it. See ["Widget ids" in Term::Fabulous::Manual::Layout](Layout.md#widget-ids).

- widget tree

    The root widget, its children, their children, and so on.

The table guide defines a few more words of its own (open and closed
rows, group path, row data, "passes the filters") in
[its list of table terms](Tables.md#table-terms).

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Troubleshooting](Troubleshooting.md).
