# NAME

Term::Fabulous::Terminal::Memory - A terminal in memory, for tests

# SYNOPSIS

```perl
use Test2::V0;
use Term::Fabulous;
use Term::Fabulous::Terminal::Memory;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::TextField;

my $field = Term::Fabulous::Widget::TextField->new( preferred_columns => 10 );
my $root  = Term::Fabulous::Widget::Box->new;
$root->add_child($field);

my $terminal = Term::Fabulous::Terminal::Memory->new( width => 30, height => 2 );
my $ui       = Term::Fabulous->new( root => $root, width => 30, height => 2, terminal => $terminal );

$ui->step;                                        # opens the terminal, fires Start, draws a frame
$terminal->press_key('Tab')->type_text('Ada');    # focus the field and type
$ui->step;                                        # handles the input as run would, draws

is $field->value, 'Ada', 'the field holds the text';
is [ $terminal->lines ], [ 'Ada       ', '' ], 'what the screen shows';
done_testing;
```

The text field has a background color, so its ten columns are kept as
spaces in ["lines"](#lines). A longer test, with clicks, is in
["Test a widget without a terminal" in Term::Fabulous::Cookbook::Output](../Cookbook/Output.md#test-a-widget-without-a-terminal).

# DESCRIPTION

A terminal (see [Term::Fabulous::Role::Terminal](../Role/Terminal.md)) that exists only in
memory. Give it to ["new" in Term::Fabulous](../../../../README.md#new) as `terminal`, queue input
with the methods below, let the application handle it with
["step" in Term::Fabulous](../../../../README.md#step) (or ["run" in Term::Fabulous](../../../../README.md#run)), and read back the
screen with ["lines"](#lines) and ["cell"](#cell).

Input goes through everything that real input goes through: the
focused widget gets the keys, Tab and Shift+Tab move the focus, a click
is hit-tested against the last frame, focuses what it hits and
presses and releases it (`OnPress`, `OnRelease`), the wheel scrolls,
and resizes fire `Resize`. The events are those termbox2 reports for a
real terminal, so key names, mouse buttons and modifiers come out as
they do there.

The screen is a [Term::Fabulous::Render::Target::Grid](../Render/Target/Grid.md)
(["cell\_target"](#cell_target)): each frame paints into it as into the terminal. It
starts empty, and it keeps the last frame after the session was closed,
so a test can look at what ["run" in Term::Fabulous](../../../../README.md#run) left on the screen.

The terminal also records what the application switched on, for the
open session: ["mouse\_enabled"](#mouse_enabled), ["inline\_rows"](#inline_rows) and
["kitty\_keyboard\_active"](#kitty_keyboard_active).

# CONSTRUCTOR

## new

```perl
my $terminal = Term::Fabulous::Terminal::Memory->new( width => 80, height => 24 );
my $terminal = Term::Fabulous::Terminal::Memory->new( width => 80, height => 24, kitty_keyboard => 1 );
my $terminal = Term::Fabulous::Terminal::Memory->new( width => 80, height => 24, sixel_cell_size => [ 10, 20 ] );
```

`width` and `height` are the size of the screen, whole numbers of at
least 1; required. `kitty_keyboard` says whether the terminal speaks
the kitty keyboard protocol, so that an application that asks for it
gets it; default 0. `sixel_cell_size`, `[width, height]` in pixels,
makes it a terminal that shows sixel graphics with cells of that size:
the pictures of [Term::Fabulous::Widget::Sixel](../Widget/Sixel.md) are recorded, and
["sixels" in Term::Fabulous::Render::Target::Grid](../Render/Target/Grid.md#sixels) on ["cell\_target"](#cell_target)
returns those of the last frame. Without it, the default, the terminal
shows no sixel graphics. Unknown parameters die.

# INPUT

Input is queued until the application reads it:
[`$ui->step`](../../../../README.md#step) reads all of it, and
[`$ui->run`](../../../../README.md#run) watches `read_handles`
(see ["read\_handles" in Term::Fabulous::Role::Terminal](../Role/Terminal.md#read_handles)), a pipe that is
readable while input waits. Every method returns the
terminal, so calls can be chained. After ["end\_input"](#end_input), queuing more
input dies.

## type\_text

```perl
$terminal->type_text('hello');
```

One key event per character, as typing the text would send.

## press\_key

```perl
$terminal->press_key('Enter');
$terminal->press_key('Ctrl+Shift+Left');
$terminal->press_key('BackTab');    # Shift+Tab
$terminal->press_key('Ctrl+C');
```

One key, by the name ["key\_name" in Term::Fabulous::Event::KeyPress](../Event/KeyPress.md#key_name) gives
it; see ["KEY NAMES" in Term::Fabulous::Event::KeyPress](../Event/KeyPress.md#key-names). A name that
`key_name` never returns dies (see
["fields\_for\_name" in Term::Fabulous::Event::KeyPress](../Event/KeyPress.md#fields_for_name)).

## click

```perl
$terminal->click( $x, $y );
```

A press and a release of the left mouse button on the cell `($x, $y)`,
counted from 0 at the top-left of the screen.

## mouse

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_WHEEL_DOWN TF_KEY_MOUSE_MOVE TB_MOD_MOTION);

$terminal->mouse( key => TB_KEY_MOUSE_WHEEL_DOWN, x => 3, y => 1 );
$terminal->mouse( key => TF_KEY_MOUSE_MOVE, mod => TB_MOD_MOTION, x => 5, y => 2 );
```

Any other mouse event, with the fields of a
[Term::Fabulous::Termbox::Event](../Termbox/Event.md) (`key`, `x`, `y`, `mod`, `ch`);
see [Term::Fabulous::Event::Mouse](../Event/Mouse.md) for what they mean. Mouse events are
dropped, as a real terminal would not send them, while the session does
not report the mouse (["mouse\_enabled"](#mouse_enabled)).

## resize

```perl
$terminal->resize( 100, 30 );
```

The terminal changes its size. The application applies it when it reads
the event: ["step" in Term::Fabulous](../../../../README.md#step) at once, ["run" in Term::Fabulous](../../../../README.md#run) after
its debounce interval. Sizes that are not whole numbers of at least 1
die.

## push\_event

```perl
use Term::Fabulous::Termbox qw(TB_EVENT_KEY);

$terminal->push_event( type => TB_EVENT_KEY, key => 0, ch => ord 'a', mod => 0 );
```

Any event, with the fields of a [Term::Fabulous::Termbox::Event](../Termbox/Event.md). The
`type` must be `TB_EVENT_KEY`, `TB_EVENT_MOUSE` or
`TB_EVENT_RESIZE`. Unknown fields die.

## end\_input

```perl
$terminal->end_input;
```

The input ends, as when the real terminal goes away: once the queued
events are read, `input_ended` is 1, and ["run" in Term::Fabulous](../../../../README.md#run) and
["step" in Term::Fabulous](../../../../README.md#step) die with `Term::Fabulous: the terminal was
closed`.

# OUTPUT

## lines

```perl
my @lines = $terminal->lines;
my @lines = $terminal->lines( colors => 1 );
```

The screen as one character string per row: the rows of the layout
(the screen's height, or the rows of an inline region), as wide as the
screen, with the spaces at the end of a row left out unless they have a
background color. With `colors` true, the rows carry ANSI color
sequences as ["row\_text" in Term::Fabulous::Render::Target::Grid](../Render/Target/Grid.md#row_text) describes;
default 0.

## cell

```perl
my ( $glyph, $fg, $bg ) = @{ $terminal->cell( $x, $y ) // [] };
```

The cell at `($x, $y)` as ["cell" in Term::Fabulous::Render::Target::Grid](../Render/Target/Grid.md#cell)
describes it, or `undef` when the last frame painted nothing there.

## cell\_target

The [Term::Fabulous::Render::Target::Grid](../Render/Target/Grid.md) the frames are painted
into.

# STATE

## width, height

The size of the screen: the constructor's, or the last size a resize
event applied.

## kitty\_keyboard

The `kitty_keyboard` constructor parameter.

## is\_open

1 while a session is open.

## session\_count

How many sessions were opened so far.

## mouse\_enabled

1 while the open session reports the mouse.

## inline\_rows

The rows of the inline region of the open session, or `undef` in
full-screen mode and when no session is open.

## kitty\_keyboard\_active

1 while the open session uses the kitty keyboard protocol: the
application asked for it and the terminal speaks it
(`kitty_keyboard`).

# TERMINAL METHODS

The methods of [Term::Fabulous::Role::Terminal](../Role/Terminal.md), called by
[Term::Fabulous](../../../../README.md): `open` (dies when a session is open already, and on
unknown options), `close`, `size`, `apply_resize`, `read_handles`,
`next_event` and `input_ended`. An inline region starts at the first
row of the screen.

# SEE ALSO

["step" in Term::Fabulous](../../../../README.md#step), ["TESTING" in Term::Fabulous::Manual::Programs](../Manual/Programs.md#testing),
[Term::Fabulous::Role::Terminal](../Role/Terminal.md), [Term::Fabulous::Terminal::Termbox](Termbox.md).
