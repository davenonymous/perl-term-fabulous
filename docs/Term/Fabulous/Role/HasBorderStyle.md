# NAME

Term::Fabulous::Role::HasBorderStyle - Border glyphs per side, and
borders that take space

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Enum::BorderStyle;

my $box = Term::Fabulous::Widget::Box->new(
        border_width => 1,
        border_color => [ 180, 200, 220, 255 ],
        border_style => Term::Fabulous::Enum::BorderStyle->Round,    # all four sides
        layout       => { padding => { left => 1, right => 1 } },    # inside the border
);

# Change one side later:
$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Double );
```

# DESCRIPTION

This role is part of every [Term::Fabulous::Widget](../Widget.md) (and therefore of
every Box, Button, ScrollBox, Canvas and input widget). It does two
things:

1. It adds the border style parameters and accessors, which choose the
characters a border is drawn with (Clay itself only knows border
widths and colors).
2. It makes borders take space in the layout, so that the content never
overlaps them.

You do not compose this role yourself; it is already part of the
widget classes. To draw a border, a widget needs a `border_width`
(from [Clay::UI::Role::Style::HasBorder](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasBorder)) and normally a border style
and a `border_color`:

```perl
border_width => 1,
border_style => Term::Fabulous::Enum::BorderStyle->Round,
border_color => [ 180, 200, 220, 255 ],
```

[The borders section of the looks guide](../Manual/Looks.md#borders)
explains borders with examples. `examples/border-options.pl` shows per-side styles, a wider
border, a `Hidden` side, `border_corners` and
`outer_border_sides`:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-border-options.svg" alt="Six bordered panels: a border on the left and top only; a solid border with a double top and a thick left side; a round border of width 2 with an empty cell inside; a round border with a hidden bottom side; a title box and a body box sharing one line; a round border drawn on the parent's background"></p>
</div>

## How a border is drawn

- A side is drawn when its border width is greater than 0 and its
style is not `Hidden`. It is always one cell thick, whatever the
width; see ["Border space"](#border-space) for what a larger width does.
- A side with the `Hidden` style is switched off: it draws
nothing and takes no space, whatever its border width. Use it to turn
one side off without changing `border_width`.
- The top and bottom sides are drawn over the whole width of the
widget and own the corners: a corner glyph appears where the top or
bottom row meets a drawn left or right side, taken from the style of
the top or bottom side. The left and right sides fill the rows between.
- A side that has a width but no style is drawn with the `Blank`
style, that is with spaces.
- `border_corners` replaces the glyph of any corner, for example
to join the box to lines around it (`\x{251C}` instead of
`\x{250C}` where a line comes in from above). The corner keeps the
colors its style gives it.
- `outer_border_sides` draws some sides on the background
outside the widget instead of its own (see below).
- The glyphs have the `border_color` (the terminal's default
foreground color when none is set). Their background is usually the
widget's background; some styles, such as `Block`, `Inner`, `Panel`
or `Wide`, use the background outside the widget or reverse video for
some glyphs so that they blend with the surroundings. See
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) for the styles.

## Border space

Clay, the layout engine, would draw borders on top of the content. This
role prevents that: when a widget has a `border_width`, the width of
every side whose style is not `Hidden` is added to that side's padding
before Clay lays the widget out. The effect is:

- The content starts inside the border, and the `padding` in the
widget's `layout` is extra space between the border and the content.
In the SYNOPSIS, a child of the box starts two cells right of the left
edge: one for the border, one for the padding.
- A width larger than 1 still draws a one-cell border, followed
by empty cells: `border_width =` 2> is a border plus one cell of
padding.
- A widget with `fit` sizing grows by the border.
- A `Hidden` side adds no padding, so the content reaches that
edge of the widget.

`border_width` is a number for all four sides, or a hash reference
`{ left => ..., right => ..., top => ..., bottom => ... }` in which
missing sides count as 0. Each width must be an integer from 0 to 65535
(checked by Clay::UI when it is set). Clay's `between_children` key
is not supported. The widget's stored `layout` is
not modified; only the configuration handed to Clay is.

# CONSTRUCTOR PARAMETERS

These parameters are accepted by the `new` of every widget class that
composes the role. Unknown values die.

- `border_style`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item, for example
    `Term::Fabulous::Enum::BorderStyle->Round`; it sets the style of
    every side that has no side parameter of its own. Default: the style
    the theme gives the widget's family, if any (see
    ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes)).
    Anything else, including the name of a style as a string, dies. To use
    a name, convert it:
    `Term::Fabulous::Enum::BorderStyle->from_name('Round')`.

- `border_style_top`
- `border_style_right`
- `border_style_bottom`
- `border_style_left`

    `undef` or a [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item for one side.
    Default: `undef`. A side parameter wins over `border_style`:

    ```perl
    border_style      => Term::Fabulous::Enum::BorderStyle->Solid,
    border_style_left => Term::Fabulous::Enum::BorderStyle->Thick,
    ```

    gives a thick left side and solid other sides, like
    `border style=Solid style-left=Thick` in a KDL layout file. The side
    accessors change one side after construction.

- `border_corners`

    `undef` (the default) or a hash reference with any of the keys
    `top_left`, `top_right`, `bottom_left` and `bottom_right`, each a
    single character one column wide. A corner named here is drawn with
    that glyph instead of the corner glyph of its style; the others keep
    theirs. Only corners that are drawn at all are affected (a corner is
    drawn where a drawn top or bottom side meets a drawn left or right
    side). The colors stay those of the style's corner. Unknown keys and
    other glyphs die. [Term::Fabulous::Widget::Table](../Widget/Table.md) uses it to join the
    lines of its cells, with the glyphs from
    ["junction" in Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md#junction).

    ```perl
    border_style   => Term::Fabulous::Enum::BorderStyle->Solid,
    border_corners => { top_left => "\x{251C}", bottom_left => "\x{251C}" },
    ```

- `outer_border_sides`

    An array reference of side names (`top`, `right`, `bottom`,
    `left`). Default: `[]`. The glyphs of these sides are drawn on the
    background just outside the widget (what is painted there, usually the
    parent's background) instead of the widget's own: the border looks like
    part of its surroundings, and a colored widget starts inside it. The
    glyphs of a style that already uses the outer background (see
    ["locations" in Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md#locations)) are not affected; those
    in reverse video use the outer background as well. A corner is drawn
    like the side next to it when that side is listed, otherwise like its
    top or bottom side. Unknown side names die.
    [Term::Fabulous::Widget::Table](../Widget/Table.md) draws its outer frame this way, so a
    highlighted row ends at the frame.

`border_corners` and `outer_border_sides` cannot be set from a KDL
layout file.

# METHODS

There is no `border_style` accessor; to change all sides after
construction, call the four side accessors.

## border\_style\_top

```perl
my $style = $box->border_style_top;
$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the top side. Takes and returns `undef` or
a [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item; anything else dies. The
change shows in the next frame.

## border\_style\_right

```perl
$box->border_style_right( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the right side, as ["border\_style\_top"](#border_style_top).

## border\_style\_bottom

```perl
$box->border_style_bottom( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the bottom side, as ["border\_style\_top"](#border_style_top).

## border\_style\_left

```perl
$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the left side, as ["border\_style\_top"](#border_style_top).

## border\_corners

```perl
my $corners = $box->border_corners;    # a copy, or undef
$box->border_corners( { top_left => "\x{253C}" } );
$box->border_corners(undef);           # the style's corners again
```

Accessor for the `border_corners` parameter. The reader returns a new
hash (or `undef`); the writer takes what the parameter takes, replaces
all corners at once and returns the new value. The change shows in the
next frame.

## outer\_border\_sides

```perl
my $sides = $box->outer_border_sides;          # a copy, e.g. [ 'left', 'top' ]
$box->outer_border_sides( [ 'left', 'right' ] );
```

Accessor for the `outer_border_sides` parameter. The reader returns a
new array reference of the sides in the order `left`, `right`,
`top`, `bottom`; the writer takes what the parameter takes and
returns the new value. The change shows in the next frame.

## is\_outer\_border\_side

```perl
my $outer = $box->is_outer_border_side('left');    # 1 or 0
```

Whether a side is listed in `outer_border_sides`. Used by
[Term::Fabulous::Render::Border](../Render/Border.md).

## border\_corner\_glyph

```perl
my $glyph = $box->border_corner_glyph('top_left');    # or undef
```

The glyph drawn at one corner instead of the style's corner glyph, or
`undef` when the style's glyph is drawn. Used by
[Term::Fabulous::Render::Border](../Render/Border.md).

## contribute\_border\_hidden

```perl
$widget->contribute_border_hidden( \%config );
```

Called by Clay::UI while it builds the configuration of a frame, after
`contribute_border`; it sets the border width Clay sees to 0 on every
`Hidden` side, so nothing is drawn there. The widget's own
`border_width` is not modified. You do not call it yourself.

## contribute\_layout\_inset

```perl
$widget->contribute_layout_inset( \%config );
```

Called by Clay::UI while it builds the configuration of a frame; it
adds the border widths of the sides that are not `Hidden` to the
padding as described in ["Border space"](#border-space). You do not call it yourself.

# SEE ALSO

[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md), ["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders),
[Term::Fabulous::Widget](../Widget.md), [Clay::UI::Role::Style::HasBorder](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasBorder), the
example program `examples/border-showcase.pl`, which shows every style.
