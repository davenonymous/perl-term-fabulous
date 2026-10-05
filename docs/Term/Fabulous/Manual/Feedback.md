# NAME

Term::Fabulous::Manual::Feedback - Progress bars, spinners and toasts

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Forms](Forms.md). Next page: [Term::Fabulous::Manual::Charts](Charts.md).

This page covers the widgets that tell the user what the program is
doing: a [progress bar](#progress-bars) for a task whose extent is
known, or not, a [spinner](#spinners) for one that just takes a
while, and [toasts](#toasts-and-alerts) for messages that must not
interrupt the user. They take no input; the program sets their state,
from a timer, a process or a listener, and they draw themselves. The
ones that move do so on the application's clock, without a timer of
their own (see ["ANIMATION"](#animation)).

The reference pages are the class pages: [Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md),
[Term::Fabulous::Widget::Spinner](../Widget/Spinner.md) and [Term::Fabulous::Widget::Toast](../Widget/Toast.md).
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

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Forms](Forms.md). Next page: [Term::Fabulous::Manual::Charts](Charts.md).

The class pages: [Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md),
[Term::Fabulous::Widget::Spinner](../Widget/Spinner.md), [Term::Fabulous::Widget::Toast](../Widget/Toast.md),
[Term::Fabulous::Widget::Display](../Widget/Display.md).
["Timers and other asynchronous work" in Term::Fabulous::Manual::Programs](Programs.md#timers-and-other-asynchronous-work)
for the timers that drive a bar, and
[Term::Fabulous::Cookbook::LiveData](../Cookbook/LiveData.md) for complete programs that update
the screen while they work.
