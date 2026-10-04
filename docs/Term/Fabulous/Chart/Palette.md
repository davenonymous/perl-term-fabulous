# NAME

Term::Fabulous::Chart::Palette - Color palettes and color arithmetic for
the chart widgets

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Palette qw(palette_colors mix_rgb contrast_rgb chart_color);

my @dark_steps = palette_colors( default => 'dark' );    # 0x3987e5, 0xd95926, ...
my $faded      = mix_rgb( $dark_steps[0], 0x141923, 0.6 ); # 60 % of the way to the background
my $on_slice   = contrast_rgb(0xeda100);                   # dark text on yellow
my ( $rgb, $opacity ) = chart_color( $widget, color => '#3987e580' );
```

# DESCRIPTION

The functions the chart widgets ([Term::Fabulous::Widget::Chart](../Widget/Chart.md) and its
subclasses) use to pick, check and mix colors. Colors are passed around as
packed `0xRRGGBB` integers, the fastest form a canvas cell takes. All
functions are exported on request. To choose a palette for a chart, pass
its name (or an array of colors of your own) as the chart's `palette`;
see ["Colors and themes" in Term::Fabulous::Widget::Chart](../Widget/Chart.md#colors-and-themes) and the recipe
["Light backgrounds, palettes and colors of your own" in Term::Fabulous::Cookbook::ChartStyles](../Cookbook/ChartStyles.md#light-backgrounds-palettes-and-colors-of-your-own).
You need the functions below only for charts or widgets of your own.

## Palettes

A palette is an ordered list of eight colors. A chart gives its first
series (or its first slice) the first color, the second series the second,
and so on, and a series keeps its color when other series are removed. Each
palette has steps for dark and for light backgrounds; a chart chooses the
steps that suit its background (see ["theme" in Term::Fabulous::Widget::Chart](../Widget/Chart.md#theme)).

- `default`

    Blue, orange, aqua, yellow, magenta, green, violet, red: the palette a
    chart uses unless you choose another. The order keeps neighbors apart for
    readers with the common color vision deficiencies. On a dark background
    every color has at least 3:1 contrast to the background; on a light one,
    aqua, yellow and magenta have less (about 2:1 to 2.7:1), so use them
    there for fills and bars rather than for thin lines. Use this palette
    unless you have a reason not to.

- `classic`

    The colors of popular dark and light editor themes: softer blue, red, green,
    yellow and purple. They match the colors of the Term::Fabulous examples.

- `pastel`

    Light, soft colors; good for large fills such as pie slices and stacked
    areas on a dark background.

- `vivid`

    Saturated, bright colors for thin lines on a dark background.

Only `default` was checked for color vision deficiencies. With the other
palettes, and in general with more than four series, help readers with
labels: the legend, value labels, or different line styles and point
glyphs.

# FUNCTIONS

## palette\_colors

```perl
my @colors = palette_colors( $name, $mode );
```

The eight colors of a palette as packed integers. `$mode` is `dark` or
`light`. Dies for an unknown name or mode.

## palette\_names

The names of all palettes, sorted: `classic`, `default`, `pastel`,
`vivid`.

## is\_palette\_name

True for the name of a palette.

## chart\_color

```perl
my ( $rgb, $opacity ) = chart_color( $owner, $name, $color );
```

Reads a color in any format a canvas cell takes (see
["Colors" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#colors)): a packed `0xRRGGBB` integer, a
string such as `'#ff8800'`, `'#ff880080'`, `'rgb(255, 136, 0)'` or
`'hsl(32, 100%, 50%)'`, an array or hash reference, or a
[Term::Fabulous::Color](../Color.md) (such as `Term::Fabulous::Enum::WebColor->Tomato`).
Returns the color as a packed integer and its alpha as an opacity from 0 to
1\. Dies with `$owner` and `$name` in the message for anything else.

## mix\_rgb

```perl
my $mixed = mix_rgb( $from, $to, $amount );
```

The color `$amount` (0 to 1) of the way from `$from` to `$to`, channel
by channel. This is how translucent fills are drawn: the fill color mixed
into what is below it.

## luminance

The relative luminance of a color as WCAG 2 defines it, from 0 (black) to 1
(white).

## is\_light\_rgb

True when dark text has more contrast on the color than light text.

## contrast\_rgb

Near black (`0x111111`) for a light color, near white (`0xF5F5F5`) for a
dark one: the color of text written on it.

## ink\_colors

```perl
my $ink = ink_colors( $background, $mode );
# { title => ..., text => ..., label => ..., axis => ..., grid => ... }
```

The colors of a chart's chrome on a background: the title, the legend text,
the tick labels and axis titles, the axis lines and the grid lines. They are
mixed from the background and the ink of the mode (white on dark, near black
on light), so grid lines are always one shade off the background and labels
are recessive, whatever background the chart has.

## rgb\_hex

The `#rrggbb` string of a packed color.

# SEE ALSO

[Term::Fabulous::Widget::Chart](../Widget/Chart.md), ["CHARTS" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#charts),
[Term::Fabulous::Color](../Color.md).
