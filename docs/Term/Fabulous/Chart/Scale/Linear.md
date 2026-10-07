# NAME

Term::Fabulous::Chart::Scale::Linear - A numeric axis with evenly spaced
ticks

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Scale::Linear;

# A vertical axis of 17 rows for data from 3 to 97:
my $scale = Term::Fabulous::Chart::Scale::Linear->fit( extent => [ 3, 97 ], cells => 17 );
say join ' ', map { $_->{label} } $scale->ticks;    # 0 25 50 75 100
say $scale->used;                                   # 17: a tick every 4 rows
```

# DESCRIPTION

A [Term::Fabulous::Chart::Scale](../Scale.md) for numbers. ["fit"](#fit) chooses the domain
and the ticks: the ticks are multiples of a nice step (1, 2, 2.5 or 5
times a power of ten), the domain is the data rounded out to the nearest
ticks, and the choice balances

- that the ticks fall on whole cells, so that grid lines lie
exactly beside their labels and at the height of the values they name
(an axis may then use a few cells less than it has),
- how much empty room the rounding adds above and below the data,
- and a comfortable distance between the ticks: about every three
to six rows on a vertical axis, and on a horizontal axis far enough apart
that the labels do not touch.

# CLASS METHODS

## fit

```perl
my $scale = Term::Fabulous::Chart::Scale::Linear->fit(%options);
```

- `cells`

    The cells the axis has, a positive integer; required.

- `extent`

    `[ $lowest, $highest ]` value of the data; `undef` for no data (the
    axis then shows 0 to 1).

- `min`, `max`

    Fixed ends of the domain. A fixed end is not rounded. `min` must be
    less than `max`, or `fit` dies.

- `zero`

    True to include 0 in the domain (bars and areas grow from 0).

- `orientation`

    `vertical` (the default) or `horizontal`; a horizontal axis spaces its
    ticks by the width of their labels.

- `measure`

    A function returning the columns a label takes; for horizontal axes.

- `format`

    The label format (see [Term::Fabulous::Chart::Format](../Format.md)).

- `step`

    A fixed distance between ticks. A step too small for the cells (more
    intervals across the data than the axis has cells) gives no ticks
    between the two ends, as when nothing else fits.

- `ticks`

    The number of ticks wanted; the closest fitting choice wins.

- `integer`

    True when all values are whole numbers: no ticks less than 1 apart
    (and no steps of 2.5 below 25), so no tick lies between two whole
    numbers.

- `nice`

    False to keep the domain at the data instead of rounding it to ticks.

- `align`

    True to choose ticks that fall on whole cells, at the price of a few
    unused cells at the end of the axis; the default for vertical axes,
    where every tick has a grid line and a label beside it.

# METHODS

Those of [Term::Fabulous::Chart::Scale](../Scale.md), and `step`, the distance
between two ticks.

# SEE ALSO

[Term::Fabulous::Chart::Scale](../Scale.md).
