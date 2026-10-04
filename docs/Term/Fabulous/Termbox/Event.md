# NAME

Term::Fabulous::Termbox::Event - One termbox2 input event

# SYNOPSIS

```perl
use Term::Fabulous::Termbox qw(tb_peek_event TB_OK TB_EVENT_KEY TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT);
use Term::Fabulous::Termbox::Event;

my $event = Term::Fabulous::Termbox::Event->new;
if ( tb_peek_event( $event, 0 ) == TB_OK && $event->type == TB_EVENT_KEY ) {
        printf "key %d char %d modifiers %d\n", $event->key, $event->ch, $event->mod;
}

# Tests build events by hand:
my $click = Term::Fabulous::Termbox::Event->new( type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 3, y => 1 );
```

# DESCRIPTION

The Perl side of termbox2's `struct tb_event`.
[`tb_peek_event`](../Termbox.md#tb_peek_event) and
[`tb_poll_event`](../Termbox.md#tb_poll_event) fill an instance in place;
[Term::Fabulous::Event::KeyPress](../Event/KeyPress.md), [Term::Fabulous::Event::Mouse](../Event/Mouse.md) and
[Term::Fabulous::Event::Resize](../Event/Resize.md) build their events from one.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Termbox::Event->new(%fields);
```

Every field is optional and defaults to 0. Unknown names die.

# FIELDS

Each field has a combined accessor: without an argument it returns the
value, with one it sets it.

- `type`

    One of `TB_EVENT_KEY`, `TB_EVENT_RESIZE`, `TB_EVENT_MOUSE`.

- `mod`

    Bitwise `TB_MOD_*` modifiers, and the `TF_MOD_SUPER`,
    `TF_MOD_HYPER` and `TF_MOD_META` of the kitty keyboard protocol.

- `key`

    A `TB_KEY_*` or `TF_KEY_*` code, 0 for a printable character.

- `ch`

    The Unicode codepoint of a printable character, 0 for a special key.
    With the kitty keyboard protocol it also holds the key of a Ctrl
    combination the legacy encoding cannot carry, such as Ctrl+Enter or
    Ctrl+I (see ["tf\_install\_input\_parser" in Term::Fabulous::Termbox](../Termbox.md#tf_install_input_parser)). For
    a `TB_KEY_MOUSE_RELEASE`, it names the released button
    (`TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE` or `TB_KEY_MOUSE_RIGHT`),
    or is 0 when the terminal did not say.

- `w`, `h`

    The new terminal size of a resize event.

- `x`, `y`

    The cell of a mouse event.

# SEE ALSO

[Term::Fabulous::Termbox](../Termbox.md), [Term::Fabulous](../../../../README.md).

# AUTHOR

davenonymous <perl@davenonymous.com>

# COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
