package Term::Fabulous::Widget::Button;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Button
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use Feature::Compat::Try;
	use Scalar::Util qw(refaddr weaken);
	use Term::Fabulous::Color;
	use Term::Fabulous::Event::Activate;

	use constant REVERSE_VIDEO => 'reverse';

	my %ACTIVATES = map { $_ => 1 } qw(Enter Space);

	# The look of a focused and of a pressed Button, as [r, g, b, a] or
	# undef for no change; pressed_background_color may also be 'reverse'.
	field $focus_border_color       :param = [ 97, 175, 239, 255 ];
	field $pressed_background_color :param = REVERSE_VIDEO;

	# Clay::UI stores can_focus as given; the constructor takes any truth value.
	sub BUILDARGS ( $class, %params ) {
		$params{can_focus} = $params{can_focus} ? 1 : 0 if exists $params{can_focus};
		return $class->SUPER::BUILDARGS(%params);
	}

	ADJUST {
		$focus_border_color       = _rgba( focus_border_color       => $focus_border_color );
		$pressed_background_color = _pressed_look( pressed_background_color => $pressed_background_color );

		weaken( my $weak_self = $self );
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		$self->on(
			OnRelease => sub ($event) {
				$weak_self->activate if refaddr( $event->target ) == refaddr($weak_self);
				return $continue;
			}
		);
		$self->on(
			KeyPress => sub ($event) {
				return $continue unless $ACTIVATES{ $event->key_name // '' };
				$weak_self->activate;
				return;
			}
		);
	}

	# Any Term::Fabulous::Color input as [r, g, b, a]; undef stays undef.
	sub _rgba ( $name, $value ) {
		return undef unless defined $value;
		try {
			return [ Term::Fabulous::Color->new( color => $value )->to_rgba ];
		}
		catch ($error) {
			die "Term::Fabulous::Widget::Button: $name is not a color: $error";
		}
	}

	sub _pressed_look ( $name, $value ) {
		return REVERSE_VIDEO if defined $value && !ref $value && $value eq REVERSE_VIDEO;
		return _rgba( $name, $value );
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(can_focus focus_border_color pressed_background_color) );
	}

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, 'can_focus' );
	}

	method focus_border_color (@new) {
		return $focus_border_color unless @new;
		$focus_border_color = _rgba( focus_border_color => $new[0] );
		$self->mark_changed;
		return $focus_border_color;
	}

	method pressed_background_color (@new) {
		return $pressed_background_color unless @new;
		$pressed_background_color = _pressed_look( pressed_background_color => $new[0] );
		$self->mark_changed;
		return $pressed_background_color;
	}

	method activate () {
		return $self->fire_event( Term::Fabulous::Event::Activate->new );
	}

	method reverse_video :override () {
		return defined $pressed_background_color && !ref $pressed_background_color && $self->is_pressed ? 1 : 0;
	}

	# Runs after contribute_background and contribute_border (Clay::UI calls
	# the contributors in alphabetical order), so the state look wins.
	method contribute_state_look ($config) {
		$config->{background_color} = $pressed_background_color
			if ref $pressed_background_color && $self->is_pressed;

		return unless defined $focus_border_color && defined $config->{border} && $self->is_focused;
		$config->{border} = { %{ $config->{border} }, color => $focus_border_color };
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Button - A box that can be clicked, focused and
activated

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_fit);

	my $save = Term::Fabulous::Widget::Button->new(
		id               => 'save',
		background_color => [ 40, 60, 90, 255 ],
		border_width     => 1,
		border_color     => [ 90, 110, 140, 255 ],
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
		layout           => {
			sizing  => { width => sizing_fit(), height => sizing_fit() },
			padding => { left => 1, right => 1 },
		},
	);
	$save->add_child( Term::Fabulous::Widget::Text->new( text => 'Save', text_color => [ 255, 255, 255, 255 ] ) );

	# A click, or Enter or Space while the button has the focus.
	$save->on( Activate => sub ($event) { save_document(); return } );

=head1 DESCRIPTION

A Button is a L<Term::Fabulous::Widget::Box> that can take the keyboard
focus, notices when the mouse button is pressed and released over it,
and tracks whether the mouse pointer is over it. Put a
L<Term::Fabulous::Widget::Text> (or anything else) inside it as its
label.

A Button fires one event for everything that counts as pressing it:
C<Activate> (L<Term::Fabulous::Event::Activate>), for a click (the left
mouse button pressed and released over the Button) and for C<Enter> or
C<Space> while it has the focus. The lower-level events are still
there: C<OnPress> and C<OnRelease> for the mouse, C<KeyPress> for
every key.

A Button shows its state by itself:

=over

=item * while it is pressed (the left mouse button held down over it),
it is drawn in reverse video: the foreground and background colors of
every cell it paints, label included, are swapped. C<pressed_background_color>
replaces that with a background color, or switches it off;

=item * while it has the focus, its border is drawn in
C<focus_border_color>, the blue the input widgets use for their accent.
A Button without a border shows nothing; give it C<border_width =E<gt> 1>
or change its background in an C<OnFocus> listener;

=item * hovering changes nothing by default. C<is_hovered> and the
C<OnHoverStart> and C<OnHoverStopped> events follow the pointer, so a
hover look is one listener away.

=back

Under L<Term::Fabulous>, Tab and Shift+Tab move the focus to and from
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
clicks still fire C<OnPress>, C<OnRelease> and C<Activate>.

=item C<focus_border_color>

The color of the border while the Button has the focus, in any format
L<Term::Fabulous::Color> accepts, or C<undef> for no focus look.
Default: C<[ 97, 175, 239, 255 ]>. It only shows on sides with a
positive C<border_width>.

=item C<pressed_background_color>

What the Button looks like while it is pressed: the string C<reverse>
(the default) draws it in reverse video, a color in any format
L<Term::Fabulous::Color> accepts replaces the background with that
color, and C<undef> leaves the Button unchanged while pressed.

=back

=head1 METHODS

A Button has all methods of L<Term::Fabulous::Widget> plus these:

=head2 activate

	$button->activate;

Fires C<Activate> on the Button, as a click or C<Enter> would, and
returns what C<fire_event> returns. Use it to trigger a button from
code, for example from an application shortcut.

=head2 focus_border_color

	$button->focus_border_color('#ffffff');
	$button->focus_border_color(undef);

Accessor for the constructor parameter of the same name. Without an
argument it returns the stored C<[r, g, b, a]> (or C<undef>); with an
argument it sets the value and returns the stored form. An invalid
color dies.

=head2 pressed_background_color

	$button->pressed_background_color('reverse');
	$button->pressed_background_color( [ 60, 90, 160, 255 ] );
	$button->pressed_background_color(undef);

Accessor for the constructor parameter of the same name. Returns the
string C<reverse>, the stored C<[r, g, b, a]>, or C<undef>.

=head2 reverse_video

	my $swapped = $button->reverse_video;

1 while the Button is pressed and C<pressed_background_color> is
C<reverse>, 0 otherwise. The renderer calls it; see
L<Term::Fabulous::Widget/reverse_video>.

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

=item C<Activate> (L<Term::Fabulous::Event::Activate>)

The user activated the Button: a click (C<OnRelease> over the Button
after C<OnPress> on it), or C<Enter> or C<Space> while the Button has
the focus. C<< $event->target >> is the Button. Fired by the Button
itself, from its own C<OnRelease> and C<KeyPress> listeners, which run
before any listener you add.

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

The pointer entered or left the Button. These events do not bubble.

=item C<KeyPress> (L<Term::Fabulous::Event::KeyPress>)

A key was pressed while the Button had the focus. C<Enter> and
C<Space> are used by the Button (they fire C<Activate> and do not
bubble); every other key bubbles on to the ancestors.

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

Any mouse event over the Button (press, release, drag, wheel), when the
Button paints the cell under the pointer (it needs a background color
or a border there).

=back

=head1 KEYS

C<Enter> and C<Space> activate the focused Button. Tab and Shift+Tab
always move the focus away (see L<Term::Fabulous::Manual/FOCUS>).

=head1 MOUSE

Pressing the left button on a cell the Button paints (its background
or its border) focuses the Button, unless C<can_focus> is 0. A Button
without a background color paints only its border (or nothing), so the
cells in between are transparent: there the C<Mouse> event and the
focus go to the widget behind the Button. C<OnPress>, C<OnRelease> and
C<Activate> do not depend on painting: they fire for any cell inside
the Button's box.

Pressing fires C<OnPress>; releasing over the Button fires
C<OnRelease> and then C<Activate>. Releasing anywhere else cancels the
click. While the button is held with the pointer dragged off the
Button, C<is_pressed> is 0 and the pressed look disappears; dragging
back onto it makes it 1 again, and releasing there still fires
C<OnRelease> and C<Activate>.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<can_focus> (C<#true> or C<#false>), C<focus_border_color> (a color
string) and C<pressed_background_color> (a color string or C<reverse>):

	use Term::Fabulous::Widget::Button as Button
	use Term::Fabulous::Widget::Text as Text

	Button "save" {
		background_color "#283c5a"
		border style=Round color="#5a6b8c"
		border_width 1
		padding left=1 right=1
		pressed_background_color "#3d5a85"
		Text { text "Save"; text_color "#ffffff"; }
	}

Listeners cannot be given in KDL; attach them in Perl after building
the layout.

=head1 CAVEATS

Term::Fabulous looks at the mouse button once per frame. A press and a
release that arrive between two frames still get a frame each, so a
click is never too fast to be seen. A click sent by a script with the
release in the same terminal report as the press is the exception; if
no such click may be missed, listen to C<Mouse> events and act on
C<TB_KEY_MOUSE_RELEASE>:

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

L<Term::Fabulous::Widget::Box>, L<Term::Fabulous::Event::Activate>,
L<Term::Fabulous::Manual/FOCUS>, L<Term::Fabulous::Manual/MOUSE>,
L<Clay::UI::Role::Interaction::Pressable>,
L<Clay::UI::Role::Interaction::Focusable>,
L<Clay::UI::Role::Interaction::Hoverable>, the example program
F<examples/buttons-and-keys.pl>.

=cut
