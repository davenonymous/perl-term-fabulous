# NAME

Term::Fabulous::Document::Mark - A formatted range of characters in the text of a block

# SYNOPSIS

```perl
use Term::Fabulous::Document::Mark;

# In the text "See perlfunc", make "perlfunc" (characters 4 to 11) bold:
my $bold = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'bold' );

# Or make it a link; the destination can be any value the program understands:
my $link = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'link', link => 'https://perldoc.perl.org/perlfunc' );

foreach my $mark ( $block->marks ) {
        say $mark->kind, ' from ', $mark->start, ' to ', $mark->end;
}
```

# DESCRIPTION

A mark records that a range of the text of a
[Term::Fabulous::Document::Block](Block.md) is formatted in some way. When a
parser removes the formatting from a paragraph, such as a bold phrase,
a code span or a link, it keeps the plain text in the block and
describes each formatted range with a mark: where the range starts and
ends, and what _kind_ of formatting it is.

Offsets are character offsets into the block's text, counted from 0, as
Perl's `substr` and `length` count them; they are not byte offsets
and not terminal columns. The start offset is the first character the
mark covers, and the end offset is exclusive: it is the offset of the
first character after the range. The characters a mark covers are
therefore `substr( $text, $mark->start, $mark->span_length )`.

A mark describes what a range _is_, not how it looks.
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) maps each kind to a style of
the current theme through a [Term::Fabulous::Document::Look](Look.md), so the
same document can be shown in any theme.

A mark is immutable: its parameters are checked when it is created and
never change afterwards.

## Kinds

Every kind except `link` must name a style of the look the view draws
with. The built-in look provides `bold`, `italic`, `strike`, `code`
and `file` for formatting within a paragraph (see
["KINDS" in Term::Fabulous::Document::Look](Look.md#kinds) for the full list). The mark
itself accepts any word as its kind; the view dies when it is given a
document (in `new` or `document`) with a mark whose kind its look
does not know. A format that
needs further kinds adds them with a subclass of the look (see
["BLOCK KINDS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#block-kinds)).

## Link marks

A mark of kind `link` carries the destination of the link in its
["link"](#link) attribute instead of naming a style. The destination can be
any defined value: a URL or a page name as a string, a hash reference
with several fields, or an object of the program. The view does not
interpret it. When the user follows the link, the view hands the value
back unchanged in the [LinkActivate](../Event/LinkActivate.md)
event, and the program decides what to do with it.

The view shows link marks as links of a [Term::Fabulous::Widget::RichText](../Widget/RichText.md),
so the link marks of a block must follow three rules that the mark and
the block do not check: a link mark must not be empty (`start` must be
less than `end`), it must not overlap another link mark of the same
block, and the link marks of a block must be given in the order of the
text (see ["links" in Term::Fabulous::Document::Block](Block.md#links)). The view dies when
it builds a block with an empty or overlapping link mark.

## Overlapping marks

Nested formatting produces marks that overlap, for example `bold` over
a whole phrase and `italic` over one word of it. Marks of other kinds
may overlap freely, and a link mark may overlap marks of other kinds.
The view applies the marks of a block in the order the block holds
them, so where two marks set the same attribute, the later one wins
(see ["marks" in Term::Fabulous::Document::Block](Block.md#marks)).

# CONSTRUCTOR

## new

```perl
my $mark = Term::Fabulous::Document::Mark->new( start => 0, end => 4, kind => 'bold' );
```

Creates a mark. Unknown parameters die, and so does a missing required
parameter. The parameters are:

- `start`, `end`

    Required. The offset of the first character the mark covers and the
    offset of the first character after it, as non-negative integers. An
    `end` less than `start` dies; an `end` equal to `start` gives an
    empty mark. Whether the range lies within the text is checked when the
    mark is given to a block (see ["new" in Term::Fabulous::Document::Block](Block.md#new)).

- `kind`

    Required. A word, made of letters, digits and underscores: `link`, or
    the name of a style of the view's look, such as `bold`, `italic`,
    `strike`, `code` or `file`. Anything else dies.

- `link`

    The destination of a link: any defined value. It is required for a mark
    of kind `link`, and giving a defined value for any other kind dies.

# METHODS

## start

```perl
my $offset = $mark->start;
```

Returns the character offset of the first character the mark covers.

## end

```perl
my $offset = $mark->end;
```

Returns the character offset of the first character after the range,
which is one more than the offset of the last character the mark
covers.

## span\_length

```perl
my $characters = $mark->span_length;
```

Returns the number of characters the mark covers, `end - start`.

## kind

```perl
my $kind = $mark->kind;    # 'bold', 'link', ...
```

Returns the kind of the mark.

## is\_link

```perl
if ( $mark->is_link ) { ... }
```

Returns 1 for a mark of kind `link`, and 0 for every other kind.

## link

```perl
my $destination = $mark->link;    # or undef
```

Returns the destination of a `link` mark, exactly as it was given to
the constructor, or `undef` for marks of other kinds.

# SEE ALSO

[Term::Fabulous::Document::Block](Block.md), [Term::Fabulous::Document::Look](Look.md),
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Event::LinkActivate](../Event/LinkActivate.md),
[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md).
