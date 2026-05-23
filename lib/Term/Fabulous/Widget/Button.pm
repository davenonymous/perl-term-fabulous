package Term::Fabulous::Widget::Button;

use v5.22;

use Object::Pad 0.825;

our $VERSION = '0.01';


class Term::Fabulous::Widget::Button
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:does(Clay::UI::Role::Interaction::Hoverable)
{


}

1;
