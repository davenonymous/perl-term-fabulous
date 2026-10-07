# NAME

Term::Fabulous::Termbox - termbox2 compiled into Term::Fabulous

# SYNOPSIS

```perl
use Term::Fabulous::Termbox qw(:api :keys :colors :event :return);
use Term::Fabulous::Termbox::Event;

my $rc = tb_init();
die tb_strerror($rc) unless $rc == TB_OK;
tb_set_output_mode(TB_OUTPUT_TRUECOLOR);

tb_set_cell( 0, 0, 'A', 0xFF8800 | TB_BOLD, TB_DEFAULT );
tb_set_cell( 1, 0, "e\x{301}", TB_DEFAULT, TB_DEFAULT );    # first codepoint ...
tb_extend_cell( 1, 0, "\x{301}" );                           # ... then the combining mark
tb_set_cell_ex( 2, 0, "\x{1F1E9}\x{1F1EA}", TB_DEFAULT, TB_DEFAULT );    # or the whole cluster at once
tb_present();

my $event = Term::Fabulous::Termbox::Event->new;
while ( tb_poll_event($event) == TB_OK ) {
        last if $event->type == TB_EVENT_KEY && $event->key == TB_KEY_CTRL_C;
}
tb_shutdown();

use Term::Fabulous::Termbox qw(:width);
tb_wcwidth(0x4E00);                       # 2
tb_cluster_width("\x{2764}\x{FE0F}");    # 2: VS16 asks for emoji presentation
```

# DESCRIPTION

An XS binding of [termbox2](https://github.com/termbox/termbox2), compiled
from the header shipped in the distribution (`src/termbox2.h`, see
`src/README.termbox2` for the exact upstream commit). Nothing is looked up
at run time, and the compile-time options are fixed:

- `TB_OPT_ATTR_W` is 64: an attribute carries a 24-bit color and every
style bit, `TB_STRIKEOUT`, `TB_UNDERLINE_2`, `TB_OVERLINE` and
`TB_INVISIBLE` included. [tb\_attr\_width](#tb_has_truecolor-tb_has_egc-tb_attr_width-tb_version) reports 64.
- `TB_OPT_EGC` is set: a cell holds a whole grapheme cluster
(["tb\_extend\_cell"](#tb_extend_cell), ["tb\_set\_cell\_ex"](#tb_set_cell_ex)). [tb\_has\_egc](#tb_has_truecolor-tb_has_egc-tb_attr_width-tb_version) reports 1.
- termbox2 measures with its own Unicode tables (`TB_OPT_LIBC_WCHAR` is
not set), so widths are the same on every platform. ["tb\_wcwidth"](#tb_wcwidth) and
["tb\_cluster\_width"](#tb_cluster_width) expose exactly the functions `tb_present` uses.

Every function keeps its termbox2 name and returns its status code, `TB_OK`
or one of the `TB_ERR_*` constants; nothing dies on a terminal error.
The exceptions are arguments the binding cannot translate at all, such as
an empty string where a character is needed or a string that carries the
UTF8 flag over bytes that are not well-formed UTF-8 (made by
`Encode::_utf8_on` or read through a `:utf8` layer), which die before
termbox2 is called.

# EXPORTS

Nothing is exported by default. The tags are

- `:api`

    The functions below, except the width functions.

- `:width`

    ["tb\_iswprint"](#tb_iswprint), ["tb\_wcwidth"](#tb_wcwidth), ["tb\_cluster\_width"](#tb_cluster_width).

- `:keys`

    Every `TB_KEY_*` constant, plus the Term::Fabulous additions
    `TF_KEY_MOUSE_MOVE`, `TF_KEY_MOUSE_WHEEL_LEFT` and
    `TF_KEY_MOUSE_WHEEL_RIGHT`, and the keys only the kitty keyboard
    protocol reports (see ["tf\_install\_input\_parser"](#tf_install_input_parser) and ["Kitty keys"](#kitty-keys)): the
    ASCII control range (`TB_KEY_CTRL_A` to
    `TB_KEY_CTRL_Z`, `TB_KEY_TAB`, `TB_KEY_ENTER`, `TB_KEY_ESC`,
    `TB_KEY_SPACE`, `TB_KEY_BACKSPACE`, `TB_KEY_BACKSPACE2`, ...), the
    function and navigation keys (`TB_KEY_F1` to `TB_KEY_F12`,
    `TB_KEY_ARROW_*`, `TB_KEY_HOME`, `TB_KEY_END`, `TB_KEY_PGUP`,
    `TB_KEY_PGDN`, `TB_KEY_INSERT`, `TB_KEY_DELETE`, `TB_KEY_BACK_TAB`) and
    the mouse "keys" (`TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_RIGHT`,
    `TB_KEY_MOUSE_MIDDLE`, `TB_KEY_MOUSE_RELEASE`, `TB_KEY_MOUSE_WHEEL_UP`,
    `TB_KEY_MOUSE_WHEEL_DOWN`).

- `:colors`

    `TB_DEFAULT`, the eight basic colors `TB_BLACK` to `TB_WHITE`, and the
    style bits `TB_BOLD`, `TB_UNDERLINE`, `TB_REVERSE`, `TB_ITALIC`,
    `TB_BLINK`, `TB_HI_BLACK`, `TB_BRIGHT`, `TB_DIM`, `TB_STRIKEOUT`,
    `TB_UNDERLINE_2`, `TB_OVERLINE`, `TB_INVISIBLE`. In truecolor mode the
    low 24 bits of an attribute are the RGB value; since `0x000000` means
    "terminal default" there, opaque black is `TB_HI_BLACK`. The deprecated
    aliases `TB_TRUECOLOR_BOLD`, `TB_TRUECOLOR_UNDERLINE`,
    `TB_TRUECOLOR_REVERSE`, `TB_TRUECOLOR_ITALIC`, `TB_TRUECOLOR_BLINK`,
    `TB_TRUECOLOR_BLACK` are exported too.

- `:event`

    `TB_EVENT_KEY`, `TB_EVENT_RESIZE`, `TB_EVENT_MOUSE`; the modifiers
    `TB_MOD_ALT`, `TB_MOD_CTRL`, `TB_MOD_SHIFT`, `TB_MOD_MOTION`, and the
    Term::Fabulous additions `TF_MOD_SUPER`, `TF_MOD_HYPER`, `TF_MOD_META`
    (16, 32, 64; only the kitty keyboard protocol reports them); the input
    modes `TB_INPUT_CURRENT`, `TB_INPUT_ESC`, `TB_INPUT_ALT`,
    `TB_INPUT_MOUSE`; the output modes `TB_OUTPUT_CURRENT`,
    `TB_OUTPUT_NORMAL`, `TB_OUTPUT_256`, `TB_OUTPUT_216`,
    `TB_OUTPUT_GRAYSCALE`, `TB_OUTPUT_TRUECOLOR`.

- `:return`

    `TB_OK` and every `TB_ERR_*` code, [tb\_strerror](#tb_last_errno-tb_strerror) names them.

- `:all`

    Everything.

## Kitty keys

The keys of the kitty keyboard protocol's functional key table that
neither termbox2 nor the legacy encodings have a code for, numbered
from `0xFFFF - 32` down in the order of kitty's table:
`TF_KEY_CAPS_LOCK`, `TF_KEY_SCROLL_LOCK`, `TF_KEY_NUM_LOCK`,
`TF_KEY_PRINT_SCREEN`, `TF_KEY_PAUSE`, `TF_KEY_MENU`; `TF_KEY_F13`
to `TF_KEY_F35`; the keypad keys `TF_KEY_KP_0` to `TF_KEY_KP_9`,
`TF_KEY_KP_DECIMAL`, `TF_KEY_KP_DIVIDE`, `TF_KEY_KP_MULTIPLY`,
`TF_KEY_KP_SUBTRACT`, `TF_KEY_KP_ADD`, `TF_KEY_KP_ENTER`,
`TF_KEY_KP_EQUAL`, `TF_KEY_KP_SEPARATOR`, `TF_KEY_KP_LEFT`,
`TF_KEY_KP_RIGHT`, `TF_KEY_KP_UP`, `TF_KEY_KP_DOWN`,
`TF_KEY_KP_PAGE_UP`, `TF_KEY_KP_PAGE_DOWN`, `TF_KEY_KP_HOME`,
`TF_KEY_KP_END`, `TF_KEY_KP_INSERT`, `TF_KEY_KP_DELETE`,
`TF_KEY_KP_BEGIN`; and the media keys `TF_KEY_MEDIA_PLAY`,
`TF_KEY_MEDIA_PAUSE`, `TF_KEY_MEDIA_PLAY_PAUSE`,
`TF_KEY_MEDIA_REVERSE`, `TF_KEY_MEDIA_STOP`,
`TF_KEY_MEDIA_FAST_FORWARD`, `TF_KEY_MEDIA_REWIND`,
`TF_KEY_MEDIA_TRACK_NEXT`, `TF_KEY_MEDIA_TRACK_PREVIOUS`,
`TF_KEY_MEDIA_RECORD`, `TF_KEY_LOWER_VOLUME`,
`TF_KEY_RAISE_VOLUME`, `TF_KEY_MUTE_VOLUME`. They are exported with
`:keys`.

# FUNCTIONS

## Lifecycle

### tb\_init, tb\_init\_file, tb\_init\_fd, tb\_init\_rwfd

```perl
my $rc = tb_init();
my $rc = tb_init_file('/dev/tty');
my $rc = tb_init_fd($ttyfd);
my $rc = tb_init_rwfd( $rfd, $wfd );
```

Open the terminal. `tb_init` uses `/dev/tty`.

### tf\_init\_inline, tf\_init\_inline\_rwfd

```perl
my $rc = tf_init_inline();
my $rc = tf_init_inline_rwfd( $rfd, $wfd );
```

A Term::Fabulous addition: open the terminal like `tb_init` and
`tb_init_rwfd`, but without taking over the screen. termbox2 then
neither switches to the alternate screen nor clears the screen, not
when it starts, not on a resize and not in `tb_shutdown`, so what the
terminal showed before stays. The cell buffers still cover the whole
terminal and `tb_present` still places cells at absolute positions:
the caller paints only the rows it owns (see ["tf\_cursor\_position"](#tf_cursor_position))
and leaves the others as `tb_clear` left them, so that `tb_present`
sends nothing for them. The `inline` parameter of ["new" in Term::Fabulous](../../../README.md#new)
is built on this.

### tb\_shutdown

Restores the terminal.

### tb\_width, tb\_height

The terminal size in cells, or `TB_ERR_NOT_INIT` before [tb\_init](#tb_init-tb_init_file-tb_init_fd-tb_init_rwfd).

### tb\_set\_input\_mode, tb\_set\_output\_mode

```perl
tb_set_input_mode( TB_INPUT_ESC | TB_INPUT_MOUSE );
tb_set_output_mode(TB_OUTPUT_TRUECOLOR);
```

## Drawing

### tb\_clear, tb\_set\_clear\_attrs, tb\_present, tb\_invalidate

As in termbox2: `tb_clear` fills the back buffer with the clear
attributes, `tb_present` sends the changed cells, `tb_invalidate` forces
a full redraw on the next `tb_present`.

### tb\_set\_cursor, tb\_hide\_cursor

```perl
tb_set_cursor( $x, $y );
tb_hide_cursor();
```

Show the terminal cursor at cell (`$x`, `$y`), or hide it. Both return
`TB_OK` or an error code; the change shows with the next `tb_present`.

### tb\_set\_cell

```perl
tb_set_cell( $x, $y, $character, $fg, $bg );
```

Writes one cell. `$character` is a Perl string whose first codepoint is
used; an integer that was never a string is taken as the codepoint itself.
An empty string or malformed UTF-8 dies.

### tb\_extend\_cell

```perl
tb_extend_cell( $x, $y, $character );
```

Appends the first codepoint of `$character` to the cell's grapheme
cluster. An empty string or malformed UTF-8 dies.

### tb\_set\_cell\_ex

```perl
tb_set_cell_ex( $x, $y, $cluster, $fg, $bg );
```

Writes a whole grapheme cluster at once: every codepoint of `$cluster`.
An empty string or malformed UTF-8 dies.

### tb\_get\_cell

```perl
my ( $rc, $text, $fg, $bg ) = tb_get_cell( $x, $y, $back );
```

Reads a cell from the back (`$back` true) or front buffer. `$text` is the
cell's cluster as a string. Only `$rc` is returned unless it is `TB_OK`.

### tb\_print

```perl
tb_print( $x, $y, $fg, $bg, $text );
```

Writes a string cell by cell, advancing by each cluster's width.

### tb\_send

```perl
tb_send($bytes);
```

Queues bytes for the terminal, for escape sequences termbox2 has no
function for. A string whose characters are all below 0x100 is sent
byte for byte, whether or not Perl stores it UTF-8 encoded; a string
with a wider character is sent UTF-8 encoded. Like everything termbox2
writes, the bytes stay in its output buffer until the next
`tb_present` or `tb_shutdown`.

### tf\_reset\_attrs

```perl
my $rc = tf_reset_attrs();
```

A Term::Fabulous addition. Queues the reset of all colors and styles
(`SGR 0`), for escape sequences sent with ["tb\_send"](#tb_send) that depend on
them, such as erasing (it uses the current background color). The next
cell `tb_present` draws sets its colors again, which termbox2 would
otherwise skip when it believes the terminal still has them.

### tf\_flush

```perl
my $rc = tf_flush();
```

A Term::Fabulous addition. Writes what ["tb\_send"](#tb_send) and the drawing
functions queued, without waiting for the next `tb_present`.

### tf\_cells\_differ

```perl
my $rc = tf_cells_differ( $x, $y, $width, $height, \my $differ );
```

A Term::Fabulous addition. Sets `$differ` to 1 when the next
`tb_present` would draw a cell of the rectangle, because the cell was
set to something other than what the terminal shows, else to 0. The
part of the rectangle outside the screen is ignored. Returns `TB_OK`
or an error; `$differ` is untouched unless the result is `TB_OK`.
Dies unless the last argument is a scalar reference.

### tf\_invalidate\_cells

```perl
my $rc = tf_invalidate_cells( $x, $y, $width, $height );
```

A Term::Fabulous addition. Makes the next `tb_present` draw every
cell of the rectangle, like `tb_invalidate` does for the whole screen:
for cells the terminal shows differently from what termbox2 believes,
such as the cells a sixel image covered. The part of the rectangle
outside the screen is ignored.

## Events

### tb\_peek\_event

```perl
my $rc = tb_peek_event( $event, $timeout_ms );
```

Waits up to `$timeout_ms` for an event and fills `$event`, a
[Term::Fabulous::Termbox::Event](Termbox/Event.md), in place. Returns `TB_OK`,
`TB_ERR_NO_EVENT` after the timeout, or an error. `$event` is untouched
unless the result is `TB_OK`.

### tb\_poll\_event

```perl
my $rc = tb_poll_event($event);
```

Like ["tb\_peek\_event"](#tb_peek_event) without a timeout.

### tf\_install\_input\_parser

```perl
my $rc = tf_install_input_parser();
```

A Term::Fabulous addition. Installs a reader that runs before termbox2's
own escape sequence parsers and decodes what they get wrong: Escape
followed by a key in the same read becomes that key with `TB_MOD_ALT`
(Alt+x, Alt+Enter, Alt plus an umlaut), and SGR mouse reports keep
their modifier bits (`TB_MOD_SHIFT`, `TB_MOD_ALT`, `TB_MOD_CTRL`),
report the pointer moving with no button as `TF_KEY_MOUSE_MOVE` with
`TB_MOD_MOTION`, and report a horizontal wheel as
`TF_KEY_MOUSE_WHEEL_LEFT` and `TF_KEY_MOUSE_WHEEL_RIGHT`, and say
which button a `TB_KEY_MOUSE_RELEASE` released: the event's `ch` is
`TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE` or `TB_KEY_MOUSE_RIGHT`
(0 when the terminal did not name the button, as in reports termbox2
decodes itself). Escape
sequences that begin with `ESC [` or `ESC O` and are not SGR mouse
reports are left to termbox2. `tb_shutdown` forgets the parser, so
call this after every `tb_init`. Returns `TB_OK`.

It also decodes the key reports of the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/),
`ESC [ code ; modifiers u`, and the legacy forms of the function keys,
`ESC [ number ; modifiers ~` and `ESC [ 1 ; modifiers letter`, when
they carry modifiers. kitty's Super, Hyper and Meta become
`TF_MOD_SUPER`, `TF_MOD_HYPER` and `TF_MOD_META`; Caps Lock and Num
Lock are dropped. The keys come as termbox2 would report them from a
legacy terminal wherever that report is exact, so code written for
termbox2 keeps working:

- Escape is `TB_KEY_ESC`; Enter, Tab and Backspace without Ctrl are
their control byte with `TB_MOD_CTRL`, as termbox2 reports the bytes;
Shift+Tab is `TB_KEY_BACK_TAB`.
- Ctrl plus a letter, Space, `\` or `]` is its control byte (Ctrl+C is
`TB_KEY_CTRL_C`), with `TB_MOD_SHIFT` and the other modifiers added
when they were held.
- What the legacy encoding cannot carry has its character in `ch`
instead, with exact modifiers: Ctrl plus Enter, Tab, Backspace or
Escape (`ch` is the control byte), and Ctrl plus a key whose control
byte is another key's or that has none (Ctrl+I, Ctrl+M, Ctrl+H, Ctrl+\[,
Ctrl+1, ...; `ch` is the unshifted character).
- Alt, Super, Hyper or Meta plus a key without Ctrl is the character
Shift makes in `ch`, without `TB_MOD_SHIFT`, like Alt plus a key from
a legacy terminal: Alt+Shift+1 is `!` with `TB_MOD_ALT` when the
terminal reports the shifted key (kitty's "report alternate keys"
flag), and Alt+Shift+a is `A` either way.
- The keys without a legacy encoding are the ["Kitty keys"](#kitty-keys).

kitty sends these reports for the keys that have no legacy encoding
even to programs that did not ask for the protocol. For the others,
ask the terminal with `tb_send("\e[>5u")` after
["tf\_kitty\_keyboard\_query"](#tf_kitty_keyboard_query) found it supported, and send `"\e[<u"`
before `tb_shutdown`, as [Term::Fabulous](../../../README.md) does.

The parser only decodes; to receive motion reports at all, ask the
terminal with `tb_send("\e[?1003h")` (and send `"\e[?1003l"`
before `tb_shutdown`), as [Term::Fabulous](../../../README.md) does.

### tf\_cursor\_position

```perl
my $rc = tf_cursor_position( $timeout_ms, \my $x, \my $y );
```

A Term::Fabulous addition. Asks the terminal where its cursor is
(`ESC [ 6 n`), waits up to `$timeout_ms` milliseconds for the answer
and stores the column and the row, counted from 0, through the
references. Input that arrives meanwhile, such as keys typed ahead,
stays queued for ["tb\_peek\_event"](#tb_peek_event); it is read already, so the
terminal descriptor no longer reports it as readable. Returns
`TB_OK`, `TB_ERR_NO_EVENT` when no answer arrived in time, or
another error; the references are untouched unless the result is
`TB_OK`. Dies unless both references are scalar references.

### tf\_kitty\_keyboard\_query

```perl
my $rc = tf_kitty_keyboard_query( $timeout_ms, \my $supported );
```

A Term::Fabulous addition. Asks the terminal whether it speaks the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/):
it sends the query for the protocol's flags (`ESC [ ? u`) followed by
the one for the primary device attributes (`ESC [ c`), which every
terminal answers, and waits up to `$timeout_ms` milliseconds for
that answer. `$supported` is then 1 when the terminal reported its
flags, 0 when it answered the device attributes alone. Both answers
are taken out of the input; keys that arrive meanwhile stay queued for
["tb\_peek\_event"](#tb_peek_event), as with ["tf\_cursor\_position"](#tf_cursor_position). Returns `TB_OK`,
`TB_ERR_NO_EVENT` when no answer arrived in time (the terminal is
taken not to speak the protocol), or another error; `$supported` is
untouched unless the result is `TB_OK`. Dies unless the argument is
a scalar reference.

### tf\_sixel\_query

```perl
my $rc = tf_sixel_query( $timeout_ms, \my $supported, \my $cell_width, \my $cell_height );
```

A Term::Fabulous addition. Asks the terminal whether it shows sixel
graphics and how many pixels a cell has: it sends the query for the
size of a cell (`ESC [ 16 t`) followed by the one for the primary
device attributes (`ESC [ c`), which every terminal answers, and
waits up to `$timeout_ms` milliseconds for that answer. `$supported`
is then 1 when the device attributes list `4` (sixel graphics), else
0\. `$cell_width` and `$cell_height` are the pixels of a cell the
terminal reported, else the ones the window size of the terminal
device gives (`ioctl TIOCGWINSZ`), else both 0. Both answers are
taken out of the input; keys that arrive meanwhile stay queued for
["tb\_peek\_event"](#tb_peek_event), as with ["tf\_cursor\_position"](#tf_cursor_position). Returns `TB_OK`,
`TB_ERR_NO_EVENT` when no device attributes arrived in time, or
another error; the references are untouched unless the result is
`TB_OK`. Dies unless the last three arguments are scalar references.

### tf\_readable\_bytes

```perl
my $count = tf_readable_bytes($fd);
```

A Term::Fabulous addition. The number of bytes waiting to be read from
the file descriptor (`ioctl FIONREAD`), or -1 when the descriptor
cannot tell (`$!` says why). A terminal descriptor that is readable
while this returns 0 is at end of file: the terminal is gone. A
terminal that hung up returns -1 with `$!` set to `EIO`.

### tb\_get\_fds

```perl
my $rc = tb_get_fds( \my $tty_fd, \my $resize_fd );
```

Stores termbox2's tty and resize-pipe descriptors through the references,
for an event loop that waits on them itself. Dies unless both arguments
are scalar references.

## Widths

### tb\_iswprint

```perl
my $printable = tb_iswprint($codepoint);
```

### tb\_wcwidth

```perl
my $columns = tb_wcwidth($codepoint);
```

The columns one codepoint takes: 0, 1, 2, or -1 for a codepoint that is
not printable.

### tb\_cluster\_width

```perl
my $columns = tb_cluster_width($cluster);
```

The columns a grapheme cluster takes, measured the way `tb_present` does:
the widest codepoint's width, forced to 1 when the cluster holds a
variation selector 15 (text presentation) and to 2 when it holds a
variation selector 16 (emoji presentation), a zero-width joiner or two
regional indicators. Clusters below width 1 still occupy one cell when
drawn. Dies on an empty string or malformed UTF-8.

## Diagnostics

### tb\_last\_errno, tb\_strerror

```perl
my $message = tb_strerror($rc);
```

### tb\_has\_truecolor, tb\_has\_egc, tb\_attr\_width, tb\_version

Report the compile-time options: 1, 1, 64 and the termbox2 version string.

# NOT BOUND

`tb_printf`, `tb_sendf` and `tb_printf_ex` (variadic; format in Perl and
use ["tb\_print"](#tb_print) or ["tb\_send"](#tb_send)), the deprecated `tb_set_func` and
`tb_cell_buffer` (use ["tb\_get\_cell"](#tb_get_cell)), and the `tb_utf8_*` helpers
(Perl strings are already Unicode).

# SEE ALSO

[Term::Fabulous::Termbox::Event](Termbox/Event.md), [Term::Fabulous](../../../README.md),
[termbox2](https://github.com/termbox/termbox2).

# AUTHOR

davenonymous <perl@davenonymous.com>

# COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

termbox2 is Copyright (c) 2015-2026 Adam Saponara and 2010-2020 nsf, and
distributed under the MIT license; see the header of `src/termbox2.h`.
