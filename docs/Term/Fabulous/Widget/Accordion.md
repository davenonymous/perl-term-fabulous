# NAME

Term::Fabulous::Widget::Accordion - Sections that open and close under
their headers

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Accordion;
use Term::Fabulous::Widget::Accordion::Item;
use Term::Fabulous::Widget::Text;

my $settings = Term::Fabulous::Widget::Accordion->new( id => 'settings' );
foreach my $section ( [ General => 'Language, time zone' ], [ Network => 'Hostname, ports' ], [ Users => 'Accounts and groups' ] ) {
        my $item = Term::Fabulous::Widget::Accordion::Item->new( title => $section->[0] );
        $item->add_child( Term::Fabulous::Widget::Text->new( text => $section->[1], text_color => '#c8cdd7' ) );
        $settings->add_child($item);
}
$settings->open(0);    # the first item

$settings->on( Select => sub ($event) {
        $status->text( ( $event->open ? 'Opened ' : 'Closed ' ) . $event->item->title );
        return;
} );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-accordion.svg" alt="Two accordions: one with the Network section open under General and a disabled Licenses section, one with borders, the toggles at the end and two sections open at once"></p>
</div>

# DESCRIPTION

The picture shows two accordions: one with its second section open
and its last section disabled, and a bordered one with the toggles at
the end of the headers and two sections open at once. The program is
`examples/widgets/accordion.pl`.

An accordion stacks sections, its _items_, each with a header line
and a body that shows while the item is open:

```text
▸ General
▾ Network
    Hostname  example.org
    Port      443
▸ Users
```

One item is open at a time: opening another closes it, and the open
item can be closed, so that all are closed. With
`multiple => 1`, any number of items can be open. The user opens
and closes an item with a click on its header, or with `Enter` or
`Space` while the header has the focus; `Tab` moves the focus from
header to header and through the widgets of the open bodies, and
`Up`, `Down`, `Home` and `End` on a header move it to the other
headers. An item can be disabled, and the accordion fires
[Term::Fabulous::Event::Select](../Event/Select.md) for every change the user makes.

Each item is a [Term::Fabulous::Widget::Accordion::Item](Accordion/Item.md): its header
holds a toggle glyph, an optional icon and the title; its body holds
the widgets you add to the item and is part of the widget tree only
while the item is open, so a closed body takes no space. The look of
the headers (the glyphs, their colors, where the toggle sits, borders
around the items) is set once, on the accordion. By default the
toggle sits at the start of the header, as in a tree; `bordered` and
`toggle_position => 'end'` give the look of a web page's
accordion.

An accordion is a [Term::Fabulous::Widget::Box](Box.md) laid out top to
bottom whose width grows unless the `layout` says otherwise; its
children are its items, and `add_child` accepts nothing else.

# CONSTRUCTOR

## new

```perl
my $accordion = Term::Fabulous::Widget::Accordion->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Box](Box.md#constructor)
(`id`, `layout`, `background_color`, the border parameters, ...)
and the ones below. All are optional; unknown parameters die.

- `multiple`

    A boolean. Default: 0, one open item at a time. True lets any number
    of items be open. Stored as 1 or 0; a reference dies.

- `bordered`

    A boolean. Default: 0. True draws a round border around every item,
    in `disabled_color`.

- `toggle_position`

    `start` (the default) or `end`: whether the toggle glyph sits before
    the title or at the right end of the header. Anything else dies.

- `open_glyph`
- `closed_glyph`

    Character strings. Default: `"\x{25BE}"` (a small down triangle) and
    `"\x{25B8}"` (a small right triangle). The toggle of an open and of a
    closed item; `'-'` and `'+'` give a plus toggle.

- `title_color`

    The color of the titles, in any format [Term::Fabulous::Color](../Color.md)
    accepts. Default: `[220, 223, 228, 255]`.

- `title_bold`

    A boolean. Default: 0. Whether the titles are bold.

- `accent_color`

    The color of an open item's toggle. Default: `[97, 175, 239, 255]`, a
    blue.

- `header_background_color`

    The background of the headers, or `undef` for none. Default:
    `undef`.

- `focus_background_color`

    The background of the header that has the focus. Default:
    `[52, 58, 72, 255]`.

- `hover_background_color`

    The background of the header under the pointer. Default:
    `[40, 45, 58, 255]`.

- `disabled_color`

    The color of a disabled item's header, and of the borders. Default:
    `[108, 112, 120, 255]`, a gray.

- `body_indent`

    A non-negative integer. Default: 2. The columns the bodies are
    indented by.

# METHODS

The methods of [Term::Fabulous::Widget](../Widget.md), plus:

## add\_child

```perl
$accordion->add_child( $item, $other_item );
```

Appends items. Dies for anything but a
[Term::Fabulous::Widget::Accordion::Item](Accordion/Item.md). When the accordion allows
one open item and an added item is open, the items open before it are
closed. Returns the accordion.

## items

```perl
my @items = $accordion->items;
```

The items, in order.

## item

```perl
my $item = $accordion->item(2);
```

The item at an index, from 0. Dies for an index outside the items.

## index\_of

```perl
my $index = $accordion->index_of($item);
```

The index of an item, or `undef`.

## open\_items

```perl
my @open = $accordion->open_items;
```

The open items, in order.

## selected

```perl
my $item = $accordion->selected;    # or undef
```

The open item, or the first open one with `multiple`; `undef` when
all are closed.

## open

```perl
$accordion->open(1);        # by index
$accordion->open($item);    # or the item
```

Opens an item from the program, closing the others unless `multiple`
allows them. Fires nothing. Dies for an index outside the items or an
item of another accordion. Returns the accordion.

## close

```perl
$accordion->close($item);
```

Closes an item. Fires nothing. Returns the accordion.

## open\_all

```perl
$accordion->open_all;
```

Opens every item. Dies unless `multiple` is set. Returns the accordion.

## close\_all

```perl
$accordion->close_all;
```

Closes every item. Returns the accordion.

## choose

```perl
$accordion->choose($index);
```

Toggles an item as the user does: opens a closed item (closing the
others unless `multiple`), closes an open one, and fires `Select`. A
disabled item changes nothing. Returns the accordion.

## multiple

```perl
$accordion->multiple(1);
```

Accessor for the `multiple` parameter. Writing 0 while several items
are open closes all but the first. Returns 1 or 0.

## bordered

```perl
$accordion->bordered(1);
```

Accessor for the `bordered` parameter. Returns 1 or 0.

## toggle\_position

```perl
$accordion->toggle_position('end');
```

Accessor for the `toggle_position` parameter: `start` or `end`.

## open\_glyph

```perl
$accordion->open_glyph('-');
```

Accessor for the `open_glyph` parameter.

## closed\_glyph

```perl
$accordion->closed_glyph('+');
```

Accessor for the `closed_glyph` parameter.

## title\_color

```perl
$accordion->title_color('#ffffff');
```

Accessor for the `title_color` parameter. The reader returns
`[r, g, b, a]`. An invalid color dies and leaves the old one.

## title\_bold

```perl
$accordion->title_bold(1);
```

Accessor for the `title_bold` parameter. Returns 1 or 0.

## accent\_color

```perl
$accordion->accent_color('#98c379');
```

Accessor for the `accent_color` parameter; works like ["title\_color"](#title_color).

## header\_background\_color

```perl
$accordion->header_background_color( [ 28, 33, 45 ] );
$accordion->header_background_color(undef);
```

Accessor for the `header_background_color` parameter; `undef`
removes the background.

## focus\_background\_color

```perl
$accordion->focus_background_color('#343a48');
```

Accessor for the `focus_background_color` parameter; works like
["title\_color"](#title_color).

## hover\_background\_color

```perl
$accordion->hover_background_color('#282d3a');
```

Accessor for the `hover_background_color` parameter; works like
["title\_color"](#title_color).

## disabled\_color

```perl
$accordion->disabled_color('#6c7078');
```

Accessor for the `disabled_color` parameter; works like
["title\_color"](#title_color).

## body\_indent

```perl
$accordion->body_indent(4);
```

Accessor for the `body_indent` parameter.

Every writer restyles the items, so the next frame shows the new look.

# KEYS

While the header of an item has the focus:

- `Enter`, `Space`

    Open or close the item (the header is a
    [Term::Fabulous::Widget::Button](Button.md)).

- `Up`, `Down`

    Move the focus to the previous or the next enabled header, wrapping
    around.

- `Home`, `End`

    Move the focus to the first or the last enabled header.

`Tab` and `Shift+Tab` move through the headers and the widgets of
the open bodies in order, as everywhere. All other keys bubble to the
ancestors.

# MOUSE

A click on a header opens or closes its item and focuses the header.
The header under the pointer is painted on `hover_background_color`.

# EVENTS

- `Select`

    [Term::Fabulous::Event::Select](../Event/Select.md) when the user opens or closes an
    item (or ["choose"](#choose) is called); `$event->item` is the item,
    `$event->index` its position and `$event->open` 1 or 0.
    Only the item the user acted on fires, not the one that closes to
    make room for it. Programmatic changes fire nothing.

The `Activate` of the headers and the events of the widgets in the
bodies bubble through the accordion as well.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`multiple`, `bordered` and `title_bold` (`#true` / `#false`),
`toggle_position`, `open_glyph`, `closed_glyph` and `body_indent`
(strings and numbers), and the colors `title_color`, `accent_color`,
`header_background_color`, `focus_background_color`,
`hover_background_color` and `disabled_color`. The items are `Item`
child nodes (see ["KDL PROPERTIES" in Term::Fabulous::Widget::Accordion::Item](Accordion/Item.md#kdl-properties)):

```kdl
use Term::Fabulous::Widget::Accordion as Accordion
use Term::Fabulous::Widget::Accordion::Item as Item
use Term::Fabulous::Widget::Text as Text

Accordion "settings" {
        bordered #true
        toggle_position "end"
        Item "general" {
                title "General"
                open #true
                Text { text "Language, time zone"; }
        }
        Item "network" {
                title "Network"
                Text { text "Hostname, ports"; }
        }
}
```

# EXAMPLES

## A plus toggle

```perl
my $faq = Term::Fabulous::Widget::Accordion->new( open_glyph => '-', closed_glyph => '+', title_bold => 1 );
```

## Remember the open section

```perl
$settings->on( Select => sub ($event) {
        $config->{section} = $event->open ? $event->item->id : undef;
        return;
} );
```

# SEE ALSO

[Term::Fabulous::Widget::Accordion::Item](Accordion/Item.md), [Term::Fabulous::Event::Select](../Event/Select.md),
[Term::Fabulous::Widget::Button](Button.md),
["ACCORDIONS" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#accordions).
