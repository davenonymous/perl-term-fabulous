# NAME

Term::Fabulous::Widget::Button - A box that can be clicked, focused and
activated

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Enum::BorderStyle;
use Clay::XS qw(sizing_fit);

my $save = Term::Fabulous::Widget::Button->new(
        id               => 'save',
        background_color => [ 40, 60, 90, 255 ],
        border_width     => 1,
        border_color     => [ 90, 110, 140, 255 ],
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
        layout           => {
                sizing  => { width => sizing_fit(), height => sizing_fit() },
                padding => { left => 1, right => 1 },
        },
);
$save->add_child( Term::Fabulous::Widget::Text->new( text => 'Save', text_color => [ 255, 255, 255, 255 ] ) );

# A click, or Enter or Space while the button has the focus.
$save->on( Activate => sub ($event) { save_document(); return } );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-button.svg" alt="Save, Cancel, Delete and Archive buttons: Save focused with a blue border, Archive disabled and drawn in gray, and the line Save was pressed"></p>
</div>

The program is `examples/widgets/button.pl`.

# DESCRIPTION

A Button is a [Term::Fabulous::Widget::Box](Box.md) that can take the keyboard
focus, notices when the mouse button is pressed and released over it,
and tracks whether the mouse pointer is over it. Put a
[Term::Fabulous::Widget::Text](Text.md) (or anything else) inside it as its
label.

A Button fires one event for everything that counts as pressing it:
`Activate` ([Term::Fabulous::Event::Activate](../Event/Activate.md)), for a click (the left
mouse button pressed and released over the Button) and for `Enter` or
`Space` while it has the focus. The lower-level events are still
there: `OnPress` and `OnRelease` for the mouse, `KeyPress` for
every key.

A Button shows its state by itself:

- while it is pressed (the left mouse button held down over it),
it is drawn in reverse video: the foreground and background colors of
every cell it paints, label included, are swapped. `pressed_background_color`
replaces that with a background color, or switches it off;
- while it has the focus, its border is drawn in
`focus_border_color`, the blue the input widgets use for their accent.
A Button without a visible border shows nothing: give it a border
with both `border_width => 1` and a `border_style` (a border
without a style is drawn as spaces, which show no color), or change its
background in an `OnFocus` listener;
- hovering changes nothing by default. `is_hovered` and the
`OnHoverStart` and `OnHoverStopped` events follow the pointer, so a
hover look is one listener away;
- while it is disabled (["disabled"](#disabled)), its border and the
[Term::Fabulous::Widget::Text](Text.md) widgets inside it are drawn in
`disabled_color`, the gray a disabled input draws its text in, and it
is never drawn focused or pressed.

Under [Term::Fabulous](../../../../README.md), Tab and Shift+Tab move the focus to and from
Buttons, and pressing the left mouse button on a cell the Button paints
(its background or its border) focuses it; see ["MOUSE"](#mouse).

# CONSTRUCTOR

## new

```perl
my $button = Term::Fabulous::Widget::Button->new(%parameters);
```

All parameters are optional; unknown parameters die. A Button takes
every parameter of [Term::Fabulous::Widget::Box](Box.md) (`id`, `layout`,
`background_color`, `border_width`, `border_color`, `border_style`,
...; see ["new" in Term::Fabulous::Widget](../Widget.md#new)) plus:

- `can_focus`

    A boolean, stored as 1 or 0. Default: 1. With 0 the Button is skipped by Tab and
    Shift+Tab, a click does not focus it, and
    `$ui->interaction->set_focused_widget($button)` dies. Mouse
    clicks still fire `OnPress`, `OnRelease` and `Activate`.

- `disabled`

    A boolean, stored as 1 or 0. Default: 0. A disabled Button ignores
    clicks, `Enter` and `Space` (no `OnPress`, `OnRelease` or
    `Activate`), cannot take the focus and is drawn disabled; see
    ["disabled"](#disabled).

- `disabled_color`

    The color of the border and of the text of a disabled Button, in any
    format [Term::Fabulous::Color](../Color.md) accepts. Default: the theme's
    `button.border.color` in the `disabled` state (the text takes
    `button.text` in that state), `[ 108, 112, 120, 255 ]` in the
    built-in dark theme. See ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes).

- `focus_border_color`

    The color of the border while the Button has the focus, in any format
    [Term::Fabulous::Color](../Color.md) accepts, or `undef` for no focus look.
    Default: the theme's `button.border.color` in the `focused` state,
    the accent `[ 97, 175, 239, 255 ]` in the built-in dark theme. It
    only shows on sides with a positive `border_width` and a
    `border_style` other than `Blank`.

- `pressed_background_color`

    What the Button looks like while it is pressed: the string `reverse`
    draws it in reverse video, a color in any format
    [Term::Fabulous::Color](../Color.md) accepts replaces the background with that
    color, and `undef` leaves the Button unchanged while pressed.
    Default: the theme's `button.background` in the `pressed` state,
    `reverse` in the built-in themes.

    The background, the border color and the border style of the Button
    itself come from the theme's `button` family when they are not
    given (see ["new" in Term::Fabulous::Widget](../Widget.md#new)); so does the color of the
    Text widgets inside it that have no `text_color`. The three looks
    above return to the theme with ["reset\_look" in Term::Fabulous::Widget](../Widget.md#reset_look).

# METHODS

A Button has all methods of [Term::Fabulous::Widget](../Widget.md) plus these:

## activate

```perl
$button->activate;
```

Fires `Activate` on the Button, as a click or `Enter` would, and
returns what `fire_event` returns. Use it to trigger a button from
code, for example from an application shortcut. It fires also while the
Button is disabled: only the user's clicks and keys are ignored then.

## focus\_border\_color

```perl
$button->focus_border_color('#ffffff');
$button->focus_border_color(undef);
```

Accessor for the constructor parameter of the same name. Without an
argument it returns the color in use, the given one or the theme's,
as `[r, g, b, a]` (or `undef` for no focus look); with an argument
it sets the value and returns the stored form. An invalid color dies.

## pressed\_background\_color

```perl
$button->pressed_background_color('reverse');
$button->pressed_background_color( [ 60, 90, 160, 255 ] );
$button->pressed_background_color(undef);
```

Accessor for the constructor parameter of the same name. Returns the
look in use, the given one or the theme's: the string `reverse`, a
`[r, g, b, a]`, or `undef`.

## reverse\_video

```perl
my $swapped = $button->reverse_video;
```

1 while the Button is pressed and `pressed_background_color` is
`reverse`, 0 otherwise. The renderer calls it for every widget; see
["A box that takes the focus and reacts to the mouse" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#a-box-that-takes-the-focus-and-reacts-to-the-mouse).

## disabled

```perl
$button->disabled(1);
if ( $button->is_enabled ) { ... }
```

Accessor from [Clay::UI::Role::Interaction::Disableable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3ADisableable). Returns 1 or
0; a write takes any plain boolean value and returns the new value.
Disabling a Button takes the focus away from it if it has it, and ends
a press that is in progress; `is_enabled` is the opposite. The Button
also has the derived state `disabled`.

## disabled\_color

```perl
$button->disabled_color('#555555');
```

Accessor for the constructor parameter of the same name; returns the
color in use, the given one or the theme's, as `[r, g, b, a]`. An
invalid color dies.

## child\_text\_color

```perl
my $color = $button->child_text_color($explicit_color);
```

The color a Text widget inside the Button is drawn in, given the color
the Text was given (or `undef`): the disabled color while the Button
is disabled, otherwise the given color or the theme's `button.text`
for the Button's state. [Term::Fabulous::Widget::Text](Text.md) asks its
nearest ancestor that has this method.

## can\_focus

```perl
$button->can_focus(0);
```

Accessor. Reads whether the Button can take the focus now: 1 when the
last value written (through `new`, a layout file or this accessor) was
true and the Button is enabled. A write records the value and returns
what reading returns now; turning it off takes the focus away from a
Button that has it. From [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable).

## is\_focused

```perl
if ( $button->is_focused ) { ... }
```

1 while the Button has the keyboard focus, 0 otherwise (also while it is
not part of a [Term::Fabulous](../../../../README.md)). To give it the focus, call
`$ui->interaction->set_focused_widget($button)`.

## is\_hovered

```perl
if ( $button->is_hovered ) { ... }
```

1 while the mouse pointer is over the Button, as of the last frame.

## is\_pressed

```perl
if ( $button->is_pressed ) { ... }
```

1 while the left mouse button, pressed over this Button, is held down
and the pointer is still over it.

# EVENTS

All events are delivered to listeners registered with
`$button->on( $name => sub ($event) { ... } )`; see
["EVENTS" in Term::Fabulous::Manual::Events](../Manual/Events.md#events) for how listener return values decide
whether an event continues to the Button's ancestors.

- `Activate` ([Term::Fabulous::Event::Activate](../Event/Activate.md))

    The user activated the Button: a click (`OnRelease` over the Button
    after `OnPress` on it), or `Enter` (also the keypad's Enter) or
    `Space` without modifiers while the Button has the focus.
    `$event->target` is the Button. Fired by the Button itself, from its
    own `OnRelease` and `KeyPress` listeners, which run before any
    listener you add. So a listener on an ancestor sees `Activate` before
    the `OnRelease` it came from bubbles up to it.

- `OnPress` ([Clay::UI::Events::OnPress](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnPress))

    The left mouse button went down over the Button. When Buttons are
    nested, only the innermost one under the pointer gets it. `$event->x`
    and `$event->y` are the pointer position in cells, as the center of
    the cell (column + 0.5, row + 0.5). The event is fired while the next
    frame is drawn, up to 1/30 second after the click.

- `OnRelease` ([Clay::UI::Events::OnRelease](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnRelease))

    The left mouse button went up over the Button after it was pressed over
    it: a completed click. Releasing elsewhere fires nothing. Carries `x`
    and `y` like `OnPress`.

- `OnFocus`, `OnBlur` ([Clay::UI::Events::OnFocus](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnFocus), [Clay::UI::Events::OnBlur](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnBlur))

    The Button got or lost the keyboard focus.

- `OnHoverStart`, `OnHoverStopped` ([Clay::UI::Events::OnHoverStart](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnHoverStart), [Clay::UI::Events::OnHoverStopped](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnHoverStopped))

    The pointer entered or left the Button. These events do not bubble.

- `KeyPress` ([Term::Fabulous::Event::KeyPress](../Event/KeyPress.md))

    A key was pressed while the Button had the focus. `Enter` and
    `Space` are used by the Button (they fire `Activate` and do not
    bubble); every other key bubbles on to the ancestors.

- `Mouse` ([Term::Fabulous::Event::Mouse](../Event/Mouse.md))

    Any mouse event over the Button (press, release, drag, wheel), when the
    Button paints the cell under the pointer (it needs a background color
    or a border there).

# KEYS

`Enter` (also the keypad's Enter) and `Space` activate the focused
Button, unless it is disabled. With a modifier (`Ctrl+Enter`,
`Shift+Space`, ...) they bubble on like every other key. A disabled
Button cannot have the focus; keys fired at it from code bubble on. Tab and Shift+Tab always move the focus
away (see ["FOCUS" in Term::Fabulous::Manual::Events](../Manual/Events.md#focus)).

# MOUSE

Pressing the left button on a cell the Button paints (its background
or its border) focuses the Button, unless `can_focus` is 0. A disabled
Button is neither focused nor pressed by the mouse. A Button
without a background color paints only its border (or nothing), so the
cells in between are transparent: there the `Mouse` event and the
focus go to the widget behind the Button. `OnPress`, `OnRelease` and
`Activate` do not depend on painting: they fire for any cell inside
the Button's box.

Pressing fires `OnPress`; releasing over the Button fires
`OnRelease` and then `Activate`. Releasing anywhere else cancels the
click. While the button is held with the pointer dragged off the
Button, `is_pressed` is 0 and the pressed look disappears; dragging
back onto it makes it 1 again, and releasing there still fires
`OnRelease` and `Activate`.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`can_focus` and `disabled` (`#true` or `#false`),
`focus_border_color` (a color string, or `#null` for no focus look),
`pressed_background_color` (a color string, `"reverse"`, or `#null`
for no pressed look) and `disabled_color` (a color string):

```kdl
use Term::Fabulous::Widget::Button as Button
use Term::Fabulous::Widget::Text as Text

Button "save" {
        background_color "#283c5a"
        border style=Round color="#5a6b8c"
        border_width 1
        padding left=1 right=1
        pressed_background_color "#3d5a85"
        Text { text "Save"; text_color "#ffffff"; }
}
```

Listeners cannot be given in KDL; attach them in Perl after building
the layout.

# SEE ALSO

[Term::Fabulous::Widget::Box](Box.md), [Term::Fabulous::Event::Activate](../Event/Activate.md),
["FOCUS" in Term::Fabulous::Manual::Events](../Manual/Events.md#focus), ["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse),
[Clay::UI::Role::Interaction::Pressable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3APressable),
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable),
[Clay::UI::Role::Interaction::Hoverable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AHoverable),
["Add buttons for the mouse and the keyboard (Button)" in Term::Fabulous::Cookbook::KeyboardAndMouse](../Cookbook/KeyboardAndMouse.md#add-buttons-for-the-mouse-and-the-keyboard-button),
the example programs `examples/widgets/button.pl` and
`examples/buttons-and-keys.pl`.
