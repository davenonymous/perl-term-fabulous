# NAME

Term::Fabulous::Widget::Table::Column - What a table column shows and how

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table;
use Term::Fabulous::Widget::Table::Mutator qw(datetime number);

my $table = Term::Fabulous::Widget::Table->new(
        id      => 'orders',
        columns => [
                { key => 'id',      title => '#',        type => 'number', width => 'fixed(6)' },
                { key => 'client',  title => 'Client',   width => 'grow', compare => 'natural' },
                { key => 'placed',  title => 'Placed',   type => 'date', mutator => datetime('%d %b %H:%M') },
                { key => 'total',   title => 'Total',    type => 'number', mutator => number( decimals => 2 ),
                  cell_style => sub ($cell) { $cell->{value} < 0 ? { text_color => '#e06c75' } : {} } },
                { key => 'items',   title => 'Items',    value => sub ($row) { scalar @{ $row->{lines} } }, type => 'number' },
                { key => 'note',    title => 'Note',     width => 'fit(0, 30)', sortable => 0, visible => 0 },
        ],
);

# Columns are values: change one by making a new one.
$table->update_column( total => title => 'Sum' );
my $column = $table->column('placed');
say $column->title, ' is a ', $column->type, ' column';
```

# DESCRIPTION

A column of a [Term::Fabulous::Widget::Table](../Table.md) decides, for every row,
which value is the cell's _raw value_, what text it shows, how it is
aligned, sized, sorted and filtered, and which widget shows it. You
describe columns as hash references in the table's `columns` parameter
(or to ["add\_column" in Term::Fabulous::Widget::Table](../Table.md#add_column)); the table makes a
Column object of each. A Column is immutable: to change one, use
["update\_column" in Term::Fabulous::Widget::Table](../Table.md#update_column), which builds a new one
with ["with"](#with). Which columns are visible is decided by the table (see
["Choosing the visible columns" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#choosing-the-visible-columns));
`visible` is only where a new column starts.

In a KDL layout file, a column is a `column` node inside the table's
node; see ["KDL PROPERTIES" in Term::Fabulous::Widget::Table](../Table.md#kdl-properties).

## Values, display text and cells

For every row the column computes:

- the raw value

    `$column->value_of($row)`: what the `value` code reference
    returns for the row's data, or the row's entry under the column key.
    Sorting uses it, and so do filters unless they say otherwise.

- the display text

    The raw value after every `mutator`, as a string (`undef` becomes
    `''`). This is what the cell shows, and what filters with
    `on => 'display'` and the table's search compare.

- the cell widget

    A [Term::Fabulous::Widget::Text](../Text.md) with the display text, aligned,
    wrapped and colored as the column and the styles say; or, with a
    `cell` code reference, any widget it returns.

# PARAMETERS

All parameters but `key` are optional; unknown parameters and invalid
values die.

- `key`

    Required. A non-empty string that names the column, unique in its
    table. It is also where the raw value comes from when there is no
    `value`.

- `title`

    The text of the header cell, also shown in the column chooser (where an
    empty title shows the key instead). Default: the key.

- `type`

    `'string'` (the default), `'number'` or `'date'`. It decides the
    default alignment, the default comparator and how filters compare the
    column's cells (see ["What a
    condition compares" in Term::Fabulous::Widget::Table::Filter](Filter.md#what-a-condition-compares)). Date values may be epoch seconds, date strings
    such as `'2024-05-03 14:30'`, or objects with an `epoch` method (see
    ["date\_epoch" in Term::Fabulous::Widget::Table::Value](Value.md#date_epoch)).

- `value`

    A code reference `sub ($row) { ... }` that returns the raw value
    from a copy of the row's data, for computed columns. Default: the row's
    entry under `key`.

- `mutator`

    A code reference `sub ( $value, $row ) { ... }`, or an array
    reference of them, that turns the raw value into the display text; the
    mutators run in order, each on the result of the one before. See
    [Term::Fabulous::Widget::Table::Mutator](Mutator.md) for ready-made ones (dates,
    numbers, sizes, ...). Default: none, the raw value is shown as it is.

- `align`

    `'left'`, `'center'` or `'right'`: where the content sits in the
    cell. Default: `'right'` for number columns, `'left'` otherwise.

- `header_align`

    The same for the header cell. Default: `align`.

- `width`

    How wide the column is, as a sizing string or a hash from the
    `sizing_*` functions of [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) (see
    ["sizing" in Term::Fabulous::Check](../../Check.md#sizing)):

    ```text
    'fit'           as wide as its widest cell (the default)
    'fit(8)'        at least 8 columns
    'fit(0, 30)'    at most 30 columns; longer text wraps
    'fixed(12)'     exactly 12 columns; longer text wraps
    'grow'          takes a share of the room the table has left over
    'grow(10, 40)'  the same, between 10 and 40 columns
    'percent(25)'   a quarter of the table's width
    ```

    The width includes the cell padding. Header cells, the filter field
    and every cell of the column are sized together, so the column is as
    wide as the widest of them (within the limits). A `grow` or
    `percent` column needs a table with a width of its own; see
    ["Column widths" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#column-widths).

- `wrap`

    `'words'` (the default), `'newlines'` or `'none'`: how the text of
    a default cell breaks into lines when the column is narrower than the
    text (see ["wrap\_mode" in Term::Fabulous::Widget::Text](../Text.md#wrap_mode)). Rows grow to the
    height of their tallest cell.

- `sortable`

    A boolean, default 1: whether the user may sort by the column (clicking
    its header). The table's [`sort_by`](../Table.md#sort_by)
    method still sorts by any column.

- `compare`

    How two raw values are ordered: `'string'` (case-insensitive),
    `'natural'` (digit runs as numbers: _file9_ before _file10_),
    `'number'` or `'date'` - with these, values that cannot be read
    (blank cells, words in a number column) sort last in both directions -
    or a code reference `sub ( $a, $b, $row_a, $row_b ) { ... }`
    returning a negative number, 0 or a positive number for ascending order
    (the table reverses it for descending order; it sees every value,
    blank ones included). Default: the column's `type`.

- `filterable`

    A boolean, default 1: whether the table's filter row has a field for
    the column.

- `filter_on`

    `'display'` or `'value'`: what the filter row's expression for this
    column compares. Default: `'display'` for string columns (users type
    what they see), `'value'` for number and date columns.

- `cell`

    A code reference `sub ($cell) { ... }` that returns the widget
    shown in a cell, any widget (a Box with several children, a Button, a
    Checkbox, a PixelCanvas). `$cell` is a hash reference with the keys
    `value` (the raw value), `display` (the display text), `row` (a copy
    of the row's data), `id` (the row's id), `column` (this Column) and
    `table`. The table builds the widget when the row first shows and
    again when the row's data or the column changes, unless there is an
    `update_cell`. Default: a Text widget.

- `update_cell`

    A code reference `sub ( $widget, $cell ) { ... }` that brings a
    widget `cell` made up to date with new data, instead of building a new
    one. Use it for input widgets, so that the focus and what the user is
    typing survive a change of the row (for example one the input itself
    made). Only with `cell`.

- `header`

    A code reference `sub ($column) { ... }` that returns the widget
    of the header cell, in place of the title. The sort marker still
    follows it. Default: the title in bold. See
    ["Widgets as column titles" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#widgets-as-column-titles).

- `cell_style`

    A code reference `sub ($cell) { ... }`, called with the same hash
    as `cell`, that returns a style hash (or `undef`) for the cell:
    conditional formatting such as red negative numbers. See
    ["STYLES AND BORDERS" in Term::Fabulous::Manual::TableStyles](../../Manual/TableStyles.md#styles-and-borders).

- `style`

    A style hash for every cell of the column: `text_color`,
    `background_color`, `bold`, `italic`, `underline`, `border_color`
    and the lines `border_left`, `border_right` and `row_lines` (between
    the cells of the column).

- `header_style`

    A style hash for the column's header cell: `text_color`,
    `background_color`, `bold`, `italic`, `underline`,
    `border_color`.

- `visible`

    A boolean, default 1: whether the column is shown when it is added to
    the table.

# METHODS

The parameters have readers of the same names: `key`, `title`,
`type`, `align`, `header_align`, `wrap`, `sortable`,
`filterable`, `filter_on`, `cell`, `update_cell`, `header`,
`cell_style`, `visible`; `width`, `style` and `header_style`
return copies, `mutators` the list of mutators.

## value\_of

```perl
my $raw = $column->value_of($row);
```

The raw value of the column in a row's data.

## display\_of

```perl
my $text = $column->display_of( $raw, $row );
```

The display text of a raw value: the value after the mutators, as a
string.

## has\_mutators

1 if the column has at least one `mutator`, 0 otherwise; without one,
the display text is the raw value as a string.

## computes\_value

1 if the column has a `value` code reference, 0 if the raw value is the
row's entry under the column key.

## order

```perl
my $order = $column->order( $left, $right, $left_row, $right_row, $direction );
```

Orders two raw values for a sort in `$direction` (1 ascending, -1
descending); used by the table.

## has\_custom\_compare

1 if `compare` is a code reference, 0 for a named comparator
(`'string'`, `'natural'`, `'number'` or `'date'`).

## sorts\_numerically

1 if the named comparator is `'number'` or `'date'`, so that
["sort\_key"](#sort_key) returns numbers; 0 for `'string'`, `'natural'` and a
code reference.

## sort\_key

```perl
my $key = $column->sort_key($raw);
```

What the named comparator orders a raw value by: the number for
`'number'`, the epoch seconds for `'date'`, the case-folded text for
`'string'`, and for `'natural'` the case-folded text with every run of
digits written as its length (five digits) followed by the digits
without leading zeros. Keys compare with `<=>` when
["sorts\_numerically"](#sorts_numerically) is 1 and with `cmp` otherwise, in the order the
comparator gives. Returns `undef` for a value the comparator cannot
read (blank, or not a number or a date); the table sorts these last.
Dies for a column whose `compare` is a code reference.

## with

```perl
my $renamed = $column->with( title => 'Sum' );
```

A new column made with the parameters of this one and the changes.

## params

The parameters the column was made with, as a list of pairs.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md), [Term::Fabulous::Widget::Table::Mutator](Mutator.md),
[Term::Fabulous::Widget::Table::Filter](Filter.md), ["COLUMNS" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#columns),
["Size, align and wrap columns (widths, wrapping, widget titles)" in Term::Fabulous::Cookbook::TableStyles](../../Cookbook/TableStyles.md#size-align-and-wrap-columns-widths-wrapping-widget-titles).
