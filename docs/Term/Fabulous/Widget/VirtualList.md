# NAME

Term::Fabulous::Widget::VirtualList - A ScrollBox that attaches only the items near the viewport

# SYNOPSIS

```perl
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use Term::Fabulous::Widget::VirtualList;
use Term::Fabulous::Widget::RichText;

my @paragraphs = ...;    # tens of thousands of markup strings

my $document = Term::Fabulous::Widget::VirtualList->new(
        id       => 'document',                                   # required
        count    => scalar @paragraphs,
        build    => sub ($index) {
                return Term::Fabulous::Widget::RichText->new( markup => $paragraphs[$index] );
        },
        estimate => sub ( $index, $columns ) {                    # rows, before the item was laid out
                return 1 + int( length( $paragraphs[$index] ) / $columns );
        },
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, child_gap => 1 },
);

$document->scroll_to_item(5000);    # show paragraph 5001 at the top
```

# DESCRIPTION

A VirtualList is a [Term::Fabulous::Widget::ScrollBox](ScrollBox.md) for a long
list of items, such as the paragraphs of a document or the rows of a
large log: thousands of items, far more than fit on the screen. It
keeps the items as data and builds a widget only for the items near the
viewport, so a frame costs what the visible part costs, however long
the list is.

Why not a ScrollBox with every item as a child: Clay only paints what
is visible, but it lays out every attached widget in every frame, and
it measures every text it lays out word by word with a cache of a fixed
size (see ["LIMITATIONS" in Term::Fabulous](../../../../README.md#limitations)). A ScrollBox with a few
thousand paragraphs is slow to scroll, and one with more words than the
cache holds dies.

The list calls `build` for an item when the item comes near the
viewport and keeps the widget it returns, so an item is built once. The
widgets of the items above and below the attached ones are replaced by
two invisible spacers as tall as those items would be, so the scrollbar,
the mouse wheel and
[scroll\_state and scroll\_to](../../../../README.md#bounding_box-scroll_state-scroll_to)
see the whole list.

How tall an item is becomes known when it was laid out once at the
current width; until then the list uses `estimate`. The sum of the
heights decides where every item starts, so a wrong estimate moves the
items below it when the real height arrives. The list corrects for
that: the item at the top of the viewport stays where it is while the
heights above it change, and when the terminal gets wider or narrower.
A good estimate keeps the scrollbar's thumb steady; an exact one (the
line count of a text that does not wrap, say) makes jumps impossible.

Scrolling and the scrollbar work as on a ScrollBox. Keys do not scroll
the list; ["scroll\_to\_item"](#scroll_to_item) and
[scroll\_to](../../../../README.md#bounding_box-scroll_state-scroll_to)
move it from code. A VirtualList needs an `id`, like every ScrollBox.

# CONSTRUCTOR

## new

```perl
my $list = Term::Fabulous::Widget::VirtualList->new( id => 'log', build => sub ($index) { ... }, %parameters );
```

Unknown parameters die. A VirtualList takes every parameter of
[Term::Fabulous::Widget::ScrollBox](ScrollBox.md) (an `id` is required there) plus:

- `build`

    **Required**. A code reference called as `$build->($index)` with
    the index of an item, from 0 to `count - 1`, when the item comes near
    the viewport. It returns the item's widget: any widget without a
    parent, a [Term::Fabulous::Widget::Text](Text.md), a
    [Term::Fabulous::Widget::RichText](RichText.md), a [Term::Fabulous::Widget::Box](Box.md)
    with children, anything. The list keeps the widget and never calls
    `build` for that index again until ["rebuild"](#rebuild). A return value that
    is not a widget, a widget that has a parent, or the widget of another
    item dies when the item is built.

- `count`

    A non-negative integer, default 0. How many items the list has.

- `estimate`

    A code reference, or a non-negative integer. Default: 1. How many rows
    an item takes before it was laid out: a number of rows for every item,
    or a code reference called as `$estimate->($index, $columns)` with
    the index of the item and the columns the items wrap to, which returns
    a non-negative integer. It is called once per item and width. Anything
    else dies.

- `overscan`

    A non-negative integer or `undef`. Default: `undef`. How many rows
    beyond the viewport, above and below, the list keeps attached. The
    viewport scrolls through the attached items without a change to the
    widget tree; when it leaves them, the list attaches the items of the
    viewport and the overscan again. `undef` means the height of the
    viewport. More overscan costs more layout work per frame and changes
    the tree less often.

The layout of the list applies to the items as on a Box: `child_gap`
is the gap between items, `child_alignment`'s `x` aligns them. The
items take the list's width (minus border, padding and scrollbar), so a
text among them wraps to it. Give the list a `grow`, `fixed` or
`percent` height, like a ScrollBox.

# METHODS

A VirtualList has all methods of [Term::Fabulous::Widget::ScrollBox](ScrollBox.md)
and [Term::Fabulous::Widget](../Widget.md) except the ones that add or remove
children (["children"](#children) below), plus:

## count

```perl
$list->count(12_000);
```

Accessor. Without an argument it returns the number of items; with one
it sets it and returns the new value (an invalid value dies). The
widgets and heights of items that still exist are kept, so a log that
grows only builds its new lines. The change shows in the next frame.

## build, estimate

```perl
$list->build( sub ($index) { ... } );
$list->estimate( sub ( $index, $columns ) { ... } );
```

Accessors for the callbacks (`estimate` returns a code reference even
when it was given as a number). Setting `build` forgets every built
widget and every height, like ["rebuild"](#rebuild); setting `estimate` forgets
the estimated heights. The change shows in the next frame.

## overscan

```perl
$list->overscan(50);
```

Accessor for the overscan rows, used like ["count"](#count); `undef` means the
height of the viewport.

## rebuild

```perl
$list->rebuild;
```

Forgets every built widget and every height, so the next frame calls
`build` and `estimate` again for the items near the viewport. Call it
when the data behind the items changed. The scroll position stays, and
the item at the top of the viewport stays there. Returns the list.

## item

```perl
my $widget = $list->item(42);
```

The widget of an item, built now if the list has not built it yet. Dies
for an index the list does not have. The widget is attached while the
item is near the viewport and detached otherwise; it is the same object
each time. A text widget (a [Term::Fabulous::Widget::Text](Text.md) or
[Term::Fabulous::Widget::RichText](RichText.md)) is laid out inside a
[Term::Fabulous::Widget::Box](Box.md) of its own, because a text has no box
the list could measure; its `parent` is that box.

## scroll\_to\_item

```perl
$list->scroll_to_item(5000);
```

Scrolls so that the item starts at the top of the viewport (or as near
as the end of the list allows) in the next frame. Dies for an index the
list does not have. Returns the list.

## window

```perl
my $window = $list->window;    # { first => 118, last => 171 }, or undef
```

The indexes of the first and last item attached at the moment, or
`undef` while none is (before the first frame, or with no items).

## visible\_items

```perl
my $visible = $list->visible_items;    # { first => 140, last => 152 }, or undef
```

The indexes of the first and last item inside the viewport in the last
frame, as the list knows their heights, or `undef` while the list was
not laid out or has no items.

## children

```perl
$list->children;    # always empty
```

A VirtualList has no children of its own: `add_child`,
`insert_children`, `clear_children`, `remove_child`,
`remove_child_with_id` and `remove_children_with` die. The items are
the children of an internal column; reach one with ["item"](#item).

# EVENTS

Those of ["EVENTS" in Term::Fabulous::Widget::ScrollBox](ScrollBox.md#events): `OnScroll` in
every frame in which the mouse wheel or the scrollbar moved the list,
and `Mouse` for wheel notches and clicks.

A widget inside an item receives events like any widget while the item
is attached. When its item is detached it loses the focus and the hover,
like any removed widget.

# KDL PROPERTIES

None: a VirtualList cannot be built from a layout file, because
`build` is code. Build it in your program and add it to a Box the
layout file defines.

# CAVEATS

An item's height comes from its first layout; until then the estimate
stands in. Dragging the scrollbar far jumps into unmeasured items, so
the items may shift once when their real heights arrive. The item at
the top of the viewport is kept in place through such shifts, and
["scroll\_to\_item"](#scroll_to_item) repeats its scroll until its item has been measured.

The list learns a frame's heights when the next frame is prepared, so a
change of the terminal size shows its effect on the window in the frame
after the one that shows the new size.

An item widget that changes its height on its own (a text whose
`text` is set) is measured again in the frame after the change shows,
while it is attached; the list does not know about changes to detached
items until they are attached again.

# SEE ALSO

[Term::Fabulous::Widget::ScrollBox](ScrollBox.md), ["LIMITATIONS" in Term::Fabulous](../../../../README.md#limitations),
["Scrolling content" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#scrolling-content), the example
program `examples/widgets/virtual-list.pl`.
