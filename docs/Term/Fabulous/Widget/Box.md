# NAME

Term::Fabulous::Widget::Box - The general-purpose container widget

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Enum::BorderStyle;
use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

my $card = Term::Fabulous::Widget::Box->new(
        id               => 'card',
        layout           => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_fit() },
                padding          => { left => 1, right => 1 },
                child_gap        => 1,
        },
        background_color => [ 30, 35, 50, 255 ],
        border_width     => 1,
        border_color     => [ 97, 175, 239, 255 ],
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
);
$card->add_child(
        Term::Fabulous::Widget::Text->new( text => 'Title',     text_color => [ 255, 255, 255, 255 ] ),
        Term::Fabulous::Widget::Text->new( text => 'Body text', text_color => [ 200, 205, 215, 255 ] ),
);
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-box.svg" alt="A card with a title and body text, and three boxes labeled fit, grow and fixed(14)"></p>
</div>

# DESCRIPTION

A Box is a rectangle that holds other widgets and arranges them in a
row or a column. It can have a background color and a border, and it
can receive events. Boxes are the building blocks of every screen:
nest them to divide the terminal into areas, then put
[Term::Fabulous::Widget::Text](Text.md) and the other widgets inside.

Box is the concrete form of [Term::Fabulous::Widget](../Widget.md); most other
widgets ([Term::Fabulous::Widget::Button](Button.md),
[Term::Fabulous::Widget::ScrollBox](ScrollBox.md), [Term::Fabulous::Widget::Canvas](Canvas.md),
the input widgets) are Boxes with extra behavior. A Box can also be
built from a KDL layout file (see ["KDL PROPERTIES"](#kdl-properties)).

The SYNOPSIS above draws this (colors left out):

```text
+----------------------------+
| Title                      |
|                            |
| Body text                  |
+----------------------------+
```

with rounded corners. The border takes one cell on every side and the
padding one more cell left and right; see
["Border space" in Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md#border-space).

# CONSTRUCTOR

## new

```perl
my $box = Term::Fabulous::Widget::Box->new(%parameters);
```

All parameters are optional; unknown parameters die. A Box accepts the
parameters common to all container widgets. Each is listed here with
its meaning in one sentence;
[the constructor of Term::Fabulous::Widget](../Widget.md#new)
describes the accepted values in full.

- `id`

    A string that names the widget and must be unique in the widget tree.
    Default: `undef` (no id).

- `layout`

    A hash reference with the keys `sizing`, `padding`, `child_gap`,
    `layout_direction`, `child_alignment`, `line_gap` and
    `line_sizing` that decides the size of
    the box and how its children are arranged. Default: `{}`, which fits
    the box to its content and places the children from left to right.

- `floating`

    A hash reference that takes the box out of its parent's layout and
    draws it on top of other widgets, attached to its parent, the root or
    another widget. Default: `undef` (the box is laid out normally).

- `background_color`

    The color of the box's area, in any format [Term::Fabulous::Color](../Color.md)
    accepts (`[r, g, b, a]`, `{ r, g, b, a }`, a string such as
    `'#14192b'`, a Color object). Default: `undef`, so the box is
    transparent.

- `glyphs_show_through`

    A boolean. Default: false. With a translucent `background_color`,
    whether text and borders below the box stay visible through it.

- `border_width`

    The border's width, a number for all sides or a hash reference with
    `left`, `right`, `top` and `bottom`. Default: `undef`, so there is
    no border.

- `border_color`

    The color of the border glyphs, in the same formats as
    `background_color`. Default: the theme's `box.border.color`, the
    `border` token in the built-in themes (see
    ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes)).

- `border_style`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item that sets the style of
    every side that has no side parameter of its own. Default: the
    theme's `box.border.style`, `Round` in the built-in themes (see
    ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes)).

- `border_style_top`
- `border_style_right`
- `border_style_bottom`
- `border_style_left`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item that sets the style of one
    side. Default: `undef`. It wins over `border_style` for that side.

- `border_corners`

    A hash reference of glyphs drawn at the corners instead of the style's
    corner glyphs. Default: `undef`.

- `outer_border_sides`

    An array reference of sides whose border glyphs are drawn on the
    background outside the box. Default: `[]`.

- `width_group`
- `height_group`

    A sizing group number that gives the box the same width (or height) as
    the other widgets with that number. Default: 0, which means no group.

- `classes`

    An array reference of free-form names, returned by
    ["get\_classes" in Term::Fabulous::Widget](../Widget.md#get_classes). Default: `[]`.

# METHODS

A Box has all methods of [Term::Fabulous::Widget](../Widget.md): children
(`add_child`, `remove_child`, `children`, ...), events (`on`,
`fire_event`), the search ["find\_by\_id" in Term::Fabulous::Widget](../Widget.md#find_by_id), the
accessors `layout`, `floating`, `background_color`,
`glyphs_show_through`, `border_color`, `border_width`, `border_style_top`,
`border_style_right`, `border_style_bottom`, `border_style_left`,
`width_group` and `height_group`, and the state methods. It adds
nothing for applications; the methods in ["SUBCLASS INTERFACE"](#subclass-interface) are for
widget authors.

# EVENTS

A Box fires no events of its own. Events fired on its children bubble
up to it (see ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events)), and
[Term::Fabulous](../../../../README.md) fires `KeyPress` on it when it is the root and
nothing has the focus, and `Mouse` when it is the topmost widget
painted under the pointer. A Box receives `Mouse` events only on the
cells it paints: its whole area when it has a background color, and
only its border cells when it has a border but no background. A Box
with neither is transparent to the mouse.

# KDL PROPERTIES

A Box built by [Term::Fabulous::Layout](../Layout.md) reads these property nodes
from its block. Child nodes whose names start with an uppercase letter
are child widgets; everything else is a property. Unknown properties,
unknown keys and invalid values die, naming the property.

```kdl
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text

Box "card" {
        layout direction=down gap=1
        sizing width="fixed(30)" height="fit(3, 10)"
        padding left=1 right=1
        child_alignment x=center
        border style=Round color="#61afef"
        border_width 1
        background_color "rgb(30, 35, 50)"

        Text { text "Title"; text_color "#ffffff"; }
        Text { text "Body text"; text_color "hsl(220, 15%, 80%)"; }
}
```

- `layout direction=... gap=N line_gap=N line_sizing=...`

    `direction` is `down` (aliases `ttb`, `top_to_bottom`), `right`
    (aliases `ltr`, `left_to_right`), `wrap` (aliases `ltr_wrap`,
    `left_to_right_wrap`; see ["Flow layout" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#flow-layout)) or
    `stack` (aliases `back_to_front`, `btf`; see
    ["Stack layout" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#stack-layout)).
    `gap` (alias `child_gap`; giving both dies) is the number of cells
    between children, a non-negative integer. `line_gap` is the number of
    rows between the lines of a `wrap` box, a non-negative integer.
    `line_sizing` is `grow` (the default) or `fit` and decides what a
    `wrap` box taller than its lines does with the leftover rows. Each key
    is optional, but at least one must be given: a bare `layout` node
    dies.

- `sizing width=... height=...`

    Each value is `grow`, `fit`, `"grow(MIN)"`, `"grow(MIN, MAX)"`,
    `"fit(MIN)"`, `"fit(MIN, MAX)"`, `"fixed(N)"` with N a non-negative
    integer number of cells, or `"percent(N)"` with N a number from 0 to
    100 (`"percent(50)"` is half of the parent; note that Perl code uses a
    fraction instead: `sizing_percent(0.5)`). MIN and MAX are
    non-negative integer numbers of cells, the limits of
    `sizing_grow($min, $max)` and `sizing_fit($min, $max)`; without MAX
    there is no maximum, and a MIN greater than MAX dies. Values with
    parentheses must be quoted. Either key may be left out. A second
    `sizing` node changes only the axes it names.

- `child_alignment x=... y=...`

    Where the children are placed when they do not fill the box: `x` is
    `left` (the default), `center` or `right`, `y` is `top` (the
    default), `center` or `bottom`. Either key may be left out, but at
    least one must be given. A second `child_alignment` node changes only
    the key it names. An unknown name dies with the known ones.

- `floating attach_to=... parent_id=... element=... parent=... offset_x=N offset_y=N z_index=N pointer_capture=... clip_to=...`

    Sets the `floating` hash (see ["floating" in Term::Fabulous::Widget](../Widget.md#floating)).
    Each key is optional, but at least one must be given:

    - `attach_to`

        `parent` (the default), `root` or `element`. `element` requires
        `parent_id`.

    - `parent_id`

        The id of the widget to attach to with `attach_to=element`, a string.

    - `element`
    - `parent`

        The point of this box (`element`) that is placed on the point of the
        widget it is attached to (`parent`): `left_top` (the default),
        `left_center`, `left_bottom`, `center_top`, `center_center`,
        `center_bottom`, `right_top`, `right_center` or `right_bottom`.

    - `offset_x`
    - `offset_y`

        Integers added to the position, in cells; negative values move left
        and up.

    - `z_index`

        An integer from -32768 to 32767; floating widgets with a higher value
        are drawn on top.

    - `pointer_capture`

        `capture` (the default) or `passthrough`.

    - `clip_to`

        `none` (the default) or `attached_parent`.

    A second `floating` node changes only the keys it names. An unknown
    name dies with the known ones.

    ```kdl
    Box "menu" {
            floating attach_to=element parent_id="menu-button" element=left_top parent=left_bottom
            floating z_index=10
            border style=Round
            border_width 1
    }
    ```

- `padding left=N right=N top=N bottom=N`

    Any subset of the four sides; non-negative integers. A second
    `padding` node changes only the sides it names, like `sizing`.

- `border style=... style-top=... style-right=... style-bottom=... style-left=... color=...`

    `style` sets all four sides, `style-top` and the other side keys
    override it for one side. Values are the names of
    [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) items (`Round`, `Solid`,
    `Double`, ...). `color` takes any color string that
    [Term::Fabulous::Color](../Color.md) understands (`"#61afef"`,
    `"rgb(97, 175, 239)"`, `"hsl(207, 82%, 66%)"`, ...). This property
    does not make a border appear: also give `border_width`.

- `border_width N` or `border_width left=N right=N top=N bottom=N`

    The border width, for all sides or per side.

- `background_color "..."`
- `border_color "..."`

    Any [Term::Fabulous::Color](../Color.md) string.

- `glyphs_show_through #true`

    `#true` or `#false` (the default), see
    ["glyphs\_show\_through" in Term::Fabulous::Widget](../Widget.md#glyphs_show_through).

- `width_group N`
- `height_group N`

    Sizing group numbers, see ["width\_group" in Term::Fabulous::Widget](../Widget.md#width_group).

`border_corners`, `outer_border_sides` and `classes` cannot be set
from KDL; set them in Perl after the build (see
["LIMITATIONS" in Term::Fabulous::Layout](../Layout.md#limitations)).

# SUBCLASS INTERFACE

This method is for authors of widget classes that should be buildable
from KDL layouts. See [Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md), which
also provides `apply_layout_node` and `apply_layout_settings`.

## layout\_properties

```perl
method layout_properties :common () {
        return ( $class->SUPER::layout_properties, title => 'scalar', collapsed => 'boolean', shortcut => \&_parse_shortcut );
}
```

The table of the properties a layout may set and how each is read (see
["layout\_properties" in Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md#layout_properties)). For a Box:
`background_color` and `border_color` are colors,
`glyphs_show_through` is a boolean, `border_width`, `width_group`
and `height_group` are scalars, and `layout`, `border`, `sizing`,
`padding`, `child_alignment` and `floating` are structured
properties the Box parses itself (see ["KDL PROPERTIES"](#kdl-properties)). Subclasses
extend the table as shown.

# SEE ALSO

[Term::Fabulous::Widget](../Widget.md) for the common parameters and methods,
["LAYOUT" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#layout) (every layout option with a
picture), the example program `examples/widgets/box.pl`, [Term::Fabulous::Layout](../Layout.md),
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md),
["Line up labels with equal widths (width\_group)" in Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md#line-up-labels-with-equal-widths-width_group),
["Use a different border style on each side" in Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md#use-a-different-border-style-on-each-side).
