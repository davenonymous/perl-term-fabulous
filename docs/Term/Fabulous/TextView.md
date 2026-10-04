# NAME

Term::Fabulous::TextView - Lay out the text of an editor in a view of
rows and columns

# SYNOPSIS

```perl
use Term::Fabulous::Editor;
use Term::Fabulous::TextView;

my $editor = Term::Fabulous::Editor->new( text => "The quick brown fox\njumps" );
my $view   = Term::Fabulous::TextView->new( editor => $editor, wrap => 1 );
$view->set_size( 10, 3 );
$view->follow_cursor;

foreach my $row ( $view->visible_rows ) {
        my ( $line, $from, $to, $is_last, $shown_from ) = @$row;
        my @clusters = $view->clusters( $line, $shown_from, $to );    # [ $offset, $shown, $columns ]
        say join '', map { $_->[1] } @clusters;                      # "The quick ", "brown fox", "jumps"
}

my ( $line, $offset ) = $view->position_at( 3, 1 );    # under a click
$view->move_vertically(1);                               # Down
```

# DESCRIPTION

Most programs never use this module directly. It is the layout behind
[Term::Fabulous::Widget::TextInput](Widget/TextInput.md): given a [Term::Fabulous::Editor](Editor.md),
how its clusters are shown, a size and whether to wrap, it works out
which part of which line is shown on which row, where the cursor is,
how far the view is scrolled, which text position a cell shows, and
where the cursor goes when it moves up or down by rows. It knows nothing
of Clay::UI or canvases: [Term::Fabulous::Widget::TextField](Widget/TextField.md) is a view
of one row without wrapping, [Term::Fabulous::Widget::TextArea](Widget/TextArea.md) one of
its height that wraps or not.

## Visual rows

Every line of the editor is cut into _parts_, each shown on one
_visual row_. Without wrapping a line is one part. With wrapping, a
line breaks after the last blank that fits the width, or else before
the cluster that does not fit (a word wider than the view breaks
anywhere). A blank that does not fit any more _hangs_ at the break: it
belongs to the next part but is not shown there, so no row starts with
the blank that ended the row above. A line whose last part fills the
width gets an empty part after it, where the cursor can stand at the
end of the line. The end of a wrapped part is shown at the start of the
next row, so the cursor there is shown at the start of the next row.

A visual row is an array reference
`[ $line, $from, $to, $is_last, $shown_from ]`: the part `[from, to)`
(character offsets) of the editor line `$line`, shown from
`$shown_from` on (after a hanging blank), and whether it is the line's
last part.

## Scrolling

The view keeps its scroll position: the first visual row shown
(["top\_row"](#top_row)) and, without wrapping, the columns scrolled out on the
left (["left\_column"](#left_column)). Scrolling to the cursor moves just far enough to
show the cursor's row, and sideways the cursor's cell (the cell after
the line when the cursor is at its end), but not so far that the view
would end in empty cells while text is hidden on the left. Sideways
scrolling has one rule: the view always starts where a cluster of the
cursor's line starts, never inside a wide character.

# CONSTRUCTOR

## new

```perl
my $view = Term::Fabulous::TextView->new(
        editor    => $editor,                  # required
        display   => sub ($cluster) { '*' },   # how a cluster is shown
        wrap      => 1,
        scrollbar => 1,
);
```

- `editor`

    Required. The [Term::Fabulous::Editor](Editor.md) to show.

- `display`

    A code reference that turns a grapheme cluster of the text into what is
    shown for it, one cluster; its width in columns
    (["cluster\_columns" in Term::Fabulous::Unicode](Unicode.md#cluster_columns)) is what the cluster takes.
    Default: ["sanitize\_text" in Term::Fabulous::Unicode](Unicode.md#sanitize_text), so no control
    character reaches the terminal. A password field shows a mask instead.

- `wrap`

    A boolean, default 0: whether long lines wrap (see ["Visual rows"](#visual-rows)).

- `scrollbar`

    A boolean, default 0: whether the last column is given to a scrollbar
    when the text has more visual rows than the view, which then lays the
    text out one column narrower (see ["has\_scrollbar"](#has_scrollbar)).

Invalid values die with a message starting with
`Term::Fabulous::TextView:`.

# METHODS

## set\_size

```perl
$view->set_size( $columns, $rows );
```

The size of the view in cells, non-negative integers. Returns the view.
A view without columns or rows scrolls nowhere. Dies unless both are
non-negative integers.

## columns

The width of the view, in cells.

## rows

The height of the view, in cells.

## set\_wrap, set\_scrollbar

```perl
$view->set_wrap(0);
$view->set_scrollbar(1);
```

Change the `wrap` and `scrollbar` settings; `set_wrap` also scrolls
back to the left edge. Return the view. Any plain value is taken as a
boolean; a reference dies.

## wrap, scrollbar

The settings.

## set\_display

```perl
$view->set_display( sub ($cluster) { '*' } );
```

Changes how clusters are shown, which may change their widths. Returns
the view. Dies unless given a code reference.

## display\_changed

```perl
$view->display_changed;
```

Tells the view that its display function now shows clusters
differently (a password field switched its mask on), so the layout and
the scroll position are worked out again. Returns the view.

## editor

The editor.

## home

```perl
$view->home;
```

Scrolls back to the first row and the left edge. Returns the view.

## visual\_rows

```perl
my @rows = $view->visual_rows;
```

Every visual row of the text, as new array references (see
["Visual rows"](#visual-rows)).

## visual\_row\_count

The number of visual rows of the text.

## visible\_rows

```perl
my @rows = $view->visible_rows;
```

The visual rows shown, from ["top\_row"](#top_row) on, at most ["rows"](#rows) of them.

## clusters

```perl
my @clusters = $view->clusters( $line, $from, $to );
```

The clusters of the part `[from, to)` of a line, each as
`[ $offset, $shown, $columns ]`: where it starts in the line, what the
display function shows for it and how many columns that takes. `$from`
and `$to` are cluster boundaries.

## text\_columns

The columns the text is laid out in: ["columns"](#columns), or one less while the
view shows a scrollbar.

## has\_scrollbar

1 when `scrollbar` is on, the view has more than one column and the
text has more visual rows than the view at its full width.

## visual\_row\_of

```perl
my $index = $view->visual_row_of( $line, $offset );
```

The index of the visual row that shows an editor position.

## top\_row

The first visual row shown, counted from 0.

## left\_column

The columns scrolled out on the left; always 0 while wrapping.

## max\_top

The highest ["top\_row"](#top_row) there is: the visual rows less the rows of the
view, at least 0.

## follow\_cursor

```perl
$view->follow_cursor;
```

Scrolls to the cursor (["scroll\_to\_cursor"](#scroll_to_cursor)) when the editor (its
["revision" in Term::Fabulous::Editor](Editor.md#revision)), the size or a setting changed since
the last call; otherwise it leaves the view where it is, also when it
was scrolled away from the cursor with ["scroll\_rows"](#scroll_rows). Returns the
view.

## scroll\_to\_cursor

Scrolls just far enough to show the cursor (see ["Scrolling"](#scrolling)). Returns
the view.

## scroll\_rows

```perl
my $moved = $view->scroll_rows(3);
```

Scrolls by visual rows (negative: up), staying within the text, without
moving the cursor. Returns how many rows it moved, negative when it
moved up, and 0 when it is already at that end.

## cursor\_cell

```perl
my ( $x, $y ) = $view->cursor_cell;
```

The view cell the cursor is shown in, or the empty list when it is out
of view. At the end of a line the cursor is in the cell after its last
cluster.

## position\_at

```perl
my ( $line, $offset ) = $view->position_at( $column, $row );
```

The editor position shown at a view cell: the start of the cluster
covering the cell, or the end of the part when the cell is past it. A
cell past the end of a wrapped part gives the position before its last
cluster, since the end itself is shown on the next row. Rows below the
text give the last row.

## move\_vertically

```perl
$view->move_vertically( 1 );          # Down
$view->move_vertically( -1, 1 );      # Shift+Up
$view->move_vertically( $view->rows - 1 );    # PageDown
```

Moves the editor's cursor by visual rows, extending the selection with
a true second argument. It aims for the column the cursor had when
vertical movement started, as long as the cursor stays where the last
vertical move put it. Beyond the first or last row it goes to the start
or the end of the text. Returns the view.

# SEE ALSO

[Term::Fabulous::Widget::TextInput](Widget/TextInput.md), [Term::Fabulous::Editor](Editor.md),
[Term::Fabulous::Unicode](Unicode.md).
