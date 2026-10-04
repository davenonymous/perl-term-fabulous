# NAME

Term::Fabulous::Event::CursorMove - The cursor of a table moved to another line

# SYNOPSIS

```perl
$table->on( CursorMove => sub ($event) {
        my $id = $event->row_id // return;    # undef on a group header
        $details->text( describe( $table->row($id) ) );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `CursorMove` on itself when
the user moves its cursor (the highlighted line keyboard commands act
on) to another line: with `Up`, `Down`, `PageUp`, `PageDown`,
`Home` or `End` (also with `Shift` in a table with
`selection => 'multiple'`), with `Ctrl+Home` or `Ctrl+End`, with
`Left` or `Right` in a tree or in groups (to the parent row, the first
child or the group header), with a click on a row, a group header or
a marker, or by turning the page (`Ctrl+PageUp`, `Ctrl+PageDown`, the
pager), which puts the cursor on the first line of the new page.

Moving the cursor from your program
(["cursor" in Term::Fabulous::Widget::Table](../Widget/Table.md#cursor),
["page" in Term::Fabulous::Widget::Table](../Widget/Table.md#page)) fires nothing, and neither does
the cursor moving because its line left the view (filtered out, below
a collapsed row or group, removed).

It fires before the [Term::Fabulous::Event::SelectionChange](SelectionChange.md), the
[Term::Fabulous::Event::PageChange](PageChange.md) and the
[Term::Fabulous::Event::Expand](Expand.md) or [Term::Fabulous::Event::Collapse](Collapse.md)
the same action causes. The cursor is explained in
["The cursor" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#the-cursor).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `CursorMove`; listen
for it with `$table->on( CursorMove => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::CursorMove->new( row_id => ..., group_path => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. Unknown parameters die, and so does a `group_path`
that is not `undef` or an array reference; it is copied.

- `row_id`

    See ["row\_id"](#row_id).

- `group_path`

    See ["group\_path"](#group_path).

# METHODS

## row\_id

The id of the row the cursor is on now, or `undef` when it is on a
group header.

## group\_path

On a group header, the values of the group and of the groups around it,
outermost first (a new array reference); `undef` on a row.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Show a list of hashes in a table (sort, select, open a row)" in Term::Fabulous::Cookbook::Tables](../Cookbook/Tables.md#show-a-list-of-hashes-in-a-table-sort-select-open-a-row).
