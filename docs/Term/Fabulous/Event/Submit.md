# NAME

Term::Fabulous::Event::Submit - The user pressed Enter in a text field

# SYNOPSIS

```perl
$search_field->on( Submit => sub ($event) {
        run_search( $event->value );
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::TextField](../Widget/TextField.md) fires `Submit` on itself when
the user presses `Enter` in it, so you can act on the text without a
separate button. It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is
`Submit`; listen for it with
`$field->on( Submit => sub ($event) { ... } )`.

- It is fired on every `Enter`, also when the text did not change, when
it is empty, and when the field is `read_only`. A disabled field fires
nothing.
- [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md) does not fire `Submit`: there,
`Enter` starts a new line.
- Like every event, it bubbles to the field's ancestors as long as the
listeners on the way return `Clay::UI::Enum::Result->CONTINUE` (a
widget without `Submit` listeners passes it on). A form can therefore
handle `Enter` in any of its fields with one listener; use
`$event->target` to see which field it came from. See
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling).

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Submit->new( value => $text );
```

Needed only by widgets of your own; the text field fires its own
events.

- `value`

    Required. The text of the field, a character string.

Unknown parameters die. An event object can be fired only once.

# METHODS

## value

```perl
my $text = $event->value;
```

The text of the field when `Enter` was pressed, a character string.

## target

```perl
my $field = $event->target;
```

The text field the event was fired on, inherited from
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).

# SEE ALSO

[Term::Fabulous::Widget::TextField](../Widget/TextField.md), [Term::Fabulous::Event::Change](Change.md),
["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["A login form (centered dialog, masked password)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#a-login-form-centered-dialog-masked-password),
["Read all values of a form" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#read-all-values-of-a-form).
