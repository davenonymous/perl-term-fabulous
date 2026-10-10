# NAME

Term::Fabulous::Event::Choose - The user chose an item of a menu

# SYNOPSIS

```perl
$menu->on( Choose => sub ($event) {
        $status->message( 'Chose ' . $event->command->label );
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Menu](../Widget/Menu.md) fires `Choose` on itself when the
user chooses one of its items: with `Enter` or `Space` on the
highlighted item, or with a click on it. A disabled item cannot be
chosen and fires nothing.

The order is always the same, so a listener and the command can rely
on it: a menu that was opened as a popup closes first and gives the
focus back, then `Choose` fires, and then the command of the item
runs. A command that opens a dialog therefore finds the focus where
the user left it, and the dialog gives it back there when it closes.

The event bubbles from the menu up through its ancestors. A menu of a
[Term::Fabulous::Widget::MenuBar](../Widget/MenuBar.md) is a child of the bar, so a listener
on the bar or above it hears about every menu of the bar. A popup menu
has left the widget tree when it fires, so listen on the menu itself.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Choose`.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Choose->new( command => $command, index => 2 );
```

Both parameters are required, and unknown parameters die. The `name`
and `bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are
accepted.

# METHODS

## command

```perl
my $id = $event->command->id;
```

The [Term::Fabulous::Command](../Command.md) of the chosen item. For an item that was
given as a hash reference, the menu made the command from it, and its
id is the `id` of the hash, or else its label.

## index

The position of the item in the menu, from 0, separators counted.

# SEE ALSO

[Term::Fabulous::Widget::Menu](../Widget/Menu.md), [Term::Fabulous::Widget::MenuBar](../Widget/MenuBar.md),
[Term::Fabulous::Command](../Command.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).
