# NAME

Term::Fabulous::Text::Style - Parse style strings such as "bold red on
\#202020"

# SYNOPSIS

```perl
use Term::Fabulous::Text::Style qw(parse_style style compose_styles apply_style);

my $style = parse_style('bold underline SteelBlue on #202020');
# { set => TB_BOLD | TB_UNDERLINE, clear => 0, color => [ 70, 130, 180, 255 ], background => [ 32, 32, 32, 255 ] }

my $plain = parse_style('not bold default');
# { set => 0, clear => TB_BOLD, color => [ 0, 0, 0, 0 ], background => undef }

my $same = style($style);    # a style hash is checked and copied, a string parsed

my $inner = compose_styles( $style, parse_style('not bold') );    # stacked: the later wins
# { set => TB_UNDERLINE, clear => TB_BOLD, color => [ 70, 130, 180, 255 ], background => [ 32, 32, 32, 255 ] }

my $look = apply_style( { attrs => TB_ITALIC, color => [ 220, 223, 228, 255 ], background => undef }, $style );
# { attrs => TB_ITALIC | TB_BOLD | TB_UNDERLINE, color => [ 70, 130, 180, 255 ], background => [ 32, 32, 32, 255 ] }
```

# DESCRIPTION

A _style_ is what a span of a [Term::Fabulous::Widget::RichText](../Widget/RichText.md)
adds to the look of the characters it covers: style bits to set or
clear, a text color and a background. It is written as a string of
words, in the manner of Python's `rich` library, or given as a hash.
This module turns both into one normalized hash, stacks such hashes
(["compose\_styles"](#compose_styles)) and applies one to a look (["apply\_style"](#apply_style)). These
two functions are the only place where style bits are combined:
[Term::Fabulous::Widget::RichText](../Widget/RichText.md) composes the styles of nested spans
with the first, and [Term::Fabulous::Render::Text](../Render/Text.md) paints each run of
a line with the second.

## Style strings

A style string is words separated by whitespace, in any order:

- `bold`, `italic`, `underline`, `reverse`, `dim`, `blink`, `strike`, `overline`, `conceal`

    Set the style bit of that name (the termbox2 attributes `TB_BOLD`,
    `TB_ITALIC`, `TB_UNDERLINE`, `TB_REVERSE`, `TB_DIM`, `TB_BLINK`,
    `TB_STRIKEOUT`, `TB_OVERLINE` and `TB_INVISIBLE` of
    [Term::Fabulous::Termbox](../Termbox.md)). `strikethrough` is the same as `strike`.
    Terminals show these with what their font has; a terminal may ignore
    some of them.

- `not WORD`

    Clear that style bit, so an inner span can switch off what an outer
    one set: `not bold`.

- A color

    The text color: any string [Term::Fabulous::Color](../Color.md) reads (see
    ["A string" in Term::Fabulous::Color](../Color.md#a-string)), such as a CSS color name in any case
    (`SteelBlue`, `steelblue`), `#ff8800`, `rgb(255, 136, 0)` or
    `hsl(32, 100%, 50%)`. `default` is the terminal's default color
    (alpha 0); the style words above win over a color of the same spelling
    (there is none among the CSS names).

- `on COLOR`

    The background, a color as above: `on #202020`, `on default`.

The last word wins where words contradict (`bold not bold` clears
bold). Unknown words die with the known ones.

## Style hashes

The normalized form has exactly these keys:

```perl
{
        set        => $bits,            # style bits to set
        clear      => $bits,            # style bits to clear
        color      => $rgba | undef,    # [ r, g, b, a ], undef leaves the color alone
        background => $rgba | undef,
}
```

Colors are `[r, g, b, a]` with alpha 0 for the terminal's default
color; `undef` means the style does not touch that color.

# FUNCTIONS

Nothing is exported by default.

## parse\_style

```perl
my $style = parse_style('bold red on #202020');
```

Parses a style string (see ["Style strings"](#style-strings)) into a style hash. An
unknown word, a `not` or `on` without its argument, `undef` or a
reference die with a message starting with
`Term::Fabulous::Text::Style:`.

## style

```perl
my $style = style($string_or_hash);
```

Returns a normalized style hash for a style string or a hash with any
of the keys of ["Style hashes"](#style-hashes); missing keys are 0 or `undef`, and
the colors may be in any format [Term::Fabulous::Color](../Color.md) accepts. The
result is a new hash. Unknown keys, invalid bits (not a non-negative
integer) and invalid colors die.

## compose\_styles

```perl
my $style = compose_styles( $outer, $inner, $innermost );
```

Stacks style hashes in order and returns the style hash they make
together, as if each were applied after the ones before it: a later
`set` bit wins over an earlier `clear` of the same bit and the other
way round (both stay recorded, so the result still clears what it must
clear), and a later color replaces an earlier one. No styles give the
style that touches nothing. Applying the result to a look gives the
same look as applying the styles one after the other. The given hashes
are not changed.

## apply\_style

```perl
my $look = apply_style( { attrs => $bits, color => $rgba, background => $rgba_or_undef }, $style );
```

Applies a style hash to a _look_, a hash of the termbox2 style bits
`attrs`, the text `color` and the `background`, and returns the new
look: the bits with `clear` removed and `set` added, and each color
replaced when the style has one. The given look is not changed. The
colors are passed through as they are, so they may be in any one form
as long as the look and the style agree: [Term::Fabulous::Render::Text](../Render/Text.md)
applies RichText runs whose colors are termbox attributes.

# SEE ALSO

[Term::Fabulous::Text::Markup](Markup.md), [Term::Fabulous::Widget::RichText](../Widget/RichText.md),
[Term::Fabulous::Color](../Color.md), [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md),
[Term::Fabulous::Termbox](../Termbox.md).
