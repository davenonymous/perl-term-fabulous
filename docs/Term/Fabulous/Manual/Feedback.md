# NAME

Term::Fabulous::Manual::Feedback - Progress bars, spinners, toasts, status bars, prompts and file dialogs

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Forms](Forms.md). Next page: [Term::Fabulous::Manual::Menus](Menus.md).

This page covers the widgets that tell the user what the program is
doing: a [progress bar](#progress-bars) for a task whose extent is
known, or not, a [spinner](#spinners) for one that just takes a
while, [toasts](#toasts-and-alerts) for messages that must not
interrupt the user, and a [status bar](#status-bars) for messages and
the program's state at the bottom of the screen. They take no input.
The program sets their state, from a timer, a process or a listener,
and they draw themselves. The ones that move do so on the application's
clock, without a timer of their own (see ["ANIMATION"](#animation)).

The section ["PROMPTS"](#prompts) is about the other direction: a prompt stops
the user to ask a question, and reports the answer. ["FILE DIALOGS"](#file-dialogs)
are prompts of a special kind, which ask for a file to open or save,
or for a folder.

The reference pages are the class pages: [Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md),
[Term::Fabulous::Widget::Spinner](../Widget/Spinner.md), [Term::Fabulous::Widget::Toast](../Widget/Toast.md),
[Term::Fabulous::Widget::StatusBar](../Widget/StatusBar.md), [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md)
and [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md).
The class the first two share, [Term::Fabulous::Widget::Display](../Widget/Display.md), is
the base of every widget that paints itself from its own state, and
the one to derive from for a feedback widget of your own
(["A widget that draws itself" in Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md#a-widget-that-draws-itself)).

# PROGRESS BARS

A [Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md) shows a value between `min`
and `max` as a bar filled from the left, with the percentage (or a
label of your own) next to it. The program sets the value as the work
goes on:

```perl
use Term::Fabulous::Widget::ProgressBar;

my $progress = Term::Fabulous::Widget::ProgressBar->new(
        max    => $total_bytes,
        layout => { sizing => { width => sizing_grow() } },
);
$progress->value($bytes_so_far);    # from a timer or a process
```

The picture shows the forms a bar can take
(`examples/widgets/progress-bar.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-progress-bar.svg" alt="Progress bars: a block bar at 42 percent, one with the value inside, a thin line bar, a striped bar, a bar of three colored segments, an indeterminate bar with its runner, and a two-row ASCII bar"></p>
</div>

- **Styles.** `block` (the default) fills cells with blocks and moves in
eighths of a cell; `line` draws a thin line like a slider's track;
`ascii` uses `#` and `-`. `fill_glyph`, `track_glyph` and
`stripe_glyph` replace the glyphs of a style. A layout that makes the
bar more than one row high gives a thicker bar.
- **The label.** The percentage by default, right of the bar;
`value_position => 'left'` or `'inside'` move it, and
`value_format` formats it as a `sprintf` string of the percentage or
with code that gets the value, for `12 of 50 MB`. `show_value => 0`
hides it.
- **Stripes.** `striped` alternates two glyphs along the filled part,
and `animated` moves them: the bar then shows that the task is still
running even while its value does not change.
- **Indeterminate.** A task whose extent is not known yet gets
`indeterminate => 1`: a runner bounces from end to end and the
label is hidden. Switch it off, set `max` and the value once the
extent is known.
- **Segments.** `segments` stack several values in one bar, each in its
own color: the used, reserved and free parts of a disk, the passed,
failed and skipped tests. `separated` leaves a cell of track between
them, and the bar's `value` is their sum.

The colors are `color` (the filled part), `track_color`,
`text_color` and, for a label inside the bar, `inside_text_color`;
the program changes `color` to show a state, for example red below a
threshold. In KDL:

```kdl
ProgressBar "download" {
        max 2048
        value 860
        style "line"
        sizing width=grow
}
```

# SPINNERS

A [Term::Fabulous::Widget::Spinner](../Widget/Spinner.md) shows that the program is busy
with something it cannot measure: connecting, waiting, loading. It
cycles through the frames of its style next to a label:

```perl
use Term::Fabulous::Widget::Spinner;

my $spinner = Term::Fabulous::Widget::Spinner->new( label => 'Connecting' );
$status_row->add_child($spinner);
# later:
$spinner->stop;
$status_row->remove_child($spinner);
```

The styles come in three sizes: one cell (`dots`, the default, made
of Braille patterns; `line`, `arc`, `circle`, `arrow`, `box`,
`pulse`, `bar`), a few cells (`dots3`, `bounce`, `wave`) and
three rows (`ring`). `frames` of your own, of one or several rows,
replace the style's, and `interval` sets the pace. `stop` freezes
the spinner at its first frame; a stopped spinner costs nothing. The
picture shows every style (`examples/widgets/spinner.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-spinner.svg" alt="Spinners in every style, each with its name: dots, line, arc, circle, arrow, box, pulse and bar in one cell, dots3, bounce and wave in several, and the three-row ring; a stopped one and one with frames of its own"></p>
</div>

In KDL:

```kdl
Spinner "busy" {
        style "arc"
        label "Loading"
}
```

# TOASTS AND ALERTS

A [Term::Fabulous::Widget::Toast](../Widget/Toast.md) is a short message in a corner of
the screen that goes away by itself: a box with an icon, a title, a
message and a close mark, in the color of its kind (`info`,
`success`, `warning` or `danger`). `show` floats it over
everything else, where it lines up below the toasts shown there
before, and takes it away after `timeout` seconds; a click on the
close mark or `hide` takes it away at once. Toasts take no focus and
no keys:

```perl
use Term::Fabulous::Widget::Toast;

$save->on( Activate => sub ($event) {
        save();
        Term::Fabulous::Widget::Toast->new( kind => 'success', title => 'Saved', message => 'Written to disk.' )->show($ui);
        return;
} );
```

An `important` toast is filled with its color, for messages that must
not be missed; `timeout => undef` keeps a toast until it is
closed; `position` chooses the corner (or the top or bottom center),
and every corner stacks its own toasts. The same widget is an _alert_
when it is added to the layout as a child instead of being shown: it
then stays where it is put, with or without a close mark. The picture
shows toasts of every kind, an important one and an alert box
(`examples/widgets/toast.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-toast.svg" alt="Toasts stacked in the top right corner: an info, a success and a warning toast with titles, messages and close marks, a filled danger toast in the bottom right corner, and an alert box inside the form"></p>
</div>

A toast fires `Close` ([Term::Fabulous::Event::Close](../Event/Close.md)) when it goes,
whichever way. In KDL a toast is an alert box inside its parent:

```kdl
Toast "unsaved" {
        kind "warning"
        message "You have unsaved changes."
        closable #false
}
```

# STATUS BARS

A [Term::Fabulous::Widget::StatusBar](../Widget/StatusBar.md) is one row, usually the last
row of the screen. On its left it shows a _message_: what just
happened, or what a key does now. On its right it shows _parts_,
short texts about the state of the program, such as the position of the
cursor or a marker for unsaved changes.

A message has one of the kinds a toast has, which gives it its color:
`info` for plain news (drawn like normal text), `success`, `warning`
and `danger`. Parts have these kinds as well, plus `dim` for a hint
that should not draw the eye and `accent` for one that should:

```perl
use Term::Fabulous::Widget::StatusBar;

my $status = Term::Fabulous::Widget::StatusBar->new(
        message => 'Ready.',
        timeout => 5,
        parts   => sub { ( ( $modified ? [ 'modified', 'accent' ] : () ), "Line $line", [ 'F1 help', 'dim' ] ) },
);
$root->add_child( $content, $status );

$status->message( 'Saved notes.txt.', 'success' );
```

A message stays until the next one replaces it, or for `timeout`
seconds when the bar has a timeout. The parts may be a list, which the
program sets again when the state changes, or a code reference, which
the bar calls whenever a frame is drawn. A code reference keeps the
parts up to date without any code that updates them, because a frame
is drawn after every key and every click. When the message and the
parts do not fit side by side, the message is cut and ends in an
ellipsis. The picture shows status bars of the kinds `success`,
`warning` and `danger` (`examples/widgets/status-bar.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-status-bar.svg" alt="A list of files with the cursor on budget.csv and, at the bottom, a status bar with the green message Saved budget.csv. and the parts file 3 of 6 and Ctrl+C quits. Above the list, status bars with a success message, a yellow warning with a blue modified part, and a red error with a red read-only part"></p>
</div>

A toast and a status bar both report what happened. A toast floats
over the screen and draws the eye, so it suits news the user must not
miss. A status bar does not move anything on the screen, so it suits
the steady stream of small news that an editor or a browser of files
produces. The recipe
["Show messages and state in a status bar (StatusBar)" in Term::Fabulous::Cookbook::Menus](../Cookbook/Menus.md#show-messages-and-state-in-a-status-bar-statusbar)
is a complete program. A status bar can also be part of a KDL layout
file, with `message`, `kind` and `timeout`:

```kdl
StatusBar "status" {
        message "Ready."
        timeout 5
}
```

# PROMPTS

A [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md) is a dialog that asks the user
something and waits for the answer: whether to delete a file, what to
call it, or simply that something went wrong. It has a title, a
message, optional input fields and a row of buttons. Like every
[Term::Fabulous::Widget::Dialog](../Widget/Dialog.md), it opens over the screen and keeps
the keyboard focus until it closes.

The three most common prompts take one call each.
[alert](../Widget/Prompt.md#alert) says something and has an
OK button, [confirm](../Widget/Prompt.md#confirm) asks a
question with OK and Cancel, and [ask](../Widget/Prompt.md#ask)
asks for one value:

```perl
use Term::Fabulous::Widget::Prompt;

Term::Fabulous::Widget::Prompt->confirm(
        $ui,
        title   => 'Delete notes.txt?',
        message => 'It cannot be restored.',
        ok      => 'Delete',
        focus   => 'cancel',
)->on( Answer => sub ($event) {
        unlink 'notes.txt' if $event->button eq 'ok';
        return;
} );
```

When the user presses a button, the prompt closes, gives the focus back
to the widget that had it, and fires `Answer`
([Term::Fabulous::Event::Answer](../Event/Answer.md)) with the id of the button and the
values of the fields. `Escape` answers with the button `cancel`.

A prompt of your own takes any input widgets as its fields, each with a
name and a label. The inputs check their own values, with `required`
and `validator` (see ["Checking input" in Term::Fabulous::Manual::Forms](Forms.md#checking-input)),
and a button marked as _primary_ asks them before it answers. While a
value is wrong, the prompt stays open, says which field is wrong and
why, and moves the focus to that field. A `check` of the whole prompt
catches what involves more than one field. The picture shows a prompt
whose e-mail field holds an address that is not valid
(`examples/widgets/prompt.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-prompt.svg" alt="A New contact prompt over the dimmed list of contacts: Name holds Ada Lovelace, E-mail holds ada@engine in red, and the red line E-mail: Please enter an e-mail address. sits above the Add and Cancel buttons"></p>
</div>

The recipes
["Confirm before quitting (Prompt)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#confirm-before-quitting-prompt) and
["Ask for a number and check it (Prompt, validator)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-for-a-number-and-check-it-prompt-validator)
are complete programs. For a dialog that is not a question, build a
[Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) and fill it with any widgets.

# FILE DIALOGS

A [Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md) asks the user for a file to
open, a name to save a file under, or a folder. It lists the folders
and files of a folder, with their sizes and the times they were last
modified, and has a field for a name or a path. The user walks through
the folders with `Enter` and `Backspace` or the mouse, picks an entry
with the cursor, or types a name. Like a prompt, it opens over the
screen, keeps the focus while it is open, and reports the result with
one `Answer` event after it closed:

```perl
use Term::Fabulous::Widget::FileDialog;

Term::Fabulous::Widget::FileDialog->new(
        mode      => 'open',
        directory => $notes_folder,
        filters   => [ [ 'Notes' => '*.txt *.md' ], [ 'All files' => '*' ] ],
)->on( Answer => sub ($event) {
        open_note( $event->value('path') ) if $event->button eq 'open';
        return;
} )->open($ui);
```

The `mode` decides what the user chooses. In `open` mode it is a file
that exists, in `save` mode a name in a folder that exists, and in
`folder` mode a folder; the list then shows folders only. The button
of the answer is the mode's, `open`, `save` or `choose`, and
`$event->value('path')` is the absolute path, as bytes: exactly
what the file system uses, ready for `open`. The list shows the names
decoded from UTF-8. `Cancel` answers `cancel`, and so does
`Escape`, which also sets `dismissed`.

_Filters_ decide which files the list shows. Each has a label and
patterns such as `*.txt *.md`; with two or more, a dropdown below the
field switches between them. Folders always show, and names that start
with a dot show only while the `Show hidden files` checkbox is
checked. In save mode, the dialog starts in the field with the name
selected up to its extension, `default_extension` adds an extension
to a name without a dot, and an existing file is replaced only after
a question, which starts on `Cancel`. The file the document already
has, given as `current_file`, is the exception: saving to it again
asks nothing. The picture shows the
dialog to open a note, with the cursor on a file
(`examples/widgets/file-dialog.pl`):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-file-dialog.svg" alt="An Open a file dialog over a dimmed notes program: the folder line ends in Documents/Projects/analytical-engine/notes, the list shows two folders and four notes with their sizes and modification times, the cursor is on reading-list.txt, which is also in the File field, and below it are the Notes filter, the Show hidden files checkbox and the Open and Cancel buttons"></p>
</div>

The dialog only chooses a path. It checks that a file to open is there,
and that the folder of a file to save is there and the file is not a
folder, but reading and writing are up to the program. The recipe
["Open and save a file (FileDialog)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#open-and-save-a-file-filedialog)
is a complete program.

# ANIMATION

Spinners, and progress bars that are `indeterminate` or `animated`,
move by themselves. They need no timer: a moving widget reads the application's
clock (["now" in Term::Fabulous](../../../../README.md#now)) and asks for a frame at the moment its
next frame is due (["request\_frame\_at" in Term::Fabulous](../../../../README.md#request_frame_at)); Term::Fabulous
draws it at the next tick of its frame timer, and nothing is drawn in
between. In a test, the `clock` parameter of ["new" in Term::Fabulous](../../../../README.md#new)
moves the animation on, and the screenshot tools of
[Term::Fabulous::Examples](../Examples.md) run it on a virtual clock. A widget of your
own animates the same way; see
["ANIMATION" in Term::Fabulous::Widget::Display](../Widget/Display.md#animation).

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Forms](Forms.md). Next page: [Term::Fabulous::Manual::Menus](Menus.md).

The class pages: [Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md),
[Term::Fabulous::Widget::Spinner](../Widget/Spinner.md), [Term::Fabulous::Widget::Toast](../Widget/Toast.md),
[Term::Fabulous::Widget::StatusBar](../Widget/StatusBar.md), [Term::Fabulous::Widget::Prompt](../Widget/Prompt.md),
[Term::Fabulous::Widget::FileDialog](../Widget/FileDialog.md), [Term::Fabulous::Widget::Display](../Widget/Display.md).
["Timers and other asynchronous work" in Term::Fabulous::Manual::Programs](Programs.md#timers-and-other-asynchronous-work)
for the timers that drive a bar, and
[Term::Fabulous::Cookbook::LiveData](../Cookbook/LiveData.md) for complete programs that update
the screen while they work.
