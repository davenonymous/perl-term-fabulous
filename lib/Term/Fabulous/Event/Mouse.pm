package Term::Fabulous::Event::Mouse;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

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

Term::Fabulous::Event::Mouse - A mouse event from the terminal

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<Mouse>, fired by
L<Term::Fabulous> on the topmost event emitter under the pointer (or the
root). Unknown constructor parameters die.

=head2 key

termbox2's mouse key: C<TB_KEY_MOUSE_LEFT>, C<TB_KEY_MOUSE_RIGHT>,
C<TB_KEY_MOUSE_MIDDLE>, C<TB_KEY_MOUSE_RELEASE>,
C<TB_KEY_MOUSE_WHEEL_UP> or C<TB_KEY_MOUSE_WHEEL_DOWN>.

=head2 x, y

Cell coordinates of the pointer.

=head2 modifiers

termbox2's C<mod> bits (C<TB_MOD_*>, for example C<TB_MOD_MOTION> while
dragging); 0 when not given to the constructor.

=head2 of

	my $event = Term::Fabulous::Event::Mouse->of($termbox_event);

Builds an event of the invoking class from a C<Termbox::Event>.

=cut
