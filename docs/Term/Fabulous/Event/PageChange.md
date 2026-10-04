# NAME

Term::Fabulous::Event::PageChange - The user turned the page of a table or changed its page size

# SYNOPSIS

```perl
$table->on( PageChange => sub ($event) {
        load_more() if $event->page == $table->page_count;
        return;
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Widget/Table.md) fires `PageChange` on itself when
the user turns to another page: with the buttons of its pager,
`Ctrl+PageUp` or `Ctrl+PageDown`, or `Ctrl+Home` or `Ctrl+End`
when the first or the last line is on another page. It also fires when
the user chooses another page size in the pager, even when the page
number stays the same.

Changing the page or the page size from your program
(["page" in Term::Fabulous::Widget::Table](../Widget/Table.md#page), `next_page`,
`previous_page`, ["page\_size" in Term::Fabulous::Widget::Table](../Widget/Table.md#page_size)) fires
nothing, and neither does the page following the cursor after the view
changed (a filter, a sort, rows added or removed). Pages are explained
in ["PAGES" in Term::Fabulous::Manual::TableRows](../Manual/TableRows.md#pages).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `PageChange`; listen
for it with `$table->on( PageChange => sub ($event) { ... } )`. It
bubbles to the table's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the table.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::PageChange->new( page => ..., page_size => ... );
```

The table builds these events itself; build one yourself only to test
your listeners. Unknown parameters die, and so does a missing `page`
or `page_size`.

- `page`

    See ["page"](#page).

- `page_size`

    See ["page\_size"](#page_size).

# METHODS

## page

The page shown now, counted from 1.

## page\_size

The number of lines per page (0: no pages).

# SEE ALSO

[Term::Fabulous::Widget::Table](../Widget/Table.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Split many rows into pages (pager and page sizes)" in Term::Fabulous::Cookbook::TableRows](../Cookbook/TableRows.md#split-many-rows-into-pages-pager-and-page-sizes).
