# NAME

Term::Fabulous::Document::Geometry - The rows and columns of the blocks of a document on the screen

# SYNOPSIS

```perl
use Term::Fabulous::Document::Geometry;

my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

my $left  = $geometry->left_of($index);                    # the padding left of the block
my $space = $geometry->space_before($index);               # 0 or 1 blank row above it
my $rows  = $geometry->estimated_rows( $index, 78 );       # before it was laid out
my $row   = $geometry->row_of_character( $index, 120, 78 );
```

# DESCRIPTION

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) lays a document out in boxes,
one per block, and lets Clay wrap their text. Before a block is laid
out, the view still needs to know how tall it will be, for the
scrollbar; and to scroll a search match into view, it needs the row of
a character within the block. This class answers both, and the
questions they build on: how far a block is indented, the blank row
above it, and how many columns its body takes. It knows no widget and
no screen.

The height of a body is the block's business
(["body\_rows" in Term::Fabulous::Document::Block](Block.md#body_rows)): a paragraph wraps its
text as Clay does ([Term::Fabulous::Text::Wrap](../Text/Wrap.md)), so its estimate is
exact as long as Clay wraps that way; code takes a row per line; a
block kind of another format answers for itself.

A geometry is a value, for one document and one indent: the view makes
a new one when either changes.

# CONSTRUCTOR

## new

```perl
my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );
```

Both parameters are required: a [Term::Fabulous::Document](../Document.md), and the
columns every block but a heading is indented by, a non-negative
integer. Anything else dies, and so do unknown parameters.

# METHODS

The methods that take a block index die for an index the document has
no block for, as ["block" in Term::Fabulous::Document](../Document.md#block) does. Column counts
are those of the block's box: the width of the view inside its border,
padding and scrollbar.

## document, indent

The parameters.

## left\_of

```perl
my $columns = $geometry->left_of($index);
```

The padding left of the block: two columns for every block quote it is
in (["quote" in Term::Fabulous::Document::Block](Block.md#quote)), then, for every block
but a heading, the indent plus the block's own
(["indent" in Term::Fabulous::Document::Block](Block.md#indent)).

## space\_before

```perl
my $rows = $geometry->space_before($index);
```

The blank rows above the block: one, as between paragraphs on paper,
except above the first block, between the items of one list (an item
after the first, see ["position" in Term::Fabulous::Document::Block::Item](Block/Item.md#position)),
between an item and the first item of a list nested in it (an item
indented deeper than the item before it) and between a term and the
indented blocks that define it.

## text\_columns

```perl
my $columns = $geometry->text_columns( $index, $box_columns );
```

The columns the block's body takes: what the box leaves after
["left\_of"](#left_of) and the marker of an item, at least one.

## estimated\_rows

```perl
my $rows = $geometry->estimated_rows( $index, $box_columns );
```

The rows the block takes: ["space\_before"](#space_before), then the block's
[body\_rows](Block.md#body_rows) in
["text\_columns"](#text_columns), and a row for the rule under a first-level heading.

## row\_of\_character

```perl
my $row = $geometry->row_of_character( $index, $offset, $box_columns );
```

The row, counted from the top of the block's box, of the character at
the offset in the block's text: past ["space\_before"](#space_before), where the
block's [row\_of\_character](Block.md#row_of_character)
puts it in ["text\_columns"](#text_columns).

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Document](../Document.md),
[Term::Fabulous::Text::Wrap](../Text/Wrap.md), ["estimate" in Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md#estimate).
