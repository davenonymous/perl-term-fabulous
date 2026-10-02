package Term::Fabulous::Widget::Input::Element;

use v5.24;
use warnings;

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Focusable;
use Clay::UI::Role::Interaction::Hoverable;
use Clay::UI::Role::Interaction::Pressable;
use Term::Fabulous::Widget::Canvas;

# The Clay::UI interaction roles of an input widget. Term::Fabulous::Widget::Input
# inherits them from here so that it can override can_focus (an Object::Pad
# class cannot override a method of a role it composes itself).
class Term::Fabulous::Widget::Input::Element
	:isa(Term::Fabulous::Widget::Canvas)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:abstract
{
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Input::Element - The Clay::UI interaction roles
behind Term::Fabulous::Widget::Input

=head1 DESCRIPTION

An abstract L<Term::Fabulous::Widget::Canvas> that composes
C<Clay::UI::Role::Interaction::Focusable>, C<Hoverable> and C<Pressable>.
It has no methods of its own.

L<Term::Fabulous::Widget::Input> inherits from it instead of composing
the roles directly, because an L<Object::Pad> class cannot override a
method of a role it composes, while a subclass can override an
inherited method. This lets an input keep C<can_focus> false while it
is disabled and still remember what C<can_focus> was set to (see
L<Term::Fabulous::Widget::Input/can_focus>).

Do not subclass this class; subclass L<Term::Fabulous::Widget::Input>
or one of its subclasses.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Input>, L<Term::Fabulous::Widget::Element>,
L<Clay::UI>.

=cut
