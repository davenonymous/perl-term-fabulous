# NAME

Term::Fabulous::Command - Something the user can do, with a name and
keys

# SYNOPSIS

```perl
use Term::Fabulous::Command;

my $save = Term::Fabulous::Command->new(
        id      => 'save',
        label   => 'Save',
        keys    => ['Ctrl+S'],
        run     => sub { save_file() },
        enabled => sub { $document->is_modified },
);

my $wrap = Term::Fabulous::Command->new(
        id      => 'wrap',
        label   => 'Wrap long lines',
        keys    => ['Alt+Z'],
        run     => sub { $wrap_lines = !$wrap_lines },
        checked => sub { $wrap_lines },
);

$save->run if $save->is_enabled;
```

# DESCRIPTION

A command is one thing a program lets the user do: save a file, quit,
switch a setting on or off. It has an id for the program, a label for
the user, the keys that run it, and the code that does it.

Commands are usually kept in a [Term::Fabulous::Commands](Commands.md) table, which
runs them when their keys are pressed, and shown in a
[Term::Fabulous::Widget::MenuBar](Widget/MenuBar.md) or a [Term::Fabulous::Widget::Menu](Widget/Menu.md),
which run them when they are chosen. Because the menus and the keys use
the same command, they always agree: the menu shows the keys that work,
and a command that cannot run now is disabled in the menu and does
nothing when its key is pressed.

A command may be _enabled_ only at times, for example Save only while
there are unsaved changes, and it may be a _toggle_, a setting that is
on or off, which a menu shows with a check mark. Both are decided by
code that the command calls whenever it needs to know, so the command
always follows the program's state without being told.

See [Term::Fabulous::Manual::Menus](Manual/Menus.md) for how commands, keys and menus
work together.

# CONSTRUCTOR

## new

```perl
my $command = Term::Fabulous::Command->new(%parameters);
```

Unknown parameters die.

- `id`

    A non-empty string that names the command. Required. Menus and the
    [Term::Fabulous::Commands](Commands.md) table refer to the command by it.

- `label`

    What a menu shows, a string. Required. End it with three dots
    (`Save as...`) when the command asks for more before it does
    anything, as is the custom in menus.

- `keys`

    An array reference of key names, as
    ["key\_name" in Term::Fabulous::Event::KeyPress](Event/KeyPress.md#key_name) gives them: `'Ctrl+S'`,
    `'F5'`, `'Alt+Left'`. Default: `[]`, no keys. A name that is not a
    key dies, naming the command. A menu shows the keys after the label.

- `run`

    A code reference that does what the command does. It is called without
    arguments. Default: `undef`, nothing. A command without `run` is
    still useful in a menu whose `Choose` event the program handles
    itself.

- `enabled`

    A code reference that returns whether the command can run now.
    Default: `undef`, always.

- `checked`

    A code reference that returns whether the setting the command switches
    is on. Default: `undef`, the command is no toggle. With it, a menu
    draws a check mark in front of the label while the code returns true.
    Running the command does not switch anything by itself: `run` does
    that.

# METHODS

## id, label

```perl
say $command->label;
```

The parameters of the same names.

## plain\_label

```perl
say $command->plain_label;    # "Save as" for the label "Save as..."
```

The label without a trailing `...`, for the places that name the
command outside a menu (a key reference, a status message). Menus show
["label"](#label), whose `...` says that the command opens a dialog.

## keys

```perl
my @keys = $command->keys;
```

The key names, in the order given.

## keys\_text

```perl
say $command->keys_text;    # "Ctrl+S, F2"
```

The key names as a menu shows them, joined with commas, or `''`
without keys.

## is\_enabled

```perl
if ( $command->is_enabled ) { ... }
```

1 when the command can run now, 0 when not. Asks `enabled` each time.

## is\_toggle

1 when the command has a `checked` code reference, 0 when not.

## is\_checked

1 while the command's setting is on, 0 while it is off or the command
is no toggle. Asks `checked` each time.

## run

```perl
$command->run or $status->message('Nothing to save.');
```

Runs the command when it is enabled, and returns 1. Returns 0 and does
nothing when it is disabled.

# SEE ALSO

[Term::Fabulous::Commands](Commands.md), [Term::Fabulous::Widget::Menu](Widget/Menu.md),
[Term::Fabulous::Widget::MenuBar](Widget/MenuBar.md), [Term::Fabulous::Manual::Menus](Manual/Menus.md).
