# NAME

Term::Fabulous::ThemeEditor::UI - The UI of the theme editor, with a
preview in another theme

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous](../../../../README.md) whose
[theme\_for](../Render.md#theme_for) gives the widgets of the
preview (the preview pane, and the dialogs and toasts it opens) the
theme being edited, and every other widget the UI's own theme.

# METHODS

## add\_preview\_root

```perl
$ui->add_preview_root($widget);
```

Makes the widget and everything below it draw with the preview theme.
The UI keeps a weak reference only.

## preview\_theme

```perl
$ui->preview_theme($theme);
```

Accessor for the theme of the preview. Setting another theme makes the
widgets read their looks again.

## is\_in\_preview

1 when the widget is in a preview root's subtree, or is the backdrop of
a dialog that is, else 0.

## theme\_for

The preview theme for the widgets in the preview, the UI's theme for
the others.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md), ["theme\_for" in Term::Fabulous::Render](../Render.md#theme_for).
