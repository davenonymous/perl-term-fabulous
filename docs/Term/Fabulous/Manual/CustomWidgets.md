# NAME

Term::Fabulous::Manual::CustomWidgets - Writing your own widgets

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Programs](Programs.md). Next page: [Term::Fabulous::Manual::Troubleshooting](Troubleshooting.md).

This page explains how to write widget classes of your own: a container
with a fixed structure (derived from Box), a widget that draws itself
(derived from Display), an input widget (derived from Input) and a box
that takes the focus and reacts to the mouse (a Box with the Clay::UI
interaction roles). It lists the methods each base class lets you
override, explains how a widget tells Term::Fabulous that it must be
drawn again, and shows how to fire events of your own, how to make a
widget usable from KDL layout files and how to test it.

Complete programs are in the cookbook, on
[Term::Fabulous::Cookbook::Extending](../Cookbook/Extending.md):
[a custom input widget](../Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch),
[a widget usable from KDL](../Cookbook/Extending.md#make-a-widget-usable-from-kdl)
and [events of your own](../Cookbook/Extending.md#fire-your-own-events).

# WRITING YOUR OWN WIDGETS

Your own widgets are classes derived from one of the Term::Fabulous
widget classes. Choose the base class by what the widget does:

- [Term::Fabulous::Widget::Box](../Widget/Box.md)

    for a container with a fixed structure or a fixed look, for example a
    "card" with a title and a body. Build the children in `ADJUST`. See
    ["A container widget"](#a-container-widget).

- [Term::Fabulous::Widget::Display](../Widget/Display.md)

    for a widget that draws itself cell by cell from its own state, such as
    a gauge, a meter or a game board; the built-in
    [Term::Fabulous::Widget::Divider](../Widget/Divider.md) is one. See
    ["A widget that draws itself"](#a-widget-that-draws-itself).

- [Term::Fabulous::Widget::Input](../Widget/Input.md)

    for an interactive widget that edits a value: you get focus handling,
    the four colors, the disabled state, `Change` events and painting at
    the right time. See ["An input widget"](#an-input-widget).

- A Box with the Clay::UI interaction roles

    for a container that takes the focus or reacts to hover and clicks,
    like [Term::Fabulous::Widget::Button](../Widget/Button.md). See
    ["A box that takes the focus and reacts to the mouse"](#a-box-that-takes-the-focus-and-reacts-to-the-mouse).

- Any built-in widget

    to change one detail of it, for example which keys a
    [Term::Fabulous::Widget::TextField](../Widget/TextField.md) uses: override its `handle_key`
    (see ["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Input](../Widget/Input.md#subclass-interface)).

## Object::Pad in brief

Term::Fabulous classes are written with [Object::Pad](https://metacpan.org/pod/Object%3A%3APad), a module that
adds class syntax to Perl. Your classes must use it too, since only an
Object::Pad class can derive from another one. The parts used on this
page:

- `use Object::Pad 0.825;`

    loads the class syntax. Term::Fabulous needs version 0.825 or later.

- `class My::Card :isa(Parent) :strict(params) { ... }`

    declares a class derived from `Parent`. `:strict(params)` makes `new`
    die on unknown parameters, as all Term::Fabulous classes do.
    `:does(Role)` composes a role, a set of methods and fields shared by
    several classes.

- `field $title :param;`

    declares an instance variable, set from the constructor parameter of
    the same name (`My::Card->new( title => 'x' )`). Without a default
    (`field $title :param = 'Untitled';`) the parameter is required.
    `:reader` adds a method that returns the field.

- `ADJUST { ... }`

    runs during construction, after the fields are set; `$self` is the new
    object.

- `method name (...) { ... }`

    declares a method; `$self` is available inside. `:override` marks a
    method that replaces one of the parent class (Object::Pad then checks
    that the parent has it), `:common` a class method, in which `$class`
    is available instead of `$self`.

## A container widget

Derive from [Term::Fabulous::Widget::Box](../Widget/Box.md) and build the children in
`ADJUST`. The widget takes every parameter of a Box (`layout`,
`background_color`, ...), and its users can still add children of
their own:

```perl
use Object::Pad 0.825;

class My::Card :isa(Term::Fabulous::Widget::Box) :strict(params) {
        use Clay::XS qw(CLAY_TOP_TO_BOTTOM);
        use Term::Fabulous::Enum::BorderStyle;
        use Term::Fabulous::Widget::Text;

        field $title :param;

        ADJUST {
                $self->layout( { %{ $self->layout }, layout_direction => CLAY_TOP_TO_BOTTOM } );
                $self->border_width(1);
                $self->border_color( [ 120, 170, 255, 255 ] );
                $self->$_( Term::Fabulous::Enum::BorderStyle->Solid ) foreach qw(border_style_right border_style_bottom border_style_left);
                $self->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );
                $self->add_child( Term::Fabulous::Widget::Text->new( text => $title, text_color => [ 255, 220, 120, 255 ] ) );
        }
}

my $card = My::Card->new( title => 'Status' );
$card->add_child( Term::Fabulous::Widget::Text->new( text => 'All systems go', text_color => [ 220, 220, 220, 255 ] ) );
```

The card draws a heavy line on top and thin lines on the other sides:

```text
┏━━━━━━━━━━━━━━┓
│Status        │
│All systems go│
└──────────────┘
```

The accessors a Box inherits (`layout`, `border_width`, ...) record
the change themselves, so the next frame shows it. A container whose
look depends on fields of its own must say so when they change; see
["Telling Term::Fabulous that something changed"](#telling-term-fabulous-that-something-changed).

## A widget that draws itself

Derive from [Term::Fabulous::Widget::Display](../Widget/Display.md) for a widget that draws
cells from its own state. The layout decides the size of the widget;
its buffer has 0 x 0 cells until the first frame lays it out (see
["Buffer size" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#buffer-size)). So do not draw in the
constructor or in the setters: the setters record the new state and
call `mark_changed`, and the base class calls your `paint` while the
frame is drawn, after the buffer got its size, and only when something
`paint` depends on changed (the size, the state marked changed, and
whatever [`paint_key`](../Widget/Display.md#paint_key)
adds). `natural_size` says how big the widget wants to be when the
layout does not size it:

```perl
use Object::Pad 0.825;

class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
        field $fraction :param = 0;

        method fraction (@new) {
                return $fraction unless @new;
                $fraction = $new[0];
                $self->mark_changed;    # a frame is due, and it paints
                return $fraction;
        }

        method natural_size () { return ( 20, 1 ) }    # columns, rows

        method paint () {
                my $filled = int( $self->columns * $fraction + 0.5 );
                $self->fill_attrs( 0,       0, $filled,                  "\x{2588}", $self->color_attr(0x61AFEF), undef );
                $self->fill_attrs( $filled, 0, $self->columns - $filled, "\x{2591}", $self->color_attr(0x3A3F4B), undef );
                return;
        }
}

my $gauge = My::Gauge->new( fraction => 0.25 );
$gauge->fraction(0.5);    # from a timer, a listener, ...
```

Paint with `put_attrs` (["put\_attrs" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#put_attrs))
and the helpers `paint_text`, `fill_attrs` and `color_attr` of
["SUBCLASS INTERFACE" in Term::Fabulous::Widget::Display](../Widget/Display.md#subclass-interface), which take
termbox2 attributes instead of colors and skip the color conversions.
Cells written in `paint` belong to the frame being drawn and make no
further frame due. The widget receives `Mouse` events for all its
cells; the method [`cell_at`](../Widget/Canvas.md#cell_at)
turns their position into a cell of the buffer.

A widget that draws with the plain canvas methods (`put`, `put_text`,
`fill`, `clear`; see ["METHODS" in Term::Fabulous::Widget::Canvas](../Widget/Canvas.md#methods)) can
derive from [Term::Fabulous::Widget::Canvas](../Widget/Canvas.md) directly and override
[refresh](../Widget/Canvas.md#refresh), which the renderer
calls for every canvas in every frame; it must then decide itself
whether anything changed since it last drew.

A canvas that is drawn from outside instead, by a listener for its
`CanvasResize` event ([Term::Fabulous::Event::CanvasResize](../Event/CanvasResize.md)), needs
no class of its own; see ["CANVASES" in Term::Fabulous::Manual::Charts](Charts.md#canvases).

## An input widget

Derive from [Term::Fabulous::Widget::Input](../Widget/Input.md) for a widget that the user
edits, like the built-in check box or slider. The base class takes the
focus, follows Tab, shows the focus and the disabled state, ignores
input while disabled, keeps the colors `text_color`,
`disabled_color`, `accent_color` and `focus_background_color`, and
calls your methods at the right time. These are the methods you write;
the [subclass interface of Input](../Widget/Input.md#subclass-interface)
describes each of them and the painting helpers in detail:

- `natural_size` (required)

    Returns the columns and rows of content the widget needs when the
    layout does not size it.

- `paint` (required)

    Draws the widget into its cleared buffer. It is called while a frame is
    drawn, only when something it depends on changed: the size, the focus,
    the disabled state, or anything you marked with `mark_changed`.

- `paint_key`

    The list of values `paint` depends on. Extend it when `paint` reads
    the state of other objects, which do not mark your widget changed.

- `handle_key`, `handle_mouse`

    Receive the `KeyPress` and `Mouse` events of the widget while it is
    enabled. Return true for an event the widget used: it then stops
    bubbling. Return false to let it go on to the ancestors, where
    application shortcuts can see it.

- `activate`

    Called for a click: the left mouse button pressed and released over
    the widget.

- `focus_changed`

    Called after the widget got or lost the focus, for what it does then
    besides painting.

- `accepts_focus`

    Returns 0 for a widget that never takes the focus itself.

- `layout_properties`

    The properties a KDL layout may set; see ["Using your widget in KDL"](#using-your-widget-in-kdl).

Call `$self->fire_change($value)` after the user changed the value,
never when your program set it, so that `Change` means the same for
your widget as for the built-in ones (see
[Term::Fabulous::Event::Change](../Event/Change.md)).

The complete example, a toggle switch with keys, clicks, `Change`
events and KDL support, is the recipe
[Write a custom input widget](../Cookbook/Extending.md#write-a-custom-input-widget-a-toggle-switch).

## A box that takes the focus and reacts to the mouse

The focus, hover and press states come from roles of [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).
Compose them into a Box to make a container interactive:

- [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable)

    The widget can take the keyboard focus: Tab stops at it, a left click
    on a cell it paints focuses it, it receives `KeyPress`, `OnFocus` and
    `OnBlur`, and it gets `can_focus` and `is_focused`. Override
    `accepts_focus` to return 0 for a class that should never take the
    focus.

- [Clay::UI::Role::Interaction::Hoverable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AHoverable)

    The widget gets `is_hovered` and the `OnHoverStart` and
    `OnHoverStopped` events.

- [Clay::UI::Role::Interaction::Pressable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3APressable)

    Includes Hoverable. The widget gets `is_pressed` and the `OnPress`
    and `OnRelease` events for the left mouse button.

- [Clay::UI::Role::Interaction::Disableable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3ADisableable)

    The widget gets `disabled` and `is_enabled`. A disabled widget
    cannot take the focus and is not pressed.

The events are described in the
[event reference](Events.md#event-reference).
The look comes from a _contributor_: a method whose name starts with
`contribute_`. Clay::UI calls all of them when it builds the widget's
configuration for a frame, in alphabetical order of their names, so a
name after `contribute_background` and `contribute_border` can change
what those set (see ["to\_config" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#to_config)). A
change of the focus, hover or press state makes the next frame due by
itself.

This tile turns lighter while the pointer is over it, lighter still
while it has the focus, and fires `Activate` for a click or `Enter`,
like a Button:

```perl
use Object::Pad 0.825;
use Clay::UI::Role::Interaction::Focusable;
use Clay::UI::Role::Interaction::Pressable;

class My::Tile
        :isa(Term::Fabulous::Widget::Box)
        :does(Clay::UI::Role::Interaction::Focusable)
        :does(Clay::UI::Role::Interaction::Pressable)
        :strict(params)
{
        use Clay::UI::Enum::Result;
        use Scalar::Util qw(refaddr weaken);
        use Term::Fabulous::Event::Activate;

        ADJUST {
                weaken( my $weak_self = $self );    # a listener must not keep its widget alive
                $self->on(
                        OnRelease => sub ($event) {
                                $weak_self->activate if refaddr( $event->target ) == refaddr($weak_self);
                                return Clay::UI::Enum::Result->CONTINUE;
                        }
                );
                $self->on(
                        KeyPress => sub ($event) {
                                return Clay::UI::Enum::Result->CONTINUE unless ( $event->main_key_name // '' ) eq 'Enter';
                                $weak_self->activate;
                                return;    # used: stop here
                        }
                );
        }

        method activate () {
                return $self->fire_event( Term::Fabulous::Event::Activate->new );
        }

        # Sorts after contribute_background, so it overrides the background.
        method contribute_tile_look ($config) {
                $config->{background_color} = [ 60, 90, 160, 255 ]  if $self->is_hovered;
                $config->{background_color} = [ 90, 130, 210, 255 ] if $self->is_focused;
                return;
        }
}

my $tile = My::Tile->new( background_color => [ 40, 45, 60, 255 ] );
$tile->on( Activate => sub ($event) { open_details(); return } );
```

The listeners check `$event->target`, because events of the
children bubble through the widget too. They hold a weak reference to
the widget: a listener that refers to its own widget directly keeps it
alive forever.

Two more methods change how Term::Fabulous draws a widget and its
children. [Term::Fabulous::Widget::Button](../Widget/Button.md) uses both:

- `reverse_video`

    Every [Term::Fabulous::Widget](../Widget.md) has it; it returns 0. While it returns
    1, the renderer draws the widget's cells with the foreground and
    background colors swapped, its children included. Override it to show
    a state:
    `method reverse_video :override () { return $self->is_pressed ? 1 : 0 }`.

- `disabled_text_color`

    Not defined by default. A [Term::Fabulous::Widget::Text](../Widget/Text.md) asks its
    nearest ancestor that has this method for a color and, when that
    returns one, draws its text in it instead of its own `text_color`.
    Return a color while the widget is disabled and `undef` otherwise, to
    gray out the labels inside it.

## Telling Term::Fabulous that something changed

Term::Fabulous draws a frame only when something changed. A widget that
keeps state of its own, which its drawing or its size depends on, must
say so whenever that state changes: it calls `$self->mark_changed`
(see ["mark\_changed" in Clay::UI::Role::Core::Element](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ACore%3A%3AElement#mark_changed)) in every setter of
that state. Otherwise a change made from a timer shows only when
something else causes a frame.

- The accessors of the base classes (`layout`, `background_color`,
`text`, ...) call it themselves.
- The drawing methods of a Canvas (`put`, `fill`, `clear`, ...) call
it, except while `refresh` runs.
- A Display (and so an Input) does not paint in its setters: they call
`mark_changed`, and the frame that it makes due calls `paint` (see
["Painting" in Term::Fabulous::Widget::Display](../Widget/Display.md#painting)).

## Events of your own

A widget can tell its users what happened with an event of its own,
fired with `fire_event`, for example a `Progress` event or a
`Selected` event with the chosen item. Such events bubble like the
built-in ones. See
[firing your own events](Events.md#firing-your-own-events)
and the recipe
[Fire your own events](../Cookbook/Extending.md#fire-your-own-events).

## Using your widget in KDL

A widget class can be used in KDL layout files once it composes
[Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md); classes derived from Box
already do. The class method `layout_properties` declares the
properties a layout may set and how each is read: `'scalar'`,
`'boolean'`, `'color'`, or a code reference for a property with a
structure of its own. Keep the inherited properties:

```perl
method layout_properties :common () {
        return ( $class->SUPER::layout_properties, title => 'scalar', collapsed => 'boolean', accent => 'color' );
}
```

A layout applies each property after the widget was constructed,
through the accessor of the same name (`$widget->title('...')`),
so every property needs an accessor that reads and writes, and checks
the value as it does for a program. A layout builds every widget with
`new( id => ... )` alone, so a class with a required parameter (a
`:param` field without a default) cannot be used in a layout; give
every field a default.

[Term::Fabulous::Layout](../Layout.md) loads the classes a layout names with
`require`. A class in its own `.pm` file in `@INC` needs nothing
more; a class defined inside the program needs a line such as
`$INC{'My/ToggleSwitch.pm'} = __FILE__;` before the layout is built.

The method
[`layout_properties`](../Role/CanParseLayout.md#layout_properties)
of [Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md) has the details and the
helpers for structured properties, and the recipe
[Make a widget usable from KDL](../Cookbook/Extending.md#make-a-widget-usable-from-kdl)
is a complete example.

## Testing your widget

[Term::Fabulous::Terminal::Memory](../Terminal/Memory.md) runs a program without a terminal:
`step` handles the input and draws a frame, and the terminal object
types keys, clicks and reports what the screen shows. Tests of a widget
can check both what it draws and the events it fires:

```perl
use Test2::V0;
use Term::Fabulous;
use Term::Fabulous::Terminal::Memory;

my $terminal = Term::Fabulous::Terminal::Memory->new( width => 30, height => 3 );
my $ui       = Term::Fabulous->new( root => $root, width => 30, height => 3, terminal => $terminal );

my @activated;
$tile->on( Activate => sub ($event) { push @activated, $event->target; return } );

$ui->step;                    # opens the terminal, draws the first frame
$terminal->press_key('Tab');  # focuses the tile
$terminal->press_key('Enter');
$ui->step;
is scalar @activated, 1, 'Enter activates the tile';
```

See [testing](Programs.md#testing) on the page about
programs, and the recipe
[Test a widget without a terminal](../Cookbook/Output.md#test-a-widget-without-a-terminal).

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Programs](Programs.md). Next page: [Term::Fabulous::Manual::Troubleshooting](Troubleshooting.md).

[Term::Fabulous::Cookbook::Extending](../Cookbook/Extending.md), [Term::Fabulous::Widget::Box](../Widget/Box.md),
[Term::Fabulous::Widget::Canvas](../Widget/Canvas.md), [Term::Fabulous::Widget::Display](../Widget/Display.md),
[Term::Fabulous::Widget::Input](../Widget/Input.md),
[Term::Fabulous::Widget::Button](../Widget/Button.md), [Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md),
[Term::Fabulous::Manual::Events](Events.md).
