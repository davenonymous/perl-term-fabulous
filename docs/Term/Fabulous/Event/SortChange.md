# NAME

Term::Fabulous::Event::SortChange - The user changed how a table is sorted

# SYNOPSIS

```perl
$table->on( SortChange => sub ($event) {
        my @keys = map { "$_->[0] ($_->[1])" } @{ $event->sort };
        $status->text( @keys ? "sorted by @keys" : 'unsorted' );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `SortChange` on itself when
the user sorts it by a `sortable` column: a click on the column's
header (with `Shift`, `Ctrl` or `Alt` it adds the column to the
sort), or `Enter` or `Space` on the header in header mode (see
["KEYS" in Term::Fabulous::Widget::Table](../Widget/Table.md#keys)). Each of these cycles the column
from ascending to descending to unsorted. A column with
`sortable => 0` ignores them and fires nothing. Sorting from your program
(["sort\_by" in Term::Fabulous::Widget::Table](../Widget/Table.md#sort_by), `clear_sort`) fires nothing.
Sorting is explained in ["SORTING" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#sorting).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `SortChange`; listen
for it with `$table->on( SortChange => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::SortChange->new( sort => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. Unknown parameters die, and so does a `sort` that is
not an array reference of array references; it is copied.

- `sort`

    See ["sort"](#sort).

# METHODS

## sort

The new sort: a new array reference of
`[ $column_key, 'asc' or 'desc' ]` pairs, the first one sorting first;
empty when the table is unsorted.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Sort rows, also with your own comparison" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#sort-rows-also-with-your-own-comparison).
