# NAME

Term::Fabulous::Manual::CustomWidgets - Writing your own widgets

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Programs](Programs.md). Next page: [Term::Fabulous::Manual::Troubleshooting](Troubleshooting.md).

This page explains how to write widget classes of your own: a container
with a fixed structure (derived from Box), a widget that draws itself
(derived from Display), an input widget (derived from Input) and a box
that takes the focus and reacts to the mouse (a Box with the Clay::UI
interaction roles), a dialog (derived from Dialog) and a popup. It
lists the methods each base class lets you override, explains how a
widget names its focus heir, how it tells Term::Fabulous that it must
be drawn again, how it does work after a frame and how it tells its
height before the layout, and shows how to make widgets a search
finds, how to fire events of your own, how to make a widget usable
from KDL layout files and how to test it.

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
    [Term::Fabulous::Widget::Divider](../Widget/Divider.md), the charts and the scrollbar are
    ones. See
    ["A widget that draws itself"](#a-widget-that-draws-itself).

- [Term::Fabulous::Widget::Input](../Widget/Input.md)

    for an interactive widget that edits a value: you get focus handling,
    the four colors (from the theme unless given), the disabled state,
    `Change` events and painting at
    the right time. See ["An input widget"](#an-input-widget).

- A Box with the Clay::UI interaction roles

    for a container that takes the focus or reacts to hover and clicks,
    like [Term::Fabulous::Widget::Button](../Widget/Button.md). See
    ["A box that takes the focus and reacts to the mouse"](#a-box-that-takes-the-focus-and-reacts-to-the-mouse).

- [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md)

    for a dialog with a title, buttons and an answer of its own. See
    ["A dialog of your own"](#a-dialog-of-your-own).

- [Term::Fabulous::Role::Popup](../Role/Popup.md) with [Term::Fabulous::Placement](../Placement.md)

    for a widget that floats over everything next to another one, like a
    dropdown's list. The widget works out its place in
    [popup\_position](../Role/Popup.md#popup_position)
    ([place\_popup](../Placement.md#place_popup) puts it next to
    its anchor and keeps it on the screen), calls
    [float\_popup](../Role/Popup.md#float_popup) from its
    `contribute_floating`, and is made with
    `floating => { z_index => TOPMOST_Z_INDEX }` (see
    [TOPMOST\_Z\_INDEX](../Placement.md#topmost_z_index)). See the
    SYNOPSIS of [Term::Fabulous::Role::Popup](../Role/Popup.md).

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
                $self->bordered(1);
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

The accessors a Box inherits (`layout`, `bordered`, ...) record
the change themselves, so the next frame shows it. A container whose
look depends on fields of its own must say so when they change; see
["Telling Term::Fabulous that something changed"](#telling-term-fabulous-that-something-changed).

A container that takes children out of the tree while one of them may
have the focus (it shows one page at a time, or collapses) can name who
gets the focus then, with a method `focus_heir`. When the focused
widget leaves the tree or can no longer take the focus, Clay::UI walks
up from it: the first widget that stays and can take the focus gets
it, unless a container on the way names a widget of its own first (see
["When the focused widget goes away" in Term::Fabulous::Manual::Events](Events.md#when-the-focused-widget-goes-away)).
A pager whose pages share a row of buttons hands the focus to the
button of the shown page:

```text
class My::Pager :isa(Term::Fabulous::Widget::Box) :strict(params) {
        field @buttons;    # one Button per page, always in the tree
        field $shown = 0;
```

```text
        method focus_heir () { return $buttons[$shown] }
}
```

Return `undef` to let the walk go on; a widget that cannot take the
focus right now counts as `undef`.

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

## Colors from the theme

Every widget draws the colors, border styles and borders it was not given from
the theme of its UI (["THEMES" in Term::Fabulous::Manual::Looks](Looks.md#themes)). A
widget class of your own takes part through
[Term::Fabulous::Role::Themed](../Role/Themed.md), which every widget composes:

- The widget's _family_ decides which slots it reads. A class inherits
the family of its base class (a widget derived from Input reads the
`input` slots, a Box the `box` slots); `theme_family` names another
one.
- `themed_params` lists the parameters the theme supplies when the
program gives none, each with the slot and the state it reads and its
_kind_: `color`, `cell_color`, `optional_color` (`undef` for
none), `border_style`, ... (see
["themed\_params" in Term::Fabulous::Role::Themed](../Role/Themed.md#themed_params)). The kind is all the
role needs: it takes the parameter from the constructor, checks every
value, and makes it a layout property. Do not declare such a parameter
as a field, and do not list it in `layout_properties`.
- The accessor is one line: it reads `look_value` and writes
`set_look`. `paint` and the `contribute_*` methods read the
accessor or `look_value`, never a copy, so that a theme switch shows
at once. A widget that paints into a buffer of its own (a Display)
repaints after a switch by itself.
- A widget that copies looks into widgets it builds (a text color into
its labels) does so in `ADJUST`, after it built them, and again in
`looks_changed`, which the role calls with the names of the looks
that may have changed: after `set_look` and `reset_look`, and with
all of them when the theme of its UI changes. A widget whose looks
live on its parts declares them in `forwarded_looks` instead, and
`reset_look` reaches the parts.

A gauge that reads its fill color from the `progress` family:

```perl
use Object::Pad 0.825;

class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
        field $fraction :param = 0;

        method theme_family :common () { return 'progress' }

        method themed_params :common () {
                return ( $class->SUPER::themed_params, fill_color => [ 'color', 'normal', 'cell_color' ] );
        }

        method fill_color (@new) {
                return @new ? $self->set_look( fill_color => $new[0] ) : $self->look_value('fill_color');
        }

        method natural_size () { return ( 20, 1 ) }

        method paint () {
                my $filled = int( $self->columns * $fraction + 0.5 );
                $self->fill_attrs( 0,       0, $filled,                  "\x{2588}", $self->color_attr( $self->fill_color ), undef );
                $self->fill_attrs( $filled, 0, $self->columns - $filled, "\x{2591}", $self->color_attr( $self->look('track') ), undef );
                return;
        }
}

my $gauge = My::Gauge->new( fraction => 0.25 );                 # the theme's progress.color
my $red   = My::Gauge->new( fraction => 0.25, fill_color => '#ff0000' );    # its own
$red->reset_look('fill_color');                                   # the theme's again
```

A slot the family does not have dies the first time the class is used,
naming the family. The slots of every family are listed in
["Families, slots and states" in Term::Fabulous::Theme](../Theme.md#families-slots-and-states); a widget whose
look needs none of them, such as a canvas drawn by its program, needs
nothing here.

A widget that needs the theme itself, to resolve the palette tokens of
a style (["resolve\_style" in Term::Fabulous::Text::Style](../Text/Style.md#resolve_style)) or to take a
look of a whole family, asks `$self->drawing_theme` (see
["drawing\_theme" in Term::Fabulous::Role::Themed](../Role/Themed.md#drawing_theme)), never `$ui->theme`:
a UI may give a part of its tree another theme
(["theme\_for" in Term::Fabulous::Render](../Render.md#theme_for)), and outside a UI, or in a plain
[Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI), the widget draws in the default theme. `look`,
`family_look` and ["of" in Term::Fabulous::Document::Look](../Document/Look.md#of) already ask it.

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
        use Scalar::Util qw(refaddr);
        use Term::Fabulous::Event::Activate;

        ADJUST {
                $self->on(
                        OnRelease => sub ( $self, $event ) {    # the owner: the tile
                                $self->activate if refaddr( $event->target ) == refaddr($self);
                                return Clay::UI::Enum::Result->CONTINUE;
                        },
                        owner => $self
                );
                $self->on(
                        KeyPress => sub ( $self, $event ) {
                                return Clay::UI::Enum::Result->CONTINUE unless ( $event->main_key_name // '' ) eq 'Enter';
                                $self->activate;
                                return;    # used: stop here
                        },
                        owner => $self
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
children bubble through the widget too. They are registered with
`owner => $self`: a widget keeps its listeners, so a listener that
refers to its own widget directly would keep it alive forever. An
owner-bound listener holds its owner weakly and gets it as its first
argument, named `$self` here so that the closure cannot reach the
method's own `$self` by mistake (see
["owner" in Clay::UI::Role::Events::Listener](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AListener#owner)). The same goes for a
listener a widget puts on one of its parts, such as a button inside
it.

Two more methods change how Term::Fabulous draws a widget and its
children. [Term::Fabulous::Widget::Button](../Widget/Button.md) uses both:

- `reverse_video`

    Every [Term::Fabulous::Widget](../Widget.md) has it; it returns 0. While it returns
    1, the renderer draws the widget's cells with the foreground and
    background colors swapped, its children included. Override it to show
    a state:
    `method reverse_video :override () { return $self->is_pressed ? 1 : 0 }`.

- `child_text_color`

    Not defined by default. A [Term::Fabulous::Widget::Text](../Widget/Text.md) asks its
    nearest ancestor that has this method, passing the color it was given
    (or `undef`), and draws its text in what the method returns; when it
    returns `undef`, the Text uses its given color or the theme's text
    color. Return a gray while the widget is disabled, and the given color
    or a theme look (`$self->look('text', $self->look_state)`)
    otherwise, as [Term::Fabulous::Widget::Button](../Widget/Button.md) does.

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

## Work after a frame

Some work needs the layout of a frame: where a child landed, how far
the box scrolled. Register it with `each_frame` (see
["each\_frame" in Term::Fabulous::Widget](../Widget.md#each_frame)): the code is called with the
widget after every frame until it returns true, at most `frames`
times, and never once the widget left the UI. The widget is passed in,
so the closure keeps no reference to it, and a `name` makes a second
request replace the first:

```perl
method show_later ($child) {
        $self->each_frame( sub ($self) { return $self->child_is_placed($child) }, name => 'show', frames => 4 );
        return $self;
}
```

Work asked for with `each_frame` before the widget is in a UI waits
until it joins one, so a constructor or a setter called before the UI
is built may ask for it. For one call after the next frame, the UI's
[after\_draw](../Render.md#after_draw) takes
`owner => $self` and calls the code once with the widget.

To scroll a child of a ScrollBox into view, call the box's
[reveal](../Widget/ScrollBox.md#reveal), which waits for the
child's layout by itself.

## Height before layout

A list that builds only the items near its viewport needs the height
of the others before Clay lays them out, for its scrollbar: a
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) asks its items with
[estimated\_rows](../Widget.md#estimated_rows). With a fixed
height in its layout, `estimated_rows` returns that height; otherwise
it asks
[estimated\_content\_rows](../Widget.md#estimated_content_rows)
how many rows the content takes in the columns left inside the padding
and the border, and adds the padding
([content\_padding](../Widget.md#content_padding)) and the
drawn border sides. That is one row, unless the class knows better: a
Box combines its children's estimates (children below each other add
up, children side by side take the tallest), a Display answers from its
`natural_size`, a Table counts its header and the rows of its page. A
widget that knows how tall its content is overrides
`estimated_content_rows($columns)`:

```perl
method estimated_content_rows :override ($columns) {
        return scalar @lines;    # a field of the widget: one row per line
}
```

A widget that keeps room of its own inside its border, as a ScrollBox
does for its scrollbars, overrides `content_padding` to add that room
(calling SUPER), so that the estimate counts it. Clay's layout corrects a guess that was off.

## Widgets a search finds

A [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) searches the widgets of its
items that do [Term::Fabulous::Role::Searchable](../Role/Searchable.md); Text and CodeBlock
do it for their text, a Table from its rows. A widget of your own that
shows text it builds only later does the role itself: it provides
`search_texts`, `search_revision`, `highlight_text`,
`clear_text_highlights` and `reveal_text` (see
["REQUIRED METHODS" in Term::Fabulous::Role::Searchable](../Role/Searchable.md#required-methods)). A container that
holds searchable widgets which are not always in the tree (pages,
a collapsible body) composes [Term::Fabulous::Role::SearchContainer](../Role/SearchContainer.md)
instead: it lists them in `searchable_parts` and makes one visible in
`reveal_part`, and the role answers the search for all of them, as
Tabs and Accordion::Item do:

```perl
use Term::Fabulous::Role::SearchContainer;

class My::Drawer :isa(Term::Fabulous::Widget::Box) :does(Term::Fabulous::Role::SearchContainer) {
        use Term::Fabulous::Role::Searchable qw(searchables_in);    # a class block is a package of its own

        field $content = Term::Fabulous::Widget::Box->new;

        method searchable_parts () { return searchables_in($content) }
        method reveal_part ($part) { $self->add_child($content) unless $self->has_child($content); return }
}
```

A search remembers its matches with the key and the revision of each
text; before it uses a key again it compares the revision, and searches
again when it changed. The container's revisions name the part at each
index, so removing a part makes the old keys stale instead of letting
them reach the part that took its place.

## A dialog of your own

A subclass of [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md) declares its title and
buttons and adds its content; the dialog draws the title, the row of
buttons and the notice line, and reports every way of closing with one
[Answer](../Event/Answer.md) event. A button that should do
more than answer is handled in
[press\_button](../Widget/Dialog.md#press_button), the inputs
the answer carries come from
[values](../Widget/Dialog.md#values):

```perl
use Term::Fabulous::Widget::Dialog;

class My::RenameDialog :isa(Term::Fabulous::Widget::Dialog) {
        use Term::Fabulous::Text::Markup qw(escape_markup);
        use Term::Fabulous::Widget::TextField;

        field $field = Term::Fabulous::Widget::TextField->new;

        sub BUILDARGS ( $class, %params ) {
                return $class->SUPER::BUILDARGS( %params, title => 'Rename', buttons => [ { id => 'rename', label => 'Rename', primary => 1 }, { id => 'cancel', label => 'Cancel' } ] );
        }

        ADJUST {
                $self->add_child($field);

                # Enter in the field presses the default button, Rename.
                $self->on( Submit => sub ( $self, $event ) { $self->press_button( $self->default_button ); return }, owner => $self );
        }

        method values :override () { return { name => $field->value } }

        # Rename answers only with a name that is free.
        method press_button :override ($id) {
                return $self->SUPER::press_button($id) unless $id eq 'rename' && -e $field->value;
                return $self->notice( escape_markup( $field->value ) . ' is taken.', 'error' );
        }
}
```

`Escape` and `close` answer `cancel` as dismissed, with the values
too. A dialog does not press a button for `Enter` in a text field by
itself: the `Submit` listener in `ADJUST` presses the
[default\_button](../Widget/Dialog.md#button-button_ids-is_primary-default_button).
The dialog puts its title first and the notice line and buttons last
when it opens
([place\_parts](../Widget/Dialog.md#place_parts)), so the
children added in `ADJUST` end up between them.

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
[Term::Fabulous::Widget::Button](../Widget/Button.md), [Term::Fabulous::Widget::Dialog](../Widget/Dialog.md),
[Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md),
[Term::Fabulous::Role::Searchable](../Role/Searchable.md),
[Term::Fabulous::Role::SearchContainer](../Role/SearchContainer.md),
[Term::Fabulous::Role::Themed](../Role/Themed.md), [Term::Fabulous::Role::Popup](../Role/Popup.md),
[Term::Fabulous::Placement](../Placement.md), ["each\_frame" in Term::Fabulous::Widget](../Widget.md#each_frame),
[Term::Fabulous::Manual::Events](Events.md).
