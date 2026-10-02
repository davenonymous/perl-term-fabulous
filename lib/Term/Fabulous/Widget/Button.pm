package Term::Fabulous::Widget::Button;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Button
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:strict(params)
{
	# Clay::UI stores can_focus as given; the constructor takes any truth value.
	sub BUILDARGS ( $class, %params ) {
		$params{can_focus} = $params{can_focus} ? 1 : 0 if exists $params{can_focus};
		return $class->SUPER::BUILDARGS(%params);
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, 'can_focus' );
	}

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, 'can_focus' );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Button - A box that can be clicked and focused

=head1 SYNOPSIS

	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fit);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Text;

	my $idle_border  = [ 120, 130, 150, 255 ];
	my $focus_border = [ 97,  175, 239, 255 ];

	my $save = Term::Fabulous::Widget::Button->new(
		id               => 'save',
		background_color => [ 40, 60, 90, 255 ],
		border_width     => 1,
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
		border_color     => $idle_border,
		layout           => {
			sizing  => { width => sizing_fit(), height => sizing_fit() },
			padding => { left => 1, right => 1 },
		},
	);
	$save->add_child( Term::Fabulous::Widget::Text->new( text => 'Save', text_color => [ 255, 255, 255, 255 ] ) );

	sub save_document () { ... }

	# A click: pressed and released over the button.
	$save->on( OnRelease => sub ($event) { save_document(); return } );

	# Keys do nothing by themselves: activate with Enter and Space.
	$save->on( KeyPress => sub ($event) {
		my $key = $event->key_name // '';
		return Clay::UI::Enum::Result->CONTINUE unless $key eq 'Enter' || $key eq 'Space';
		save_document();
		return;
	} );

	# There is no built-in focus look: show the focus with the border.
	$save->on( OnFocus => sub ($event) { $save->border_color($focus_border); return Clay::UI::Enum::Result->CONTINUE } );
	$save->on( OnBlur  => sub ($event) { $save->border_color($idle_border);  return Clay::UI::Enum::Result->CONTINUE } );

=head1 DESCRIPTION

A Button is a L<Term::Fabulous::Widget::Box> that can take the keyboard
focus, notices when the mouse button is pressed and released over it,
and tracks whether the mouse pointer is over it. Put a
L<Term::Fabulous::Widget::Text> (or anything else) inside it as its
label.

A Button is deliberately minimal. It has

=over

=item * no look of its own: it is drawn exactly like a Box with the
same parameters, whether it is focused, hovered or pressed;

=item * no key handling: pressing Enter or Space on a focused Button
does nothing unless you add a C<KeyPress> listener;

=item * no "click" event: a click is an C<OnRelease> event, which is
fired only when the button was pressed over this Button and released
over it again.

=back

The SYNOPSIS shows the usual way to add all three. Under
L<Term::Fabulous>, Tab and Shift+Tab move the focus to and from
Buttons, and pressing the left mouse button on a cell the Button paints
(its background or its border) focuses it; see L</MOUSE>.

=head1 CONSTRUCTOR

=head2 new

	my $button = Term::Fabulous::Widget::Button->new(%parameters);

All parameters are optional; unknown parameters die. A Button takes
every parameter of L<Term::Fabulous::Widget::Box> (C<id>, C<layout>,
C<background_color>, C<border_width>, C<border_color>, C<border_style>,
...; see L<Term::Fabulous::Widget/new>) plus:

=over

=item C<can_focus>

A boolean, stored as 1 or 0. Default: 1. With 0 the Button is skipped by Tab and
Shift+Tab, a click does not focus it, and
C<< $ui->interaction->set_focused_widget($button) >> dies. Mouse
clicks still fire C<OnPress> and C<OnRelease>.

=back

=head1 METHODS

A Button has all methods of L<Term::Fabulous::Widget> plus these,
from the L<Clay::UI> interaction roles:

=head2 can_focus

	$button->can_focus(0);

Accessor. Without an argument it returns the stored flag (1 by
default); with an argument it stores the value as given, treated as a
boolean, and returns it.
Turning it off does not take the focus away from a Button that has it.

=head2 is_focused

	if ( $button->is_focused ) { ... }

1 while the Button has the keyboard focus, 0 otherwise (also while it is
not part of a L<Term::Fabulous>). To give it the focus, call
C<< $ui->interaction->set_focused_widget($button) >>.

=head2 is_hovered

	if ( $button->is_hovered ) { ... }

1 while the mouse pointer is over the Button, as of the last frame.
Terminals report the pointer only when a mouse button is pressed or
released, while the mouse is dragged with a button held, and when the
wheel turns; plain mouse movement is not reported. "Hovered" therefore
means "under the last reported pointer position", not "under the mouse
right now", and it is not suitable for live hover highlighting.

=head2 is_pressed

	if ( $button->is_pressed ) { ... }

1 while the left mouse button, pressed over this Button, is held down
and the pointer is still over it.

=head1 EVENTS

All events are delivered to listeners registered with
C<< $button->on( $name => sub ($event) { ... } ) >>; see
L<Term::Fabulous::Manual/EVENTS> for how listener return values decide
whether an event continues to the Button's ancestors.

=over

=item C<OnPress> (L<Clay::UI::Events::OnPress>)

The left mouse button went down over the Button. When Buttons are
nested, only the innermost one under the pointer gets it. C<< $event->x >>
and C<< $event->y >> are the pointer position in cells, as the center of
the cell (column + 0.5, row + 0.5). The event is fired while the next
frame is drawn, up to 1/30 second after the click.

=item C<OnRelease> (L<Clay::UI::Events::OnRelease>)

The left mouse button went up over the Button after it was pressed over
it: a completed click. Releasing elsewhere fires nothing. Carries C<x>
and C<y> like C<OnPress>.

=item C<OnFocus>, C<OnBlur> (L<Clay::UI::Events::OnFocus>, L<Clay::UI::Events::OnBlur>)

The Button got or lost the keyboard focus.

=item C<OnHoverStart>, C<OnHoverStopped> (L<Clay::UI::Events::OnHoverStart>, L<Clay::UI::Events::OnHoverStopped>)

The last reported pointer position entered or left the Button (see
L</is_hovered> for when the terminal reports it). These events do not
bubble.

=item C<KeyPress> (L<Term::Fabulous::Event::KeyPress>)

A key was pressed while the Button had the focus.

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

Any mouse event over the Button (press, release, drag, wheel), when the
Button paints the cell under the pointer (it needs a background color
or a border there).

=back

=head1 KEYS

None. Add a C<KeyPress> listener as shown in the SYNOPSIS. Tab and
Shift+Tab always move the focus away (see
L<Term::Fabulous::Manual/FOCUS>).

=head1 MOUSE

Pressing the left button on a cell the Button paints (its background
or its border) focuses the Button, unless C<can_focus> is 0. A Button
without a background color paints only its border (or nothing), so the
cells in between are transparent: there the C<Mouse> event and the
focus go to the widget behind the Button. C<OnPress> and C<OnRelease>
do not depend on painting: they fire for any cell inside the Button's
box.

Pressing fires C<OnPress>; releasing over the Button fires
C<OnRelease>. Releasing anywhere else cancels the click. While the
button is held with the pointer dragged off the Button, C<is_pressed>
is 0; dragging back onto it makes it 1 again, and releasing there still
fires C<OnRelease>.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<can_focus> (C<#true> or C<#false>):

	use Term::Fabulous::Widget::Button as Button
	use Term::Fabulous::Widget::Text as Text

	Button "save" {
		background_color "#283c5a"
		padding left=1 right=1
		Text { text "Save"; text_color "#ffffff"; }
	}

Listeners cannot be given in KDL; attach them in Perl after building
the layout.

=head1 CAVEATS

Term::Fabulous looks at the mouse button once per frame, every 1/30
second. A click whose press and release both arrive between two frames
(a very fast click, or one sent by a script) produces no C<OnPress> and
no C<OnRelease>. If no click may be missed, listen to C<Mouse> events
instead and act on C<TB_KEY_MOUSE_RELEASE>:

	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_RELEASE);

	$save->on( Mouse => sub ($event) {
		return Clay::UI::Enum::Result->CONTINUE unless $event->key == TB_KEY_MOUSE_RELEASE;
		save_document();
		return;
	} );

A release is reported for the cell under the pointer, so this also
fires when the press started elsewhere, and only on cells the Button
paints.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Box>, L<Term::Fabulous::Manual/FOCUS>,
L<Term::Fabulous::Manual/MOUSE>,
L<Clay::UI::Role::Interaction::Pressable>,
L<Clay::UI::Role::Interaction::Focusable>,
L<Clay::UI::Role::Interaction::Hoverable>, the example program
F<examples/buttons-and-keys.pl>.

=cut
