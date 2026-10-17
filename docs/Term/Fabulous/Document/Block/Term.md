# NAME

Term::Fabulous::Document::Block::Term - The term of an item in a list of definitions

# SYNOPSIS

```perl
my $term = Term::Fabulous::Document::Block::Term->new( text => 'open FILEHANDLE,EXPR', indent => 0 );
```

# DESCRIPTION

The term a list of definitions defines, such as `=item open FILEHANDLE`
in [perlfunc](https://metacpan.org/pod/perlfunc). The paragraphs that describe it follow as blocks of
their own, indented one level deeper, and the view leaves no blank row
between the term and the first of them. Terms are link targets just
like headings (see ["find\_section" in Term::Fabulous::Document](../../Document.md#find_section)).

It has the parameters and methods of [Term::Fabulous::Document::Block](../Block.md)
and nothing more; its [kind](../Block.md#kind) is
`term`.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Document::Block::Item](Item.md).
