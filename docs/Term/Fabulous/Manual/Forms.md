# NAME

Term::Fabulous::Manual::Forms - Forms and input widgets

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Events](Events.md). Next page: [Term::Fabulous::Manual::Feedback](Feedback.md).

This page is the guide to the input widgets: text fields, text areas,
checkboxes, radio buttons, dropdowns and sliders. It first describes
what all inputs have in common (value, `Change` event, id, focus,
disabled and read-only inputs, the visual states, size and checking
input), then shows each input widget with a short example and a
picture, explains how the text inputs are edited (keys, selection,
clipboard, undo), and ends with complete forms: reading all values and
building a form from a KDL layout file. The reference of each widget is
on its class page; complete programs are in
[Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md).

The page assumes you know how to build a widget tree
(["WIDGETS AND THE WIDGET TREE" in Term::Fabulous::Manual::Layout](Layout.md#widgets-and-the-widget-tree)) and how
listeners work (["EVENTS" in Term::Fabulous::Manual::Events](Events.md#events)).

- ["FORMS AND INPUT WIDGETS"](#forms-and-input-widgets): the widgets and what they share
- ["THE INPUT WIDGETS ONE BY ONE"](#the-input-widgets-one-by-one): text fields, password fields, text
areas, checkboxes, radio buttons, dropdowns, sliders
- ["EDITING TEXT"](#editing-text): keys, selection, clipboard, undo, editing from the
program
- ["KEYS OF THE INPUT WIDGETS"](#keys-of-the-input-widgets): all keys at a glance
- ["COMPLETE FORMS"](#complete-forms): a small form, reading all values, a form in KDL

# FORMS AND INPUT WIDGETS

A form is a box with input widgets in it. Term::Fabulous has no form
widget of its own: any [Term::Fabulous::Widget::Box](../Widget/Box.md) holds inputs, and
because the events of the inputs bubble up to it, one listener on the
box sees every change.

## The input widgets

- [Term::Fabulous::Widget::TextField](../Widget/TextField.md)

    One line of text, optionally masked for passwords. Fires `Submit` on
    `Enter`. See ["Text fields"](#text-fields).

- [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md)

    Several lines of text, wrapped or scrolled sideways, with a scrollbar.
    See ["Text areas"](#text-areas).

- [Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md)

    On or off, with an optional "indeterminate" third look. See
    ["Checkboxes"](#checkboxes).

- [Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md) and [Term::Fabulous::Widget::RadioButton](../Widget/RadioButton.md)

    One choice of several, all visible. See ["Radio buttons"](#radio-buttons).

- [Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md)

    One choice of several, from a list that opens over the other widgets.
    See ["Dropdowns"](#dropdowns).

- [Term::Fabulous::Widget::Slider](../Widget/Slider.md)

    A number from a range. See ["Sliders"](#sliders).

- [Term::Fabulous::Widget::StarRating](../Widget/StarRating.md)

    A number of stars, whole or half, editable or read-only. See
    ["Star ratings"](#star-ratings).

- [Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md)

    One choice of a few, shown side by side as one bar. See
    ["Segmented controls"](#segmented-controls).

`examples/form.pl` uses all of them in one form. The picture shows it
after the user typed a name and a note and chose a color; the status
line at the bottom shows the last `Change`.

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-form.svg" alt="A form with name, password, notes, color, size, volume, newsletter and terms, and the status line color changed to: Yellow"></p>
</div>

All input widgets except the radio group are subclasses of
[Term::Fabulous::Widget::Input](../Widget/Input.md), whose page describes the shared
parameters and methods in full. The text field and the text area share
a second base class, [Term::Fabulous::Widget::TextInput](../Widget/TextInput.md), with the
editing keys, the placeholder and `read_only`. A radio group is a box
that holds radio buttons; it takes the focus and holds the value for
all of them.

## Values

Every input has a `value` method that reads its current value:

- a text field or text area: its text, a character string (see
["Text is character strings" in Term::Fabulous::Manual::Looks](Looks.md#text-is-character-strings));
- a checkbox: 1 (checked) or 0;
- a radio group: the value of the selected button, or `undef`;
- a dropdown: the value of the selected option, or `undef`;
- a slider: a number.

To set the value from your program, call `value` with an argument on a
text field, text area, radio group, dropdown or slider, and `checked`
on a checkbox (a checkbox's `value` is read only). A radio button's
`value` is different: it is the value the button gives its group when
it is selected, and writing it does not select the button.

```perl
$name->value('Ada Lovelace');
$terms->checked(1);
$size->value('l');           # a radio group: selects the button with the value 'l'
$color->value('navy');       # a dropdown: selects the option with the value 'navy'
$volume->value(75);
```

Setting a value from the program never fires `Change`. Three methods
act like the user instead and do fire it: `$checkbox->toggle`,
`$group->choose($button)` and `$dropdown->choose($index)`.

## The Change and Submit events

An input fires a [Term::Fabulous::Event::Change](../Event/Change.md) when the user changes
its value. `$event->value` is the new value and
`$event->target` the input that changed. A radio group fires it on
the group, not on the button.

```perl
use Clay::UI::Enum::Result;

$volume->on(
        Change => sub ($event) {
                say 'Volume: ', $event->value;
                return Clay::UI::Enum::Result->CONTINUE;
        }
);
```

`Change` bubbles to the ancestors of the input, unless a listener on
the way stops it (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](Events.md#return-values-and-bubbling)), so one
listener on the form box sees the changes of all inputs inside it. Tell
the inputs apart by their id:

```perl
$form->on(
        Change => sub ($event) {
                $status->text( $event->target->id . ' is now ' . ( $event->value // 'nothing' ) );
                return;
        }
);
```

A text field also fires a [Term::Fabulous::Event::Submit](../Event/Submit.md) when the
user presses `Enter`, with the text as `$event->value`. A text
area uses `Enter` for a new line and fires no `Submit`. To react to
`Enter` in other inputs, listen for `KeyPress` on the form (see
["Application shortcuts" in Term::Fabulous::Manual::Events](Events.md#application-shortcuts)).

## Ids

Give every input an `id` (`id => 'email'` in Perl,
`TextField "email"` in KDL). The id identifies the input in a form-wide
listener (`$event->target->id`), and
[find\_by\_id](../Widget.md#find_by_id) finds it in the tree, which is how
a program gets hold of the inputs of a form built from a layout file.
Ids must be unique within a widget tree (see
["Widget ids" in Term::Fabulous::Manual::Layout](Layout.md#widget-ids)).

## Focus

The input that has the _focus_ (see
["focus" in Term::Fabulous::Manual::Glossary](Glossary.md#focus)) receives the key presses.
`Tab` moves the focus to the next input, `Shift+Tab` (`BackTab`) to
the previous one, and a click on an input focuses it. A radio group is
one focus stop for all its buttons. To put the cursor into the first
field when the program starts:

```perl
$ui->interaction->set_focused_widget($name);
```

The focused input shows it: its content is painted on its
`focus_background_color`, and a text input shows a block cursor. Keys
an input does not use, such as `Tab`, `Escape` and the function keys,
bubble on to its ancestors, so application shortcuts keep working while
the user types. The [focus section](Events.md#focus) of the events
page describes the focus order, `can_focus` and how to change the
order.

## Disabled inputs

`disabled` greys an input out: it is painted in its `disabled_color`,
ignores keys, clicks and the mouse wheel, and cannot take the focus, so
`Tab` skips it. An input that has the focus loses it when it is
disabled. Buttons and radio groups have `disabled` too; a radio
button counts as disabled while its group is.

```perl
my $password = Term::Fabulous::Widget::TextField->new( id => 'password', mask => '*', disabled => 1 );

$terms->on(
        Change => sub ($event) {
                $password->disabled( !$event->value );    # enabled while the box is checked
                return;
        }
);
```

The program can still set the value of a disabled input. See
["disabled" in Term::Fabulous::Widget::Input](../Widget/Input.md#disabled) and the recipe
[Disable inputs until a checkbox is checked](../Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked).

## Read-only text

A text field or text area with `read_only => 1` keeps its normal
look and can take the focus; the user can move the cursor, select and
copy, but not change the text. Use it for text the user should be able
to copy, such as a generated key or a log; use `disabled` when the
input should look unavailable. See
["read\_only" in Term::Fabulous::Widget::TextInput](../Widget/TextInput.md#read_only).

## Visual states

The inputs show their state themselves; you choose the colors:

- **Focused**: the content on `focus_background_color`. A text input
shows the cursor as a block (the character under it in reverse video),
a slider paints its thumb in `text_color`, and a radio group highlights
the button the keyboard is on.
- **Disabled**: everything in `disabled_color`.
- **Placeholder**: an empty text input, or a dropdown without a selection,
shows its `placeholder` in `placeholder_color`.
- **Masked**: a text field with a `mask` shows the mask character for
every character of the text.
- **Selected text**: selected text in a text input is painted on
`selection_color`.
- **Checked, selected, open**: check marks, the selected radio button, the
filled part of a slider, the dropdown's arrow and the border of its
open list are painted in `accent_color`.

The colors are parameters and accessors of every input (`text_color`,
`disabled_color`, `accent_color`, `focus_background_color`, see
["CONSTRUCTOR" in Term::Fabulous::Widget::Input](../Widget/Input.md#constructor)) and of some inputs only
(`placeholder_color`, `selection_color`, `track_color`,
`list_background_color`, `highlight_text_color`). They take every
[color format](Looks.md#color-formats). The
pictures in ["THE INPUT WIDGETS ONE BY ONE"](#the-input-widgets-one-by-one) show each widget in its
states.

Your program can ask for the state too: `$input->is_focused`,
`$input->is_enabled`, or `$input->has_state('focused')` with
the state names `focused`, `hovered`, `pressed` and `disabled`
(see ["has\_state" in Term::Fabulous::Widget](../Widget.md#has_state)).

## Size

Without a `sizing` rule in its `layout`, an input is exactly as big
as its content: a text field is `preferred_columns` wide (default 20)
and one row high, a text area `preferred_columns` by `preferred_rows`
(40 by 5), a checkbox or radio button as wide as its mark and label, a
dropdown as wide as its longest label plus the arrow, a slider
`preferred_columns` plus its value label. A sizing rule in the
`layout` wins:

```perl
use Clay::XS qw(sizing_grow sizing_fixed);

# A text field that fills the width of its row:
Term::Fabulous::Widget::TextField->new( layout => { sizing => { width => sizing_grow() } } );

# A text area as wide as its parent and eight rows high:
Term::Fabulous::Widget::TextArea->new( layout => { sizing => { width => sizing_grow(), height => sizing_fixed(8) } } );
```

To line up the labels of a form, put each label into a box of the same
width group (see ["Equal sizes across the tree" in Term::Fabulous::Manual::Layout](Layout.md#equal-sizes-across-the-tree)),
as `examples/kdl-form.pl` does. The [size section](../Widget/Input.md#size) of
[Term::Fabulous::Widget::Input](../Widget/Input.md) explains how to line up inputs of
different natural widths.

## Checking input

The inputs check nothing about the meaning of a value; only the text
inputs have a length limit (`max_length`), and a slider keeps its
value within its range. Check the values yourself, either while the
user types (in a `Change` listener) or when the user submits the form
(in a `Submit` listener, or when the user activates a button), and
show what is wrong next to the input:

```perl
use Term::Fabulous::Widget::Text;

my $email = Term::Fabulous::Widget::TextField->new( id => 'email', placeholder => 'name@example.com', max_length => 80 );
my $error = Term::Fabulous::Widget::Text->new( text => ' ', text_color => '#e06c75' );

$email->on(
        Submit => sub ($event) {
                my $is_valid = $event->value =~ /\A[^@\s]+@[^@\s]+\z/;
                $error->text( $is_valid ? ' ' : 'Please enter an e-mail address.' );
                $ui->loop->stop if $is_valid;
                return;
        }
);
```

The recipe
[A login form](../Cookbook/Forms.md#a-login-form-centered-dialog-masked-password)
checks a whole form when the user presses `Enter`.

# THE INPUT WIDGETS ONE BY ONE

Every picture below comes from a program in `examples/widgets/`, which
shows the widget in its states; run it to try the keys. The class page
of each widget is the reference: all parameters, methods, keys, mouse
actions, events and KDL properties.

## Text fields

A [Term::Fabulous::Widget::TextField](../Widget/TextField.md) holds one line of text. It
scrolls sideways when the text is wider than the field, shows a
`placeholder` while it is empty, limits the text to `max_length`
characters if you set one, and fires `Submit` on `Enter`.

```perl
use Term::Fabulous::Widget::TextField;

my $name = Term::Fabulous::Widget::TextField->new(
        id                => 'name',
        placeholder       => 'Your name',
        max_length        => 40,
        preferred_columns => 30,
);
$name->on(
        Submit => sub ($event) {
                say 'Hello, ', $event->value;
                return;
        }
);
```

The picture shows a focused field in which `Lovelace` is selected, an
empty field with a placeholder, a masked password and a disabled field
(`examples/widgets/text-field.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text-field.svg" alt="Four text fields: a focused field with Ada Lovelace typed and Lovelace selected, a placeholder, a masked password and a disabled field"></p>
</div>

In KDL:

```kdl
TextField "name" {
        placeholder "Your name"
        max_length 40
        preferred_columns 30
}
```

## Password fields

A text field with a `mask` shows every character as the mask
character. `value` and the events still give the real text. A masked
text cannot be copied or cut, and the word keys and the double click
act on the whole text, so they do not reveal where its spaces are.

```perl
my $password = Term::Fabulous::Widget::TextField->new( id => 'password', mask => '*' );

$password->mask(undef);    # show the text, for example while a "Show password" box is checked
```

In KDL: `TextField "password" { mask "*"; }`. See
["mask" in Term::Fabulous::Widget::TextField](../Widget/TextField.md#mask).

## Text areas

A [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md) holds several lines of text.
`Enter` starts a new line. Long lines wrap at spaces (or, with
`wrap => 0`, the view scrolls sideways), and a scrollbar shows the
position while the text has more rows than the area.

```perl
use Clay::XS qw(sizing_grow sizing_fixed);
use Term::Fabulous::Widget::TextArea;

my $notes = Term::Fabulous::Widget::TextArea->new(
        id          => 'notes',
        placeholder => 'Anything else?',
        layout      => { sizing => { width => sizing_grow(), height => sizing_fixed(6) } },
);

my @lines = split /\n/, $notes->value, -1;
```

The picture shows a focused text area with a wrapped line and a
scrollbar (`examples/widgets/text-area.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text-area.svg" alt="A text area with a shopping list, a wrapped long line and a scrollbar"></p>
</div>

In KDL:

```kdl
TextArea "notes" {
        placeholder "Anything else?"
        sizing width=grow height="fixed(6)"
}
```

## Checkboxes

A [Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md) is on or off. `Space`,
`Enter` or a click toggles it. Its `value` is 1 or 0, and you set it
with `checked`. A checkbox can also be _indeterminate_, a third look
for a box that stands for a group of boxes of which only some are
checked.

```perl
use Term::Fabulous::Widget::Checkbox;

my $news = Term::Fabulous::Widget::Checkbox->new(
        id      => 'newsletter',
        label   => 'Send me the newsletter',
        checked => 1,
);
say $news->checked ? 'subscribed' : 'not subscribed';
```

The picture shows a focused, an unchecked, a checked, an indeterminate
and a disabled checkbox (`examples/widgets/checkbox.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-checkbox.svg" alt="Five check boxes: focused, unchecked, checked, indeterminate and disabled"></p>
</div>

In KDL:

```kdl
Checkbox "newsletter" {
        label "Send me the newsletter"
        checked #true
}
```

## Radio buttons

A [Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md) lets the user choose one of
several [Term::Fabulous::Widget::RadioButton](../Widget/RadioButton.md)s, all visible at once.
The buttons are children of the group (or deeper inside it, for example
in a box). The group holds the value, takes the focus for all its
buttons and fires `Change`; the arrow keys move the selection, and a
click selects a button. The buttons are laid out from top to bottom
unless the group's `layout` says otherwise.

```perl
use Clay::XS qw(CLAY_LEFT_TO_RIGHT);
use Term::Fabulous::Widget::RadioGroup;
use Term::Fabulous::Widget::RadioButton;

my $size = Term::Fabulous::Widget::RadioGroup->new(
        id     => 'size',
        value  => 'm',
        layout => { layout_direction => CLAY_LEFT_TO_RIGHT, child_gap => 2 },
);
$size->add_child( Term::Fabulous::Widget::RadioButton->new( label => $_->[0], value => $_->[1] ) )
        foreach [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ];
```

A button without a `value` stands for its label. The picture shows a
focused group in a row, a group in a column and a disabled group
(`examples/widgets/radio.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-radio.svg" alt="Radio buttons in a row with Medium chosen, in a column with Express shipping chosen, and a disabled group"></p>
</div>

In KDL:

```kdl
RadioGroup "size" {
        value "m"
        layout direction=right gap=2
        RadioButton { label "Small"; value "s"; }
        RadioButton { label "Medium"; value "m"; }
        RadioButton { label "Large"; value "l"; }
}
```

## Dropdowns

A [Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md) shows the selected option and
opens a list of all options on `Enter`, `Space`, `Alt+Down`, `F4` or
a click. The list floats over the other widgets, below the dropdown, or
above it when it does not fit below and there is more room above. Every option has a label (what
the user sees) and a value (what `value` and `Change` give); an option
given as a plain string is both. `Up` and `Down` change the selection
without opening the list, and typing the first letters of a label jumps
to it.

```perl
use Term::Fabulous::Widget::Dropdown;

my $color = Term::Fabulous::Widget::Dropdown->new(
        id          => 'color',
        placeholder => 'Pick a color',
        options     => [ 'Red', 'Green', [ 'Dark blue' => 'navy' ] ],
);
$color->value('navy');
say $color->selected_label;    # Dark blue
```

The picture shows a dropdown with its placeholder, one with a
selection, and a focused one with its list open
(`examples/widgets/dropdown.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-dropdown.svg" alt="Three dropdowns: a placeholder, France selected, and an open list of colors with Blue highlighted"></p>
</div>

In KDL, `options` adds options whose value is their label, and
`option` adds one option with a value of its own:

```kdl
Dropdown "color" {
        placeholder "Pick a color"
        options "Red" "Green"
        option "Dark blue" value="navy"
}
```

## Sliders

A [Term::Fabulous::Widget::Slider](../Widget/Slider.md) chooses a number between `min` and
`max`, in steps of `step`. The arrow keys move it by a step, `PageUp`
and `PageDown` by a `page_step`, `Home` and `End` to the ends; the
mouse clicks, drags and turns the wheel. The value is shown right of the
track, formatted with `value_format`.

```perl
use Term::Fabulous::Widget::Slider;

my $volume = Term::Fabulous::Widget::Slider->new(
        id           => 'volume',
        min          => 0,
        max          => 100,
        step         => 5,
        value        => 30,
        value_format => '%d%%',
);
```

The picture shows a focused slider, one that formats its value with a
code reference, and a disabled one (`examples/widgets/slider.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-slider.svg" alt="Three sliders: focused at 65 percent, a temperature of 21.5 degrees, and a disabled one"></p>
</div>

In KDL:

```kdl
Slider "volume" {
        step 5
        value 30
        value_format "%d%%"
}
```

## Star ratings

A [Term::Fabulous::Widget::StarRating](../Widget/StarRating.md) shows `max` stars (five by
default), the first `value` of them filled, and lets the user choose
with the arrow keys, the digits, a click on a star or the wheel; while
the pointer hovers over a star, the stars up to it are previewed. With
`half` the value moves in half stars. `read_only` shows a rating
without letting the user change it, for lists and cards, and
`show_value` adds the value as text.

```perl
use Term::Fabulous::Widget::StarRating;

my $rating = Term::Fabulous::Widget::StarRating->new(
        id         => 'rating',
        value      => 3,
        show_value => 1,
);
```

The picture shows a focused rating, one with half stars, a read-only
one, one out of ten without gaps and a disabled one
(`examples/widgets/star-rating.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-star-rating.svg" alt="Star ratings: a focused one with three of five stars, one with half stars and its value, a read-only one, one out of ten with a gap of zero, and a disabled one"></p>
</div>

In KDL:

```kdl
StarRating "rating" {
        value 3
        show_value #true
}
```

## Segmented controls

A [Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md) shows a few options side
by side as one bar and highlights the selected one: what a radio group
does, in one row and without marks. The options are given like a
dropdown's (a label, `[ label, value ]` or a hash, which may also
disable the option). The arrow keys, `Home`, `End` and the digits
choose, so does a click, and the selection changes at once. A
`vertical` control stacks the segments, and a control whose `layout`
makes it wider than its labels shares the space among the segments.

```perl
use Term::Fabulous::Widget::SegmentedControl;

my $period = Term::Fabulous::Widget::SegmentedControl->new(
        id      => 'period',
        options => [ [ Day => 'd' ], [ Week => 'w' ], [ Month => 'm' ] ],
        value   => 'w',
);
```

The picture shows a focused control, one stretched to the full width,
one with a disabled segment, a vertical one and a disabled one
(`examples/widgets/segmented-control.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-segmented-control.svg" alt="Segmented controls: a focused one with Week selected, one stretched to the full width, one with a disabled segment, a vertical one, and a disabled one"></p>
</div>

In KDL:

```kdl
SegmentedControl "period" {
        options "Day" "Week" "Month"
        value "Week"
}
```

# EDITING TEXT

The text field and the text area are edited the same way. What follows is a summary; the reference is the
[keys](../Widget/TextInput.md#keys) and
[mouse](../Widget/TextInput.md#mouse) sections of
[Term::Fabulous::Widget::TextInput](../Widget/TextInput.md).

## Editing keys

- Typing inserts at the cursor and replaces the selection.
- `Left` and `Right` move by a character, `Ctrl+Left` and
`Ctrl+Right` by a word, `Home` and `End` to the start and end of the
line, `Ctrl+Home` and `Ctrl+End` to the start and end of the text. In
a text area, `Up`, `Down`, `PageUp` and `PageDown` move by rows.
- `Backspace` and `Delete` delete a character, `Ctrl+W` and
`Ctrl+Delete` a word, `Ctrl+U` and `Ctrl+K` everything to the start
or the end of the line.
- In a text field, `Enter` fires `Submit`; in a text area, it starts a
new line.

`Tab` is never inserted; it moves the focus. The cursor moves by
_grapheme clusters_ (see ["grapheme cluster" in Term::Fabulous::Manual::Glossary](Glossary.md#grapheme-cluster)),
so it never stops inside a character that is made of several code
points, and wide characters such as CJK take two columns.

## Selecting text

Hold `Shift` with any movement key to select (`Shift+Right`,
`Ctrl+Shift+Left`, `Shift+End`, ...), or press `Ctrl+A` to select
everything. With the mouse, drag over the text, or double-click a word.
Selected text is painted on the input's `selection_color`, as in the
picture of the text field above. Typing, `Backspace` or a paste
replaces the selection.

## The clipboard

`Ctrl+Insert` copies the selection, `Ctrl+X` or `Shift+Delete` cuts
it, and `Ctrl+V` or `Shift+Insert` pastes. `Ctrl+C` is not copy: it
ends the program (see
["Keys Term::Fabulous handles itself" in Term::Fabulous::Manual::Events](Events.md#keys-term-fabulous-handles-itself)).

The clipboard is one string shared by all text inputs of the program,
not the clipboard of your desktop. Your program reads and writes it with
[clipboard](../Editor.md#clipboard) from [Term::Fabulous::Editor](../Editor.md):

```perl
use Term::Fabulous::Editor;

Term::Fabulous::Editor->clipboard('order-4711');    # Ctrl+V now pastes this
my $copied = Term::Fabulous::Editor->clipboard;      # what the user copied last
```

See the recipe
[Copy and paste through the clipboard](../Cookbook/Forms.md#copy-and-paste-through-the-clipboard)
and, for a key that loads the desktop clipboard, the example
[Load the system clipboard on a key press](../Editor.md#load-the-system-clipboard-on-a-key-press).

## Undo and redo

`Ctrl+Z` undoes the last change and `Ctrl+Y` redoes it. Typing is
undone one word (or one run of spaces) at a time; every other edit is
one step. Up to 100 steps are kept. Setting the text with `value`
clears the history.

## Changing the text from the program

`value` replaces the whole text. For anything finer, use the
[Term::Fabulous::Editor](../Editor.md) of the input, which holds the text, the
cursor, the selection and the undo history. After changing it, call
`mark_changed` on the input so that a frame is drawn; the input then
scrolls to the cursor and shows the change. Edits through the editor
fire no `Change`.

```perl
# Append a line at the end of a text area and show it:
my $editor = $log->editor;
$editor->move_document_end;
$editor->insert( $editor->is_empty ? $line : "\n$line" );
$log->mark_changed;

# Select the whole text of a field:
$name->editor->select_all;
$name->mark_changed;
```

# KEYS OF THE INPUT WIDGETS

The keys each input uses while it has the focus. Keys an input does not
use bubble to its ancestors. Each class page lists the details in its
KEYS section.

| Widget     | Keys                                                       |
| ---------- | ---------------------------------------------------------- |
| TextField  | typing, editing keys (see EDITING TEXT), Enter: Submit     |
| TextArea   | typing, editing keys, Up/Down/PageUp/PageDown (with Shift: |
|            | select), Enter: new line                                   |
| Checkbox   | Space, Enter: toggle                                       |
| RadioGroup | Up/Left, Down/Right: previous/next button (wraps around);  |
|            | Home, End: first/last button; Space, Enter: select the     |
|            | button the keyboard is on                                  |
| Dropdown   | closed: Enter, Space, Alt+Down, F4: open the list;         |
|            | Up, Down: previous/next option; Home, End: first/last      |
|            | option; letters: jump to a label                           |
|            | open: Up, Down, PageUp, PageDown, Home, End: move the      |
|            | highlight; Enter, Space: choose; Escape: close;            |
|            | letters: jump to a label                                   |
| Slider     | Left/Down, Right/Up: one step; PageDown, PageUp: one       |
|            | page_step; Home, End: lowest, highest value                |
| StarRating | Left/Down, Right/Up: one star (or half); Home, End: no     |
|            | stars, all stars; 0-9: that many stars                     |
| Segmented- | Left/Up, Right/Down: previous/next segment (wraps          |
| Control    | around); Home, End: first/last segment; 1-9: that segment  |

The class pages: ["KEYS" in Term::Fabulous::Widget::TextInput](../Widget/TextInput.md#keys),
["KEYS" in Term::Fabulous::Widget::TextField](../Widget/TextField.md#keys),
["KEYS" in Term::Fabulous::Widget::TextArea](../Widget/TextArea.md#keys),
["KEYS" in Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md#keys),
["KEYS" in Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md#keys),
["KEYS" in Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md#keys),
["KEYS" in Term::Fabulous::Widget::Slider](../Widget/Slider.md#keys),
["KEYS" in Term::Fabulous::Widget::StarRating](../Widget/StarRating.md#keys),
["KEYS" in Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md#keys).

# COMPLETE FORMS

## A small form

A complete program with a name field and a checkbox; one listener on the
form box reports every change, and `Enter` in the name field ends the
program:

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Checkbox;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;

my $form = Term::Fabulous::Widget::Box->new(
        layout => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_grow() },
                child_gap        => 1,
        },
);
my $name   = Term::Fabulous::Widget::TextField->new( id => 'name', placeholder => 'Your name' );
my $terms  = Term::Fabulous::Widget::Checkbox->new( id => 'terms', label => 'I accept the terms' );
my $status = Term::Fabulous::Widget::Text->new(
        text       => 'Type your name, then press Enter.',
        text_color => [ 220, 220, 220, 255 ],
);
$form->add_child( $name, $terms, $status );

my $ui = Term::Fabulous->new( root => $form, width => 80, height => 24 );

# One listener for every input of the form.
$form->on(
        Change => sub ($event) {
                $status->text( $event->target->id . ' is now ' . $event->value );
                return;
        }
);
$name->on(
        Submit => sub ($event) {
                $ui->loop->stop;
                return;
        }
);

# Start with the cursor in the name field.
$ui->interaction->set_focused_widget($name);
$ui->run;

say 'Name: ', $name->value, ', terms accepted: ', $terms->value;
```

## Reading a whole form

Every input has a `value` reader, so a short function collects the
values of all inputs with an id into a hash, for example to save them:

```perl
# { id => value } of every input at or below $node that has an id.
sub form_values ( $node, $values = {} ) {
        my $is_input = $node->isa('Term::Fabulous::Widget::Input') || $node->isa('Term::Fabulous::Widget::RadioGroup');
        $values->{ $node->id } = $node->value
                if $is_input && defined $node->id && !$node->isa('Term::Fabulous::Widget::RadioButton');
        if ( $node->can('children') ) {
                form_values( $_, $values ) foreach @{ $node->children };
        }
        return $values;
}

my $values = form_values($form);    # { name => 'Ada', terms => 1, ... }
```

Radio buttons are skipped: their group holds the state. The recipe
[Read all values of a form](../Cookbook/Forms.md#read-all-values-of-a-form) explains
the function in detail; to fill a form from saved values, call `value`
(or `checked` for a checkbox) on each input in the same way.

## A form in a KDL layout file

A form can be described in KDL (see
["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](KDL.md#kdl-layout-files)) and built with
[Term::Fabulous::Layout](../Layout.md). The program then finds the inputs by their
ids. `examples/kdl-form.pl` builds a form with every input widget
except the text area, shows each change in a status line and the values
of all inputs on `F2`:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-kdl-form.svg" alt="A form built from KDL with name, password, size, color, volume and newsletter, and a status line with all values"></p>
</div>

The recipe
[Build a form from a KDL file](../Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox)
shows and explains the program.

## More form recipes

[Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md) has complete programs for:

- [a login form in a centered dialog](../Cookbook/Forms.md#a-login-form-centered-dialog-masked-password),
which checks its input on `Enter`;
- [asking a question in a dialog](../Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget);
- [asking for input below the shell's output](../Cookbook/Forms.md#ask-for-input-below-the-shell-s-output-inline-mode);
- [choosing from options in Perl](../Cookbook/Forms.md#choose-from-options-in-perl-dropdown-radiogroup-slider);
- [disabling inputs until a checkbox is checked](../Cookbook/Forms.md#disable-inputs-until-a-checkbox-is-checked);
- [a status line that follows the focus](../Cookbook/Forms.md#show-a-status-line-that-follows-the-focus-onfocus);
- [changing the Tab order](../Cookbook/Forms.md#change-the-tab-order-hasfocusorder);
- [copying and pasting through the clipboard](../Cookbook/Forms.md#copy-and-paste-through-the-clipboard).

To write an input widget of your own, see
["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Input](../Widget/Input.md#subclass-interface) and
[Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md).

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Events](Events.md). Next page: [Term::Fabulous::Manual::Feedback](Feedback.md).

The class pages: [Term::Fabulous::Widget::Input](../Widget/Input.md),
[Term::Fabulous::Widget::TextInput](../Widget/TextInput.md), [Term::Fabulous::Widget::TextField](../Widget/TextField.md),
[Term::Fabulous::Widget::TextArea](../Widget/TextArea.md), [Term::Fabulous::Widget::Checkbox](../Widget/Checkbox.md),
[Term::Fabulous::Widget::RadioGroup](../Widget/RadioGroup.md), [Term::Fabulous::Widget::RadioButton](../Widget/RadioButton.md),
[Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md), [Term::Fabulous::Widget::Slider](../Widget/Slider.md),
[Term::Fabulous::Widget::StarRating](../Widget/StarRating.md),
[Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md),
[Term::Fabulous::Editor](../Editor.md), [Term::Fabulous::Event::Change](../Event/Change.md),
[Term::Fabulous::Event::Submit](../Event/Submit.md).

The recipes: [Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md).
