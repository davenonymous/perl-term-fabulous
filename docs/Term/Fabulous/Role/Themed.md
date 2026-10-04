# NAME

Term::Fabulous::Role::Themed - How a widget reads its colors and
border styles from the theme

# SYNOPSIS

```perl
use Object::Pad 0.825;

class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
        field $fill_color :param = undef;    # undef: the theme's progress.color

        method theme_family :common () { return 'progress' }

        method themed_params :common () {
                return ( $class->SUPER::themed_params, fill_color => [ 'color', 'normal' ] );
        }

        ADJUST {
                $self->set_look( fill_color => cell_color( $self, fill_color => $fill_color ) ) if defined $fill_color;
        }

        method fill_color (@new) {
                return $self->look_value('fill_color') unless @new;
                return $self->set_look( fill_color => cell_color( $self, fill_color => $new[0] ) );
        }

        method paint () {
                my $fill = $self->color_attr( $self->look_value('fill_color') );
                ...
        }
}

$gauge->fill_color('#ff8800');    # explicit, wins over the theme
$gauge->reset_look('fill_color');  # back to the theme
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
        return ( $class->SUPER::themed_params, accent_color => [ 'accent', 'normal' ], focus_background_color => [ 'background', 'focused' ] );
}
```

The parameters whose value the theme supplies when the program gives
none: `name => [ slot, state ]`. The slot and state must exist in
the family; the first use of the class checks that and dies otherwise.
A subclass returns its parent's list plus its own.

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

## theme\_changed

```perl
method theme_changed () { $self->request_prepare; return }
```

Optional. Called on every widget of a UI's tree, top down, when the
UI is created and when its theme is set to another one, and on a
widget (and everything below it) when it joins a tree that is in a
UI. Most widgets need none, because they read their looks when a
frame is drawn. A widget that copies looks into the parts it builds
([Term::Fabulous::Widget::Table](../Widget/Table.md) colors its cells, its pager and its
scrollbar) builds or colors them again here.

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

## look\_value

```perl
my $color = $self->look_value('accent_color');
```

What a themed parameter is worth: the explicit value when the program
set one, else the theme's value of the slot and state the parameter
maps to. Dies for a name that is not in ["themed\_params"](#themed_params).

## themed\_value

```perl
my $background = $self->themed_value( 'background', $state, $explicit // $self->look('background') );
```

The value of a slot in a state, given the value of the normal state:
the explicit value of the parameter mapped to that state (such as
`focus_background_color`), else the theme's own value for the state,
else the normal value. This is how an explicit normal color stays in
states the theme does not color differently.

## adopt\_look\_params

```perl
ADJUSTPARAMS ($params) {
        $self->adopt_look_params( $params, qw(accent_color focus_background_color) );
}
```

For the constructor: takes the named parameters out of the
`ADJUSTPARAMS` hash and passes each one that was given to the
accessor of the same name, which checks and records it. A parameter
the program left out stays with the theme. Themed parameters are not
declared as fields, so that "not given" and "given as `undef`" (for
a look that `undef` switches off) stay apart.

## set\_look

```perl
$self->set_look( accent_color => $checked_color );
```

Records an explicit value, already validated by the caller, and marks
the widget changed. Returns the value.

## has\_look\_override

```perl
if ( $self->has_look_override('accent_color') ) { ... }
```

Whether the program set the parameter explicitly.

## reset\_look

```perl
$widget->reset_look('accent_color');
$widget->reset_look( 'border_color', 'background_color' );
```

Drops the explicit values of the named parameters, so the theme
supplies them again, and marks the widget changed. Returns the widget.
Dies for a name that is not in ["themed\_params"](#themed_params).

## forget\_looks

```perl
$widget->forget_looks;
```

Drops the fetched looks of the widget and of every widget below it;
the next read fetches them from the theme of the UI the widget is in
now. Term::Fabulous calls it when a widget joins or leaves a tree.

# SEE ALSO

[Term::Fabulous::Theme](../Theme.md), [Term::Fabulous::Widget](../Widget.md),
[Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md).
