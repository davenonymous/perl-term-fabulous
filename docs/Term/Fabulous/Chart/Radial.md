# NAME

Term::Fabulous::Chart::Radial - Geometry of round charts in terminal
cells

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Radial qw(circle_frame polar_of point_at);

my $circle = circle_frame( 0, 0, 40, 20 );          # center (20, 10), radius 20
my ( $distance, $angle ) = polar_of( $circle, 30, 10 );    # 10, 0.25 (3 o'clock)
my ( $x, $y ) = point_at( $circle, 10, 0.5 );          # (20, 15): 6 o'clock
```

# DESCRIPTION

Pie, donut, polar area and radar charts are round, but terminal cells are
not square: a cell is about twice as high as it is wide. These functions
measure distances in cell widths and count a row as `CELL_ASPECT` (2) of
them, so circles come out round. Angles are in turns (1 is a full circle),
clockwise from 12 o'clock. Positions are in cells and may be fractional:
`(0, 0)` is the top-left corner of the area's first cell, and
`(0.5, 0.5)` its center.

You need this module only for round charts of your own; the chart
widgets use it internally. All functions and constants are exported on
request.

# CONSTANTS

- `CELL_ASPECT`

    2: how many cell widths a cell is high.

- `TAU`

    A full circle in radians (2 pi).

# FUNCTIONS

## circle\_frame

```perl
my $circle = circle_frame( $x, $y, $width, $height, $margin );
```

The largest circle that fits an area of `$width` by `$height` cells
starting at cell `($x, $y)`, its radius less `$margin` cell widths
(default 0): a hash with `center_x`, `center_y` (cells) and `radius`
(cell widths, never below 0).

## polar\_of

```perl
my ( $distance, $angle ) = polar_of( $circle, $x, $y, $start );
```

The polar coordinates of the point `($x, $y)` (cells): its distance from
the circle's center in cell widths, and its angle in turns from 0 to 1,
clockwise from `$start` (in turns; default 0, 12 o'clock).

## point\_at

```perl
my ( $x, $y ) = point_at( $circle, $distance, $angle, $start );
```

The reverse: the point in cells at `$distance` cell widths from the
center and `$angle` turns clockwise from `$start` (default 0).

# SEE ALSO

[Term::Fabulous::Widget::PieChart](../Widget/PieChart.md), [Term::Fabulous::Widget::RadarChart](../Widget/RadarChart.md),
["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Chart](../Widget/Chart.md#subclass-interface).
