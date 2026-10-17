# NAME

Term::Fabulous::Document - A format-independent document model for the document view

# SYNOPSIS

```perl
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Mark;

my $document = Term::Fabulous::Document->new(
        blocks => [
                Term::Fabulous::Document::Block::Heading->new( text => 'NAME', level => 1 ),
                Term::Fabulous::Document::Block::Paragraph->new(
                        text  => 'Call frobnicate() or see perlfunc.',
                        marks => [
                                Term::Fabulous::Document::Mark->new( start => 5,  end => 17, kind => 'code' ),
                                Term::Fabulous::Document::Mark->new( start => 25, end => 33, kind => 'link', link => 'perlfunc' ),
                        ],
                ),
        ],
        source => 'lib/Foo/Bar.pm',
);

say $document->count, ' blocks';
foreach my $heading ( $document->headings ) {
        say '  ' x ( $heading->level - 1 ), $heading->text;
}

my $target  = $document->find_section('NAME');        # 0, the index of the heading
my @matches = $document->find_text('frobnicate');    # ( [ 1, 5, 15 ] )
```

# DESCRIPTION

A document holds the content of a page in a form that
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md) can show without knowing the
format it was written in. A parser reads a source, such as a POD file or
a Markdown file, and turns it into a document; the view displays the
document. The document itself knows nothing about the screen, and the
view knows nothing about POD or Markdown.

Besides holding the blocks, a document answers the questions a reader
program asks about them: where the headings are, which section a block
belongs to, which block a link to a named section leads to, and where a
text occurs.

A document is immutable: its blocks are checked when it is built and
never change afterwards. To show different content, build a new
document and give it to the view (see
["document" in Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md#document)).

## The model

The model has three levels:

- A _document_ is an ordered list of blocks, in reading order.
- A _block_ ([Term::Fabulous::Document::Block](Document/Block.md)) is one paragraph-like
unit: a heading, a paragraph, a list item, the term of a definition
list or a verbatim (code) paragraph. A format can add kinds of its own
(see ["Adding a kind" in Term::Fabulous::Document::Block](Document/Block.md#adding-a-kind)). Every block has a _kind_, its
plain _text_ with all formatting removed, and a list of marks. Two
numbers place it in the nesting of the source: its _indent_ in columns,
which comes from the lists it is in, and its _quote_ depth, the number
of block quotes it is in.
- A _mark_ ([Term::Fabulous::Document::Mark](Document/Mark.md)) records that a range of a
block's text is formatted in some way: bold, italic, code, a link, and
so on. The range is given by a start offset and an end offset. Offsets
count characters of the Perl string (as `substr` and `length` do),
not bytes and not terminal columns, and the end offset is exclusive:
the mark covers the characters from `start` up to, but not including,
`end`.

The document has no tree structure. Nesting in the source, such as a
list inside a list item or a paragraph inside a block quote, is
flattened into the indent and the quote depth of each block.

## Writing a parser

A parser for a new format reads the source and produces the list of
blocks. The parser resolves everything a formatter would normally work
out, so that the blocks hold plain data:

- Formatting codes are removed from the text and recorded as marks of
kinds such as `bold`, `italic` or `code` (see
["Kinds" in Term::Fabulous::Document::Mark](Document/Mark.md#kinds)). The offsets of a mark refer
to the text _after_ all formatting has been removed.
- Links become marks of kind `link` that carry the link's destination,
in any form the program understands (see
["link" in Term::Fabulous::Document::Mark](Document/Mark.md#link)).
- Entities and escapes, such as `E<gt>` in POD or `&amp;` in
Markdown, are replaced by the characters they stand for before offsets
are computed.
- The text of a heading, paragraph, item or term is a single line. The
view wraps it at spaces to the width available, so the parser joins
the source lines of a paragraph with single spaces.
- List nesting becomes the `indent` of the blocks: an item has the
indent of its list, and the blocks inside the item, including the items
of a nested list, are indented further by the item's `marker_width`,
so that they line up with the item's text.
- Block quote nesting becomes the `quote` depth of every block inside
the quote.
- Each list item gets a marker (a bullet or a number such as `3.`), and
all items of one list share one `marker_width` (see
[Term::Fabulous::Document::Block::Item](Document/Block/Item.md)).
- In a definition list, each term becomes a
[Term::Fabulous::Document::Block::Term](Document/Block/Term.md), followed by the blocks that
define it, indented deeper than the term.
- Verbatim paragraphs keep their lines, separated by `"\n"`, with the
indentation all lines share removed and tabs expanded to spaces (see
[Term::Fabulous::Document::Block::Verbatim](Document/Block/Verbatim.md)).

[Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser) is such a parser for POD. A format can also add
information of its own by subclassing this class, as
[Pod::Fabulous::Document](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3ADocument) adds the name and the abstract of a POD page.
[Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md) builds documents step by step and
walks through writing a parser for a new format.

## Sections

Several methods work with _sections_. A section starts at a heading
and runs up to the next heading of any level, so sections are not
nested. Sections are numbered from 0 in document order: section `$n`
starts with the heading at block index `($document->heading_indexes)[$n]`.
Blocks before the first heading belong to no section.

# CONSTRUCTOR

## new

```perl
my $document = Term::Fabulous::Document->new( blocks => \@blocks, source => $path );
```

Creates a document. Unknown parameters die. The parameters are:

- `blocks`

    An array reference of [Term::Fabulous::Document::Block](Document/Block.md) objects, in
    reading order. The default is an empty array: a document without
    blocks. The document keeps a copy of the array, so changing the array
    afterwards does not change the document. A value that is not an array
    reference, or an element that is not a block object, dies.

- `source`

    A string that identifies where the document came from, usually the path
    of the file it was read from, or `undef` (the default), for example
    for a document parsed from a string. Term::Fabulous does not use the
    value; it is there for the program. A reference dies.

# METHODS

## blocks

```perl
my @blocks = $document->blocks;
```

Returns the list of blocks, in reading order.

## count

```perl
my $count = $document->count;
```

Returns the number of blocks.

## block

```perl
my $block = $document->block($index);
```

Returns the block at a block index, from 0 to `$document->count - 1`.
An index that is not a non-negative integer, or that is not less than
the number of blocks, dies.

## source

```perl
my $path = $document->source;
```

Returns the `source` given to the constructor, or `undef`.

## heading\_indexes

```perl
my @indexes = $document->heading_indexes;
```

Returns the block indexes of all headings (blocks whose
[kind](Document/Block.md#kind) is `heading`, see
[Term::Fabulous::Document::Block::Heading](Document/Block/Heading.md)), in document order. This
is the table of contents of the document: the position of an index in
this list is the number of its [section](#sections).

## headings

```perl
my @headings = $document->headings;
```

Returns the heading blocks themselves, in the same order as
["heading\_indexes"](#heading_indexes): the heading of section `$n` is `$headings[$n]`.

```perl
# A table of contents, indented by heading level:
foreach my $heading ( $document->headings ) {
        say '  ' x ( $heading->level - 1 ), $heading->text;
}
```

## section\_at

```perl
my $number = $document->section_at($index);
```

Returns the number of the [section](#sections) that the block at
`$index` belongs to: the position, in ["heading\_indexes"](#heading_indexes), of the last
heading at or before the block. A heading belongs to the section it
starts. Returns `undef` for a block before the first heading, and for
every block of a document without headings. An invalid block index
dies, as in ["block"](#block).

## heading\_of\_section

```perl
my $heading = $document->heading_of_section($number);
say $heading->text;
```

Returns the heading block that starts section `$number`, with sections
numbered as ["section\_at"](#section_at) returns them. A number that is not a
non-negative integer less than the number of sections dies.

## block\_of\_section

```perl
my $index = $document->block_of_section($number);
```

Returns the block index of the heading that starts section `$number`,
which is where the section begins. A number that is not a non-negative
integer less than the number of sections dies.

## links

```perl
foreach my $link ( $document->links ) {
        my ( $index, $mark ) = @$link;
        say $mark->link, ' in block ', $index;
}
```

Returns every link of the document as a list of array references
`[ $block_index, $mark ]`, where `$mark` is a
[Term::Fabulous::Document::Mark](Document/Mark.md) of kind `link`. The links are in
the order of the text: by block, and within a block by start offset
(see ["links" in Term::Fabulous::Document::Block](Document/Block.md#links)). Each call returns new
array references, so the caller may change them.

## find\_section

```perl
my $index = $document->find_section('open');
```

Returns the block index that a link to the named section leads to, or
`undef` when no block matches. The candidates are the headings and the
terms of definition lists ([Term::Fabulous::Document::Block::Term](Document/Block/Term.md)).
Before comparing, leading and trailing whitespace is removed from the
name and from the text of each candidate, and every run of whitespace
inside is replaced by a single space. A name that is empty after this
returns `undef`; an undefined name or a reference dies.

The rules below are tried in order, and the first rule that matches any
candidate decides. Within a rule, headings are preferred to terms, and
an earlier block to a later one.

1. The text equals the name exactly.
2. The text equals the name when case is ignored (compared with `fc`).
3. The text starts with the name, and the name is followed either by the
end of the text or by a character that is not a word character. This
lets `open` find the term `open FILEHANDLE,EXPR`, as a link to
["open" in perlfunc](https://metacpan.org/pod/perlfunc#open) intends.
4. The same as rule 3, but ignoring case.

## find\_text

```perl
my @matches = $document->find_text('hash');
foreach my $match (@matches) {
        my ( $index, $start, $end ) = @$match;
        say "block $index: ", substr( $document->block($index)->text, $start, $end - $start );
}
```

Searches the text of every block for a query and returns every
occurrence as an array reference `[ $block_index, $start, $end ]`,
where `$start` and `$end` are character offsets into the block's
text, with `$end` exclusive. The occurrences are in document order and
do not overlap.

The query is plain text, not a regular expression. Case is handled as
`less -i` handles it: a query without uppercase letters ignores case
(`hash` finds `Hash`), and a query with at least one uppercase letter
matches case exactly (`Hash` does not find `hash`). An empty query
returns an empty list; an undefined query or a reference dies.

# SEE ALSO

[Term::Fabulous::Document::Block](Document/Block.md), [Term::Fabulous::Document::Mark](Document/Mark.md),
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md), [Term::Fabulous::Cookbook::Documents](Cookbook/Documents.md),
[Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser).
