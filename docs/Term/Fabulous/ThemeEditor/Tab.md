# NAME

Term::Fabulous::ThemeEditor::Tab - A theme open in the theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A tab holds the text of one theme in a
[Term::Fabulous::ThemeEditor::KdlArea](KdlArea.md), whose editor keeps the one undo
history of both modes; the [Term::Fabulous::Theme::Document](../Theme/Document.md) parsed
from it; the file it belongs to and the text last saved there.

# CONSTRUCTOR

## new

```perl
my $tab = Term::Fabulous::ThemeEditor::Tab->new( path => 'ocean.kdl', text => $kdl );
my $tab = Term::Fabulous::ThemeEditor::Tab->new( untitled => 1, text => $template );
```

`path` or `untitled` (a number) is required; `text` is the theme's
text, `mode` (`form` or `text`) the mode the tab starts in, and
`modified` true for a text that is not the file's.

# METHODS

## path, untitled, title

The file, the number of an untitled theme, and the name the tab shows:
the file's base name or `untitled-N`.

## area, text, document

The text area, its text, and the document last parsed from it.

## mode

The mode the tab shows, `form` or `text`; writing sets it.

## form\_state

A hash reference the form keeps its state of this tab in.

## saved\_text, is\_modified

The text last read or saved (`undef` when there is none), and whether
the text differs from it.

## preview\_theme, is\_stale

The theme the preview shows (the document's, or while the text has
errors the last valid one), and whether that is an older state.

## sync, reparse

`reparse` parses the text; `sync` does so when the text changed since
the last parse and returns whether it did.

## change\_text, change\_document

Change the text as one undo step, replacing only the lines that differ.
`change_document` takes code that gets the current document and
returns a changed one.

## undo, redo, can\_undo, can\_redo

The undo history of the text area's editor.

## changed\_on\_disk

1 when the file's size or modification time differs from when it was
read or saved last.

## save

Writes the text to the tab's file, or to another one which becomes the
tab's file, in the line ends the file was read with.

## revert

Reads the file again; its text replaces the tab's as one undo step.

## write\_recovery

Writes the unsaved text to `FILE.unsaved` (`DIRECTORY/untitled-N.kdl.unsaved`
for an untitled theme) and returns that path.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
