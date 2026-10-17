# NAME

Term::Fabulous::Document::Block - Base class for the blocks of a document

# SYNOPSIS

```perl
foreach my $block ( $document->blocks ) {
        say $block->kind, ' at indent ', $block->indent, ': ', $block->text;
        say '  ', $_->kind, ' ', $_->start, '..', $_->end foreach $block->marks;
}
```

# DESCRIPTION

A [Term::Fabulous::Document](../Document.md) is an ordered list of blocks. A block is
one paragraph-like unit of the document, such as a heading, a paragraph
or a list item, and the [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) shows
each block as a unit of its own, separated from its neighbors by a
blank row in most cases.

A block holds plain data that the view can show without knowing the
source format. The parser that created it ([Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser) for
POD, [Term::Fabulous::Widget::Markdown](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AMarkdown) for Markdown) has already
resolved everything a formatter would otherwise work out: the
formatting codes are removed from the text and recorded as
[marks](Mark.md), entities are replaced by the
characters they stand for, and the nesting of lists and block quotes is
recorded in the ["indent"](#indent) and the ["quote"](#quote) of each block. See
["Writing a parser" in Term::Fabulous::Document](../Document.md#writing-a-parser) for the full list.

A block is immutable: its parameters are checked when it is created and
never change afterwards.

## Built-in kinds

This class is abstract; every block is an object of a subclass, and the
subclass determines the block's ["kind"](#kind). Term::Fabulous ships five
kinds:

- [Term::Fabulous::Document::Block::Heading](Block/Heading.md)

    Kind `heading`: a heading of level 1 to 6.

- [Term::Fabulous::Document::Block::Paragraph](Block/Paragraph.md)

    Kind `paragraph`: an ordinary paragraph of text.

- [Term::Fabulous::Document::Block::Item](Block/Item.md)

    Kind `item`: an item of a bulleted or numbered list, with its marker.

- [Term::Fabulous::Document::Block::Term](Block/Term.md)

    Kind `term`: the term that an entry of a definition list defines.

- [Term::Fabulous::Document::Block::Verbatim](Block/Verbatim.md)

    Kind `verbatim`: a verbatim paragraph, usually code, shown line by
    line without wrapping.

## Adding a kind

A format that has blocks the built-in kinds do not cover, such as a
table or a horizontal rule, adds kinds of its own. A new kind needs two
parts:

- A subclass of this class that returns a new word from ["kind"](#kind). If the
body of the block is not text that wraps like a paragraph, the subclass
also overrides ["body\_rows"](#body_rows), and ["row\_of\_character"](#row_of_character) if the block has
text that can be searched.
- A subclass of [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) with a method
`view_of_KIND` that builds the widget for blocks of the new kind (see
["BLOCK KINDS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#block-kinds)). The view dies
when it has to show a block for whose kind it has no such method.

For example, a horizontal rule has no text and always takes one row:

```perl
use v5.32;
use feature 'signatures';
no warnings 'experimental::signatures';
use Object::Pad 0.825;
use Term::Fabulous::Document::Block;

class My::Block::Rule :isa(Term::Fabulous::Document::Block) :strict(params) {
        ADJUST {
                die "My::Block::Rule: a rule has no text" if length $self->text;
        }

        method kind () {
                return 'rule';
        }

        method body_rows :override ($columns) {
                return 1;
        }
}

my $rule = My::Block::Rule->new( text => '' );
```

[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md) shows complete examples,
including the matching view subclass.

# CONSTRUCTOR

## new

```perl
my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Some text.', marks => [$mark], indent => 2 );
```

Creates a block. Because this class is abstract, `new` must be called
on a subclass; each subclass may accept further parameters. Unknown
parameters die. The parameters every block accepts are:

- `text`

    Required. The text of the block, a string with all formatting removed.
    For a heading, paragraph, item or term, the text is a single line: the
    view wraps it to the width available, breaking lines only at spaces,
    so a parser joins the source lines of a paragraph with single spaces.
    A verbatim block keeps its lines, separated by `"\n"`. A missing,
    undefined or reference value dies.

- `marks`

    An array reference of [Term::Fabulous::Document::Mark](Mark.md) objects. The
    default is an empty array. Every mark must lie within the text: a mark
    whose end offset is greater than the length of the text dies, and so
    does an element that is not a mark object. The order of the marks
    matters; see ["marks"](#marks). Link marks are checked further: one that
    covers no text (`start` equal to `end`) dies, and so do two link
    marks that overlap, because the view shows them as the links of a
    [Term::Fabulous::Widget::Text](../Widget/Text.md), which refuses both. The block
    keeps a copy of the array.

- `indent`

    A non-negative integer, default 0: the number of columns by which the
    block is indented, in addition to the view's own
    [indent](../Widget/DocumentView.md#indent). A parser sets it
    from the lists the block is nested in.

- `quote`

    A non-negative integer, default 0: the number of block quotes the block
    is nested in. The view draws a vertical bar to the left of the block
    for each level, followed by a space (see
    ["How blocks are shown" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#how-blocks-are-shown)).

# METHODS

## kind

```perl
my $kind = $block->kind;    # 'heading', 'paragraph', 'item', 'term', 'verbatim', ...
```

Returns the kind of the block: a word that each subclass defines. The
document view uses it to choose how to show the block, and
[Term::Fabulous::Document](../Document.md) uses it to find headings and terms. Every
subclass must implement this method.

## text

```perl
my $text = $block->text;
```

Returns the text of the block, without formatting.

## marks

```perl
my @marks = $block->marks;
```

Returns the marks of the block in the order they were given to the
constructor. The order matters where marks overlap: the view applies
the styles of the marks in this order, so a later mark wins where two
marks set the same attribute, such as the text color. A parser usually
adds the marks in the order the formatting opens in the source.

## links

```perl
my @links = $block->links;
```

Returns the marks of kind `link`, ordered by their start offset,
whatever order they were given in. This is the order in which the view
counts the links of a block; link marks never overlap, so the order is
unambiguous.

## indent

```perl
my $columns = $block->indent;
```

Returns the indent of the block, in columns.

## quote

```perl
my $depth = $block->quote;
```

Returns the number of block quotes the block is nested in.

## body\_rows

```perl
my $rows = $block->body_rows($columns);
```

Returns the number of rows the body of the block takes when it is laid
out `$columns` columns wide, which must be a positive integer. The
body is the block's content without the blank row the view may put
above it. [Term::Fabulous::Document::Geometry](Geometry.md) calls this method to
estimate the height of a block the view has not laid out yet.

This implementation wraps the text at spaces the way Clay does (see
["wrapped\_rows" in Term::Fabulous::Text::Wrap](../Text/Wrap.md#wrapped_rows)) and returns at least 1.
[Term::Fabulous::Document::Block::Verbatim](Block/Verbatim.md) overrides it to return
one row per line. A subclass whose body is not wrapped text, such as a
table, overrides it too.

## row\_of\_character

```perl
my $row = $block->row_of_character( $offset, $columns );
```

Returns the row, counted from 0, on which the character at character
offset `$offset` appears when the body is laid out `$columns` columns
wide. The offset must be a non-negative integer and the columns a
positive integer. The view uses this to scroll a search match or a
selected link into view.

This implementation wraps the text as ["body\_rows"](#body_rows) does (see
["wrapped\_row" in Term::Fabulous::Text::Wrap](../Text/Wrap.md#wrapped_row)): a space belongs to the word
before it, and an offset past the end of the text is on the last row.
In a verbatim block, the row is the number of line breaks before the
offset.

# SEE ALSO

[Term::Fabulous::Document](../Document.md), [Term::Fabulous::Document::Mark](Mark.md),
[Term::Fabulous::Document::Geometry](Geometry.md), [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md),
[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md).
