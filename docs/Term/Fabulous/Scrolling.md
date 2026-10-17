# NAME

Term::Fabulous::Scrolling - Scroll a container by rows, by pages and to its ends, as a pager does

# SYNOPSIS

```perl
use Term::Fabulous::Scrolling qw(scroll_by_rows scroll_by_pages scroll_to_start scroll_to_end scrolled_percent);

my $box = $ui->find_by_id('log');    # a ScrollBox, a VirtualList, a document view
scroll_by_rows( $ui, $box, 1 );      # one row down
scroll_by_pages( $ui, $box, -1 );    # one page up
scroll_to_end( $ui, $box );
say scrolled_percent( $ui, $box ), '%';

scroll_by_rows( $ui, $box, 1 ) or say 'already at the end';
```

# DESCRIPTION

A program that lets the user scroll a container with keys, as a pager
does, needs the same few moves for every container: by a row, by a
page, to either end, and far enough to bring a range of rows into view.
This module provides these moves for any scroll container, such as a
[Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md), a
[Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md) or a
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md).
[Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md) has a recipe that scrolls a
ScrollBox with pager keys using these functions.

All scroll containers are scrolled the same way, with the UI's
[scroll\_state and scroll\_to](../../../README.md#bounding_box-scroll_state-scroll_to)
methods, and this module applies the same rules to all of them:

- A _page_ is the number of rows the container shows inside its border,
padding and scrollbars, less one. The row that is kept stays in view
after the move and helps the reader find their place. A page is at
least one row.

    Clay reports the whole box of the container as its viewport, border
    included. To find the rows that show content, the module therefore
    takes the box from `bounding_box` and subtracts the padding of the
    container's layout (from its `to_config`), which is where
    Term::Fabulous reserves the room for the border and the scrollbars.

- Scrolling stops at the ends of the content. Every function that
scrolls returns 1 when it moved the content and 0 when it did not, for
example because the content is already at that end. A key handler can
use the return value to tell whether the key had an effect.
- Clay keeps the scroll position in fractions of a row. A function
compares the target position with the current one, both rounded to the
nearest whole row; when they round to the same row, it does not scroll
and returns 0.

Before the first frame has laid the container out, Clay knows neither
its size nor its scroll position, so there is nothing to scroll. Until
then the functions that scroll return 0 without doing anything,
["page\_rows"](#page_rows) and ["scrolled\_percent"](#scrolled_percent) return `undef`, and
["inner\_rows"](#inner_rows) returns an empty list.

The calculations come from [Term::Fabulous::Viewport](Viewport.md). The functions
take the UI and the container as arguments rather than being methods of
a widget, so any container can use them and a test can exercise them
with a small ScrollBox on a memory terminal. The document view uses
them for its line and page keys, to scroll search matches and links
into view, and for the percentage it reports.

# FUNCTIONS

Nothing is exported by default. Every function takes the UI (a
[Term::Fabulous](../../../README.md) object) and the scroll container as its first two
arguments and dies when the UI cannot report scroll states or the
container is not an object. Counts of rows and pages must be integers;
a negative count scrolls up. Anything else dies.

## scroll\_by\_rows

```perl
my $moved = scroll_by_rows( $ui, $widget, $rows );
```

Scrolls the content by `$rows` rows: down for a positive number, up
for a negative one, and no further than either end. Returns 1 when the
content moved and 0 otherwise.

## scroll\_by\_pages

```perl
my $moved = scroll_by_pages( $ui, $widget, $pages );
```

Scrolls the content by `$pages` pages of ["page\_rows"](#page_rows) rows each: down
for a positive number, up for a negative one. Returns 1 when the
content moved and 0 otherwise.

## scroll\_to\_start, scroll\_to\_end

```perl
my $moved = scroll_to_start( $ui, $widget );
my $moved = scroll_to_end( $ui, $widget );
```

Scroll to the top of the content, or so far down that its last row is
at the bottom of the view. Return 1 when the content moved and 0
otherwise.

## reveal\_rows

```perl
my $moved = reveal_rows( $ui, $widget, $from, $to );
```

Scrolls the rows from screen row `$from` up to, but not including,
screen row `$to` into the container's inner rows (see ["inner\_rows"](#inner_rows)),
with the smallest possible move. The content does not move when the
rows are already in view. Rows above the view end up at its top, and
rows below it end up at its bottom. When the rows are more than the
view can show, their first row goes to the top (see
["reveal\_range" in Term::Fabulous::Viewport](Viewport.md#reveal_range)). Both rows are screen
coordinates, as ["bounding\_box, scroll\_state, scroll\_to" in Term::Fabulous](../../../README.md#bounding_box-scroll_state-scroll_to)
reports them. Returns 1 when the content moved and 0 otherwise.

## inner\_rows

```perl
my ( $top, $bottom ) = inner_rows( $ui, $widget );
```

Returns the screen row of the first row of the container's content and
the screen row just below its last one, both inside the border, padding
and scrollbars. `$bottom - $top` is the number of rows that show
content. Returns an empty list before the first frame has laid the
container out.

## page\_rows

```perl
my $rows = page_rows( $ui, $widget );
```

Returns the number of rows in a page: the inner rows less one, at least
1\. Returns `undef` before the first frame has laid the container out.

## scrolled\_percent

```perl
my $percent = scrolled_percent( $ui, $widget );
```

Returns how far the content is scrolled down, as an integer from 0 at
the top to 100 at the end, rounded to the nearest percent. When all of
the content fits into the view, it returns 100, because the reader
sees all of it. Returns `undef` before the first frame has laid the
container out.

# SEE ALSO

[Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md), [Term::Fabulous::Viewport](Viewport.md),
[Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md), [Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md),
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md), ["SCROLLING" in Term::Fabulous::Manual::Events](Manual/Events.md#scrolling).
