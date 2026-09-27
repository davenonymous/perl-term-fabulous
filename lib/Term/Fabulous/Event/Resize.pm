package Term::Fabulous::Event::Resize;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Resize :isa(Clay::UI::Events::Event) :strict(params) {
	field $width  :param :reader;
	field $height :param :reader;
	field $is_post_event :param :reader = 0;

	method is_pre_event() {
		return !$is_post_event;
	}

	method event_name :common { 'Resize' }

	method of :common ($ev, $is_post_event = 0) {
		return $class->new(
			width => $ev->w,
			height => $ev->h,
			is_post_event => $is_post_event,
		);
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::Resize - The terminal changed size

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<Resize>, fired by
L<Term::Fabulous> on the root widget twice per debounced resize. Unknown
constructor parameters die.

=head2 width, height

The new terminal size in cells.

=head2 is_post_event, is_pre_event

Whether the new size has already been applied to the layout.

=head2 of

	my $event = Term::Fabulous::Event::Resize->of($termbox_event, $is_post_event);

Builds an event of the invoking class from a C<Termbox::Event>.

=cut
