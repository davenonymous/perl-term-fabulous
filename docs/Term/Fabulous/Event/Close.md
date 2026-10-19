# NAME

Term::Fabulous::Event::Close - A dialog, a toast or a popup menu went away

# SYNOPSIS

```perl
$dialog->on( Close => sub ($event) {
        $status->text('dialog closed');
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) (a Prompt, a FileDialog, a
KeyReference included) fires `Close` on itself whenever it closes: when
a button or the `answer` method answers it, when the user presses
`Escape`, or when the program calls `$dialog->close`. `Answer`
([Term::Fabulous::Event::Answer](Answer.md)) follows right after. When the
listeners run, the dialog is no longer part of the widget tree, and the
keyboard focus has gone back to the widget that had it before the dialog
opened, if that widget can still take the focus.

A [Term::Fabulous::Widget::Toast](../Widget/Toast.md) fires it on itself when it goes
away: when its timeout runs out, when the user clicks its close mark,
or when the program calls `$toast->hide`.

A [Term::Fabulous::Widget::Menu](../Widget/Menu.md) that was opened as a popup fires it on
itself when it closes: when the user chooses an item, presses `Escape`
or moves the focus elsewhere, or when the program calls
`$menu->close`.

The event has no fields of its own; `$event->target` is the
dialog, the toast or the menu. It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent)
whose name is `Close`. The widget has no parent any more when it
fires, so the event does not bubble anywhere. Listen on the dialog,
the toast or the menu itself.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Close->new;
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# SEE ALSO

[Term::Fabulous::Widget::Dialog](../Widget/Dialog.md), [Term::Fabulous::Widget::Toast](../Widget/Toast.md),
[Term::Fabulous::Widget::Menu](../Widget/Menu.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent),
["Ask a question in a dialog (Dialog widget)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget).
