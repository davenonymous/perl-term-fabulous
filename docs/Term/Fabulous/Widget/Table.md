# NAME

Term::Fabulous::Widget::Table - Rows and columns with sorting, filtering,
grouping, trees, pages and selection

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table;
use Term::Fabulous::Widget::Table::Mutator qw(date number);

my $table = Term::Fabulous::Widget::Table->new(
        id        => 'staff',
        row_id    => 'id',              # the rows' 'id' entry names each row
        selection => 'multiple',        # check boxes, Space, Shift+arrows, Ctrl+A
        columns   => [
                { key => 'name',    title => 'Name' },
                { key => 'team',    title => 'Team' },
                { key => 'started', title => 'Started', type => 'date',   mutator => date('%d %b %Y') },
                { key => 'salary',  title => 'Salary',  type => 'number', mutator => number( decimals => 0 ) },
        ],
        rows => [
                { id => 1, name => 'Ada',   team => 'Core', started => '2019-03-04', salary => 81000 },
                { id => 2, name => 'Grace', team => 'Web',  started => '2021-11-15', salary => 76500 },
                { id => 3, name => 'Linus', team => 'Core', started => '2017-06-01', salary => 90000 },
        ],
        sort       => [ [ started => 'desc' ] ],
        filter_row => 1,                # a filter field under every column title
        page_size  => 25,               # pages of 25 lines, with a pager below
);

$table->on( RowActivate => sub ($event) {       # Enter or a double click
        say 'open ', $event->row->{name};
        return;
} );
$table->on( SelectionChange => sub ($event) {
        say scalar @{ $event->selected_ids }, ' selected';
        return;
} );

$table->add_row( { id => 4, name => 'Ken', team => 'Web', started => '2023-01-09', salary => 70000 } );
$table->set_value( 2, salary => 79000 );
$table->group_by('team');
my @chosen = $table->selected_rows;              # copies of the selected rows' data
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-table.svg" alt="A table of staff with a filter row, sorted by the start date, two rows selected with check boxes and a pager below"></p>
</div>

The program is `examples/widgets/table.pl`.

# DESCRIPTION

A table shows a list of Perl hashes as rows and columns. You describe
the columns once; the table takes care of everything the user does with
the rows: moving through them with the keyboard and the mouse, sorting
by a click on a column title, filtering, opening and closing groups and
tree rows, turning pages and selecting rows. Your program reads and
changes the data at any time through the table's methods, and learns
about the user's actions through events.

This page is the reference: the exact contract of every parameter,
method, key, mouse action, event and KDL property (what it takes,
returns and when it dies), in ["CONSTRUCTOR"](#constructor), ["METHODS"](#methods), ["KEYS"](#keys),
["MOUSE"](#mouse), ["EVENTS"](#events) and ["KDL PROPERTIES"](#kdl-properties). To find a name in a
terminal, run `perldoc Term::Fabulous::Widget::Table` and search with
`/`, for example `/filter_row`.

The table guide explains every feature with examples, organized by
feature, on three pages of the manual:

- [Term::Fabulous::Manual::Tables](../Manual/Tables.md)

    How a table works, the terms used, rows, columns, display text and
    mutators, and widgets in cells. Its
    [FEATURE INDEX](../Manual/Tables.md#feature-index) lists
    every feature with the section that explains it.

- [Term::Fabulous::Manual::TableRows](../Manual/TableRows.md)

    Sorting, filtering, grouping, trees, pages, the cursor and the
    selection.

- [Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md)

    Colors, styles, lines between and around the cells, padding, size,
    scrolling and printing.

Complete programs that use tables are in [Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md),
[Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md),
[Term::Fabulous::Cookbook::TableStyles](../Cookbook/TableStyles.md) and [Term::Fabulous::Examples](../Examples.md).

## Features

- Any number of columns, each with its own width (fit, fixed, grow,
percent, with limits), alignment and text wrapping; rows are as high as
their tallest cell. See ["COLUMNS" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#columns).
- _Mutators_ turn raw values into display text, for example epoch
seconds into a date, while sorting and filtering keep using the raw
value. See ["DISPLAY TEXT AND MUTATORS" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#display-text-and-mutators).
- Any widget as a cell: buttons, check boxes, text fields, canvases. See
["CELL WIDGETS" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#cell-widgets).
- Sorting by one or several columns, by the user or from Perl, with
built-in comparisons for text, natural text, numbers and dates, or your
own function. See ["SORTING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#sorting).
- Filtering: a filter row where the user types expressions such as
`>=100` or `2024-05`, named filters from Perl (text, number and
date comparisons, on the raw value or the display text, combined with
and, or, not), and a search over all columns. See ["FILTERING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#filtering).
- Grouping rows by the values of one or more columns, under group
headers that open and close. See ["GROUPING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#grouping).
- Trees: rows with child rows, opened and closed with a marker. See
["TREES" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#trees).
- Pages with a pager and a choice of page sizes. See ["PAGES" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#pages).
- A cursor and no, single or multiple selection, with check boxes. See
["SELECTION AND CURSOR" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#selection-and-cursor).
- Choosing the visible columns, also by the user in a column chooser.
See ["Choosing the visible columns" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#choosing-the-visible-columns).
- Colors, striped rows, and lines (borders) per table, column, row and
cell, joined into a clean grid. See ["STYLES AND BORDERS" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#styles-and-borders).
- Changing the data at any time: cells, whole rows, adding and removing
rows and columns. See ["Changing the data" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#changing-the-data).
- Full keyboard and mouse use (see ["KEYS"](#keys) and ["MOUSE"](#mouse)), events for
every user action (see ["EVENTS"](#events)), and tables in KDL layout files (see
["KDL PROPERTIES"](#kdl-properties)).

# CONSTRUCTOR

## new

```perl
my $table = Term::Fabulous::Widget::Table->new( id => 'orders', %parameters );
```

Makes a table. `id` is required. Unknown parameters and invalid values
die, naming the parameter. The
[parameters of a Box](Box.md#constructor) work
too; the useful ones are `layout` (only its `sizing`; see
["SIZE AND SCROLLING" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#size-and-scrolling)) and
`background_color` (see ["Colors" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#colors)). Most parameters have an accessor
of the same name, described under ["METHODS"](#methods).

### Data

- `id`

    Required. A string, unique among the widgets of the program, as for
    every widget. The table also uses the id `"$id/body"` for its
    scrolling body, so that one must not be used either.

- `columns`

    An array reference of column definitions, hash references (see
    ["COLUMNS" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#columns) and ["PARAMETERS" in Term::Fabulous::Widget::Table::Column](Table/Column.md#parameters)) or
    [Term::Fabulous::Widget::Table::Column](Table/Column.md) objects. Default: no columns.
    Two columns with the same key die.

- `rows`

    An array reference of hash references, the rows (see ["ROWS" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#rows)). They
    are copied. Default: no rows.

- `row_id`

    Where row ids come from: a key of the rows, a code reference
    `sub ($row) { ... }`, or `undef` (the default) for ids the table
    counts up from 1. See ["Row ids" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#row-ids).

- `children_key`

    The key under which a row holds its child rows, as an array reference
    of rows; this makes the table a tree (see ["TREES" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#trees)). Default: `undef`,
    no tree.

- `tree_expanded`

    A boolean. Default: 0. When true, rows with children start open.

- `tree_column`

    The key of the column that shows the tree's indentation and markers.
    Default: `undef`, the first visible column.

### Sorting, filtering, grouping, pages

- `sort`

    An array reference of column keys (ascending) and `[ $key, 'asc' ]` or
    `[ $key, 'desc' ]` pairs; the first one decides first. Default: `[]`,
    unsorted. See ["SORTING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#sorting).

- `filter_row`

    A boolean. Default: 0. When true, a row of filter fields shows below
    the column titles. See ["The filter row" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#the-filter-row).

- `group_by`

    A column key, or an array reference of column keys (outermost first).
    Default: no groups. See ["GROUPING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#grouping).

- `group_label`

    A code reference that gets a hash about a group and returns the text or
    the widget of its header. Default: `undef`, `Title: value (count)`.
    See ["Group headers" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#group-headers).

- `page_size`

    A non-negative integer, the number of lines per page. Default: 0, no
    pages. See ["PAGES" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#pages).

- `page_sizes`

    A non-empty array reference of positive integers, the page sizes the
    pager offers. Default: `[10, 25, 50, 100]`.

- `pager`

    `undef` (the default): show the pager while `page_size` is above 0.
    1: always show it. 0: never.

### Selection and input

- `selection`

    `'none'` (the default), `'single'` or `'multiple'`. With
    `'single'`, the selection follows the cursor: every move onto a data
    row selects that row. See ["Selection" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#selection).

- `selection_column`

    A boolean: whether the selection column with check boxes is shown.
    Default: `undef`, which means 1 for `'multiple'` and 0 otherwise.
    Never shown with `'none'`.

- `hover`

    A boolean. Default: 1. Whether the line under the mouse pointer is
    highlighted with the `hover_color`.

- `double_click_seconds`

    A number of seconds, at least 0. Default: 0.4. Two clicks on the same
    line at most this far apart are a double click. Only a parameter; there
    is no accessor.

### Parts shown

- `header`

    A boolean. Default: 1. Whether the column titles are shown. Without
    them, the user cannot sort by clicking, and `Up` does not lead into the
    header.

- `scrollbar`

    A boolean. Default: 1. Whether the scrollbar column is shown right of
    the rows.

- `empty_text`

    A string. Default: `'No rows'`. Shown, in the `muted_color` and
    italic, when the table has no rows.

- `no_match_text`

    A string. Default: `'No rows match'`. Shown instead when the table has
    rows but none passes the filters.

### Lines and spacing

- `border`

    The line style of all four sides of the frame. Default: `'Round'`. The
    values of this and the following parameters are described in
    ["Lines between and around the cells" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#lines-between-and-around-the-cells).

- `border_top`, `border_right`, `border_bottom`, `border_left`

    One side of the frame. Default: `undef`, the style of `border`.

- `column_lines`

    The lines between the columns. Default: `'Solid'`.

- `row_lines`

    The lines between the rows. Default: `undef`, none.

- `header_line`

    The line below the column titles and the filter row. Default:
    `'Solid'`. `undef` takes the style of `row_lines`.

- `cell_padding`

    A non-negative integer (the left and right padding) or a hash reference
    with any of `left`, `right`, `top` and `bottom`. Default: 1. See
    ["Cell padding" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#cell-padding).

### Styles and colors

- `row_style`

    A code reference `sub ( $row, $id ) { ... }` that returns a style
    hash of the _row_ kind, or `undef`. Default: none. See ["Styles of
    rows and cells" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#styles-of-rows-and-cells).

- `header_style`

    A style hash of the _row_ kind for the column titles. Default: none.

- `group_style`

    A style hash of the _row_ kind for group headers. Default: none.

- `stripe_color`

    A color, or `undef` (the default) for no stripes. See ["Striped
    rows" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#striped-rows).

- `text_color`, `header_text_color`, `header_background_color`, `group_text_color`, `group_background_color`, `cursor_color`, `selected_color`, `hover_color`, `filter_background_color`, `error_color`, `muted_color`, `line_color`

    Colors in any format of [Term::Fabulous::Color](../Color.md). What each one colors,
    and its default, is described in
    ["Colors" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#colors).

# METHODS

The methods are listed by topic. Unless a method says otherwise:

- A method that changes the table fires **no** event. The change shows in
the next frame.
- A method that is not an accessor and changes the table returns the
table, so calls can be chained.
- Accessors return the value when called without an argument, and set it
with one. Setting returns the new value, except for `rows`, `search`,
`filter_text`, `group_by`, `page`, `page_size` and `cursor`, which
return the table.
- Methods that take a row id die when no row has that id; methods that
take a column key die when there is no such column.

## Methods for rows

### rows

```perl
my $rows = $table->rows;
$table->rows( \@rows );
```

Without an argument: copies of all rows as an array reference, in data
order, in the form you gave them (in a tree, with the child rows nested
under `children_key`). With an array reference of hash references:
replaces all rows. Rows whose id stays keep their selection; all tree
rows are closed again (or open, with `tree_expanded`). Returns the
table.

### add\_row

```perl
my $id = $table->add_row( \%row );
my $id = $table->add_row( \%row, index => 0 );
my $id = $table->add_row( \%row, parent => $parent_id, index => 2 );
```

Adds one row and returns its id. `index` is the position among its
siblings in data order (0 is the first; default: after the last);
`parent` makes it a child row of that row, which needs a tree. Dies
for an index out of range, an id in use, or other options.

### add\_rows

```perl
my @ids = $table->add_rows( \@rows, %options );
```

Adds several rows, at one position, with the same options as
`add_row`. Returns their ids. If one row is invalid, none is added.

### update\_row

```perl
$table->update_row( $id, { name => 'Ada L.', team => 'Web' } );
```

Merges the hash of changes into the row's data. The keys need not be
column keys. Dies when the changes would give the row another id, or
contain `children_key`. Returns the table.

### replace\_row

```perl
$table->replace_row( $id, \%data );
```

Replaces the row's data with a copy of `\%data` (an entry under
`children_key` is ignored; the child rows stay). Dies when the data
would give the row another id. Returns the table.

### set\_value

```perl
$table->set_value( $id, $key, $value );
```

Sets one entry of the row's data. `$key` must be a column key; use
`update_row` for other entries. Returns the table.

### remove\_row

```perl
$table->remove_row($id);
```

Removes a row and all its child rows. They leave the selection, and
their styles from `set_row_style` and `set_cell_style` are forgotten.
Returns the table.

### remove\_rows

```perl
$table->remove_rows(@ids);
```

Like `remove_row`, for several rows. Dies before removing anything
when one of the ids is unknown.

### clear\_rows

```perl
$table->clear_rows;
```

Removes all rows. Returns the table.

### row

```perl
my $data = $table->row($id);
```

A copy of the row's data (without its child rows).

### value

```perl
my $raw = $table->value( $id, $key );
```

The raw value of a cell: what the column reads or computes from the
row.

### display\_value

```perl
my $text = $table->display_value( $id, $key );
```

The display text of a cell: the raw value after the column's mutators,
as a string (`''` for `undef`).

### has\_row

```perl
if ( $table->has_row($id) ) { ... }
```

1 when a row has the id, 0 otherwise. Never dies.

### row\_ids

```perl
my @ids = $table->row_ids;
```

The ids of all rows, in data order (in a tree: each row, then its
children).

### row\_count

```perl
my $count = $table->row_count;
```

The number of rows, child rows included, filtered or not.

### filtered\_row\_ids

```perl
my @ids = $table->filtered_row_ids;
```

The ids of the rows that pass the filters and the search, in view order
(sorted and grouped), including rows inside closed groups and tree
rows.

### page\_row\_ids

```perl
my @ids = $table->page_row_ids;
```

The ids of the data rows on the current page, in the order they are
shown.

### parent\_of

```perl
my $parent = $table->parent_of($id);
```

The id of the row's parent row, or `undef` for a top-level row.

### children\_of

```perl
my @ids = $table->children_of($id);
```

The ids of the row's child rows, in data order (all of them, filtered
or not).

## Methods for columns

### columns

```perl
my @columns = $table->columns;
```

The [Term::Fabulous::Widget::Table::Column](Table/Column.md) objects, in order, hidden
ones included.

### column

```perl
my $column = $table->column('salary');
```

One column object. Dies for an unknown key.

### column\_keys

```perl
my @keys = $table->column_keys;
```

The keys of all columns, in order, hidden ones included.

### add\_column

```perl
my $column = $table->add_column( \%definition );
my $column = $table->add_column( \%definition, index => 0 );
```

Adds a column at the end, or at `index` (0 is the first). Returns the
new column object. Dies when a column has the key already, for an index
out of range, or other options.

### remove\_column

```perl
$table->remove_column('email');
```

Removes a column, also from the sort and the grouping, with every filter
that compares it and its filter field text. Returns the table.

### move\_column

```perl
$table->move_column( email => 0 );
```

Moves a column to an index (0 is the first, the highest is the number of
columns minus 1). Returns the table.

### update\_column

```perl
my $column = $table->update_column( salary => title => 'Pay', align => 'center' );
```

Replaces a column with a new one made from its parameters and the
changes, and returns the new column object. The column keeps its place
and whether it is visible: `visible` in the changes has no effect (use
["show\_columns"](#show_columns) and ["hide\_columns"](#hide_columns)). The `key` cannot be changed
(that dies).

### visible\_columns

```perl
my @keys = $table->visible_columns;
```

The keys of the visible columns, in order.

### is\_column\_visible

```perl
if ( $table->is_column_visible('email') ) { ... }
```

1 or 0.

### show\_columns

```perl
$table->show_columns(qw(email phone));
```

Shows the named columns, each at its place in the order of the columns.
Returns the table.

### hide\_columns

```perl
$table->hide_columns('note');
```

Hides the named columns. Returns the table.

### set\_visible\_columns

```perl
$table->set_visible_columns(qw(name team));
```

Shows exactly the named columns and hides all others. The order of the
columns does not change. Returns the table.

### open\_column\_chooser

```perl
$table->open_column_chooser;
```

Opens the column chooser (see ["Choosing the visible columns" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#choosing-the-visible-columns)) and
gives it the focus. Does nothing when it is open. Returns the table.
Changes the user makes in it fire `ColumnsChange`.

### close\_column\_chooser

```perl
$table->close_column_chooser;
```

Closes the column chooser; when it had the focus, the table gets the
focus. Does nothing when it is closed. Returns the table.

### is\_column\_chooser\_open

1 while the column chooser is open, 0 otherwise.

## Methods for sorting

### sort\_by

```perl
$table->sort_by( 'team', [ salary => 'desc' ] );
$table->sort_by;    # no sort
```

Sorts by the columns given, replacing the sort (see ["Sorting from
Perl" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#sorting-from-perl)). Without arguments, the table is unsorted. Dies for an unknown
column, a direction other than `'asc'` or `'desc'`, or a column named
twice. Returns the table.

### clear\_sort

```perl
$table->clear_sort;
```

The same as `sort_by` without arguments.

### sort\_spec

```perl
my $spec = $table->sort_spec;    # [ [ 'team', 'asc' ], [ 'salary', 'desc' ] ]
```

The sort, as an array reference of `[ $key, $direction ]` pairs (a
copy). `[]` when unsorted.

## Methods for filtering

### filter

```perl
$table->filter( $name => $filter );
$table->filter( $name => sub ($row) { ... } );
$table->filter( $name => undef );    # remove it
```

Sets the filter of a name: a [Term::Fabulous::Widget::Table::Filter](Table/Filter.md),
a code reference (called with a copy of each row's data; true keeps the
row), or `undef` to remove it. A filter under the same name is
replaced. Dies for a name that is not a non-empty string or that starts
with `column:` (those belong to the filter row), for a filter of
another kind, and for a filter that names an unknown column or compares
with a value its column's type cannot read. In a tree, opens the rows
that lead to matching rows. Returns the table.

### remove\_filter

```perl
$table->remove_filter('adults');
```

Removes the filter of that name; does nothing when there is none.
Returns the table.

### filter\_names

```perl
my @names = $table->filter_names;
```

The names of the filters set with `filter`, in the order they were
first set. The filter row's filters are not listed.

### clear\_filters

```perl
$table->clear_filters;
```

Removes all filters: those set with `filter`, the search, and the text
of every filter field. Returns the table.

### search

```perl
$table->search('ada');
my $text = $table->search;
```

Accessor for the search text (see ["Searching all columns" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#searching-all-columns)). `''`
or `undef` ends the search. Setting it returns the table. In a tree,
opens the rows that lead to matching rows.

### filter\_text

```perl
$table->filter_text( size => '>=1000' );
my $text = $table->filter_text('size');
```

Accessor for the filter expression of a column's filter field (see
["The filter row" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#the-filter-row)), also while the filter row is hidden. `''` or
`undef` removes the column's filter. An invalid expression does not
die: the column is then unfiltered, and `filter_error` says why.
Setting it returns the table and fires no `FilterChange`.

### filter\_error

```perl
my $message = $table->filter_error('size');
```

Why the column's filter expression is invalid, or `undef` when it is
valid or empty.

### filter\_row

```perl
$table->filter_row(1);
my $shown = $table->filter_row;
```

Accessor for the `filter_row` parameter. Hiding the filter row keeps
the filters of its fields; use `clear_filters` or `filter_text` to
remove them. Setting it returns the new value.

## Methods for groups

### group\_by

```perl
$table->group_by( 'team', 'city' );
$table->group_by(undef);           # no groups
my @keys = $table->group_by;
```

Groups by the columns given, outermost first (see ["GROUPING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#grouping)), and
returns the table. Without arguments, returns the keys of the group
columns (an empty list when not grouped). Dies for an unknown column or
a column named twice.

### ungroup

```perl
$table->ungroup;
```

Ends the grouping. Returns the table.

### is\_group\_expanded

```perl
if ( $table->is_group_expanded( 'Sales', 'Berlin' ) ) { ... }
```

1 when the group with that path is open, 0 when it is closed. Also 1
for a path that names no group.

### expand\_group

```perl
$table->expand_group('Sales');
$table->expand_group( 'Sales', 'Berlin' );
```

Opens the group with that path (the raw values of the group and the
groups around it, outermost first). Returns the table.

### collapse\_group

```perl
$table->collapse_group( 'Sales', 'Berlin' );
```

Closes the group with that path. Returns the table.

### expand\_all\_groups

```perl
$table->expand_all_groups;
```

Opens every group, nested groups included. Returns the table.

### collapse\_all\_groups

```perl
$table->collapse_all_groups;
```

Closes every group there is now (with the current filters), nested
groups included. Groups that appear later start open. Returns the
table.

### cursor\_group

```perl
my $path = $table->cursor_group;
```

The path of the group header the cursor is on (an array reference), or
`undef` when the cursor is on a data row or there is no cursor.

## Methods for trees

### is\_expanded

```perl
if ( $table->is_expanded($id) ) { ... }
```

1 when the row is open, 0 otherwise.

### expand

```perl
$table->expand( '/src', '/src/lib' );
```

Opens the rows with these ids. Returns the table.

### collapse

```perl
$table->collapse('/src');
```

Closes the rows with these ids; their child rows keep their own state.
Returns the table.

### expand\_all

```perl
$table->expand_all;
```

Opens every row that has child rows. Returns the table.

### collapse\_all

```perl
$table->collapse_all;
```

Closes every row that has child rows. Returns the table.

### children\_key

```perl
$table->children_key('children');
```

Accessor for the `children_key` parameter. Setting it dies while the
table has rows; set it before adding rows. Setting returns the new
value.

### tree\_expanded

```perl
$table->tree_expanded(1);
```

Accessor for the `tree_expanded` parameter. Setting it affects rows
added afterwards, not the rows the table has. Setting returns the new
value.

### tree\_column

```perl
$table->tree_column('name');
$table->tree_column(undef);    # the first visible column
```

Accessor for the `tree_column` parameter. Dies for an unknown column.
Setting returns the new value.

## Methods for pages

### page

```perl
$table->page(3);
my $page = $table->page;    # from 1
```

Accessor for the current page, counted from 1. Setting turns to that
page (a number above the last page turns to the last page) and, when the
page changes, puts the cursor on its first line; it dies for a number that is not a whole
number from 1. Setting returns the table. Without pages, the page is
always 1.

### page\_count

```perl
my $pages = $table->page_count;
```

The number of pages, at least 1.

### page\_size

```perl
$table->page_size(50);
my $size = $table->page_size;
```

Accessor for the number of lines per page, 0 for no pages. Setting
keeps the cursor on its line and shows that line's page; it returns the
table. Dies for a value that is not a non-negative integer.

### next\_page

```perl
$table->next_page;
```

Turns one page forward; on the last page, nothing happens. Returns the
table.

### previous\_page

```perl
$table->previous_page;
```

Turns one page back; on the first page, nothing happens. Returns the
table.

### page\_sizes

```perl
$table->page_sizes( [ 20, 50 ] );
```

Accessor for the `page_sizes` parameter. Setting returns a copy of the
new list.

### pager

```perl
$table->pager(0);
```

Accessor for the `pager` parameter (`undef`, 1 or 0). Setting returns
the new value.

## Methods for selection and cursor

### selection

```perl
$table->selection('multiple');
my $mode = $table->selection;
```

Accessor for the selection mode. Setting keeps the part of the
selection the new mode allows (see ["Selection" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#selection)), shows or hides the
selection column as `selection_column` says, and returns the new mode.

### selection\_column

```perl
$table->selection_column(0);
```

Accessor for the `selection_column` parameter. Once set (by parameter
or accessor), it no longer follows the selection mode. Setting returns
the new value.

### selected\_ids

```perl
my @ids = $table->selected_ids;
```

The ids of the selected rows, in data order.

### selected\_rows

```perl
my @rows = $table->selected_rows;
```

Copies of the data of the selected rows, in data order.

### is\_selected

```perl
if ( $table->is_selected($id) ) { ... }
```

1 or 0. Never dies.

### set\_selection

```perl
$table->set_selection(@ids);
$table->set_selection;    # nothing selected
```

Selects exactly these rows. Dies with `selection => 'none'` when
ids are given, and for more than one id with `'single'`. Returns the
table.

### select

```perl
$table->select(@ids);
```

Adds rows to the selection; with `'single'`, selects the row instead
of the one selected before. Dies like `set_selection`. Returns the
table.

### deselect

```perl
$table->deselect(@ids);
```

Removes rows from the selection. Returns the table.

### select\_all

```perl
$table->select_all;
```

Adds every row that passes the filters to the selection. Dies unless
the mode is `'multiple'`. Returns the table.

### clear\_selection

```perl
$table->clear_selection;
```

Selects nothing. Returns the table.

### cursor

```perl
my $id = $table->cursor;
$table->cursor($id);
```

Without an argument: the id of the row the cursor is on, or `undef`
when it is on a group header or the view is empty. With a row id: puts
the cursor on that row, turns to its page, scrolls it into view and
returns the table. Dies when the row is not shown (filtered out, or
inside a closed group or tree row). Does not change the selection. See
["The cursor" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#the-cursor).

### scroll\_to\_row

```perl
$table->scroll_to_row($id);
```

The same as `$table->cursor($id)`.

## Methods for styles

### set\_row\_style

```perl
$table->set_row_style( $id, { background_color => '#3b3222', border_top => 'Double' } );
```

Sets the style hash (_row_ kind) of a row, replacing what was set for
it before; `{}` or `undef` removes it. Dies for unknown keys or
invalid values. Returns the table.

### row\_style\_of

```perl
my $style = $table->row_style_of($id);
```

A copy of what `set_row_style` set for the row (colors as
`[ $r, $g, $b, $a ]`, lines as [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md)
objects), `{}` when nothing.

### set\_cell\_style

```perl
$table->set_cell_style( $id, 'amount', { text_color => '#e06c75' } );
```

Sets the style hash (_cell_ kind) of one cell, like `set_row_style`.

### cell\_style\_of

```perl
my $style = $table->cell_style_of( $id, 'amount' );
```

A copy of what `set_cell_style` set for the cell, `{}` when nothing.

### row\_style

```perl
$table->row_style( sub ( $row, $id ) { ... } );
$table->row_style(undef);
```

Accessor for the `row_style` code reference; `undef` removes it.
Setting returns the new value.

### group\_label

```perl
$table->group_label( sub ($group) { ... } );
```

Accessor for the `group_label` code reference; `undef` brings back
the default label. Setting returns the new value.

### header\_style

```perl
$table->header_style( { background_color => '#2c313c' } );
```

Accessor for the `header_style` style hash. Returns a copy; setting
returns a copy of the checked style.

### group\_style

```perl
$table->group_style( { text_color => '#e5c07b' } );
```

Accessor for the `group_style` style hash, like `header_style`.

## Methods for lines and spacing

The line accessors below take a line style name, a
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) object, `'none'` or `undef` (see
["Lines between and around the cells" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#lines-between-and-around-the-cells)). They return the style as an
object (the `Hidden` style for `'none'`), or `undef` for no line.

### border

```perl
$table->border('Double');
my $style = $table->border;
```

Sets all four sides of the frame and returns the style of the top side.
Reading returns the style the four sides share, or `undef` when they
differ or none has a style.

### border\_top

```perl
$table->border_top('Heavy');
```

Accessor for the top side of the frame.

### border\_right

Accessor for the right side of the frame.

### border\_bottom

Accessor for the bottom side of the frame.

### border\_left

Accessor for the left side of the frame.

### column\_lines

```perl
$table->column_lines('none');
```

Accessor for the lines between the columns.

### row\_lines

```perl
$table->row_lines('Dashed');
```

Accessor for the lines between the rows.

### header\_line

```perl
$table->header_line('Heavy');
```

Accessor for the line below the column titles. `undef` takes the style
of `row_lines`, as in the constructor.

### cell\_padding

```perl
$table->cell_padding( { left => 2, right => 2 } );
my $padding = $table->cell_padding;    # { left => 2, right => 2, top => 0, bottom => 0 }
```

Accessor for the `cell_padding` parameter; returns a hash with all four
sides. Setting rebuilds every cell.

## Methods for colors

```perl
$table->cursor_color('#3e4451');
my $rgba = $table->cursor_color;    # [ 62, 68, 81, 255 ]
```

Every color has an accessor of its name. It takes any format of
[Term::Fabulous::Color](../Color.md) and returns `[ $r, $g, $b, $a ]`; an invalid
color dies and keeps the old one.
[The colors section of the table styles guide](../Manual/TableStyles.md#colors)
describes what each color colors.

### text\_color

The text of the data cells and the filter fields, the pager's buttons
and page number, the text and frame of the column chooser, and the
scrollbar's thumb.

### header\_text\_color

The text of the column titles.

### header\_background\_color

The background of the column titles.

### group\_text\_color

The text of group headers.

### group\_background\_color

The background of group headers and of the column chooser.

### cursor\_color

The background of the cursor's line while the table has the focus, of
the column title the keyboard is on, and of a focused filter field.

### selected\_color

The background of selected rows.

### hover\_color

The background of the line under the mouse pointer.

### filter\_background\_color

The background of the filter row.

### error\_color

The text of a filter field with an invalid expression.

### muted\_color

The text shown in an empty table, and the pager's count.

### line\_color

Every line that no style gives a `border_color`, and the scrollbar's
track.

### stripe\_color

The background of every second data row; `undef` for no stripes.

### background\_color

The background of cells that have no other; `undef` for the background
of the nearest opaque ancestor.

## Other accessors

Accessors for parameters with a single value. Setting returns the new
value.

### header

```perl
$table->header(0);
```

Whether the column titles are shown.

### scrollbar

```perl
$table->scrollbar(0);
```

Whether the scrollbar column is shown.

### hover

```perl
$table->hover(0);
```

Whether the line under the mouse pointer is highlighted.

### empty\_text

```perl
$table->empty_text('Nothing here yet');
```

The text of a table without rows.

### no\_match\_text

```perl
$table->no_match_text('Nothing found');
```

The text of a table whose rows all are filtered out.

### row\_id

```perl
$table->row_id('sku');
```

Where row ids come from (see ["Row ids" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#row-ids)). Setting it dies while the
table has rows.

## Widgets of the table

The table builds its widgets itself; these methods give access to them
for reading and testing. Do not add, remove or rearrange their
children.

### cell\_widget

```perl
my $widget = $table->cell_widget( $id, $key );
```

The widget a cell shows: the widget of the column's `cell` code, or a
[Term::Fabulous::Widget::Text](Text.md). `undef` when the row is not on the
current page, the column is hidden, or the table has not been drawn
since the row was added.

### body

The [Term::Fabulous::Widget::ScrollBox](ScrollBox.md) that holds the rows, with the
id `"$id/body"`.

### pager\_widget

The [Term::Fabulous::Widget::Table::Pager](Table/Pager.md), also while it is not
shown.

### model

The [Term::Fabulous::Widget::Table::Model](Table/Model.md) that holds the data and the
view. Read from it as you like, for example the lines of the view;
change the table only through the table's methods.

### prepare\_layout

Called by [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) once per frame, before the layout, when the table
changed (see [Clay::UI::Role::Core::Preparable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3APreparable)); it brings the
widgets up to date. You do not call it.

### layout\_properties

The table of the KDL properties (see ["KDL PROPERTIES"](#kdl-properties) and
["layout\_properties" in Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md#layout_properties)).

### apply\_layout\_node

Called by [Term::Fabulous::Layout](../Layout.md) when it builds a table from a KDL
node (see [Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md)). Dies for child
widget nodes. You do not call it.

### apply\_layout\_settings

Called by ["apply\_layout\_node"](#apply_layout_node) with the properties of the node. Applies
`row_id` and `children_key` first, then the columns, then the other
properties, and `sort` and `group_by` last. You do not call it.

# KEYS

The table uses these keys while it has the focus. Keys it does not use
bubble to its ancestors (see ["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard)), among
them `Tab`, which moves the focus on.

## On the rows

```text
Up, Down                 the previous or next line of the page
PageUp, PageDown         as many lines back or forward as the rows show, minus one,
                         so that one line stays in view (within the page)
Home, End                the first or last line of the page
Ctrl+Home, Ctrl+End      the first or last line of all pages
Ctrl+PageUp              the previous page (the cursor goes to its first line)
Ctrl+PageDown            the next page
Up on the first line     into the header (see below), when titles are shown
```

```text
Enter                    on a data row: fire RowActivate
                         on a group header: open or close the group
Space                    selection 'multiple': select or deselect the row
                         selection 'single': select the row
                         on a group header: open or close the group
Shift+Up, Shift+Down,    selection 'multiple': select the range from the line where the
Shift+PageUp/PageDown,   range started to the new cursor line
Shift+Home, Shift+End
Ctrl+A                   selection 'multiple': select every row that passes the filters,
                         or deselect them all when all of them are selected already
                         (selected rows hidden by a filter stay selected)
```

```text
Right, +                 open the tree row or group; on an open one, Right goes to the
                         first line inside it
Left, -                  close the tree row or group; on a closed one (or a row without
                         children), Left goes to the parent row or the group header above
```

With selection `'single'`, every move of the cursor onto a data row
also selects that row. A moving key fires `CursorMove` when the cursor
moves, then `PageChange` when the page changes, then
`SelectionChange` when the selection changes.

## In the header

`Up` on the first line of the page moves the keyboard into the row of
column titles; the title it is on is drawn in the `cursor_color`.

```text
Left, Right              the previous or next column title
Home, End                the first or last column title
Enter                    sort by this column alone: ascending, descending, unsorted
Space                    add this column to the sort, or cycle its direction
                         (Enter and Space do nothing on a column with sortable => 0)
Enter or Space on [ ]    the same as Ctrl+A on the rows
c                        open the column chooser
Down, Escape             back to the rows
```

## In the filter row

```text
Enter, Down              back to the rows
Escape                   empty the field (when it has text)
```

All other keys edit the text as in any [Term::Fabulous::Widget::TextField](TextField.md).
`Tab` and `Shift+Tab` move between the fields.

## In the column chooser

```text
Tab, Shift+Tab           the next or previous check box; Tab after the last one
                         leaves the chooser, which closes it
Space, Enter             show or hide the column
Escape                   close the chooser; the table gets the focus
```

## In a widget inside a cell

The widget gets the keys first. Movement keys it does not use move the
table's cursor and give the focus back to the table; `Enter` and
`Space` are left to the widget. See ["Keys and clicks in cell
widgets" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#keys-and-clicks-in-cell-widgets).

# MOUSE

- **Click on a row**: moves the cursor there (`CursorMove`). With
`selection => 'single'`, selects the row. With `'multiple'`, a
plain click selects only that row; `Ctrl`+click or `Alt`+click
selects or deselects it and keeps the others; `Shift`+click selects
the range from where the range started to that row; a click into the
selection column selects or deselects that row and keeps the others.
- **Double click on a row** (two clicks on the same line within
`double_click_seconds`): each click does what a click does (moves the
cursor, selects), then the second one fires `RowActivate`.
- **Click on a group header** or on the marker of a tree row: opens or
closes it (`Expand` or `Collapse`) and moves the cursor there.
- **Click on a column title**: sorts by it alone (ascending, descending,
unsorted). With `Shift`, `Ctrl` or `Alt`: adds it to the sort, or
cycles it within the sort. A click on the title of the selection column
does what `Ctrl+A` does on the rows (see ["Selection" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#selection)).
- **Right click on a column title**: opens the column chooser.
- **Click or drag on the scrollbar**: scrolls so that the thumb is
centered where the pointer is.
- **Wheel**: scrolls the rows up and down; a horizontal wheel scrolls them
sideways, and the titles follow.
- **Pointer over a row**: with `hover => 1`, the line under the
pointer is drawn in the `hover_color`.
- **Click on an input in a cell**: goes to the input; the table moves its
cursor to the row (with `selection => 'single'`, that selects it).
See ["Keys and clicks in cell widgets" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#keys-and-clicks-in-cell-widgets).

# EVENTS

The table fires these events on itself when the user acts; changes from
your program fire none. Listen with `$table->on( Name => sub ($event) { ... } )`.
Every event bubbles to the table's ancestors like all events (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table. Each event's page describes it in
full.

- `CursorMove`

    [Term::Fabulous::Event::CursorMove](../Event/CursorMove.md): the user moved the cursor.
    `$event->row_id` is the row it is on now, or `undef` on a group
    header, where `$event->group_path` is the group's path.

- `SelectionChange`

    [Term::Fabulous::Event::SelectionChange](../Event/SelectionChange.md): the user changed the
    selection. `$event->selected_ids`, `$event->added_ids` and
    `$event->removed_ids` are array references of row ids.

- `RowActivate`

    [Term::Fabulous::Event::RowActivate](../Event/RowActivate.md): `Enter` on a data row or a
    double click on it. `$event->row_id` and `$event->row` (a
    copy of its data).

- `SortChange`

    [Term::Fabulous::Event::SortChange](../Event/SortChange.md): the user changed the sort with a
    click or a key in the header. `$event->sort` is the new sort, like
    `sort_spec`.

- `FilterChange`

    [Term::Fabulous::Event::FilterChange](../Event/FilterChange.md): the user changed the text of a
    filter field. `$event->column`, `$event->text`, and
    `$event->error` (the reason the text is not a valid expression,
    else `undef`).

- `PageChange`

    [Term::Fabulous::Event::PageChange](../Event/PageChange.md): the user turned the page or
    changed the page size. `$event->page` and
    `$event->page_size`.

- `Expand`, `Collapse`

    [Term::Fabulous::Event::Expand](../Event/Expand.md) and
    [Term::Fabulous::Event::Collapse](../Event/Collapse.md): the user opened or closed a tree
    row (`$event->row_id`) or a group (`$event->group_path`; the
    other one is `undef`).

- `ColumnsChange`

    [Term::Fabulous::Event::ColumnsChange](../Event/ColumnsChange.md): the user showed or hid a
    column in the column chooser. `$event->visible` is the keys of the
    visible columns.

When one key or click causes several events, they come in this order:
`CursorMove`, `PageChange`, `SelectionChange`, then `RowActivate`,
`Expand` or `Collapse`.

To add keys of your own, listen for `KeyPress` (see
["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard)). A listener on the table itself
gets every key the table gets, also the ones the table uses (`Up`,
`Enter`, ...); it must return `Clay::UI::Enum::Result->CONTINUE`
for keys it does not use, or they stop at the table (`Tab` too, see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)). A listener on an
ancestor of the table gets only the keys the table does not use,
because the table stops the others from bubbling further.

# KDL PROPERTIES

A table can be part of a KDL layout (see
["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](../Manual/KDL.md#kdl-layout-files)). The layout describes the
table: its columns, sort, grouping, lines, colors and options. The rows,
everything that is a code reference (mutators, cell widgets,
callbacks), the style hashes `header_style` and `group_style` of the
table, and `double_click_seconds` come from Perl.

```kdl
use Term::Fabulous::Widget::Table as Table

Table "inventory" {
        sizing width=grow height=grow
        selection multiple
        row_id "sku"
        page_size 25
        page_sizes 25 50 100
        filter_row #true
        stripe_color "#1c2029"
        lines frame=Round columns=Solid rows=none header=Heavy color="#5c6370"
        cell_padding left=1 right=1

        column "sku" title="SKU" width="fixed(10)"
        column "name" title="Name" width=grow compare=natural
        column "qty" title="Qty" type=number {
                style text_color="#e5c07b" border_left=Heavy
                header_style text_color="#e5c07b"
        }
        column "updated" title="Updated" type=date visible=#false
        column "category" title="Category"

        sort "qty" "desc"
        sort "name"
        group_by "category"
}

use Term::Fabulous::Layout;
use Term::Fabulous::Widget::Table::Mutator qw(date);

my $root  = Term::Fabulous::Layout->new( file => 'inventory.kdl' )->build;
my $table = $root->find_by_id('inventory');    # here the root itself
$table->rows( \@items );
$table->update_column( updated => mutator => date() );
```

The properties:

- `column "key" ...`

    A column, with the key as its argument. Properties: `title`, `type`,
    `width`, `align`, `header_align`, `wrap`, `sortable`,
    `filterable`, `filter_on`, `compare` (not a code reference) and
    `visible`, with the values of the column parameters. Inside its block,
    an optional `style` node with the keys of a style hash of the
    _column_ kind (`text_color`, `background_color`, `bold`, `italic`,
    `underline`, `border_color`, `border_left`, `border_right`,
    `row_lines`), and an optional `header_style` node with the keys of
    the _header_ kind (the first six of these); see
    ["Style keys" in Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md#style-keys). Repeat `column` for
    every column, in order. The other column parameters (`value`,
    `mutator`, `cell`, ...) are code references; add them from Perl with
    ["update\_column"](#update_column), as below.

- `sort "key" ["asc" or "desc"]`

    Adds a column to the sort; the direction defaults to `asc`. Repeat it
    for a sort by several columns, the first one first.

- `group_by "key" ...`

    The group columns, outermost first.

- `lines frame=... top=... right=... bottom=... left=... columns=... rows=... header=... color=...`

    The lines: `frame` is the parameter `border`, `top` to `left` are
    `border_top` to `border_left`, `columns` is `column_lines`, `rows`
    is `row_lines`, `header` is `header_line`, `color` is
    `line_color`. Each takes a line style name or `none`. Every key is
    optional.

- `cell_padding N`, `cell_padding left=... right=... top=... bottom=...`

    The `cell_padding` parameter.

- `page_sizes N N ...`

    The `page_sizes` parameter.

- `selection`, `selection_column`, `page_size`, `pager`, `filter_row`, `header`, `scrollbar`, `hover`, `row_id`, `children_key`, `tree_expanded`, `tree_column`, `empty_text`, `no_match_text`

    The parameters of the same names, with one value each (booleans as
    `#true` and `#false`; `row_id` only as a key).

- `text_color`, `header_text_color`, `header_background_color`, `group_text_color`, `group_background_color`, `cursor_color`, `selected_color`, `hover_color`, `filter_background_color`, `error_color`, `muted_color`, `line_color`, `stripe_color`

    The colors of the parameters of the same names, in any of the
    [color forms of a layout file](../Manual/KDL.md#colors).

- the properties of a Box

    `sizing`, `background_color` and the other
    [KDL properties of a Box](Box.md#kdl-properties). Note that a Box's
    `border` property is the Box border around the whole widget, not the
    table's frame; the frame is `lines frame=...`.

`row_id` and `children_key` are applied first, then the columns, then
the other properties, and `sort` and `group_by` last, wherever they
stand in the block. A table takes no child widget nodes; one dies.

# PERFORMANCE

[Term::Fabulous](../../../../README.md) lays out every widget of the screen in every frame
that changed, and a table makes about two widgets per cell. What costs
time is therefore the number of cells **shown**, not the number of rows:

- Up to a few hundred rows, a table without pages responds at once.
- For more rows, use `page_size`. With pages, only the cells of one page
are widgets, and a table of 10,000 rows with pages of 50 lines answers a
key press in a few hundredths of a second. Sorting or filtering 10,000
rows takes a few tenths of a second the first time; the table keeps the
display texts, so later searches are fast.
- A table without pages builds widgets for all its rows, about two per
cell. A [Term::Fabulous](../../../../README.md) program fits about 8,190 widgets on the
screen by default (`max_element_count` 8192), so a table of 5 columns
without pages reaches the limit at about 750 rows and then dies when it
is drawn. Raise `max_element_count` (see ["new" in Term::Fabulous](../../../../README.md#new)) or,
better, use pages: with a limit high enough, 1,000 rows of 5 columns
without pages take about half a second per key press. The same limit
applies to a large page of many columns.
- Custom `compare` functions are called for every comparison of a sort;
named comparisons compute one key per row. Mutators and `value` code
run once per cell and row change.

# CAVEATS

- A table needs an `id`, and uses `"$id/body"` as the id of its body.
- A table takes no child widgets: its cells come from its columns and
rows. Do not call `add_child` on it, and do not change its `layout`
other than its `sizing`.
- Cell widgets can be replaced by new ones at any time (see ["When cell
widgets are built" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#when-cell-widgets-are-built)). Keep state in the row data.
- The cursor is drawn only while the table has the focus.
- Changes from your program fire no events. If a listener also has to
run for them, call it yourself.
- Many terminals keep `Shift`+click for selecting text on the screen and
do not report it to programs; `Ctrl`+click and the keyboard work
there.

# SEE ALSO

[Term::Fabulous::Widget::Table::Column](Table/Column.md), [Term::Fabulous::Widget::Table::Mutator](Table/Mutator.md),
[Term::Fabulous::Widget::Table::Filter](Table/Filter.md), [Term::Fabulous::Widget::Table::Value](Table/Value.md),
[Term::Fabulous::Widget::Table::Model](Table/Model.md), [Term::Fabulous::Widget::Table::Style](Table/Style.md),
[Term::Fabulous::Widget::Table::Borders](Table/Borders.md), [Term::Fabulous::Widget::Table::Pager](Table/Pager.md),
[Term::Fabulous::Widget::Table::ColumnChooser](Table/ColumnChooser.md),
[Term::Fabulous::Manual::Tables](../Manual/Tables.md), [Term::Fabulous::Manual::TableRows](../Manual/TableRows.md),
[Term::Fabulous::Manual::TableStyles](../Manual/TableStyles.md), [Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md),
[Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md), [Term::Fabulous::Cookbook::TableStyles](../Cookbook/TableStyles.md),
[Term::Fabulous::Examples](../Examples.md).
