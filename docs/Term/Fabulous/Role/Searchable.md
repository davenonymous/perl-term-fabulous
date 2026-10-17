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

The role declares the methods below and provides none, so a class that
composes it defines all of them.

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

Makes the text named by the key visible inside the widget, as far as
the widget can: a table turns to the page of the row, a tab control
activates the page. Returns an array reference of two values, each of
which may be `undef`: the [Term::Fabulous::Widget::Text](../Widget/Text.md) that shows
the text, once it exists, and the row within the widget on which the
character at the offset lies, when the widget knows it before a layout
(a code block knows its line). A caller that scrolls the widget into
view uses the row, else the text widget's painted lines, else the
widget's own box.

# FUNCTIONS

## searchables\_in

```perl
my @widgets = searchables_in($widget);
```

The widgets at or below `$widget` that compose this role, in layout
order: `$widget` itself if it does, else those found among its
layout children, the children of a widget that does the role not
included (it answers for them). Exported on request.

# SEE ALSO

[Term::Fabulous::Widget::Text](../Widget/Text.md), [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md),
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md).
