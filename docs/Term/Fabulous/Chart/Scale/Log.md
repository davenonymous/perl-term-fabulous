# NAME

Term::Fabulous::Chart::Scale::Log - A logarithmic numeric axis

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Scale::Log;

my $scale = Term::Fabulous::Chart::Scale::Log->fit( extent => [ 3, 42_000 ], cells => 17 );
say join ' ', map { $_->{label} } $scale->ticks;    # 1 10 100 1k 10k 100k
```

# DESCRIPTION

A [Term::Fabulous::Chart::Scale](../Scale.md) on which every power of the base
(10 by default) is the same distance from the next one, so values that
span several orders of magnitude, or grow by a constant factor, can be
read. Its domain runs from the power at or below the smallest value to
the power at or above the largest. The ticks are the powers; where they
would crowd, only every second (third, ...) power is labeled.

Values of zero or below have no position on a logarithmic axis; charts
leave them out (a line has a gap there).

# CLASS METHODS

## fit

```perl
my $scale = Term::Fabulous::Chart::Scale::Log->fit(%options);
```

Takes `cells`, `extent`, `min`, `max`, `orientation`, `measure` and
`format` like ["fit" in Term::Fabulous::Chart::Scale::Linear](Linear.md#fit) (the format
defaults to `si`), and `base`, a number greater than 1 (default 10).
`min` and `max` must be greater than 0. A fixed end is kept also when
the data lies beyond it: the other end then moves a power of the base
away from it.

# METHODS

Those of [Term::Fabulous::Chart::Scale](../Scale.md), and `base`.

# SEE ALSO

[Term::Fabulous::Chart::Scale](../Scale.md).
