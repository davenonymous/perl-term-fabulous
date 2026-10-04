# NAME

Term::Fabulous::Event::Resize - The terminal changed size

# SYNOPSIS

```perl
$root->on( Resize => sub ($event) {
        return if $event->is_pre_event;    # react once, after the new size is set
        $status->text( sprintf '%d x %d', $event->width, $event->height );
        return;
} );
```

# DESCRIPTION

[Term::Fabulous](../../../../README.md) fires a `Resize` event when the terminal window
changes size. Most programs do not need it: the layout follows the new
size automatically, because widgets sized with `grow` or `percent(...)`
are laid out again in the next frame. Listen for it when something that
is not part of the layout depends on the terminal size. In inline mode
(["INLINE MODE" in Term::Fabulous](../../../../README.md#inline-mode)) the height it reports is the rows of the
region, which changes only while the terminal has fewer rows than
`inline` asks for.

Resizes are debounced: while the user drags the window border, nothing
is fired; one tenth of a second after the last size change, the event is
fired twice for the final size, always on the root widget. No `Resize`
is fired when `run` starts and replaces the `width` and `height`
given to `new` with the terminal's size: that fires `Start`
([Term::Fabulous::Event::Start](Start.md)) instead (see
["Change the layout with the terminal size (Start and Resize events)" in Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md#change-the-layout-with-the-terminal-size-start-and-resize-events)).
The two events of a resize:

1. First with ["is\_pre\_event"](#is_pre_event) true. At this point `$ui->width` and
`$ui->height` still hold the old size.
2. Then with ["is\_post\_event"](#is_post_event) true, after `$ui->width` and
`$ui->height` have been set to the new size. The new layout is
computed and shown with the next frame, at the next tick of the 1/30
second frame timer.

A size with zero columns or zero rows is ignored and fires nothing. No
frames are drawn while a resize is pending.

The class is a subclass of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), so `target`,
`current_target`, `name` (`'Resize'` unless given to the constructor)
and `bubble_mode` are available as well. Since the event is fired on
the root, it has no ancestors to bubble to.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Resize->new( width => 120, height => 40, is_post_event => 1 );
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted as well.

- `width`

    Required. The new terminal width in columns.

- `height`

    Required. The new terminal height in rows.

- `is_post_event`

    Optional boolean. True if the new size has already been applied.
    Default: `0`.

## of

```perl
my $event = Term::Fabulous::Event::Resize->of( $termbox_event, $is_post_event );
```

Builds an event from a `Term::Fabulous::Termbox::Event` of type `TB_EVENT_RESIZE`:
`width` and `height` from its `w` and `h`. `$is_post_event` is
optional and defaults to `0`. Class method.

# METHODS

## width

```perl
my $columns = $event->width;
```

The new terminal width in columns.

## height

```perl
my $rows = $event->height;
```

The new terminal height in rows.

## is\_pre\_event

```perl
return if $event->is_pre_event;
```

True for the first of the two events, fired before the new size is
applied. Always the opposite of ["is\_post\_event"](#is_post_event).

## is\_post\_event

```perl
return unless $event->is_post_event;
```

True for the second of the two events, fired after the new size is
applied.

# SEE ALSO

[Term::Fabulous](../../../../README.md), [Term::Fabulous::Event::Start](Start.md),
[Term::Fabulous::Event::CanvasResize](CanvasResize.md), ["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events).
