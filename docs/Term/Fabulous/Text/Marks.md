# NAME

Term::Fabulous::Text::Marks - The spans, highlights and links of one text

# SYNOPSIS

```perl
use Term::Fabulous::Text::Marks;
use Term::Fabulous::Theme;

my $marks = Term::Fabulous::Text::Marks->new(
        owner => 'My::Widget',
        text  => 'Read the manual first.',
        spans => [ [ 0, 4, 'bold' ] ],
        links => [ [ 9, 15, 'manual' ] ],
);
$marks->add_span( 'italic', 16, 21 );
$marks->set_highlights( [ [ 9, 15, 'on warning' ] ] );    # not content

foreach my $run ( @{ $marks->runs( theme => Term::Fabulous::Theme->default ) } ) {
        my ( $from, $to, $style ) = @$run;    # a style hash, tokens resolved
}
```

# DESCRIPTION

The marks of one text: the _spans_ a program styles it with, the
_highlights_ a search paints over them, and the _links_. Every range
is `[ $start, $end, ... ]` in characters, `$end` excluded, checked
against the text, with error messages worded alike for spans,
highlights and links; styles are style hashes of
[Term::Fabulous::Text::Style](Style.md). Readers return copies.

The marks count the changes of their content in ["content\_revision"](#content_revision):
the text, the spans and the links. Highlights are not content: a search
that marks what it found does not make the offsets it recorded stale.

["runs"](#runs) cuts the text where ranges start and end and stacks the styles
that cover each piece. [Term::Fabulous::Widget::Text](../Widget/Text.md) and
[Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md) keep their marks here, present them
through [Term::Fabulous::Role::MarkedText](../Role/MarkedText.md), and turn the runs into the
tuples their renderers paint with.

Error messages start with the `owner`, the class of the widget the
marks belong to.

# CONSTRUCTOR

## new

```perl
my $marks = Term::Fabulous::Text::Marks->new( owner => ref($self), text => $text, spans => \@spans, links => \@links );
```

`owner` (required) is the name the messages start with. `text` is the
string (default `''`), `spans` an array reference of
`[ $start, $end, $style ]` and `links` one of
`[ $start, $end, $target ]` (both default empty). Dies as ["set\_spans"](#set_spans)
and ["add\_link"](#add_link) do, and for `links` that are not an array reference
(`links must be an array reference of [start, end, target], got ...`)
or an entry that is not `[ $start, $end, $target ]`
(`a link is [start, end, target], got ...`). The content revision
starts at 0.

# METHODS

## text

```perl
my $text = $marks->text;
```

The text.

## set\_text

```perl
$marks->set_text($new);
```

Replaces the text and drops every span, highlight and link, which
pointed into the old one. Counts as a change. Returns the marks.

## content\_revision

```perl
my $revision = $marks->content_revision;
```

A number that grows with every change of the text, the spans or the
links (also one that sets them to what they were), and never with the
highlights.

## has\_marks

1 when the text has any span, highlight or link, else 0.

## spans

```perl
my $spans = $marks->spans;    # [ [ $start, $end, \%style ], ... ]
```

A copy of the spans, in the order they stack.

## set\_spans

```perl
$marks->set_spans( [ [ 0, 4, 'bold' ] ] );
```

Replaces the spans. Counts as a change. Returns the marks. Dies for
anything but an array reference (`spans must be an array reference of
[start, end, style]`), for an entry that is not
`[ $start, $end, $style ]` (`a span is [start, end, style]`), for
offsets that are not non-negative integers, for an end before its start
(`span end 0 lies before its start 1`) or past the text
(`span end 3 lies past the text (2 characters)`), and for a style
["style" in Term::Fabulous::Text::Style](Style.md#style) does not read.

## add\_span

```perl
$marks->add_span( 'underline', 5, 9 );
$marks->add_span('dim');                # the whole text
```

Appends a span from `$start` (default 0) up to `$end` (default the end
of the text), checked as by ["set\_spans"](#set_spans). Counts as a change. Returns
the marks.

## highlights

```perl
my $highlights = $marks->highlights;
```

A copy of the highlights, which are painted over the spans.

## set\_highlights

```perl
$marks->set_highlights( [ [ 3, 5, 'on accent' ] ] );
```

Replaces the highlights, checked like spans (with `highlight` in the
messages). Not a change of the content. Returns the marks.

## check\_spans

```perl
my @spans = $marks->check_spans( 'highlighter span' => $result );
```

Checked copies of ranges given by someone else, with the styles
normalized, in the wording of ["set\_spans"](#set_spans) with `$what` in place of
`span`. For ranges a widget stacks with ["runs"](#runs) without keeping them
here, such as the spans of a syntax highlighter.

## links

```perl
my $links = $marks->links;    # [ [ $start, $end, $target ], ... ]
```

A copy of the links, ordered by their start, none overlapping another.

## link\_count

The number of links.

## link\_at

```perl
my $index = $marks->link_at($offset);
```

The index of the link the character at the offset lies in, or
`undef`. An offset that is not a non-negative integer dies.

## add\_link

```perl
my $index = $marks->add_link( $target, 9, 15 );
```

Puts a link from `$start` (default 0) up to `$end` (default the end of
the text) in its place among the links and returns its index there, so
that a widget can keep track of a selected link. Counts as a change.
Dies for an undefined target (`a link needs a target`), an empty range
(`a link must not be empty, got 2 to 2`), a range that overlaps a link
(`the link 10 to 14 overlaps the link 4 to 12`) and offsets as for
spans (with `link`).

## clear\_links

```perl
$marks->clear_links;
```

Removes every link. Counts as a change. Returns the marks.

## runs

```perl
my $runs = $marks->runs( theme => $theme, under => \@ranges, over => \@ranges );
```

The text cut at every start and end of a range, as
`[ [ $from, $to, \%style ], ... ]` from 0 to the end of the text, in
order, each piece with the styles of the ranges that cover it composed
in this order (see ["compose\_styles" in Term::Fabulous::Text::Style](Style.md#compose_styles)): the
`under` ranges, the spans, the highlights, the `over` ranges, each
list in its own order; palette tokens are resolved against `theme`
(["resolve\_style" in Term::Fabulous::Text::Style](Style.md#resolve_style)). A piece no range covers
has the neutral style. `under` and `over` are optional and not checked
here: pass ranges with normalized style hashes, as ["check\_spans"](#check_spans)
returns them. A code block stacks its highlighter's spans under the
program's, a text the looks of its links over the highlights. Empty
ranges cover nothing. An empty text has no runs. The work is one sweep
over the boundaries. Dies without a `theme` or with another option.

# SEE ALSO

[Term::Fabulous::Text::Style](Style.md), [Term::Fabulous::Text::Markup](Markup.md),
[Term::Fabulous::Widget::Text](../Widget/Text.md), [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md),
[Term::Fabulous::Role::MarkedText](../Role/MarkedText.md).
