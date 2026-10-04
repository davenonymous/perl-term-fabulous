# NAME

Term::Fabulous::Manual::Troubleshooting - Solutions to common problems

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md). Next page: [Term::Fabulous::Manual::Glossary](Glossary.md).

This page lists common problems, each under a heading that describes
the symptom or quotes the error message, with the cause and the
solution. When a program dies, search this page for the start of its
message. The limits of Term::Fabulous itself are listed under
[LIMITATIONS](../../../../README.md#limitations) on the main page.

# TROUBLESHOOTING

## "tb\_init failed: No such device or address"

[`$ui->run`](../../../../README.md#run) needs a terminal: the process has no controlling
terminal, for example in a cron job, a service or a CI run. Print the
widget tree as text with [Term::Fabulous::Static](../Static.md) there instead (see
["RENDERING WITHOUT A TERMINAL" in Term::Fabulous::Manual::Programs](Programs.md#rendering-without-a-terminal)), and
test programs with [Term::Fabulous::Terminal::Memory](../Terminal/Memory.md) (see
["TESTING" in Term::Fabulous::Manual::Programs](Programs.md#testing)).

## "the terminal did not report its cursor position"

[Inline mode](../../../../README.md#inline-mode) asks the terminal where its
cursor is (`ESC [ 6 n`) and waits a second for the answer. The
terminal, or a program between it and yours, does not answer. Use a
terminal that does (xterm-compatible terminals and tmux do), or run in
full-screen mode.

## "the locale's character set is not UTF-8"

[`$ui->run`](../../../../README.md#run) warns when the locale is not UTF-8, because
wide characters are then misaligned. See
["Wide characters (CJK, emoji) shift the rest of the line"](#wide-characters-cjk-emoji-shift-the-rest-of-the-line).

## My text does not show (invisible text)

The default `text_color` of a Text widget is opaque black, which is
invisible on a dark background. Always pass a `text_color`, or
`[0, 0, 0, 0]` for the terminal's default text color. See ["TEXT" in Term::Fabulous::Manual::Looks](Looks.md#text).

## "the widget tree has more elements than max\_element\_count (8192) allows"

The widget tree is too large for Clay's element table: by default at
most 8190 widgets fit in a frame. Pass a larger `max_element_count` to
`Term::Fabulous->new`, or show fewer widgets at a time, for example
by building only the visible part of a long list, or by drawing many
small items on a canvas instead. See ["new" in Term::Fabulous](../../../../README.md#new).

## A table shows no cursor

The cursor of a [Term::Fabulous::Widget::Table](../Widget/Table.md) is drawn only while the
table, or a widget in one of its cells, has the keyboard focus. Give it
the focus with `Tab`, a click, or
`$ui->interaction->set_focused_widget($table)`. See
["The cursor" in Term::Fabulous::Manual::TableRows](TableRows.md#the-cursor).

## "a table needs an id"

[Term::Fabulous::Widget::Table](../Widget/Table.md) dies with
`Term::Fabulous::Widget::Table: a table needs an id (its body keeps its scroll position by it)`
when it is made without an `id`. Give every table an `id` that is
unique in the widget tree, for example
`Term::Fabulous::Widget::Table->new( id => 'staff', ... )`.
See ["TABLES" in Term::Fabulous::Manual::Tables](Tables.md#tables).

## Garbled characters in a Text widget, input, canvas or KDL layout

All of these take character strings. If your source code contains
non-ASCII characters, add `use utf8;`. If the text comes from a file,
a command or `@ARGV`, decode it first (`decode('UTF-8', $bytes)`); see
["Text is character strings" in Term::Fabulous::Manual::Looks](Looks.md#text-is-character-strings).

## Wide characters (CJK, emoji) shift the rest of the line

The locale is not UTF-8 (`run` warns about it), or the terminal
disagrees with the C library about the character's width. Set a UTF-8
locale, for example `export LANG=C.UTF-8` (`locale -a` lists the
installed locales).

## Colors are wrong or look washed out

The terminal does not support 24-bit colors. Use a terminal that does;
inside tmux, enable truecolor (`set -as terminal-features ",*:RGB"`).

## A KeyPress listener on the root never sees some keys

The focused widget used them, or one of its listeners (or one on a widget
between it and the root) did not return
`Clay::UI::Enum::Result->CONTINUE`. See
["Return values and bubbling" in Term::Fabulous::Manual::Events](Events.md#return-values-and-bubbling).

## A Mouse listener never fires

The widget draws nothing at the clicked cell (no background color, no
border), so the click goes to the widget behind it, or it is a Text
widget. Give the box a background color, or listen on an ancestor.

## Hover effects do not follow the mouse

The terminal does not report mouse movement (mode 1003), or a terminal
multiplexer between it and the program drops the reports. Clicks, drags
and the wheel still work. See ["What the terminal reports" in Term::Fabulous::Manual::Events](Events.md#what-the-terminal-reports).

## A change from a timer does not show

Term::Fabulous draws a frame only when it knows that something changed.
The widget methods tell it; state a widget of your own keeps itself does
not. Call `mark_changed` on the widget after changing it, or
`$ui->invalidate`. See
[Telling Term::Fabulous that something changed](CustomWidgets.md#telling-term-fabulous-that-something-changed).

## Unrecognised parameters for ... constructor

Every Term::Fabulous class rejects constructor parameters it does not
know, to catch typos. Check the spelling against the class's
documentation.

## The program dies with "is still attached to a parent"

A widget has one parent at a time, so `add_child` dies with
`Clay::UI: widget ... is still attached to a parent; remove it first`
for a widget that has one. Remove it from its current parent before
adding it elsewhere; see ["Changing the tree" in Term::Fabulous::Manual::Layout](Layout.md#changing-the-tree).

## "'root' is already the root of another Clay::UI"

A widget tree belongs to one [Term::Fabulous](../../../../README.md) or
[Term::Fabulous::Static](../Static.md) object at a time. Keep one object and call
its methods again (`run`, `render_lines`) instead of creating a
second one for the same root; see ["new" in Term::Fabulous](../../../../README.md#new).

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md). Next page: [Term::Fabulous::Manual::Glossary](Glossary.md).
