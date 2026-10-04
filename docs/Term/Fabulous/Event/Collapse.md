# NAME

Term::Fabulous::Event::Collapse - The user closed a row or a group of a table

# SYNOPSIS

```perl
$table->on( Collapse => sub ($event) {
        say 'closed ', defined $event->row_id ? 'row ' . $event->row_id : "group @{ $event->group_path }";
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `Collapse` on itself when the
user closes an open tree row (hiding its children) or an open group:
with a click on the marker in front of it or, for a group, anywhere on
its header; with `Left` or `-` on it; or with `Enter` or `Space` on
a group header. A click fires it after the
[Term::Fabulous::Event::CursorMove](CursorMove.md) the click causes.

Closing from your program (`collapse`, `collapse_all`,
`collapse_group`, `collapse_all_groups`) fires nothing. Its
counterpart is [Term::Fabulous::Event::Expand](Expand.md). Groups and trees are
explained in ["Opening and closing groups" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#opening-and-closing-groups)
and ["Opening and closing tree rows" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#opening-and-closing-tree-rows).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Collapse`; listen
for it with `$table->on( Collapse => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Collapse->new( row_id => ..., group_path => ... );
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

The id of the row that was closed, or `undef` for a group.

## group\_path

For a group, the values of the group and of the groups around it,
outermost first (a new array reference); `undef` for a row.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Group rows by a column (collapsible group headers)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#group-rows-by-a-column-collapsible-group-headers),
["Show nested data as a tree (expand and collapse rows)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#show-nested-data-as-a-tree-expand-and-collapse-rows).
