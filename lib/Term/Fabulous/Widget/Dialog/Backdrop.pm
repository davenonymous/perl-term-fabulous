package Term::Fabulous::Widget::Dialog::Backdrop;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Focusable;
use Clay::UI::Role::Interaction::HasFocusOrder;
use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Dialog::Backdrop
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::HasFocusOrder)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(
		CLAY_ATTACH_TO_ROOT CLAY_ATTACH_POINT_CENTER_CENTER
		CLAY_ALIGN_X_CENTER CLAY_ALIGN_Y_CENTER sizing_grow
	);
	use List::Util qw(first);
	use Scalar::Util qw(refaddr weaken);

	field $dialog  :param :weak :reader;
	field $z_index :param;

	ADJUST {
		$self->floating(
			{
				attach_to     => CLAY_ATTACH_TO_ROOT,
				attach_points => { element => CLAY_ATTACH_POINT_CENTER_CENTER, parent => CLAY_ATTACH_POINT_CENTER_CENTER },
				z_index       => $z_index,
			}
		);
		$self->layout(
			{
				sizing          => { width => sizing_grow(), height => sizing_grow() },
				child_alignment => { x => CLAY_ALIGN_X_CENTER, y => CLAY_ALIGN_Y_CENTER },
			}
		);
		$self->glyphs_show_through(1);

		weaken( my $weak_self = $self );
		$self->on(
			KeyPress => sub ($event) {
				my $owner = $weak_self->dialog;
				return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Escape' && defined $owner && $owner->close_on_escape;
				$owner->close;
				return;
			}
		);
	}

	# The focusable widgets inside the dialog, in tree order; the backdrop
	# itself when there are none, so the focus has somewhere to stay.
	method focus_order () {
		my @inside = _focusables_below( $self->dialog );
		return @inside ? @inside : ($self);
	}

	sub _focusables_below ($node) {
		return () unless defined $node && $node->can('children');
		return map { ( ( _can_take_focus($_) ? $_ : () ), _focusables_below($_) ) } $node->children->@*;
	}

	sub _can_take_focus ($widget) {
		return $widget->DOES('Clay::UI::Role::Interaction::Focusable') && $widget->can_focus;
	}

	method get_next_focus ()     { return $self->_step_focus(1) }
	method get_previous_focus () { return $self->_step_focus(-1) }

	method _step_focus ($step) {
		my @order   = $self->focus_order;
		my $focused = $self->ui->interaction->get_focused_widget;
		my $index   = defined $focused ? first { refaddr( $order[$_] ) == refaddr($focused) } 0 .. $#order : undef;
		return $order[0] unless defined $index;
		return $order[ ( $index + $step ) % @order ];
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Dialog::Backdrop - The screen-filling layer
behind an open dialog

=head1 DESCRIPTION

This class is internal to L<Term::Fabulous::Widget::Dialog>. When a
dialog opens, it creates one Backdrop, puts itself inside it and adds
the Backdrop to the root widget. The Backdrop

=over

=item *

floats over the whole screen (attached to the root, grown to its size,
with the dialog's C<z_index>), painted in the dialog's
C<backdrop_color> with the glyphs below showing through, and centers
the dialog in itself;

=item *

catches every mouse event outside the dialog, since it paints every
cell of the screen; Clay treats it as a floating element that captures
the pointer, so nothing below it is hovered or pressed;

=item *

can take the keyboard focus, so a click outside the dialog focuses the
Backdrop instead of a widget behind it;

=item *

decides the Tab order while the focus is inside the dialog
(L<Clay::UI::Role::Interaction::HasFocusOrder>): Tab and Shift+Tab
cycle through the focusable widgets inside the dialog, and through the
Backdrop alone when there are none;

=item *

closes the dialog on C<Escape>, when the dialog's C<close_on_escape> is
set.

=back

=head1 METHODS

=head2 dialog

The L<Term::Fabulous::Widget::Dialog> this Backdrop belongs to.

=head2 focus_order

	my @widgets = $backdrop->focus_order;

The focusable widgets inside the dialog, in tree order, or the Backdrop
itself when there are none.

=head2 get_next_focus, get_previous_focus

The L<Clay::UI::Role::Interaction::HasFocusOrder> methods: the widget
after or before the focused one in L</focus_order>, wrapping around.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Dialog>.

=cut
