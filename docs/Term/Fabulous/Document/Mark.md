# NAME

Term::Fabulous::Document::Mark - A kind of styling over a range of a block's text

# SYNOPSIS

```perl
use Term::Fabulous::Document::Mark;

# "See perlfunc" with "perlfunc" bold:
my $bold = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'bold' );

# ... or a link, to whatever the program's links are:
my $link = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'link', link => 'https://perldoc.perl.org/perlfunc' );

foreach my $mark ( $block->marks ) {
        say $mark->kind, ' from ', $mark->start, ' to ', $mark->end;
}
```

# DESCRIPTION

A mark is what a parser leaves behind once it has taken the formatting
of a paragraph apart: the range of characters a bold phrase, a code
span or a link covered in the text of a [Term::Fabulous::Document::Block](Block.md),
and what _kind_ of thing it is. Marks say what a range is, not how it
looks; [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) turns the kinds into
styles of the current theme with a [Term::Fabulous::Document::Look](Look.md),
so the same document can be shown in any theme.

Every kind but `link` names a style of the look the view draws with;
the look of a view dies for a kind it does not know (see
["KINDS" in Term::Fabulous::Document::Look](Look.md#kinds)). A `link` mark carries the
link's destination instead, any defined value the program gives it: a
string, or an object of the program. The view hands it back in the
[LinkActivate](../Event/LinkActivate.md) event when the user
follows the link.

Nested formatting gives marks that overlap: `bold` over a whole
phrase and `italic` over one word of it. The marks of a block are in
the order the parser opened them.

A mark is a value: it is checked when it is created and never changes.

# CONSTRUCTOR

## new

```perl
my $mark = Term::Fabulous::Document::Mark->new( start => 0, end => 4, kind => 'bold' );
```

Unknown parameters die. The parameters:

- `start`, `end`

    Required. The character offsets of the first character the mark
    covers and of the one after the last: non-negative integers with
    `start <= end`.

- `kind`

    Required. A word (letters, digits and underscores): `link`, or the
    name of a style of the view's look, such as `bold`, `italic`,
    `code`, `file` or `strike`.

- `link`

    The destination, any defined value; required for `link` marks and
    refused for the others.

# METHODS

## start

```perl
my $offset = $mark->start;
```

The offset of the first character the mark covers.

## end

```perl
my $offset = $mark->end;
```

The offset after the last character the mark covers.

## span\_length

```perl
my $characters = $mark->span_length;
```

The number of characters the mark covers, `end - start`.

## kind

```perl
my $kind = $mark->kind;    # 'bold', 'link', ...
```

The kind.

## is\_link

```perl
if ( $mark->is_link ) { ... }
```

1 for a `link` mark, 0 otherwise.

## link

```perl
my $destination = $mark->link;    # or undef
```

The destination of a `link` mark, `undef` for the other kinds.

# SEE ALSO

[Term::Fabulous::Document::Block](Block.md), [Term::Fabulous::Document::Look](Look.md),
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md).
