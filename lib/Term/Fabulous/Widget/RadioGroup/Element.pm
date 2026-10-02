package Term::Fabulous::Widget::RadioGroup::Element;

use v5.24;
use warnings;

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Focusable;
use Term::Fabulous::Widget::Box;

# The Clay::UI focus role of a radio group. Term::Fabulous::Widget::RadioGroup
# inherits it from here so that it can override can_focus (an Object::Pad
# class cannot override a method of a role it composes itself).
class Term::Fabulous::Widget::RadioGroup::Element
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:abstract
{
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::RadioGroup::Element - The Clay::UI focus role
behind Term::Fabulous::Widget::RadioGroup

=head1 DESCRIPTION

An abstract L<Term::Fabulous::Widget::Box> that composes
C<Clay::UI::Role::Interaction::Focusable>. It has no methods of its
own.

L<Term::Fabulous::Widget::RadioGroup> inherits from it instead of
composing the role directly, because an L<Object::Pad> class cannot
override a method of a role it composes, while a subclass can override
an inherited method. This lets a group keep C<can_focus> false while it
is disabled and still remember what C<can_focus> was set to (see
L<Term::Fabulous::Widget::RadioGroup/can_focus>).

Do not subclass this class; subclass
L<Term::Fabulous::Widget::RadioGroup>.

=head1 SEE ALSO

L<Term::Fabulous::Widget::RadioGroup>, L<Term::Fabulous::Widget::Element>,
L<Clay::UI>.

=cut
