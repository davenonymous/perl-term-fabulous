# NAME

Term::Fabulous::ThemeEditor::Prompt - Questions and small forms of the
theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) with a title, a message in
rich markup (see [Term::Fabulous::Text::Markup](../Text/Markup.md)), optional fields
(a text field, a segmented choice or a dropdown list) and a row of
buttons. A text field starts with its text selected, so typing replaces
it. `Escape` closes the dialog like a button with the id `cancel`;
`Enter` in a text field presses the first primary button. A primary
button runs the checks of the fields first; a field whose check
returns a message keeps the dialog open and shows it.

# CONSTRUCTOR

## new

```perl
Term::Fabulous::ThemeEditor::Prompt->new(
        title   => 'New theme',
        message => 'A theme starts from one of the built-in themes.',
        fields  => [
                { name => 'name', label => 'Name', value => 'untitled', check => sub ($value, $values) { length $value ? undef : 'A theme needs a name.' } },
                { name => 'base', label => 'Based on', kind => 'choice', options => [qw(dark light)] },
        ],
        buttons => [ [ create => 'Create', 1 ], [ cancel => 'Cancel' ] ],
        on_done => sub ( $button, $values ) { ... },
)->open($ui);
```

# METHODS

## finish

Ends the dialog as if a button had been pressed.

## values, field

The values of the fields by name, and one field's widget.

## default\_button

The id of the button `Enter` in a text field presses.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
