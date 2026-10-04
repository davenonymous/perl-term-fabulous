# NAME

Term::Fabulous::Role::Terminal - What Term::Fabulous needs from a
terminal

# SYNOPSIS

```perl
use Object::Pad 0.825;
use Term::Fabulous::Role::Terminal;

class My::Terminal :does(Term::Fabulous::Role::Terminal) {
        method open (%options)           { ... }
        method close ()                  { ... }
        method is_open ()                { ... }
        method size ()                   { ... }    # ( $columns, $rows )
        method apply_resize ( $w, $h )   { ... }    # ( $columns, $rows )
        method read_handles ()           { ... }
        method next_event ()             { ... }    # a Term::Fabulous::Termbox::Event or undef
        method input_ended ()            { ... }
        method kitty_keyboard_active ()  { ... }
        method cell_target ()            { ... }
}

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24, terminal => My::Terminal->new );
```

# DESCRIPTION

Most programs never use this module directly. [Term::Fabulous](../../../../README.md) talks
to the terminal only through an object that composes this role, its
_terminal_. Two terminals come with the distribution:

- [Term::Fabulous::Terminal::Termbox](../Terminal/Termbox.md)

    The real terminal, through termbox2. The default.

- [Term::Fabulous::Terminal::Memory](../Terminal/Memory.md)

    A terminal in memory, for tests: the test queues keys, clicks and
    resizes, drives the application with ["step" in Term::Fabulous](../../../../README.md#step) and reads
    back what the screen shows.

Term::Fabulous keeps everything that is not about the terminal itself:
the [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync) loop, its timers and signals, the routing of keys and
the mouse to the widgets, focus, wheel scrolling and frame pacing. A
terminal only opens and closes the session, reports input and receives
the painted cells.

# REQUIRED METHODS

A class composing the role provides all of the following. Errors are
reported by dying with a message that starts with the class name.

## open

```perl
$terminal->open( inline => undef, mouse => 1, kitty_keyboard => 1 );
```

Starts a session. `inline` is `undef` for the full screen, or the
number of rows of a region below the shell's output (see
["INLINE MODE" in Term::Fabulous](../../../../README.md#inline-mode)). `mouse` says whether the terminal
reports the mouse, including motion with no button held.
`kitty_keyboard` says whether to ask the terminal for the kitty
keyboard protocol, and to switch it on if the terminal speaks it.
Term::Fabulous always passes all three. Dies when the session cannot
start; the terminal is then left as it was. Dies when it is open
already.

## close

```perl
$terminal->close;
```

Ends the session and gives the terminal back as it was: the modes
["open"](#open) switched on are off again, an inline region's last frame stays
on the screen with the cursor below it. Does nothing when no session is
open.

## is\_open

1 between ["open"](#open) and ["close"](#close), otherwise 0.

## size

```perl
my ( $columns, $rows ) = $terminal->size;
```

The size of the layout, in cells, while the session is open: the
terminal's size, or in inline mode its width and the rows of the
region. Both are at least 1.

## apply\_resize

```perl
my ( $columns, $rows ) = $terminal->apply_resize( $width, $height );
```

Called with the size a resize event reported, once Term::Fabulous
applies it. Returns the new size of the layout, like ["size"](#size); in
inline mode the terminal finds its region again first.

## read\_handles

```perl
my @handles = $terminal->read_handles;
```

File handles that become readable when input waits, while the session
is open. Term::Fabulous watches them with [IO::Async](https://metacpan.org/pod/IO%3A%3AAsync) during
["run" in Term::Fabulous](../../../../README.md#run) and calls ["next\_event"](#next_event) when one is readable.
Term::Fabulous never reads from them and never closes them, and it
switches them back to blocking mode after IO::Async has made them
non-blocking. Handles the terminal owns must stay open until ["close"](#close).

## next\_event

```perl
while ( defined( my $event = $terminal->next_event ) ) { ... }
```

Returns the next input event without waiting, as a
[Term::Fabulous::Termbox::Event](../Termbox/Event.md) of the type `TB_EVENT_KEY`,
`TB_EVENT_MOUSE` or `TB_EVENT_RESIZE`, or `undef` when none waits.
Dies when reading the input fails.

## input\_ended

1 when the input has ended for good (the terminal went away), so that
no event will ever come again; otherwise 0. Term::Fabulous asks after
reading the events of a readable handle.

## kitty\_keyboard\_active

1 while the session uses the kitty keyboard protocol, otherwise 0.

## cell\_target

```perl
my $target = $terminal->cell_target;
```

The object [Term::Fabulous::Render](../Render.md) paints into: a cell target, see
["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target). It is the same object for the
lifetime of the terminal.

# SEE ALSO

[Term::Fabulous](../../../../README.md), [Term::Fabulous::Terminal::Termbox](../Terminal/Termbox.md),
[Term::Fabulous::Terminal::Memory](../Terminal/Memory.md), ["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target).
