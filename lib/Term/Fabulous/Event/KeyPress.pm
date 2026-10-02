package Term::Fabulous::Event::KeyPress;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::KeyPress :isa(Clay::UI::Events::Event) :strict(params) {
	use Termbox 2 qw(
		TB_KEY_ARROW_LEFT TB_KEY_ARROW_RIGHT TB_KEY_ARROW_UP TB_KEY_ARROW_DOWN
		TB_KEY_HOME TB_KEY_END TB_KEY_PGUP TB_KEY_PGDN TB_KEY_INSERT TB_KEY_DELETE TB_KEY_BACK_TAB
		TB_KEY_F1 TB_KEY_F2 TB_KEY_F3 TB_KEY_F4 TB_KEY_F5 TB_KEY_F6
		TB_KEY_F7 TB_KEY_F8 TB_KEY_F9 TB_KEY_F10 TB_KEY_F11 TB_KEY_F12
		TB_MOD_ALT TB_MOD_CTRL TB_MOD_SHIFT
	);

	field $key       :param :reader;
	field $char      :param :reader;
	field $modifiers :param :reader;

	# termbox2 reports the keys of the ASCII control range with their byte as
	# the key code; Termbox.pm exports no constants for them.
	my %NAME_BY_KEY = (
		0x08                 => 'Backspace',    # Ctrl+H, sent by some terminals for Backspace
		0x09                 => 'Tab',
		0x0D                 => 'Enter',
		0x1B                 => 'Escape',
		0x20                 => 'Space',
		0x7F                 => 'Backspace',
		TB_KEY_ARROW_LEFT()  => 'Left',
		TB_KEY_ARROW_RIGHT() => 'Right',
		TB_KEY_ARROW_UP()    => 'Up',
		TB_KEY_ARROW_DOWN()  => 'Down',
		TB_KEY_HOME()        => 'Home',
		TB_KEY_END()         => 'End',
		TB_KEY_PGUP()        => 'PageUp',
		TB_KEY_PGDN()        => 'PageDown',
		TB_KEY_INSERT()      => 'Insert',
		TB_KEY_DELETE()      => 'Delete',
		TB_KEY_BACK_TAB()    => 'BackTab',
		TB_KEY_F1()          => 'F1',
		TB_KEY_F2()          => 'F2',
		TB_KEY_F3()          => 'F3',
		TB_KEY_F4()          => 'F4',
		TB_KEY_F5()          => 'F5',
		TB_KEY_F6()          => 'F6',
		TB_KEY_F7()          => 'F7',
		TB_KEY_F8()          => 'F8',
		TB_KEY_F9()          => 'F9',
		TB_KEY_F10()         => 'F10',
		TB_KEY_F11()         => 'F11',
		TB_KEY_F12()         => 'F12',
	);

	method event_name :common { 'KeyPress' }

	method of :common ($ev) {
		return $class->new(
			key => $ev->key,
			char => $ev->ch,
			modifiers => $ev->mod,
		);
	}

	sub _is_control_byte ($code) {
		return $code < 0x20 || $code == 0x7F;
	}

	# The key without its modifiers, and whether it implies Ctrl: the
	# unnamed bytes of the control range are Ctrl plus a letter or symbol.
	method _base_key () {
		return ( 'Space', 0 ) if $char == 0x20;
		return ( chr($char), 0 ) if $char != 0;
		return ( $NAME_BY_KEY{$key}, 0 ) if exists $NAME_BY_KEY{$key};
		return ( 'Space', 1 ) if $key == 0x00;
		return ( chr( $key + 0x40 ), 1 ) if $key < 0x20;
		return ( undef, 0 );
	}

	# termbox2 sets TB_MOD_CTRL on every byte of the control range, Enter
	# and Tab included; there the byte alone says whether Ctrl was held.
	method key_name () {
		my ( $base, $implies_ctrl ) = $self->_base_key;
		return undef unless defined $base;

		my $ctrl = $char == 0 && _is_control_byte($key) ? $implies_ctrl : $modifiers & TB_MOD_CTRL;
		my @names;
		push @names, 'Ctrl'  if $ctrl;
		push @names, 'Alt'   if $modifiers & TB_MOD_ALT;
		push @names, 'Shift' if $modifiers & TB_MOD_SHIFT;
		return join '+', @names, $base;
	}

	method text () {
		return undef if $modifiers & ( TB_MOD_CTRL | TB_MOD_ALT );
		return chr($char) if $char >= 0x20 && ( $char < 0x7F || $char > 0x9F );
		return ' ' if $char == 0 && $key == 0x20;
		return undef;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::KeyPress - A key press from the terminal

=head1 SYNOPSIS

	$widget->on( KeyPress => sub ($event) {
		return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Ctrl+S';
		save();
		return Clay::UI::Enum::Result->HANDLED;
	} );

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<KeyPress>, fired by
L<Term::Fabulous> on the focused widget (or the root). Unknown
constructor parameters die.

=head2 key, char, modifiers

termbox2's C<key> (a C<TB_KEY_*> code, 0 for printable characters),
C<ch> (the Unicode codepoint, 0 for special keys) and C<mod>
(C<TB_MOD_*> bits).

=head2 key_name

	my $name = $event->key_name;    # 'Left', 'Ctrl+Shift+Right', 'Enter', 'a', 'Alt+x', ...

A readable name of the key with its modifiers, for key bindings. The
modifiers come first, always in the order C<Ctrl+Alt+Shift+>. The key
is one of C<Left>, C<Right>, C<Up>, C<Down>, C<Home>, C<End>,
C<PageUp>, C<PageDown>, C<Insert>, C<Delete>, C<Backspace>, C<Tab>,
C<BackTab> (Shift+Tab), C<Enter>, C<Escape>, C<Space> (however the
terminal reports it), C<F1> to C<F12>, an uppercase letter or symbol
after C<Ctrl+> (C<Ctrl+W>), or the typed character itself.

Terminals send Ctrl plus a letter as a control byte, which termbox2
reports as its key code, so C<Ctrl+H>, C<Ctrl+I> and C<Ctrl+M> arrive
as C<Backspace>, C<Tab> and C<Enter>. termbox2 marks every control byte
with C<TB_MOD_CTRL>; for them the name ignores that bit, so Enter is
C<Enter>, never C<Ctrl+Enter>. C<undef> for a key code without a name.

=head2 text

The character the key types: a string of one character for a
printable key (including C<Space>) pressed without Ctrl or Alt,
C<undef> for anything else.

=head2 of

	my $event = Term::Fabulous::Event::KeyPress->of($termbox_event);

Builds an event of the invoking class from a C<Termbox::Event>.

=cut
