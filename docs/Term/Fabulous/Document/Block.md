# NAME

Term::Fabulous::Document::Block - One paragraph of a document, ready to be shown

# SYNOPSIS

```perl
foreach my $block ( $document->blocks ) {
        say $block->kind, ' at indent ', $block->indent, ': ', $block->text;
        say '  ', $_->kind, ' ', $_->start, '..', $_->end foreach $block->marks;
}
```

# DESCRIPTION

A [Term::Fabulous::Document](../Document.md) is a list of blocks, one for every
paragraph a [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) shows. A parser
([Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser) for POD, [Term::Fabulous::Widget::Markdown](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AMarkdown)
for Markdown) has already resolved everything the source format leaves
to a formatter: the formatting codes are gone from the text and became
[marks](Mark.md), entities are characters, lists
became indents and markers. What remains is plain data that a widget
shows without knowing the format.

This class is abstract. Term::Fabulous ships these kinds of block:

- [Term::Fabulous::Document::Block::Heading](Block/Heading.md)

    a heading of level 1 to 6;

- [Term::Fabulous::Document::Block::Paragraph](Block/Paragraph.md)

    an ordinary paragraph;

- [Term::Fabulous::Document::Block::Item](Block/Item.md)

    an item of a bulleted or numbered list, with its marker;

- [Term::Fabulous::Document::Block::Term](Block/Term.md)

    the term of an item in a list of definitions;

- [Term::Fabulous::Document::Block::Verbatim](Block/Verbatim.md)

    a verbatim paragraph (code), shown line by line without wrapping.

A viewer for another format adds kinds of its own by subclassing this
class: the document view builds a block of kind `KIND` with its
`view_of_KIND` method (see
["BLOCK KINDS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#block-kinds)), and the geometry
asks the block how tall its body is (["body\_rows"](#body_rows)).

Blocks are values: they are checked when they are created and never
change.

# CONSTRUCTOR

## new

```perl
my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Some text.', marks => [$mark], indent => 2 );
```

Called on a subclass; unknown parameters die. The parameters every
block takes:

- `text`

    Required. The text, a string without formatting codes. Paragraphs are
    one line; their line breaks are the viewer's business. A verbatim
    block keeps its lines.

- `marks`

    An array reference of [Term::Fabulous::Document::Mark](Mark.md) objects, each
    within the text. Default: none.

- `indent`

    A non-negative integer, default 0: how many columns the block is
    indented relative to the document's body, from the lists it is in.

- `quote`

    A non-negative integer, default 0: how many block quotes the block is
    inside. The view draws a bar left of the block for each level (see
    ["How blocks are shown" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#how-blocks-are-shown)).

# METHODS

## kind

```perl
my $kind = $block->kind;    # 'heading', 'paragraph', 'item', 'term', 'verbatim', ...
```

The kind of block, one word per subclass.

## text

```perl
my $text = $block->text;
```

The text.

## marks

```perl
my @marks = $block->marks;
```

The marks, in the order their formatting codes were opened.

## links

```perl
my @links = $block->links;
```

The marks of kind `link`, in the order of the text.

## indent

```perl
my $columns = $block->indent;
```

The indent, in columns.

## quote

```perl
my $depth = $block->quote;
```

How many block quotes the block is inside.

## body\_rows

```perl
my $rows = $block->body_rows($columns);
```

The rows the block's body takes in that many columns: its text wrapped
as Clay wraps it (["wrapped\_rows" in Term::Fabulous::Text::Wrap](../Text/Wrap.md#wrapped_rows)). A
verbatim block takes a row per line instead; a subclass whose body is
not wrapped text overrides this.

## row\_of\_character

```perl
my $row = $block->row_of_character( $offset, $columns );
```

The row, from 0, of the character at the offset when the body is laid
out in that many columns (["wrapped\_row" in Term::Fabulous::Text::Wrap](../Text/Wrap.md#wrapped_row));
in a verbatim block, the number of line breaks before it.

# SEE ALSO

[Term::Fabulous::Document](../Document.md), [Term::Fabulous::Document::Mark](Mark.md),
[Term::Fabulous::Document::Geometry](Geometry.md), [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md).
