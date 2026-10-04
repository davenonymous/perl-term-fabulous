# NAME

Term::Fabulous::Cookbook - Recipes for common Term::Fabulous tasks

# HOW TO USE THIS COOKBOOK

The cookbook is a collection of recipes: short, complete solutions to
common tasks, each with a program you can run and change. The recipes
are grouped by topic into fourteen pages. ["THE RECIPES"](#the-recipes) below lists
every page with every recipe on it. Each page lists its own recipes at
the top and links to the previous and the next page, so you can also
read the cookbook from start to end.

The cookbook shows _how_ to do something. The concepts behind the
recipes (layout, colors, events, focus, forms, charts, tables, KDL
layouts) are explained in [Term::Fabulous::Manual](Manual.md), and every class
has a reference page of its own. The recipes link to the exact sections
they rely on.

## How a recipe is written

Every recipe solves one task. Its title names the task in plain words,
often followed in parentheses by the classes, options or keywords it
uses, so a search for the task or the class finds it: search this index (with `/` in
`perldoc Term::Fabulous::Cookbook`, or with the browser on MetaCPAN),
or the page of the topic.

A recipe starts with one sentence on its goal, introduced with "Goal:".
Then it shows a complete program or a snippet, a picture of the
program running (or the text it prints), and a list that explains the
lines that matter, with links to the reference documentation.

A snippet is not a complete program. It shows the lines that change
the program of another recipe and names that recipe with a link. When
a snippet uses `$root` or `$ui`, these are the root widget and the
[Term::Fabulous](../../../README.md) object of that program.

## Running the programs

You need not copy the programs: every complete program is shipped as a
file in the distribution, and each recipe names its file. Most are in
the `examples/cookbook` directory and start with this header:

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
```

Programs with non-ASCII text in their source add `use utf8` after
`use warnings`.

A few recipes show a demo program from the `examples` directory,
which holds the programs of [Term::Fabulous::Examples](Examples.md). Those start
with `use experimental 'signatures'` instead of
`use feature 'signatures'`, and with a `use lib "$FindBin::Bin/../lib/"`
line.

Run a program with `perl FILE` in a terminal that uses a UTF-8 locale
and supports 24-bit colors (see ["REQUIREMENTS" in Term::Fabulous::Manual](Manual.md#requirements)),
after installing Term::Fabulous. In an unpacked copy of the
distribution that is built but not installed (`perl Makefile.PL &&
make`), add `-Mblib`:

```sh
perl -Mblib examples/cookbook/minimal-program.pl
```

Interactive programs take over the terminal (all of it, or a few
rows below the shell's output in inline mode); Ctrl+C ends every one of
them. Programs that only print something, such as a report
made with [Term::Fabulous::Static](Static.md) or the results of a test, print
and end on their own.

The pictures are taken from the shipped files by running them in a
terminal of the size shown, after the input the recipe describes, so
they show exactly what the code does. They appear in the HTML version
of the documentation, for example on MetaCPAN, but not in `perldoc`;
programs that print text show that text in the recipe as well.

# THE RECIPES

The pages, in reading order, each with its recipes:

- [Term::Fabulous::Cookbook::GettingStarted](Cookbook/GettingStarted.md)

    A first program, quitting and text:

    - [A minimal program to start from](Cookbook/GettingStarted.md#a-minimal-program-to-start-from)
    - [Quit with q or Escape](Cookbook/GettingStarted.md#quit-with-q-or-escape)
    - [Show non-ASCII text (umlauts, CJK, combining accents)](Cookbook/GettingStarted.md#show-non-ascii-text-umlauts-cjk-combining-accents)
    - [Wrap, align and space text](Cookbook/GettingStarted.md#wrap-align-and-space-text)
    - [Let the terminal handle the mouse (select and copy text)](Cookbook/GettingStarted.md#let-the-terminal-handle-the-mouse-select-and-copy-text)

- [Term::Fabulous::Cookbook::KeyboardAndMouse](Cookbook/KeyboardAndMouse.md)

    Key bindings and buttons:

    - [Bind a key to an action](Cookbook/KeyboardAndMouse.md#bind-a-key-to-an-action)
    - [Add buttons for the mouse and the keyboard (Button)](Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button)

- [Term::Fabulous::Cookbook::LiveData](Cookbook/LiveData.md)

    Timers, logs and the output of commands:

    - [Update the screen from a timer (a clock)](Cookbook/LiveData.md#update-the-screen-from-a-timer-a-clock)
    - [Add lines to a scrolling log (ScrollBox)](Cookbook/LiveData.md#add-lines-to-a-scrolling-log-scrollbox)
    - [Scroll a ScrollBox from code (keep a log at the newest line)](Cookbook/LiveData.md#scroll-a-scrollbox-from-code-keep-a-log-at-the-newest-line)
    - [Show the output of a running command](Cookbook/LiveData.md#show-the-output-of-a-running-command)

- [Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md)

    Forms, dialogs and input widgets:

    - [A login form (centered dialog, masked password)](Cookbook/Forms.md#a-login-form-centered-dialog-masked-password)
    - [Ask a question in a dialog (Dialog widget)](Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget)
    - [Ask for input below the shell's output (inline mode)](Cookbook/Forms.md#ask-for-input-below-the-shell-s-output-inline-mode)
    - [Choose from options in Perl (Dropdown, RadioGroup, Slider)](Cookbook/Forms.md#choose-from-options-in-perl-dropdown-radiogroup-slider)
    - [Read all values of a form](Cookbook/Forms.md#read-all-values-of-a-form)
    - [Find widgets by id](Cookbook/Forms.md#find-widgets-by-id)
    - [Build a form from a KDL file (text fields, radio buttons, dropdown, slider, checkbox)](Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox)
    - [Disable inputs until a checkbox is checked](Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked)
    - [Show a status line that follows the focus (OnFocus)](Cookbook/Forms.md#show-a-status-line-that-follows-the-focus-onfocus)
    - [Change the Tab order (HasFocusOrder)](Cookbook/Forms.md#change-the-tab-order-hasfocusorder)
    - [Copy and paste through the clipboard](Cookbook/Forms.md#copy-and-paste-through-the-clipboard)

- [Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md)

    Layout, borders, colors and themes:

    - [Line up labels with equal widths (width\_group)](Cookbook/Layout.md#line-up-labels-with-equal-widths-width_group)
    - [Use a different border style on each side](Cookbook/Layout.md#use-a-different-border-style-on-each-side)
    - [Change colors at run time (a theme with lighten and darken)](Cookbook/Layout.md#change-colors-at-run-time-a-theme-with-lighten-and-darken)
    - [Mark widgets with states and classes](Cookbook/Layout.md#mark-widgets-with-states-and-classes)
    - [Change the layout with the terminal size (Start and Resize events)](Cookbook/Layout.md#change-the-layout-with-the-terminal-size-start-and-resize-events)

- [Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md)

    Show, format, edit and print tables:

    - [Show a list of hashes in a table (sort, select, open a row)](Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row)
    - [Format cells: dates, numbers, sizes and flags (mutators)](Cookbook/Tables.md#format-cells-dates-numbers-sizes-and-flags-mutators)
    - [Edit the data of a table (widget cells, add and remove rows and columns)](Cookbook/Tables.md#edit-the-data-of-a-table-widget-cells-add-and-remove-rows-and-columns)
    - [Let the user choose the visible columns (column chooser)](Cookbook/Tables.md#let-the-user-choose-the-visible-columns-column-chooser)
    - [Describe a table in a KDL layout (columns, lines, sort, groups)](Cookbook/Tables.md#describe-a-table-in-a-kdl-layout-columns-lines-sort-groups)
    - [Print a table as a report (Static)](Cookbook/Tables.md#print-a-table-as-a-report-static)

- [Term::Fabulous::Cookbook::TableRows](Cookbook/TableRows.md)

    Sort, filter, group, nest and page table rows:

    - [Sort rows, also with your own comparison](Cookbook/TableRows.md#sort-rows-also-with-your-own-comparison)
    - [Let the user filter rows (filter row and search box)](Cookbook/TableRows.md#let-the-user-filter-rows-filter-row-and-search-box)
    - [Filter rows from Perl (numbers, dates, text, raw or shown values)](Cookbook/TableRows.md#filter-rows-from-perl-numbers-dates-text-raw-or-shown-values)
    - [Group rows by a column (collapsible group headers)](Cookbook/TableRows.md#group-rows-by-a-column-collapsible-group-headers)
    - [Show nested data as a tree (expand and collapse rows)](Cookbook/TableRows.md#show-nested-data-as-a-tree-expand-and-collapse-rows)
    - [Split many rows into pages (pager and page sizes)](Cookbook/TableRows.md#split-many-rows-into-pages-pager-and-page-sizes)

- [Term::Fabulous::Cookbook::TableStyles](Cookbook/TableStyles.md)

    Column sizes, lines and colors of tables:

    - [Size, align and wrap columns (widths, wrapping, widget titles)](Cookbook/TableStyles.md#size-align-and-wrap-columns-widths-wrapping-widget-titles)
    - [Lines and colors per row, column and cell (conditional formatting)](Cookbook/TableStyles.md#lines-and-colors-per-row-column-and-cell-conditional-formatting)
    - [A table with colored rows and titles (block frame, no grid lines)](Cookbook/TableStyles.md#a-table-with-colored-rows-and-titles-block-frame-no-grid-lines)
    - [Compare the line options of a table (frames, grid lines, block frames)](Cookbook/TableStyles.md#compare-the-line-options-of-a-table-frames-grid-lines-block-frames)

- [Term::Fabulous::Cookbook::Charts](Cookbook/Charts.md)

    One for each chart type:

    - [Draw a line chart with labels and points (LineChart)](Cookbook/Charts.md#draw-a-line-chart-with-labels-and-points-linechart)
    - [Grouped, stacked and horizontal bars (BarChart)](Cookbook/Charts.md#grouped-stacked-and-horizontal-bars-barchart)
    - [Show shares as a pie or donut (PieChart, DonutChart)](Cookbook/Charts.md#show-shares-as-a-pie-or-donut-piechart-donutchart)
    - [A scatter plot with trend lines (ScatterPlot)](Cookbook/Charts.md#a-scatter-plot-with-trend-lines-scatterplot)
    - [Stacked areas and shares of 100% (AreaChart)](Cookbook/Charts.md#stacked-areas-and-shares-of-100-areachart)
    - [How values are distributed (Histogram)](Cookbook/Charts.md#how-values-are-distributed-histogram)
    - [Compare profiles on radar and polar area charts (RadarChart, PolarAreaChart)](Cookbook/Charts.md#compare-profiles-on-radar-and-polar-area-charts-radarchart-polarareachart)
    - [Show sparklines in table cells (Sparkline)](Cookbook/Charts.md#show-sparklines-in-table-cells-sparkline)

- [Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md)

    Time axes, live data, transforms, KDL layouts and printed reports with charts:

    - [Plot values over time (time axis, from and to, a dashed forecast)](Cookbook/ChartTechniques.md#plot-values-over-time-time-axis-from-and-to-a-dashed-forecast)
    - [A live chart that follows new data (append, max\_points, span)](Cookbook/ChartTechniques.md#a-live-chart-that-follows-new-data-append-max_points-span)
    - [Show values of very different sizes (logarithmic axis)](Cookbook/ChartTechniques.md#show-values-of-very-different-sizes-logarithmic-axis)
    - [Smooth noisy data and index it to 100 (transforms)](Cookbook/ChartTechniques.md#smooth-noisy-data-and-index-it-to-100-transforms)
    - [Describe charts in a KDL layout (series, slices, transforms)](Cookbook/ChartTechniques.md#describe-charts-in-a-kdl-layout-series-slices-transforms)
    - [Print charts in a report (Static)](Cookbook/ChartTechniques.md#print-charts-in-a-report-static)

- [Term::Fabulous::Cookbook::ChartStyles](Cookbook/ChartStyles.md)

    Curves, markers, colors, line styles and hover of charts:

    - [Connect points with curves and easings (curve)](Cookbook/ChartStyles.md#connect-points-with-curves-and-easings-curve)
    - [Draw with Braille, blocks or box lines (marker)](Cookbook/ChartStyles.md#draw-with-braille-blocks-or-box-lines-marker)
    - [Light backgrounds, palettes and colors of your own](Cookbook/ChartStyles.md#light-backgrounds-palettes-and-colors-of-your-own)
    - [Line styles, gaps, bar widths, stack groups and grid lines](Cookbook/ChartStyles.md#line-styles-gaps-bar-widths-stack-groups-and-grid-lines)
    - [Show details of the point under the pointer (SeriesHover, highlight)](Cookbook/ChartStyles.md#show-details-of-the-point-under-the-pointer-serieshover-highlight)

- [Term::Fabulous::Cookbook::Canvases](Cookbook/Canvases.md)

    Draw on a canvas:

    - [Paint with the mouse (Canvas, clicks and drags)](Cookbook/Canvases.md#paint-with-the-mouse-canvas-clicks-and-drags)
    - [Plot data on a pixel canvas (PixelCanvas)](Cookbook/Canvases.md#plot-data-on-a-pixel-canvas-pixelcanvas)

- [Term::Fabulous::Cookbook::Output](Cookbook/Output.md)

    Reports and tests without a terminal:

    - [Render a report to a file or pipe (Static)](Cookbook/Output.md#render-a-report-to-a-file-or-pipe-static)
    - [Test a widget without a terminal](Cookbook/Output.md#test-a-widget-without-a-terminal)

- [Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md)

    Your own widgets and events:

    - [Write a custom input widget (a toggle switch)](Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch)
    - [Make a widget usable from KDL](Cookbook/Extending.md#make-a-widget-usable-from-kdl)
    - [Fire your own events](Cookbook/Extending.md#fire-your-own-events)

# SEE ALSO

[Term::Fabulous](../../../README.md) (the main module), [Term::Fabulous::Manual](Manual.md) (concepts
and reference overview), the widget classes under
`Term::Fabulous::Widget::`, [Term::Fabulous::Layout](Layout.md) (KDL layouts),
[Term::Fabulous::Static](Static.md) (rendering to text), and
[Term::Fabulous::Examples](Examples.md) (all example programs of the distribution,
with pictures).
