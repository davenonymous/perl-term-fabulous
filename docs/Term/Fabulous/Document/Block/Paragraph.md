# NAME

Term::Fabulous::Document::Block::Paragraph - An ordinary paragraph block

# SYNOPSIS

```perl
my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Hello, world.', indent => 0 );
```

# DESCRIPTION

A paragraph block holds an ordinary paragraph of text. This includes
paragraphs inside a list item, inside the definition of a term or
inside a block quote: the `indent` and `quote` parameters record how
deeply the paragraph is nested (see
["new" in Term::Fabulous::Document::Block](../Block.md#new)).

The text is a single line, which the document view wraps to the width
available, breaking lines only at spaces. A parser therefore joins the
source lines of a paragraph with single spaces.

A paragraph block has the constructor parameters and methods of
[Term::Fabulous::Document::Block](../Block.md) and nothing more; its
[kind](../Block.md#kind) is `paragraph`.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md).
