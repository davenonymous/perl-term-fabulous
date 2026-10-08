# NAME

Term::Fabulous::Event::ValidityChange - The value of an input widget became valid or invalid

# SYNOPSIS

```perl
use Clay::UI::Enum::Result;

# On one input:
$email->on( ValidityChange => sub ($event) {
        $hint->text( $event->error // ' ' );
        return Clay::UI::Enum::Result->CONTINUE;
} );

# Once for a whole form: the event bubbles up from every input inside it.
$form->on( ValidityChange => sub ($event) {
        printf "%s is now %s\n", $event->target->id, $event->is_valid ? 'fine' : $event->error;
        return;
} );

# Report the inputs that are invalid from the start, such as empty
# required fields, which have fired nothing yet:
$_->validate foreach $form->invalid_inputs;
```

# DESCRIPTION

A `ValidityChange` event tells you that the message an input widget
has about its value changed: the value became invalid, became valid,
or is invalid for another reason than before (see
["required" in Term::Fabulous::Widget::Input](../Widget/Input.md#required) and
["validator" in Term::Fabulous::Widget::Input](../Widget/Input.md#validator)). It is a
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `ValidityChange`; listen for
it with `$widget->on( ValidityChange => sub ($event) { ... } )`.

- It is fired by ["validate" in Term::Fabulous::Widget::Input](../Widget/Input.md#validate), which the
input runs after every `Change` event and whenever its `required`,
`required_message` or `validator` is written. It fires only when the
message differs from the one the input reported last: typing a second
wrong character into an e-mail field fires nothing new.
- Before its first `ValidityChange`, an input counts as having reported
a valid value. An input that is invalid from the start (an empty
required field, a field created with a wrong `value`) therefore fires
nothing until the user changes it or something calls `validate`.
Setting the value from the program fires nothing either, as with
`Change`; call `validate` to report it.
- It is fired on the input, right after the `Change` event it follows,
and bubbles to the input's ancestors in the same way (see
[Term::Fabulous::Event::Change](Change.md)).

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::ValidityChange->new( is_valid => 0, error => 'Please enter an e-mail address.' );
```

You only need the constructor when you write your own input widget;
the built-in widgets fire their own events.

- `is_valid`

    Required. 1 or 0.

- `error`

    The message, or `undef` for a valid value. Default: `undef`.

# METHODS

## is\_valid

```perl
if ( $event->is_valid ) { ... }
```

Whether the value is valid now.

## error

```perl
my $message = $event->error;
```

What is wrong with the value, as ["error" in Term::Fabulous::Widget::Input](../Widget/Input.md#error)
reports it, or `undef` when it is valid.

## target

```perl
my $input = $event->target;
```

The input the event was fired on, inherited from
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).

# SEE ALSO

[Term::Fabulous::Widget::Input](../Widget/Input.md), [Term::Fabulous::Validator](../Validator.md),
[Term::Fabulous::Event::Change](Change.md),
["Checking input" in Term::Fabulous::Manual::Forms](../Manual/Forms.md#checking-input),
["Check the values of a form (required, validator)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#check-the-values-of-a-form-required-validator).
