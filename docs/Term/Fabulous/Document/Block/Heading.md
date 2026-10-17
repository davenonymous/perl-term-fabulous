# NAME

Term::Fabulous::Document::Block::Heading - A heading, level 1 to 6

# SYNOPSIS

```perl
my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'DESCRIPTION', level => 1 );
say $heading->level;    # 1
```

# DESCRIPTION

A heading of a document: `=head1` in POD, `#` in Markdown. Headings
are never indented by a list, but may be inside a block quote.

# CONSTRUCTOR

## new

```perl
my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'Methods', level => 2 );
```

The parameters of ["new" in Term::Fabulous::Document::Block](../Block.md#new) plus:

- `level`

    Required. An integer from 1 to 6.

An `indent` other than 0 dies.

# METHODS

The methods of [Term::Fabulous::Document::Block](../Block.md), whose
[kind](../Block.md#kind) is `heading`, plus:

## level

```perl
my $level = $heading->level;
```

The level, 1 to 6.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), ["heading\_indexes" in Term::Fabulous::Document](../../Document.md#heading_indexes).
