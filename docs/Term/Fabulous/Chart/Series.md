# NAME

Term::Fabulous::Chart::Series - One data series of an XY chart

# SYNOPSIS

```perl
# Series are made by the charts from hashes:
my $chart = Term::Fabulous::Widget::LineChart->new(
        series => [ { name => 'CPU', data => [ 12, 40, 33 ], color => '#3987e5', curve => 'monotone' } ],
);
$chart->add_points( CPU => 51, 47 );
```

# DESCRIPTION

The data and the options of one series of a
[Term::Fabulous::Widget::XYChart](../Widget/XYChart.md). The chart widgets create series from
the hashes in their `series` parameter (see
["SERIES" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#series)) and change them through their
own methods; you do not need this class directly. It checks every option
and data point when it is given, so a wrong value dies at once with the
series' name in the message.

# CONSTRUCTOR

## new

```perl
my $series = Term::Fabulous::Chart::Series->new(
        owner => 'My::Chart',
        name  => 'CPU',
        type  => 'line',
        slot  => 0,
        data  => [ 12, 40, 33 ],
        color => '#3987e5',
        curve => 'monotone',
);
```

`owner` (the class name of the chart, which starts every message),
`name` (a non-empty string), `type` (`line`, `area`, `bar` or
`scatter`) and `slot` (the palette slot) are required. `data`
(default: none) and `color` (default: `undef`, the palette's) are
checked as ["set\_data, add\_points, clear"](#set_data-add_points-clear) and
["color, color\_opacity, set\_color"](#color-color_opacity-set_color) check them, and every option of
["SERIES" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#series) may be given. Unknown parameters die. Two more
parameters serve the charts:

- `described_as`

    How the messages about the options name the series. Default: `undef`,
    `series 'NAME'` (`curve of series 'CPU' must be ...`); the empty string
    leaves the series out (`curve must be ...`), for the options a chart
    takes for all of its series.

- `check_points`

    A code reference called with the series and an array reference of its
    new points (as ["points, count"](#points-count) holds them) before they are stored: from
    the constructor, `set_data` and `add_points`. It dies for points the
    chart cannot show (a radar chart: a label it does not have), and the
    data stays as it was. Default: none.

# METHODS

## name, type, slot

The series' name, its type (`line`, `area`, `bar` or `scatter`) and
its palette slot (the color it has when it has no `color` of its own).

## set\_type

```perl
$series->set_type('area');
```

Changes the type. Drops the series' own `marker` when the new type
cannot draw with it. Dies for an unknown type.

## color, color\_opacity, set\_color

The color as a packed `0xRRGGBB` integer (`undef`: the palette's), and
its alpha as an opacity from 0 to 1. `set_color` takes every color form
of [Term::Fabulous::Color](../Color.md) or a packed integer; `undef` returns to the
palette's color.

## option, set\_option

```perl
my $curve = $series->option('curve');
$series->set_option( curve => 'monotone' );
```

Reads and sets one option (see ["Series keys" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#series-keys));
`undef` means the chart's setting. Both die for an unknown option name;
`set_option` also dies for an invalid value.

## set\_data, add\_points, clear

Replace, extend or empty the data. A data point is a number (the y value,
its x is its position in the series), `undef` (a gap), `[ $x, $y ]` or
`{ x => $x, y => $y }`. With `max_points`, the oldest points
are dropped. An invalid point, or one `check_points` refuses, dies and
changes nothing.

## points, count

The points as `[ $x_or_undef, $y_or_undef ]` (read only) and their
number.

## keep\_last

```perl
$series->keep_last(100);
```

Drops all but the newest points, as `max_points` does.

## is\_visible

False when the series' `visible` option is false. Default: true.

## revision

A number that changes with every change of the series.

## dash\_pattern

```perl
my $pattern = $series->dash_pattern('dashed');
```

The subpixel pattern of a line style.

## marker\_names, option\_names

```perl
my @markers = Term::Fabulous::Chart::Series->marker_names('bar');
```

The markers a type of series can be drawn with, and the names of all
options.

# SEE ALSO

[Term::Fabulous::Widget::XYChart](../Widget/XYChart.md).
