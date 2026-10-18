# NAME

Term::Fabulous::Widget::Table::Frame - A frame around a table that shows its focus

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table::Frame qw(framed);

my $list = Term::Fabulous::Widget::Table->new( id => 'files', header => 0, border => 'none', ... );
$dialog->add_child( framed( $list, 10 ) );
```

# DESCRIPTION

The widgets that show a list in a [Term::Fabulous::Widget::Table](../Table.md)
(the file dialog, the color picker and the theme editor's value dialog)
put the table in a frame of its own: a plain [Term::Fabulous::Widget::Box](../Box.md)
border that shows the focus and, unlike the table's own frame, can be
asked for a height that gives way to the widgets around it. This
module makes that frame. It is internal to Term::Fabulous and not
meant to be used directly.

# FUNCTIONS

## framed

```perl
my $frame = framed( $table, $rows );
my $frame = framed( $table, $rows, $min_rows );
```

Returns a bordered [Term::Fabulous::Widget::Box](../Box.md) as wide as its
parent allows and `$rows + 2` cells high, with `$table` as its only
child. `$rows` counts the lines the table shows, its header lines
included (a header with a `header_line` is two). The table should
grow to fill the frame and have no frame of its own
(`border => 'none'`).

With `$min_rows` fewer than `$rows`, the frame gives up rows before
the widgets around it do when its parent has no room for all of them,
down to `$min_rows + 2` cells. It then also holds an empty column of
no width next to the table, which keeps the frame `$rows + 2` cells
high however few rows the table has (Clay sizes a box by its content).
The table's id with `/strut` is the id of that column. More
`$min_rows` than `$rows` dies.

While the table has the focus, the frame's border is drawn in the
theme's `input.accent`; when the table loses it, the border goes back
to its theme color.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md), [Term::Fabulous::Widget::Box](../Box.md).
