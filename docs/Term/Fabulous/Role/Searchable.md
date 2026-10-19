# NAME

Term::Fabulous::Role::Searchable - The texts of a widget, for search and highlights

# SYNOPSIS

```perl
use Term::Fabulous::Role::Searchable qw(searchables_in);

foreach my $widget ( searchables_in($item) ) {
        foreach my $entry ( $widget->search_texts ) {
                my ( $key, $text ) = @$entry;
                next unless $text =~ /needle/;
                $widget->highlight_text( $key, [ [ $-[0], $+[0], 'on yellow' ] ] );
                my ( $shown, $row ) = @{ $widget->reveal_text( $key, $-[0] ) };
        }
}
```

# DESCRIPTION

A widget that composes this role can be searched: it says which texts
it shows, marks ranges of a text with a style, and brings a text into
view inside itself. [Term::Fabulous::Widget::Text](../Widget/Text.md) and
[Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md) do it for the one text each of
them holds. A widget that builds its texts only when it needs them,
such as a [table](../Widget/Table.md) with cells on other
pages, does it from its own data, so that a search reaches text that
is not on the screen. [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) searches
its items through this role.
["Search a document and show the reader's position (search, ViewChange)" in Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md#search-a-document-and-show-the-reader-s-position-search-viewchange)
shows a search over a document;
["Widgets a search finds" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#widgets-a-search-finds) shows
how to make a widget of your own searchable.

The role declares the methods below, which a class that composes it
defines, and provides ["search\_serial"](#search_serial). A widget that holds other
searchable widgets and answers for them composes
[Term::Fabulous::Role::SearchContainer](SearchContainer.md) instead, which provides the
methods.

A _key_ names one text of the widget (see ["search\_texts"](#search_texts)). Keys are
only valid together with their revision: a caller that keeps a key (a
search that remembers its matches) keeps the
["search\_revision"](#search_revision) it read with it, and compares the two before it
uses the key again; when the revision differs, the text changed and the
caller searches again.

# REQUIRED METHODS

## search\_texts

```perl
my @entries = $widget->search_texts;    # ( [ $key, $text ], ... )
```

The texts the widget shows, in the order they appear, each with a
_key_: any value that names that text within the widget and stays the
same while the text exists, such as `undef` for a widget with one
text, or a row and a column for a table cell. Offsets into `$text` are
character offsets.

## search\_revision

```perl
my $revision = $widget->search_revision($key);
```

A value that changes whenever the text named by the key changes, so a
caller can tell whether offsets it recorded earlier still point where
they did. Comparing two values with `ne` is enough.

## highlight\_text

```perl
$widget->highlight_text( $key, [ [ $start, $end, $style ], ... ] );
```

Marks ranges of the text named by the key with styles (strings or hash
references as [Term::Fabulous::Text::Style](../Text/Style.md) reads them), replacing the
ranges given before for that text. The widget shows them over its own
styles whenever it shows that text, also when it builds the widget for
it later. Offsets past the text die.

## clear\_text\_highlights

```perl
$widget->clear_text_highlights;
```

Removes every highlight of every text of the widget.

## reveal\_text

```perl
my ( $shown, $row ) = @{ $widget->reveal_text( $key, $offset ) };
```

Makes the text named by the key visible inside the widget, as far as the
widget can: a table turns to the page of the row, a tab control
activates the page. Returns an array reference of two values, each of
which may be `undef`: the widget that shows the text (a Text inside the
widget, such as a table's cell, or the widget itself, as a Text or a
CodeBlock returns), once it exists, and the row within the widget on
which the character at the offset lies, when the widget knows it before
a layout (a code block knows its line). A caller that scrolls the widget
into view uses the row, else the text widget's painted lines, else the
widget's own box.

# PROVIDED METHODS

## search\_serial

```perl
my $serial = $widget->search_serial;
```

A number that names the widget among all searchable widgets made by the
process, given at construction and never reused, also not after the
widget is freed. ["nested\_search\_revision"](#nested_search_revision) puts it into the revisions
of the texts a container answers for, so that a key that leads to
another widget after the widgets changed reads as changed.

# FUNCTIONS

## searchables\_in

```perl
my @widgets = searchables_in($widget);
```

The widgets at or below `$widget` that compose this role, in layout
order: `$widget` itself if it does, else those found among its
layout children, the children of a widget that does the role not
included (it answers for them). Exported on request.

## Nested keys

The functions below are the role's methods for a widget that answers
for searchable widgets inside it (its _parts_):
`\@widgets` are those widgets (from ["searchables\_in"](#searchables_in)), and a key names
one by its index in the list and that widget's own key,
`[ $index, $key ]`. Keys are positions, so a key still means "the same
place" after its widget was built again (a table re-applies highlights
to rebuilt cells by position). A key whose index is past the list names
no widget; a key that is not `[ index, key ]` dies.
[Term::Fabulous::Role::SearchContainer](SearchContainer.md) provides the role's methods
with them, for [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md) and
[Term::Fabulous::Widget::Accordion::Item](../Widget/Accordion/Item.md);
[Term::Fabulous::Widget::Table](../Widget/Table.md) calls them for the widgets of its
custom cells. All exported on request.

## nested\_part

```perl
my $widget = nested_part( \@widgets, $key );
```

The widget the key names, or `undef` when its index is past the list.

## nested\_search\_texts

```perl
my @entries = nested_search_texts( \@widgets );    # keys [ $index, $key ]
```

The texts of all the widgets, in order, with nested keys.

## nested\_search\_revision

```perl
my $revision = nested_search_revision( \@widgets, $key );
```

The ["search\_serial"](#search_serial) of the widget at the index and that widget's own
revision of the text, `"$serial:$revision"`: when another widget comes
to the index (a page was removed before it), the revision changes, so a
caller that compares revisions searches again instead of using the key.
`'gone'` for a key whose index is past the list.

## nested\_highlight\_text

```perl
nested_highlight_text( \@widgets, $key, \@ranges );
```

Highlights the text in the widget the key names; nothing for a key past
the list.

## nested\_clear\_text\_highlights

```perl
nested_clear_text_highlights( \@widgets );
```

Clears the highlights of every widget.

## nested\_reveal\_text

```perl
my $revealed = nested_reveal_text( \@widgets, $key, $offset );
```

The widget's `reveal_text`; `[ undef, undef ]` for a key past the list.

# SEE ALSO

[Term::Fabulous::Role::SearchContainer](SearchContainer.md),
[Term::Fabulous::Role::MarkedText](MarkedText.md), [Term::Fabulous::Widget::Text](../Widget/Text.md),
[Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md), [Term::Fabulous::Widget::Table](../Widget/Table.md),
[Term::Fabulous::Widget::Tabs](../Widget/Tabs.md),
[Term::Fabulous::Widget::Accordion::Item](../Widget/Accordion/Item.md),
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md),
["Widgets a search finds" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#widgets-a-search-finds).
