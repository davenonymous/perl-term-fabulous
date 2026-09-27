package Term::Fabulous::Widget::Button;

use v5.22;
use warnings;

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Button
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:strict(params)
{
	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, 'can_focus' );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Button - Focusable, pressable, hoverable Box

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Box> that can take focus and tracks hover
and press state. In a KDL layout it accepts the Box properties plus
C<can_focus> (C<#true> / C<#false>).

=cut
