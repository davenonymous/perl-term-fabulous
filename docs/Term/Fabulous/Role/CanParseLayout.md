# NAME

Term::Fabulous::Role::CanParseLayout - Let a widget class be built from
a KDL layout

# SYNOPSIS

```perl
package My::Panel;
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
use Object::Pad 0.825;
use Term::Fabulous::Widget::Box;

# Box already composes Term::Fabulous::Role::CanParseLayout.
# This class only stores what the layout says; drawing the title is
# up to the class (see examples/custom-widget.pl for a full widget).
class My::Panel :isa(Term::Fabulous::Widget::Box) :strict(params) {
        field $title       :param :accessor = '';
        field $title_color :param :accessor = [ 255, 255, 255, 255 ];
        field @shortcuts;

        # The properties a layout may set, and how each is read:
        # title "Settings", title_color "#ffcc00", shortcut key="F2" action="save".
        method layout_properties :common () {
                return (
                        $class->SUPER::layout_properties,
                        title       => 'scalar',
                        title_color => 'color',
                        shortcut    => \&_parse_shortcut,
                );
        }

        method _parse_shortcut ($kid) {
                my $props = $self->kdl_properties( $kid, qw(key action) );
                push @shortcuts, [ $props->{key}, $props->{action} ];
                return;
        }

        method shortcuts () { return @shortcuts }
}

1;
```

and in a layout:

```kdl
use My::Panel as Panel

Panel "settings" {
        title "Settings"
        title_color "#ffcc00"
        border_width 1
        shortcut key="F2" action="save"
        shortcut key="F10" action="quit"
}
```

# DESCRIPTION

[Term::Fabulous::Layout](../Layout.md) builds a widget tree from a KDL document.
For every widget node it constructs the widget with only its id, and
then hands the node to the finished widget:

```perl
my $widget = $class->new( id => $id );
$widget->apply_layout_node($node);
```

This role provides ["apply\_layout\_node"](#apply_layout_node). It reads every property node
of the widget's node as the class declares it in ["layout\_properties"](#layout_properties),
and then applies them all through ["apply\_layout\_settings"](#apply_layout_settings). Since the
widget is fully constructed by then, a layout sets its properties
exactly like a program calling the accessors after `new`: every check
and default of the constructor has run, and nothing depends on the
order in which roles and subclasses are built. A class can only be
used in a layout when it composes this role; [Term::Fabulous::Layout](../Layout.md)
checks that when the layout declares the class with `use`.

All widget classes of Term::Fabulous compose the role (through
[Term::Fabulous::Widget::Box](../Widget/Box.md), or directly as
[Term::Fabulous::Widget::Text](../Widget/Text.md) does). To make your own widget usable
in layouts, the easiest way is to subclass Box or one of its
subclasses, as in the SYNOPSIS: you inherit the parsing of `layout`,
`sizing`, `padding`, `border` and the color properties, and only add
your own.

## Property nodes and child nodes

Inside a widget's block, a node whose name starts with an uppercase
letter (`Text`, `Box`, ...) is a child widget; [Term::Fabulous::Layout](../Layout.md)
builds it and adds it with `add_child` after the widget's properties
were applied. Every other node (`text`, `_note`, `1st`, ...) is a
property of the widget. Both sides use the same rule, the function
`Term::Fabulous::Role::CanParseLayout::is_widget_node_name($name)`.

# REQUIRED METHODS

## layout\_properties

```perl
method layout_properties :common () {
        return (
                $class->SUPER::layout_properties,
                title     => 'scalar',
                collapsed => 'boolean',
                accent    => 'color',
                shortcut  => \&_parse_shortcut,
        );
}
```

A class method (`:common`) returning the properties a layout may set,
as pairs of a name and how its node is read:

- `'scalar'`

    The node's value, read with ["kdl\_value"](#kdl_value): its single argument
    (`title "x"`) or a hash reference of its `key=value` pairs
    (`border_width left=1 right=2`).

- `'boolean'`

    The node's single argument, read with ["kdl\_boolean"](#kdl_boolean): a layout must
    write `#true` or `#false` (or `1` and `0`), so a quoted `"false"`
    dies instead of counting as true.

- `'color'`

    The node's value, read with ["kdl\_value"](#kdl_value) and turned into
    `[r, g, b, a]` with ["color" in Term::Fabulous::Check](../Check.md#color), so a layout can
    write any color string (`"#ffcc00"`, `"rgb(255, 204, 0)"`,
    `"hsl(48, 100%, 50%)"`). Color names are not color strings; see
    [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md) for their values.

- a code reference

    A _structured_ property: the code is called as a method with the
    property node, `$self->$code($kid)`, and parses and applies the
    node itself, typically with the helpers below. Use it for nodes that do
    not fit the other kinds, such as an argument together with `key=value`
    pairs.

Each name of the first three kinds is also the name of the accessor
that sets it: the value is applied as `$self->name($value)`, so
the accessor checks it, as for a program. This table is the only way a
layout can set a value: a property that is not in it dies with the list
of known names, so a layout file can neither call arbitrary methods nor
silently ignore a misspelled property. A subclass returns its parent's
table (`$class->SUPER::layout_properties`) plus its own pairs; a
later pair for a name replaces the parent's. Any other kind dies when a
layout is applied.

# METHODS

## apply\_layout\_node

```perl
$widget->apply_layout_node($node);
```

Applies the properties of a [Text::KDL::XS::Node](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS%3A%3ANode) to the widget and
returns the widget. Called by [Term::Fabulous::Layout](../Layout.md) right after
`new`. It reads every property node in the order of the layout (child
widget nodes are skipped) into a _setting_, `[ $name, $value ]`: the
value read as ["layout\_properties"](#layout_properties) declares it, or for a structured
property the node itself. Then it calls ["apply\_layout\_settings"](#apply_layout_settings) with
all of them. Dies when a property is unknown (the message lists the
known names), when a node's shape is wrong, or when an accessor rejects
a value; [Term::Fabulous::Layout](../Layout.md) adds the widget's name and id to the
message.

## apply\_layout\_settings

```perl
method apply_layout_settings :override (@settings) {
        my %range = map {@$_} grep { $_->[0] =~ /\A(?:min|max)\z/ } @settings;
        $self->set_range(%range) if %range;
        return $self->SUPER::apply_layout_settings( grep { $_->[0] !~ /\A(?:min|max)\z/ } @settings );
}
```

Applies the settings in the order given: an accessor call for a simple
property, the handler for a structured one. Override it to apply related
values together, so that a layout may give them in any order:
[Term::Fabulous::Widget::Slider](../Widget/Slider.md) sets `min`, `max` and `step`
through one range setter, and [Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md) sets
its options before the value that picks one of them. Pass the other
settings on to `SUPER::apply_layout_settings`.

# HELPERS

These are for the handlers of structured properties. `$kid` is always
a property node (a child node of the widget's node).

## kdl\_boolean

```perl
my $flag = $self->kdl_boolean($kid);    # 1 or 0
```

The single argument of a boolean property node: `#true` and `1` give
`1`, `#false` and `0` give `0`. Anything else dies, including
`#null`, other numbers and strings such as `"false"`:

```text
Term::Fabulous::Widget::Checkbox: layout property 'checked' must be #true or #false, got 'false'
```

## kdl\_value

```perl
my $value = $self->kdl_value($kid);
```

The value of a property node as Perl data: its single argument
(`border_width 1` gives `1`, `title "x"` gives `'x'`, `#true`
gives a true value), or, for a node with only `key=value` pairs, a
hash reference of them (`border_width left=1 right=2` gives
`{ left => 1, right => 2 }`). Dies when the node has several
arguments, both arguments and pairs, nothing at all, or child nodes.

## kdl\_argument

```perl
my $argument = $self->kdl_argument($kid);
die "title needs a string" unless $argument->is_string;
my $text = $argument->value;
```

The single argument of a property node as a [Text::KDL::XS::Value](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS%3A%3AValue)
object, for when you need to check its type. Dies unless the node has
exactly one argument and no pairs or children.

## kdl\_properties

```perl
my $props = $self->kdl_properties( $kid, qw(key action) );
```

The `key=value` pairs of a property node as a hash reference of Perl
values. The listed names are the keys allowed; at least one pair must
be present, but not every allowed key. Dies when the node has
arguments or child nodes, has no pairs, or has a key that is not
allowed (the message lists the allowed keys).

# SEE ALSO

[Term::Fabulous::Layout](../Layout.md), ["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](../Manual/KDL.md#kdl-layout-files),
["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Box](../Widget/Box.md#subclass-interface),
["WRITING YOUR OWN WIDGETS" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#writing-your-own-widgets), [Text::KDL::XS](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS),
the example program `examples/custom-widget.pl`.
