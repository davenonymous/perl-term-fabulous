# NAME

Term::Fabulous::Chart::Easing - Easing functions for the curves of
charts

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Easing qw(easing easing_names);
use Term::Fabulous::Widget::LineChart;

my $ease = easing('ease-in-out-cubic');
say $ease->(0.25);    # 0.0625

# In a chart: every segment between two points follows the curve.
my $chart = Term::Fabulous::Widget::LineChart->new(
        curve  => 'ease-in-out-sine',
        series => [ { name => 'Steps', data => [ 1, 4, 2, 5 ] } ],
);
```

# DESCRIPTION

An easing function maps the way from one point to the next (`t` from 0
to 1) to the share of the change made so far. A chart whose `curve` is
an easing name draws each segment of a line or area along that function:
`linear` is a straight line, `ease-in-out-sine` a gentle S between
every two points, `ease-out-bounce` a bounce at the end of every
segment. Every curve passes
through the data points themselves, so the values stay exact; the shape
between them is decoration. For smooth lines that stay faithful to the
data, prefer the `monotone` curve of [Term::Fabulous::Chart::Curve](Curve.md).

The functions are the classic set (as on easings.net): for each of the
families `sine`, `quad`, `cubic`, `quart`, `quint`, `expo`,
`circ`, `back`, `elastic` and `bounce` there is `ease-in-FAMILY`
(slow start), `ease-out-FAMILY` (slow end) and `ease-in-out-FAMILY`
(slow at both ends), plus `linear`. `back` and `elastic` overshoot:
their curves leave the range between two points for a moment.
That makes 31 names, such as `ease-in-quad`, `ease-out-expo` and
`ease-in-out-elastic`.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-chart-curves.svg" alt="Six small charts of the same seven points connected linear, step, monotone, catmull-rom, ease-in-out-sine and ease-out-bounce"></p>
</div>

The last two charts in the picture use easings; the program is in
["Connect points with curves and easings (curve)" in Term::Fabulous::Cookbook::ChartStyles](../Cookbook/ChartStyles.md#connect-points-with-curves-and-easings-curve).

# FUNCTIONS

## easing

```perl
my $function = easing($name);
```

The function of a name: a code reference from `t` (0 to 1) to the
eased `t` (0 at 0, 1 at 1). Dies for an unknown name, with all names
in the message.

## easing\_names

All names, `linear` included, sorted.

## is\_easing\_name

1 for an easing name, else 0.

# SEE ALSO

[Term::Fabulous::Chart::Curve](Curve.md), ["Curves" in Term::Fabulous::Widget::XYChart](../Widget/XYChart.md#curves).
