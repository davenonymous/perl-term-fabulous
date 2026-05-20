package Term::Fabulous::Widget;

use v5.22;

use Object::Pad 0.825;

class Term::Fabulous::Widget
	:does(Clay::UI::Role::Core::Element)

	:does(Clay::UI::Role::Events::Listener)
	:does(Clay::UI::Role::Events::Emitter)

	:does(Clay::UI::Role::Layout::HasLayout)
	:does(Clay::UI::Role::Layout::HasParent)
	:does(Clay::UI::Role::Layout::HasSizingGroup)

	:does(Clay::UI::Role::Style::HasBackground)
	:does(Clay::UI::Role::Style::HasStates)

	:does(Clay::UI::Role::Style::HasBorder)
	:does(Term::Fabulous::Role::HasBorderStyle)
{
	field $classes :param = [];

	method get_classes () {
		return (@$classes, map { 'state_' . lc($_) } $self->states);
	}

}

1;
