# NAME

Term::Fabulous::Terminal::Termbox - The real terminal, through termbox2

# SYNOPSIS

```perl
use Term::Fabulous;
use Term::Fabulous::Terminal::Termbox;

# The default terminal of Term::Fabulous; there is no need to pass it.
my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

# Another terminal, for example the slave side of a pseudo terminal.
my $terminal = Term::Fabulous::Terminal::Termbox->new( input => $tty, output => $tty );
my $other    = Term::Fabulous->new( root => $other_root, width => 80, height => 24, terminal => $terminal );
```

# DESCRIPTION

Most programs never use this module directly: it is the terminal
[Term::Fabulous](../../../../README.md) uses unless it is given another one. It implements
[Term::Fabulous::Role::Terminal](../Role/Terminal.md) with the termbox2 library
([Term::Fabulous::Termbox](../Termbox.md)), and paints through its cell target
[Term::Fabulous::Terminal::Termbox::Cells](Termbox/Cells.md).

When a session is opened (see ["open"](#open)), it:

- starts termbox2 in full-screen mode (`tb_init`, which switches to the
alternate screen) or, in inline mode, without taking over the screen
(`tf_init_inline`);
- switches to 24-bit colors and to the input parser of
[Term::Fabulous::Termbox](../Termbox.md), which reads Alt combinations, the mouse in
SGR encoding and the kitty keyboard protocol;
- with `mouse`, asks the terminal for clicks, drags, the wheel and the
pointer moving without a button (mouse mode 1003);
- with `kitty_keyboard`, asks the terminal whether it speaks the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/),
waiting at most half a second for the answer, and if it does, pushes the
flags 1 (disambiguate escape codes) and 4 (report alternate keys);
- hides the cursor;
- in inline mode, asks the terminal for the cursor position (`ESC [ 6 n`,
at most a second), places the region on the cursor's line or the line
below it, scrolls the terminal up when the region does not fit below,
and erases the region's rows.

["close"](#close) undoes all of it in reverse: mouse motion reporting off, the
kitty flags popped, the cursor placed below the inline region, and
`tb_shutdown`.

# CONSTRUCTOR

## new

```perl
my $terminal = Term::Fabulous::Terminal::Termbox->new;
my $terminal = Term::Fabulous::Terminal::Termbox->new( input => $in, output => $out );
```

Without parameters, the session uses the controlling terminal
(`/dev/tty`). With `input` and `output`, two open file handles, it
reads the terminal's input from the one and writes to the other
(`tb_init_rwfd` and `tf_init_inline_rwfd`), for example both the slave
side of a pseudo terminal; the terminal's size is read from `output`.
They go together: only one of them dies, and so does a handle that is
not open. Nothing is opened until ["open"](#open).

# METHODS

The methods of [Term::Fabulous::Role::Terminal](../Role/Terminal.md). Errors die with
messages that start with `Term::Fabulous::Terminal::Termbox:`.

## open

```perl
$terminal->open( inline => undef, mouse => 1, kitty_keyboard => 1 );
```

Starts a session as described above. Unknown options die, and so does
an `inline` that is not a whole number of rows of at least 1. When
termbox2 cannot start, `open` dies with the termbox2 error, for
example `tb_init failed: No such device or address` when the process
has no controlling terminal; when the terminal reports a size of 0
columns or rows, with `the terminal reports an unusable size`; in
inline mode, when the terminal does not report its cursor position in
time, with `the terminal did not report its cursor position; inline
mode needs a terminal that answers ESC [ 6 n`. After a failure the
terminal is closed again.

## close

```perl
$terminal->close;
```

Ends the session as described above. Does nothing when no session is
open, so calling it twice is harmless.

## is\_open

1 while a session is open.

## size

```perl
my ( $columns, $rows ) = $terminal->size;
```

The terminal's size, or in inline mode its width and the rows of the
region: the `inline` rows, or fewer on a terminal that is not as high.

## apply\_resize

```perl
my ( $columns, $rows ) = $terminal->apply_resize( $width, $height );
```

Takes the size of a resize event. In inline mode it finds the region
again: it asks the terminal where the cursor is (between frames the
hidden cursor waits at the start of the region's first row, and a
terminal that rewraps its lines moves it along), erases from there down
and places the region there. Returns the new size, like ["size"](#size).

## read\_handles

Duplicates of termbox2's terminal input and resize descriptors, opened
by ["open"](#open) and closed by ["close"](#close).

## next\_event

```perl
my $event = $terminal->next_event;    # Term::Fabulous::Termbox::Event or undef
```

The next event termbox2 has read (`tb_peek_event` without waiting), or
`undef` when there is none yet: nothing buffered, only the beginning
of a key sequence, or an interrupted poll. Any other error dies with
`reading terminal input failed: ...`.

## input\_ended

1 when the terminal input descriptor reports readable but has no byte
to read (or cannot even tell, `EIO`): the terminal went away. termbox2
reports that only as "no event", again and again.

## kitty\_keyboard\_active

1 while the session uses the kitty keyboard protocol.

## cell\_target

The [Term::Fabulous::Terminal::Termbox::Cells](Termbox/Cells.md) the frames are painted
into.

# SEE ALSO

[Term::Fabulous](../../../../README.md), [Term::Fabulous::Role::Terminal](../Role/Terminal.md),
[Term::Fabulous::Terminal::Memory](Memory.md), [Term::Fabulous::Termbox](../Termbox.md).
