package Term::Fabulous::Event::SeriesHover;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::SeriesHover :isa(Clay::UI::Events::Event) :strict(params) {
	field $series :param :reader = undef;
	field $index  :param :reader = undef;
	field $label  :param :reader = undef;
	field $value  :param :reader = undef;
	field $x      :param :reader = undef;

	method event_name :common { 'SeriesHover' }
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::SeriesHover - The mouse moved onto another series,
point or slice of a chart

=head1 SYNOPSIS

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

=head1 DESCRIPTION

The chart widgets (L<Term::Fabulous::Widget::Chart> and its subclasses)
fire C<SeriesHover> on themselves when the mouse pointer moves onto
something else of the chart: onto a line, an area, a bar, a point, a pie
slice or a legend entry, or away from all of them. While the pointer is on
a series, the chart emphasizes it and fades the others (see
L<Term::Fabulous::Widget::Chart/Hover and emphasis>).

Charts have no tooltips; this event tells your program what the pointer
is on, so it can show the details its own way, for example in a status
line next to the chart.

Moving within the same point fires nothing. A chart with
C<< hover =E<gt> 0 >> fires no C<SeriesHover> events.

It is a L<Clay::UI::Events::Event> whose name is C<SeriesHover>; it
bubbles to the chart's ancestors, and C<< $event->target >> is the chart.

=head1 CONSTRUCTOR

=head2 new

	my $event = Term::Fabulous::Event::SeriesHover->new( series => 'Sales', index => 3, label => 'Apr', value => 42 );

Charts build these events themselves; build one yourself only to test
your listeners. All parameters are optional; unknown parameters die.

=head1 METHODS

=head2 series

The name of the series under the pointer; for a pie, donut or polar area
chart the label of the slice. C<undef> when the pointer left the
chart's series (the event then has no other values either).

=head2 index

The number of the data point under the pointer (from 0, in the order of
the series' data after its C<transform>), the category of a bar, the
number of a slice, or the number of the axis in a radar chart. On a line
or an area it is the point (or the axis) nearest to the pointer. C<undef>
on a legend entry.

=head2 label

What the point is called: its category label, its x value as the axis
writes it, the radar axis label or the slice label. On a legend entry,
the entry's text: the series name or the slice label.

=head2 value

The value of the point: its y value (not the stacked total), or the
slice's value. On a legend entry C<undef>, except for a slice's legend
entry, which carries the slice's value.

=head2 x

The x value of the point as a number: the category number, the number on
a numeric axis, epoch seconds on a time axis. C<undef> for slices, radar
charts and legend entries.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Chart>, L<Term::Fabulous::Manual/EVENTS>.

=cut
