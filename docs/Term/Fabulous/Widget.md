# NAME

Term::Fabulous::Widget - Abstract base class of the Term::Fabulous
container widgets

# SYNOPSIS

```perl
# Term::Fabulous::Widget is abstract; you use its subclasses:
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Enum::BorderStyle;
use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

my $panel = Term::Fabulous::Widget::Box->new(
        id               => 'panel',
        layout           => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_fit() },
                padding          => { left => 1, right => 1 },
                child_gap        => 1,
        },
        background_color => [ 30, 35, 50, 255 ],
        border_width     => 1,
        border_color     => [ 120, 160, 220, 255 ],
        border_style     => Term::Fabulous::Enum::BorderStyle->Round,
        classes          => ['sidebar'],
);

# Writing a widget class of your own:
use Object::Pad;
class My::Panel :isa(Term::Fabulous::Widget) :strict(params) { }
```

# DESCRIPTION

`Term::Fabulous::Widget` is the common base of every Term::Fabulous
widget that is a rectangle on the screen and can hold other widgets:
[Term::Fabulous::Widget::Box](Widget/Box.md) and everything built on it
([Term::Fabulous::Widget::Button](Widget/Button.md), [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md),
[Term::Fabulous::Widget::Canvas](Widget/Canvas.md), the input widgets, ...).
[Term::Fabulous::Widget::Text](Widget/Text.md) is not one of them: text is a leaf that
always lives inside such a widget.

The class is abstract: `Term::Fabulous::Widget->new` dies. Create a
[Term::Fabulous::Widget::Box](Widget/Box.md) when you need a plain container, or
subclass this class (or Box) for a widget of your own.

This page is the reference for everything these widgets have in common:
the constructor parameters for layout, background, border and ids, and
the methods for children, events and states. Most of it comes from
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI), the widget layer on top of the Clay layout engine, through
the roles this class inherits from [Term::Fabulous::Widget::Element](Widget/Element.md)
and the one it composes itself:

- [Clay::UI::Role::Core::Container](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AContainer): children (`add_child`, ...)
- [Clay::UI::Role::Events::Listener](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AListener) and [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter): events (`on`, `fire_event`)
- [Clay::UI::Role::Layout::HasFloating](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasFloating): the `floating` hash
- [Clay::UI::Role::Layout::HasLayout](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasLayout): the `layout` hash
- [Clay::UI::Role::Layout::HasParent](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasParent): `parent`, `root`, `ui`
- [Clay::UI::Role::Layout::HasSizingGroup](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasSizingGroup): `width_group`, `height_group`
- [Clay::UI::Role::Style::HasBackground](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasBackground): `background_color`
- [Clay::UI::Role::Style::HasBorder](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasBorder): `border_width`, `border_color`
- [Clay::UI::Role::Style::HasStates](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasStates): `add_state`, `states`, ...
- [Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md): the border glyphs (`border_style`, ...)
- [Term::Fabulous::Role::Themed](Role/Themed.md): the colors and border styles the theme supplies (`look`, `reset_look`, ...)

The sections below summarize what you need for everyday use; the role
pages have the full details.

# CONSTRUCTOR

## new

```perl
my $box = Term::Fabulous::Widget::Box->new(%parameters);
```

`new` is called on a concrete subclass. All parameters are optional.
The concrete classes reject unknown parameters: a typo dies with
`Unrecognised parameters for ... constructor`. Widgets are created
empty; add children afterwards with ["add\_child"](#add_child).

- `id`

    A non-empty string. Default: none. Names the widget:
    ["remove\_child\_with\_id"](#remove_child_with_id) removes children by id, listeners can tell widgets apart with
    `$event->target->id`, and Clay keeps state (such as a scroll
    position) for it between frames. ["find\_by\_id"](#find_by_id) finds a widget in a
    tree by its id. Ids must be unique in a widget tree: two widgets with
    the same id make drawing die with a `Clay error`. Ids starting with
    `anon:` are reserved and die. Widgets without an id get one
    generated from their position in the tree.
    [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md) requires an id.

- `layout`

    A hash reference of layout options. Default: `{}`, which sizes the
    widget to fit its content and stacks children from left to right. The
    keys are:

    - `sizing`

        `{ width => $sizing, height => $sizing }`, each built with a
        function from [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS): `sizing_fit($min, $max)` (as big as the
        content, the default), `sizing_grow($min, $max)` (take the space left
        over in the parent), `sizing_fixed($cells)` and
        `sizing_percent($fraction)` (a share of the parent, a number from 0 to
        1; `0.5` is half). A fraction above 1 is accepted by `new` but makes
        drawing die with a `Clay error`. `$min` and `$max` are optional
        limits in cells. Either axis may be
        left out.

    - `padding`

        `{ left => $n, right => $n, top => $n, bottom => $n }`, any
        subset, in cells; `padding_all($n)` from [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) builds one with
        all four sides. The padding lies inside the border (see
        ["Border space" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border-space)).

    - `child_gap`

        The number of empty cells between two neighboring children.

    - `layout_direction`

        `CLAY_LEFT_TO_RIGHT` (the default), `CLAY_TOP_TO_BOTTOM`,
        `CLAY_LEFT_TO_RIGHT_WRAP` (left to right, wrapping onto new lines; see
        ["Flow layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#flow-layout)) or `CLAY_BACK_TO_FRONT` (on top
        of each other; see ["Stack layout" in Term::Fabulous::Manual::Layout](Manual/Layout.md#stack-layout)), constants
        exported by [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS).

    - `line_gap`

        The number of empty rows between two lines of a
        `CLAY_LEFT_TO_RIGHT_WRAP` layout. Default: 0.

    - `line_sizing`

        `CLAY_LINE_SIZING_GROW` (the default) or `CLAY_LINE_SIZING_FIT`,
        constants exported by [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS): whether the lines of a
        `CLAY_LEFT_TO_RIGHT_WRAP` layout share the rows left over below them
        or keep the height of their tallest child.

    - `child_alignment`

        `{ x => $x, y => $y }` with `CLAY_ALIGN_X_LEFT`,
        `CLAY_ALIGN_X_CENTER` or `CLAY_ALIGN_X_RIGHT` and `CLAY_ALIGN_Y_TOP`,
        `CLAY_ALIGN_Y_CENTER` or `CLAY_ALIGN_Y_BOTTOM`. Default: left and top.

    Any other key, or a value of the wrong shape, dies. See
    ["LAYOUT" in Term::Fabulous::Manual::Layout](Manual/Layout.md#layout) for how these work together.

- `floating`

    A hash reference that takes the widget out of its parent's layout and
    draws it on top of the other widgets, positioned against its parent,
    the root or another widget. It takes no space in its parent. Default:
    `undef`, the widget is laid out normally. The keys, all optional, take
    constants exported by [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS):

    - `attach_to`

        What the widget is positioned against: `CLAY_ATTACH_TO_PARENT`,
        `CLAY_ATTACH_TO_ROOT` (the whole screen) or
        `CLAY_ATTACH_TO_ELEMENT_WITH_ID` (the widget named by `parent_id`).
        The default, `CLAY_ATTACH_TO_NONE`, does not make the widget float.

    - `parent_id`

        With `CLAY_ATTACH_TO_ELEMENT_WITH_ID`, the Clay element id number of
        the widget to attach to: `Clay::XS::Clay_GetElementId($id)->{id}`
        for the widget with the id `$id`. That widget does not have to be an
        ancestor.

    - `attach_points`

        `{ element => $point, parent => $point }`: the point of this
        widget that is placed on the point of the widget it is attached to,
        each one of `CLAY_ATTACH_POINT_LEFT_TOP`, `..._LEFT_CENTER`,
        `..._LEFT_BOTTOM`, `..._CENTER_TOP`, `..._CENTER_CENTER`,
        `..._CENTER_BOTTOM`, `..._RIGHT_TOP`, `..._RIGHT_CENTER` and
        `..._RIGHT_BOTTOM`. Default: both `CLAY_ATTACH_POINT_LEFT_TOP`.

    - `offset`

        `{ x => $columns, y => $rows }`, added to the position; negative
        values move left and up.

    - `expand`

        `{ width => $columns, height => $rows }`, enlarges the widget's
        area without changing the space its children get.

    - `z_index`

        An integer from -32768 to 32767. Floating widgets with a higher value
        are drawn on top of those with a lower one.

    - `pointer_capture_mode`

        `CLAY_POINTER_CAPTURE_MODE_CAPTURE` (the default) or
        `CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH`, Clay's pointer setting for
        the widget. Term::Fabulous delivers `Mouse` events to the topmost
        widget painted under the pointer either way.

    - `clip_to`

        `CLAY_CLIP_TO_NONE` (the default) or `CLAY_CLIP_TO_ATTACHED_PARENT`,
        which cuts the widget off at the clipping area (such as a
        [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md)) of the widget it is attached to.

    Any other key, or a value of the wrong shape, dies. See
    [Clay::UI::Role::Layout::HasFloating](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasFloating).

- `background_color`

    The color of the widget's area, in any format
    [Term::Fabulous::Color](Color.md) accepts: an array reference `[r, g, b, a]`
    (or `[r, g, b]`, alpha 255), a hash reference
    `{ r =` ..., g => ..., b => ..., a => ... }>, a string such as
    `'#ff0000'` or `'rgb(255, 0, 0)'`, or a Term::Fabulous::Color
    object. The value is stored as `[r, g, b, a]`, which is what the
    reader returns. Default: none, so the widget's area shows what is
    behind it. An alpha of 0 means no color, 255 is opaque, and 1 to 254 is
    translucent: the color is blended with whatever is below the widget
    (see `glyphs_show_through`). See ["COLORS" in Term::Fabulous::Manual::Looks](Manual/Looks.md#colors).

    A widget with neither a background color nor a border paints nothing,
    so it is also invisible to the mouse: clicks on it go to the widget
    behind it. A widget with only a border receives clicks on its border
    cells.

- `glyphs_show_through`

    Only matters with a translucent `background_color` (alpha 1 to 254).
    False (the default): the widget's area is covered with spaces in the
    blended color, so text and borders below it disappear. True: they stay
    visible through the background, with their colors tinted by it, until
    the widget paints its own content over them. Where the color below is
    the terminal default, which cannot be blended, the background is drawn
    opaque and a glyph's default foreground stays as it is. Any true or
    false value; references die. See
    ["Alpha and the terminal default color" in Term::Fabulous::Manual::Looks](Manual/Looks.md#alpha-and-the-terminal-default-color).

- `border_width`

    The border's thickness: a number for all four sides, or a hash
    reference `{ left => $n, right => $n, top => $n, bottom => $n }`
    (missing sides are 0). Default: no border. In a terminal a drawn border
    is always one cell thick; any positive width draws the side, and the
    width is the space the side takes from the widget, except on a side
    whose style is `Hidden`, which draws nothing and takes no space. Use
    `1`.

- `border_color`

    The color of the border glyphs, in the same formats as
    `background_color`. Default: the terminal's default foreground color.

- `border_style`

    A [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item, such as
    `Term::Fabulous::Enum::BorderStyle->Round`, or its name
    (`'Round'`), used for every side
    that has no side parameter of its own. Default: none; a side that has a
    width but no style is drawn with the `Blank` style (spaces). See
    [Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

- `border_style_top`
- `border_style_right`
- `border_style_bottom`
- `border_style_left`

    The style of one side, a [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item or
    its name. It wins over `border_style` for that side; see
    [Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

- `border_corners`

    `undef` (the default) or a hash reference with any of the keys
    `top_left`, `top_right`, `bottom_left` and `bottom_right`, each a
    glyph drawn at that corner instead of the style's corner glyph, for
    example to join the box to lines around it. See
    ["border\_corners" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_corners).

- `outer_border_sides`

    An array reference of side names (`top`, `right`, `bottom`,
    `left`) whose glyphs are drawn on the background outside the widget
    instead of the widget's own. Default: `[]`. See
    ["outer\_border\_sides" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#outer_border_sides).

- `width_group`
- `height_group`

    An integer from 0 to 1048575. Default: 0 (no group). Widgets anywhere
    in the tree with the same non-zero group number get the same width (or
    height): the largest content size among them. Useful to line up form
    labels. Only `fit` and `grow` sizing take part. See
    [Clay::UI::Role::Layout::HasSizingGroup](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasSizingGroup).

- `classes`

    An array reference of strings. Default: `[]`. Names of your own,
    returned by ["get\_classes"](#get_classes) and ["classes"](#classes). The theme reads them: a
    widget whose classes name a variant of its family draws with that
    variant (see ["Variants and classes" in Term::Fabulous::Manual::Looks](Manual/Looks.md#variants-and-classes)).
    The array is copied; anything but an array of defined, non-reference
    names dies.

The background, the border color and the border style come from the
theme of the UI when they are not given, where the theme has them for
the widget's family (a plain Box has none in the built-in themes; a
Button, a Dialog or a Toast has); see
["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes). Subclasses document the
theme slot each of their colors reads.

# METHODS

The methods fall into four groups: children (`add_child` to `ui`),
events (`on`, `fire_event`, `handlers_for`), layout and style
accessors (`layout` to `height_group`) and states (`add_state` to
`get_classes`).

States: every widget has a set of state names. `hovered`, `pressed`,
`focused` and `disabled` are _derived_ states: they follow the
widget's interaction (for example on a [Term::Fabulous::Widget::Button](Widget/Button.md))
or its `disabled` flag and cannot be set by hand. You may add names of
your own, for example `selected`. See
[Clay::UI::Role::Style::HasStates](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AStyle%3A%3AHasStates).

## add\_child

```perl
$box->add_child($widget);
$box->add_child( $header, $body, $footer );
```

Appends one or more widgets (or [Term::Fabulous::Widget::Text](Widget/Text.md)s) as
children, in order. Returns the widget, so calls chain:
`$root->add_child($a)->add_child($b)`.

A widget has at most one parent at a time. Adding a widget that still
has a parent dies, and so does adding the root of a [Term::Fabulous](../../../README.md)
or a widget to itself or one of its descendants. To move a widget,
remove it from its parent first. See
["add\_child" in Clay::UI::Role::Core::Container](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AContainer#add_child).

## remove\_child

```perl
$box->remove_child($status);
$box->remove_child( $spinner, $label );
```

Removes each given widget that is a direct child of this one (the very
object; widgets without an id and Text widgets included). A widget that
is not a direct child is ignored. Dies, removing nothing, for anything
but a widget, an id included (use ["remove\_child\_with\_id"](#remove_child_with_id)). A removed
widget keeps its children and its state and can be added again. Returns
the widget.

Removing a subtree that holds the focused widget or a hovered widget
fires `OnBlur` or `OnHoverStopped` on it during the call; `OnBlur`
still bubbles through the old parents. When an `OnBlur` listener dies,
the removal is completed first and the error is rethrown afterwards.

## remove\_child\_with\_id

```perl
$box->remove_child_with_id('status');
```

Removes every direct child whose `id` equals the argument. Unknown ids
are ignored. Text widgets are never removed this way, even when they
have an `id` (use ["remove\_child"](#remove_child) or ["remove\_children\_with"](#remove_children_with)).
Returns the widget. Removal works as described in ["remove\_child"](#remove_child).

## remove\_children\_with

```perl
$box->remove_children_with( sub { $_->isa('Term::Fabulous::Widget::Text') } );
```

Removes every direct child for which the code reference returns true.
The child is passed as the argument and in `$_`. Returns the widget.
Removal works as described in ["remove\_child"](#remove_child).

## clear\_children

```perl
$box->clear_children;
```

Removes all children. Returns the widget. Removal works as described
in ["remove\_child"](#remove_child).

## id

```perl
my $id = $widget->id;
```

The `id` given to the constructor, or `undef` when none was given
(the generated id is not returned). There is no writer.

## invalid\_inputs

```perl
if ( my @invalid = $form->invalid_inputs ) {
        $message->text( $invalid[0]->error );
        $ui->interaction->set_focused_widget( $invalid[0] );
        return;
}
```

The input widgets at or below this one, in the same order as
["find\_by\_id"](#find_by_id) walks, whose value is not valid (see
["is\_valid" in Term::Fabulous::Widget::Input](Widget/Input.md#is_valid)): empty while `required`,
or rejected by their `validator`. The widget itself is included when
it is such an input. Returns an empty list when every input is fine,
also when there is none. The tree is walked on every call.

## find\_by\_id

```perl
my $volume = $root->find_by_id('volume');
```

The first widget, in depth-first pre-order, whose `id` equals the
argument: the widget itself, then its first child and that child's
descendants, then the second child, and so on, the order in which the
frame lays them out (["descendants" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#descendants)).
Text widgets with an id are found too, and so are the widgets a widget
keeps below an internal child, such as the items of a
[Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md). Returns `undef` when there is
none. Dies when the argument is `undef`. The tree is walked on every
call; keep the result instead of searching in every event.

## children

```perl
my @kids = @{ $box->children };
```

A new array reference with the direct children, in order. Changing the
array does not change the widget.

## has\_child

```perl
$box->add_child($status) unless $box->has_child($status);
```

1 when the widget is a direct child of this one (the very object), else
0\. Dies for anything but a widget.

## get\_children\_with

```perl
my @buttons = $box->get_children_with( sub { $_->isa('Term::Fabulous::Widget::Button') } );
```

The direct children for which the code reference returns true (as a
list). Does not look at grandchildren.

## descendants

```perl
my @fields = grep { $_->isa('Term::Fabulous::Widget::TextField') } $form->descendants;
```

Every widget below this one, not the widget itself, as a list in the
order the frame lays them out: each child followed by the widgets below
it, including those a widget keeps below an internal child (the items
of a [Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md)). See
["descendants" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#descendants).

## parent

```perl
my $owner = $widget->parent;
```

The widget that contains this one, or `undef` for the root and for
widgets that were never added or were removed.

## root

```perl
my $top = $widget->root;
```

The topmost widget above this one (the widget itself when it has no
parent).

## ui

```perl
my $ui = $widget->ui;
```

The [Term::Fabulous](../../../README.md) (or [Term::Fabulous::Static](Static.md)) object whose tree
contains the widget, or `undef` when it is not part of one. Useful in
listeners, for example `$widget->ui->interaction->set_focused_widget(...)`.

## contains

```perl
return if $popup->contains( $event->target );
```

1 when the argument is this widget or a widget below it, else 0. Dies
for anything but a widget. To ask whether the focus is inside a
widget, use `$widget->ui->interaction->has_focus_within($widget)`.
See ["contains" in Clay::UI::Role::Layout::HasParent](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasParent#contains).

## on

```perl
$widget->on( KeyPress => sub ($event) { ...; return } );
```

Registers a listener: a code reference called with the event object
whenever an event of that name is fired on this widget or bubbles up
to it from a descendant. Several listeners per name are allowed; they
run in the order they were added. Returns the widget. Dies when the
name is empty or the listener is not a code reference.

What the listener returns decides whether the event continues to the
parent: only `Clay::UI::Enum::Result->CONTINUE` lets it go on, any
other value (including a plain `return;`) stops it after this widget.
The other listeners on the same widget still run. A few event types
never bubble, whatever the listeners return.
See ["EVENTS" in Term::Fabulous::Manual::Events](Manual/Events.md#events) for the event names and the rules.

## fire\_event

```perl
$widget->fire_event( Term::Fabulous::Event::Change->new( value => 42 ) );
```

Delivers an event object to this widget's listeners and then up the
parent chain as described in ["on"](#on). An event object can be fired only
once. Term::Fabulous calls this for you; call it yourself for events of
your own or in tests. See [Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter).

## handlers\_for

```perl
my $listeners = $widget->handlers_for('KeyPress');
printf "%d KeyPress listeners\n", scalar @$listeners;
```

A new array reference with the listeners registered on this widget for
an event name, in the order they were added (an empty array reference
when there are none). Changing the array does not change the widget.
Mostly useful in tests.

## layout

```perl
my $layout = $box->layout;
$box->layout( { %{ $box->layout }, child_gap => 2 } );
```

Accessor for the `layout` hash (see ["new"](#new)). Without an argument it
returns a copy of the stored hash; with an argument it replaces the
whole hash and returns a copy of the new one. Changing the returned hash
does not change the widget; write it back. An invalid hash dies like the
constructor parameter. The change shows in the next frame. Copy the old
hash as above to change a single key.

## floating

```perl
my $floating = $popup->floating;
$popup->floating( { %{ $popup->floating // {} }, offset => { x => 4, y => 2 } } );
```

Accessor for the `floating` hash (see ["new"](#new)). Without an argument it
returns a copy of the stored hash (`undef` when none is set); with an
argument it replaces the whole hash and returns a copy of the new one. `undef`
makes the widget part of its parent's layout again. An invalid hash
dies like the constructor parameter. The change shows in the next
frame.

## background\_color

```perl
$box->background_color( [ 60, 90, 140, 255 ] );
$box->background_color('#3c5a8c');
```

Accessor. Without an argument it returns the color in use as
`[r, g, b, a]`: the given one, or the theme's background for the
widget's family (`undef` for a widget whose family has none, such as
a plain Box); with an argument it sets the value, in any format the
constructor parameter accepts, and returns the stored `[r, g, b, a]`.
`undef` removes the given background color (["reset\_look"](#reset_look) does the
same). An invalid value dies like the constructor parameter of the
same name. The change shows in the next frame.

## background\_below

```perl
my $rgba = $widget->background_below;                     # opaque backgrounds only
my $seen = $widget->background_below( translucent => 1 );
```

The color the widget lies on, as a new `[r, g, b, a]`: the
["background\_color"](#background_color) of the widget itself or of its nearest ancestor
that has an opaque one, else the screen background of the
[Term::Fabulous](../../../README.md) object the widget is shown in (the theme's
`background` token, returned with alpha 255 because it is painted
opaque; see ["SCREEN BACKGROUND" in Term::Fabulous::Render](Render.md#screen-background)), else
`undef`: for a widget that is in no UI, in a
[Term::Fabulous::Static](Static.md) (which paints no screen) or under a
`background` token with alpha 0. Widgets that draw on what lies below
them use it: a [Term::Fabulous::Widget::Table](Widget/Table.md) paints the cells that
have no color of their own in it, and a chart mixes its ink from it.

A translucent background (alpha from 1 to 254) lets the colors below
show through, so it is skipped. With `translucent => 1` it counts
as well: that is the color a painter blends a widget's own cells over,
which is how the unset cells of a [Term::Fabulous::Widget::Canvas](Widget/Canvas.md) are
painted. Other options die.

## glyphs\_show\_through

```perl
$box->glyphs_show_through(1);
```

Accessor for the constructor parameter of the same name (0 or 1).
Without an argument it returns the current value; with an argument it
sets the value and returns the new one. The change shows in the next
frame.

## border\_color

```perl
$box->border_color( [ 97, 175, 239, 255 ] );
$box->border_color( Term::Fabulous::Enum::WebColor->SteelBlue );
```

Accessor. Without an argument it returns the color in use as
`[r, g, b, a]`: the given one, or the theme's border color for the
widget's family (`undef` for the terminal's default color, as for a
plain Box); with an argument it sets the value, in any format the
constructor parameter accepts, and returns the stored `[r, g, b, a]`.
`undef` removes the given color (["reset\_look"](#reset_look) does the same). An
invalid value dies like the constructor parameter of the same name.
The change shows in the next frame.

## border\_width

```perl
$box->border_width(1);
```

Accessor. Without an argument it returns the current value (`undef`
when none is set); with an argument it sets the value and returns the
new value. `undef` removes the border. An invalid value dies like the
constructor parameter of the same name. The change shows in the next
frame. Changing it changes the layout, because borders take space.

## border\_style\_top

```perl
$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the top side. The writer takes `undef`
(no style of its own), a [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item or
its name, returns the new value, and anything else dies. The reader
returns the style the side is drawn in: its own, else the theme's (or
one the widget derives), else `Blank`; see
["border\_style\_of" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_style_of). The change
shows in the next frame.
There is no `border_style` accessor; set the sides one by one. See
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

## border\_style\_right

```perl
$box->border_style_right( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the right side. The writer takes `undef`
(no style of its own), a [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item or
its name, returns the new value, and anything else dies. The reader
returns the style the side is drawn in: its own, else the theme's (or
one the widget derives), else `Blank`; see
["border\_style\_of" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_style_of). The change
shows in the next frame.
There is no `border_style` accessor; set the sides one by one. See
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

## border\_style\_bottom

```perl
$box->border_style_bottom( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the bottom side. The writer takes `undef`
(no style of its own), a [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item or
its name, returns the new value, and anything else dies. The reader
returns the style the side is drawn in: its own, else the theme's (or
one the widget derives), else `Blank`; see
["border\_style\_of" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_style_of). The change
shows in the next frame.
There is no `border_style` accessor; set the sides one by one. See
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

## border\_style\_left

```perl
$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Heavy );
```

Accessor for the style of the left side. The writer takes `undef`
(no style of its own), a [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item or
its name, returns the new value, and anything else dies. The reader
returns the style the side is drawn in: its own, else the theme's (or
one the widget derives), else `Blank`; see
["border\_style\_of" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_style_of). The change
shows in the next frame.
There is no `border_style` accessor; set the sides one by one. See
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md).

## border\_corners

```perl
$box->border_corners( { top_left => "\x{251C}" } );
```

Accessor for the corner glyphs; the reader returns a new hash reference
or `undef`. See ["border\_corners" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#border_corners).

## outer\_border\_sides

```perl
$box->outer_border_sides( [ 'left', 'right' ] );
```

Accessor for the sides drawn outside the widget; the reader returns a
new array reference. See
["outer\_border\_sides" in Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md#outer_border_sides).

## width\_group

```perl
$label->width_group(1);
```

Accessor. Without an argument it returns the group number (0 when the
widget is in no group); with an argument it sets it and returns the new
value. An invalid value dies like the constructor parameter. The change
shows in the next frame.

## height\_group

```perl
$row->height_group(2);
```

Accessor for the height group, used like ["width\_group"](#width_group).

## add\_state

```perl
$row->add_state('selected');
```

Adds a state name of your own. Returns the widget. Dies for the
derived states `hovered`, `pressed`, `focused` and `disabled`.

## remove\_state

```perl
$row->remove_state('selected');
```

Removes a state name of your own. Returns the widget. Dies for the
derived states `hovered`, `pressed`, `focused` and `disabled`.

## toggle\_state

```perl
$row->toggle_state('selected');
```

Adds the name when it is missing, removes it otherwise. Returns the
widget. Dies for the derived states `hovered`, `pressed`, `focused`
and `disabled`.

## clear\_states

```perl
$row->clear_states;
```

Removes all state names of your own. The derived states
(`hovered`, `pressed`, `focused`, `disabled`) are not affected. Returns the
widget.

## has\_state

```perl
if ( $row->has_state('selected') ) { ... }
```

True when the state is active, including the derived ones.

## states

```perl
my @active = $row->states;
```

The active state names, in no particular order.

## classes

```perl
my $names = $widget->classes;    # ['sidebar']
$widget->classes( [ 'sidebar', 'primary' ] );
```

Accessor for the `classes` parameter. Without an argument it returns
a copy of the names; with an array reference it replaces them, makes
the widget read its theme looks again and returns a copy of the new
names. An invalid value dies like the constructor parameter. The
change shows in the next frame.

## get\_classes

```perl
my @classes = $widget->get_classes;    # ('sidebar', 'state_focused')
```

The names from the `classes` parameter, followed by `state_NAME` for
every active state (`state_hovered`, `state_selected`, ...). The
theme reads the classes only, not the state names.

## reset\_look

```perl
$button->reset_look('border_color');
$button->reset_look( 'background_color', 'focus_border_color' );
```

Drops the colors or border styles the program gave for the named
parameters, so the theme supplies them again. Takes the names of
the widget's themed parameters (`background_color`, `border_color`
and the ones a subclass lists), including the looks a widget keeps on
its parts (the colors of a [Term::Fabulous::Widget::Tabs](Widget/Tabs.md) live on its
bar, the scrollbar colors of a [Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md) on
both scrollbars); an unknown name dies naming the known ones. Returns
the widget. The change shows in the next frame. From
[Term::Fabulous::Role::Themed](Role/Themed.md), which also has [look](Role/Themed.md#look)
and [look\_value](Role/Themed.md#look_value) for widget
authors.

## mark\_changed

```perl
$widget->mark_changed;
```

For widget authors: tells Term::Fabulous that the widget has changed in
a way its accessors do not know about (state of your own that the
widget draws), so that the next frame is drawn. The built-in accessors
call it themselves. Returns the widget. See
["mark\_changed" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#mark_changed) and
[Term::Fabulous::Manual::CustomWidgets](Manual/CustomWidgets.md).

## tree\_changed

```perl
class My::Counter :isa(Term::Fabulous::Widget::Box) {
        field $clicks = 0;

        method tree_changed :override () {
                $self->SUPER::tree_changed;
                $clicks = 0;    # counts again from its new place
                return;
        }
}
```

For widget authors: Clay::UI calls it on every widget of a subtree
that joined a tree, left one or became the root of a UI, once the
change is complete (see
["tree\_changed" in Clay::UI::Role::Layout::HasParent](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasParent#tree_changed)). Here the widget
forgets the looks it fetched, since its new place may be in a UI with
another theme, and when that place is in a UI, calls
[looks\_changed](Role/Themed.md#looks_changed) with all
its looks. An override calls `$self->SUPER::tree_changed` first,
as [Term::Fabulous::Widget::VirtualList](Widget/VirtualList.md) does to rebuild its items for
the new place.

## reverse\_video

```perl
my $swapped = $widget->reverse_video;    # 0
```

For widget authors: whether the renderer swaps the foreground and
background colors of every cell the widget and its children paint.
Always 0 here; [Term::Fabulous::Widget::Button](Widget/Button.md) returns 1 while it is
pressed with `pressed_background_color => 'reverse'`. Override it in
a widget class of your own for the same effect.

# EVENTS

The class fires no events of its own. Every widget receives the events
fired on its descendants, because events bubble up the tree (see
["on"](#on)), and [Term::Fabulous](../../../README.md) fires these on any widget:

- `Mouse` ([Term::Fabulous::Event::Mouse](Event/Mouse.md))

    On the topmost widget painted under the pointer, for clicks and wheel
    notches. A widget paints its whole area when it has a background color
    and only its border cells when it has a border but no background; a
    widget with neither is transparent to the mouse.

- `KeyPress` ([Term::Fabulous::Event::KeyPress](Event/KeyPress.md))

    On the root widget when no widget has the focus.

Subclasses add their own events, such as `Activate` on a
[Term::Fabulous::Widget::Button](Widget/Button.md) and `OnScroll` on a
[Term::Fabulous::Widget::ScrollBox](Widget/ScrollBox.md).
[The event reference of the events guide](Manual/Events.md#event-reference)
lists them all.

# SEE ALSO

[Term::Fabulous::Widget::Box](Widget/Box.md),
["LAYOUT" in Term::Fabulous::Manual::Layout](Manual/Layout.md#layout) (the layout options with
pictures), ["EVENTS" in Term::Fabulous::Manual::Events](Manual/Events.md#events),
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI),
["Line up labels with equal widths (width\_group)" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#line-up-labels-with-equal-widths-width_group),
["Use a different border style on each side" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#use-a-different-border-style-on-each-side),
["Mark widgets with states and classes" in Term::Fabulous::Cookbook::Layout](Cookbook/Layout.md#mark-widgets-with-states-and-classes).
