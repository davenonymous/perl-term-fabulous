# NAME

Term::Fabulous::Widget::ScrollBox - A box whose content scrolls

# SYNOPSIS

```perl
use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM);
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

my $log = Term::Fabulous::Widget::ScrollBox->new(
        id               => 'log',                  # required
        layout           => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_fixed(10) },
                padding          => { left => 1, right => 1 },
        },
        background_color => [ 30, 35, 50, 255 ],
        border_width     => 1,
        border_color     => [ 120, 160, 220, 255 ],
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
);
$log->add_child( Term::Fabulous::Widget::Text->new( text => "Line $_", text_color => [ 220, 220, 220, 255 ] ) )
        foreach 1 .. 100;

$log->on( OnScroll => sub ($event) {
        printf STDERR "scrolled by %d rows\n", $event->delta_y;
        return;
} );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-scroll-box.svg" alt="Two framed boxes scrolled down, one with numbered lines, one with squares, each with a scrollbar in its last column whose thumb shows the visible part"></p>
</div>

# DESCRIPTION

A ScrollBox is a [Term::Fabulous::Widget::Box](Box.md) for content that is
larger than the box: everything that does not fit is clipped, and the
user scrolls through it with the mouse wheel or with the scrollbars.
Typical uses are logs, long lists and help texts.

A vertical scrollbar (a [Term::Fabulous::Widget::Scrollbar](Scrollbar.md)) takes the
last column inside the border, and a horizontal one the last row when
the box scrolls sideways; the content keeps clear of them. While the
content fits, a scrollbar is empty but keeps its column or row, so the
content does not jump when it starts to scroll. A click on a scrollbar
scrolls so that the thumb is centered under the pointer, and dragging
with the left button keeps doing so. `scrollbar => 0` removes the
scrollbars and gives their cells back to the content.

The size of a ScrollBox comes from its own `sizing`, not from its
content, so give it a `fixed`, `grow` or `percent` height (and
width, when it scrolls sideways). With the default `fit` sizing the
box grows with its content instead of scrolling it.

Under [Term::Fabulous](../../../../README.md), every notch of the mouse wheel scrolls the
ScrollBox under the pointer by three rows, and every notch of a
horizontal wheel (or a sideways tilt of the wheel) by three columns,
unless a widget under the pointer used the notch to scroll itself (see
["CAVEATS"](#caveats)). The scroll position is
clamped, so the content cannot be scrolled past its first or last row.
The position is applied when the next frame is drawn. Keys do not
scroll a ScrollBox.

The content is clipped to the whole box, border included: scrolled
content passes under the border, which is drawn on top of it. Content
scrolled out of view receives no mouse events.

# CONSTRUCTOR

## new

```perl
my $box = Term::Fabulous::Widget::ScrollBox->new( id => 'log', %parameters );
```

Unknown parameters die. A ScrollBox takes every parameter of
[Term::Fabulous::Widget::Box](Box.md) (see ["new" in Term::Fabulous::Widget](../Widget.md#new)) plus:

- `id`

    A non-empty string, unique in the widget tree. **Required**: without it
    the constructor dies, because the scroll position is stored by id from
    one frame to the next.

- `vertical`

    A boolean, stored as 1 or 0. Default: 1. Whether the content scrolls
    up and down.

- `horizontal`

    A boolean, stored as 1 or 0. Default: 0. Whether the content scrolls
    sideways, with a horizontal wheel or with `child_offset`.

- `child_offset`

    `undef` or a hash reference `{ x => $columns, y => $rows }`.
    Default: `undef`, which lets the mouse wheel control the position.
    A hash takes over: the content is drawn shifted by that many cells, and
    the wheel no longer moves it. Negative values move the content up and
    left, so `{ x => 0, y => -3 }` shows the content from its fourth
    row on. Set it back to `undef` to give control back to the wheel. The wheel
    keeps moving the hidden scroll position while `child_offset` is set,
    so the content may jump when you set it back to `undef`.

- `scrollbar`

    A boolean, stored as 1 or 0. Default: 1. Whether the scrollbars are
    shown: a vertical one while `vertical` is true, a horizontal one while
    `horizontal` is true. Each takes one column or row inside the border
    from the content.

- `track_color`

    The color of the scrollbars' track, anything [Term::Fabulous::Color](../Color.md)
    understands. Default: the scrollbar's dark grey, `[ 70, 76, 90, 255 ]`.

- `thumb_color`

    The color of the scrollbars' thumb. Default: the scrollbar's light blue,
    `[ 97, 175, 239, 255 ]`.

# METHODS

To read or set the scroll position of a ScrollBox from your program, for
example to keep a log at its newest line, call the methods
[scroll\_state and scroll\_to](../../../../README.md#bounding_box-scroll_state-scroll_to)
of the application object with the box. The recipe
[Scroll a ScrollBox from code](../Cookbook/LiveData.md#scroll-a-scrollbox-from-code-keep-a-log-at-the-newest-line)
shows them in a complete program.

A ScrollBox has all methods of [Term::Fabulous::Widget](../Widget.md) plus these
accessors (from [Clay::UI::Role::Layout::HasScroll](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasScroll)):

## vertical

```perl
$box->vertical(0);
```

Accessor. Without an argument it returns the stored value, 1 or 0;
with an argument it stores any true or false value as 1 or 0 and
returns it. References die.
The change shows in the next frame.

## horizontal

```perl
$box->horizontal(1);
```

Accessor for `horizontal`, used like ["vertical"](#vertical).

## child\_offset

```perl
$box->child_offset( { x => 0, y => -20 } );    # show from row 21 on
$box->child_offset(undef);                      # back to the wheel
```

Accessor. Without an argument it returns the hash reference, or
`undef` while the wheel controls the position; with an argument it
sets it and returns the new value. An invalid value dies like the
constructor parameter. The change shows in the next frame.

## scrollbar

```perl
$box->scrollbar(0);
```

Accessor for `scrollbar`, used like ["vertical"](#vertical). Switching the
scrollbars off gives their cells back to the content in the next frame.

## track\_color, thumb\_color

```perl
$box->track_color('#464c5a');
$box->thumb_color( [ 97, 175, 239, 255 ] );
```

Accessors for the scrollbar colors. Without an argument they return the
color as `[r, g, b, a]`; with one they set it on both scrollbars and
return it. An invalid color dies and leaves the old one.

## children

```perl
my @lines = @{ $box->children };
```

The children you added, as on any [Term::Fabulous::Widget::Box](Box.md). The
scrollbars are not among them, and `clear_children` and the other
removal methods leave them alone.

# EVENTS

- `OnScroll` ([Clay::UI::Events::OnScroll](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AOnScroll))

    Fired on the ScrollBox in every frame in which its scroll position
    changed. `$event->delta_y` is how far the content moved, in rows:
    negative when the user scrolled down (the content moved up), positive
    when scrolled up. `$event->delta_x` is the same for columns.
    While `child_offset` is set, `OnScroll` still reports the movement of
    the hidden scroll position that the wheel moves, even though the
    content does not move.

- `Mouse` ([Term::Fabulous::Event::Mouse](../Event/Mouse.md))

    Fired for wheel notches and clicks over the box, like on any Box (see
    ["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse)). The scrolling does not depend on what
    your listeners return: a listener that stops the event from bubbling
    does not stop the scrolling. Only a call to
    ["use\_wheel" in Term::Fabulous::Event::Mouse](../Event/Mouse.md#use_wheel) keeps a notch from scrolling
    the box.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`horizontal`, `vertical` and `scrollbar` (`#true` or `#false`) and
the colors `track_color` and `thumb_color`. The node needs an id
argument:

```kdl
ScrollBox "log" {
        layout direction=down
        sizing width=grow height="fixed(10)"
        vertical #true
        thumb_color "#61afef"
}
```

`child_offset` cannot be set from KDL.

# CAVEATS

A widget inside a ScrollBox that uses the mouse wheel itself (a
[Term::Fabulous::Widget::TextArea](TextArea.md), a [Term::Fabulous::Widget::Slider](Slider.md),
an open [Term::Fabulous::Widget::Dropdown](Dropdown.md) list) takes the notches
over it while it can move, and the ScrollBox stays put; once the widget
is at its end, the notches scroll the ScrollBox again. So a long form
scrolls past a text area as soon as the text area shows its last rows.

The scrollbars are drawn over the box, inside its border, after the
content. Content that scrolls sideways passes under the vertical
scrollbar's column; while there is nothing to scroll down, that column
is empty and shows the content beneath.

# SEE ALSO

["SCROLLING" in Term::Fabulous::Manual::Events](../Manual/Events.md#scrolling),
["Scroll a ScrollBox from code (keep a log at the newest line)" in Term::Fabulous::Cookbook::LiveData](../Cookbook/LiveData.md#scroll-a-scrollbox-from-code-keep-a-log-at-the-newest-line),
[Term::Fabulous::Widget::Scrollbar](Scrollbar.md), [Term::Fabulous::Widget::Box](Box.md),
[Clay::UI::Role::Layout::HasScroll](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasScroll), the example program
`examples/scroll-box.pl`.
