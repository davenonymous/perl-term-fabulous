# NAME

Term::Fabulous::Widget::FileDialog::FolderLine - The line that names
the folder a file dialog shows, and its message line

# DESCRIPTION

This class is internal to [Term::Fabulous::Widget::FileDialog](../FileDialog.md).
Applications never create one themselves.

It is a [Term::Fabulous::Widget::Display](../Display.md) one row high that grows to
the width of its parent and paints a label (`Folder:`), a path and a
text after the path in the theme's `text.color`. When the path does
not fit the width the line gets, its start is cut off and replaced by
`...`, so the end of the path, the folder itself, stays in view. On a
line too narrow for the label, ten columns of the path and the text
after it, the path keeps up to ten columns and the text after it is
cut at the right; a label too long for the line is cut at the right.

The file dialog uses one for the folder it shows and one for its
message line, which names a path the same way (`There is no file`,
the path, `in this folder.`) and is one row high even when it says
nothing.

# CONSTRUCTOR

## new

```perl
my $line = Term::Fabulous::Widget::FileDialog::FolderLine->new( path => '/home/ada/notes' );
```

Accepts the parameters of [Term::Fabulous::Widget::Display](../Display.md) and three
character strings: `label` (default `'Folder: '`), `path` (default
`''`) and `after` (default `''`). Unknown parameters die.

# METHODS

## path

```perl
$line->path('/home/ada');
```

Accessor for the path. Writing paints the line again with the next
frame.

## say

```perl
$line->say( 'There is no file ', 'notes/todo.txt', ' in this folder.' );
```

Sets the label, the path and the text after it (the last two default
to `''`) and paints the line again with the next frame. Returns the
line.

## text

```perl
my $text = $line->text;
```

The whole text of the line, uncut: the label, the path and the text
after it.

## cut\_from\_the\_left

```perl
my $shown = Term::Fabulous::Widget::FileDialog::FolderLine::cut_from_the_left( $path, 20 );
```

A function: the end of a text that fits a number of columns, after
`...` when its start had to go. Returns the text itself when it fits,
and an empty string for no room.

# SEE ALSO

[Term::Fabulous::Widget::FileDialog](../FileDialog.md).
