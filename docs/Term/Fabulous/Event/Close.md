# NAME

Term::Fabulous::Event::Close - A dialog was closed or a toast went away

# SYNOPSIS

```perl
$dialog->on( Close => sub ($event) {
        $status->text('dialog closed');
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) fires `Close` on itself when it
closes, whether the user pressed `Escape` or the program called
`$dialog->close`. When the listeners run, the dialog is no longer
part of the widget tree, and the keyboard focus has gone back to the
widget that had it before the dialog opened, if that widget can still
take the focus.

A [Term::Fabulous::Widget::Toast](../Widget/Toast.md) fires it on itself when it goes
away: when its timeout runs out, when the user clicks its close mark,
or when the program calls `$toast->hide`.

The event has no fields of its own; `$event->target` is the
dialog or the toast. It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is
`Close`. The widget has no parent any more when it fires, so the
event does not bubble anywhere; listen on the dialog or toast itself.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Close->new;
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# SEE ALSO

[Term::Fabulous::Widget::Dialog](../Widget/Dialog.md), [Term::Fabulous::Widget::Toast](../Widget/Toast.md),
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent),
["Ask a question in a dialog (Dialog widget)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget).
