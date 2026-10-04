# NAME

Term::Fabulous::Event::SelectionChange - The user changed which rows of a table are selected

# SYNOPSIS

```perl
$table->on( SelectionChange => sub ($event) {
        my @ids = @{ $event->selected_ids };
        $status->text( @ids . ' selected' );
        say "now selected: $_" foreach @{ $event->added_ids };
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `SelectionChange` on itself
when the user changes which rows are selected.

With `selection => 'multiple'`: a click on a row (selects it
alone), a `Ctrl`- or `Alt`-click on a row or a click into the
selection column (toggle the row), a `Shift`-click or `Shift` with a
movement key (select the range from the anchor), `Space` (toggles the
cursor's row), `Ctrl+A`, and a click on the selection column's header
or `Enter` or `Space` on it in header mode (select every filtered row,
or none when all of them are selected).

With `selection => 'single'`: the cursor moving onto a row, a click
on a row, and `Space`.

It fires only when the selection changed, after the
[Term::Fabulous::Event::CursorMove](CursorMove.md) the same action causes. Changes
your program makes (`select`, `deselect`, `set_selection`, ...) fire
nothing, and neither do rows leaving the selection because they were
removed. Selection modes are explained in
["Selection" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#selection).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `SelectionChange`;
listen for it with
`$table->on( SelectionChange => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::SelectionChange->new( selected_ids => ..., added_ids => ..., removed_ids => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. Unknown parameters die, and so does a `selected_ids`,
`added_ids` or `removed_ids` that is missing or not an array
reference; they are copied.

- `selected_ids`

    See ["selected\_ids"](#selected_ids).

- `added_ids`

    See ["added\_ids"](#added_ids).

- `removed_ids`

    See ["removed\_ids"](#removed_ids).

# METHODS

## selected\_ids

The ids of all selected rows after the change, in the order of the data
(a new array reference).

## added\_ids

The ids that were selected by this change (a new array reference).

## removed\_ids

The ids that were deselected by this change (a new array reference).

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Show a list of hashes in a table (sort, select, open a row)" in Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row).
