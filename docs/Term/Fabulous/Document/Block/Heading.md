# NAME

Term::Fabulous::Document::Block::Heading - A heading block of level 1 to 6

# SYNOPSIS

```perl
my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'DESCRIPTION', level => 1 );
say $heading->level;    # 1
```

# DESCRIPTION

A heading block holds a heading of a document, such as `=head1` in POD
or `#` in Markdown. Its level runs from 1, the top level, to 6.

Headings divide a document into sections: [Term::Fabulous::Document](../../Document.md)
lists them in ["heading\_indexes" in Term::Fabulous::Document](../../Document.md#heading_indexes) and
["headings" in Term::Fabulous::Document](../../Document.md#headings), and treats them as targets for
links to sections (see ["find\_section" in Term::Fabulous::Document](../../Document.md#find_section)).

The document view shows the whole text of a heading in the style of
its level (`heading1` to `heading6` of
["KINDS" in Term::Fabulous::Document::Look](../Look.md#kinds)), with marks applied on top,
and draws a horizontal rule under a first-level heading. A heading is
never indented: it starts at the left edge of the view's text area and
ignores the view's [indent](../../Widget/DocumentView.md#indent).
It can, however, be inside a block quote.

# CONSTRUCTOR

## new

```perl
my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'Methods', level => 2 );
```

Creates a heading block. It accepts the parameters of
["new" in Term::Fabulous::Document::Block](../Block.md#new), plus:

- `level`

    Required. The level of the heading, an integer from 1 to 6. Any other
    value dies.

A heading cannot be indented: an `indent` other than 0 dies. The
`quote` parameter is allowed.

# METHODS

A heading block has the methods of [Term::Fabulous::Document::Block](../Block.md);
its [kind](../Block.md#kind) is `heading`. It adds
one method:

## level

```perl
my $level = $heading->level;
```

Returns the level of the heading, an integer from 1 to 6.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), ["heading\_indexes" in Term::Fabulous::Document](../../Document.md#heading_indexes).
