# NAME

Term::Fabulous::ThemeEditor::TabStrip - The row of open themes in the
theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. One row with a tab per open theme: its name, a dot when it has
unsaved changes or an exclamation mark when its text has errors, and a
close button; a `+` button at the end makes a new theme. The active
tab is drawn in the colors of the theme's `tabs` family. When the
tabs do not fit, the strip scrolls to the active one and shows arrows
at the ends, which select the next hidden tab.

A click on a tab selects it, a click on its close button or a middle
click on it closes it, a click on `+` makes a new theme.

# CONSTRUCTOR

## new

```perl
my $strip = Term::Fabulous::ThemeEditor::TabStrip->new(
        tabs      => sub { ( { title => 'ocean.kdl', modified => 1, errors => 0, active => 1 }, ... ) },
        on_select => sub ($index) { ... },
        on_close  => sub ($index) { ... },
        on_new    => sub () { ... },
);
```

`tabs` returns the tabs to show, read whenever a frame is drawn.

# METHODS

## natural\_size, paint, paint\_key

As in [Term::Fabulous::Widget::Display](../Widget/Display.md).

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
