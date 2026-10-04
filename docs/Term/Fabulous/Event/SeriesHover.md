# NAME

Term::Fabulous::Event::SeriesHover - The mouse moved onto another series,
point or slice of a chart

# SYNOPSIS

```perl
$chart->on( SeriesHover => sub ($event) {
        if ( !defined $event->series ) {
                $status->text('');
        }
        elsif ( defined $event->index ) {
                $status->text( sprintf '%s, %s: %s', $event->series, $event->label, $event->value );
        }
        else {
                $status->text( $event->series );    # the legend entry
        }
        return;
} );
```

# DESCRIPTION

The chart widgets ([Term::Fabulous::Widget::Chart](../Widget/Chart.md) and its subclasses)
fire `SeriesHover` on themselves when the mouse pointer moves onto
something else of the chart: onto a line, an area, a bar, a point, a pie
slice or a legend entry, or away from all of them. While the pointer is on
a series, the chart emphasizes it and fades the others (see
["Hover and emphasis" in Term::Fabulous::Widget::Chart](../Widget/Chart.md#hover-and-emphasis)).

Charts have no tooltips; this event tells your program what the pointer
is on, so it can show the details its own way, for example in a status
line next to the chart.

Moving within the same point fires nothing. When the pointer moves off
the series, leaves the chart, or the program turns hover off with
`$chart->hover(0)` while the pointer is on a series, the chart
fires one event without a series. A chart with
`hover => 0` fires no `SeriesHover` events.
`$chart->hovered` returns the defined values of the last event as
a hash reference (`undef` before the first event).

The recipe
["Show details of the point under the pointer (SeriesHover, highlight)" in Term::Fabulous::Cookbook::ChartStyles](../Cookbook/ChartStyles.md#show-details-of-the-point-under-the-pointer-serieshover-highlight)
shows the details in a status line.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `SeriesHover`; it
bubbles to the chart's ancestors, and `$event->target` is the chart.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::SeriesHover->new( series => 'Sales', index => 3, label => 'Apr', value => 42 );
```

Charts build these events themselves; build one yourself only to test
your listeners. All parameters are optional; unknown parameters die.

# METHODS

## series

The name of the series under the pointer; for a pie, donut or polar area
chart the label of the slice. `undef` when the pointer left the
chart's series (the event then has no other values either).

## index

The number of the data point under the pointer (from 0, in the order of
the series' data after its `transform`), the category of a bar, the
number of a histogram bin, the position of a slice among the slices as
drawn (after sorting and folding into `Other`), or the number of the
axis in a radar chart. On a line or an area it is the point (or the
axis) nearest to the pointer. `undef` on a legend entry.

## label

What the point is called: its category label, its x value as the axis
writes it, the range of a histogram bin, the radar axis label or the
slice label. On a legend entry,
the entry's text: the series name or the slice label.

## value

The value of the point: its y value (not the stacked total), the height
of a histogram bar in the chart's measure, or the slice's value. On a legend entry `undef`, except for a slice's legend
entry, which carries the slice's value.

## x

The x value of the point as a number: the category number, the number on
a numeric axis, epoch seconds on a time axis, the middle of a histogram
bin. `undef` for slices, radar
charts and legend entries.

# SEE ALSO

["Hover and emphasis" in Term::Fabulous::Widget::Chart](../Widget/Chart.md#hover-and-emphasis),
["CHARTS" in Term::Fabulous::Manual::Charts](../Manual/Charts.md#charts), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events).
