# NAME

Term::Fabulous::Chart::Format - Number and date labels of charts

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Format qw(number_formatter format_value time_formatter);

my $label = number_formatter( 'auto', 0.25, 2 );    # ticks 0.25 apart up to 2
say $label->(1.5);                                  # 1.50
say number_formatter( 'auto', 5000, 40000 )->(25000);    # 25k
say number_formatter( 'percent', 0.1, 1 )->(0.3);        # 30%
say format_value(1234.5678);                             # 1234.6
say time_formatter( '%H:%M', 1 )->(0);                   # 00:00
```

# DESCRIPTION

The chart widgets write their tick labels, value labels and legend values
with these functions. An axis takes its `format` from the axis hash (see
["AXES" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#axes)):

- `auto` (the default)

    As many decimals as the distance between two ticks needs, so all labels of
    an axis have the same number of decimals (`0.0`, `0.5`, `1.0`). When a
    tick reaches 10000, the labels use SI prefixes (`10k`, `2.5M`).

- `si`

    Always with SI prefixes: k (thousand), M (million), G and T.

- `integer`

    Whole numbers.

- `percent`

    The value times 100 with a percent sign: `0.25` is `25%`. Use it for
    fractions, such as the axis of a `percent` stack or a `normalize`d
    series.

- a sprintf format

    Anything with a `%`, such as `'%.1f °C'` or `'$%d'`, is a
    ["sprintf" in perlfunc](https://metacpan.org/pod/perlfunc#sprintf) format called with the value.

- a code reference

    Called with the value; returns the label.

Time axes take a ["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) format, such as `'%H:%M'` or
`'%Y-%m-%d'`, or a code reference called with the epoch seconds.

# FUNCTIONS

## number\_formatter

```perl
my $format = number_formatter( $format, $step, $largest );
```

A function that writes the label of one tick, for ticks `$step` apart
whose largest magnitude is `$largest`. `$format` is one of the formats
above (`undef` is `auto`); the decimals follow `$step`, so all labels
of an axis get the same number of decimals. A code reference is
returned as it is.

## format\_value

```perl
my $text = format_value( $value, $format );
```

A single value, as a bar's value label or a hover label shows it. Without
`$format`: one decimal from 100 on, two from 1 to 100, three
significant digits below 1 (at most six decimals), trailing zeros
removed, and SI prefixes from a million on (`2.5M`). With a
`$format` as above, that format; `si` uses prefixes from a thousand
on, `percent` writes one decimal below 10%. `undef` gives the empty
string.

```perl
say format_value(0.012345);            # 0.0123
say format_value(2_500_000);           # 2.5M
say format_value( 0.05, 'percent' );    # 5.0%
```

## format\_values

```perl
my @texts = format_values( \@values, $format );
```

Several values shown together, such as the labels of the bars of a
chart: written like `format_value` writes them, but all with as many
decimals as the one that needs most (`48.0` beside `51.2`), unless a
`$format` is given or a value has an SI prefix.

## time\_formatter

```perl
my $format = time_formatter( $strftime_format, $utc );
say $format->($epoch);
```

A function that writes epoch seconds with a ["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) format,
in local time, or in UTC when `$utc` is true. A code reference is
returned as it is.

## decimals\_of

The decimals needed to write a number to six significant digits: 0 for
`20`, 2 for `0.25`, 6 for `1/3`; at most 10.

## check\_number\_format, check\_time\_format

```perl
check_number_format( $owner, $name, $format );
```

Die unless `$format` is a valid number (or time) format, with `$owner`
and `$name` at the start of the message; return it. `undef` and code
references are always valid.

# SEE ALSO

[Term::Fabulous::Chart::Scale](Scale.md), [Term::Fabulous::Widget::XYChart](../Widget/XYChart.md),
["Axis keys" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#axis-keys),
["Draw a line chart with labels and points (LineChart)" in Term::Fabulous::Cookbook::Charts](../Cookbook/Charts.md#draw-a-line-chart-with-labels-and-points-linechart),
["Plot values over time (time axis, from and to, a dashed forecast)" in Term::Fabulous::Cookbook::ChartTechniques](../Cookbook/ChartTechniques.md#plot-values-over-time-time-axis-from-and-to-a-dashed-forecast).
