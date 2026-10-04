# NAME

Term::Fabulous::Chart::Scale - What the scales of chart axes have in
common

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Scale::Linear;

my $scale = Term::Fabulous::Chart::Scale::Linear->fit( extent => [ 3, 97 ], cells => 21 );
say $scale->min, ' .. ', $scale->max;                  # 0 .. 100
say join ' ', map { $_->{label} } $scale->ticks;      # 0 25 50 75 100
say $scale->position(50);                             # 0.5
```

# DESCRIPTION

A scale maps the values of one axis to positions from 0 (the start of the
axis) to 1 (its end) and chooses the ticks shown on it. The chart widgets
fit a scale to the data and to the cells the axis has every time they are
drawn:

- [Term::Fabulous::Chart::Scale::Linear](Scale/Linear.md)

    Numbers, evenly spaced ticks at "nice" numbers (1, 2, 2.5 and 5 times a
    power of ten).

- [Term::Fabulous::Chart::Scale::Log](Scale/Log.md)

    Positive numbers on a logarithmic axis, ticks at the powers of the base.

- [Term::Fabulous::Chart::Scale::Time](Scale/Time.md)

    Points in time (epoch seconds), ticks at calendar boundaries: whole
    minutes, hours, days, months, years.

- [Term::Fabulous::Chart::Scale::Category](Scale/Category.md)

    Labels, one slot each.

# METHODS

## min, max

The domain: the values at position 0 and 1.

## position

```perl
my $t = $scale->position($value);
```

0 for `min`, 1 for `max`, values in between in between; values outside
the domain lie outside 0 to 1. `undef` for a value the scale cannot show
(zero or less on a logarithmic scale).

## value\_at

The value at a position; the inverse of `position`.

## ticks

```perl
foreach my $tick ( $scale->ticks ) {
        my ( $value, $label, $position ) = @$tick{qw(value label position)};
}
```

The ticks in order, as hashes with the value, its label and its position.

## tick\_count

The number of ticks.

## cells, used

The number of cells the scale was fitted to, and the number of cells its
ticks span: scales whose ticks are evenly spaced choose them so that each
tick falls on a whole cell, and then may span fewer cells than they were
given. The chart lays the axis out over `used` cells, so every grid line
lies exactly at its label.

## is\_band

True for scales that give each value a slot (categories) instead of a
point.

## contains

True when a value lies within the domain.

## kind

`linear`, `log`, `time` or `category`.

# SEE ALSO

[Term::Fabulous::Widget::XYChart](../Widget/XYChart.md).
