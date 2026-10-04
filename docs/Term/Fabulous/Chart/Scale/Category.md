# NAME

Term::Fabulous::Chart::Scale::Category - An axis of named categories

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Scale::Category;

my $scale = Term::Fabulous::Chart::Scale::Category->fit( labels => [qw(Jan Feb Mar)], cells => 30 );
say $scale->position(1);     # 0.5: the middle of the second slot
say $scale->slot_cells;      # 10
```

# DESCRIPTION

A [Term::Fabulous::Chart::Scale](../Scale.md) for labels such as months, products or
names. The values are the category numbers, from 0. A _band_ scale (the
default, and what bar charts use) gives each category an equal slot and
places it at the slot's middle; the slots are whole cells wide when the
cells left over (shared by both ends of the axis) are few, so the gaps
between bars are all equal. A _point_ scale places the first category
at the start of the axis and the last at its end, as line charts of
categories do.

Every category is a tick. When the labels do not fit beside each other,
only every second (third, ...) category is labeled.

# CLASS METHODS

## fit

```perl
my $scale = Term::Fabulous::Chart::Scale::Category->fit( labels => \@labels, cells => $cells, band => 1 );
```

`cells` is required; `labels` defaults to none, `band` to true (false
makes a point scale). Also takes `orientation` (default `horizontal`)
and `measure` like ["fit" in Term::Fabulous::Chart::Scale::Linear](Linear.md#fit). The
labels are shown as they are: a category scale takes no `format`.

# METHODS

Those of [Term::Fabulous::Chart::Scale](../Scale.md), and:

## labels, count

The labels and their number.

## slot\_cells

The cells one category takes along the axis; it can be a fraction.

# SEE ALSO

[Term::Fabulous::Chart::Scale](../Scale.md).
