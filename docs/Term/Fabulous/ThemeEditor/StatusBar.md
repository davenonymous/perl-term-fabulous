# NAME

Term::Fabulous::ThemeEditor::StatusBar - The status line of the theme
editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. One row: a message on the left (cut with a `~` when it does not
fit), drawn in the color of its kind
(the theme's `toast` colors for `success`, `warning` and `error`),
and on the right what a code reference returns, as `[ text, kind ]`
parts (kinds `info`, `dim`, `accent`, `success`, `warning`,
`error`), read whenever a frame is drawn.

# METHODS

## message

```perl
$status->message( 'Saved ocean.kdl.', 'success' );
```

Shows a message of a kind; the message stays until the next one.

## text, kind

The message shown and its kind.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
