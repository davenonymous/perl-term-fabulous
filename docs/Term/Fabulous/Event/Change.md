# NAME

Term::Fabulous::Event::Change - The user changed the value of an input widget

# SYNOPSIS

```perl
use Clay::UI::Enum::Result;

# On one input:
$name_field->on( Change => sub ($event) {
        say 'The name is now: ', $event->value;
        return Clay::UI::Enum::Result->CONTINUE;    # let ancestors see it too
} );

# Once for a whole form: Change bubbles up from every input inside it.
$form_box->on( Change => sub ($event) {
        my $input = $event->target;                 # the input that changed
        printf "%s = %s\n", $input->id, $event->value // 'nothing';
        return;
} );
```

# DESCRIPTION

A `Change` event tells you that the user changed the value of an input
widget: by typing into a [Term::Fabulous::Widget::TextField](../Widget/TextField.md) or
[Term::Fabulous::Widget::TextArea](../Widget/TextArea.md), toggling a
[Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md), selecting a radio button of a
[Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md), choosing an option of a
[Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md), moving a
[Term::Fabulous::Widget::Slider](../Widget/Slider.md), choosing the stars of a
[Term::Fabulous::Widget::StarRating](../Widget/StarRating.md) or a segment of a
[Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md).

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Change`; listen for
it with `$widget->on( Change => sub ($event) { ... } )`.

- `Change` is fired only for changes the user makes with the keyboard
or the mouse, and for the methods that act "as the user does"
(`$checkbox->toggle`, `$group->choose($button)`,
`$dropdown->choose($index)`). Setting a value from your program
(`$field->value('x')`, `$checkbox->checked(1)`, ...) never
fires it.
- It is fired on the input whose value changed (for radio buttons: on the
radio group). `$event->target` is that widget.
- It bubbles to the ancestors of that widget, so a container can listen
once for all the inputs inside it. Bubbling continues past a widget only
if that widget has no `Change` listeners, or if every one of its
`Change` listeners returned `Clay::UI::Enum::Result->CONTINUE`. A
listener that returns anything else, including a plain `return;` or the
value of its last statement, stops the event at that widget. See
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling).

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Change->new( value => $new_value );
```

You only need the constructor when you write your own input widget; the
built-in widgets fire their own events (see
["fire\_change" in Term::Fabulous::Widget::Input](../Widget/Input.md#fire_change)).

- `value`

    Required. The new value, in the form the widget's `value` reader
    returns it. May be `undef`.

Unknown parameters die. Like every [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent), an event
object can be fired only once.

# METHODS

## value

```perl
my $new_value = $event->value;
```

The new value of the input, in the form its `value` reader returns it:

- [Term::Fabulous::Widget::TextField](../Widget/TextField.md) and
[Term::Fabulous::Widget::TextArea](../Widget/TextArea.md): the whole text, a character string
(lines joined with `"\n"` in a text area).
- [Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md): `1` (checked) or `0`
(unchecked).
- [Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md): the `value` of the selected
[Term::Fabulous::Widget::RadioButton](../Widget/RadioButton.md).
- [Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md): the `value` of the chosen option.
- [Term::Fabulous::Widget::Slider](../Widget/Slider.md): the new number.
- [Term::Fabulous::Widget::StarRating](../Widget/StarRating.md): the new number of stars.
- [Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md): the `value` of the
selected option.

## target

```perl
my $input = $event->target;
```

The widget the event was fired on, inherited from
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent). It stays the same while the event bubbles;
`$event->current_target` is the widget whose listeners run right
now.

# SEE ALSO

[Term::Fabulous::Widget::Input](../Widget/Input.md), [Term::Fabulous::Event::Submit](Submit.md),
["FORMS AND INPUT WIDGETS" in Term::Fabulous::Manual::Forms](../Manual/Forms.md#forms-and-input-widgets),
["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events),
["Read all values of a form" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#read-all-values-of-a-form),
["Choose from options in Perl (Dropdown, RadioGroup, Slider)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#choose-from-options-in-perl-dropdown-radiogroup-slider).
