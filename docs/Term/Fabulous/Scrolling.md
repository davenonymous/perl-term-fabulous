# NAME

Term::Fabulous::Scrolling - Scroll a container by rows, by pages and to its ends

# SYNOPSIS

```perl
use Term::Fabulous::Scrolling qw(scroll_by_rows scroll_by_pages scroll_to_start scroll_to_end scrolled_percent);

my $box = $ui->find_by_id('log');    # a ScrollBox, a VirtualList, a document view
scroll_by_rows( $ui, $box, 1 );          # a row down
scroll_by_pages( $ui, $box, -1 );        # a page up
scroll_to_end( $ui, $box );
say scrolled_percent( $ui, $box ), '%';

scroll_by_rows( $ui, $box, 1 ) or say 'already at the end';
```

# DESCRIPTION

A program that scrolls a container with its keys, as a pager does, needs
the same few moves for every container: a row, a page, the ends, and a
range of rows into view. Every scroll container of Clay is scrolled the
same way, with the
[scroll\_to and scroll\_state](../../../README.md#bounding_box-scroll_state-scroll_to)
of the UI, and by the same rules, which this module holds:

- A _page_ is the rows the container shows inside its border, padding
and scrollbars, less one, which stays in view as a landmark; at least
one row. Clay's viewport is the whole box of the container, border
included, so the module measures the box with `bounding_box` and takes
off the padding of the container's declaration (`to_config`), where
Term::Fabulous puts the border and the scrollbars too.
- Scrolling stops at the ends, and a function that scrolls returns 1 when
it moved the content and 0 when it could not, so a key binding can
tell. Clay keeps the position in fractions of a row; a move of less
than half a row is none.

The arithmetic is [Term::Fabulous::Viewport](Viewport.md)'s. The functions take
the UI and the container, so that a test gives them a small
[Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md) on a memory terminal. Before the
first frame laid the container out, there is nothing to scroll: the
functions that scroll return 0, and the others `undef` or an empty
list. [Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md) scrolls with these
functions.

# FUNCTIONS

Nothing is exported by default. Every function dies when the UI is
not a UI or the widget not a widget; the number of rows or pages must
be an integer, negative to scroll up.

## scroll\_by\_rows

```perl
scroll_by_rows( $ui, $widget, $rows );
```

Scrolls by rows: down for a positive number, up for a negative one.

## scroll\_by\_pages

```perl
scroll_by_pages( $ui, $widget, $pages );
```

Scrolls by pages of ["page\_rows"](#page_rows).

## scroll\_to\_start, scroll\_to\_end

```perl
scroll_to_end( $ui, $widget );
```

Scrolls to the top or to the end of the content.

## reveal\_rows

```perl
reveal_rows( $ui, $widget, $from, $to );
```

Scrolls the screen rows from `$from` to before `$to` into the inner
rows, with the smallest move: not at all when they are in view, and so
that the first of them is at the top or the last at the bottom
otherwise; rows taller than the view show their start (see
["reveal\_range" in Term::Fabulous::Viewport](Viewport.md#reveal_range)).

## inner\_rows

```perl
my ( $top, $bottom ) = inner_rows( $ui, $widget );
```

The first screen row of the container's content and the row after its
last, inside the border, padding and scrollbars; an empty list before
the first frame.

## page\_rows

```perl
my $rows = page_rows( $ui, $widget );
```

The rows of a page: the inner rows less one, at least one.

## scrolled\_percent

```perl
my $percent = scrolled_percent( $ui, $widget );
```

How far the content is scrolled, from 0 at the top to 100 at the end,
rounded; 100 when the content fits, so that it is seen whole.

# SEE ALSO

[Term::Fabulous::Viewport](Viewport.md), [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md),
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md), ["SCROLLING" in Term::Fabulous::Manual::Events](Manual/Events.md#scrolling).
