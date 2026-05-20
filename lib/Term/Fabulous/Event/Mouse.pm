package Term::Fabulous::Event::Mouse;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Mouse :isa(Clay::UI::Events::Event) {
	field $key    :param :reader;
	field $x      :param :reader;
	field $y      :param :reader;

	method event_name :common { 'Mouse' }

	method of :common ($ev) {
		return Term::Fabulous::Event::Mouse->new(
			key => $ev->key,
			x => $ev->x,
			y => $ev->y,
		);
	}
}

1;
