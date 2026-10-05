# NAME

Term::Fabulous::Widget::RichText - Text with styled spans: bold words,
colored phrases, highlighted ranges

# SYNOPSIS

```perl
use Term::Fabulous::Widget::RichText;

# Markup in the syntax of Python's rich library:
my $hint = Term::Fabulous::Widget::RichText->new(
        markup => 'Press [bold]Enter[/] to save, [bold red]Esc[/] to leave. [dim]Unsaved changes are lost.[/]',
);

# Or text and spans:
my $line = Term::Fabulous::Widget::RichText->new(
        text  => 'error: file not found',
        spans => [ [ 0, 6, 'bold red' ] ],
);
$line->stylize( 'underline', 7, 11 );    # "file"
$line->stylize('on #3a3f4b');            # the whole text
```

# DESCRIPTION

A RichText is a [Term::Fabulous::Widget::Text](Text.md) whose characters can
differ in look: a _span_ covers a range of the text and sets or
clears style bits (bold, italic, underline, reverse, dim, blink,
strike, overline, conceal), a text color and a background for the
characters it covers. Clay lays the text out exactly like a Text,
wrapping and aligning it; the renderer then paints each wrapped line
with the spans applied. Everything a Text does, a RichText does too:
`text_color`, `bold`, `italic` and `underline` are the base look
of the whole text, and a span changes it where the span lies.

Spans are given as `[ $start, $end, $style ]`: the character offsets
of the first character and of the one after the last, and a style
string or hash of [Term::Fabulous::Text::Style](../Text/Style.md) (`'bold red on
\#202020'`). They may overlap: later spans win where they do. A span
boundary inside a grapheme cluster (a letter with a combining accent,
an emoji with a modifier) snaps to the cluster.

Markup writes the same thing inline: `[bold]Enter[/]`; see
[Term::Fabulous::Text::Markup](../Text/Markup.md) for the syntax.

The painter of a RichText needs [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) 0.05 or later, which
tells it where every wrapped line starts in the text.

# CONSTRUCTOR

## new

```perl
my $text = Term::Fabulous::Widget::RichText->new(%parameters);
```

All parameters of ["new" in Term::Fabulous::Widget::Text](Text.md#new), plus:

- `spans`

    An array reference of spans `[ $start, $end, $style ]`. Default:
    `[]`. Offsets are non-negative integers with
    `$start <= $end <= length $text`; `$style` is a style string or
    hash. Anything else dies.

- `markup`

    A string in the markup syntax of [Term::Fabulous::Text::Markup](../Text/Markup.md), which
    gives both the text and the spans; it cannot be given together with
    `text` or `spans`. Invalid markup dies.

# METHODS

The methods of [Term::Fabulous::Widget::Text](Text.md), plus:

## text

```perl
$text->text('Plain again');
```

As for a Text, and setting it drops every span and the markup, because
the spans pointed into the old text.

## markup

```perl
my $markup = $text->markup;    # undef when the text was not given as markup
$text->markup('[bold]New[/] text');
```

Accessor. Without an argument it returns the markup the text and spans
were last set from, or `undef` when they were given or changed
directly. With an argument it replaces the text and the spans with
what the markup says, and returns the markup. Invalid markup dies and
leaves the widget as it was. The change shows in the next frame.

## spans

```perl
my $spans = $text->spans;    # [ [ 0, 6, { set => ..., clear => ..., color => ..., background => ... } ], ... ]
```

The spans, in the order they apply, each with its normalized style
hash (see ["Style hashes" in Term::Fabulous::Text::Style](../Text/Style.md#style-hashes)). The result is
a copy.

## stylize

```perl
$text->stylize( 'bold red', 0, 6 );
$text->stylize('on #3a3f4b');    # the whole text
```

Adds a span after the existing ones, so it wins where they overlap.
`$start` defaults to 0, `$end` to the length of the text. Returns
the widget, so calls chain. Invalid offsets or styles die. The change
shows in the next frame.

## clear\_spans

```perl
$text->clear_spans;
```

Drops every span, keeping the text. Returns the widget.

## line\_styles

```perl
my $runs = $text->line_styles( $offset, $length );
```

Used by the renderer ([Term::Fabulous::Render::Text](../Render/Text.md)) for each wrapped
line: the characters `[ $offset, $offset + $length )` of the text cut
into runs of one look, as
`[ $characters, $set, $clear, $fg_attr, $bg_attr ]`: the number of
characters, the termbox2 style bits the runs's spans set and clear,
and the text and background attributes they give it, `undef` where
the base look stays. The runs are computed once per change of the
text or the spans.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Text](Text.md#kdl-properties), plus
`markup`:

```kdl
RichText "hint" {
        markup "Press [bold]Enter[/] to save"
}
```

`markup` and `text` replace each other: whichever comes last wins.
Spans cannot be given in KDL other than through markup.

# SEE ALSO

[Term::Fabulous::Widget::Text](Text.md), [Term::Fabulous::Text::Style](../Text/Style.md),
[Term::Fabulous::Text::Markup](../Text/Markup.md), ["TEXT" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#text).
