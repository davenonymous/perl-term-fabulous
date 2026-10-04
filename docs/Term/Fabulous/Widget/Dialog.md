# NAME

Term::Fabulous::Widget::Dialog - A box that opens over the whole screen
and keeps the focus

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Dialog;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(sizing_fixed);

my $dialog = Term::Fabulous::Widget::Dialog->new(
        id     => 'confirm',
        layout => { sizing => { width => sizing_fixed(40) } },
);
my $quit = Term::Fabulous::Widget::Button->new( background_color => [ 40, 60, 90, 255 ], layout => { padding => { left => 1, right => 1 } } );
$quit->add_child( Term::Fabulous::Widget::Text->new( text => 'Quit', text_color => [ 255, 255, 255, 255 ] ) );
$dialog->add_child(
        Term::Fabulous::Widget::Text->new( text => 'Really quit? Escape cancels.', text_color => [ 220, 220, 220, 255 ] ),
        $quit,
);
$quit->on( Activate => sub ($event) { $ui->loop->stop; return } );
$dialog->on( Close => sub ($event) { $status->text('cancelled'); return } );

# From a key binding or a button:
$dialog->open($ui);
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-dialog.svg" alt="A Delete 3 files? dialog with Delete and Cancel buttons over a dimmed list of files; Delete has the focus and a blue border"></p>
</div>

The program is `examples/widgets/dialog.pl`.

# DESCRIPTION

A Dialog is a [Term::Fabulous::Widget::Box](Box.md) that is not part of the
layout until it is opened. ["open"](#open) puts it in the center of the
screen, on top of everything else, behind a translucent backdrop that
dims the rest of the screen, and gives the keyboard focus to the first
widget inside it. While it is open:

- Tab and Shift+Tab cycle through the widgets inside the dialog only;
- mouse clicks outside the dialog reach nothing behind it, whatever the
`backdrop_color`: they move the focus onto the backdrop, from where
Tab goes to the first widget of the dialog and Shift+Tab to the last,
and their `Mouse` events are fired on the backdrop, from where they
bubble to the root widget (the backdrop's parent), not to the widgets
behind the dialog;
- key presses go to the focused widget inside the dialog and bubble up
through the dialog to the backdrop, where `Escape` closes the dialog
(unless `close_on_escape` is off). They go no further: the widgets
and key bindings behind the dialog do not see them. Ctrl+C still ends
the program, Tab and Shift+Tab still move the focus;
- the focus stays inside the dialog: when the focused widget is disabled
or removed, the backdrop takes the focus (an `OnBlur` listener inside
the dialog must let the event bubble for that, see
[Term::Fabulous::Widget::Dialog::Backdrop](Dialog/Backdrop.md));
- the widgets behind the dialog stay visible through the backdrop, but
are neither hovered nor pressed.

["close"](#close) takes the dialog off the screen, puts the focus back on the
widget that had it before (if that widget can still take the focus),
and fires `Close`
([Term::Fabulous::Event::Close](../Event/Close.md)) on the dialog. A closed dialog can be
opened again, as often as needed, and keeps its children and their
state in between.

A Dialog comes with a look from the theme's `dialog` family (a dark
background and a round border in the accent blue in the built-in dark
theme), one cell of padding and a vertical layout with a gap of one
row between the children. Every one of these is an ordinary Box
parameter and can be overridden. Give the dialog a
width (`sizing` in `layout`); without one it is as wide as its
widest child.

# CONSTRUCTOR

## new

```perl
my $dialog = Term::Fabulous::Widget::Dialog->new(%parameters);
```

All parameters are optional; unknown parameters die. A Dialog takes
every parameter of [Term::Fabulous::Widget::Box](Box.md) (see
["new" in Term::Fabulous::Widget](../Widget.md#new)), with the defaults described above,
plus:

- `backdrop_color`

    The color of the layer behind the dialog, in any format
    [Term::Fabulous::Color](../Color.md) accepts. Default: the theme's
    `dialog.backdrop`, `[ 0, 0, 0, 128 ]` in the dark theme, black at
    half opacity, which dims the screen behind the dialog. An opaque color
    hides it; alpha 0 leaves it as it is.

- `z_index`

    An integer from -32768 to 32767; other values die. Dialogs and other floating widgets with a higher value are
    drawn over those with a lower one. Default: 1000. The open list of a
    [Term::Fabulous::Widget::Dropdown](Dropdown.md) floats over every z\_index, so it is
    drawn over the dialog it is in.

- `close_on_escape`

    A boolean. Default: 1: `Escape`, pressed while the focus is inside the
    dialog, closes it. With 0 the program closes the dialog itself.

# METHODS

A Dialog has all methods of [Term::Fabulous::Widget](../Widget.md) plus these:

## open

```perl
$dialog->open($ui);
```

Opens the dialog in the [Term::Fabulous](../../../../README.md) object `$ui`: adds it to
the screen as described above and focuses the first focusable widget
inside it (the backdrop when there is none). Opening an open dialog
does nothing. Dies when `$ui` is not a [Term::Fabulous](../../../../README.md) (or other
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI)) object, and when the dialog has been added to another
widget as a child. Returns the dialog.

## close

```perl
$dialog->close;
```

Closes the dialog: removes it from the screen, gives the focus back to
the widget that had it when the dialog opened (if that widget still
exists and can take the focus) and fires `Close` on the dialog.
Closing a closed dialog does nothing. A dialog whose backdrop the
program took out of the tree itself (with `clear_children` on the
root, for example) is still open until `close` is called; `close`
then only fires `Close`. Returns the dialog.

## is\_open

```perl
if ( $dialog->is_open ) { ... }
```

1 while the dialog is open, 0 otherwise.

## backdrop

```perl
my $backdrop = $dialog->backdrop;
```

The [Term::Fabulous::Widget::Dialog::Backdrop](Dialog/Backdrop.md) behind the open dialog,
or `undef` while it is closed or after the program took it out of the
tree. Rarely needed.

## backdrop\_color, z\_index, close\_on\_escape

```perl
$dialog->backdrop_color( [ 0, 0, 0, 200 ] );
$dialog->z_index(2000);
$dialog->close_on_escape(0);
```

Accessors for the constructor parameters of the same names. Without an
argument they return the current value; with one they set it and return
the stored form. Changes to `backdrop_color` and `z_index` show on an
open dialog with the next frame.

# EVENTS

Besides the events of every Box (["EVENTS" in Term::Fabulous::Widget::Box](Box.md#events)),
a Dialog fires:

- `Close` ([Term::Fabulous::Event::Close](../Event/Close.md))

    The dialog was closed, by `Escape` or by ["close"](#close). Fired on the
    dialog after it has left the screen, so it does not bubble anywhere.

Events from the widgets inside the dialog (`Activate` of a Button,
`Submit` of a text field, `Change`, ...) bubble through the dialog as
usual, so one listener on the dialog can handle them all.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`backdrop_color` (a color string), `z_index` (an integer from -32768
to 32767) and
`close_on_escape` (`#true` or `#false`).

A Dialog is added to the widget tree only when it opens, and a Dialog
that is a child of another widget cannot open. A layout file has only
one top-level widget, so a Dialog must be the root widget of a layout
file of its own. `build` returns the dialog, which is not open yet.
With this in `about.kdl`:

```kdl
use Term::Fabulous::Widget::Dialog as Dialog
use Term::Fabulous::Widget::Text as Text

Dialog "about" {
        sizing width="fixed(40)"
        backdrop_color "rgba(0, 0, 0, 0.7)"
        Text { text "Term::Fabulous"; text_color "#ffffff"; }
}
```

open the dialog from Perl:

```perl
my $about = Term::Fabulous::Layout->new( file => 'about.kdl' )->build;
$about->open($ui);
```

# SEE ALSO

[Term::Fabulous::Widget::Box](Box.md), [Term::Fabulous::Event::Close](../Event/Close.md),
[Term::Fabulous::Widget::Dialog::Backdrop](Dialog/Backdrop.md),
["FOCUS" in Term::Fabulous::Manual::Events](../Manual/Events.md#focus), ["floating" in Term::Fabulous::Widget](../Widget.md#floating),
["Ask a question in a dialog (Dialog widget)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#ask-a-question-in-a-dialog-dialog-widget),
["A login form (centered dialog, masked password)" in Term::Fabulous::Cookbook::Forms](../Cookbook/Forms.md#a-login-form-centered-dialog-masked-password).
