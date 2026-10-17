# NAME

Term::Fabulous::Document::Block::Paragraph - An ordinary paragraph

# SYNOPSIS

```perl
my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Hello, world.', indent => 0 );
```

# DESCRIPTION

An ordinary paragraph of a document, or a paragraph inside a list item
or a block quote, with `indent` and `quote` telling how deep. It has
the parameters and methods of [Term::Fabulous::Document::Block](../Block.md) and
nothing more; its [kind](../Block.md#kind) is
`paragraph`.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md).
