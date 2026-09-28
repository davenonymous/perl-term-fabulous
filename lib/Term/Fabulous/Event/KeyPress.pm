package Term::Fabulous::Event::KeyPress;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::KeyPress :isa(Clay::UI::Events::Event) :strict(params) {
	field $key       :param :reader;
	field $char      :param :reader;
	field $modifiers :param :reader;

	method event_name :common { 'KeyPress' }

	method of :common ($ev) {
		return $class->new(
			key => $ev->key,
			char => $ev->ch,
			modifiers => $ev->mod,
		);
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::KeyPress - A key press from the terminal

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<KeyPress>, fired by
L<Term::Fabulous> on the focused widget (or the root). Unknown
constructor parameters die.

=head2 key, char, modifiers

termbox2's C<key> (a C<TB_KEY_*> code, 0 for printable characters),
C<ch> (the Unicode codepoint, 0 for special keys) and C<mod>
(C<TB_MOD_*> bits).

=head2 of

	my $event = Term::Fabulous::Event::KeyPress->of($termbox_event);

Builds an event of the invoking class from a C<Termbox::Event>.

=cut
