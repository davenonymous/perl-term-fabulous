# NAME

Term::Fabulous::Widget::TextField - Single-line text input

# SYNOPSIS

```perl
use Term::Fabulous::Widget::TextField;

my $name = Term::Fabulous::Widget::TextField->new(
        id          => 'name',
        placeholder => 'Your name',
        max_length  => 40,
);
$name->on( Submit => sub ($event) {
        say 'Hello, ', $event->value;
        return;
} );

my $password = Term::Fabulous::Widget::TextField->new(
        id   => 'password',
        mask => '*',
);

say $name->value;    # the text, a character string
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text-field.svg" alt="Four text fields: a focused field with Ada Lovelace typed and Lovelace selected, a placeholder, a masked password and a disabled field"></p>
</div>

# DESCRIPTION

The picture shows the states of a text field: focused, with part of the
text selected (the block cursor stands on the first selected
character); empty, showing its `placeholder`; masked for a password;
and disabled. The program is `examples/widgets/text-field.pl`.

A text field holds one line of text that the user can type, edit, select
and copy. When the text is wider than the field, the field scrolls
sideways to keep the cursor visible: just far enough to show the
cursor's cell (the cell after the text when the cursor is at its end),
never so far that the field ends in empty cells while text is hidden on
the left, and always starting at a whole character (see
["Scrolling" in Term::Fabulous::TextView](../TextView.md#scrolling)). Line breaks never get into the
text: in pasted or assigned text they become spaces. Pressing `Enter`
fires a [Term::Fabulous::Event::Submit](../Event/Submit.md).

The text is a Perl character string (decoded text), not UTF-8 encoded
bytes.

The editing keys, mouse selection, the placeholder, `max_length`,
`read_only` and the `Change` event are the same as in the text area
and are described in [Term::Fabulous::Widget::TextInput](TextInput.md). Disabling,
colors and sizing are described in [Term::Fabulous::Widget::Input](Input.md).

# CONSTRUCTOR

## new

```perl
my $field = Term::Fabulous::Widget::TextField->new(%parameters);
```

Accepts the parameters of
["CONSTRUCTOR" in Term::Fabulous::Widget::TextInput](TextInput.md#constructor) (`value`,
`placeholder`, `max_length`, `read_only`, `placeholder_color`,
`selection_color`, `background_color`) and of
["CONSTRUCTOR" in Term::Fabulous::Widget::Input](Input.md#constructor) (`id`, `layout`,
`disabled`, `can_focus`, `text_color`, `disabled_color`,
`accent_color`, `focus_background_color`, the border parameters, the
other Box parameters), plus the two below. Unknown parameters die.

- `preferred_columns`

    A positive integer. Default: 20. The width of the text in columns when
    the `layout` gives the field no width. The field is one row high unless
    the `layout` gives it a height. Padding and border are added to these
    sizes. Dies if not a positive integer.

- `mask`

    A single character that is one column wide, or `undef`. Default:
    `undef` (the text is shown). When set, every character of the text is
    shown as this character, for passwords. `value` and the `Change` and
    `Submit` events still give the real text. While the mask is set, the
    text cannot be copied or cut to the clipboard, and the word keys and
    the double click act on the whole text, so they do not tell where its
    spaces are (see ["KEYS" in Term::Fabulous::Widget::TextInput](TextInput.md#keys)). Dies if the mask is not exactly
    one grapheme cluster one column wide.

# METHODS

The methods of ["METHODS" in Term::Fabulous::Widget::TextInput](TextInput.md#methods) (`value`,
`max_length`, `placeholder`, `read_only`, `placeholder_color`,
`selection_color`, `editor`) and of
["METHODS" in Term::Fabulous::Widget::Input](Input.md#methods) (`disabled`, `is_enabled`,
the color accessors, `mark_changed`), plus:

## preferred\_columns

```perl
my $columns = $field->preferred_columns;
$field->preferred_columns(30);
```

Accessor for the `preferred_columns` parameter. A new value takes
effect at the next frame. Writing returns the new value. Dies if not a
positive integer; the old value then stays.

## mask

```perl
$field->mask('*');      # hide the text
$field->mask(undef);    # show it again
```

Accessor for the `mask` parameter. Writing marks the field changed and
returns the new mask. A mask that is not a single one-column character
dies; the old mask then stays.

# KEYS

All keys of ["KEYS" in Term::Fabulous::Widget::TextInput](TextInput.md#keys), plus:

- `Enter`

    Fires [Term::Fabulous::Event::Submit](../Event/Submit.md) with the text. The key is used
    (it does not bubble). This also happens when the field is `read_only`.

`Up`, `Down`, `PageUp` and `PageDown` are not used by a text field
and bubble to its ancestors, as do `Escape`, `Tab`, the function keys
and every other key not listed in ["KEYS" in Term::Fabulous::Widget::TextInput](TextInput.md#keys).

# MOUSE

As described in ["MOUSE" in Term::Fabulous::Widget::TextInput](TextInput.md#mouse): click to
place the cursor, drag (while the pointer stays over the input) to
select, double-click to select a word. The mouse wheel is not used.

# EVENTS

- `Change`

    [Term::Fabulous::Event::Change](../Event/Change.md) after every change the user makes to
    the text; `$event->value` is the new text.

- `Submit`

    [Term::Fabulous::Event::Submit](../Event/Submit.md) when the user presses `Enter`;
    `$event->value` is the text.

Neither is fired for changes made by the program. Both bubble to the
ancestors (see ["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)).

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::TextInput](TextInput.md#kdl-properties),
plus `preferred_columns` and `mask`:

```kdl
use Term::Fabulous::Widget::TextField as TextField

TextField "email" {
        placeholder "name@example.com"
        preferred_columns 30
        max_length 80
}
```

# EXAMPLES

## A search field that reacts to Enter and to typing

```perl
use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow);
use Term::Fabulous::Widget::TextField;

my $search = Term::Fabulous::Widget::TextField->new(
        id          => 'search',
        placeholder => 'Search (Enter to run)',
        layout      => { sizing => { width => sizing_grow() } },
);
$search->on( Change => sub ($event) {
        show_suggestions( $event->value );
        return Clay::UI::Enum::Result->CONTINUE;
} );
$search->on( Submit => sub ($event) {
        run_search( $event->value );
        return;
} );
```

## A password field that is enabled by a checkbox

```perl
use Term::Fabulous::Widget::Checkbox;

my $password = Term::Fabulous::Widget::TextField->new( mask => '*', disabled => 1 );
my $enable   = Term::Fabulous::Widget::Checkbox->new( label => 'Set a password' );
$enable->on( Change => sub ($event) {
        $password->disabled( !$event->value );
        return;
} );
```

## Give the field the focus when the program starts

```perl
my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->interaction->set_focused_widget($name);
$ui->run;
```

# SEE ALSO

[Term::Fabulous::Widget::TextInput](TextInput.md), [Term::Fabulous::Widget::TextArea](TextArea.md),
[Term::Fabulous::Event::Submit](../Event/Submit.md),
[the text field section of the forms guide](../Manual/Forms.md#text-fields),
["A login form (centered dialog, masked password)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#a-login-form-centered-dialog-masked-password).
