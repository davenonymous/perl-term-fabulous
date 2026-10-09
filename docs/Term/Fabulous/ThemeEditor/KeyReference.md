# NAME

Term::Fabulous::ThemeEditor::KeyReference - The key reference of the
theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) with every key of the editor
and what it does, in a table grouped by where the key works, and a
search field that filters the table by any text in it. `Escape` or
`Close` closes it.

# CONSTRUCTOR

## new

```perl
Term::Fabulous::ThemeEditor::KeyReference->new(
        keys   => [ [ 'Everywhere', 'Ctrl+S', 'Save the theme' ], ... ],
        height => $ui->height - 4,
        width  => $ui->width - 4,
)->open($ui);
```

The keys are given as `[ where, keys, action ]`, in the order they
are listed; `height` and `width` are the dialog's size (at least 12
rows and 60 columns; default 30 by 78).

# METHODS

## search, table

The search field and the table.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
