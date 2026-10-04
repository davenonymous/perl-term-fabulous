# NAME

Term::Fabulous::Render::Attr - Turn colors into termbox2 truecolor attributes

# SYNOPSIS

```perl
use Term::Fabulous::Render::Attr qw(color_attr clay_color cell_color_attr blended_bg_attr);
use Term::Fabulous::Color;

my $fg = color_attr( Term::Fabulous::Color->rgb( 0, 0, 0 ) );               # TB_HI_BLACK
my $bg = color_attr( clay_color( { r => 20, g => 25, b => 35, a => 255 } ) );  # 0x141923
my $cell_fg = cell_color_attr( fg => '#ffcc00' );                             # 0xFFCC00
my $dimmed  = blended_bg_attr( Term::Fabulous::Color->rgba( 0, 0, 0, 128 ), 0xFFFFFF );  # 0x7F7F7F
```

# DESCRIPTION

Most programs never use this module directly. It is used by the render
roles and the canvas widgets. Read it if you write your own cell target
or UI class (see [Term::Fabulous::Render](../Render.md)), or to understand the color
values returned by ["cell" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#cell) and
["pixel" in Term::Fabulous::Widget::PixelCanvas](../Widget/PixelCanvas.md#pixel).

termbox2 describes the colors of a cell with an integer _attribute_. In
truecolor mode, the one Term::Fabulous uses, an attribute holds a
24-bit color `0xRRGGBB` in its low bits and flags such as reverse video
in its high bits. Two values are special:

- `TB_DEFAULT` (0)

    The terminal's default color. This is what a color with alpha 0 ("no
    color") becomes.

- `TB_HI_BLACK`

    Opaque black. termbox2 would read the color `0x000000` as the default
    color, so black needs this flag of its own.

A color with an alpha from 1 to 254 is _translucent_. Terminals cannot
blend colors themselves, so ["blended\_bg\_attr"](#blended_bg_attr) and ["blended\_fg\_attr"](#blended_fg_attr)
compute the mix of such a color with the attribute below it. The
terminal default color has no RGB value to mix with; see those functions
for what happens then.

Truecolor is always available: termbox2 is compiled into the
distribution with 64-bit attributes (see [Term::Fabulous::Termbox](../Termbox.md)).

# FUNCTIONS

Nothing is exported by default. Import the functions you need by name.

## color\_attr

```perl
my $attr = color_attr($color);
```

Takes a [Term::Fabulous::Color](../Color.md) object and returns its attribute:
`TB_DEFAULT` when its alpha is 0, `TB_HI_BLACK` for black, and
the packed `0xRRGGBB` value otherwise. Results are cached (the cache is
emptied when it reaches 4096 entries).

## clay\_color

```perl
my $color = clay_color( $command->{renderData}{backgroundColor} );
```

Takes a color as it appears in Clay render commands, a hash reference
with the keys `r`, `g`, `b` and `a`, and returns the matching
[Term::Fabulous::Color](../Color.md) object. Results are cached, so a frame does not
parse colors it has seen before (the cache is emptied when it reaches
4096 entries). Dies unless the argument is a hash reference; invalid
channels die in [Term::Fabulous::Color](../Color.md).

## cell\_color\_attr

```perl
my $attr = cell_color_attr( fg => $color );
```

Converts the color argument of the canvas drawing methods (see
["Colors" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#colors)) into an attribute:

- `undef` returns `undef` ("no color of its own").
- A non-negative integer is taken as a packed `0xRRGGBB` color as it is;
`0` becomes `TB_HI_BLACK`. Integers above `0xFFFFFF` die.
- A [Term::Fabulous::Color](../Color.md) object, or anything
`Term::Fabulous::Color->new` accepts (`[r, g, b, a]`, `'#rrggbb'`,
`'hsl(...)'`, ...), goes through ["color\_attr"](#color_attr). A color with alpha 0
returns `undef`.

The first argument names the color in error messages, for example
`Term::Fabulous::Render::Attr: fg must be a packed 0xRRGGBB value, got 16777216`.
Invalid colors die in [Term::Fabulous::Color](../Color.md).

## blended\_bg\_attr

```perl
my $attr = blended_bg_attr( $color, $under );
```

The background attribute of a translucent [Term::Fabulous::Color](../Color.md)
painted over the background attribute `$under`: each channel of the
color is mixed with the channel below it by the color's alpha
(`over * alpha + under * (255 - alpha)`, divided by 255 and rounded),
and black becomes `TB_HI_BLACK`. When `$under` is the terminal
default color, which cannot be blended, the result is the color drawn
opaque (["color\_attr"](#color_attr)). Style flags in `$under` are kept. An opaque
color returns itself, a color with alpha 0 returns `$under`. Results
are cached like ["color\_attr"](#color_attr).

## blended\_fg\_attr

```perl
my $attr = blended_fg_attr( $color, $under );
```

The same mix for the foreground attribute `$under` of a glyph that a
translucent background is painted over, so that the glyph shows through
tinted. A terminal-default foreground cannot be blended and is returned
unchanged; style flags such as `TB_REVERSE` are kept.

# SEE ALSO

[Term::Fabulous::Color](../Color.md), [Term::Fabulous::Render](../Render.md),
["COLORS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#colors).
