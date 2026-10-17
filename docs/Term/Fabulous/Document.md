# NAME

Term::Fabulous::Document - A document as a list of blocks, for a document view

# SYNOPSIS

```perl
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Paragraph;

my $document = Term::Fabulous::Document->new(
        blocks => [
                Term::Fabulous::Document::Block::Heading->new( text => 'NAME', level => 1 ),
                Term::Fabulous::Document::Block::Paragraph->new( text => 'Foo::Bar - does things' ),
        ],
        source => 'lib/Foo/Bar.pm',
);

say $document->count, ' blocks';
foreach my $heading ( $document->headings ) {
        say '  ' x ( $heading->level - 1 ), $heading->text;
}

my $target  = $document->find_section('METHODS');    # a block index, or undef
my @matches = $document->find_text('frobnicate');    # [ block index, start, end ], ...
```

# DESCRIPTION

A document is what a parser makes of a source in some documentation
format: the [blocks](Document/Block.md) a reader shows,
in order, plus the questions a reader asks about them. It knows nothing
about the screen; [Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md) shows it, and
knows nothing about the format.

Documents are values: built once, never changed. Opening another page
means parsing another document.

A parser for a format is a function from a source to a document;
[Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser) is one for POD, and a subclass of this class
may add what a format knows about itself, as [Pod::Fabulous::Document](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3ADocument)
adds the name and the abstract of a POD page.

# CONSTRUCTOR

## new

```perl
my $document = Term::Fabulous::Document->new( blocks => \@blocks, source => $path );
```

Unknown parameters die. The parameters:

- `blocks`

    An array reference of [Term::Fabulous::Document::Block](Document/Block.md) objects.
    Default: none, an empty document.

- `source`

    The path of the file the document was read from, or `undef` (the
    default) for a document parsed from a string.

# METHODS

## blocks

```perl
my @blocks = $document->blocks;
```

The blocks, in the order of the source.

## count

```perl
my $count = $document->count;
```

The number of blocks.

## block

```perl
my $block = $document->block($index);
```

The block at an index from 0 to `count - 1`. Any other index dies.

## source

```perl
my $path = $document->source;
```

The path of the file the document was read from, or `undef`.

## heading\_indexes

```perl
my @indexes = $document->heading_indexes;
```

The indexes of the heading blocks ([Term::Fabulous::Document::Block::Heading](Document/Block/Heading.md)),
in order: the table of contents.

## headings

```perl
my @headings = $document->headings;
```

The heading blocks themselves, in the same order: section number `$n`
is `$headings[$n]`.

## section\_at

```perl
my $number = $document->section_at($index);
```

The number of the section a block is in: the position, in
["heading\_indexes"](#heading_indexes), of the last heading at or before the block.
`undef` for blocks before the first heading.

## heading\_of\_section

```perl
my $heading = $document->heading_of_section($number);
say $heading->text;
```

The heading that starts a section, numbered as ["section\_at"](#section_at) numbers
them. A number that is not a section of the document dies.

## block\_of\_section

```perl
my $index = $document->block_of_section($number);
```

The block index of that heading: where the section starts. A number
that is not a section of the document dies.

## links

```perl
foreach my $link ( $document->links ) {
        my ( $index, $mark ) = @$link;
        say $mark->link, ' in block ', $index;
}
```

Every link of the document, in the order of the text, as
`[ $block_index, $mark ]` with the [Term::Fabulous::Document::Mark](Document/Mark.md) of
kind `link`. The array references are copies.

## find\_section

```perl
my $index = $document->find_section('open');
```

The block a link to the named section leads to, or `undef` when there
is none. Sections are the headings and the terms of definition lists
([Term::Fabulous::Document::Block::Term](Document/Block/Term.md)), compared with runs of
whitespace squeezed to one space. The first of these rules that finds a
block decides, and within a rule headings come before terms and earlier
blocks before later ones:

1. The text equals the name.
2. The text equals the name when case is ignored.
3. The text starts with the name, followed by the end or a character that
is not a word character: `open` finds `open FILEHANDLE,EXPR`, the
way ["open" in perlfunc](https://metacpan.org/pod/perlfunc#open) is meant.
4. As 3., ignoring case.

## find\_text

```perl
my @matches = $document->find_text('hash');
```

Every occurrence of a text in the blocks, as `[ $block_index, $start,
$end ]` character offsets, in the order of the document; occurrences
do not overlap. A query without capital letters ignores case
(`hash` finds `Hash`); one with a capital letter matches case
(`Hash` does not find `hash`), as `less` does with its option
`-i`. The query is plain text, not a pattern. An empty query finds
nothing.

# SEE ALSO

[Term::Fabulous::Document::Block](Document/Block.md), [Term::Fabulous::Document::Mark](Document/Mark.md),
[Term::Fabulous::Widget::DocumentView](Widget/DocumentView.md), [Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser).
