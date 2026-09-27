package Term::Fabulous::Widget;

use v5.22;
use warnings;

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
	:abstract
{
	field $classes :param = [];

	method get_classes () {
		return (@$classes, map { 'state_' . lc($_) } $self->states);
	}

}

1;

__END__

=head1 NAME

Term::Fabulous::Widget - Abstract base class of Term::Fabulous element widgets

=head1 DESCRIPTION

Composes the Clay::UI element, event, layout and style roles plus
L<Term::Fabulous::Role::HasBorderStyle>. The class is abstract and
cannot be constructed; use L<Term::Fabulous::Widget::Box> as the
concrete container, or subclass this class for new widgets.

=head2 get_classes

The C<classes> constructor parameter (an arrayref of names) followed by
C<state_E<lt>nameE<gt>> for every current state (C<state_hovered>, ...).

=cut
