# NAME

Term::Fabulous::Widget::FileDialog::FolderLine - The line that names
the folder a file dialog shows

# DESCRIPTION

This class is internal to [Term::Fabulous::Widget::FileDialog](../FileDialog.md).
Applications never create one themselves.

It is a [Term::Fabulous::Widget::Display](../Display.md) one row high that grows to
the width of its parent and paints a label (`Folder:`) and a path in
the theme's `text.color`. When the path does not fit the width the
line gets, its start is cut off and replaced by `...` (by
["fit\_columns" in Term::Fabulous::Unicode](../../Unicode.md#fit_columns)), so the end of the path, the
folder itself, stays in view; with fewer than three columns for the
path, the `...` is cut to them. A label too long for the line is cut
at the right.

The file dialog uses one for the folder it shows, and one without a
label for each name in its list, so that a long name keeps its end.

# CONSTRUCTOR

## new

```perl
my $line = Term::Fabulous::Widget::FileDialog::FolderLine->new( path => '/home/ada/notes' );
```

Accepts the parameters of [Term::Fabulous::Widget::Display](../Display.md) and two
character strings: `label` (default `'Folder: '`) and `path`
(default `''`). Unknown parameters die.

# METHODS

## path

```perl
$line->path('/home/ada');
```

Accessor for the path. Writing paints the line again with the next
frame.

# SEE ALSO

[Term::Fabulous::Widget::FileDialog](../FileDialog.md).
