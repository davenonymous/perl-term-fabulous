# NAME

Term::Fabulous::ThemeEditor::SettingsList - The table of settings in
the theme editor's form

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A tree of rows in sections, each row showing a swatch, the
setting (indented, sections with a marker), its value and where the
value comes from, under a row of titles. Only the rows near the
viewport are widgets, inside a [Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md),
so the list costs the same with every section open. The rows are
painted in the colors of the theme's `table` family: the cursor in
`table.cursor` (`table.selected` while the list does not have the
focus), the row under the pointer in `table.hover`, sections in
`table.group.text` on `table.group.background`, settings the theme
does not set in `table.muted`. A text too long for its column ends in
`~`; the columns keep their places whatever the list shows.

Keys while the list has the focus: `Up`, `Down`, `PageUp`,
`PageDown`, `Home`, `End` move the cursor; `Right` or `+` opens a
section (on an open one, `Right` goes to its first row); `Left` or
`-` closes a section, or goes to the section above a row; `Enter` or
`Space` opens or closes a section and edits a setting. A click puts
the cursor on a row, a click on a section's marker opens or closes it,
a double click activates a row, the wheel scrolls.

# CONSTRUCTOR

## new

```perl
my $list = Term::Fabulous::ThemeEditor::SettingsList->new(
        id          => 'settings',
        on_activate => sub ($id) { ... },    # Enter or a double click on a setting
        on_cursor   => sub ($id) { ... },    # the cursor moved
);
```

# METHODS

## rows

Replaces all rows: hashes with `id`, `setting`, `value`, `origin`,
`swatch` (glyphs), `color` (the swatch's color), `set`, and for a
section `section => 1` with its rows under `children`.

## row, has\_row, row\_ids, parent\_of, children\_of, update\_row, refresh

Reading the rows, changing one's texts, and showing the rows again
after such changes (a search or a filter may take other rows then).

## expand, collapse, toggle, expand\_all, collapse\_all, is\_expanded

Opening and closing sections.

## search, filter, filtered\_row\_ids

The search text (rows whose texts hold it, in any case, with their
sections), named filters (code that gets a row), and the ids of the
rows shown.

## cursor, cursor\_index

The row under the cursor; setting it opens the sections above the row
and scrolls it into view, and dies for a row a search or a filter
hides.

## activate, click, hover

What `Enter`, a click and the pointer do to a row.
`click( $index, $column, $click_count )` takes the click's place in
a run of quick clicks
(["click\_count" in Term::Fabulous::Event::Mouse](../Event/Mouse.md#click_count), default 1); the second
click of a double click on the same row activates it.

## shown\_count, shown\_row, hover\_index, value\_columns

What the rows paint from.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md), [Term::Fabulous::ThemeEditor::Form](Form.md),
[Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md).
