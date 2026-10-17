# NAME

Term::Fabulous::Document::Block::Verbatim - A verbatim block: code, shown exactly as written

# SYNOPSIS

```perl
my $code = Term::Fabulous::Document::Block::Verbatim->new( text => "my \$x = 1;\nsay \$x;", language => 'perl' );
say for $code->lines;
```

# DESCRIPTION

A verbatim block holds a verbatim paragraph of a document, usually
code. The document view shows its text exactly as written: the lines
are kept, nothing in the text is interpreted as formatting, and lines
are never wrapped. A line wider than the view is cut off at the edge,
and the view scrolls all its verbatim blocks sideways together (see
[Term::Fabulous::Widget::CodeBlock](../../Widget/CodeBlock.md)).

The parser prepares the text: it separates the lines with `"\n"`,
removes the indentation that all lines share, and expands tabs to
spaces, because the code block shows a tab as a single space. The text
should not end with `"\n"`, which would add an empty last line.

The optional `language` names the language the code is written in.
The view passes it, together with the code, to its syntax highlighter
(see ["highlighter" in Term::Fabulous::Widget::DocumentView](../../Widget/DocumentView.md#highlighter) and
["highlighter" in Term::Fabulous::Widget::CodeBlock](../../Widget/CodeBlock.md#highlighter)).

# CONSTRUCTOR

## new

```perl
my $code = Term::Fabulous::Document::Block::Verbatim->new( text => 'ls -l', language => 'shell' );
```

Creates a verbatim block. It accepts the parameters of
["new" in Term::Fabulous::Document::Block](../Block.md#new), plus:

- `language`

    `undef` (the default), or the name of the language as a non-empty
    string. An empty string or a reference dies.

A verbatim block cannot have marks: giving a non-empty `marks` array
dies. The view still highlights search matches in the code.

# METHODS

A verbatim block has the methods of [Term::Fabulous::Document::Block](../Block.md);
its [kind](../Block.md#kind) is `verbatim`. It
adds or overrides these methods:

## language

```perl
my $language = $code->language;    # 'perl', or undef
```

Returns the language of the code, or `undef` when the source names
none.

## lines

```perl
my @lines = $code->lines;
```

Returns the lines of the text, split at `"\n"`, without the line
breaks. A text that ends with `"\n"` has an empty last line, and an
empty text is one empty line, the row the code block shows for it.

## body\_rows, row\_of\_character

```perl
my $rows = $code->body_rows($columns);
my $row  = $code->row_of_character( $offset, $columns );
```

Because code does not wrap, the width does not matter: `body_rows`
returns the number of ["lines"](#lines), and `row_of_character` returns the
number of line breaks before the character offset, which is the index
of the line that contains the character.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Widget::CodeBlock](../../Widget/CodeBlock.md).
