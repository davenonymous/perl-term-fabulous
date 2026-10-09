# NAME

Term::Fabulous::ThemeEditor::Preview - The gallery of widgets in the
theme editor's preview

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A box with a scroll box of sections, one or more per widget
family, each under a divider that names the families it shows: the
palette (a swatch of every token), text and links, boxes, buttons,
fields (text fields with a placeholder, a selection, an invalid value
and a disabled one, a text area with a scrollbar), choices (check
boxes, radio buttons, a segmented control, a slider, a star rating, a
dropdown), tabs, an accordion, a table (groups, a filter row, pages),
progress bars and a spinner, toasts (and a button that shows one),
a button that opens a dialog, dividers, an image, and the variants the
theme defines, each with a sample of its family.

The editor draws the gallery in the theme being edited (see
[Term::Fabulous::ThemeEditor::UI](UI.md)); the widgets read their looks
themselves. A toast or a dialog opened from the gallery draws in that
theme too.

`PageUp`, `PageDown`, `Ctrl+Home` and `Ctrl+End` scroll the
gallery when the focused widget in it does not use them, and a widget
that gets the focus is scrolled into view.

# METHODS

## show\_theme

```perl
$preview->show_theme( $theme, [ 'button', 'primary' ], ... );
```

Shows a theme: the palette swatches take its colors, and the variants
section shows a sample of each `[ family, name ]` given.

## section\_of\_family, show\_section

```perl
$preview->show_section( $preview->section_of_family('button') );
```

The section that shows a family, and scrolling so that a section
starts at the top (`palette` and `variants` are sections too).

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
