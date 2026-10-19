# NAME

Term::Fabulous::Event::Answer - The user answered a dialog

# SYNOPSIS

```perl
$prompt->on( Answer => sub ($event) {
        return if $event->button ne 'save';
        save_as( $event->value('name') );
        return;
} );
```

# DESCRIPTION

Every [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) fires `Answer` on itself once
each time it closes, right after `Close`: when the user presses one of
its buttons or `Escape`, or when the program calls `answer` or
`close`. When the listeners run, the dialog is already closed and the
keyboard focus is back on the widget that had it before the dialog
opened, so a listener can open the next dialog right away.

The event says which button answered the dialog and what values it
carries. One rule holds for every dialog: an answer carries the
dialog's `values` (see ["values" in Term::Fabulous::Widget::Dialog](../Widget/Dialog.md#values)) and
what the answer adds to them, and a dialog closed without a button (by
`Escape` or by `close`) answers with the button `cancel`, carries
its `values` as well and is _dismissed_. So a program that names its
cancel button `cancel` handles both in the same way, and one that
needs to tell them apart asks ["dismissed"](#dismissed).

- A [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md) reports the values of its fields,
by field name, in every answer, also when it is dismissed.
- A [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md) has no values of its own. Its
choice answers `open`, `save` or `choose` after its mode with
`{ path => $path }`, the absolute path chosen, in bytes as the
file system has it (see
["File names" in Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md#file-names)). Its `Cancel`
button answers `cancel`, and `Escape` or `close` answer `cancel`
as dismissed, both with empty values:

    ```perl
    $dialog->on( Answer => sub ($event) {
            open_file( $event->value('path') ) if $event->button eq 'open';
            return;
    } );
    ```

- A [Term::Fabulous::Widget::KeyReference](../Widget/KeyReference.md) answers `close` from its
Close button.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Answer`. The dialog
has no parent any more when it fires, so the event does not bubble
anywhere: listen on the dialog itself.

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

The id of the button that answered the dialog, or `cancel` when the
dialog was dismissed. For a file dialog: `open`, `save`, `choose` or
`cancel`.

## values

```perl
my %values = %{ $event->values };
```

The values the answer carries, as a new hash reference: a prompt's
fields by field name (an empty hash without fields), a file dialog's
`{ path => $path }` for a choice and an empty hash when it was
cancelled, an empty hash for a plain dialog.

## value

```perl
my $name = $event->value('name');
```

One of the values, or `undef` for a name the answer has no value of.

## dismissed

```perl
return if $event->dismissed;
```

1 when the dialog was closed without a button, by `Escape` or by the
program calling `close`, and 0 when a button (or `answer`) answered
it.

# SEE ALSO

["Answers" in Term::Fabulous::Widget::Dialog](../Widget/Dialog.md#answers), [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md), [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md),
[Term::Fabulous::Widget::KeyReference](../Widget/KeyReference.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent),
["A dialog of your own" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#a-dialog-of-your-own),
["Ask for a number and check it (Prompt, validator)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-for-a-number-and-check-it-prompt-validator).
