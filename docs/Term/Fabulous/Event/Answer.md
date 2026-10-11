# NAME

Term::Fabulous::Event::Answer - The user answered a prompt or a file dialog

# SYNOPSIS

```perl
$prompt->on( Answer => sub ($event) {
        return if $event->button ne 'save';
        save_as( $event->value('name') );
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md) fires `Answer` on itself once each
time it is answered: when the user presses one of its buttons, when the
user presses `Escape`, or when the program calls `answer` or
`close`. When the listeners run, the prompt is already closed and the
keyboard focus is back on the widget that had it before the prompt
opened, so a listener can open the next prompt right away.

The event says which button answered the prompt and what its fields
held at that moment. A prompt closed without a button (by `Escape` or
by `close`) answers with the button `cancel` and is _dismissed_. So
a program that names its cancel button `cancel` handles both in the
same way, and one that needs to tell them apart asks ["dismissed"](#dismissed).

A [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md) fires the same event, once each
time it is opened, when the user chose a file or a folder or cancelled.
Its button is `open`, `save` or `choose` after its mode, and its
values are `{ path => $path }`, the absolute path chosen, in
bytes as the file system has it (see
["File names" in Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md#file-names)). Its `Cancel`
button answers `cancel`, and `Escape` or `close` answer `cancel`
as dismissed; a cancelled file dialog's values are empty:

```perl
$dialog->on( Answer => sub ($event) {
        open_file( $event->value('path') ) if $event->button eq 'open';
        return;
} );
```

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Answer`. The prompt
or the file dialog has no parent any more when it fires, so the event
does not bubble anywhere: listen on the prompt or the dialog itself.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Answer->new(
        button    => 'save',
        values    => { name => 'notes.txt' },
        dismissed => 0,
);
```

`button` is required, and the others are optional. Unknown parameters
die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# METHODS

## button

```perl
if ( $event->button eq 'delete' ) { ... }
```

The id of the button that answered the prompt, or `cancel` when the
prompt was dismissed. For a file dialog: `open`, `save`, `choose` or
`cancel`.

## values

```perl
my %values = %{ $event->values };
```

The values of the prompt's fields, by field name, as a new hash
reference. A prompt without fields gives an empty hash. A file dialog
gives `{ path => $path }`, or an empty hash when it was cancelled.

## value

```perl
my $name = $event->value('name');
```

The value of one field, or `undef` for a name the prompt has no field
of.

## dismissed

```perl
return if $event->dismissed;
```

1 when the prompt or the file dialog was closed without a button, by
`Escape` or by the program calling `close`, and 0 when a button
answered it.

# SEE ALSO

[Term::Fabulous::Widget::Prompt](../Widget/Prompt.md), [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md),
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent),
["Ask for a number and check it (Prompt, validator)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-for-a-number-and-check-it-prompt-validator).
