# NAME

Term::Fabulous::Event::RowActivate - The user activated a row of a table

# SYNOPSIS

```perl
$table->on( RowActivate => sub ($event) {
        open_document( $event->row->{path} );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `RowActivate` on itself when
the user presses `Enter` on a row or double-clicks it: the action that
opens or edits the row. `Enter` on a group header opens or closes the
group instead. `Enter` pressed in a widget inside a cell (a button, a
text field) and a double click on such a widget are left to that
widget and fire no `RowActivate`.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `RowActivate`; listen
for it with `$table->on( RowActivate => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::RowActivate->new( row_id => ..., row => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. `row` is required. Unknown parameters die, and so do
array and hash parameters of the wrong kind; they are copied.

- `row_id`

    See ["row\_id"](#row_id).

- `row`

    See ["row"](#row).

# METHODS

## row\_id

The id of the row.

## row

A copy of the row's data (a new hash reference).

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Show a list of hashes in a table (sort, select, open a row)" in Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row).
