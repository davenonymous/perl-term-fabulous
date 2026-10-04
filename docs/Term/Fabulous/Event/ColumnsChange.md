# NAME

Term::Fabulous::Event::ColumnsChange - The user chose which columns of a table are shown

# SYNOPSIS

```perl
$table->on( ColumnsChange => sub ($event) {
        save_setting( columns => join ',', @{ $event->visible } );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `ColumnsChange` on itself each
time the user shows or hides a column in its column chooser (see
["open\_column\_chooser" in Term::Fabulous::Widget::Table](../Widget/Table.md#open_column_chooser)).
The methods [show\_columns](../Widget/Table.md#show_columns) and its relatives fire
nothing. The column chooser is explained in
[the column chooser section of the tables guide](../Manual/Tables.md#choosing-the-visible-columns).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `ColumnsChange`;
listen for it with
`$table->on( ColumnsChange => sub ($event) { ... } )`. It bubbles
to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::ColumnsChange->new( visible => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. `visible` is required and must be an array reference;
it is copied. Unknown parameters die.

- `visible`

    See ["visible"](#visible).

# METHODS

## visible

The keys of the visible columns, in their order (a new array
reference).

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Choosing the visible columns" in Term::Fabulous::Manual::Tables](../Manual/Tables.md#choosing-the-visible-columns),
["Let the user choose the visible columns (column chooser)" in Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md#let-the-user-choose-the-visible-columns-column-chooser).
