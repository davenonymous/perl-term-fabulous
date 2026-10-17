# NAME

Term::Fabulous::Document::Block::Item - An item block of a bulleted or numbered list

# SYNOPSIS

```perl
my $item = Term::Fabulous::Document::Block::Item->new( marker => "\x{2022}", marker_width => 2, position => 1, text => 'First point.' );
```

# DESCRIPTION

An item block holds the first paragraph of an item of a bulleted or
numbered list, together with the item's _marker_: the bullet or the
number shown before the text. The document view shows the marker in a
column of its own, `marker_width` columns wide, and wraps the text in
the remaining width, so that every line of the text starts after the
marker (a hanging indent).

Any further blocks that belong to the item, such as more paragraphs,
code or a nested list, follow the item block as blocks of their own.
A parser gives them an `indent` of the item's `indent` plus its
`marker_width`, so that they line up with the item's text.

## Lists

The document has no list object; a list is a run of item blocks. A
parser gives all items of one list the same `marker_width`, wide
enough for the widest marker of the list plus at least one space, so
that the texts of all items line up, as with `9.` and `10.`:

```perl
use List::Util qw(max);
use Term::Fabulous::Unicode qw(string_columns);

my @texts   = map { "Point $_." } 1 .. 10;
my @markers = map { "$_." } 1 .. @texts;
my $width   = 1 + max map { string_columns($_) } @markers;    # 4

my @items = map {
        Term::Fabulous::Document::Block::Item->new(
                marker       => $markers[$_],
                marker_width => $width,
                position     => $_ + 1,
                text         => $texts[$_],
        )
} 0 .. $#texts;
```

The `position` of an item is its ordinal in the list, counted from 1,
regardless of the number its marker shows: the first item of a list
that starts at 5 still has position 1. The view uses it to decide where
a list begins. It leaves no blank row before an item when the block
before it is also an item and either the item is not the first of its
list (its position is greater than 1) or it is indented deeper than the
item before it (it is the first item of a nested list). Every other
item, in particular the first item of a list that directly follows
another list at the same indent, gets a blank row before it, so the two
lists stay apart.

# CONSTRUCTOR

## new

```perl
my $item = Term::Fabulous::Document::Block::Item->new( marker => '10.', marker_width => 4, position => 10, text => 'Tenth.' );
```

Creates an item block. It accepts the parameters of
["new" in Term::Fabulous::Document::Block](../Block.md#new), plus:

- `marker`

    Required. The marker, a non-empty string, such as a bullet character
    (`"\x{2022}"`) or a number with its dot (`'10.'`). An empty string,
    an undefined value or a reference dies.

- `marker_width`

    Required. The width of the marker column in terminal columns, including
    the space after the marker: a positive integer greater than the width
    of the marker in columns. A value that leaves no space after the marker
    dies.

- `position`

    The ordinal of the item in its list, a positive integer counted from 1.
    The default is 1.

# METHODS

An item block has the methods of [Term::Fabulous::Document::Block](../Block.md);
its [kind](../Block.md#kind) is `item`. It adds
these methods:

## marker

```perl
my $marker = $item->marker;
```

Returns the marker.

## marker\_width

```perl
my $columns = $item->marker_width;
```

Returns the width of the marker column in columns: the distance from
the start of the marker to the start of the text.

## position

```perl
my $position = $item->position;
```

Returns the ordinal of the item in its list, counted from 1.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Document::Block::Term](Term.md).
