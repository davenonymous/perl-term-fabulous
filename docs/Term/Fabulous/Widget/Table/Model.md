# NAME

Term::Fabulous::Widget::Table::Model - The rows of a table and how it shows them

# SYNOPSIS

```perl
my $model = $table->model;    # every table has one

say $model->row_count, ' rows, ', scalar( $model->filtered_row_ids ), ' match';
foreach my $line ( $model->page_lines ) {
        say $line->{kind} eq 'group'
                ? "group $line->{display} ($line->{count})"
                : ( '  ' x $line->{depth} ) . $model->display_of( $line->{id}, 'name' );
}
```

# DESCRIPTION

The model holds everything a [Term::Fabulous::Widget::Table](../Table.md) knows
apart from its widgets: the columns, the rows (a list, or a tree), the
sort, the filters, the grouping, which groups and tree rows are open,
the pages, the selection and the cursor. From these it computes the
_view_: the lines the table shows, in order, each a data row or a
group header. It has no widgets and no colors, so it can be used and
tested on its own.

Programs normally use the table's methods (see
[Term::Fabulous::Widget::Table](../Table.md)), which change the model, keep the
widgets up to date and fire the events. The model is reachable as
`$table->model` for reading, for example the view's lines; change
it through the table, or the table's widgets will not follow until the
next change through the table.

## Lines

["lines"](#lines) and ["page\_lines"](#page_lines) return the view as hash references:

- a row

    `{ kind => 'row', key, id, depth, has_children, expanded }`:
    `id` is the row id, `depth` its level in the tree (0 for top-level
    rows), `has_children` whether it has child rows that pass the filters,
    `expanded` whether they are shown.

- a group header

    `{ kind => 'group', key, group_key, path, depth, column, value, display, count, ids, expanded }`:
    `column` is the key of the column grouped by at this level (`depth`,
    from 0), `value` the raw value the group's rows share and `display`
    its display text, `path` the values of this group and the groups
    around it (outermost first), `count` the number of rows in the group
    (child rows included), `ids` the top-level row ids in it and
    `expanded` whether the group is open.

`key` names a line across changes: `"r\0$id"` for a row,
`"g\0..."` for a group. `row_key` and `id_of_key` (see
["View"](#view)) convert.

## How the view is computed

1. Rows pass when they match every filter and the search (see
["FILTERING" in Term::Fabulous::Manual::TableRows](../../Manual/TableRows.md#filtering)); in a tree, the ancestors
of a passing row pass too, so nothing is cut off from its parent.
2. Top-level rows are split into groups by the value of each `group_by`
column in turn; groups are ordered by that value, ascending unless the
sort says otherwise for the column.
3. Rows are sorted within each group and, in a tree, within their parent,
by the sort; rows that compare equal keep their data order.
4. The lines are listed: each group header, then its contents unless it is
collapsed; each row, then its children if it is expanded.
5. With a `page_size`, the lines are cut into pages of that many lines.

The view is computed when it is first needed after a change and kept
until the next one. Raw values and display texts are kept per cell until
the row or the column changes, so mutators run once per cell.

# CONSTRUCTOR

```perl
my $model = Term::Fabulous::Widget::Table::Model->new(
        row_id       => 'id',          # or sub ($row) { ... }, or undef
        children_key => 'children',    # or undef for flat rows
        page_size    => 25,            # 0: one page
        expand_new   => 0,             # rows with children start expanded?
);
```

The table makes its model from its own parameters of the same names;
see ["new" in Term::Fabulous::Widget::Table](../Table.md#new).

# METHODS

The table's methods of the same purpose describe the behavior from the
user's side (see ["METHODS" in Term::Fabulous::Widget::Table](../Table.md#methods)). Methods that
take a row id, a column key or a line key die for one that does not
exist, unless they say otherwise; a method that dies changes nothing.
Methods that change something and have no result to report return an
empty list.

## How rows are read

- `row_id`

    The `row_id` parameter: a column key, a code reference, or `undef`
    when the model numbers the rows itself (from 1).

- `set_row_id($row_id)`

    Changes how row ids are read and returns the new `row_id`. Dies while
    there are rows, and for a value that is neither `undef`, a non-empty
    string nor a code reference.

- `children_key`

    The `children_key` parameter: the key of the nested rows in the data,
    or `undef` for flat data.

- `set_children_key($key)`

    Changes the key of the nested rows and returns it. Dies while there are
    rows, and for a value that is neither `undef` nor a non-empty string.

- `expand_new`
- `expand_new($bool)`

    Accessor for the `expand_new` parameter: whether rows with children
    start expanded when they are added (by `set_rows` or `add_rows`).
    Returns 1 or 0; writing affects only rows added later.

## Columns

- `columns`

    The [Term::Fabulous::Widget::Table::Column](Column.md) objects, in order, hidden
    ones included.

- `column($key)`

    The column with the key. Dies if there is none.

- `column_keys`

    The keys of all columns, in order.

- `has_column($key)`

    1 if there is a column with the key, 0 otherwise (also for `undef`).

- `type_of($key)`

    The `type` of a column: `'string'`, `'number'` or `'date'`.

- `visible_columns`

    The Column objects of the visible columns, in order.

- `is_column_visible($key)`

    1 if the column is visible, 0 if it is hidden.

- `set_column_visible( $key, $visible )`

    Shows or hides a column. Does nothing when it is already so.

- `set_visible_columns(@keys)`

    Shows the columns with these keys and hides all others; the order of
    the columns stays. Does nothing when that is what is shown already.

- `add_column( $spec, $index )`

    Adds a column before the column at `$index` (from 0), or at the end
    without an index, and returns its Column object. `$spec` is a hash
    reference of column parameters or a Column object. The column starts
    hidden when its `visible` is 0. Dies for an invalid `$spec`, a key
    that is in use, or an index that is not an integer from 0 to the number
    of columns.

- `replace_column($column)`

    Puts a Column object in the place of the column with the same key, and
    returns it. Whether the column is visible stays as it was. Dies if there
    is no column with that key.

- `remove_column($key)`

    Removes a column. It also leaves the sort and the grouping, and every
    filter that compares it is removed.

- `move_column( $key, $index )`

    Moves a column to `$index` (from 0) among the columns. Dies for an
    index that is not an integer from 0 to the last index.

## Rows

- `set_rows(\@rows)`

    Replaces all rows and returns an array reference of the top-level ids.
    Each row is a hash reference; its entry under `children_key` (for tree
    data) is an array reference of child rows, nested as deep as you like.
    The model keeps a shallow copy of each row without that entry. Selected
    ids that still exist stay selected; every row with children is expanded
    when `expand_new` is set, none otherwise. Dies when `\@rows` is not an
    array reference of hash references, when a children entry is not an
    array reference, when a row has no id (see `row_id`), or when two rows
    have the same id.

- `add_rows( \@rows, %options )`

    Adds rows (with their children) and returns their top-level ids. The
    options are `parent`, the id of the row they become children of (only
    for tree data), and `index`, the position among their new siblings
    (from 0; default: after the last one). Dies for unknown options, a
    `parent` without `children_key`, an index out of range, and for the
    rows as `set_rows` does; an id that is in use dies too.

- `update_row( $id, \%changes )`

    Sets some entries of a row's data. Dies when `\%changes` is not a hash
    reference, when it has the `children_key` entry (add or remove child
    rows instead), and when the changed data would give the row another id.

- `replace_row( $id, \%data )`

    Replaces a row's data with a copy of `\%data`; a `children_key` entry
    in it is ignored and the row keeps its children. Dies when `\%data` is
    not a hash reference or would give the row another id.

- `set_value( $id, $key, $value )`

    Sets one entry of a row's data, as `update_row` does. `$key` need not
    be a column key.

- `remove_rows(@ids)`

    Removes rows and their children; they also leave the selection.

- `clear_rows`

    Removes all rows, the selection and which rows are expanded.

- `row($id)`

    A copy of a row's data (a new hash reference), without its children.

- `rows`

    All rows as `set_rows` takes them: an array reference of copies, with
    the children of tree data nested under `children_key`.

- `has_row($id)`

    1 if there is a row with the id, 0 otherwise (also for `undef`).

- `row_count`

    The number of rows, child rows included.

- `row_ids`

    The ids of all rows, depth-first in data order.

- `parent_of($id)`

    The id of a row's parent, or `undef` for a top-level row.

- `children_of($id)`

    The ids of a row's children, in data order.

- `depth_of($id)`

    A row's level in the tree: 0 for a top-level row.

- `row_revision($id)`

    Counts the changes of a row's data (`update_row`, `replace_row`,
    `set_value`); the table rebuilds a row's widgets when it changes.

## Cells

- `data_of($id)`

    The copy of a row's data the column callbacks get: the same hash
    reference until the row changes. Do not change it.

- `value_of( $row, $key )`

    The raw value of a cell (see
    ["value\_of" in Term::Fabulous::Widget::Table::Column](Column.md#value_of)). `$row` is a row id
    or a copy from `data_of`; any other hash reference is read as a row's
    data without using the cache. Dies for an unknown column.

- `display_of( $row, $key )`

    The display text of a cell, a string (see
    ["display\_of" in Term::Fabulous::Widget::Table::Column](Column.md#display_of)). `$row` is as for
    `value_of`.

## Sorting

- `sort_spec`

    The sort as a new array reference of `[ $key, 'asc' or 'desc' ]`
    pairs, the first one sorting first; empty when unsorted.

- `set_sort(@spec)`

    Replaces the sort. Each entry is a column key (ascending) or an array
    reference `[ $key, 'asc' or 'desc' ]`; no entries unsort. Returns 1
    when the sort changed, 0 otherwise. Dies for an unknown column, a
    direction other than `'asc'` or `'desc'`, or a column named twice.
    Whether the column is `sortable` is not checked.

- `cycle_sort( $key, $add )`

    Sorts as a click on a header does: a column cycles from ascending to
    descending to unsorted. With a false `$add` the column becomes the only
    sort key; with a true one it is added at the end of the sort, or cycled
    in its place. Returns 1 when the sort changed, 0 otherwise.

## Filtering

- `set_filter( $name, $filter )`

    Sets the filter of a name: a [Term::Fabulous::Widget::Table::Filter](Filter.md),
    or a code reference, which becomes a Filter with that `test`. A filter
    of the same name is replaced and keeps its place; `undef` removes it
    (see `remove_filter`). The filter is checked against the columns
    first (see ["check" in Term::Fabulous::Widget::Table::Filter](Filter.md#check)). Returns 1
    (for `undef`, what `remove_filter` returns).
    Dies for a name that is not a non-empty string, for any other kind of
    filter, and when the check dies.

- `remove_filter($name)`

    Removes the filter of a name. Returns 1 if there was one, 0 otherwise.

- `filter($name)`

    The Filter of a name, or `undef`.

- `filter_names`

    The names of the filters, in the order they were first set.

- `clear_filters`

    Removes every filter and the search. Returns 1 if there was anything to
    remove, 0 otherwise.

- `search`
- `search($text)`

    Accessor for the search text (`''` for none; writing `undef` sets
    `''`). A row matches when the text appears, case-insensitively, in the
    display text of one of its visible columns. Returns the search text.
    Dies for a reference.

- `is_filtered`

    1 when there is a filter or a search text, 0 otherwise.

- `expand_to_matches`

    In tree data with a filter or a search, expands every row that has a
    passing child, so what the filter found is shown. Returns 1 if a row was
    expanded, 0 otherwise.

## Grouping

- `group_by`
- `group_by(@keys)`

    Accessor for the columns the top-level rows are grouped by, outermost
    first. `group_by(undef)` ungroups. Writing returns the new keys and
    dies for an unknown column or a column named twice.

- `group_key_of(@path)`

    The `group_key` of the group a path names (see ["Lines"](#lines)).

- `is_group_collapsed(@path)`

    1 if the group the path names is collapsed, 0 otherwise. The path is the
    group's value and those of the groups around it, outermost first, as in
    a line's `path`.

- `set_group_collapsed( \@path, $collapsed )`

    Collapses or opens the group a path names. The state is kept by path,
    so it also applies to a group that only appears later. Returns 1 when
    the state changed, 0 otherwise. Dies when `\@path` is not an array
    reference.

- `set_all_groups_collapsed($collapsed)`

    With a true value, collapses every group the rows that pass the
    filters form now, nested groups included; with a false one, opens
    every group.

## Tree

- `is_expanded($id)`

    1 if the row is expanded, 0 otherwise.

- `set_expanded( $id, $expanded )`

    Expands or collapses a row. Returns 1 when the state changed, 0
    otherwise.

- `set_all_expanded($expanded)`

    Expands every row that has children, or collapses every row.

## View

- `lines`

    The lines of the whole view (every page), as new hash references (see
    ["Lines"](#lines)).

- `line_count`

    The number of lines of the whole view.

- `line($key)`

    The line with the key as a new hash reference, or `undef` when it is
    not in the view.

- `line_index($key)`

    The position of a line in the whole view (from 0), or `undef` when it
    is not in the view.

- `filtered_row_ids`

    The ids of every row that passes the filters, in view order; rows
    inside collapsed groups and below collapsed rows included.

These are functions, not methods (call them with the package name):

- `row_key($id)`

    The line key of a row.

- `group_key($group_key)`

    The line key of a group, from its `group_key`.

- `id_of_key($key)`

    The row id of a row's line key, or `undef` for a group's key or
    `undef`.

## Pages

- `page_size`

    The number of lines per page; 0 for no pages.

- `set_page_size($size)`

    Changes the page size; the page becomes the cursor's page. Returns 1
    when the size changed, 0 otherwise. Dies for a value that is not a
    non-negative integer.

- `page_count`

    The number of pages, at least 1.

- `page`

    The current page, from 1.

- `set_page($page)`

    Turns to a page (at most the last one) and puts the cursor on its first
    line. Returns 1 when the page changed, 0 otherwise (the cursor then
    stays). Dies for a value that is not a whole number from 1.

- `page_lines`

    The lines of the current page, as new hash references.

- `page_of_line($key)`

    The page a line is on, or `undef` when it is not in the view.

## Selection

- `selected_ids`

    The ids of the selected rows, depth-first in data order; rows that are
    filtered out stay selected.

- `is_selected($id)`

    1 if the row is selected, 0 otherwise (also for an unknown id).

- `set_selection(@ids)`

    Selects exactly these rows. Returns `( \@added, \@removed )`: the ids
    that became selected and those that stopped being selected, each in
    data order (two empty array references when nothing changed). The model
    does not know the table's `selection` mode; any number of rows may be
    selected.

- `select(@ids)`

    Adds rows to the selection. Returns as `set_selection` does.

- `deselect(@ids)`

    Removes rows from the selection. Returns as `set_selection` does.

- `toggle_selected($id)`

    Selects a row that is not selected, deselects one that is. Returns as
    `set_selection` does.

## Cursor

The cursor is always on a line of the current page while the view has
lines, and `undef` when it has none. When its line leaves the view, it
moves to the line that stands for it: the nearest shown ancestor row, or
its group header, or else the first line of the page.

- `cursor`

    The line key of the cursor, or `undef` when the view is empty.

- `set_cursor($key)`

    Puts the cursor on a line and turns to the line's page. Returns 1 when
    the cursor moved to another line, 0 otherwise. Dies when the line is not
    in the view.

- `anchor`

    The line key a range selection extends from, or `undef`.

- `set_anchor($key)`

    Sets the anchor; the model does not check it.

- `line_after_cursor($steps)`

    The key of the line `$steps` lines below the cursor (above for a
    negative number), kept within the lines of the whole view; `undef`
    when there is no cursor.

- `first_line_key`
- `last_line_key`

    The key of the first or the last line of the whole view, or `undef`
    when the view is empty.

- `line_keys_between( $from, $to )`

    The keys of the lines from one line to another, both included, in view
    order (`$from` may come after `$to`). Dies when a line is not in the
    view.

## Changes

- `revision`

    Counts every change: of the rows, the columns, the sort, the filters,
    the grouping, what is open, the page, the selection and the cursor.

- `columns_revision`

    Counts the changes of the columns: added, replaced, removed, moved,
    shown or hidden.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md).
