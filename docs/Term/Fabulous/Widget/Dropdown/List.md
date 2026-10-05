# NAME

Term::Fabulous::Widget::Dropdown::List - The option list of an open dropdown

# DESCRIPTION

This class is internal to [Term::Fabulous::Widget::Dropdown](../Dropdown.md).
Applications never create a list themselves: the dropdown creates one
each time it opens, adds it as a floating child of itself (so it is
drawn over the other widgets, attached below or above the dropdown), and
removes it when it closes.

The list is a [Term::Fabulous::Widget::Display](../Display.md) that paints the
dropdown's options with a one-column margin on both sides, highlights
one of them, scrolls through them when there are more options than
rows, and then shows a scrollbar in its rightmost column. It turns mouse
presses into highlights and mouse releases into choices, and scrolls on
the mouse wheel. It never takes the keyboard focus; the dropdown keeps
the focus and handles the keys.

The methods below are documented for authors of dropdown subclasses and
for tests.

# CONSTRUCTOR

## new

```perl
my $list = Term::Fabulous::Widget::Dropdown::List->new(
        dropdown     => $dropdown,
        visible_rows => 8,
        ...
);
```

Called by the dropdown with these parameters, plus `background_color`,
`border_color`, `border_width`, `border_style`, `layout` and
`floating` (see ["floating" in Term::Fabulous::Widget](../../Widget.md#floating)). Unknown
parameters die.

- `dropdown`

    Required. The [Term::Fabulous::Widget::Dropdown](../Dropdown.md) the list belongs to.
    Held as a weak reference.

- `visible_rows`

    Required. A positive integer: how many options the list shows at once.

# METHODS

## visible\_rows

```perl
my $rows = $list->visible_rows;
```

How many options the list shows at once.

## top\_option

```perl
my $index = $list->top_option;
```

The index of the first option shown (from 0).

## show\_highlight

```perl
$list->show_highlight;
```

Scrolls the dropdown's highlighted option into view and marks the list
changed. Returns the list.

## scroll

```perl
$list->scroll(-1);
```

Scrolls by a number of options (negative: towards the first), staying
within the options. Returns the list.

## option\_at\_row

```perl
my $index = $list->option_at_row($row);
```

The index of the option shown at a row of the list's content (from 0),
or `undef` for a row without an option.

## paint, paint\_key, natural\_size

The [Term::Fabulous::Widget::Display](../Display.md) interface. `paint` draws the
visible options and, when the list scrolls, the scrollbar. The paint key
adds the first option shown, what the shown rows display and the
scrollbar's colors, so the list paints again whenever that changed, also
when the change came from the dropdown (its colors, its highlight, its
options). The natural size (the widest label with its margins and the
scrollbar column, by `visible_rows`) is used only for an axis the
dropdown leaves unsized; it always sizes both.

# MOUSE

A left press on an option highlights it; releasing the left button over
an option chooses it (see ["choose" in Term::Fabulous::Widget::Dropdown](../Dropdown.md#choose)).
Presses on the scrollbar column are ignored. Each notch of the mouse
wheel scrolls by one option.

# SEE ALSO

[Term::Fabulous::Widget::Dropdown](../Dropdown.md).
