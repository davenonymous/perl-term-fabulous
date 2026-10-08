# NAME

Term::Fabulous::Widget::Checkbox - A box the user can check and uncheck

# SYNOPSIS

```perl
use Clay::UI::Enum::Result;
use Term::Fabulous::Widget::Checkbox;

my $terms = Term::Fabulous::Widget::Checkbox->new(
        id    => 'terms',
        label => 'I accept the terms',
);
$terms->on( Change => sub ($event) {
        say $event->value ? "accepted" : "declined";
        return Clay::UI::Enum::Result->CONTINUE;
} );

say $terms->checked ? 'accepted' : 'not accepted';
$terms->checked(1);    # programmatic: fires no Change
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-checkbox.svg" alt="Five check boxes: focused, unchecked, checked, indeterminate and disabled"></p>
</div>

# DESCRIPTION

The picture shows a checkbox in each of its states: focused (on the
`focus_background_color`), unchecked, checked, indeterminate and
disabled. The program is `examples/widgets/checkbox.pl`.

A checkbox shows a mark followed by a label:

```text
[x] I accept the terms
[ ] Send me the newsletter
[-] Some of the items
```

The user toggles it with `Space`, `Enter` or a mouse click. Its value
is 1 (checked) or 0 (unchecked).

A checkbox can also be _indeterminate_: it then shows the indeterminate
mark (`[-]`) whatever `checked` says, which is useful for a box that
stands for a group of other boxes, some checked and some not. Toggling
an indeterminate box checks it.

Disabling, colors, focus and sizing are described in
[Term::Fabulous::Widget::Input](Input.md). The checkbox is one row high and as
wide as its widest mark plus a space and the label, unless the
`layout` sizes it.

# CONSTRUCTOR

## new

```perl
my $checkbox = Term::Fabulous::Widget::Checkbox->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Input](Input.md#constructor)
(`id`, `layout`, `background_color`, the border parameters,
`disabled`, `can_focus`, `text_color`, `disabled_color`,
`accent_color`, `focus_background_color`, the other Box parameters)
and the ones below. Unknown parameters die.

- `label`

    A character string. Default: `''` (no label, only the mark). The text
    after the mark, painted in `text_color`. Dies if not a string.

- `checked`

    A boolean. Default: 0. Whether the box starts checked. Stored as 1 or 0;
    a reference dies.

- `indeterminate`

    A boolean. Default: 0. Whether the box starts indeterminate (see
    ["DESCRIPTION"](#description)). Stored as 1 or 0; a reference dies.

- `checked_mark`

    A character string. Default: `'[x]'`. The mark of a checked box,
    painted in `accent_color`. Dies if not a string.

- `unchecked_mark`

    A character string. Default: `'[ ]'`. The mark of an unchecked box,
    painted in `text_color`. Dies if not a string.

- `indeterminate_mark`

    A character string. Default: `'[-]'`. The mark of an indeterminate box,
    painted in `accent_color`. Dies if not a string.

The label is painted after the width of the widest mark, so it stays
in place when the box is toggled, even with marks of different widths.

# METHODS

The methods of ["METHODS" in Term::Fabulous::Widget::Input](Input.md#methods) (`disabled`,
`is_enabled`, the color accessors, `mark_changed`), plus:

## checked

```perl
my $is_checked = $checkbox->checked;
$checkbox->checked(1);
```

Accessor. Returns 1 or 0. Writing sets the state, clears
`indeterminate`, marks the input changed, and returns the new state.
Writing fires no `Change` event. A reference dies and leaves the state
unchanged.

## value

```perl
my $is_checked = $checkbox->value;
```

The same as reading `checked`: 1 or 0. Read-only; use `checked` to
change the state. This is the value `Change` events carry.

A `required` checkbox (see ["required" in Term::Fabulous::Widget::Input](Input.md#required))
counts as empty while it is unchecked, so it is invalid until the user
checks it: the way to insist on accepted terms.

## indeterminate

```perl
my $is_indeterminate = $checkbox->indeterminate;
$checkbox->indeterminate(1);
```

Accessor. Returns 1 or 0. Writing marks the input changed, returns the
new state and fires no event; it does not change `checked`, so
`$checkbox->indeterminate(0)` shows the `checked` state again. A
reference dies and leaves the state unchanged.

## toggle

```perl
$checkbox->toggle;
```

Toggles the box as the user does: an unchecked or indeterminate box
becomes checked, a checked box becomes unchecked, `indeterminate` is
cleared, and a `Change` event is fired. Works even while the box is
disabled. Returns the checkbox.

## label

```perl
my $label = $checkbox->label;
$checkbox->label('Remember me');
```

Accessor for the label. Writing marks the input changed and returns the new label; the
new width takes effect at the next frame. A value that is not a string
dies and leaves the label unchanged.

## checked\_mark

```perl
my $mark = $checkbox->checked_mark;
$checkbox->checked_mark('[*]');
```

Accessor for the `checked_mark` parameter. Writing marks the input changed and returns
the new mark. A value that is not a string dies and leaves the mark
unchanged.

## unchecked\_mark

```perl
$checkbox->unchecked_mark('[_]');
```

Accessor for the `unchecked_mark` parameter; works like
["checked\_mark"](#checked_mark).

## indeterminate\_mark

```perl
$checkbox->indeterminate_mark('[~]');
```

Accessor for the `indeterminate_mark` parameter; works like
["checked\_mark"](#checked_mark).

# KEYS

While the checkbox has the focus and is enabled:

- `Space`, `Enter`

    Toggle the box (see ["toggle"](#toggle)).

All other keys bubble to the ancestors.

# MOUSE

A click (left button pressed and released over the checkbox, mark or
label) toggles it and focuses it.

# EVENTS

- `Change`

    [Term::Fabulous::Event::Change](../Event/Change.md) when the user toggles the box (or
    ["toggle"](#toggle) is called); `$event->value` is 1 (now checked) or 0
    (now unchecked). It bubbles to the ancestors.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Input](Input.md#kdl-properties), plus
`label` (a string), `checked` and `indeterminate` (`#true` /
`#false`), and `checked_mark`, `unchecked_mark` and
`indeterminate_mark` (strings):

```kdl
use Term::Fabulous::Widget::Checkbox as Checkbox

Checkbox "newsletter" {
        label "Send me the newsletter"
        checked #true
}
```

# EXAMPLES

## A "select all" box for a group of boxes

```perl
my @items = map { Term::Fabulous::Widget::Checkbox->new( label => $_ ) } qw(Apples Pears Plums);
my $all   = Term::Fabulous::Widget::Checkbox->new( label => 'All fruit' );

sub update_all () {
        my $checked = grep { $_->checked } @items;
        if    ( $checked == 0 )      { $all->checked(0) }
        elsif ( $checked == @items ) { $all->checked(1) }
        else                         { $all->indeterminate(1) }
        return;
}

$_->on( Change => sub ($event) { update_all(); return } ) foreach @items;
$all->on( Change => sub ($event) {
        $_->checked( $event->value ) foreach @items;    # fires no Change
        return;
} );
```

## Ballot-box marks

All three marks are one column wide, so the label never moves (see
["CONSTRUCTOR"](#constructor)).

```perl
my $box = Term::Fabulous::Widget::Checkbox->new(
        label              => 'Done',
        checked_mark       => "\x{2611}",    # BALLOT BOX WITH CHECK
        unchecked_mark     => "\x{2610}",    # BALLOT BOX
        indeterminate_mark => "\x{25A3}",    # WHITE SQUARE CONTAINING BLACK SMALL SQUARE
);
```

# SEE ALSO

[Term::Fabulous::Widget::Input](Input.md), [Term::Fabulous::Event::Change](../Event/Change.md),
[the checkbox section of the forms guide](../Manual/Forms.md#checkboxes),
["Disable inputs until a checkbox is checked" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked).
