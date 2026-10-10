# NAME

Term::Fabulous::Commands - The commands of a program, and the keys
that run them

# SYNOPSIS

```perl
use Term::Fabulous::Commands;

my $commands = Term::Fabulous::Commands->new(
        commands => [
                { id => 'save', label => 'Save', keys => ['Ctrl+S'], run => sub { save_file() }, enabled => sub { $modified } },
                { id => 'quit', label => 'Quit', keys => ['Ctrl+Q'], run => sub { $ui->loop->stop } },
        ],
);
$commands->add( { id => 'help', label => 'Help', keys => ['F1'], run => sub { show_help() } } );

# Every key that no widget uses reaches the root, and runs its command:
$commands->listen($root);

# The same commands in a menu bar:
my $menu_bar = Term::Fabulous::Widget::MenuBar->new(
        commands => $commands,
        menus    => [ { title => 'File', items => [ 'save', '-', 'quit' ] } ],
);
```

# DESCRIPTION

A program that has more than a few keys keeps them in one place: a
table of [Term::Fabulous::Command](Command.md) objects, each with its id, its
label, its keys and its code. The table runs a command when one of its
keys is pressed, and the menus of a [Term::Fabulous::Widget::MenuBar](Widget/MenuBar.md)
or a [Term::Fabulous::Widget::Menu](Widget/Menu.md) show the same commands, with their
keys, by id.

The table makes sure that a key runs one command only: a key that two
commands claim dies when the second one is added, so a conflict shows
up when the program starts, not when the user wonders why a key does
the wrong thing.

## Where the keys come from

A key press goes to the widget that has the focus and then bubbles up
to the root (see ["Return values and bubbling" in Term::Fabulous::Manual::Events](Manual/Events.md#return-values-and-bubbling)).
["listen"](#listen) on the root runs the commands of the keys that no widget
below used: a text field keeps the letters it types, and Ctrl+S
reaches the root and saves.

A command that is disabled does not use its key: the key goes on, and
nothing happens. A program that wants to say why, for example in a
[Term::Fabulous::Widget::StatusBar](Widget/StatusBar.md), listens for the keys itself and
asks ["command\_for\_key"](#command_for_key) and ["is\_enabled" in Term::Fabulous::Command](Command.md#is_enabled).

# CONSTRUCTOR

## new

```perl
my $commands = Term::Fabulous::Commands->new( commands => [ ... ] );
```

- `commands`

    An array reference of commands, each a [Term::Fabulous::Command](Command.md) or a
    hash reference of the parameters of
    ["new" in Term::Fabulous::Command](Command.md#new). Default: `[]`. They are added as
    ["add"](#add) adds them.

Unknown parameters die.

# METHODS

## add

```perl
$commands->add(
        { id => 'find', label => 'Find...', keys => ['Ctrl+F'], run => sub { ... } },
        $command_object,
);
```

Adds commands at the end of the table. Dies when a command's id is
taken already, when one of its keys runs another command already, and
for anything that is not a command or a hash reference. A call that
dies adds none of its commands. Returns the table.

## command

```perl
my $save = $commands->command('save');
```

The command with an id. Dies for an id the table has no command of.

## commands

```perl
foreach my $command ( $commands->commands ) {
        printf "%-20s %s\n", $command->label, $command->keys_text;
}
```

Every command, in the order they were added. A list of keys for a
help screen comes from here.

## command\_for\_key

```perl
my $command = $commands->command_for_key('Ctrl+S');
```

The command a key name runs, or `undef`.

## handle\_key

```perl
return Clay::UI::Enum::Result->HANDLED if $commands->handle_key($event);
```

Runs the command of a [Term::Fabulous::Event::KeyPress](Event/KeyPress.md): the command
of its `key_name`, or else of its `main_key_name` (so the Enter and
digit keys of the number pad run the commands of the main keys).
Returns 1 when a command ran, and 0 when the key runs no command or its
command is disabled.

## listen

```perl
$commands->listen( $ui->root );
```

Adds a `KeyPress` listener to a widget that calls ["handle\_key"](#handle_key), and
stops the key from bubbling further when a command ran. Listen on the
root for keys that work everywhere, or on a part of the screen for keys
that work only while the focus is inside it. The listener keeps the
table alive as long as the widget lives, so the program need not keep
it in a variable, and it cannot be taken away again. Returns the
table.

# SEE ALSO

[Term::Fabulous::Command](Command.md), [Term::Fabulous::Widget::MenuBar](Widget/MenuBar.md),
[Term::Fabulous::Widget::Menu](Widget/Menu.md), [Term::Fabulous::Manual::Menus](Manual/Menus.md),
[Term::Fabulous::Cookbook::Menus](Cookbook/Menus.md).
