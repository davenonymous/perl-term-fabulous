# NAME

Term::Fabulous::Widget::Scrollbar - A scrollbar for a scroll container

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Scrollbar;

my $bar = Term::Fabulous::Widget::Scrollbar->new(
        follows     => $scroll_box,
        axis        => 'vertical',
        track_color => [ 70, 76, 90, 255 ],
        thumb_color => [ 97, 175, 239, 255 ],
        layout      => { sizing => { width => sizing_fixed(1), height => sizing_grow() } },
);
```

# DESCRIPTION

A [Term::Fabulous::Widget::Canvas](Canvas.md) one cell thick that shows how far a
scroll container (a widget with [Clay::UI::Role::Layout::HasScroll](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasScroll),
such as a [Term::Fabulous::Widget::ScrollBox](ScrollBox.md)) is scrolled along one
axis. While the content is larger than the container along that axis,
it draws a track (a thin line) with a thumb (a heavy line) whose length
and place show which part of the content is visible; otherwise it is
empty. A vertical scrollbar paints its first column with U+2502 and
U+2503, a horizontal one its first row with U+2500 and U+2501. It
paints from the scroll state of the frame being drawn, so it is always
up to date, and it paints again only when the thumb moved. A scrollbar
for an axis its container does not scroll along (`vertical` or
`horizontal` of the container is false) is laid out zero cells thick
and takes no space.

A left click on the scrollbar scrolls the container so that the thumb
is centered under the pointer, and dragging with the left button keeps
doing so (see ["position\_at"](#position_at)). The container must have been laid out
with the scrollbar in the same [Term::Fabulous](../../../../README.md); the scrollbar is
empty before the first frame.

[Term::Fabulous::Widget::ScrollBox](ScrollBox.md) makes its own scrollbars, inside
its border, and [Term::Fabulous::Widget::Table](Table.md) shows one right of its
body. Make one yourself to put a scrollbar somewhere else: give it a
`fixed(1)` width and a `grow` height (or the other way round for a
horizontal one) and place it next to the container.

# CONSTRUCTOR

## new

```perl
my $bar = Term::Fabulous::Widget::Scrollbar->new( follows => $box, %parameters );
```

Unknown parameters die. A Scrollbar takes every parameter of
[Term::Fabulous::Widget::Canvas](Canvas.md) plus:

- `follows`

    **Required**. The scroll container whose position the scrollbar shows,
    held weakly. Dies unless it does [Clay::UI::Role::Layout::HasScroll](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasScroll).

- `axis`

    `'vertical'` (the default) or `'horizontal'`; anything else dies.

- `track_color`

    The color of the track. Default: a dark grey, `[ 70, 76, 90, 255 ]`.
    Takes anything a canvas cell takes (see
    ["put" in Term::Fabulous::Widget::Canvas](Canvas.md#put)).

- `thumb_color`

    The color of the thumb. Default: a light blue, `[ 97, 175, 239, 255 ]`.

# METHODS

A Scrollbar has all methods of [Term::Fabulous::Widget::Canvas](Canvas.md) plus:

## axis

```perl
my $axis = $bar->axis;
```

Returns `'vertical'` or `'horizontal'`. Read-only.

## track\_color

```perl
$bar->track_color('#464c5a');
```

Accessor for the `track_color` parameter. Writing marks the scrollbar
changed and returns the new color as `[r, g, b, a]`. An invalid color
dies and leaves the old one.

## thumb\_color

```perl
$bar->thumb_color('#61afef');
```

Accessor for the `thumb_color` parameter, as ["track\_color"](#track_color).

## position\_at

```perl
my $position = $bar->position_at($cell);
```

The scroll position along the axis (Clay's, 0 or negative; see
["bounding\_box, scroll\_state, scroll\_to" in Term::Fabulous](../../../../README.md#bounding_box-scroll_state-scroll_to)) that centers
the thumb on a cell of the track, counted from the top or the left, or
`undef` when there is nothing to scroll. A click on the scrollbar
scrolls to this position.

# EVENTS

- `Mouse` ([Term::Fabulous::Event::Mouse](../Event/Mouse.md))

    A left press or a drag with the left button scrolls the container and
    stops the event; other mouse events bubble on. Your own listeners run
    after the scrollbar's.

# SEE ALSO

[Term::Fabulous::Widget::ScrollBox](ScrollBox.md), [Term::Fabulous::Widget::Table](Table.md),
["SCROLLING" in Term::Fabulous::Manual::Events](../Manual/Events.md#scrolling).
