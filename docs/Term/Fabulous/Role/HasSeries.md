# NAME

Term::Fabulous::Role::HasSeries - Named data series of a chart

# SYNOPSIS

```perl
$chart->add_series( { name => 'web', data => [ 3, 5, 4 ], color => '#3987e5' } );
$chart->add_points( web => 6, 7 );
$chart->append( '2026-06-01 10:00', { web => 12, api => 4 } );
$chart->set_series( web => ( line_style => 'dashed' ) );
$chart->hide_series('api');
$chart->remove_series('web');
```

# DESCRIPTION

The series of [Term::Fabulous::Widget::XYChart](../Widget/XYChart.md) and
[Term::Fabulous::Widget::RadarChart](../Widget/RadarChart.md): adding, changing and removing them
and their data. Every series has a unique name; methods find series by it
and die for names the chart does not have. Every change shows in the next
frame. The methods that change series return the chart, so calls can
be chained.

Each series gets the next color of the chart's palette when it is added
and keeps it, also when series before it are removed. Options the chart
takes for all of its series (`curve`, `marker`, ...) apply to every
series that has none of its own.

# METHODS

## add\_series

```perl
$chart->add_series( { name => $name, type => $type, data => \@data, color => $color, %options } );
$chart->add_series( name => $name, data => \@data );
```

Adds a series at the end; see ["SERIES" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#series)
for its keys. A series without a name is called `Series 1`, `Series 2`,
and so on. Dies for a name the chart has already, a type the chart cannot
draw, invalid options or data, and data the chart cannot show (a radar
chart: a value for a label it does not have); nothing is added then.

## remove\_series, clear\_series

```perl
$chart->remove_series( 'web', 'api' );
$chart->clear_series;
```

Remove the named series, or all of them. An unknown name dies before any
series is removed. The remaining series keep their colors.

## series\_names, has\_series

The names of all series in order; whether a name is one of them.

## series

```perl
my $description = $chart->series('web');
# { name => 'web', type => 'line', color => '#3987e5', curve => 'monotone', data => [ ... ] }
```

A new hash describing a series: name, type, color (as `#rrggbb`, when it
has one of its own), the options it has set itself except `transform`,
and the data: y values for points without x, `[ x, y ]` pairs for the
others (points given as hashes come back as pairs).

## set\_series

```perl
$chart->set_series( web => ( type => 'area', fill_opacity => 0.5, color => undef ) );
```

Changes the type, the color, the data or options of a series; `undef`
removes an option (the chart's applies again) or the color (the palette's
applies again). The name cannot change. Everything is checked first: an
invalid value dies and leaves the series as it was. A new type drops a
`marker` of the series that the new type cannot draw with.

## set\_data, add\_points, clear\_data

```perl
$chart->set_data( web => [ 1, 2, 3 ] );
$chart->add_points( web => [ $time, 4.2 ], [ $time + 60, 3.9 ] );
$chart->clear_data('web');
```

Replace, extend or empty the data of a series. With `max_points` (the
series' own or the chart's), the oldest points are dropped. Invalid data,
or data the chart cannot show, dies and changes nothing.

## append

```perl
$chart->append( $x, { web => 12, api => 4 } );
$chart->append( undef, { web => 12 } );    # the next index
```

Adds one point to each series named in the hash, all at the same x (with
`undef`: each at its next position): the way to feed several series from
one measurement. An unknown name or an invalid value dies and adds no
point to any series.

## show\_series, hide\_series, is\_series\_visible

A hidden series is not drawn, has no legend entry and does not count for
the axes; its data is kept.

## series\_default

```perl
my $curve = $chart->series_default('curve');
$chart->series_default( curve => 'monotone' );
```

Reads or sets an option the chart gives all its series; `undef` removes
it. Dies for a name the chart does not take as a series option, and for
an invalid value. The charts also have an accessor for each
(`$chart->curve('monotone')`).

## series\_option

```perl
my $curve = $chart->series_option( $series, 'curve' );
```

The option a series object is drawn with: its own, or the chart's.

## all\_series, visible\_series

The [Term::Fabulous::Chart::Series](../Chart/Series.md) objects, all or the visible ones;
for the chart's own drawing code.

# REQUIRED METHODS

`default_series_type`, `series_types` (the types the chart draws),
`series_default_names` (the options it takes for all its series),
`check_series_type( $name, $type )`, which dies when the chart cannot
show a series of that type in its current state (the role calls it
before a series is added or changes its type), and
`check_series_points( $name, $points )`, which dies when the chart
cannot show the points (`[ $x, $y ]` pairs, as
["points, count" in Term::Fabulous::Chart::Series](../Chart/Series.md#points-count) holds them); the role has every
series call it with its new points before they are stored, so bad data
dies at once and leaves the series as it was.

# SEE ALSO

[Term::Fabulous::Widget::XYChart](../Widget/XYChart.md), [Term::Fabulous::Widget::RadarChart](../Widget/RadarChart.md),
[Term::Fabulous::Chart::Series](../Chart/Series.md), ["Series and data" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#series-and-data),
["A live chart that follows new data (append, max\_points, span)" in Term::Fabulous::Cookbook::ChartTechniques](../Cookbook/ChartTechniques.md#a-live-chart-that-follows-new-data-append-max_points-span).
