# NAME

Term::Fabulous::Widget::DonutChart - A pie chart with a hole

# SYNOPSIS

```perl
use Term::Fabulous::Widget::DonutChart;

my $chart = Term::Fabulous::Widget::DonutChart->new(
        title         => 'Sales by region',
        legend_values => 'value',
        format        => 'si',
        data          => [ [ Europe => 412_000 ], [ 'North America' => 365_000 ], [ Asia => 290_000 ] ],
);

$chart->center_text("1.07M\norders");    # instead of the total
$chart->hole(0.5);
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-donut-chart.svg" alt="A donut of a monthly budget with the total in the middle and the amounts and shares in the legend"></p>
</div>

`examples/widgets/donut-chart.pl` draws this chart.

# DESCRIPTION

A donut is a [Term::Fabulous::Widget::PieChart](PieChart.md) whose `hole` is 0.6
of the radius by default. A ring shows shares as well as a pie does, and
the hole holds a text.

## The text in the hole

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-donut-chart-centers.svg" alt="Three donuts of the same budget: the total 2170 euros in the middle of the first, 21% Food in the middle of the second with the other slices faded, and a text of its own, 2170 euros per month, in the third"></p>
</div>

The hole shows, in this order of preference:

- the `center_text`, when it is set: one or more lines separated by
newlines, the first in bold (an empty string shows nothing);
- the share and the label of the emphasized slice, while the pointer is
on a slice or its legend entry, or while `highlight` names a slice;
- the total of the slices in bold, with the word `Total` below it.

Values are written with the chart's `format`. The text appears when the
radius of the hole is at least three cell widths, that is when the hole
is at least six columns wide; lines wider than the hole are cut.
`examples/widgets/donut-chart-centers.pl` shows the three cases.

Everything else, the data forms, the parameters, methods, events and KDL
properties, is on [Term::Fabulous::Widget::PieChart](PieChart.md).

# CONSTRUCTOR

## new

```perl
my $chart = Term::Fabulous::Widget::DonutChart->new(%parameters);
```

The parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::PieChart](PieChart.md#constructor), with
`hole` defaulting to 0.6.

# KDL PROPERTIES

```kdl
use Term::Fabulous::Widget::DonutChart as DonutChart

DonutChart "sales" {
        hole 0.5
        center_text "Orders"
        slice "Europe" 412000
        slice "Asia" 290000
}
```

See ["KDL PROPERTIES" in Term::Fabulous::Widget::PieChart](PieChart.md#kdl-properties).

# SEE ALSO

[Term::Fabulous::Widget::PieChart](PieChart.md), [Term::Fabulous::Widget::Chart](Chart.md),
["CHARTS" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#charts),
["Show shares as a pie or donut (PieChart, DonutChart)" in Term::Fabulous::Cookbook::Charts](../Cookbook/Charts.md#show-shares-as-a-pie-or-donut-piechart-donutchart),
the example programs `examples/widgets/donut-chart.pl` and
`examples/widgets/donut-chart-centers.pl`.
