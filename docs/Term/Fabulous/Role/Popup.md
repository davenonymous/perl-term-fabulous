# NAME

Term::Fabulous::Role::Popup - A floating widget that keeps its place on the screen

# SYNOPSIS

```perl
use Object::Pad;
use Term::Fabulous::Placement qw(place_popup TOPMOST_Z_INDEX);

class My::Tooltip
        :isa(Term::Fabulous::Widget::Display)
        :does(Term::Fabulous::Role::Popup)
{
        use Term::Fabulous::Placement qw(place_popup);

        field $anchor :param :weak;

        # Below the anchor, or above it when there is no room below.
        method popup_position () {
                my $ui  = $self->ui                   // return undef;
                my $box = $ui->bounding_box($anchor) // return undef;
                my $place = place_popup( anchor => $box, size => [ 20, 3 ], screen => [ $ui->width, $ui->height ] );
                return { x => $place->{x}, y => $place->{y} };
        }

        method contribute_floating :override ($config) {
                $self->SUPER::contribute_floating($config);
                $self->float_popup($config) if defined $config->{floating};
                return;
        }
}

my $tip = My::Tooltip->new( anchor => $button, floating => { z_index => TOPMOST_Z_INDEX } );
```

# DESCRIPTION

A role for floating widgets that float over everything at a position
they work out themselves (with [Term::Fabulous::Placement](../Placement.md)), from the
boxes the last frame laid out: the list of a
[Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md), a [Term::Fabulous::Widget::Menu](../Widget/Menu.md),
a table's column chooser
(["open\_column\_chooser" in Term::Fabulous::Widget::Table](../Widget/Table.md#open_column_chooser)). The widget calls
["float\_popup"](#float_popup) from its `contribute_floating`; the role attaches it to
the root at the position, and after each frame checks whether the frame
moved what the position depends on (an anchor that grew, a popup laid
out for the first time). If so, it marks the widget changed, and the
next frame puts it where it belongs. A popup therefore finds its place
within two frames of any change, and stays put while nothing changes.

A widget composing the role needs `each_frame` and `mark_changed`, as
every [Term::Fabulous::Widget](../Widget.md) has.

# REQUIRED METHODS

## popup\_position

```perl
my $position = $popup->popup_position;    # { x => 12, y => 3 }
```

Where the popup's top left corner goes in this frame, in screen cells,
or `undef` while that is not known (its anchor has no box yet). Called
while the frame is laid out and after it is drawn.

# PROVIDED METHODS

## float\_popup

```perl
$self->float_popup($config);
```

For `contribute_floating`: changes the `floating` hash of `$config`
to attach the widget to the root (both attach points at the left top
corner) with ["popup\_position"](#popup_position) as its offset, and keeps everything
else of it (the `z_index`, for example). Without a position, the
floating hash stays as the widget declared it for this frame. Either
way, the position is checked again after the frame (see
["DESCRIPTION"](#description)). `$config` must have a `floating` hash.

# SEE ALSO

[Term::Fabulous::Placement](../Placement.md), [Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md),
[Term::Fabulous::Widget::Menu](../Widget/Menu.md),
["open\_column\_chooser" in Term::Fabulous::Widget::Table](../Widget/Table.md#open_column_chooser),
["Floating widgets" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#floating-widgets).
