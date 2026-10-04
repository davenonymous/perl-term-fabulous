# NAME

Term::Fabulous::Enum::WebColor - The CSS named colors as
Term::Fabulous::Color objects

# SYNOPSIS

```perl
use Term::Fabulous::Enum::WebColor;

my $tomato = Term::Fabulous::Enum::WebColor->Tomato;    # a Term::Fabulous::Color
$box->background_color($tomato);                         # widgets take the object itself
$canvas->fill( 0, 0, 10, 2, ' ', undef, Term::Fabulous::Enum::WebColor->MidnightBlue );

my $color = Term::Fabulous::Enum::WebColor->from_name('SteelBlue');    # undef for unknown names
my @all   = Term::Fabulous::Enum::WebColor->values;                     # 148 colors, AliceBlue first
```

# DESCRIPTION

An [Object::PadX::Enum](https://metacpan.org/pod/Object%3A%3APadX%3A%3AEnum) enumeration of the 148 named colors of CSS
(CSS Color Module Level 4, including the `Gray`/`Grey` spellings and
`RebeccaPurple`). Every item is a [Term::Fabulous::Color](../Color.md) with alpha
255, so it has all of that class's methods: `to_rgba`, `rgb_int`,
`lighten`, `blend` and so on. Items are singletons; derived colors
such as `->Red->with_alpha(128)` are new, plain
Term::Fabulous::Color objects.

The item names are in PascalCase, as the other enumerations of
Term::Fabulous, and `from_name` is case sensitive: `'SteelBlue'` is
found, `'steelblue'` is not. Color names as strings, such as `'red'`, are
not accepted by ["new" in Term::Fabulous::Color](../Color.md#new) or in KDL layouts; use
`Term::Fabulous::Enum::WebColor->Red->hexString` or the hex value
there. `examples/web-colors.pl` shows all of the colors in a grid.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-web-colors.svg" alt="A grid of color swatches with their hex values and names, and a dropdown to sort them"></p>
</div>

# METHODS

## values

```perl
my @colors = Term::Fabulous::Enum::WebColor->values;
```

Class method. All items in the order of the table below.

## from\_name

```perl
my $color = Term::Fabulous::Enum::WebColor->from_name('Tomato');
```

Class method. The item with that exact name, or `undef`.

## from\_ordinal

```perl
my $color = Term::Fabulous::Enum::WebColor->from_ordinal(0);    # AliceBlue
```

Class method. The item at a position of ["values"](#values), counted from 0, or
`undef` when there is none.

## name

```perl
say Term::Fabulous::Enum::WebColor->Tomato->name;    # Tomato
```

The name of an item.

## ordinal

```perl
my $position = Term::Fabulous::Enum::WebColor->Tomato->ordinal;
```

The position of an item in ["values"](#values), counted from 0.

Every item also has all methods of [Term::Fabulous::Color](../Color.md).

# COLORS

| Name                 | Value   |
| -------------------- | ------- |
| AliceBlue            | #f0f8ff |
| AntiqueWhite         | #faebd7 |
| Aqua                 | #00ffff |
| Aquamarine           | #7fffd4 |
| Azure                | #f0ffff |
| Beige                | #f5f5dc |
| Bisque               | #ffe4c4 |
| Black                | #000000 |
| BlanchedAlmond       | #ffebcd |
| Blue                 | #0000ff |
| BlueViolet           | #8a2be2 |
| Brown                | #a52a2a |
| BurlyWood            | #deb887 |
| CadetBlue            | #5f9ea0 |
| Chartreuse           | #7fff00 |
| Chocolate            | #d2691e |
| Coral                | #ff7f50 |
| CornflowerBlue       | #6495ed |
| Cornsilk             | #fff8dc |
| Crimson              | #dc143c |
| Cyan                 | #00ffff |
| DarkBlue             | #00008b |
| DarkCyan             | #008b8b |
| DarkGoldenRod        | #b8860b |
| DarkGray             | #a9a9a9 |
| DarkGreen            | #006400 |
| DarkGrey             | #a9a9a9 |
| DarkKhaki            | #bdb76b |
| DarkMagenta          | #8b008b |
| DarkOliveGreen       | #556b2f |
| DarkOrange           | #ff8c00 |
| DarkOrchid           | #9932cc |
| DarkRed              | #8b0000 |
| DarkSalmon           | #e9967a |
| DarkSeaGreen         | #8fbc8f |
| DarkSlateBlue        | #483d8b |
| DarkSlateGray        | #2f4f4f |
| DarkSlateGrey        | #2f4f4f |
| DarkTurquoise        | #00ced1 |
| DarkViolet           | #9400d3 |
| DeepPink             | #ff1493 |
| DeepSkyBlue          | #00bfff |
| DimGray              | #696969 |
| DimGrey              | #696969 |
| DodgerBlue           | #1e90ff |
| FireBrick            | #b22222 |
| FloralWhite          | #fffaf0 |
| ForestGreen          | #228b22 |
| Fuchsia              | #ff00ff |
| Gainsboro            | #dcdcdc |
| GhostWhite           | #f8f8ff |
| Gold                 | #ffd700 |
| GoldenRod            | #daa520 |
| Gray                 | #808080 |
| Green                | #008000 |
| GreenYellow          | #adff2f |
| Grey                 | #808080 |
| HoneyDew             | #f0fff0 |
| HotPink              | #ff69b4 |
| IndianRed            | #cd5c5c |
| Indigo               | #4b0082 |
| Ivory                | #fffff0 |
| Khaki                | #f0e68c |
| Lavender             | #e6e6fa |
| LavenderBlush        | #fff0f5 |
| LawnGreen            | #7cfc00 |
| LemonChiffon         | #fffacd |
| LightBlue            | #add8e6 |
| LightCoral           | #f08080 |
| LightCyan            | #e0ffff |
| LightGoldenRodYellow | #fafad2 |
| LightGray            | #d3d3d3 |
| LightGreen           | #90ee90 |
| LightGrey            | #d3d3d3 |
| LightPink            | #ffb6c1 |
| LightSalmon          | #ffa07a |
| LightSeaGreen        | #20b2aa |
| LightSkyBlue         | #87cefa |
| LightSlateGray       | #778899 |
| LightSlateGrey       | #778899 |
| LightSteelBlue       | #b0c4de |
| LightYellow          | #ffffe0 |
| Lime                 | #00ff00 |
| LimeGreen            | #32cd32 |
| Linen                | #faf0e6 |
| Magenta              | #ff00ff |
| Maroon               | #800000 |
| MediumAquaMarine     | #66cdaa |
| MediumBlue           | #0000cd |
| MediumOrchid         | #ba55d3 |
| MediumPurple         | #9370db |
| MediumSeaGreen       | #3cb371 |
| MediumSlateBlue      | #7b68ee |
| MediumSpringGreen    | #00fa9a |
| MediumTurquoise      | #48d1cc |
| MediumVioletRed      | #c71585 |
| MidnightBlue         | #191970 |
| MintCream            | #f5fffa |
| MistyRose            | #ffe4e1 |
| Moccasin             | #ffe4b5 |
| NavajoWhite          | #ffdead |
| Navy                 | #000080 |
| OldLace              | #fdf5e6 |
| Olive                | #808000 |
| OliveDrab            | #6b8e23 |
| Orange               | #ffa500 |
| OrangeRed            | #ff4500 |
| Orchid               | #da70d6 |
| PaleGoldenRod        | #eee8aa |
| PaleGreen            | #98fb98 |
| PaleTurquoise        | #afeeee |
| PaleVioletRed        | #db7093 |
| PapayaWhip           | #ffefd5 |
| PeachPuff            | #ffdab9 |
| Peru                 | #cd853f |
| Pink                 | #ffc0cb |
| Plum                 | #dda0dd |
| PowderBlue           | #b0e0e6 |
| Purple               | #800080 |
| RebeccaPurple        | #663399 |
| Red                  | #ff0000 |
| RosyBrown            | #bc8f8f |
| RoyalBlue            | #4169e1 |
| SaddleBrown          | #8b4513 |
| Salmon               | #fa8072 |
| SandyBrown           | #f4a460 |
| SeaGreen             | #2e8b57 |
| SeaShell             | #fff5ee |
| Sienna               | #a0522d |
| Silver               | #c0c0c0 |
| SkyBlue              | #87ceeb |
| SlateBlue            | #6a5acd |
| SlateGray            | #708090 |
| SlateGrey            | #708090 |
| Snow                 | #fffafa |
| SpringGreen          | #00ff7f |
| SteelBlue            | #4682b4 |
| Tan                  | #d2b48c |
| Teal                 | #008080 |
| Thistle              | #d8bfd8 |
| Tomato               | #ff6347 |
| Turquoise            | #40e0d0 |
| Violet               | #ee82ee |
| Wheat                | #f5deb3 |
| White                | #ffffff |
| WhiteSmoke           | #f5f5f5 |
| Yellow               | #ffff00 |
| YellowGreen          | #9acd32 |

# SEE ALSO

[Term::Fabulous::Color](../Color.md), [Object::PadX::Enum](https://metacpan.org/pod/Object%3A%3APadX%3A%3AEnum),
["COLORS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#colors).
