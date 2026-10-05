# NAME

Term::Fabulous::Text::Style - Parse style strings such as "bold red on
\#202020"

# SYNOPSIS

```perl
use Term::Fabulous::Text::Style qw(parse_style style apply_style);

my $style = parse_style('bold underline SteelBlue on #202020');
# { set => TB_BOLD | TB_UNDERLINE, clear => 0, color => [ 70, 130, 180, 255 ], background => [ 32, 32, 32, 255 ] }

my $plain = parse_style('not bold default');
# { set => 0, clear => TB_BOLD, color => [ 0, 0, 0, 0 ], background => undef }

my $same = style($style);    # a style hash is checked and copied, a string parsed

my $look = apply_style( { attrs => TB_ITALIC, color => [ 220, 223, 228, 255 ], background => undef }, $style );
# { attrs => TB_ITALIC | TB_BOLD | TB_UNDERLINE, color => [ 70, 130, 180, 255 ], background => [ 32, 32, 32, 255 ] }
```

# DESCRIPTION

A _style_ is what a span of a [Term::Fabulous::Widget::RichText](../Widget/RichText.md)
adds to the look of the characters it covers: style bits to set or
clear, a text color and a background. It is written as a string of
words, in the manner of Python's `rich` library, or given as a hash.
This module turns both into one normalized hash, and applies such a
hash to a look.

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

    The text color: a CSS color name in any case (`SteelBlue`,
    `steelblue`; the names of [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md)), or any
    string [Term::Fabulous::Color](../Color.md) reads, such as `#ff8800`,
    `rgb(255, 136, 0)` or `hsl(32, 100%, 50%)`. `default` is the
    terminal's default color (alpha 0).

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

## apply\_style

```perl
my $look = apply_style( { attrs => $bits, color => $rgba, background => $rgba_or_undef }, $style );
```

Applies a style hash to a _look_, a hash of the termbox2 style bits
`attrs`, the text `color` and the `background`, and returns the new
look: the bits with `clear` removed and `set` added, and each color
replaced when the style has one. The given look is not changed.

# SEE ALSO

[Term::Fabulous::Text::Markup](Markup.md), [Term::Fabulous::Widget::RichText](../Widget/RichText.md),
[Term::Fabulous::Color](../Color.md), [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md),
[Term::Fabulous::Termbox](../Termbox.md).
