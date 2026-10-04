# NAME

Term::Fabulous::Widget::Table::Cell - A cell of a table

# DESCRIPTION

The box [Term::Fabulous::Widget::Table](../Table.md) puts around every cell it
shows: header cells, filter fields, data cells and the cells that span
the columns (group headers, the text of an empty table). It is a
[Term::Fabulous::Widget::Box](../Box.md) that composes
[Clay::UI::Role::Layout::GridCell](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AGridCell), so the table's grids size it as the
cell of its column and row. The table gives it its background, padding
and border (the grid lines), and its content: the widget a column's
`cell` option returns, or a [Term::Fabulous::Widget::Text](../Text.md).

The table builds and changes these boxes itself; do not change them.
They are useful for reading: a `Mouse` event on a table cell has the
cell (or a widget inside it) as its target, and `line_key`,
`column_key` and `part` tell which cell it is.

# METHODS

## part

`'header'`, `'filter'` or `'body'`.

## line\_key

The key of the line of the table's model the cell belongs to (see
["Lines" in Term::Fabulous::Widget::Table::Model](Model.md#lines)), or `undef` in the
header.

## column\_key

The key of the cell's column; `''` for the selection column, `undef`
for a cell that spans the columns.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md).
