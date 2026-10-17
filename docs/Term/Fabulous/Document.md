# NAME

Term::Fabulous::Document - A document: a list of widgets with the
sections and the layout a document view shows them with

# SYNOPSIS

```perl
use Term::Fabulous::Document;
use Term::Fabulous::Widget::Table;

my $document = Term::Fabulous::Document->new( source => 'snapback.md' );
$document->heading( 1, 'snapback' );
$document->paragraph( { text => 'Copies files to a backup disk.', marks => [ [ 0, 6, 'bold' ] ] } );
$document->heading( 2, 'Usage' );
$document->code( "snapback ~/Documents /mnt/backup", language => 'shell' );
$document->list_item( "\x{2022}", { markup => 'Keeps the last [code]14[/] backups.' } );
$document->paragraph( { markup => 'See [link=faq.md]the FAQ[/].' } );

# Any widget is an item: a table, a picture, a form.
$document->add( Term::Fabulous::Widget::Table->new( id => 'releases', columns => [...], rows => [...] ) );

my $view = Term::Fabulous::Widget::DocumentView->new( id => 'manual', document => $document );
```

# DESCRIPTION

A document is what a [Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md) shows: an
ordered list of _items_, each a widget, with a few options that say
how the view lays the item out, and the _sections_ and _anchors_ that
links lead to. A parser makes one from a file: it calls the
["FACTORIES"](#factories) for the common items, headings, paragraphs, list items,
terms, code and rules, and ["add"](#add) for any other widget. The document
knows nothing of the screen; it can be made and inspected without a
terminal.

An item is any widget without a parent: a [Term::Fabulous::Widget::Text](Widget/Text.md),
a box of several widgets, a [table](Widget/Table.md), a
form with buttons. The view searches the texts of every item through
[Term::Fabulous::Role::Searchable](Role/Searchable.md), selects and follows the links of
every [Term::Fabulous::Widget::Text](Widget/Text.md) in them, and lets the user reach
their interactive widgets with Tab.

Every item belongs to the document while the document exists, and is
shown by one view at a time: the view wraps each item in a box of its
own (see ["How items are shown" in Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md#how-items-are-shown)).

Worked examples are in [Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md).

## Item options

["add"](#add) and every factory take these options, which the view applies
when it shows the item:

- `gap`

    The blank rows above the item, a non-negative integer. Default: 1 for
    ["add"](#add); the factories choose (see ["FACTORIES"](#factories)). The first item of a
    document never has blank rows above it.

- `indent`

    Columns by which the item is indented, on top of the view's own
    [indent](Widget/DocumentView.md#indent). Default: 0.

- `flush`

    A boolean: the item ignores the view's indent and starts at the left
    edge (plus its own `indent`). Default: 0; headings are flush.

- `quote`

    The number of block quotes the item is in, a non-negative integer. The
    view draws a bar on its left for each. Default: 0.

- `rows`

    The rows the item takes, when it is known before the item is laid out
    and the item's own estimate is not good enough. Default: none; the view
    asks the widget (["estimated\_rows" in Term::Fabulous::Widget](Widget.md#estimated_rows)). A wrong
    number does no harm beyond a scrollbar that jumps a little when the
    item comes into view.

- `section`

    `[ $level, $title ]`: the item starts a section, with a level from 1
    to 6 and a title. Sections make the table of contents and the section
    of [Term::Fabulous::Event::ViewChange](Event/ViewChange.md), and ["find\_section"](#find_section) finds
    them. Headings start sections.

- `anchor`

    A name links can lead to (["find\_section"](#find_section)), such as the text of a
    term.

An unknown option and an invalid value die.

# CONSTRUCTOR

## new

```perl
my $document = Term::Fabulous::Document->new( source => $path, look => 'My::Look' );
```

Creates an empty document. Both parameters are optional:

- `source`

    A string: where the document came from, a file name for instance, for
    the program to show or to resolve relative links with. Default: none.

- `look`

    The name of a loaded [Term::Fabulous::Document::Look](Document/Look.md) class, whose
    kinds the factories style marks with, and whose `code_block` and
    `clipped` styles code blocks paint with. Default:
    `Term::Fabulous::Document::Look`. A reader with mark kinds of its own
    names a subclass (see ["Changing and adding kinds" in Term::Fabulous::Document::Look](Document/Look.md#changing-and-adding-kinds)).

# FACTORIES

Each factory makes an item, adds it with the given ["Item options"](#item-options),
and returns the widget. A text is given as one of:

- a string, the plain text;
- `{ text => $text, marks => [ [ $start, $end, $kind ], [ $start, $end, 'link', $target ], ... ] }`:
the text and its _marks_, ranges of character offsets (the start and
the offset after the end) with a kind of the document's look (`bold`,
`italic`, `code`, `file`, ...; see ["KINDS" in Term::Fabulous::Document::Look](Document/Look.md#kinds))
or `link` with a target, any defined value that
[LinkActivate](Event/LinkActivate.md) hands back;
- `{ markup => $markup }`: markup as
[Term::Fabulous::Text::Markup](Text/Markup.md) reads it, styles and links included.

Marks may overlap, links may not. A kind the look does not know, a mark
past the text and an invalid shape die. The styles are palette tokens
of the theme (["token\_style" in Term::Fabulous::Document::Look](Document/Look.md#token_style)), so a
theme switch recolors the document without any work.

Unless the `gap` option says otherwise, a factory puts one blank row
above its item, with two exceptions: none between the items of a list
(an item whose `position` is above 1 after an item), nor before the
first item of a list nested in the item above it (indented deeper); and
none between a term and the item after it, if that item is not a term
and is indented deeper than the term, its definition.

## heading

```perl
my $widget = $document->heading( $level, $text, %options );
```

A heading of level 1 to 6, in the style of its level (`heading1` to
`heading6`); a first-level heading has a horizontal rule under it. It
is `flush`, and starts a section with its text as the title.

## paragraph

```perl
my $text = $document->paragraph( $text, %options );
```

A paragraph: a [Term::Fabulous::Widget::Text](Widget/Text.md) that the view wraps to
its width.

## term

```perl
my $text = $document->term( $text, %options );
```

The term of a definition list, in the `term` style, with its text as an
anchor. Give the paragraph that defines it a deeper `indent`, and it
follows the term without a blank row.

## list\_item

```perl
my $row = $document->list_item( $marker, $text, marker_width => 3, position => 1, %options );
```

An item of a list: the marker (a bullet or a number, in the `marker`
style, which a search passes over) in a column of its own, and the
text, whose lines all start after the marker. `marker_width` is the
columns from the start of the marker to the start of the text, at least
one more than the marker takes (the default); give all items of a list
the same width so that their texts line up. `position` counts the
items of a list from 1 (the default); an item with position 1 starts a
new list, with a blank row above. A nested list is a list with a
deeper `indent`: the parent's `indent` plus its `marker_width`.

## code

```perl
my $block = $document->code( $code, language => 'perl', %options );
```

A [Term::Fabulous::Widget::CodeBlock](Widget/CodeBlock.md): code that keeps its lines and
never wraps, in the document look's `code_block` style. The optional
`language` goes to the view's
[highlighter](Widget/DocumentView.md#highlighter).

## rule

```perl
my $divider = $document->rule(%options);
```

A horizontal rule, a [Term::Fabulous::Widget::Divider](Widget/Divider.md) across the view.

# METHODS

## add

```perl
my $widget = $document->add( $widget, %options );
```

Adds a widget as the next item, with the ["Item options"](#item-options), and returns
it. The widget must be an element or a text without a parent, and not
an item already; anything else dies. Items can be added while a view
shows the document: the view shows them from its next frame.

## items, count, item

```perl
my @widgets = $document->items;
my $count   = $document->count;
my $widget  = $document->item($index);
```

The items, their number, and the item with an index from 0. An index
that is no item dies.

## options\_of

```perl
my $options = $document->options_of($index);    # { gap, indent, flush, quote, rows }
```

How the view lays the item out, as a new hash.

## kind\_of

```perl
my $kind = $document->kind_of($index);    # 'heading', 'paragraph', 'term', 'item', 'code', 'rule' or 'widget'
```

What made an item: the factory (`item` for ["list\_item"](#list_item)), or `widget`
for an item given to ["add"](#add).

## index\_of

```perl
my $index = $document->index_of($widget);    # or undef
```

The index of an item, or `undef` for a widget that is no item (one
inside an item, say).

## texts, searchables

```perl
my @texts       = $document->texts($index);
my @searchables = $document->searchables($index);
```

The [Term::Fabulous::Widget::Text](Widget/Text.md) widgets of an item, the item itself
included, in tree order (where its links are), and the widgets of the
item that answer a search (["searchables\_in" in Term::Fabulous::Role::Searchable](Role/Searchable.md#searchables_in)).

## code\_blocks

```perl
my @blocks = $document->code_blocks;
```

The code blocks the ["code"](#code) factory made, which the view gives its
highlighter.

## sections, section\_count

```perl
foreach my $section ( $document->sections ) {
        say '  ' x ( $section->{level} - 1 ), $section->{title};    # a table of contents
}
```

The sections in the order of the document, each as a new hash with the
`item` index it starts at, its `level` and its `title`, and their
number.

## item\_of\_section, level\_of\_section, title\_of\_section

```perl
my $index = $document->item_of_section(3);
```

The item a section starts at, its level and its title, by the number of
the section from 0. A number that is no section dies.

## section\_at

```perl
my $number = $document->section_at($index);    # or undef
```

The number of the section an item is in: the last section that starts
at or before it. `undef` for an item before the first section.

## find\_section

```perl
my $index = $document->find_section('Methods');    # or undef
```

The item a link to a section leads to. The name is compared, with
whitespace squeezed, with the titles of the sections first, then with
the anchors: exactly, then ignoring case, then as a title or anchor that
starts with the name as a word (`open` finds `open FILEHANDLE,EXPR`),
then the same ignoring case. `undef` when nothing matches or the name
is empty.

## find\_text

```perl
foreach my $match ( $document->find_text('needle') ) {
        my ( $index, $widget, $key, $start, $end ) = @$match;
}
```

Every occurrence of the text in the texts the searchable widgets of the
items show, in the order of the document: the item, the widget that
shows the text, the text's key (see
["search\_texts" in Term::Fabulous::Role::Searchable](Role/Searchable.md#search_texts)) and the offsets of
the match. A query without capital letters ignores case; it is text,
not a pattern. Matches do not overlap.

## source, look

The values of the constructor parameters.

## shown\_by

```perl
my $view = $document->shown_by;    # or undef
```

The view that shows the document. A document is shown by one view at a
time; giving it to a second one dies.

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md), [Term::Fabulous::Document::Look](Document/Look.md),
[Term::Fabulous::Role::Searchable](Role/Searchable.md), [Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md).
