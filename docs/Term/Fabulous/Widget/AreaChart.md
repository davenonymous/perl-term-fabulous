# NAME

Term::Fabulous::Widget::AreaChart - Lines with the area below them filled

# SYNOPSIS

```perl
use Term::Fabulous::Widget::AreaChart;

my $chart = Term::Fabulous::Widget::AreaChart->new(
        title   => 'Traffic by source',
        stacked => 1,
        curve   => 'monotone',
        labels  => [qw(Mon Tue Wed Thu Fri Sat Sun)],
        series  => [
                { name => 'Search', data => [ 420, 460, 455, 510, 480, 300, 280 ] },
                { name => 'Social', data => [ 180, 150, 210, 260, 300, 340, 310 ] },
                { name => 'Direct', data => [ 120, 130, 125, 140, 135, 110, 100 ] },
        ],
);

$chart->stacked('percent');    # each day as shares of 100%
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-area-chart.svg" alt="Three stacked areas for Search, Social and Direct over the months of a year, with a title and a legend at the top"></p>
</div>

The program is `examples/widgets/area-chart.pl`.

# DESCRIPTION

An area chart is a line chart whose series are filled down to the
baseline, in block characters placed to an eighth of a cell, translucent
so that overlapping areas show through each other: 0.6 of the color
over the background, 0.8 when the areas are stacked. With `stacked` the areas lie on each other and show
how parts add up to a whole; `stacked => 'percent'` shows the
shares. The y axis includes zero, where the areas grow from.

An area has no line along its top by default; `line => 1`
adds one in Braille dots. `fill_opacity` sets the translucency,
`curve` the shape of the top. Everything else is described on
[Term::Fabulous::Widget::XYChart](XYChart.md); an AreaChart is an XYChart whose
series are `area` series unless they say otherwise.

# CONSTRUCTOR

## new

```perl
my $chart = Term::Fabulous::Widget::AreaChart->new(%parameters);
```

The parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::XYChart](XYChart.md#constructor) and
["CONSTRUCTOR" in Term::Fabulous::Widget::Chart](Chart.md#constructor). For areas: `stacked`,
`fill_opacity`, `line`, `curve`, `marker` (`block` by default).

# METHODS

Those of ["METHODS" in Term::Fabulous::Widget::XYChart](XYChart.md#methods).

# KDL PROPERTIES

```kdl
use Term::Fabulous::Widget::AreaChart as AreaChart

AreaChart "traffic" {
        stacked #true
        curve "monotone"
        labels "Mon" "Tue" "Wed"
        series "Search" { data 420 460 455 }
        series "Social" { data 180 150 210 }
}
```

See ["KDL PROPERTIES" in Term::Fabulous::Widget::XYChart](XYChart.md#kdl-properties).

# SEE ALSO

[Term::Fabulous::Widget::XYChart](XYChart.md), [Term::Fabulous::Widget::LineChart](LineChart.md),
["CHARTS" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#charts),
["Stacked areas and shares of 100% (AreaChart)" in Term::Fabulous::Cookbook::Charts](../Cookbook/Charts.md#stacked-areas-and-shares-of-100-areachart).
