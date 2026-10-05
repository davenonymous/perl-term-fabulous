# NAME

Term::Fabulous::Color - An immutable RGBA color, parsed from many notations

# SYNOPSIS

```perl
use Term::Fabulous::Color;
use Term::Fabulous::Widget::Box;

# One constructor that understands every notation ...
my $purple = Term::Fabulous::Color->new( color => '#7c3aed' );
my $faded  = Term::Fabulous::Color->new( color => 'rgba(255, 0, 128, 0.5)' );
my $teal   = Term::Fabulous::Color->new( color => 'hsl(174, 72%, 56%)' );
my $blue   = Term::Fabulous::Color->new( color => [ 40, 80, 200 ] );
my $gray   = Term::Fabulous::Color->new( color => { r => 128, g => 128, b => 128, a => 255 } );

# ... and shortcuts for the common cases.
my $red    = Term::Fabulous::Color->rgb( 255, 0, 0 );
my $glass  = Term::Fabulous::Color->rgba( 255, 0, 0, 128 );
my $violet = Term::Fabulous::Color->hex('#7c3aed');
my $mint   = Term::Fabulous::Color->hsl( 150, 60, 70 );

# Derive new colors; the original never changes.
my $hover  = $purple->lighten(0.1);
my $shadow = $purple->darken(0.2);
my $mix    = $red->blend( $blue, 0.25 );

# Widgets take the object itself, or any of the formats new() accepts.
my $box = Term::Fabulous::Widget::Box->new( background_color => $shadow );
```

# DESCRIPTION

A color with red, green, blue and alpha (opacity) channels, each an
integer from 0 to 255. Color objects are immutable: methods such as
["lighten"](#lighten) and ["blend"](#blend) return a new object.

Term::Fabulous uses this class to parse every color given as a string:
colors in [KDL layout files](Layout.md), the colors of the
input widgets and the cell colors of a
[canvas](Widget/Canvas.md), and every widget color
(`background_color`, `border_color`, the `text_color` of a Text
widget, the input widget colors) takes a Color object or any input
["new"](#new) accepts. See ["COLORS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#colors).

`examples/colors.pl` shows one color written in six formats, colors
derived with ["darken"](#darken), ["lighten"](#lighten) and ["blend"](#blend), and backgrounds with
less and less alpha:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-colors.svg" alt="Six orange swatches written in different formats; a blue darkened, lightened and blended with white in steps; red swatches with alpha 255, 192, 128, 64 and 0 over a light panel; a line in the terminal's default text color"></p>
</div>

## Alpha

An alpha of 0 means "no color": a background with alpha 0 is not
painted, so whatever is below it shows through, and a text or foreground
color with alpha 0 uses the terminal default color. An alpha from 1 to 254
(see ["is\_translucent"](#is_translucent)) makes a widget background translucent: it is
blended with the colors below it when it is painted. Text and border
colors with such an alpha are drawn opaque. See
["Alpha and the terminal default color" in Term::Fabulous::Manual::Looks](Manual/Looks.md#alpha-and-the-terminal-default-color).

## Channel rules

Every channel is rounded to the nearest integer once, when the color is
built (an exact half rounds up), and the rounded value must be from 0 to
255\. So `255.4` becomes 255, `0.5` becomes 1 and `-0.4` becomes 0,
while `255.5` and `-1` die. Undefined values, non-numbers, NaN and
infinities die too. The error names the channel and the value:

```text
Term::Fabulous::Color: red must be a number in 0..255, got '300'
```

# CONSTRUCTOR

## new

```perl
my $color = Term::Fabulous::Color->new( color => $spec );
```

Builds a color from `$spec`. `color` is the only parameter and it is
required; unknown parameters die. `$spec` can be any of the following.

- A Term::Fabulous::Color object

    Its four channels are copied. Objects of subclasses work as well.

- An array reference

    `[ $r, $g, $b ]` or `[ $r, $g, $b, $a ]`. Alpha defaults to 255. Any
    other number of elements dies.

- A hash reference

    With exactly the keys `r`, `g`, `b` (and optionally `a`), or exactly
    `red`, `green`, `blue` (and optionally `alpha`). Alpha defaults to
    255\. Any other set of keys dies.

- A string

    In one of the notations below. The string must not have leading or
    trailing whitespace; whitespace after `(` and around the commas is
    allowed. The function names are lowercase. Three-digit hex such as
    `'#f00'` is not supported.

    | String             | Example                    | Meaning                           |
    | ------------------ | -------------------------- | --------------------------------- |
    | #rrggbb            | '#7c3aed', '7c3aed'        | hex, alpha 255; '#' is optional   |
    | #rrggbbaa          | '#7c3aed80'                | hex with alpha                    |
    | packed integer     | 0xFF8800, '16746496'       | 0xRRGGBB as one number, alpha 255 |
    | rgb(r, g, b)       | 'rgb(124, 58, 237)'        | channels 0..255, alpha 255        |
    | rgba(r, g, b, a)   | 'rgba(124, 58, 237, 0.5)'  | alpha as described below          |
    | hsl(h, s%, l%)     | 'hsl(262, 83%, 58%)'       | hue in degrees, alpha 255         |
    | hsla(h, s%, l%, a) | 'hsla(262, 83%, 58%, 50%)' | alpha as described below          |
    | web color name     | 'SteelBlue', 'steelblue'   | a CSS named color, alpha 255      |

    Hex digits may be upper or lower case. A string of digits only is a
    packed `0xRRGGBB` integer (the form the canvas drawing methods take as
    well), so a hex color that consists of digits only, such as
    `'123456'`, needs its `#`. A packed integer above `0xFFFFFF` dies.
    Channel values in `rgb()` and `rgba()` may have decimals; they are
    rounded (see ["Channel rules"](#channel-rules)).

    In `hsl()` and `hsla()`, the hue is in degrees and taken modulo 360,
    so `360` is the same as `0` and `-90` the same as `270`. Saturation
    and lightness are percentages from 0 to 100 and must be written with a
    `%` sign.

    The alpha of `rgba()` and `hsla()` is read according to how it is
    written, in the strings and in the ["rgba"](#rgba) and ["hsla"](#hsla) class methods
    alike:

    | Written as          | Example | Meaning              | Alpha |
    | ------------------- | ------- | -------------------- | ----: |
    | integer, no point   | 128     | channel value 0..255 |   128 |
    | number with a point | 0.5     | fraction 0..1        |   128 |
    | number with %       | 50%     | percentage 0..100    |   128 |

    Watch the difference between `1` and `1.0`: `'rgba(0, 0, 0, 1)'` has
    alpha 1 (almost fully transparent),
    while `'rgba(0, 0, 0, 1.0)'` has alpha 255. In Perl code, a number
    without a fractional part is written without a point when it becomes a
    string, so `->rgba( 0, 0, 0, 1.0 )` is alpha 1 as well; pass
    `'100%'` or `255` for opaque.

    A web color name is one of the 148 CSS named colors of
    [Term::Fabulous::Enum::WebColor](Enum/WebColor.md) (`Gray` and `Grey` spellings,
    `RebeccaPurple`), in any case: `'SteelBlue'`, `'steelblue'` and
    `'STEELBLUE'` are the same color. Where a name could also mean
    something else, the other meaning is looked up first: a palette token of
    a [theme](Theme.md) (`accent`, `text`, ...; none of them
    is a web color name) and the words of a
    [style string](Text/Style.md) (`bold`, `default`, ...).

    This grammar is the one of every color in Term::Fabulous: widget color
    parameters and accessors, canvas cells, KDL layout files, theme files
    and rich text markup.

Anything else (`undef`, other references or objects, unknown strings)
dies with the offending value in the message.

## rgb

```perl
my $color = Term::Fabulous::Color->rgb( $r, $g, $b );
```

Class method. An opaque color (alpha 255) from three channels from 0 to
255 (see ["Channel rules"](#channel-rules)).

## rgba

```perl
my $color = Term::Fabulous::Color->rgba( $r, $g, $b, $a );
```

Class method. Like ["rgb"](#rgb) with an explicit alpha, read with the alpha
grammar of the `rgba()` string (see ["new"](#new)): a bare integer is the
channel value from 0 to 255, a number with a decimal point a fraction
of 1, and a string ending in `%` a percentage.

## hex

```perl
my $color = Term::Fabulous::Color->hex('#7c3aed');
my $color = Term::Fabulous::Color->hex('7c3aed80');
```

Class method. A color from a six- or eight-digit hex string with an
optional leading `#`. Any other string dies, even one that ["new"](#new)
would accept.

## hsl

```perl
my $color = Term::Fabulous::Color->hsl( $hue, $saturation, $lightness );
```

Class method. An opaque color from a hue in degrees (taken modulo 360)
and saturation and lightness as plain numbers from 0 to 100 (no `%`
sign). The conversion is computed in floating point, and each channel
is rounded once at the end.

## hsla

```perl
my $color = Term::Fabulous::Color->hsla( $hue, $saturation, $lightness, $alpha );
```

Class method. Like ["hsl"](#hsl), plus an alpha read with the same grammar
as in ["rgba"](#rgba) and in the `hsla()` string: `->hsla( 0, 0, 0, 0.5 )`
and `->hsla( 0, 0, 0, '50%' )` give alpha 128, while
`->hsla( 0, 0, 0, 1 )` gives alpha 1, not opaque.

# METHODS

## red

```perl
my $r = $color->red;
```

The red channel, an integer from 0 to 255.

## green

```perl
my $g = $color->green;
```

The green channel, an integer from 0 to 255.

## blue

```perl
my $b = $color->blue;
```

The blue channel, an integer from 0 to 255.

## alpha

```perl
my $a = $color->alpha;
```

The alpha channel, an integer from 0 (transparent) to 255 (opaque).

## is\_translucent

```perl
if ( $color->is_translucent ) { ... }
```

True when the alpha is from 1 to 254: the color is neither "no color"
(alpha 0) nor opaque (alpha 255). A translucent background is blended
with what is below it; see ["Alpha"](#alpha).

## to\_rgba

```perl
my ( $r, $g, $b, $a ) = $color->to_rgba;
```

Returns the four channels as a list. Widgets take the Color object
itself; wrap the result in `[ ]` where a plain `[r, g, b, a]` array
is wanted.

## to\_hsl

```perl
my ( $hue, $saturation, $lightness ) = $color->to_hsl;
```

Returns hue (0 to 359), saturation and lightness (0 to 100) of the
color, each rounded to an integer. Alpha is ignored.

## lighten

```perl
my $brighter = $color->lighten(0.15);
```

Returns a color with more lightness in HSL terms. `$amount` is a
fraction added to the lightness: `0.15` adds 15 percentage points. The
result is clamped to 0% to 100% lightness, so `lighten(1)` is white.
Hue, saturation and alpha stay the same, and `lighten(0)` returns an
identical color. A negative amount darkens. Dies if `$amount` is not a
number.

## darken

```perl
my $shadow = $color->darken(0.15);
```

The same as `$color->lighten(-$amount)`.

## blend

```perl
my $mix = $color->blend( $other, $ratio );
```

Returns a mix of this color and `$other`, channel by channel, alpha
included: `$ratio` 0 gives this color, 1 gives `$other`, 0.5 the
middle. Channels of the result are rounded like every other channel
(see ["Channel rules"](#channel-rules)): black blended with white at 0.5 is
`(128, 128, 128)`. `$other` must be a Term::Fabulous::Color object
and `$ratio` a number from 0 to 1; anything else dies with a message
that names the offending argument.

## with\_alpha

```perl
my $translucent = $color->with_alpha(128);
```

Returns a copy with a different alpha channel (0 to 255, rounded as
described in ["Channel rules"](#channel-rules)).

## rgb\_int

```perl
my $packed = $color->rgb_int;    # 0xRRGGBB
```

The red, green and blue channels packed into one integer, `0xRRGGBB`.
This is also the fast way to give a color to the canvas drawing methods
(see ["Colors" in Term::Fabulous::Widget::Canvas](Widget/Canvas.md#colors)), but note that a packed
integer has no alpha channel.

## rgba\_int

```perl
my $packed = $color->rgba_int;   # 0xRRGGBBAA
```

All four channels packed into one integer, `0xRRGGBBAA`.

## rgb\_float

```perl
my ( $r, $g, $b ) = $color->rgb_float;
```

The red, green and blue channels scaled to the range 0 to 1.

## rgba\_float

```perl
my ( $r, $g, $b, $a ) = $color->rgba_float;
```

All four channels scaled to the range 0 to 1.

## hexString

```perl
my $hex = $color->hexString;     # '#7c3aedff'
```

The color as a lowercase `#rrggbbaa` string. Alpha is always included.

## ansi

```perl
print $color->ansi, 'colored text', "\e[0m";
```

The 24-bit ANSI escape sequence that sets this color as the foreground
color (`ESC [ 38 ; 2 ; r ; g ; b m`). Alpha is ignored.

## ansi\_bg

```perl
print $color->ansi_bg, ' ', "\e[0m";
```

The 24-bit ANSI escape sequence that sets this color as the background
color (`ESC [ 48 ; 2 ; r ; g ; b m`). Alpha is ignored.

## fg\_sgr

```perl
print $color->fg_sgr;
```

Like ["ansi"](#ansi), except that a color with alpha 0 returns `ESC [ 39 m`,
which switches back to the terminal's default foreground color.

## bg\_sgr

```perl
print $color->bg_sgr;
```

Like ["ansi\_bg"](#ansi_bg), except that a color with alpha 0 returns
`ESC [ 49 m`, which switches back to the terminal's default background
color.

## hsl\_to\_rgb

```perl
my ( $r, $g, $b ) = Term::Fabulous::Color->hsl_to_rgb( $hue, $saturation, $lightness );
```

Class method. Converts hue (degrees, taken modulo 360), saturation and
lightness (0 to 100) to red, green and blue (0 to 255), computed in
floating point and rounded once. Dies if saturation or lightness are
outside 0..100.

## rgb\_to\_hsl

```perl
my ( $hue, $saturation, $lightness ) = Term::Fabulous::Color->rgb_to_hsl( $r, $g, $b );
```

Class method. Converts red, green and blue (numbers from 0 to 255) to
hue (0 to 359) and saturation and lightness (0 to 100), each rounded to
an integer. Dies if a channel is outside 0..255.

# SEE ALSO

["COLORS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#colors), [Term::Fabulous::Render::Attr](Render/Attr.md),
["Colors" in Term::Fabulous::Widget::Canvas](Widget/Canvas.md#colors), [Term::Fabulous::Enum::WebColor](Enum/WebColor.md),
[Term::Fabulous::Theme](Theme.md),
["Switch themes at run time (built-in themes and a theme file)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#switch-themes-at-run-time-built-in-themes-and-a-theme-file).
