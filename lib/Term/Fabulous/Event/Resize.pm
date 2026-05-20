package Term::Fabulous::Event::Resize;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Resize :isa(Clay::UI::Events::Event) {
	field $width  :param :reader;
	field $height :param :reader;
	field $is_post_event :param :reader = 0;

	method is_pre_event() {
		return !$is_post_event;
	}

	method event_name :common { 'Resize' }

	method of :common ($ev, $is_post_event = 0) {
		return Term::Fabulous::Event::Resize->new(
			width => $ev->w,
			height => $ev->h,
			is_post_event => $is_post_event,
		);
	}
}

1;
