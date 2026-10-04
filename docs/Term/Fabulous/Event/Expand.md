# NAME

Term::Fabulous::Event::Expand - The user opened a row or a group of a table

# SYNOPSIS

```perl
$tree->on( Expand => sub ($event) {
        my $id = $event->row_id // return;    # a group was opened
        $status->text( scalar( $tree->children_of($id) ) . ' entries in ' . $tree->row($id)->{name} );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `Expand` on itself when the
user opens a tree row that has children (showing them) or a collapsed
group: with a click on the marker in front of it or, for a group,
anywhere on its header; with `Right` or `+` on it; or with `Enter`
or `Space` on a group header. A click fires it after the
[Term::Fabulous::Event::CursorMove](CursorMove.md) the click causes.

Opening from your program (`expand`, `expand_all`, `expand_group`,
`expand_all_groups`) fires nothing, and neither does the table opening
rows to show what a filter found. Its counterpart is
[Term::Fabulous::Event::Collapse](Collapse.md). Groups and trees are explained in
["Opening and closing groups" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#opening-and-closing-groups) and
["Opening and closing tree rows" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#opening-and-closing-tree-rows).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Expand`; listen for
it with `$table->on( Expand => sub ($event) { ... } )`. It bubbles
to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Expand->new( row_id => ..., group_path => ... );
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

The id of the row that was opened, or `undef` for a group.

## group\_path

For a group, the values of the group and of the groups around it,
outermost first (a new array reference); `undef` for a row.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Show nested data as a tree (expand and collapse rows)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#show-nested-data-as-a-tree-expand-and-collapse-rows),
["Group rows by a column (collapsible group headers)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#group-rows-by-a-column-collapsible-group-headers).
