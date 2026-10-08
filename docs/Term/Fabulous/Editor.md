# NAME

Term::Fabulous::Editor - Text, cursor, selection, undo and clipboard of
a text input

# SYNOPSIS

```perl
use Term::Fabulous::Editor;

my $editor = Term::Fabulous::Editor->new( text => "Hello\nworld" );

$editor->move_document_start;
$editor->move_word_right(1);         # select "Hello"
$editor->type('Goodbye');            # replaces the selection
say $editor->text;                   # "Goodbye\nworld"

$editor->undo;
say $editor->text;                   # "Hello\nworld"

# Inside a text input widget:
my $field_editor = $text_field->editor;
$field_editor->select_all;
$text_field->mark_changed;           # the next frame scrolls and paints it
```

# DESCRIPTION

`Term::Fabulous::Editor` is the editing model behind
[Term::Fabulous::Widget::TextField](Widget/TextField.md) and
[Term::Fabulous::Widget::TextArea](Widget/TextArea.md), without any drawing: a list of
lines, a cursor, an optional selection, an undo history and a
clipboard. The widgets translate key presses and clicks into calls of
these methods and draw the result. You use the editor directly when you
want to move the cursor, select or change text of an input from your
program (through `$input->editor`), or when you build a text widget
of your own.

The text is a Perl character string (decoded text), not UTF-8 encoded
bytes. Internally it is kept as a list of lines without their line
breaks; `text` joins them with `"\n"`.

The cursor moves by grapheme clusters: what a reader sees as one
character, such as `e` followed by a combining accent, an emoji with a
skin tone modifier, or a flag made of two regional indicators. The
segmentation is the same as the renderer's ([Term::Fabulous::Unicode](Unicode.md)),
so the cursor never lands inside a character. Words, for word movement
and word deletion, are runs of `\w` characters (letters, digits and
`_`).

Changes made through the editor of an input widget fire no `Change`
event. Call `$input->mark_changed` afterwards so that a frame is
drawn: the input notices the new ["revision"](#revision) then, scrolls the cursor
into view and paints the text (see
["editor" in Term::Fabulous::Widget::TextInput](Widget/TextInput.md#editor)).

# CONSTRUCTOR

## new

```perl
my $editor = Term::Fabulous::Editor->new(
        text       => '',
        multi_line => 1,
        max_length => undef,
        accept     => undef,
);
```

All parameters are optional. Unknown parameters die, and so do invalid
values, with a message that starts with `Term::Fabulous::Editor:`.
Through a text input, the message names the input's class instead (see
["max\_length" in Term::Fabulous::Widget::TextInput](Widget/TextInput.md#max_length)).

- `text`

    A character string. Default: `''`. The initial text, as for
    ["set\_text"](#set_text). Dies if it is longer than `max_length`.

- `multi_line`

    A boolean. Default: 1. A single-line editor (0) turns every line break
    it is given into a space, so its text is always one line.

- `max_length`

    A non-negative integer, or `undef`. Default: `undef` (no limit). The
    most grapheme clusters the text may hold; every line break counts as
    one. Inserted and typed text is cut to fit. Dies if it is not a
    non-negative integer or `undef`.

- `accept`

    Which grapheme clusters may enter the text, as for ["set\_accept"](#set_accept).
    Default: `undef` (every cluster). Dies, as `set_accept` does, if the
    initial text has a cluster the spec rejects.

# POSITIONS

Several methods take or return a position: a line index `$row` (from
0) and a character offset `$offset` into that line (from 0, in Perl
characters, not columns). A valid position lies on a grapheme cluster
boundary. Methods that take a position clamp it to the text (a row past
the last line means the last line, an offset past the end of a line
means its end) and move an offset inside a cluster back to the start of
that cluster. A row or offset that is not an integer dies.

# METHODS: TEXT

## text

```perl
my $text = $editor->text;
```

The whole text, a character string with lines joined by `"\n"`.

## set\_text

```perl
$editor->set_text("new\ntext");
```

Replaces the whole text. `"\r\n"` and `"\r"` become `"\n"` (and every
line break becomes a space in a single-line editor). Puts the cursor at
the end, clears the selection and the undo and redo history. Returns the
editor. Dies if the text is not a string or is longer than
`max_length`.

## lines

```perl
my @lines = $editor->lines;
```

The lines of the text, without line breaks. There is always at least
one line (an empty text has one empty line).

## line

```perl
my $line = $editor->line($row);
```

One line of the text, without its line break. Valid rows are 0 to
`line_count - 1`; a row past the end or below 0 returns `undef`.

## line\_count

```perl
my $count = $editor->line_count;
```

The number of lines, at least 1.

## boundaries

```perl
my @offsets = $editor->boundaries($row);
```

The grapheme cluster boundaries of a line as character offsets, from 0
up to and including the length of the line. For `"ae\x{301}"` they are
`(0, 1, 3)`.

## character\_count

```perl
my $count = $editor->character_count;
```

The number of grapheme clusters in the text, line breaks included (each
counts as one). This is what `max_length` limits.

## is\_empty

```perl
if ( $editor->is_empty ) { ... }
```

True when the text is the empty string.

## max\_length

```perl
my $limit = $editor->max_length;
```

The length limit, or `undef` for none.

## set\_max\_length

```perl
$editor->set_max_length(80);
$editor->set_max_length(undef);
```

Sets the length limit. Returns the editor. Dies if the limit is not a
non-negative integer or `undef`, or if the text is already longer.

## accept

```perl
my $spec = $editor->accept;
```

The accept spec as it was given to ["set\_accept"](#set_accept), or `undef` for
none.

## set\_accept

```perl
$editor->set_accept('0-9');                             # digits only
$editor->set_accept(qr/\p{L}/);                         # letters of any script
$editor->set_accept( sub ($cluster) { $cluster ne ' ' } );
$editor->set_accept(undef);                             # everything again
```

Restricts which grapheme clusters may enter the text. The spec is the
body of a character class (what a KDL layout writes; `'0-9'` means
`qr/[0-9]/`), a regular expression that every cluster must match, a
code reference called with each cluster that returns true to accept
it, or `undef` for no restriction. Returns the editor.

["insert"](#insert) and ["type"](#type) drop the clusters the spec rejects and keep
the rest, so pasting `+49 170 1234` into a digits-only editor inserts
the digits; an insertion of which nothing is accepted does nothing at
all, not even replace the selection. Line breaks are never subject to
the spec. ["set\_text"](#set_text) is for the program and dies instead, as it does
for `max_length`; so does `set_accept` itself when the text already
has a rejected cluster. Dies for a string that is not a valid
character class body and for any other kind of value.

## revision

```perl
my $revision = $editor->revision;
```

A number that grows whenever the text, the cursor or the selection
changes: edits, `set_text`, undo, redo, every cursor movement and
selection change, also one that ends where it started. Compare it with
an earlier value to know whether a view of the editor is still up to
date; [Term::Fabulous::Widget::TextInput](Widget/TextInput.md) repaints and scrolls to the
cursor when it grew.

## text\_revision

```perl
my $revision = $editor->text_revision;
```

Like ["revision"](#revision), but grows only when the text changes (edits,
`set_text`, undo, redo), for what is derived from the text alone, such
as the line wrapping of [Term::Fabulous::Widget::TextArea](Widget/TextArea.md).

## multi\_line

```perl
my $keeps_line_breaks = $editor->multi_line;
```

True for a multi-line editor (see the `multi_line` parameter).

# METHODS: CURSOR AND SELECTION

The cursor is where typing inserts text. A selection reaches from an
anchor (where the selection started) to the cursor. The movement methods
below take an optional `$extend` argument: when true, the selection is
extended to the new cursor position (starting at the old cursor
position if there was no selection); when false or omitted, the
selection is cleared. Movement and selection methods return the editor,
so calls can be chained.

## cursor

```perl
my ( $row, $offset ) = $editor->cursor;
```

The position of the cursor.

## move\_to

```perl
$editor->move_to( $row, $offset );
$editor->move_to( $row, $offset, 1 );    # extend the selection
```

Moves the cursor to a position (see ["POSITIONS"](#positions)).

## move\_left

```perl
$editor->move_left;
$editor->move_left(1);
```

Moves one grapheme cluster to the left, to the end of the previous line
from the start of a line. Without `$extend` and with a selection, the
cursor goes to the start of the selection instead and the selection is
cleared.

## move\_right

```perl
$editor->move_right;
$editor->move_right(1);
```

Moves one grapheme cluster to the right, to the start of the next line
from the end of a line. Without `$extend` and with a selection, the
cursor goes to the end of the selection instead and the selection is
cleared.

## move\_word\_left

```perl
$editor->move_word_left($extend);
```

Moves to the start of the word before the cursor (skipping non-word
characters in between). From the start of a line, moves to the end of
the previous line.

## move\_word\_right

```perl
$editor->move_word_right($extend);
```

Moves to the end of the word after the cursor. From the end of a line,
moves to the start of the next line.

## move\_line\_start

```perl
$editor->move_line_start($extend);
```

Moves to the start of the cursor's line.

## move\_line\_end

```perl
$editor->move_line_end($extend);
```

Moves to the end of the cursor's line.

## move\_document\_start

```perl
$editor->move_document_start($extend);
```

Moves to the start of the text.

## move\_document\_end

```perl
$editor->move_document_end($extend);
```

Moves to the end of the text.

## set\_selection

```perl
$editor->set_selection( $anchor_row, $anchor_offset, $cursor_row, $cursor_offset );
```

Selects from the anchor position to the cursor position (either may
come first) and puts the cursor at the second position. Selecting an
empty range leaves no selection.

## select\_all

```perl
$editor->select_all;
```

Selects the whole text, with the cursor at its end.

## clear\_selection

```perl
$editor->clear_selection;
```

Removes the selection; the cursor stays where it is.

## select\_word\_at

```perl
$editor->select_word_at( $row, $offset );
```

Selects the word containing the grapheme cluster at the position (at the
end of a line: the last cluster). When that cluster is not part of a
word (its first character does not match `\w`), selects just that one
cluster. On an empty line, only moves the cursor there. This is what a
double click does.

## has\_selection

```perl
if ( $editor->has_selection ) { ... }
```

True when there is a non-empty selection.

## selection

```perl
my ( $row_0, $offset_0, $row_1, $offset_1 ) = $editor->selection;
```

The start and end positions of the selection, in text order (the start
comes first, whatever direction it was made in), or the empty list when
nothing is selected.

## selected\_text

```perl
my $text = $editor->selected_text;
```

The selected text (lines joined with `"\n"`), or `''` when nothing is
selected.

# METHODS: EDITING

Every edit method returns 1 when it changed the text and 0 when it did
not. An edit that changes the text replaces the selection (if there is
one), leaves no selection behind, puts the cursor after the inserted
text, and can be undone. None of them fires events; they are plain
methods on the text model.

## insert

```perl
$editor->insert('text');
```

Inserts a character string at the cursor, replacing the selection. Line
breaks are converted as in ["set\_text"](#set_text). With an ["accept"](#accept) spec, the
clusters it rejects are left out; when that leaves nothing of a
non-empty string, nothing happens and 0 is returned. With
`max_length`, only as much of the text as fits is inserted. Inserting
an empty string with a selection deletes the selection.

## type

```perl
$editor->type('a');
```

Like ["insert"](#insert), for text the user types: consecutive calls are merged
into one undo step per word and per run of spaces, so undo takes back a
word at a time. Any cursor movement, and any other edit, ends the
current step. Typing an empty string with a selection deletes the
selection, as `insert` does, in an undo step of its own.

## delete\_backward

```perl
$editor->delete_backward;
```

Deletes the selection, or else the grapheme cluster (or line break)
before the cursor. This is `Backspace`.

## delete\_forward

```perl
$editor->delete_forward;
```

Deletes the selection, or else the grapheme cluster (or line break)
after the cursor. This is `Delete`.

## delete\_word\_backward

```perl
$editor->delete_word_backward;
```

Deletes the selection, or else everything from the start of the word
before the cursor to the cursor.

## delete\_word\_forward

```perl
$editor->delete_word_forward;
```

Deletes the selection, or else everything from the cursor to the end of
the word after it.

## delete\_to\_line\_start

```perl
$editor->delete_to_line_start;
```

Deletes the selection, or else everything from the start of the line to
the cursor. At the start of a line, deletes the line break before it
(joining the line with the previous one).

## delete\_to\_line\_end

```perl
$editor->delete_to_line_end;
```

Deletes the selection, or else everything from the cursor to the end of
the line. At the end of a line, deletes the line break after it.

# METHODS: CLIPBOARD

## copy

```perl
$editor->copy;
```

Puts the selected text on the clipboard. Returns 1, or 0 (and leaves the
clipboard alone) when nothing is selected. Does not change the text.

## cut

```perl
$editor->cut;
```

Puts the selected text on the clipboard and deletes it. Returns 1, or 0
when nothing is selected.

## paste

```perl
$editor->paste;
```

Inserts the clipboard at the cursor, like ["insert"](#insert). Returns whether
the text changed.

## clipboard

```perl
my $text = Term::Fabulous::Editor->clipboard;
Term::Fabulous::Editor->clipboard('text to paste');
$editor->clipboard('text to paste');    # the same clipboard
```

Reads or sets the clipboard, called on the class or on any editor: one character
string shared by all editors, and therefore by all text inputs, of the
program. It is not connected to the clipboard of your desktop; set it
yourself to bring text in from there. Setting anything but a string
dies.

# METHODS: UNDO

## undo

```perl
$editor->undo;
```

Takes back the last edit, restoring the text, the cursor and the
selection as they were before it. Returns 1, or 0 when there is nothing
to undo. Up to 100 steps are kept; older ones are forgotten. A step
keeps only the text it replaced and the text it wrote, so the history
stays small however long the text is.

## redo

```perl
$editor->redo;
```

Redoes the last undone edit and puts the cursor after it, without a
selection. Returns 1, or 0 when there is nothing to redo. Any new edit
clears the redo steps.

## can\_undo

```perl
if ( $editor->can_undo ) { ... }
```

True when ["undo"](#undo) would do something.

## can\_redo

```perl
if ( $editor->can_redo ) { ... }
```

True when ["redo"](#redo) would do something.

# EXAMPLES

## Insert a timestamp at the cursor of a text area

```perl
use POSIX qw(strftime);

my $editor = $notes->editor;
if ( $editor->insert( strftime( '%Y-%m-%d %H:%M ', localtime ) ) ) {
        $notes->mark_changed;    # the next frame scrolls to the cursor
}
```

## Select the second line of a text area

```perl
my $editor = $area->editor;
$editor->set_selection( 1, 0, 1, length $editor->line(1) );
$area->mark_changed;
```

## Load the system clipboard on a key press

The clipboard is not the desktop clipboard. This listener on the root
widget copies the desktop clipboard (through the `xclip` program) into
it when the user presses `F2`; `F2` bubbles up from text inputs, and
`Ctrl+V` then pastes the text.

```perl
use Clay::UI::Enum::Result;
use Encode qw(decode);

$root->on( KeyPress => sub ($event) {
        return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'F2';
        my $bytes = qx{xclip -o -selection clipboard};    # UTF-8 bytes
        Term::Fabulous::Editor->clipboard( decode( 'UTF-8', $bytes ) ) if defined $bytes;
        return;
} );
```

# SEE ALSO

[Term::Fabulous::Widget::TextInput](Widget/TextInput.md), [Term::Fabulous::Widget::TextField](Widget/TextField.md),
[Term::Fabulous::Widget::TextArea](Widget/TextArea.md), [Term::Fabulous::TextView](TextView.md),
[Term::Fabulous::Unicode](Unicode.md),
[the editing section of the forms guide](Manual/Forms.md#editing-text),
["Copy and paste through the clipboard" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#copy-and-paste-through-the-clipboard).
