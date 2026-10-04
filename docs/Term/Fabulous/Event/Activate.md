# NAME

Term::Fabulous::Event::Activate - The user activated a button

# SYNOPSIS

```perl
$save_button->on( Activate => sub ($event) {
        save_document();
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::Button](../Widget/Button.md) fires `Activate` on itself when
the user activates it, whichever way: a click (the left mouse button
pressed and released over the button), or `Enter` (also the keypad's
Enter) or `Space` without modifiers while the button has the keyboard
focus. `$button->activate` fires it from code. Listen for it instead of
`OnRelease` and `KeyPress` when the action is the same for the mouse
and the keyboard, which it nearly always is.

The event has no fields of its own; `$event->target` is the
button. It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `Activate`,
so it bubbles up to the ancestors like every other event.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::Activate->new;
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# SEE ALSO

[Term::Fabulous::Widget::Button](../Widget/Button.md), ["Clicks, hover and press" in Term::Fabulous::Manual::Events](../Manual/Events.md#clicks-hover-and-press),
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent),
["Add buttons for the mouse and the keyboard (Button)" in Term::Fabulous::Cookbook::KeyboardAndMouse](../Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button).
