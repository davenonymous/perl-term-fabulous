# NAME

Term::Fabulous::Chart::Scale::Time - A date and time axis

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Scale::Time;

# Two days of data on an axis 60 columns wide, in UTC:
my $scale = Term::Fabulous::Chart::Scale::Time->fit(
        extent => [ 1780272000, 1780444800 ],
        cells  => 60,
        utc    => 1,
);
say join ', ', map { $_->{label} } $scale->ticks;    # Jun 1, 12:00, Jun 2, 12:00, Jun 3
```

# DESCRIPTION

A [Term::Fabulous::Chart::Scale](../Scale.md) for points in time, given as epoch
seconds. The domain is the data's first and last moment (or the `min`
and `max` of the axis). The ticks fall on calendar boundaries: every 1,
2, 5, 10, 15 or 30 seconds or minutes; every 1, 2, 3, 6 or 12 hours;
every day or second day; every week (on Mondays); every 1, 2, 3 or 6
months; every 1, 2, 5, 10, ... years. The finest interval whose labels
have room is chosen.

Without a `format`, the labels follow the interval: years (`2026`),
months (`Feb`, and the year in January), days (`Jun 3`), hours and
minutes (`06:00`, and the date at midnight) or seconds (`06:00:15`).
So an axis of hours shows on which day each night begins. A `format` (a
["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) format or a code reference) labels every tick the same
way.

Times are local unless `utc` is true. Ticks at local boundaries stay on
them across changes of daylight saving time.

# CLASS METHODS

## fit

```perl
my $scale = Term::Fabulous::Chart::Scale::Time->fit(%options);
```

Takes `cells`, `extent`, `min`, `max`, `orientation` (default
`horizontal`), `measure` and `format` (a ["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) format or
a code reference called with the epoch seconds) like
["fit" in Term::Fabulous::Chart::Scale::Linear](Linear.md#fit), the values in epoch
seconds, and `utc`. `min` must be before `max`.

# METHODS

Those of [Term::Fabulous::Chart::Scale](../Scale.md), and `utc` and `interval`,
the tick interval as `[ $unit, $count ]` (`[ 'hour', 6 ]`).

# SEE ALSO

[Term::Fabulous::Chart::Scale](../Scale.md), ["Time axes" in Term::Fabulous::Widget::XYChart](../../Widget/XYChart.md#time-axes).
