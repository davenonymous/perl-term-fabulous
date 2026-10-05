# NAME

Term::Fabulous::Widget::Accordion::Item - One section of an accordion

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Accordion;
use Term::Fabulous::Widget::Accordion::Item;

my $network = Term::Fabulous::Widget::Accordion::Item->new( title => 'Network', open => 1 );
$network->add_child( $hostname_row, $port_row );    # the body
$accordion->add_child($network);

$network->open(0);           # close it from the program; fires nothing
say $network->is_open;       # 0
$network->disabled(1);       # the user cannot open it
```

# DESCRIPTION

An item is one section of a [Term::Fabulous::Widget::Accordion](../Accordion.md): a
header line with a toggle glyph, an optional icon and a title, and a
body of any widgets below it that is shown while the item is open.
The header is a [Term::Fabulous::Widget::Button](../Button.md), so it takes the
focus, reacts to `Enter`, `Space` and clicks, and can be disabled;
the look of all headers (glyphs, colors, where the toggle sits) comes
from the accordion, see
["CONSTRUCTOR" in Term::Fabulous::Widget::Accordion](../Accordion.md#constructor).

The children you add to an item go into its body, which is part of
the widget tree only while the item is open: a closed body takes no
space, and the widgets inside it cannot take the focus. The body is a
box laid out top to bottom, indented by the accordion's
`body_indent`.

An item can also be used on its own, outside an accordion: it then
toggles itself and shows the default look.

# CONSTRUCTOR

## new

```perl
my $item = Term::Fabulous::Widget::Accordion::Item->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Box](../Box.md#constructor)
(`id`, `layout`, `background_color`, the border parameters, ...),
of which `layout_direction` is always top to bottom and the width
grows unless the `layout` says otherwise, and the ones below. Unknown
parameters die.

- `title`

    A character string. Default: `''`. The text of the header.

- `icon`

    A character string, or `undef`. Default: `undef`. A short text, for
    example a symbol, shown before the title.

- `open`

    A boolean. Default: 0. Whether the item starts open. In an accordion
    that allows one open item, the last open item added wins.

- `disabled`

    A boolean. Default: 0. A disabled item cannot be opened or closed by
    the user, is skipped by Tab and drawn in the accordion's
    `disabled_color`; its body stays as it is.

# METHODS

The methods of [Term::Fabulous::Widget](../../Widget.md), of which `add_child`,
`remove_child`, `remove_child_with_id`, `remove_children_with` and
`clear_children` act on the body (`children` and `has_child` see the
header and, while open, the body), plus:

## open

```perl
my $is_open = $item->open;
$item->open(1);
```

Accessor. Writing opens or closes the item without an event and
without regard to the accordion's `multiple`; the accordion's
["open" in Term::Fabulous::Widget::Accordion](../Accordion.md#open) keeps that rule. Returns 1 or
0.

## is\_open

```perl
if ( $item->is_open ) { ... }
```

The same as reading ["open"](#open).

## disabled

```perl
$item->disabled(1);
```

Accessor for the header's `disabled` flag. Returns 1 or 0.

## is\_enabled

The opposite of ["disabled"](#disabled).

## title

```perl
$item->title('Advanced');
```

Accessor for the title; the new text shows in the next frame.

## icon

```perl
$item->icon("\x{2699}");
$item->icon(undef);
```

Accessor for the icon.

## focus

```perl
$item->focus;
```

Gives the keyboard focus to the item's header. Dies when the item is
not part of a [Term::Fabulous](../../../../../README.md).

## is\_focused

True while the header has the focus.

## header

```perl
my $button = $item->header;
```

The header [Term::Fabulous::Widget::Button](../Button.md), to listen on it or to
style it further.

## body

```perl
my $box = $item->body;
```

The body [Term::Fabulous::Widget::Box](../Box.md), also while the item is closed.

## accordion

```perl
my $accordion = $item->accordion;
```

The [Term::Fabulous::Widget::Accordion](../Accordion.md) the item is in, or `undef`.

## refresh\_look

```perl
$item->refresh_look;
```

Updates the header from the item's state and the accordion's settings.
The accordion calls it when its settings change; call it yourself
after changing the header's look behind its back. Returns the item.

# EVENTS

An item fires no events of its own: the accordion fires
[Term::Fabulous::Event::Select](../../Event/Select.md) when the user opens or closes an
item. The header fires the events of a Button (`Activate`,
`OnFocus`, `OnBlur`, ...), which bubble through the item.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](../Box.md#kdl-properties), plus
`title` and `icon` (strings) and `open` and `disabled` (`#true` /
`#false`). Child widget nodes go into the body:

```kdl
use Term::Fabulous::Widget::Accordion::Item as Item

Item "network" {
        title "Network"
        open #true
        Text { text "Hostname: example.org"; }
}
```

# SEE ALSO

[Term::Fabulous::Widget::Accordion](../Accordion.md), [Term::Fabulous::Event::Select](../../Event/Select.md),
["ACCORDIONS" in Term::Fabulous::Manual::Layout](../../Manual/Layout.md#accordions).
