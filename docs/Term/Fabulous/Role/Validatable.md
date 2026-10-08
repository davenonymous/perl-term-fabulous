# NAME

Term::Fabulous::Role::Validatable - An input widget whose value can be checked

# SYNOPSIS

```perl
# Every input widget has these:
my $field = Term::Fabulous::Widget::TextField->new( required => 1, validator => 'email' );
my $error = $field->error;        # the message, or undef
my $fine  = $field->is_valid;     # 1 or 0
$field->validate;                 # fires ValidityChange when the message changed
```

# DESCRIPTION

The role behind the `required` and `validator` parameters of the
input widgets. [Term::Fabulous::Widget::Input](../Widget/Input.md) composes it, so every
input has them; the parameters, accessors and events are documented
there (["required" in Term::Fabulous::Widget::Input](../Widget/Input.md#required),
["validator" in Term::Fabulous::Widget::Input](../Widget/Input.md#validator),
["error" in Term::Fabulous::Widget::Input](../Widget/Input.md#error),
["is\_valid" in Term::Fabulous::Widget::Input](../Widget/Input.md#is_valid),
["validate" in Term::Fabulous::Widget::Input](../Widget/Input.md#validate)).

A widget of your own that is not an input may compose the role too. It
needs a `value` method and [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter) (for
`fire_event`). The role reads the value whenever it is asked, so the
value may change behind its back; call ["validate" in Term::Fabulous::Widget::Input](../Widget/Input.md#validate) when it does.

# SUBCLASS INTERFACE

## value\_is\_empty

```perl
method value_is_empty :override () { return $checked ? 0 : 1 }
```

Whether the value counts as not filled in, which `required` rejects
and the validator never sees. Default: the value is `undef` or the
empty string. [Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md) overrides it: an
unchecked box is empty.

## validator\_changed

```perl
method validator_changed :override () { ... }
```

Called after `validator` was written, before the value is checked
again. Default: nothing. [Term::Fabulous::Widget::TextInput](../Widget/TextInput.md) takes
the validator's suggested `accept` here.

## validator\_coerce

```perl
$self->validator_coerce($spec);
```

Keeps the coerced validator without checking the value or calling
["validator\_changed"](#validator_changed); the constructor uses it, since the value does
not exist yet when the role's parameters are read. A class whose
constructor builds the value afterwards calls ["validator\_changed"](#validator_changed)
itself when it needs the suggestion.

# SEE ALSO

[Term::Fabulous::Widget::Input](../Widget/Input.md), [Term::Fabulous::Validator](../Validator.md),
[Term::Fabulous::Event::ValidityChange](../Event/ValidityChange.md).
