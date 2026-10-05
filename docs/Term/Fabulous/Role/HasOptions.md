# NAME

Term::Fabulous::Role::HasOptions - A widget whose options come from a layout

# SYNOPSIS

```perl
class My::Picker :isa(Term::Fabulous::Widget::Input) :does(Term::Fabulous::Role::HasOptions) :strict(params) {
        field $list = Term::Fabulous::OptionList->new( owner => __CLASS__ );

        method options (@new) {
                return $list->options unless @new;
                $list->set_options( $new[0] );
                $self->mark_changed;
                return $list->options;
        }

        method layout_properties :common () {
                return (
                        $class->SUPER::layout_properties,
                        value => 'scalar',
                        options => \&add_layout_options,
                        option  => \&add_layout_options,
                );
        }
}
```

# DESCRIPTION

[Term::Fabulous::Widget::Dropdown](../Widget/Dropdown.md) and
[Term::Fabulous::Widget::SegmentedControl](../Widget/SegmentedControl.md) compose this role so that a
KDL layout gives their options in the same way, in either form, and
before the `value` or `selected_index` that picks one, wherever these
stand in the layout:

```kdl
options "Day" "Week" "Month"
option "Year" value="y" disabled=#true
value "y"
```

# REQUIRED METHODS

## options

The options accessor: without an argument the options (as
["options" in Term::Fabulous::OptionList](../OptionList.md#options) returns them), with an array
reference the new options.

# METHODS

## apply\_layout\_settings

Applies the `options` and `option` properties first, then the others,
as [Term::Fabulous::Role::CanParseLayout](CanParseLayout.md) does.

## add\_layout\_options

```kdl
$self->add_layout_options($node);
```

Adds the options of an `options` or `option` property node (see
["from\_layout\_node" in Term::Fabulous::OptionList](../OptionList.md#from_layout_node)) after the ones the
widget has. The class lists it as the handler of both properties in its
`layout_properties`.

# SEE ALSO

[Term::Fabulous::OptionList](../OptionList.md), [Term::Fabulous::Manual::KDL](../Manual/KDL.md).
