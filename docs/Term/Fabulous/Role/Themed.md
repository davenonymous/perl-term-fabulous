# NAME

Term::Fabulous::Role::Themed - How a widget reads its colors and
border styles from the theme

# SYNOPSIS

```perl
use Object::Pad 0.825;

class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
        method theme_family :common () { return 'progress' }

        # fill_color: the theme's progress.color unless given; a color
        method themed_params :common () {
                return ( $class->SUPER::themed_params, fill_color => [ 'color', 'normal', 'cell_color' ] );
        }

        method fill_color (@new) {
                return @new ? $self->set_look( fill_color => $new[0] ) : $self->look_value('fill_color');
        }

        method paint () {
                my $fill = $self->color_attr( $self->fill_color );
                ...
        }
}

my $gauge = My::Gauge->new( fill_color => '#ff8800' );    # explicit, wins over the theme
$gauge->reset_look('fill_color');                          # back to the theme
```

# DESCRIPTION

Every Term::Fabulous widget composes this role (through
[Term::Fabulous::Widget](../Widget.md) or [Term::Fabulous::Widget::Text](../Widget/Text.md)). It
holds the widget's _explicit_ looks, the colors and border styles the
program set, and reads everything else from the
[Term::Fabulous::Theme](../Theme.md) of the UI the widget is in, for the widget's
_family_ and _classes_. A widget in no UI reads the default theme.

The looks are fetched once and kept until the theme changes
(["generation" in Term::Fabulous::Theme](../Theme.md#generation)) or the widget joins or leaves a
tree, so reading a look while a frame is drawn costs one hash lookup.

A themed parameter is declared once, in ["themed\_params"](#themed_params), with the
slot it reads and its _kind_. The role takes a parameter of a kind
from the constructor, checks every value given to ["set\_look"](#set_look) by the
kind and makes it a layout property, so the widget writes only a
one-line accessor. A widget that copies looks into parts it builds
learns about every change in one hook, ["looks\_changed"](#looks_changed); a widget
whose looks live on its parts declares them in ["forwarded\_looks"](#forwarded_looks).

This page is for widget authors; ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes)
explains themes to users, and
[Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md) shows the role in a widget.

# CLASS METHODS A WIDGET DEFINES

## theme\_family

```perl
method theme_family :common () { return 'input' }
```

The family whose slots the widget draws with, one of
["Families, slots and states" in Term::Fabulous::Theme](../Theme.md#families-slots-and-states). A subclass
inherits its parent's family unless it defines its own.

## themed\_params

```perl
method themed_params :common () {
        return (
                $class->SUPER::themed_params,
                accent_color           => [ 'accent',     'normal',  'cell_color' ],
                focus_background_color => [ 'background', 'focused', 'cell_color' ],
        );
}
```

The parameters whose value the theme supplies when the program gives
none: `name => [ slot, state, kind ]`. The slot and state must
exist in the family; the first use of the class checks that, and the
kind, and dies otherwise. A subclass returns its parent's list plus
its own.

The kind says what a value is:

- `color`, `cell_color`

    A color (["color" in Term::Fabulous::Check](../Check.md#color); `cell_color` also takes a
    packed `0xRRGGBB`), stored as `[r, g, b, a]`. `undef` dies with a
    message that names ["reset\_look"](#reset_look), the way back to the theme. In a
    layout it is a `'color'` property.

- `optional_color`, `optional_cell_color`

    The same, or `undef` for none (a look the widget then leaves out,
    such as a focus border). In a layout it is a `'scalar'` property, so
    `#null` gives `undef`.

- `border_style`, `grid_border_style`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item or its name
    (["border\_style" in Term::Fabulous::Check](../Check.md#border_style)); `grid_border_style` only a
    style with joints. `undef` dies as for a color. A `'scalar'` layout
    property.

- a code reference

    A check of your own, called like the functions of
    [Term::Fabulous::Check](../Check.md) as `$check->( $widget, $name, $value )`,
    `undef` included; it returns the value to keep or dies. A `'scalar'`
    layout property.

The role takes a parameter of a kind out of the constructor's
arguments and records it, checked, as an explicit value; a parameter
the program left out stays with the theme. It does that before the
class's own fields and `ADJUST` blocks run, so it calls neither the
accessor nor ["looks\_changed"](#looks_changed): build your parts in `ADJUST` from
["look\_value"](#look_value). Do not declare such a parameter as a field: "not
given" and "given as `undef`" (for a look `undef` switches off) stay
apart this way. A layout entry of the same name in
["layout\_properties" in Term::Fabulous::Role::CanParseLayout](CanParseLayout.md#layout_properties) replaces the
one the kind gives.

Without a kind (`[ slot, state ]`) the class keeps and checks the
value itself and the role leaves the constructor and the layout to
it: [Term::Fabulous::Widget](../Widget.md) keeps `background_color` and
`border_color` in the Clay::UI roles, [Term::Fabulous::Widget::Text](../Widget/Text.md)
its `text_color`. Its accessor checks the value before
["set\_look"](#set_look), and ["look\_reset"](#look_reset) clears it.

## forwarded\_looks

```perl
method forwarded_looks :common () {
        return ( bar => [ 'Term::Fabulous::Widget::Tabs::Bar', qw(line_color text_color) ] );
}
```

Optional. The looks the widget keeps on parts it builds:
`method => [ part class, names ]`, where the method returns the
parts (one or more) and every name is a themed parameter with a kind
of the part class. [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md) keeps its colors on
its bar, [Term::Fabulous::Widget::ScrollBox](../Widget/ScrollBox.md) its scrollbar colors on
both scrollbars. The role routes ["set\_look"](#set_look) (checked by the part's
kind, in the widget's name, then given to every part),
["look\_value"](#look_value) and ["has\_look\_override"](#has_look_override) (asking the first part) and
["reset\_look"](#reset_look) (on every part) through the method, and makes the names
layout properties of the part's kinds. The widget passes the
constructor's values to the parts it builds, or calls ["set\_look"](#set_look)
once they exist. The first use of the class dies for a name the part
class has no kind for, a name that is also a themed parameter of the
widget, or a name given twice.

# METHODS A WIDGET DEFINES

## look\_state

```perl
method look_state () { return $self->is_focused ? 'focused' : 'normal' }
```

The state the widget shows now: `normal`, or a state its family's
slots have. [Term::Fabulous::Widget](../Widget.md) answers `normal`; a widget with
states overrides it and decides the precedence (a disabled button is
disabled, not focused).

## look\_reset

```perl
method look_reset ($name) { ... }
```

Called by ["reset\_look"](#reset_look) for every parameter name, after the role
dropped its explicit value. A class that keeps the explicit value of a
parameter outside the role ([Term::Fabulous::Widget](../Widget.md) keeps
`background_color` and `border_color` in the Clay::UI roles) clears
it here; the others do nothing.

## classes

The widget's class names as an array reference; see
["classes" in Term::Fabulous::Widget](../Widget.md#classes).

## looks\_changed

```perl
method looks_changed (@names) {
        $_close_button->text_color( $self->text_color );
        return;
}
```

Optional. Called with the names of the looks that may have changed:
after ["set\_look"](#set_look) (the name), after ["reset\_look"](#reset_look) (the names given),
and with every look of the widget (its themed parameters and its
forwarded looks) when ["forget\_looks"](#forget_looks) runs while the widget is in a
UI, which is when the UI is created, when its theme is set to another
one and when the widget joins a tree that is in a UI. Not called
during construction (see ["themed\_params"](#themed_params)), nor for a widget outside
a UI, which reads its looks when it is drawn.

Most widgets need none, because they read their looks when a frame is
drawn. A widget that copies looks into the parts it builds
([Term::Fabulous::Widget::Table](../Widget/Table.md) colors its cells, its pager and its
scrollbar) colors them again here.

# CLASS METHODS

## themed\_layout\_properties

```perl
my %kind_of = My::Gauge->themed_layout_properties;    # ( fill_color => 'color' )
```

The layout properties the themed parameters of a kind and the
forwarded looks give the class (see ["themed\_params"](#themed_params));
[Term::Fabulous::Role::CanParseLayout](CanParseLayout.md) adds them to the class's own
[layout\_properties](CanParseLayout.md#layout_properties).

# METHODS

## look

```perl
my $color = $self->look('accent');
my $color = $self->look( 'border.color', 'focused' );
```

The theme's value of a slot of the widget's family in a state
(`normal` by default), for the widget's classes: `[r, g, b, a]`, a
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item, `'reverse'` or `undef`
for none. A state the theme gives no value of its own looks like the
normal state.

## family\_look

```perl
my $track = $self->family_look( scrollbar => 'track' );
```

Like ["look"](#look), for a slot of another family, without the widget's
classes: for a part the widget paints itself in the looks of that
family, such as the scrollbar of a [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md).
Read it while painting; a theme switch repaints a
[Term::Fabulous::Widget::Display](../Widget/Display.md) by itself.

## look\_value

```perl
my $color = $self->look_value('accent_color');
```

What a themed parameter is worth: the explicit value when the program
set one, else the theme's value of the slot and state the parameter
maps to. A forwarded look is the first part's. Dies for a name that is
neither in ["themed\_params"](#themed_params) nor in ["forwarded\_looks"](#forwarded_looks).

## themed\_value

```perl
my $background = $self->themed_value( 'background', $state, $explicit // $self->look('background') );
```

The value of a slot in a state, given the value of the normal state:
the explicit value of the parameter mapped to that state (such as
`focus_background_color`), else the theme's own value for the state,
else the normal value. This is how an explicit normal color stays in
states the theme does not color differently.

## set\_look

```perl
$self->set_look( accent_color => '#61afef' );
```

Records an explicit value: checked by the parameter's kind (a
parameter without a kind takes the value as given, checked by the
caller), or, for a forwarded look, checked by the part's kind and
given to every part. Marks the widget changed, calls
["looks\_changed"](#looks_changed) with the name and returns the value as recorded
(`[r, g, b, a]` for a color). Dies for an unknown name.

## has\_look\_override

```perl
if ( $self->has_look_override('accent_color') ) { ... }
```

Whether the program set the parameter explicitly (for a forwarded
look: on the first part).

## reset\_look

```perl
$widget->reset_look('accent_color');
$widget->reset_look( 'border_color', 'background_color' );
```

Drops the explicit values of the named parameters, so the theme
supplies them again (a forwarded look on every part), marks the widget
changed and calls ["looks\_changed"](#looks_changed) with the names. Returns the
widget. Dies for a name that is neither in ["themed\_params"](#themed_params) nor in
["forwarded\_looks"](#forwarded_looks), before anything changes.

## forget\_looks

```perl
$widget->forget_looks;
```

Drops the fetched looks of the widget and of every widget below it;
the next read fetches them from the theme of the UI the widget is in
now. When the widget is in a UI, calls ["looks\_changed"](#looks_changed) with all its
looks. Term::Fabulous calls it when a widget joins or leaves a tree or
changes its classes.

# FUNCTIONS

## forget\_tree\_looks

```perl
Term::Fabulous::Role::Themed::forget_tree_looks( $ui->root );
```

["forget\_looks"](#forget_looks) for a node and every themed widget below it, also
below nodes that are not themed (the rows of a grid). The UI calls it
when it is created and when its theme changes.

# SEE ALSO

[Term::Fabulous::Theme](../Theme.md), [Term::Fabulous::Widget](../Widget.md),
[Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md).
