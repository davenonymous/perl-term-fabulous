package Term::Fabulous::Event::KeyPress;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::KeyPress :isa(Clay::UI::Events::Event) {
	field $key       :param :reader;
	field $char      :param :reader;
	field $modifiers :param :reader;

	method event_name :common { 'KeyPress' }

	method of :common ($ev) {
		return Term::Fabulous::Event::KeyPress->new(
			key => $ev->key,
			char => $ev->ch,
			modifiers => $ev->mod,
		);
	}
}

1;
