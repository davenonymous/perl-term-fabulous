# NAME

Term::Fabulous::ThemeEditor::ValueDialog - The dialog that edits one
setting in the theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. The dialog opens at the right edge of the screen and does not dim
the screen behind it, so the preview on the left shows the value being
chosen in its true colors. What the dialog offers depends on the
setting:

- a color slot

    A [Term::Fabulous::Widget::ColorPicker](../Widget/ColorPicker.md): the palette's tokens as
    swatches with their colors (and `none` where the slot may have no
    color, `reverse` for `button.background.pressed`), and a color of its
    own: a field for `#rrggbb`, `#rrggbbaa`, `rgb(...)`, `hsl(...)` or a
    color name, a sample, sliders for red, green and blue or for hue,
    saturation and lightness (switched with `RGB` and `HSL`), and one for
    alpha.

- a palette token

    The color picker without swatches: a token's value must be a color.

- a style slot

    A list of the border styles with a sample of each (only those with
    joints for `tabs.line.style`, and `none` where the slot may have no
    style).

- `theme.name`, `theme.extends`

    A field for the name; a list of the built-in themes.

A list shows that it has the keyboard focus with its frame in the
accent color. Every choice shows in the preview at once. `Apply` (or
`Enter` in a list or a field) writes the value to the theme as one undo
step, `Reset to default` removes the setting, and `Cancel` or
`Escape` leaves the theme as it was. A value the setting cannot take,
or a text in the color field that is no color, is not applied; the line
above the buttons says why.

# CONSTRUCTOR

## new

```perl
my $dialog = Term::Fabulous::ThemeEditor::ValueDialog->new(
        key       => 'button.border.color.focused',
        current   => 'accent',
        is_set    => 0,
        default   => 'accent',
        palette   => $theme->palette,
        list_rows => 12,    # the rows of the list of tokens or styles
);
$dialog->on( Change => sub ($event) { preview( $event->value ); return } );    # undef: the theme as it is
$dialog->on( Answer => sub ($event) { ... } );
```

The dialog is a [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) with the title
`Edit KEY`, on the right (`placement => 'right'`), with the
buttons `apply` (primary), `reset` (only for a setting the theme
sets) and `cancel`, and a notice line that keeps its place.

# METHODS

## key, value

The setting's key and the value chosen now.

## apply

What `Apply` and `Enter` do: answers `apply` with the value, unless
the value cannot be applied; then the notice line says why.

# EVENTS

- `Change` ([Term::Fabulous::Event::Change](../Event/Change.md))

    A value was chosen: the value to preview, or `undef` for one the key
    cannot take. Fired on the dialog; the `Change` events of its inputs do
    not bubble past it.

- `Answer` ([Term::Fabulous::Event::Answer](../Event/Answer.md))

    `apply` with `{ value => $value }`, `reset`, `cancel`, or
    `cancel` dismissed (Escape).

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
