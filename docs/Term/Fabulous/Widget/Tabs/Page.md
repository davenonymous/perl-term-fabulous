# NAME

Term::Fabulous::Widget::Tabs::Page - One page of a Tabs widget

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Tabs;
use Term::Fabulous::Widget::Tabs::Page;

my $network = Term::Fabulous::Widget::Tabs::Page->new( title => 'Network', icon => "\x{2601}" );
$network->add_child( $hostname_row, $port_row );    # the content
$tabs->add_child($network);

$network->active(1);        # show it; fires nothing
say $network->is_active;    # 1
$network->disabled(1);      # the user cannot switch to it
```

# DESCRIPTION

A page is one tab of a [Term::Fabulous::Widget::Tabs](../Tabs.md): a box of any
widgets that is shown while its tab is the active one, and a title
with an optional icon for the tab button that the Tabs makes for it.
Only the active page is part of the widget tree: the other pages take
no space, and the widgets inside them cannot take the focus.

A page is a [Term::Fabulous::Widget::Box](../Box.md) that, unless its `layout`
says otherwise, stacks its children top to bottom, grows to fill the
Tabs and keeps one cell of padding on every side. The Tabs draws a
border around it in its `line_style` and `line_color`, open on the
side of the tab bar, unless its `page_border` is off (see
["CONSTRUCTOR" in Term::Fabulous::Widget::Tabs](../Tabs.md#constructor)); the page's own border
parameters are overwritten.

A page can also be used on its own, outside a Tabs: it is then a plain
box that remembers its title.

# CONSTRUCTOR

## new

```perl
my $page = Term::Fabulous::Widget::Tabs::Page->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Box](../Box.md#constructor)
(`id`, `layout`, `background_color`, ...) and the ones below.
Unknown parameters die.

- `title`

    A character string. Default: `''`. The text of the tab.

- `icon`

    A character string, or `undef`. Default: `undef`. A short text, for
    example a symbol, shown before the title (above it in a tab with a
    vertical label).

- `active`

    A boolean. Default: 0. Whether the page becomes the active one when it
    is added to a Tabs. Without it, the first enabled page added is the
    active one.

- `disabled`

    A boolean. Default: 0. A disabled page cannot be chosen by the user:
    its tab is drawn in the Tabs' `disabled_color`, skipped by the keys
    and ignores clicks. A page that is disabled while it is active stays
    shown.

# METHODS

The methods of [Term::Fabulous::Widget](../../Widget.md) (`add_child` and the other
children methods act on the content), plus:

## title

```perl
$page->title('Advanced');
```

Accessor for the title; the tab shows the new text in the next frame.

## icon

```perl
$page->icon("\x{2699}");
$page->icon(undef);
```

Accessor for the icon.

## disabled

```perl
$page->disabled(1);
```

Accessor for the `disabled` flag. Returns 1 or 0.

## is\_enabled

The opposite of ["disabled"](#disabled).

## active

```perl
my $shown = $page->active;
$page->active(1);
```

Accessor. In a Tabs, reading tells whether the page is the active one,
and writing a true value makes it active (a false value shows no page),
without an event, like ["select" in Term::Fabulous::Widget::Tabs](../Tabs.md#select). On its
own, the page remembers the value for the Tabs it joins. Returns 1 or
0.

## is\_active

```perl
if ( $page->is_active ) { ... }
```

1 while the page is the active one of its Tabs, 0 otherwise (also
outside a Tabs).

## tabs

```perl
my $tabs = $page->tabs;
```

The [Term::Fabulous::Widget::Tabs](../Tabs.md) the page belongs to, or `undef`.
Unlike `parent`, it is set also while the page is not shown.

# EVENTS

A page fires no events of its own: the Tabs fires
[Term::Fabulous::Event::Select](../../Event/Select.md) when the user chooses a tab. The
events of the widgets in the page bubble through it.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](../Box.md#kdl-properties), plus
`title` and `icon` (strings) and `active` and `disabled`
(`#true` / `#false`). Child widget nodes are the content:

```kdl
use Term::Fabulous::Widget::Tabs::Page as Page

Page "network" {
        title "Network"
        active #true
        Text { text "Hostname: example.org"; }
}
```

# SEE ALSO

[Term::Fabulous::Widget::Tabs](../Tabs.md), [Term::Fabulous::Event::Select](../../Event/Select.md),
["TABS" in Term::Fabulous::Manual::Layout](../../Manual/Layout.md#tabs).
