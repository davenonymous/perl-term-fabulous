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

	use Clay::UI::Enum::Result;

	# Ctrl+S saves, every other key goes on to the ancestors.
	$root->on( KeyPress => sub ($event) {
		my $name = $event->key_name // '';
		if ( $name eq 'Ctrl+S' ) {
			save_document();
			return;    # handled: stop here
		}
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	# What did the user type?
	$widget->on( KeyPress => sub ($event) {
		my $character = $event->text;    # 'a', 'A', 'e' with an accent, ' ', or undef
		return Clay::UI::Enum::Result->CONTINUE unless defined $character;
		append_to_buffer($character);
		return;
	} );

=head1 DESCRIPTION

L<Term::Fabulous> fires a C<KeyPress> event for every key the terminal
reports while L<Term::Fabulous/run> is active. The event is fired on the
focused widget, or on the root widget when no widget has the focus, and
then bubbles up to the ancestors (see
L<Term::Fabulous::Manual/Return values and bubbling>). Listen for it with
C<< $widget->on( KeyPress => sub ($event) { ... } ) >>.

The class is a subclass of L<Clay::UI::Events::Event>, so C<target>,
C<current_target>, C<name> (C<'KeyPress'> unless given to the
constructor) and C<bubble_mode> (C<IF_CONTINUE>) are available as well.

The most useful methods are L</key_name>, which turns the key into a
readable name such as C<'Ctrl+Left'> for key bindings, and L</text>,
which returns the character a key types. The raw termbox2 values are
available through L</key>, L</char> and L</modifiers>.

=head1 CONSTRUCTOR

=head2 new

	use Termbox 2 qw(TB_KEY_ARROW_LEFT TB_MOD_CTRL TB_MOD_SHIFT);

	my $typed_a    = Term::Fabulous::Event::KeyPress->new( key => 0, char => ord 'a', modifiers => 0 );
	my $left       = Term::Fabulous::Event::KeyPress->new( key => TB_KEY_ARROW_LEFT, char => 0, modifiers => 0 );
	my $word_left  = Term::Fabulous::Event::KeyPress->new( key => TB_KEY_ARROW_LEFT, char => 0, modifiers => TB_MOD_CTRL | TB_MOD_SHIFT );
	my $ctrl_w     = Term::Fabulous::Event::KeyPress->new( key => 0x17, char => 0, modifiers => TB_MOD_CTRL );
	my $enter      = Term::Fabulous::Event::KeyPress->new( key => 0x0D, char => 0, modifiers => 0 );

	$text_field->fire_event($typed_a);

Programs rarely build key presses themselves; L<Term::Fabulous> does it
for every key. Building one by hand is useful in tests, to simulate
typing without a terminal (see L<Term::Fabulous::Manual/TESTING>). The
three parameters below are required, and unknown parameters die. The
C<name> and C<bubble_mode> parameters of L<Clay::UI::Events::Event> are
accepted as well.

=over

=item C<key>

An integer. The termbox2 key code: a C<TB_KEY_*> constant for special
keys (arrows, Home, F1, ...), the byte value for keys of the ASCII
control range (C<0x0D> for Enter, C<0x17> for Ctrl+W, ...), and C<0>
for a typed character.

=item C<char>

An integer. The Unicode code point of a typed character (C<ord 'a'>),
or C<0> for a special key.

=item C<modifiers>

An integer. A bit mask of the termbox2 constants C<TB_MOD_ALT> (1),
C<TB_MOD_CTRL> (2) and C<TB_MOD_SHIFT> (4); C<0> for none.

=back

An event object can be fired only once. Build a new one for every
C<fire_event> call.

=head2 of

	my $event = Term::Fabulous::Event::KeyPress->of($termbox_event);

Builds an event from a C<Termbox::Event> as returned by termbox2's
C<tb_peek_event> or C<tb_poll_event>: C<key> from its C<key>, C<char>
from its C<ch> and C<modifiers> from its C<mod>. Called by
L<Term::Fabulous>; class method.

=head1 METHODS

=head2 key_name

	my $name = $event->key_name;    # 'Left', 'Ctrl+Shift+Right', 'Enter', 'a', 'Ctrl+W', ...

Returns a readable name of the key together with its modifiers, or
C<undef> for a key code that has no name. Compare it with C<eq> to bind
keys; see L</KEY NAMES> for every possible result. Because the result
can be C<undef>, write C<< ( $event->key_name // '' ) eq 'Ctrl+S' >>
to avoid "uninitialized" warnings.

The name is built as follows:

=over

=item *

The modifiers come first, joined with C<+>, always in the order
C<Ctrl>, C<Alt>, C<Shift>: C<'Ctrl+Alt+Shift+Left'>, never
C<'Shift+Ctrl+Left'>.

=item *

The key follows: a key name such as C<Left> or C<F5>, an uppercase
letter or a symbol after C<Ctrl+> (C<'Ctrl+W'>), or the typed character
itself (C<'a'>, C<'A'>, C<'?'>, C<'E<eacute>'>).

=back

=head2 text

	my $character = $event->text;

Returns the character the key types, as a character string of length
one, or C<undef> when the key does not type anything.

=over

=item *

A printable character typed without Ctrl or Alt returns that character:
C<'a'>, C<'A'>, C<'7'>, C<'?'>, C<'E<eacute>'>, a CJK character, and so on.

=item *

The space bar returns C<' '>, however the terminal reports it.

=item *

Special keys (arrows, Enter, Tab, Backspace, Escape, function keys, ...),
Ctrl and Alt combinations, and control characters (U+0000 to U+001F,
U+007F to U+009F) return C<undef>.

=back

Text inputs insert exactly what C<text> returns.

=head2 key

	my $code = $event->key;

The raw termbox2 key code given to the constructor (see L</new>).

=head2 char

	my $code_point = $event->char;

The raw Unicode code point of a typed character, C<0> for a special key.
Use C<chr $event-E<gt>char> to get the character, or better L</text>,
which also filters out control characters.

=head2 modifiers

	use Termbox 2 qw(TB_MOD_CTRL);
	my $ctrl_held = $event->modifiers & TB_MOD_CTRL;

The raw bit mask of C<TB_MOD_ALT>, C<TB_MOD_CTRL> and C<TB_MOD_SHIFT>.
Note that termbox2 sets C<TB_MOD_CTRL> on every key of the ASCII control
range, including Enter, Tab, Escape and Backspace; L</key_name> takes
care of that, so prefer it over testing the bits yourself.

=head1 KEY NAMES

These are all the names L</key_name> returns, without modifiers.

=head2 Named keys

	Name          Key
	------------  ------------------------------------------------
	Left          Arrow left
	Right         Arrow right
	Up            Arrow up
	Down          Arrow down
	Home          Home
	End           End
	PageUp        Page Up
	PageDown      Page Down
	Insert        Insert
	Delete        Delete (forward delete)
	Backspace     Backspace (byte 0x7F or 0x08)
	Tab           Tab (byte 0x09)
	BackTab       Shift+Tab, as most terminals report it
	Enter         Enter / Return (byte 0x0D)
	Escape        Escape (byte 0x1B)
	Space         The space bar (key 0x20, or key 0 with char 0x20)
	F1 .. F12     Function keys

=head2 Ctrl and a letter

Terminals send Ctrl plus a letter as a single control byte, and the name
is C<Ctrl+> followed by the uppercase letter: C<'Ctrl+A'> to C<'Ctrl+Z'>.
Some of these bytes are the same bytes other keys send, so the terminal
cannot tell them apart and they get the name of the other key:

	You press   Name
	---------   ---------
	Ctrl+H      Backspace
	Ctrl+I      Tab
	Ctrl+M      Enter
	Ctrl+[      Escape

The remaining control bytes are named after the symbol that produces
them on a US keyboard: C<'Ctrl+Space'> (byte 0, also sent for Ctrl+@ or
Ctrl+2), C<'Ctrl+\'>, C<'Ctrl+]'>, C<'Ctrl+^'> and C<'Ctrl+_'>. Ctrl+J
(byte 0x0A, line feed) is named C<'Ctrl+J'>, not C<'Enter'>.

termbox2 marks every control byte with C<TB_MOD_CTRL>. For these keys
C<key_name> ignores that bit and decides from the byte alone, so Enter is
always C<'Enter'>, never C<'Ctrl+Enter'>.

=head2 Modifier combinations

	Name                 You press
	-------------------  ----------------------------------------------
	Shift+Left           Shift and Left
	Ctrl+Right           Ctrl and Right
	Ctrl+Shift+Right     Ctrl, Shift and Right
	Alt+Down             Alt and Down
	Ctrl+Alt+Shift+F5    Ctrl, Alt, Shift and F5

Modifiers are reported only for the special keys that terminals send as
xterm modifier sequences: the four arrow keys, Home, End, Insert,
Delete, Page Up, Page Down and F1 to F12. Any combination of Ctrl, Alt
and Shift with these keys gets a name, as far as the terminal sends it.

For every other key, terminals cannot report modifiers, which leads to
these rules:

=over

=item *

Shift plus a character arrives as the shifted character, without a
modifier: Shift+a is C<'A'>, never C<'Shift+A'>.

=item *

Ctrl plus a letter arrives as a control byte and is named C<'Ctrl+W'>
and so on (see L</Ctrl and a letter>). Ctrl+Shift+W is the same byte,
so it is C<'Ctrl+W'> too.

=item *

Alt plus a character is sent as Escape followed by the character.
L<Term::Fabulous> reads input in termbox2's C<TB_INPUT_ESC> mode, so
Alt+x arrives as two separate key presses, C<'Escape'> and then C<'x'>.
Ctrl+Alt+W likewise arrives as C<'Escape'> and then C<'Ctrl+W'>. Names
such as C<'Alt+x'> therefore only occur for events you build yourself
with C<< modifiers => TB_MOD_ALT >>; a real terminal never produces
them, and Alt plus a letter cannot be bound as one key.

=back

=head2 Unnamed keys

C<key_name> returns C<undef> for key codes it does not know, for
example a C<TB_KEY_MOUSE_*> code given to the constructor by mistake.

=head1 BINDING KEYS

Compare L</key_name> with the name of the key you want. A dispatch table
keeps longer lists readable:

	use Clay::UI::Enum::Result;

	my %action = (
		'Ctrl+S' => sub { save_document() },
		'Ctrl+Q' => sub { $ui->loop->stop },
		'F1'     => sub { show_help() },
	);

	$root->on( KeyPress => sub ($event) {
		my $code = $action{ $event->key_name // '' }
			// return Clay::UI::Enum::Result->CONTINUE;
		$code->();
		return;
	} );

Key presses are fired on the focused widget first. A listener on the
root sees a key only if no widget on the way returned anything other
than C<< Clay::UI::Enum::Result->CONTINUE >>. The input widgets pass on
the keys they do not use (Escape, function keys, Ctrl+S, ...), so
application shortcuts on the root keep working while the user types.
See L<Term::Fabulous::Manual/KEYBOARD>.

Ctrl+C, Tab and Shift+Tab are fired like every other key, but
L<Term::Fabulous> then acts on them itself (it stops on Ctrl+C and moves
the focus on Tab and Shift+Tab); see
L<Term::Fabulous::Manual/Keys Term::Fabulous handles itself>.

=head1 SEE ALSO

L<Term::Fabulous::Manual/KEYBOARD>, L<Term::Fabulous>,
L<Term::Fabulous::Event::Mouse>, L<Clay::UI::Events::Event>, L<Termbox>.

=cut
