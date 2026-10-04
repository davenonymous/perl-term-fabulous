# NAME

Term::Fabulous::Event::FilterChange - The user typed into a filter field of a table

# SYNOPSIS

```perl
$table->on( FilterChange => sub ($event) {
        $status->text( $event->error // sprintf '%d of %d rows', scalar $table->filtered_row_ids, $table->row_count );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `FilterChange` on itself when
the user changes the text of a field in its filter row (see
["filter\_row" in Term::Fabulous::Widget::Table](../Widget/Table.md#filter_row)), by typing or by clearing
a non-empty field with `Escape`, after the table has applied the text.
A text that is not a valid filter expression leaves the column
unfiltered and is shown in the `error_color`; `error` says why.
Setting filters from your program (`filter`, `filter_text`,
`search`, ...) fires nothing. The filter row and its expressions are
explained in ["The filter row" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#the-filter-row).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `FilterChange`;
listen for it with
`$table->on( FilterChange => sub ($event) { ... } )`. It bubbles
to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::FilterChange->new( column => ..., text => ..., error => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. Unknown parameters die, and so does a missing `column`
or `text`.

- `column`

    See ["column"](#column).

- `text`

    See ["text"](#text).

- `error`

    See ["error"](#error).

# METHODS

## column

The key of the column whose field changed.

## text

The text of the field.

## error

`undef` when the text is a valid filter expression (or empty),
otherwise why it is not one, for example
`'abc' is not a number filter (use 5, >5, >=5, <5, <=5, !=5 or 5..10)`.
The same message is available as
`$table->filter_error($column)`.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Let the user filter rows (filter row and search box)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#let-the-user-filter-rows-filter-row-and-search-box).
