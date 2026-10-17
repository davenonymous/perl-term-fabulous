# NAME

Term::Fabulous::Document::Geometry - Where the blocks of a document go on the screen, in rows and columns

# SYNOPSIS

```perl
use Term::Fabulous::Document::Geometry;

my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

my $left  = $geometry->left_of($index);                     # columns of padding left of the block
my $space = $geometry->space_before($index);                # 0 or 1 blank row above it
my $width = $geometry->text_columns( $index, 78 );          # columns left for its body
my $rows  = $geometry->estimated_rows( $index, 78 );        # its height before it is laid out
my $row   = $geometry->row_of_character( $index, 120, 78 ); # the row of character 120 in its box
```

# DESCRIPTION

You rarely need this class directly: [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md)
creates and uses it for you. It matters when you write a new kind of
block (see [Term::Fabulous::Document::Block](Block.md)), because the geometry
relies on the block to report how many rows its body takes and on which
row a character lies, or when you build your own widget that lays out a
[Term::Fabulous::Document](../Document.md) the way the view does.

The view lays a document out as a column of boxes, one per block, and
lets Clay wrap the text inside them. Clay knows the height of a box
only after it has laid the box out, but the view needs heights earlier:
it estimates the height of every block it has not laid out yet, so that
the scrollbar reflects the whole document (see
["estimate" in Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md#estimate)). To scroll a search
match or a selected link into view, it also needs the row of a
character within its block. This class answers both questions, and the
ones they depend on: how far a block is indented, whether a blank row
separates it from the block above, and how many columns remain for its
body. It works on numbers only and knows nothing of widgets or the
screen.

The height of a block's body is up to the block itself
(["body\_rows" in Term::Fabulous::Document::Block](Block.md#body_rows)). A paragraph wraps its
text the way Clay does ([Term::Fabulous::Text::Wrap](../Text/Wrap.md)), so its estimate
is exact as long as Clay keeps wrapping that way. A verbatim block
takes one row per line. A block kind added for another format computes
its own height.

A geometry belongs to one document and one indent and never changes.
The view creates a new geometry whenever either of them changes.

# CONSTRUCTOR

## new

```perl
my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );
```

Creates the geometry of a document. Both parameters are required:

- `document`

    The [Term::Fabulous::Document](../Document.md) whose blocks are measured.

- `indent`

    A non-negative integer: the number of columns by which every block
    except a heading is indented from the left edge of its box, in addition
    to the block's own indent.

The constructor dies when `document` is not a Term::Fabulous::Document,
when `indent` is not a non-negative integer, and when it gets an
unknown parameter.

# METHODS

The methods that take a block index die when the document has no block
with that index, as ["block" in Term::Fabulous::Document](../Document.md#block) does.

`$box_columns` is the width of the block's box, in columns. In the
document view, a block's box spans the inside of the view: its width
less its border, padding and scrollbar.

## document, indent

```perl
my $document = $geometry->document;
my $columns  = $geometry->indent;
```

Return the values given to the constructor.

## left\_of

```perl
my $columns = $geometry->left_of($index);
```

Returns the number of columns between the left edge of the block's box
and the start of the block. This is two columns for every block quote
the block is in (["quote" in Term::Fabulous::Document::Block](Block.md#quote)), room for
the quote bar and a space. Every block except a heading is then
indented further by the geometry's ["indent"](#indent) plus the block's own
indent (["indent" in Term::Fabulous::Document::Block](Block.md#indent)). A heading is
indented by its quote columns only.

## space\_before

```perl
my $rows = $geometry->space_before($index);
```

Returns the number of blank rows above the block: 1 to separate it from
the block above, as paragraphs are separated on paper, or 0 in these
cases:

- the block is the first block of the document;
- the block and the block before it are both list items, and the block
is either not the first item of its list (see
["position" in Term::Fabulous::Document::Block::Item](Block/Item.md#position)) or indented deeper
than the item before it, which makes it the first item of a list nested
in that item;
- the block directly follows a term of a definition list, is not a term
itself and is indented deeper than the term, which makes it the start
of the term's definition.

## text\_columns

```perl
my $columns = $geometry->text_columns( $index, $box_columns );
```

Returns the number of columns left for the block's body in a box that
is `$box_columns` wide: the box width less ["left\_of"](#left_of) and, for an
item, the width of its marker
(["marker\_width" in Term::Fabulous::Document::Block::Item](Block/Item.md#marker_width)). The result is
at least 1, however narrow the box.

## estimated\_rows

```perl
my $rows = $geometry->estimated_rows( $index, $box_columns );
```

Returns the number of rows the block takes in a box that is
`$box_columns` wide, computed without laying it out. It is the sum of
["space\_before"](#space_before), the block's
[body\_rows](Block.md#body_rows) for
["text\_columns"](#text_columns) columns, and one row for the rule under a first-level
heading. The view uses it as the estimate of its
[Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md).

## row\_of\_character

```perl
my $row = $geometry->row_of_character( $index, $offset, $box_columns );
```

Returns the row of the character at `$offset` (counted in characters
from 0) in the block's text, counted from 0 at the top of the block's
box in a box that is `$box_columns` wide. It is ["space\_before"](#space_before) plus
the row the block's
[row\_of\_character](Block.md#row_of_character)
reports for ["text\_columns"](#text_columns) columns. The view adds the result to the
top of the block's box on the screen to find the screen row it has to
scroll into view. Dies when `$offset` is not a non-negative integer.

# SEE ALSO

[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md), [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md),
[Term::Fabulous::Document](../Document.md), [Term::Fabulous::Document::Block](Block.md),
[Term::Fabulous::Text::Wrap](../Text/Wrap.md), ["estimate" in Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md#estimate).
