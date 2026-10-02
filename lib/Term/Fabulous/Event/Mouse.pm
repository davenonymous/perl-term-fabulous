package Term::Fabulous::Event::Mouse;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Mouse :isa(Clay::UI::Events::Event) :strict(params) {
	field $key       :param :reader;
	field $x         :param :reader;
	field $y         :param :reader;
	field $modifiers :param :reader = 0;

	method event_name :common { 'Mouse' }

	method of :common ($ev) {
		return $class->new(
			key => $ev->key,
			x => $ev->x,
			y => $ev->y,
			modifiers => $ev->mod,
		);
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::Mouse - A mouse click, release, drag or wheel
turn from the terminal

=head1 SYNOPSIS

	use Termbox 2 qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RIGHT TB_KEY_MOUSE_WHEEL_UP TB_MOD_MOTION);

	$panel->on( Mouse => sub ($event) {
		my ( $x, $y ) = ( $event->x, $event->y );    # terminal cell, from 0
		if ( $event->key == TB_KEY_MOUSE_LEFT ) {
			if ( $event->modifiers & TB_MOD_MOTION ) {
				drag_to( $x, $y );                   # moved with the left button held
			}
			else {
				start_at( $x, $y );                  # left button pressed
			}
		}
		return;
	} );

=head1 DESCRIPTION

L<Term::Fabulous> fires a C<Mouse> event for every mouse report the
terminal sends while L<Term::Fabulous/run> is active and mouse input is
enabled (the C<mouse> parameter of L<Term::Fabulous/new>, on by
default). The event is fired on the topmost widget that painted the
cell under the pointer in the last frame (see
L<Term::Fabulous::Manual/MOUSE> for the exact rules), or on the root
widget when there is none, and then bubbles up to the ancestors.

The class is a subclass of L<Clay::UI::Events::Event>, so C<target>,
C<current_target>, C<name> (C<'Mouse'> unless given to the constructor)
and C<bubble_mode> (C<IF_CONTINUE>) are available as well.

=head2 What the terminal reports

Terminals report the mouse only in these cases:

=over

=item * a button is pressed: C<key> is C<TB_KEY_MOUSE_LEFT>,
C<TB_KEY_MOUSE_MIDDLE> or C<TB_KEY_MOUSE_RIGHT>;

=item * a button is released: C<key> is C<TB_KEY_MOUSE_RELEASE>, which
does not say which button was released;

=item * the pointer moves while a button is held (a drag): C<key> is the
held button's key again and C<modifiers> has C<TB_MOD_MOTION> set;

=item * the wheel turns: C<key> is C<TB_KEY_MOUSE_WHEEL_UP> or
C<TB_KEY_MOUSE_WHEEL_DOWN>, one event per notch.

=back

Moving the pointer without a button held is not reported at all.
Clay::UI's hover state (C<OnHoverStart>, C<OnHoverStopped>,
C<is_hovered>) therefore changes only when one of the reports above
arrives, not while the pointer merely moves.

Terminals encode Shift, Ctrl and Alt in their mouse reports, but
termbox2 decodes only the button, the motion flag and the wheel and
drops the modifier bits. C<modifiers> is therefore always C<0> or
C<TB_MOD_MOTION>; Shift+click cannot be told apart from a click.

=head1 CONSTRUCTOR

=head2 new

	use Termbox 2 qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_MOD_MOTION);

	my $press   = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_LEFT, x => 10, y => 3 );
	my $drag    = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_LEFT, x => 12, y => 3, modifiers => TB_MOD_MOTION );
	my $release = Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_RELEASE, x => 12, y => 3 );

	$canvas->fire_event($press);

Programs rarely build mouse events themselves; L<Term::Fabulous> does it
for every report. Building one by hand is useful in tests (see
L<Term::Fabulous::Manual/TESTING>). Note that firing a hand-built event
on a widget only runs the listeners. For a real left press,
L<Term::Fabulous> records the pointer position and moves the keyboard
focus (see L<Term::Fabulous::Manual/FOCUS>) before it fires the
C<Mouse> event. Clay::UI's C<OnPress> and C<OnRelease>
events (L<Clay::UI::Role::Interaction::Pressable>) come later, during
the next frame (within 1/30 second), when the recorded pointer is
handed to Clay. A hand-built C<Mouse> event does none of this. Unknown
parameters die. Besides the parameters below, the C<name> and
C<bubble_mode> parameters of L<Clay::UI::Events::Event> are accepted.

=over

=item C<key>

Required. One of the C<TB_KEY_MOUSE_*> constants listed under L</key>.

=item C<x>

Required. The column of the pointer, counted from 0 at the left edge of
the terminal.

=item C<y>

Required. The row of the pointer, counted from 0 at the top edge of the
terminal.

=item C<modifiers>

Optional. A bit mask; only C<TB_MOD_MOTION> is meaningful. Default: C<0>.

=back

An event object can be fired only once. Build a new one for every
C<fire_event> call.

=head2 of

	my $event = Term::Fabulous::Event::Mouse->of($termbox_event);

Builds an event from a C<Termbox::Event>: C<key>, C<x>, C<y> and
C<modifiers> from its C<key>, C<x>, C<y> and C<mod>. Called by
L<Term::Fabulous>; class method.

=head1 METHODS

=head2 key

	my $key = $event->key;

Which button or wheel direction the event is about. Import the
constants from L<Termbox>:

	use Termbox 2 qw(
		TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_MIDDLE TB_KEY_MOUSE_RIGHT
		TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN
		TB_MOD_MOTION
	);

	Constant                  Meaning
	------------------------  ------------------------------------------
	TB_KEY_MOUSE_LEFT         left button pressed (or dragged)
	TB_KEY_MOUSE_MIDDLE       middle button pressed (or dragged)
	TB_KEY_MOUSE_RIGHT        right button pressed (or dragged)
	TB_KEY_MOUSE_RELEASE      a button was released (which one is unknown)
	TB_KEY_MOUSE_WHEEL_UP     wheel turned up (away from the user) one notch
	TB_KEY_MOUSE_WHEEL_DOWN   wheel turned down one notch

=head2 x

	my $column = $event->x;

The column of the cell under the pointer, an integer from 0 at the left
edge of the terminal. termbox2 stores reported positions in 8 bits, so
on very large terminals clicks at column 255 or further right arrive
with wrong coordinates. To get a position inside a canvas, use
L<Term::Fabulous::Widget::Canvas/cell_at> or
L<Term::Fabulous::Widget::PixelCanvas/pixel_at>.

=head2 y

	my $row = $event->y;

The row of the cell under the pointer, an integer from 0 at the top
edge of the terminal. As for L</x>, rows from 255 on arrive wrong.

=head2 modifiers

	my $dragging = $event->modifiers & TB_MOD_MOTION;

A bit mask. C<TB_MOD_MOTION> is set when the event reports a move with
a button held (a drag); otherwise the value is C<0>.

=head1 SEE ALSO

L<Term::Fabulous::Manual/MOUSE>, L<Term::Fabulous>,
L<Term::Fabulous::Event::KeyPress>, L<Clay::UI::Events::Event>,
L<Termbox>.

=cut
