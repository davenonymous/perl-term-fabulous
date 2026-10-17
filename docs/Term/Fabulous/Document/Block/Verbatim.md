# NAME

Term::Fabulous::Document::Block::Verbatim - A verbatim paragraph: code, shown as it is

# SYNOPSIS

```perl
my $code = Term::Fabulous::Document::Block::Verbatim->new( text => "my \$x = 1;\nsay \$x;", language => 'perl' );
say for $code->lines;
```

# DESCRIPTION

A verbatim paragraph of a document, usually code. Its text is shown
exactly as written: the lines are kept, formatting codes are not
interpreted, and nothing wraps. The parser is expected to remove the
indentation all lines share and to expand tabs.

The `language` names what the code is written in, for a syntax
highlighter (see ["highlighter" in Term::Fabulous::Widget::CodeBlock](../../Widget/CodeBlock.md#highlighter)).

# CONSTRUCTOR

## new

```perl
my $code = Term::Fabulous::Document::Block::Verbatim->new( text => 'ls -l', language => 'shell' );
```

The parameters of ["new" in Term::Fabulous::Document::Block](../Block.md#new) plus:

- `language`

    `undef` (the default), or the name of the language, a non-empty
    string.

A verbatim block has no marks: giving any dies.

# METHODS

The methods of [Term::Fabulous::Document::Block](../Block.md), whose
[kind](../Block.md#kind) is `verbatim`, plus:

## language

```perl
my $language = $code->language;    # 'perl', or undef
```

The language, or `undef` when the document names none.

## lines

```perl
my @lines = $code->lines;
```

The lines of the text, without line ends.

## body\_rows, row\_of\_character

A row per line, whatever the columns; a character is on the row of its
line.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Widget::CodeBlock](../../Widget/CodeBlock.md).
