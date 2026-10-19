# NAME

Term::Fabulous::Placement - Where a popup goes on the screen

# SYNOPSIS

```perl
use Term::Fabulous::Placement qw(place_popup TOPMOST_Z_INDEX);

# A list of 6 rows under a field at row 15 of a 40 x 20 screen:
my $place = place_popup(
        anchor => { x => 30, y => 15, width => 10, height => 1 },
        size   => [ 20, 6 ],
        screen => [ 40, 20 ],
        prefer => 'below',
);
# { x => 20, y => 9, flipped => 1, rows => 15 }: above the field
# (too little room below), moved left to stay on the screen
```

# DESCRIPTION

The popups of Term::Fabulous (the list of a
[Term::Fabulous::Widget::Dropdown](Widget/Dropdown.md), a [Term::Fabulous::Widget::Menu](Widget/Menu.md)
opened under a widget or at a point, the column chooser of a
[Term::Fabulous::Widget::Table](Widget/Table.md)) float over everything, attached to
the root at the position this module works out from the box of their
anchor, their own size and the size of the screen. One rule places
them all and keeps them on the screen. A custom popup can use it the
same way: compose [Term::Fabulous::Role::Popup](Role/Popup.md), return the position
from its `popup_position` and float at ["TOPMOST\_Z\_INDEX"](#topmost_z_index).

# FUNCTIONS

Nothing is exported by default.

## place\_popup

```perl
my $place = place_popup( anchor => $box, size => [ $width, $height ], screen => [ $columns, $rows ], prefer => 'below', align => 'left' );
```

Returns a hash reference: the `x` and `y` of the popup's top left
corner, whether it `flipped` to the other side of its anchor (1 or 0),
and the `rows` the screen has on the side it opened to. The options:

- `anchor`

    Required. The box the popup belongs to, a hash reference with `x`,
    `y`, `width` and `height` (as ["bounding\_box" in Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI#bounding_box) returns
    them). For a popup at a point, a box of width and height 0 there.

- `size`

    Required. `[ width, height ]` of the popup, border included.

- `screen`

    Required. `[ columns, rows ]` of the screen.

- `prefer`

    Where the popup goes: `below` the anchor (the default), `above` it,
    or `at` it (its top at the anchor's top, over the anchor). A popup
    below or above its anchor goes to the other side when it does not fit
    on its own side and the other side has more room; `rows` is the room
    of the side it opened to, so a popup that can shrink (the dropdown's
    list) takes no more rows than that. A popup at its anchor never flips;
    its `rows` is the height of the screen.

- `align`

    `left` (the default): the popup's left edge at the anchor's left
    edge. `right`: its right edge at the anchor's right edge.

Finally the popup is moved left and up as far as it takes to end on
the screen, and right and down to start on it: a popup wider or taller
than the screen starts at its left or top edge.

Dies with a message that starts with `Term::Fabulous::Placement:
place_popup` for an unknown option, an anchor that is not such a box,
a size or screen that is not two numbers of at least 0, or a `prefer`
or `align` not listed above.

## TOPMOST\_Z\_INDEX

The highest `z_index` Clay has, 32767. A popup belongs to the focused
widget, so it floats over every other floating widget, a dialog
included.

# SEE ALSO

[Term::Fabulous::Role::Popup](Role/Popup.md), [Term::Fabulous::Widget::Menu](Widget/Menu.md), [Term::Fabulous::Widget::Dropdown](Widget/Dropdown.md),
["open\_column\_chooser" in Term::Fabulous::Widget::Table](Widget/Table.md#open_column_chooser),
[Term::Fabulous::Manual::Layout](Manual/Layout.md).
