# NAME

Term::Fabulous::Event::KeyPress - A key press from the terminal

# SYNOPSIS

```perl
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
```

# DESCRIPTION

[Term::Fabulous](../../../../README.md) fires a `KeyPress` event for every key the terminal
reports while ["run" in Term::Fabulous](../../../../README.md#run) is active. The event is fired on the
focused widget, or on the root widget when no widget has the focus, and
then bubbles up to the ancestors (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)). Listen for it with
`$widget->on( KeyPress => sub ($event) { ... } )`.

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'KeyPress'` unless given to the
constructor) and `bubble_mode` (`IF_CONTINUE`) are available as well.

The most useful methods are ["key\_name"](#key_name), which turns the key into a
readable name such as `'Ctrl+Left'` for key bindings, ["main\_key\_name"](#main_key_name),
which names the keypad keys after the main keyboard keys they stand
for, and ["text"](#text), which returns the character a key types. The raw
termbox2 values are available through ["key"](#key), ["char"](#char) and
["modifiers"](#modifiers).

Terminals that speak the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
report more keys and modifiers than others; see
["THE KITTY KEYBOARD PROTOCOL"](#the-kitty-keyboard-protocol).

# CONSTRUCTOR

## new

```perl
use Term::Fabulous::Termbox qw(TB_KEY_ARROW_LEFT TB_MOD_CTRL TB_MOD_SHIFT);

my $typed_a    = Term::Fabulous::Event::KeyPress->new( key => 0, char => ord 'a', modifiers => 0 );
my $left       = Term::Fabulous::Event::KeyPress->new( key => TB_KEY_ARROW_LEFT, char => 0, modifiers => 0 );
my $word_left  = Term::Fabulous::Event::KeyPress->new( key => TB_KEY_ARROW_LEFT, char => 0, modifiers => TB_MOD_CTRL | TB_MOD_SHIFT );
my $ctrl_w     = Term::Fabulous::Event::KeyPress->new( key => 0x17, char => 0, modifiers => TB_MOD_CTRL );
my $enter      = Term::Fabulous::Event::KeyPress->new( key => 0x0D, char => 0, modifiers => 0 );

$text_field->fire_event($typed_a);
```

Programs rarely build key presses themselves; [Term::Fabulous](../../../../README.md) does it
for every key. Building one by hand is useful in tests of one widget,
to simulate typing at it; a whole program is tested with the keys of
["press\_key" in Term::Fabulous::Terminal::Memory](../Terminal/Memory.md#press_key), which go through the
focus like real ones (see ["TESTING" in Term::Fabulous::Manual::Programs](../Manual/Programs.md#testing)). The
three parameters below are required, and unknown parameters die. The
`name` and `bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are
accepted as well.

- `key`

    An integer. The termbox2 key code: a `TB_KEY_*` constant for special
    keys (arrows, Home, F1, ...), a `TF_KEY_*` constant for the keys only
    the kitty keyboard protocol reports (F13, the keypad, media keys, ...;
    see ["Kitty keys" in Term::Fabulous::Termbox](../Termbox.md#kitty-keys)), the byte value for keys of
    the ASCII control range (`0x0D` for Enter, `0x17` for Ctrl+W, ...),
    and `0` for a typed character.

- `char`

    An integer. The Unicode code point of a typed character (`ord 'a'`),
    or `0` for a special key. With the kitty keyboard protocol it also
    holds the key of a Ctrl combination the legacy encoding cannot carry:
    the control byte of Enter, Tab, Backspace or Escape for Ctrl+Enter and
    so on, or the unshifted character for Ctrl+I, Ctrl+1 and the like (see
    ["tf\_install\_input\_parser" in Term::Fabulous::Termbox](../Termbox.md#tf_install_input_parser)).

- `modifiers`

    An integer. A bit mask of the termbox2 constants `TB_MOD_ALT` (1),
    `TB_MOD_CTRL` (2) and `TB_MOD_SHIFT` (4), and of `TF_MOD_SUPER`
    (16), `TF_MOD_HYPER` (32) and `TF_MOD_META` (64), which only the
    kitty keyboard protocol reports; `0` for none.

An event object can be fired only once. Build a new one for every
`fire_event` call.

## of

```perl
my $event = Term::Fabulous::Event::KeyPress->of($termbox_event);
```

Builds an event from a `Term::Fabulous::Termbox::Event` as returned by termbox2's
`tb_peek_event` or `tb_poll_event`: `key` from its `key`, `char`
from its `ch` and `modifiers` from its `mod`. Called by
[Term::Fabulous](../../../../README.md); class method.

## fields\_for\_name

```perl
my %fields = Term::Fabulous::Event::KeyPress->fields_for_name('Ctrl+Shift+Left');
my $termbox_event = Term::Fabulous::Termbox::Event->new( type => TB_EVENT_KEY, %fields );
```

The other way round from ["key\_name"](#key_name): the `key`, `ch` and `mod`
fields of the termbox2 event a terminal reports for the key with that
name, the way termbox2 and its kitty keyboard protocol parser report
it. `Ctrl+W` is the control byte 0x17 with the Ctrl bit, `Enter` the
byte 0x0D (with the Ctrl bit termbox2 sets on every control byte),
`Ctrl+I` the character `i` with the Ctrl bit, `a` the character.
The [`press_key`](../Terminal/Memory.md#press_key) method
of Term::Fabulous::Terminal::Memory uses it. Class method.

The name must be one that ["key\_name"](#key_name) returns, with its modifiers in
the order `Ctrl`, `Alt`, `Shift`, `Super`, `Hyper`, `Meta` (see
["KEY NAMES"](#key-names)); a KeyPress built from the fields has exactly that
`key_name`. Any other name dies with
`Term::Fabulous::Event::KeyPress: no key is named 'ctrl+w'`.

# METHODS

## key\_name

```perl
my $name = $event->key_name;    # 'Left', 'Ctrl+Shift+Right', 'Enter', 'a', 'Ctrl+W', ...
```

Returns a readable name of the key together with its modifiers, or
`undef` for a key code that has no name (including the C1 control
characters U+0080 to U+009F, which ["text"](#text) does not return either).
Compare it with `eq` to bind
keys; see ["KEY NAMES"](#key-names) for every possible result. Because the result
can be `undef`, write `( $event->key_name // '' ) eq 'Ctrl+S'`
to avoid "uninitialized" warnings.

The name is built as follows:

- The modifiers come first, joined with `+`, always in the order
`Ctrl`, `Alt`, `Shift`, `Super`, `Hyper`, `Meta`:
`'Ctrl+Alt+Shift+Left'`, never `'Shift+Ctrl+Left'`. Only terminals
that speak the kitty keyboard protocol report `Super`, `Hyper` and
`Meta`.
- The key follows: a key name such as `Left` or `F5`, an uppercase
letter or a symbol after `Ctrl+` (`'Ctrl+W'`), or the typed character
itself (`'a'`, `'A'`, `'?'`, `'é'`).

## main\_key\_name

```perl
my $name = $event->main_key_name;    # 'Left' for both Left and the keypad's Left
```

Like ["key\_name"](#key_name), except that a keypad key the kitty keyboard
protocol tells apart is named after the main keyboard key it stands
for, as terminals without the protocol report it: `KeypadLeft` is
`'Left'`, `KeypadEnter` is `'Enter'`, `Keypad7` is `'7'`,
`KeypadAdd` is `'+'`, and `'Ctrl+KeypadHome'` is `'Ctrl+Home'`.
`KeypadBegin` has no such key and keeps its name. For every other key
the result is the same as ["key\_name"](#key_name). The built-in widgets bind
their keys with `main_key_name`, so the keypad works in them with or
without the protocol; use it for bindings that should do the same.

## text

```perl
my $character = $event->text;
```

Returns the character the key types, as a character string of length
one, or `undef` when the key does not type anything.

- A printable character typed without Ctrl or Alt returns that character:
`'a'`, `'A'`, `'7'`, `'?'`, `'é'`, a CJK character, and so on.
- The space bar returns `' '`, however the terminal reports it.
- Special keys (arrows, Enter, Tab, Backspace, Escape, function keys, ...),
combinations with Ctrl, Alt, Super, Hyper or Meta, and control
characters (U+0000 to U+001F, U+007F to U+009F) return `undef`.

Text inputs insert exactly what `text` returns.

## key

```perl
my $code = $event->key;
```

The raw termbox2 key code given to the constructor (see ["new"](#new)).

## char

```perl
my $code_point = $event->char;
```

The raw Unicode code point of a typed character, `0` for a special key.
Use `chr $event->char` to get the character, or better ["text"](#text),
which also filters out control characters.

## modifiers

```perl
use Term::Fabulous::Termbox qw(TB_MOD_CTRL);
my $ctrl_held = $event->modifiers & TB_MOD_CTRL;
```

The raw bit mask of `TB_MOD_ALT`, `TB_MOD_CTRL` and `TB_MOD_SHIFT`,
and of `TF_MOD_SUPER`, `TF_MOD_HYPER` and `TF_MOD_META` from the
kitty keyboard protocol. Note that termbox2 sets `TB_MOD_CTRL` on every key of the ASCII control
range, including Enter, Tab, Escape and Backspace; ["key\_name"](#key_name) takes
care of that, so prefer it over testing the bits yourself.

# KEY NAMES

These are all the names ["key\_name"](#key_name) returns, without modifiers.

## Named keys

| Name      | Key                                               |
| --------- | ------------------------------------------------- |
| Left      | Arrow left                                        |
| Right     | Arrow right                                       |
| Up        | Arrow up                                          |
| Down      | Arrow down                                        |
| Home      | Home                                              |
| End       | End                                               |
| PageUp    | Page Up                                           |
| PageDown  | Page Down                                         |
| Insert    | Insert                                            |
| Delete    | Delete (forward delete)                           |
| Backspace | Backspace (byte 0x7F or 0x08)                     |
| Tab       | Tab (byte 0x09)                                   |
| BackTab   | Shift+Tab, as most terminals report it            |
| Enter     | Enter / Return (byte 0x0D)                        |
| Escape    | Escape (byte 0x1B)                                |
| Space     | The space bar (key 0x20, or key 0 with char 0x20) |
| F1 .. F12 | Function keys                                     |

Terminals that speak the kitty keyboard protocol report these keys as
well:

| Name               | Key                                        |
| ------------------ | ------------------------------------------ |
| F13 .. F35         | Function keys beyond F12                   |
| CapsLock           | Caps Lock                                  |
| ScrollLock         | Scroll Lock                                |
| NumLock            | Num Lock                                   |
| PrintScreen        | Print Screen                               |
| Pause              | Pause                                      |
| Menu               | Menu (context menu key)                    |
| Keypad0 .. Keypad9 | Keypad digits                              |
| KeypadDecimal      | Keypad . (decimal point)                   |
| KeypadDivide       | Keypad /                                   |
| KeypadMultiply     | Keypad *                                   |
| KeypadSubtract     | Keypad -                                   |
| KeypadAdd          | Keypad +                                   |
| KeypadEnter        | Keypad Enter                               |
| KeypadEqual        | Keypad =                                   |
| KeypadSeparator    | Keypad separator                           |
| KeypadLeft         | Keypad Left (Num Lock off), and so on:     |
| KeypadRight        | KeypadUp, KeypadDown, KeypadPageUp,        |
|                    | KeypadPageDown, KeypadHome, KeypadEnd,     |
|                    | KeypadInsert, KeypadDelete                 |
| KeypadBegin        | Keypad 5 with Num Lock off                 |
| MediaPlay          | Media keys: MediaPause, MediaPlayPause,    |
|                    | MediaReverse, MediaStop, MediaFastForward, |
|                    | MediaRewind, MediaTrackNext,               |
|                    | MediaTrackPrevious, MediaRecord            |
| LowerVolume        | Volume down                                |
| RaiseVolume        | Volume up                                  |
| MuteVolume         | Mute                                       |

kitty reports the keypad keys only when they do not type text: with
Num Lock on, a keypad digit typed alone is the character `'7'`, but
Ctrl plus that key is `'Ctrl+Keypad7'`. ["main\_key\_name"](#main_key_name) names the
keypad keys after their main keyboard keys instead. Whether the lock
keys, Print Screen and the media keys reach the program at all depends
on the terminal and the desktop.

## Ctrl and a letter

Terminals send Ctrl plus a letter as a single control byte, and the name
is `Ctrl+` followed by the uppercase letter: `'Ctrl+A'` to `'Ctrl+Z'`.
Some of these bytes are the same bytes other keys send, so the terminal
cannot tell them apart and they get the name of the other key:

| You press | Name      |
| --------- | --------- |
| Ctrl+H    | Backspace |
| Ctrl+I    | Tab       |
| Ctrl+M    | Enter     |
| Ctrl+[    | Escape    |

The remaining control bytes are named after the symbol that produces
them on a US keyboard: `'Ctrl+Space'` (byte 0, also sent for Ctrl+@ or
Ctrl+2), `'Ctrl+\'`, `'Ctrl+]'`, `'Ctrl+^'` and `'Ctrl+_'`. Ctrl+J
(byte 0x0A, line feed) is named `'Ctrl+J'`, not `'Enter'`.

termbox2 marks every control byte with `TB_MOD_CTRL`. For these keys
`key_name` ignores that bit and decides from the byte alone, so Enter is
always `'Enter'`, never `'Ctrl+Enter'`. Terminals that speak the kitty
keyboard protocol tell all of these keys apart; see
["THE KITTY KEYBOARD PROTOCOL"](#the-kitty-keyboard-protocol).

## Modifier combinations

| Name              | You press               |
| ----------------- | ----------------------- |
| Shift+Left        | Shift and Left          |
| Ctrl+Right        | Ctrl and Right          |
| Ctrl+Shift+Right  | Ctrl, Shift and Right   |
| Alt+Down          | Alt and Down            |
| Ctrl+Alt+Shift+F5 | Ctrl, Alt, Shift and F5 |

Modifiers are reported only for the special keys that terminals send as
xterm modifier sequences: the four arrow keys, Home, End, Insert,
Delete, Page Up, Page Down and F1 to F12. Any combination of Ctrl, Alt
and Shift with these keys gets a name, as far as the terminal sends it.

For every other key, terminals cannot report modifiers, unless they
speak the kitty keyboard protocol (see ["THE KITTY KEYBOARD PROTOCOL"](#the-kitty-keyboard-protocol)),
which leads to these rules:

- Shift plus a character arrives as the shifted character, without a
modifier: Shift+a is `'A'`, never `'Shift+A'`.
- Ctrl plus a letter arrives as a control byte and is named `'Ctrl+W'`
and so on (see ["Ctrl and a letter"](#ctrl-and-a-letter)). Ctrl+Shift+W is the same byte,
so it is `'Ctrl+W'` too.
- Alt plus a character is sent as Escape followed by the character, in
one write. [Term::Fabulous](../../../../README.md) recognizes that pair and names it
`'Alt+x'`, `'Alt+Enter'`, `'Alt+ü'`; Ctrl+Alt+W arrives as
`'Ctrl+Alt+W'`. A lone Escape is still `'Escape'`. Alt+\[ and Alt+O
cannot be told from the start of the escape sequences of other keys and
are not named. An Escape followed so quickly by a key that both arrive
in the same read looks like Alt plus that key.

## Unnamed keys

`key_name` returns `undef` for key codes it does not know, for
example a `TB_KEY_MOUSE_*` code given to the constructor by mistake.

# THE KITTY KEYBOARD PROTOCOL

[Term::Fabulous](../../../../README.md) asks the terminal for the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
when it supports it (kitty and a growing number of other terminals;
see the `kitty_keyboard` parameter of ["new" in Term::Fabulous](../../../../README.md#new)). Such a terminal reports keys
without the ambiguities of the legacy encodings, and the names follow:

- Every Ctrl combination gets its own name: Ctrl+I is `'Ctrl+I'`, not
`'Tab'`; Ctrl+M is `'Ctrl+M'`, Ctrl+H `'Ctrl+H'`, Ctrl+\[ `'Ctrl+['`;
Ctrl+Enter, Ctrl+Tab, Ctrl+Backspace and Ctrl+Escape are
`'Ctrl+Enter'` and so on; Ctrl+1 is `'Ctrl+1'`.
- Shift is named together with Ctrl: Ctrl+Shift+W is `'Ctrl+Shift+W'`,
no longer the same as `'Ctrl+W'`. Shift+Enter is `'Shift+Enter'`.
- Alt plus a key no longer depends on timing, and Alt+\[ and Alt+O get
names. Alt plus a character is still named after the character Shift
makes, as in other terminals: Alt+Shift+a is `'Alt+A'`, Alt+Shift+1 on
a US keyboard `'Alt+!'`.
- Super, Hyper and Meta are reported; they behave like Alt:
`'Super+a'`, `'Ctrl+Super+Left'`.
- The keys in the second table of ["Named keys"](#named-keys) are reported.

Keys typed without a modifier are unchanged: the character, Enter, Tab,
Backspace and Shift+Tab (`'BackTab'`) are reported as in any other
terminal, and so are the names of Ctrl+C, Tab and Shift+Tab that
[Term::Fabulous](../../../../README.md) acts on itself.

# BINDING KEYS

Compare ["key\_name"](#key_name) with the name of the key you want, or
["main\_key\_name"](#main_key_name) when the keypad keys should count as the main keyboard
keys they stand for. To find the name of a key on your terminal, run
`examples/event-monitor.pl` and press it. A dispatch table keeps longer lists readable:

```perl
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
```

Key presses are fired on the focused widget first. A listener on the
root sees a key only if no widget on the way returned anything other
than `Clay::UI::Enum::Result->CONTINUE`. The input widgets pass on
the keys they do not use (Escape, function keys, Ctrl+S, ...), so
application shortcuts on the root keep working while the user types.
See ["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard).

Ctrl+C, Tab and Shift+Tab are fired like every other key, but
[Term::Fabulous](../../../../README.md) then acts on them itself (it stops on Ctrl+C and moves
the focus on Tab and Shift+Tab); see
["Keys Term::Fabulous handles itself" in Term::Fabulous::Manual::Events](../Manual/Events.md#keys-term-fabulous-handles-itself).

# SEE ALSO

["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard), [Term::Fabulous](../../../../README.md),
[Term::Fabulous::Event::Mouse](Mouse.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), [Term::Fabulous::Termbox](../Termbox.md),
["Bind a key to an action" in Term::Fabulous::Cookbook::KeyboardAndMouse](../Cookbook/KeyboardAndMouse.md#bind-a-key-to-an-action),
["Quit with q or Escape" in Term::Fabulous::Cookbook::GettingStarted](../Cookbook/GettingStarted.md#quit-with-q-or-escape).
