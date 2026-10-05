# NAME

Term::Fabulous::Role::HasRange - A widget whose range comes from a layout in one piece

# SYNOPSIS

```perl
use Object::Pad 0.825;

class My::Dial :isa(Term::Fabulous::Widget::Display) :does(Term::Fabulous::Role::HasRange) :strict(params) {
        field $range;    # a Term::Fabulous::Range

        method range_properties :common () { return qw(min max step) }

        method set_range (%range) {
                $range->set_range(%range);
                $self->mark_changed;
                return $self;
        }
}
```

# DESCRIPTION

The widgets that pick a value from a [Term::Fabulous::Range](../Range.md)
([Term::Fabulous::Widget::Slider](../Widget/Slider.md), [Term::Fabulous::Widget::StarRating](../Widget/StarRating.md),
[Term::Fabulous::Widget::ProgressBar](../Widget/ProgressBar.md)) compose this role, so that a KDL
layout may give the parts of their range in any order: the parts are
collected and handed to `set_range` in one call, before the other
properties (the `value` among them) are applied. A range is checked as
a whole, so `min 300; max 400;` works on a widget whose range was
`0..100`, which applying `min` alone could not.

# REQUIRED METHODS

## range\_properties

```perl
method range_properties :common () { return qw(min max step) }
```

A class method: the names of the layout properties that make the range.
Each must also be a layout property of the class (see
["layout\_properties" in Term::Fabulous::Role::CanParseLayout](CanParseLayout.md#layout_properties)).

## set\_range

```perl
method set_range (%range) { ... }
```

Changes the range parts given, checked as a whole. Called with the
range properties the layout gave, by their names.

# METHODS

## apply\_layout\_settings

Applies the range properties with ["set\_range"](#set_range) in one call, then the
other settings as [Term::Fabulous::Role::CanParseLayout](CanParseLayout.md) does.

# SEE ALSO

[Term::Fabulous::Range](../Range.md), [Term::Fabulous::Manual::KDL](../Manual/KDL.md).
