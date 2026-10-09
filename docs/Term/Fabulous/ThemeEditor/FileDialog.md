# NAME

Term::Fabulous::ThemeEditor::FileDialog - The open and save dialog of
the theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) that lists the folders and the
theme files (`*.kdl`, or all files when `Show all files` is checked)
of a directory, with their sizes and modification times, and a field
for a file name or a path.

The list has its frame in the accent color while it has the keyboard
focus. In the list, `Enter` or a double click opens a folder (`../` is the
parent folder) or chooses a file, `Backspace` goes to the parent
folder, and the cursor on a file puts its name into the field. In the
field, `Enter` takes the name or path: relative to the folder shown,
absolute, or starting with `~` for the home directory; a folder opens
it. To save, a name without an extension gets `.kdl`. `Escape` or
`Cancel` closes the dialog without a choice.

# CONSTRUCTOR

## new

```perl
Term::Fabulous::ThemeEditor::FileDialog->new(
        mode      => 'save',          # or 'open'
        directory => '.',
        name      => 'ocean.kdl',     # what the field starts with
        on_done   => sub ($path) { ... },    # undef when cancelled
        list_rows => 10,                     # the entries the list shows
)->open($ui);
```

# METHODS

## mode, directory

The mode, and the folder the dialog shows.

## choose

Takes a name or a path as the field does.

## typed, list

The text of the field and the list of the folder.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
