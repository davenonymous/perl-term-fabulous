# NAME

Term::Fabulous::Scrolling - Scroll a container by rows, by pages and to its ends, as a pager does

# SYNOPSIS

```perl
use Term::Fabulous::Scrolling qw(scroll_by_key scroll_by_rows scroll_by_pages scroll_offset scroll_to_end scrolled_percent);

my $box = $ui->find_by_id('log');    # a ScrollBox, a VirtualList, a document view
scroll_by_rows( $ui, $box, 1 );      # one row down
scroll_by_pages( $ui, $box, -1 );    # one page up
scroll_to_end( $ui, $box );
say scrolled_percent( $ui, $box ), '%';
say 'scrolled down by ', scroll_offset( $ui, $box ), ' rows';

scroll_by_rows( $ui, $box, 1 ) or say 'already at the end';

# PageUp, PageDown, Ctrl+Home and Ctrl+End, in a KeyPress listener:
my $moved = scroll_by_key( $ui, $box, $event->main_key_name, keys => 'pager' );
return Clay::UI::Enum::Result->HANDLED if defined $moved;
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
    takes the container's `content_box` (["content\_box" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#content_box)): its box
    in the last frame less the padding that frame declared for it, which is
    where Term::Fabulous reserves the room for the border and the
    scrollbars.

- Scrolling stops at the ends of the content. Every function that
scrolls returns 1 when it moved the content and 0 when it did not, for
example because the content is already at that end. A key handler can
use the return value to tell whether the key had an effect.
- Offsets are positive: 0 at the start of the content, growing as it is
scrolled down (or right). Clay keeps the scroll position as a negative
number; this module turns it around, so a program never needs to (see
["scroll\_offset"](#scroll_offset)).
- A [Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md) (a document view too) knows
the height of the items it has not built only as an estimate, so
["scroll\_to\_start, scroll\_to\_end"](#scroll_to_start-scroll_to_end) send it to its first or last
item (["scroll\_to\_item" in Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md#scroll_to_item)), which it
measures on the way.
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

## scroll\_by\_columns

```perl
my $moved = scroll_by_columns( $ui, $widget, $columns );
```

Scrolls the content sideways by `$columns` columns: right for a
positive number, left for a negative one, and no further than either
end. For a container that scrolls sideways (a ScrollBox with
`horizontal => 1`). Returns 1 when the content moved and 0
otherwise.

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
otherwise. A VirtualList is asked to show its first or last item
instead; for it, 1 means it was asked, 0 that it already shows that end
or has no items.

## reveal\_rows

```perl
my $moved = reveal_rows( $ui, $widget, $from, $to );
my $moved = reveal_rows( $ui, $widget, $from, $to, align => 'top' );
```

Scrolls the rows from screen row `$from` up to, but not including,
screen row `$to` into the container's inner rows (see ["inner\_rows"](#inner_rows)).
Both rows are screen coordinates, as
["bounding\_box, scroll\_state, scroll\_to" in Term::Fabulous](../../../README.md#bounding_box-scroll_state-scroll_to) reports them.
`align` says how:

- `nearest` (the default)

    With the smallest possible move. The content does not move when the
    rows are already in view. Rows above the view end up at its top, and
    rows below it end up at its bottom. When the rows are more than the
    view can show, their first row goes to the top (see
    ["reveal\_range" in Term::Fabulous::Viewport](Viewport.md#reveal_range)).

- `top`

    The first row goes to the top of the view, as far as the content
    allows: near the end of the content, the content stops at its end.

Another `align` or another option dies. Returns 1 when the content
moved and 0 otherwise.

## scroll\_by\_key

```perl
my $moved = scroll_by_key( $ui, $widget, $event->main_key_name, keys => 'pager' );
my $moved = scroll_by_key( $ui, $widget, $event->main_key_name, keys => 'less' );
```

Scrolls as a key of a pager does. `keys` names the set of keys, and is
required:

| Set     | Key             | Move          |
| ------- | --------------- | ------------- |
| `pager` | PageDown        | one page down |
|         | PageUp          | one page up   |
|         | Ctrl+End        | to the end    |
|         | Ctrl+Home       | to the start  |
| `less`  | Down, j         | one row down  |
|         | Up, k           | one row up    |
|         | PageDown, Space | one page down |
|         | PageUp, b       | one page up   |
|         | End, G          | to the end    |
|         | Home, g         | to the start  |

`pager` is for a container whose arrow keys belong to the widgets
inside it, `less` for one that is read like a text, as
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md) is. Pages are those of
["scroll\_by\_pages"](#scroll_by_pages). The key is a name as
["main\_key\_name" in Term::Fabulous::Event::KeyPress](Event/KeyPress.md#main_key_name) returns it.

Returns `undef` when the key is not in the set (also for `undef`), so
that the caller can let it go on; for a key of the set, 1 when the
content moved and 0 when it did not (it is already at that end, or not
laid out yet), either way a key the set uses. Another `keys` or another
option dies.

## scroll\_offset

```perl
my $rows = scroll_offset( $ui, $widget );
```

How far the content is scrolled down, in rows: 0 at the start, up to
["max\_scroll\_offset"](#max_scroll_offset) at the end. Clay keeps fractions of a row, so the
number may have a fraction too. Returns `undef` before the first frame
has laid the container out.

## max\_scroll\_offset

```perl
my $rows = max_scroll_offset( $ui, $widget );
```

The largest ["scroll\_offset"](#scroll_offset), where the last row of the content is at
the bottom of the view: the content height less the viewport's, at
least 0. Returns `undef` before the first frame has laid the container
out.

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
