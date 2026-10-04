# NAME

Term::Fabulous::Event::Start - The terminal is open and its size is known

# SYNOPSIS

```perl
$root->on( Start => sub ($event) {
        $status->text( sprintf '%d x %d', $event->width, $event->height );
        return;
} );
```

# DESCRIPTION

[`$ui->run`](../../../../README.md#run) fires one `Start` event on the root widget after
it has opened the terminal and replaced the `width` and `height`
given to `new` with the terminal's size (in inline mode, the height is
the rows of the region; see ["INLINE MODE" in Term::Fabulous](../../../../README.md#inline-mode)), and before
the first frame is drawn. It fires from inside the running event loop, before any input
is read: `$ui->width` and `$ui->height` already hold the
terminal size, and `$ui->loop` is the running loop, so a listener
can add timers to it or stop it. Timers and other work the program
queued on the loop before `run` may run before it. Later size changes fire
`Resize` ([Term::Fabulous::Event::Resize](Resize.md)) instead; a program that
lays itself out by the terminal size usually listens to both.

The event is fired at every call of `run`. A program that drives the
UI with ["step" in Term::Fabulous](../../../../README.md#step) instead gets it from the `step` that
opens the terminal; a `run` on a terminal that `step` has opened
already does not fire it again.

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'Start'` unless given to the constructor)
and `bubble_mode` are available as well. Since the event is fired on
the root, it has no ancestors to bubble to.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Start->new( width => 120, height => 40 );
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted as well.

- `width`

    Required. The terminal width in columns.

- `height`

    Required. The terminal height in rows.

# METHODS

## width

```perl
my $columns = $event->width;
```

The terminal width in columns.

## height

```perl
my $rows = $event->height;
```

The terminal height in rows.

# SEE ALSO

[Term::Fabulous](../../../../README.md), [Term::Fabulous::Event::Resize](Resize.md),
["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Change the layout with the terminal size (Start and Resize events)" in Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md#change-the-layout-with-the-terminal-size-start-and-resize-events).
