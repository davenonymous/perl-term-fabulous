# NAME

Term::Fabulous::Event::Select - The user opened or closed an item of an accordion, or chose a tab

# SYNOPSIS

```perl
$accordion->on( Select => sub ($event) {
        my $item = $event->item;
        $status->text( $event->open ? 'Opened ' . $item->title : 'Closed ' . $item->title );
        return;
} );

$tabs->on( Select => sub ($event) {
        $status->text( 'Showing ' . $event->item->title );
        return;
} );
```

# DESCRIPTION

A widget that lets the user pick one of its items fires `Select` on
itself when the user does so:

- A [Term::Fabulous::Widget::Accordion](../Widget/Accordion.md), when the user opens or closes
one of its items: with a click on the item's header, with `Enter` or
`Space` while the header has the focus, or through
`$accordion->choose($index)`, which acts as the user does. Opening
and closing from your program (`open`, `close`, `open_all`,
`close_all`, `$item->open(1)`) fires nothing. When opening one
item closes another, because the accordion allows one open item at a
time, only the item the user acted on fires.
- A [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md), when the user chooses another tab:
with a click on it, with an arrow key, `Home` or `End` while the
active tab has the focus, with `Ctrl+PageUp` or `Ctrl+PageDown`
from anywhere inside, or through `$tabs->choose($index)`. The
item is the page now shown. Choosing from your program (`select`,
`$page->active(1)`) fires nothing, and so does choosing the tab
that is active already.
- A [Term::Fabulous::Widget::Tabs::Bar](../Widget/Tabs/Bar.md) used on its own, likewise; the
item is then the tab, a [Term::Fabulous::Widget::Tabs::Button](../Widget/Tabs/Button.md). Under
a Tabs, the bar's event does not bubble past the Tabs, which fires its
own with the page.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Select`; listen for
it with `$widget->on( Select => sub ($event) { ... } )`. It
bubbles to the widget's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the accordion, the Tabs or the bar.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Select->new( item => $item, index => 2, open => 1 );
```

The widgets build these events themselves; build one yourself only to
test your listeners, or to fire `Select` from a widget of your own.
Unknown parameters die, and so does an `index` that is not a
non-negative integer.

- `item`

    Required. See ["item"](#item).

- `index`

    Required. See ["index"](#index).

- `open`

    A boolean. Default: 1. See ["open"](#open).

# METHODS

## item

The widget the user chose: a [Term::Fabulous::Widget::Accordion::Item](../Widget/Accordion/Item.md),
a [Term::Fabulous::Widget::Tabs::Page](../Widget/Tabs/Page.md) (from a Tabs) or a
[Term::Fabulous::Widget::Tabs::Button](../Widget/Tabs/Button.md) (from a bar on its own).

## index

Its position among the accordion's items or the tabs, from 0.

## open

1 when the item was opened or the tab chosen, 0 when an accordion
item was closed.

# SEE ALSO

[Term::Fabulous::Widget::Accordion](../Widget/Accordion.md), [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md),
[Term::Fabulous::Widget::Tabs::Bar](../Widget/Tabs/Bar.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["ACCORDIONS" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#accordions),
["TABS" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#tabs).
