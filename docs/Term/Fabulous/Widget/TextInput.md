# NAME

Term::Fabulous::Widget::TextInput - Common base class of the text input widgets

# SYNOPSIS

```perl
use Clay::UI::Enum::Result;
use Term::Fabulous::Widget::TextField;

# The parameters and methods below work the same for both text inputs:
my $field = Term::Fabulous::Widget::TextField->new(
        value             => 'initial text',
        placeholder       => 'Type here',
        max_length        => 40,
        read_only         => 0,
        placeholder_color => '#787e8a',
        selection_color   => [ 38, 79, 120 ],
);

my $text = $field->value;          # a character string
$field->value('replaced');         # fires no Change event

$field->on( Change => sub ($event) {
        say 'now: ', $event->value;
        return Clay::UI::Enum::Result->CONTINUE;
} );
```

# DESCRIPTION

`Term::Fabulous::Widget::TextInput` is the abstract base class of
[Term::Fabulous::Widget::TextField](TextField.md) (one line) and
[Term::Fabulous::Widget::TextArea](TextArea.md) (several lines). It holds what both
have in common: the text with its cursor, selection, undo history and
clipboard (kept in a [Term::Fabulous::Editor](../Editor.md)), the editing keys, mouse
selection, the placeholder and the `read_only` mode. You do not create
a `TextInput` directly; its `new` dies.

The text is a Perl character string (decoded text), not UTF-8 encoded
bytes. The cursor moves by grapheme clusters, that is by what a reader
sees as one character (a letter with a combining accent, an emoji with
modifiers, a flag), and wide characters such as CJK take two columns.

While the input has the focus, its content is painted on
`focus_background_color` and the cursor is shown as a block: the
character under it in reverse video. Selected text is painted on
`selection_color`. While the text is empty, the `placeholder` is
shown instead, in `placeholder_color`.

Everything described for [Term::Fabulous::Widget::Input](Input.md) applies as
well: `disabled`, the colors, focus, sizing and the `Change` event.

# CONSTRUCTOR

## new

```perl
my $field = Term::Fabulous::Widget::TextField->new(%parameters);
my $area  = Term::Fabulous::Widget::TextArea->new(%parameters);
```

The text inputs accept the parameters of
["CONSTRUCTOR" in Term::Fabulous::Widget::Input](Input.md#constructor) and these. Unknown
parameters die.

- `value`

    A character string. Default: `''`. The initial text. The cursor starts
    at its end. A text field turns line breaks into spaces; a text area
    converts `"\r\n"` and `"\r"` to `"\n"`. Dies if the text is longer
    than `max_length`.

- `placeholder`

    A character string. Default: `''` (none). A hint shown in
    `placeholder_color` while the text is empty. It is never part of the
    `value`.

- `max_length`

    A non-negative integer, or `undef`. Default: `undef` (no limit). The
    most characters the text may hold, counted in grapheme clusters; in a
    text area every line break counts as one. Typing and pasting stop at the
    limit: pasted text is cut to fit. Dies if the initial `value` is longer.

- `read_only`

    A boolean, stored as 1 or 0. Default: 0. A read-only input can still
    take the focus, and its text can be selected and copied, but the user
    cannot change it: typing and the editing keys are not used and bubble
    on to the ancestors. Programmatic writes to `value` still work. A read-only input looks
    like an editable one; disable it (["disabled" in Term::Fabulous::Widget::Input](Input.md#disabled))
    when the user should see that the text cannot be changed. A reference
    dies.

- `placeholder_color`

    A color, in any format [Term::Fabulous::Widget::Input](Input.md) accepts.
    Default: the theme's `text_input.placeholder`, `[120, 126, 138, 255]`
    in the dark theme, a gray.

- `selection_color`

    A color, in any format [Term::Fabulous::Widget::Input](Input.md) accepts. The
    background of selected text. Default: the theme's
    `text_input.selection`, `[38, 79, 120, 255]` in the dark theme, a
    dark blue.

- `background_color`

    Any [Term::Fabulous::Color](../Color.md) format, stored as `[r, g, b, a]`.
    Default: the theme's `text_input.background`, `[36, 40, 48, 255]` in
    the dark theme, a dark gray, so the input stands out from its
    surroundings. Pass `[0, 0, 0, 0]` for no background of its own.

# METHODS

## value

```perl
my $text = $input->value;
$input->value("new text");
```

Accessor for the text, a character string. Writing replaces the whole
text, puts the cursor at its end, clears the selection and the undo
history, marks the input changed, and returns the new text (after line-break
conversion). It fires no `Change` event. Dies if the new text is not a
string or is longer than `max_length`.

## max\_length

```perl
my $limit = $input->max_length;
$input->max_length(10);
$input->max_length(undef);         # no limit
```

Accessor for the length limit (see the `max_length` parameter). Returns
the new limit. Dies if the limit is not a non-negative integer or
`undef`, or if the current text is already longer; the limit then stays as it
was.

## placeholder

```perl
$input->placeholder('Search');
```

Accessor for the placeholder text. Writing marks the input changed and
returns the new placeholder; a value that is not a string dies and
leaves the placeholder unchanged.

## read\_only

```perl
my $is_read_only = $input->read_only;
$input->read_only(1);
```

Accessor for the `read_only` flag. Returns 1 or 0, also for a value
passed to `new`. Any plain value is accepted as a boolean; a reference
dies and leaves the flag unchanged. Writing does not change what the
input shows.

## placeholder\_color

```perl
$input->placeholder_color('#888888');
```

Accessor for the placeholder color. Writing marks the input changed and returns the
new color as `[r, g, b, a]`; an invalid color dies and leaves the color
unchanged.

## selection\_color

```perl
$input->selection_color([ 60, 60, 120 ]);
```

Accessor for the selection background. Writing marks the input changed and returns
the new color as `[r, g, b, a]`; an invalid color dies and leaves the color
unchanged.

## editor

```perl
my $editor = $input->editor;
```

The [Term::Fabulous::Editor](../Editor.md) that holds the text, the cursor, the
selection and the undo history. Use it to move the cursor, select or
edit text from your program. Afterwards call `$input->mark_changed`
so that a frame is drawn: the input notices the change of the editor
(["revision" in Term::Fabulous::Editor](../Editor.md#revision)) when the frame is drawn, scrolls
the cursor into view and paints the text. Edits made through the editor
fire no `Change` event.

```perl
$field->editor->select_all;
$field->mark_changed;

$area->editor->move_document_start;
$area->editor->insert("Dear Sir or Madam,\n");
$area->mark_changed;
```

# KEYS

The keys below are named as ["main\_key\_name" in Term::Fabulous::Event::KeyPress](../Event/KeyPress.md#main_key_name)
returns them, so the keypad keys a terminal with the kitty keyboard
protocol tells apart work as their main keyboard keys. A text input uses them while it has the focus and is
enabled; they then do not bubble. All other keys bubble on to the
ancestors: for example `Escape`, `Tab`, `BackTab` (`Shift+Tab`),
`F1` to `F12` and `Alt+` combinations. [Term::Fabulous](../../../../README.md) moves the
focus on `Tab` and `BackTab` and stops on `Ctrl+C`, after the key
has been delivered.

- Typing

    A printable character (pressed without `Ctrl` or `Alt`) is inserted at
    the cursor, replacing the selection.

- `Left`, `Right`

    Move the cursor one character left or right, across line breaks. With a
    selection, they move to its start (`Left`) or end (`Right`) and clear
    it.

- `Ctrl+Left`, `Ctrl+Right`

    Move to the start of the word before the cursor, or to the end of the
    word after it. Words are runs of letters, digits and `_`.

- `Home`, `End`

    Move to the start or end of the line (in a text area: of the text
    line, not of the wrapped row).

- `Ctrl+Home`, `Ctrl+End`

    Move to the start or end of the whole text.

- `Shift+Left`, `Shift+Right`, `Ctrl+Shift+Left`, `Ctrl+Shift+Right`, `Shift+Home`, `Shift+End`, `Ctrl+Shift+Home`, `Ctrl+Shift+End`

    The movements above, extending the selection.

- `Ctrl+A`

    Selects the whole text.

- `Backspace`, `Delete`

    Delete the selection, or else the character before (`Backspace`) or
    after (`Delete`) the cursor.

- `Ctrl+W`, `Ctrl+Delete`

    Delete the selection, or else the word before (`Ctrl+W`) or after
    (`Ctrl+Delete`) the cursor.

- `Ctrl+U`, `Ctrl+K`

    Delete the selection, or else everything from the start of the line to
    the cursor (`Ctrl+U`) or from the cursor to the end of the line
    (`Ctrl+K`). At the very start (end) of a line, they delete the line
    break before (after) it.

- `Ctrl+X`, `Shift+Delete`

    Cut: copy the selection to the clipboard and delete it.

- `Ctrl+Insert`

    Copy the selection to the clipboard. `Ctrl+C` is not copy: it stops
    [Term::Fabulous](../../../../README.md).

- `Ctrl+V`, `Shift+Insert`

    Paste the clipboard at the cursor, replacing the selection.

- `Ctrl+Z`, `Ctrl+Y`

    Undo and redo. Consecutive typing is undone one word (or one run of
    spaces) at a time; up to 100 steps are kept.

The clipboard is the one of ["clipboard" in Term::Fabulous::Editor](../Editor.md#clipboard): one
string shared by all text inputs of the program. It is not the system
clipboard.

While `read_only` is set, typing and the keys that change the text
(`Backspace`, `Delete`, `Ctrl+W`, `Ctrl+Delete`, `Ctrl+U`,
`Ctrl+K`, `Ctrl+X`, `Shift+Delete`, `Ctrl+V`, `Shift+Insert`,
`Ctrl+Z`, `Ctrl+Y`) are not used and bubble; movement, selection and
copying still work.

While the text is hidden (a [Term::Fabulous::Widget::TextField](TextField.md) with a
`mask`), the word keys act on the whole text, so they cannot tell
where its spaces are: `Ctrl+Left` and `Ctrl+Right` move like `Home`
and `End`, `Ctrl+W` and `Ctrl+Delete` delete like `Ctrl+U` and
`Ctrl+K`. `Ctrl+X`, `Shift+Delete` and `Ctrl+Insert` do nothing
and bubble: hidden text is not copied to the clipboard.

[Term::Fabulous::Widget::TextField](TextField.md) and
[Term::Fabulous::Widget::TextArea](TextArea.md) add keys of their own (`Enter`,
`Up`, `Down`, ...); see their KEYS sections.

# MOUSE

- Click

    A left click places the cursor at the clicked character and focuses the
    input.

- Shift+click

    A left click with `Shift` held extends the selection from the cursor
    to the clicked character. Many terminals keep `Shift` with the mouse
    for their own text selection and do not pass such a click on; dragging
    works everywhere.

- Double click

    A second left click at the same position within 0.4 seconds selects the
    word there (or the single character, when it is not part of a word),
    or the whole text while it is hidden.

- Drag

    Moving the pointer with the left button held selects from where the
    button went down to the pointer, as long as the pointer stays over the
    input.

# EVENTS

- `Change`

    [Term::Fabulous::Event::Change](../Event/Change.md) after every change the user makes to
    the text (typing, deleting, cutting, pasting, undo, redo), with the new
    text as its `value`. Keys that do not change the text (cursor
    movement, copying, typing at `max_length`) fire nothing. Programmatic
    changes through `value` or `editor` fire nothing.

[Term::Fabulous::Widget::TextField](TextField.md) also fires
[Term::Fabulous::Event::Submit](../Event/Submit.md) on `Enter`.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Input](Input.md#kdl-properties), plus
`value`, `placeholder`, `max_length`, `read_only` (`#true` /
`#false`), `placeholder_color` and `selection_color`. `max_length`
is applied before `value`, wherever it stands, so a too long value
dies.

```kdl
TextField "nick" {
        max_length 12
        value "guest"
        placeholder "Nickname"
}
```

# SUBCLASS INTERFACE

[Term::Fabulous::Widget::TextField](TextField.md) and
[Term::Fabulous::Widget::TextArea](TextArea.md) build on these; a new kind of text
input would too. A text input lays its text out with a
[Term::Fabulous::TextView](../TextView.md) (["view"](#view)), which does the wrapping, the
scrolling and the mapping between cells and text positions; the text
input keeps the keys, the mouse, the painting and the placeholder.

## is\_multi\_line

```perl
method is_multi_line :common () { return 1 }
```

Class method. Whether the editor keeps line breaks (1) or turns them
into spaces (0, the default).

## view

```perl
$self->view->set_wrap(1);
```

The [Term::Fabulous::TextView](../TextView.md) of the input: one row without wrapping
until a subclass changes its settings (see
["set\_wrap, set\_scrollbar" in Term::Fabulous::TextView](../TextView.md#set_wrap-set_scrollbar)). The input gives it the size
of its buffer and lets it follow the cursor every time a frame is drawn,
and paints the rows it shows. Use it to move the cursor by rows
(["move\_vertically" in Term::Fabulous::TextView](../TextView.md#move_vertically)) or to scroll
(["scroll\_rows" in Term::Fabulous::TextView](../TextView.md#scroll_rows)); call `mark_changed` after
changing what it shows.

## natural\_size

```perl
method natural_size () { return ( $preferred_columns, 1 ) }
```

Required; see ["natural\_size" in Term::Fabulous::Widget::Input](Input.md#natural_size).

## paint

```perl
method paint :override () {
        $self->SUPER::paint;
        ...    # paint more, for example a scrollbar
}
```

Paints the rows the view shows, with the selection and the cursor, or
the placeholder while the text is empty; see
["paint" in Term::Fabulous::Widget::Input](Input.md#paint). Override it to paint more.

## hides\_text

```perl
method hides_text :override () { return defined $mask ? 1 : 0 }
```

Whether the text is not shown as it is. Default: 0; the text field
returns 1 while it has a `mask`. While it is true, the text cannot be
copied or cut, and the word keys and the double click act on the whole
text (see ["KEYS"](#keys)).

## display\_cluster

```perl
method display_cluster :override ($cluster) { return $shown }
```

How one grapheme cluster of the text is shown; the view lays the text
out with what this returns. The default replaces control characters
(see ["sanitize\_text" in Term::Fabulous::Unicode](../Unicode.md#sanitize_text)); the text field returns
its `mask` instead when one is set. When what it returns changes, call
["display\_changed" in Term::Fabulous::TextView](../TextView.md#display_changed).

## apply\_edit

```perl
return $self->apply_edit( $self->editor->insert($text) );
```

Call after an editor edit made on behalf of the user: marks the input
changed (the next frame scrolls to the cursor and paints the result),
and fires `Change` when the argument is true (the editor's edit
methods return whether the text changed). Returns 1, so it can be
returned from `handle_key` directly.

# SEE ALSO

[Term::Fabulous::Widget::TextField](TextField.md), [Term::Fabulous::Widget::TextArea](TextArea.md),
[Term::Fabulous::Editor](../Editor.md), [Term::Fabulous::TextView](../TextView.md),
[Term::Fabulous::Widget::Input](Input.md),
[the editing section of the forms guide](../Manual/Forms.md#editing-text),
["Copy and paste through the clipboard" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#copy-and-paste-through-the-clipboard).
