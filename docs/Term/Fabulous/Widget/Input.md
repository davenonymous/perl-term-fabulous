# NAME

Term::Fabulous::Widget::Input - Common base class of the input widgets

# SYNOPSIS

```perl
use Term::Fabulous::Widget::TextField;

# Every input widget accepts these parameters:
my $field = Term::Fabulous::Widget::TextField->new(
        id                     => 'name',
        disabled               => 0,
        text_color             => '#dcdfe4',
        accent_color           => [ 97, 175, 239, 255 ],
        disabled_color         => 0x6c7078,
        focus_background_color => 'rgb(52, 58, 72)',
);

$field->disabled(1);                   # gray, ignores input, loses the focus
$field->accent_color('#ff8800');      # shows in the next frame

# A widget of your own (see SUBCLASS INTERFACE):
use Object::Pad;
use Term::Fabulous::Widget::Input;

class My::Toggle :isa(Term::Fabulous::Widget::Input) :strict(params) {
        field $on = 0;

        method value () { return $on }

        method natural_size () { return ( 5, 1 ) }    # columns, rows

        method paint () {
                my $bg = $self->paint_focus_background;
                $self->paint_text( 0, 0, $on ? '[ON]' : '[OFF]', $self->accent_attr, $bg );
                return;
        }

        method activate () {                       # a click
                $on = $on ? 0 : 1;
                $self->mark_changed;                    # the next frame paints it
                $self->fire_change($on);
                return;
        }

        method handle_key ($event) {
                return 0 unless ( $event->main_key_name // '' ) eq 'Space';
                $self->activate;
                return 1;                               # used: stops bubbling
        }
}
```

# DESCRIPTION

`Term::Fabulous::Widget::Input` is the abstract base class of all
input widgets:

- [Term::Fabulous::Widget::TextField](TextField.md) - one line of text
- [Term::Fabulous::Widget::TextArea](TextArea.md) - several lines of text
- [Term::Fabulous::Widget::Checkbox](Checkbox.md) - a box to check
- [Term::Fabulous::Widget::RadioButton](RadioButton.md) - one choice of a
[Term::Fabulous::Widget::RadioGroup](RadioGroup.md)
- [Term::Fabulous::Widget::Dropdown](Dropdown.md) - one choice from a list that opens
- [Term::Fabulous::Widget::Slider](Slider.md) - a number from a range
- [Term::Fabulous::Widget::StarRating](StarRating.md) - a number of stars
- [Term::Fabulous::Widget::SegmentedControl](SegmentedControl.md) - one choice of a few,
side by side

You do not create an `Input` directly (the class is abstract and
`new` dies); this page describes what all input widgets have in
common, and how to write an input widget of your own.

What every input widget does:

- It takes the keyboard focus. Under [Term::Fabulous](../../../../README.md), `Tab` and
`BackTab` (Shift+Tab) move the focus from input to input, and a click on an
input focuses it. The focused input shows its content on
`focus_background_color`. A radio button is the exception: its radio
group takes the focus for all its buttons.
- It receives the key presses while it has the focus. Keys it uses (for
example letters in a text field) stop there; keys it does not use (for
example `Escape`, `Tab` or `F1`) bubble on to its ancestors, so
application shortcuts on an outer box keep working while the user types.
Each widget's KEYS section lists the keys it uses. See
["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard).
- It works with the mouse: clicks, drags and the mouse wheel, as described
in each widget's MOUSE section. The terminal reports the mouse only when
a button is pressed or released, while it is dragged, and when the wheel
turns; plain pointer movement is not reported. The hover state of an
input (`is_hovered`, the `OnHoverStart` and `OnHoverStopped` events)
therefore changes only at those moments, not while the pointer merely
moves.
- It fires a [Term::Fabulous::Event::Change](../Event/Change.md) when the user changes its
value (see ["EVENTS"](#events)).
- It sizes itself to its content unless the `layout` says otherwise (see
["SIZE"](#size)).
- It can be disabled (see ["disabled"](#disabled)).
- It has the derived states `focused`, `hovered`, `pressed` and
`disabled`, which `$input->has_state('focused')` and
`$input->states` report (see ["has\_state" in Term::Fabulous::Widget](../Widget.md#has_state)).
- It can be built from a KDL layout file (see ["KDL PROPERTIES"](#kdl-properties)).

Technically, an input is a [Term::Fabulous::Widget::Display](Display.md), a
canvas that paints itself when a frame is drawn (see ["Painting"](#painting)):
setters only record the new state, and the frame paints whatever
changed since the last one, so only cells that really changed are sent
to the terminal. Anything you draw into an input with the canvas
methods (`put`, `put_text`, ...) is lost the next time it paints.

## Painting

Every setter of an input records the new value and calls
`mark_changed` (["mark\_changed" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#mark_changed)), so a
frame becomes due; nothing is painted at once. When the frame is drawn,
the renderer calls the input's `refresh`
(["refresh" in Term::Fabulous::Widget::Canvas](Canvas.md#refresh)), which compares the input's
_paint key_ (see ["paint\_key"](#paint_key)) with the one it last painted for: the
size of its buffer, how often the input was marked changed, whether it
has the focus and whether it is enabled, and what a subclass adds, such
as the state of its radio group. Only when the key differs does it
clear the buffer and call ["paint"](#paint). So the cells always show the state
of the frame they are drawn in, also when the state was changed by
another widget, and a frame that changes nothing about an input paints
nothing of it. The cells read with `cell` show the state of the last
frame. This is how every [Term::Fabulous::Widget::Display](Display.md) paints; see
["Painting" in Term::Fabulous::Widget::Display](Display.md#painting).

# CONSTRUCTOR

## new

```perl
my $input = Term::Fabulous::Widget::TextField->new(%parameters);    # or any other input
```

Every input widget's `new` accepts the parameters below, in addition to
its own. Unknown parameters die. `Term::Fabulous::Widget::Input`
itself is abstract: calling `Term::Fabulous::Widget::Input->new`
dies.

- `id`

    A string. Optional. Identifies the widget for Clay, which needs a unique
    id per widget; it is also handy for telling inputs apart in a form-wide
    `Change` listener (`$event->target->id`). Ids must be unique in a
    widget tree.

- `layout`

    A hash reference of layout options, as for every widget: `sizing`,
    `padding`, `child_gap`, `child_alignment`, `layout_direction`. See
    ["LAYOUT" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#layout). A `sizing` you give here overrides
    the natural size of the input on that axis (see ["SIZE"](#size)).

- `background_color`

    The widget's background, in any format [Term::Fabulous::Color](../Color.md) accepts
    (see ["Color formats" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#color-formats)); it is stored as an
    `[r, g, b, a]` array reference. Text inputs and the dropdown
    default to a dark gray (`[36, 40, 48, 255]`); the other inputs have no
    background of their own and show the background of their parent.

- `border_width`
- `border_color`
- `border_style`

    A border around the input, exactly as for
    [Term::Fabulous::Widget::Box](Box.md); see ["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders).
    The border takes cells inside the widget's box; the natural size is
    grown accordingly.

- `disabled`

    A boolean, stored as 1 or 0. Default: 0. A disabled input is painted in
    `disabled_color`, ignores keys, clicks and the mouse wheel, and cannot
    take the focus; since the user cannot change it, it fires no `Change`
    or `Submit` of its own accord. See ["disabled"](#disabled).

- `can_focus`

    A boolean. Default: 1. Whether the input may take the keyboard focus
    (see [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable)). It counts while the
    input is enabled: a disabled input cannot take the focus, whatever this
    says (see ["can\_focus"](#can_focus)). A [Term::Fabulous::Widget::RadioButton](RadioButton.md) never
    takes the focus (it does not accept it, see ["accepts\_focus"](#accepts_focus)), so for
    it the parameter has no effect.

- `text_color`

    The color of the input's text. Default: `[220, 223, 228, 255]`, a light
    gray.

- `disabled_color`

    The color of all text while the input is disabled, and of inactive parts
    such as scrollbar tracks. Default: `[108, 112, 120, 255]`, a medium
    gray.

- `accent_color`

    The color of highlights: check marks, the selected radio button's mark,
    the filled part of a slider, the dropdown's arrow and the border of its
    open list. Default: `[97, 175, 239, 255]`, a light blue.

- `focus_background_color`

    The background of the input's content while it has the focus. Default:
    `[52, 58, 72, 255]`, a dark blue-gray.

The four colors accept every color format of the canvas: a packed
`0xRRGGBB` integer, an `[r, g, b]` or `[r, g, b, a]` array reference,
a `{ r, g, b }` hash reference, a string such as `'#ff8800'`,
`'rgb(255, 136, 0)'` or `'hsl(32, 100%, 50%)'`, or a
[Term::Fabulous::Color](../Color.md) object (see
["Colors" in Term::Fabulous::Widget::Canvas](Canvas.md#colors)). `undef` and invalid colors
die. A color with alpha 0 means "no color": the terminal's default color
is used.

An input is a [Term::Fabulous::Widget::Box](Box.md), so it also takes the
other parameters of a Box, described in ["new" in Term::Fabulous::Widget](../Widget.md#new):
`floating`, `width_group` and `height_group` (to line up the inputs
of a form), `classes`, `glyphs_show_through`, the per-side border
styles (`border_style_top` and so on), `border_corners` and
`outer_border_sides`.

# METHODS

## disabled

```perl
my $is_disabled = $input->disabled;
$input->disabled(1);
$input->disabled(0);
```

Accessor, from [Clay::UI::Role::Interaction::Disableable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3ADisableable). Returns 1
or 0; any plain true or false value may be written, also through
`new`; a reference dies (`Clay::UI: 'disabled' must be a plain boolean
value`).

Writing a true value disables the input: it is painted in
`disabled_color`, ignores keys, clicks and the mouse wheel (so the user
causes no `Change` or `Submit`), cannot take the focus (`can_focus`
reads 0) and, if it has the focus, gives the focus up at once (no widget is focused afterwards,
unless the input is inside an open [Term::Fabulous::Widget::Dialog](Dialog.md),
whose backdrop takes it). Clay::UI never presses a disabled widget: a
click on it fires no `OnPress` or `OnRelease`. `KeyPress` and
`Mouse` events fired on a disabled input still bubble on to its
ancestors, and it is still hovered (`OnHoverStart`,
`OnHoverStopped`), so listeners you add yourself for these still run.
It has the derived state `disabled`
(["DERIVED STATES" in Clay::UI::Role::Style::HasStates](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasStates#DERIVED-STATES)).

Writing a false value enables the input again: it can take the focus
when `can_focus` was last set to a true value, through `new`, a
layout file or the accessor, also while the input was disabled. A
[Term::Fabulous::Widget::RadioButton](RadioButton.md), which never takes the focus,
keeps 0. Writing the value the input already has changes nothing.
Returns the new value (1 or 0).

A radio button also counts as disabled while its radio group is
disabled: its `is_enabled` is then false, while its own `disabled`
stays 0.

## is\_enabled

```perl
if ( $input->is_enabled ) { ... }
```

True when the input accepts input, the opposite of `disabled`.

## text\_color

```perl
my $color = $input->text_color;
$input->text_color('#ffffff');
```

Accessor for the `text_color` parameter. The reader returns the color
as `[r, g, b, a]`, whatever form it was given in (see
["cell\_color" in Term::Fabulous::Check](../Check.md#cell_color)). Writing marks the input changed and
returns the new color. An invalid color, or `undef`, dies and leaves
the old color.

## disabled\_color

```perl
$input->disabled_color([ 90, 90, 90 ]);
```

Accessor for the `disabled_color` parameter; works like
["text\_color"](#text_color).

## accent\_color

```perl
$input->accent_color(0xFF8800);
```

Accessor for the `accent_color` parameter; works like ["text\_color"](#text_color).

## focus\_background\_color

```perl
$input->focus_background_color('rgb(40, 44, 60)');
```

Accessor for the `focus_background_color` parameter; works like
["text\_color"](#text_color).

## mark\_changed

```perl
$input->mark_changed;
```

Marks the input changed: a frame becomes due (see
["mark\_changed" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#mark_changed)), and that frame paints
the input again from its current state and sizes it again, also when
the change was made from a timer. The setters call it, so you only need
it after changing state behind the widget's back, for example through
["editor" in Term::Fabulous::Widget::TextInput](TextInput.md#editor). Returns the input.

## can\_focus

```perl
$input->can_focus(0);
if ( $input->can_focus ) { ... }
```

Whether the input can take the focus now: 1 when it may (the last
value written, through `new`, a layout file or this accessor, was
true), it is enabled and it accepts the focus at all (a radio button
does not); 0 otherwise. Writing records whether the input may take the
focus and returns what reading returns now: `can_focus(1)` on a
disabled input returns 0, and the input takes the focus once it is
enabled. The order of `can_focus` and `disabled` does not matter.
Writing a false value to the focused input takes the focus away at
once. From [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable).

## is\_focused

```perl
if ( $input->is_focused ) { ... }
```

True while the input has the keyboard focus. Inherited from
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable). Give an input the focus with
`$ui->interaction->set_focused_widget($input)`.

# SIZE

Every input has a natural content size: for example one row and as many
columns as its label needs (a checkbox), or `preferred_columns` by one
row (a text field). When the `layout` gives no `sizing` for an axis,
the input is given a fixed size on that axis: its natural size plus its
padding and border width (see ["Size" in Term::Fabulous::Widget::Display](Display.md#size)).
A `sizing` in the `layout` always wins:

```perl
# 20 columns wide (the default preferred_columns), one row high:
Term::Fabulous::Widget::TextField->new;

# As wide as the parent allows, still one row high:
Term::Fabulous::Widget::TextField->new( layout => { sizing => { width => sizing_grow() } } );
```

The natural size is a `fixed` sizing, and a `width_group` or
`height_group` (["new" in Term::Fabulous::Widget](../Widget.md#new)) lines up `fit` and
`grow` sizings only. An input has no content Clay could fit, so a
plain `fit` sizing gives it no columns at all; to line up inputs, give
each a `fit` sizing with its natural size as the minimum:

```perl
# Both 30 columns wide, the width of the wider one:
Term::Fabulous::Widget::TextField->new( width_group => 1, layout => { sizing => { width => sizing_fit(20) } } );
Term::Fabulous::Widget::TextField->new( width_group => 1, layout => { sizing => { width => sizing_fit(30) } } );
```

# EVENTS

- `Change`

    [Term::Fabulous::Event::Change](../Event/Change.md), fired on the input when the user
    changes its value. Setting the value from the program never fires it.
    It bubbles to the input's ancestors unless a listener on the way
    returns something other than `Clay::UI::Enum::Result->CONTINUE`.

- `OnFocus`, `OnBlur`

    [Clay::UI::Events::OnFocus](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnFocus) and [Clay::UI::Events::OnBlur](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnBlur), fired by
    Clay::UI when the input gains or loses the focus.

- `OnHoverStart`, `OnHoverStopped`, `OnPress`, `OnRelease`

    The pointer events of [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI); see ["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse).
    A completed click (`OnRelease` after a press on the same input) is what
    toggles a checkbox or selects a radio button.

- `CanvasResize`

    [Term::Fabulous::Event::CanvasResize](../Event/CanvasResize.md), fired when the layout gives the
    input a new size. The input paints itself for the new size in the same
    frame.

The input registers its own listeners for `KeyPress`, `Mouse`,
`OnFocus`, `OnBlur` and `OnRelease` when it is constructed. Listeners you add with `on` run after them, on the same
widget, and see every event, including keys the input used. Keep in mind
that your listener's return value also decides whether the event
bubbles further.

# KDL PROPERTIES

In a layout file (see [Term::Fabulous::Layout](../Layout.md)), every input accepts
the properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties)
(`layout`, `sizing`, `padding`, `border`, `background_color`,
`border_color`, `border_width`, `width_group`, `height_group`) and
the following ones. The string after the widget name is its `id`
(`TextField "name"` is the `id` `name`).

- `disabled`

    Takes `#true` or `#false`, like the `disabled` parameter.

- `can_focus`

    Takes `#true` or `#false`, like the `can_focus` parameter; with
    `disabled #true` in the same block the order does not matter.

- `text_color`, `disabled_color`, `accent_color`, `focus_background_color`

    Any [Term::Fabulous::Color](../Color.md) string, such as `"#ff8800"` or
    `"rgb(255, 136, 0)"`.

A complete layout with one disabled text field:

```kdl
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::TextField as TextField

Box "form" {
        TextField "name" {
                disabled #true
                accent_color "#ff8800"
                sizing width=grow
        }
}
```

Properties are applied after the widget was constructed, with the same
checks as the accessors of the same name. Values that depend on each
other are applied together, so their order in the layout does not
matter: a dropdown's `options` come before its `value`, a slider's
`min`, `max` and `step` are one range set before its `value`, and a
text input's `max_length` comes before its `value`. Everything else is
applied in the order of the layout.

# SUBCLASS INTERFACE

To write an input widget of your own, subclass
`Term::Fabulous::Widget::Input` with [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) (see the
["SYNOPSIS"](#synopsis)). You must implement `natural_size` and `paint`; override
the other methods as needed. Paint with `put_attrs`
(["put\_attrs" in Term::Fabulous::Widget::Canvas](Canvas.md#put_attrs)) and the helpers below and
those of ["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Display](Display.md#subclass-interface)
(`color_attr`, `paint_text`, `fill_attrs`), which take termbox2
attributes (the integers returned by `foreground_attr`, `color_attr`
and friends) instead of colors.

Term::Fabulous draws a frame only when something changed, and the frame
paints the input (see ["Painting"](#painting)). Whenever your widget changes state
that `paint` or `natural_size` uses, call `$self->mark_changed`
and do not paint: the next frame calls `paint`. When `paint` also
reads state of other objects that change without telling your widget,
add that state to ["paint\_key"](#paint_key). Without either, the change shows only
when something else makes the input paint.

## natural\_size

```perl
method natural_size () { return ( $columns, $rows ) }
```

Required. The content size the input wants when the layout does not
size it (see ["SIZE"](#size)): a number of cells per axis, or a sizing hash of
[Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS), as described in
["natural\_size" in Term::Fabulous::Widget::Display](Display.md#natural_size). Called for every frame.

## paint

```perl
method paint () { ... }
```

Required. Draws the input into its buffer. It is called while a frame is
drawn, when the ["paint\_key"](#paint_key) changed, with a cleared buffer that has at
least one cell; use `$self->columns` and `$self->rows` for
its size. Cell writes made here belong to the frame being drawn and make
no further frame due.

## paint\_key

```perl
method paint_key :override () {
        my $group = $self->group;
        return ( $self->SUPER::paint_key, $group->value, $group->is_focused );
}
```

The list of values ["paint"](#paint) depends on; the input paints again when
any of them changed since it last painted. The default holds what
["paint\_key" in Term::Fabulous::Widget::Display](Display.md#paint_key) holds (the size of the
buffer and a count of the input's `mark_changed` calls), whether the
input has the focus and whether it is enabled. Extend it with what
`paint` reads from other objects, which do not mark this input
changed: [Term::Fabulous::Widget::RadioButton](RadioButton.md) adds its group's value,
focus and cursor button, [Term::Fabulous::Widget::TextInput](TextInput.md) its
editor's revision. The values are compared as strings; keep them cheap
to compute, since the key is computed for every frame.

## handle\_key

```perl
method handle_key ($event) { return $used }
```

Receives every [Term::Fabulous::Event::KeyPress](../Event/KeyPress.md) fired on the input
(or bubbling up to it) while it is enabled. Return true when you used
the key: the event then stops. Return false to let it bubble on. The
default uses nothing.

## handle\_mouse

```perl
method handle_mouse ($event) { return $used }
```

Receives every [Term::Fabulous::Event::Mouse](../Event/Mouse.md) fired on the input (or
bubbling up to it) while it is enabled. Return value as for
`handle_key`. The default uses nothing.

The event carries terminal coordinates. Use
["cell\_at" in Term::Fabulous::Widget::Canvas](Canvas.md#cell_at) to turn them into a cell of
the input's buffer; it returns the empty list when the pointer is
outside the buffer (on the border or padding):

```perl
method handle_mouse ($event) {
        my ( $column, $row ) = $self->cell_at($event) or return 0;
        ...
}
```

## activate

```perl
method activate () { ... }
```

Called when the input is clicked (the left button pressed and released
over it) while it is enabled. The default does nothing.

## focus\_changed

```perl
method focus_changed ($is_focused) { ... }
```

Called after the input gained (`$is_focused` true) or lost the focus,
for what a widget does then besides painting (a dropdown closes its
list). The default does nothing; the focus is part of the
["paint\_key"](#paint_key).

## layout\_properties

```perl
method layout_properties :common () {
        return ( $class->SUPER::layout_properties, on_label => 'scalar', off_label => 'scalar', on_color => 'color' );
}
```

The table of the properties a KDL layout may set and how each is read
(see ["layout\_properties" in Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md#layout_properties)). To
make parameters of your widget settable from a layout file, declare it
as a class method (`:common`), keep the inherited table through
`$class->SUPER::layout_properties` and add an accessor (reader and
writer) of the same name for each new property. Every input inherits
`can_focus` and `disabled` (booleans) and its four colors.

## accepts\_focus

```perl
method accepts_focus :override () { return 0 }
```

Whether the input can ever take the focus. Default: 1 (from
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable)). An input that returns 0
(like [Term::Fabulous::Widget::RadioButton](RadioButton.md)) gets `can_focus` 0 even
when enabled.

## fire\_change

```perl
$self->fire_change($new_value);
```

Fires a [Term::Fabulous::Event::Change](../Event/Change.md) with that value on the input.
Call it after the user changed the value, never when the program did.

## foreground\_attr

```perl
my $fg = $self->foreground_attr;
```

The termbox2 attribute of `text_color`, or of `disabled_color` while
the input is disabled.

## accent\_attr

```perl
my $fg = $self->accent_attr;
```

The termbox2 attribute of `accent_color`, or of `disabled_color`
while the input is disabled.

## reverse\_attr

```perl
my $cursor_fg = $self->reverse_attr($fg);
```

An attribute in reverse video (foreground and background swapped), as
used for the text cursor. `undef` counts as the terminal default.

## rgba\_of

```perl
my $rgba = $self->rgba_of($color);
```

Any color the canvas accepts, as the `[r, g, b, a]` array reference
that `background_color` and `border_color` take. A packed integer is
opaque.

## focus\_background\_attr

```perl
my $bg = $self->focus_background_attr;
```

The attribute of `focus_background_color` while the input has the
focus, `undef` otherwise. Override it to change when the focus
background is shown ([Term::Fabulous::Widget::RadioButton](RadioButton.md) shows it
only on the button the keyboard is on).

## paint\_focus\_background

```perl
my $bg = $self->paint_focus_background;
```

Fills the whole buffer with `focus_background_attr` when it is defined,
and returns it (`undef` when the input shows no focus background).
Pass the result on as the background of everything you paint after it.

# CAVEATS

- A disabled input does not use the mouse wheel; inside a
[Term::Fabulous::Widget::ScrollBox](ScrollBox.md) the wheel over it scrolls the
scroll box. So does the wheel over a text area, a slider or an open
dropdown list that cannot move any further.

# SEE ALSO

["FORMS AND INPUT WIDGETS" in Term::Fabulous::Manual::Forms](../Manual/Forms.md#forms-and-input-widgets),
[Term::Fabulous::Event::Change](../Event/Change.md), [Term::Fabulous::Widget::Display](Display.md),
[Term::Fabulous::Widget::Canvas](Canvas.md), [Term::Fabulous::Widget::TextInput](TextInput.md).
