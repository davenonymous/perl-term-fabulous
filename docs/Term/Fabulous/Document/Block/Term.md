# NAME

Term::Fabulous::Document::Block::Term - A term block of a definition list

# SYNOPSIS

```perl
my $term = Term::Fabulous::Document::Block::Term->new( text => 'open FILEHANDLE,EXPR', indent => 0 );
```

# DESCRIPTION

A term block holds the term that an entry of a definition list
defines, such as `=item open FILEHANDLE,EXPR` in [perlfunc](https://metacpan.org/pod/perlfunc), or a
term of a description list in other formats. The document view shows
its whole text in the `term` style of
["KINDS" in Term::Fabulous::Document::Look](../Look.md#kinds), with marks applied on top.

The blocks that define the term follow the term block as blocks of
their own, with an `indent` greater than the term's. [Pod::Fabulous::Parser](https://metacpan.org/pod/Pod%3A%3AFabulous%3A%3AParser),
for example, indents them by the indent of the `=over`, 4 columns by
default. The view leaves no blank row between a term and the block
after it if that block is not a term and is indented deeper than the
term. Two terms that follow each other directly are separated by a
blank row.

Terms are targets for links to sections, just like headings (see
["find\_section" in Term::Fabulous::Document](../../Document.md#find_section)), but they do not start
sections of their own.

A term block has the constructor parameters and methods of
[Term::Fabulous::Document::Block](../Block.md) and nothing more; its
[kind](../Block.md#kind) is `term`.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Document::Block::Item](Item.md).
