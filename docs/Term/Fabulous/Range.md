# NAME

Term::Fabulous::Range - A value in a range, on a grid of steps

# SYNOPSIS

```perl
use Term::Fabulous::Range;

my $range = Term::Fabulous::Range->new( owner => 'My::Dial', min => 0, max => 1, step => 0.1, value => 0.3 );

$range->value;                  # 0.3
$range->set_value(0.46);        # 0.5: snapped to the grid
$range->move_by_key('Right');   # 1: the value moved to 0.6
$range->move_by_key('End');     # 1: to 1
$range->move_by_key('End');     # 0: it is there already
$range->move_by_key('Tab');     # undef: not a key of a range
$range->fraction;               # 1
$range->format_value(0.6);      # '0.6'

$range->set_range( min => -1 );   # the value stays on the new grid
```

# DESCRIPTION

The value of a widget that picks a number from a range: a
[Term::Fabulous::Widget::Slider](Widget/Slider.md), a
[Term::Fabulous::Widget::StarRating](Widget/StarRating.md) (its half stars are a step of
0.5) and a [Term::Fabulous::Widget::ProgressBar](Widget/ProgressBar.md) (a range without a
step). It holds `min`, `max`, an optional `step` and the value;
checks a range as a whole; snaps a value to the grid `min`,
`min + step`, ... and limits it to the range; moves the value by keys,
steps and pages; reports the fraction of the range; and writes a value
as text.

It knows nothing of widgets or events. A method that moves the value
the way a user does returns whether the value changed, and the widget
fires its `Change` event then. Errors start with the `owner` given to
the constructor, the widget's class.

# CONSTRUCTOR

## new

```perl
my $range = Term::Fabulous::Range->new( owner => ref($self), min => $min, max => $max, step => $step, value => $value );
```

- `owner`

    Required. The name the error messages start with.

- `min`, `max`

    Finite numbers, `min` below `max`. Default `min`: 0; `max` is
    required.

- `step`

    A positive number or `undef` (the default): with a step, values lie
    on the grid `min`, `min + step`, ... up to the last grid value at or
    below `max`; without one, a value is any number in the range.

- `value`

    The value, in the range. Default: `min`. Snapped to the grid.

- `page_step`

    How far `PageUp` and `PageDown` move: a positive number, or `undef`
    (the default) for a tenth of the range, rounded to whole steps and at
    least one step.

- `paging`

    A boolean. Default: 1. When false, `PageUp` and `PageDown` are not
    keys of the range (["move\_by\_key"](#move_by_key) returns `undef` for them).

- `value_format`

    `undef` (the default), a `sprintf` format string or a code
    reference, as ["value\_format" in Term::Fabulous::Check](Check.md#value_format) checks it; see
    ["format\_value"](#format_value).

- `default_format`

    A code reference that writes a value when `value_format` is `undef`;
    it gets the value and the range. Default: none, the value with
    ["decimals"](#decimals) digits after the point.

- `format_percent`

    A boolean. Default: 0. When true, a `sprintf` `value_format` gets the
    value's percentage of the range and a code reference gets the value
    and its fraction, as a [Term::Fabulous::Widget::ProgressBar](Widget/ProgressBar.md) documents.

Invalid values die: `OWNER: min (5) must be less than max (5)`,
`OWNER: step must be positive, got 0`, `OWNER: value must be in 0..10, got 12`,
and the messages of [Term::Fabulous::Check](Check.md).

# METHODS

## min, max, step

The range. Change it with ["set\_range"](#set_range).

## set\_range

```perl
$range->set_range( min => 200, max => 300 );
```

Changes `min`, `max` and `step` together and checks the result as a
whole, so a new range can be set in one go whatever the old one was.
The value moves into the new range and onto its grid. Unknown parts
die (`OWNER: set_range takes min, max and step, got low`; a range
without a step takes only `min` and `max`). Returns the range.

## value

The value.

## set\_value

```perl
$range->set_value(42);
```

Sets the value as the program does: dies for a number outside the range,
snaps it to the grid and returns it.

## move\_to

```perl
my $changed = $range->move_to($number);
```

Moves the value as the user does: to the grid value nearest to the
number, limited to the range. Returns 1 when the value changed, else 0.

## move\_by

```perl
my $changed = $range->move_by(-1);            # a step down
my $changed = $range->move_by( 1, 'page' );   # a page up
```

Moves by a number of steps (or pages) with ["move\_to"](#move_to). A range without
a step moves by a tenth of a page.

## move\_by\_key

```perl
my $changed = $range->move_by_key( $event->main_key_name );
```

Moves as a key asks: `Left` and `Down` a step down, `Right` and
`Up` a step up, `PageDown` and `PageUp` a page (see `paging`),
`Home` to `min` and `End` to the highest grid value. Returns
`undef` for any other key, else what ["move\_to"](#move_to) returns.

## fraction, fraction\_of

```perl
my $share = $range->fraction;             # of the value
my $share = $range->fraction_of($number);
```

Where a number lies in the range, from 0 at `min` to 1 at `max`.

## snapped

```perl
my $on_grid = $range->snapped($number);
```

The grid value nearest to a number, limited to the range; without a
step, the number limited to the range.

## top\_value

The highest grid value: `max` when the range is a whole number of
steps.

## decimals

The digits after the decimal point that the grid needs: enough for the
step and for `min` (`0.25` has 2, `1e-12` has 12). Snapped values are
rounded to them, so they print without floating-point noise.

## page\_step, set\_page\_step

```perl
my $page = $range->page_step;
$range->set_page_step(25);
$range->set_page_step(undef);    # a tenth of the range again
```

## value\_format, set\_value\_format

The format given (see `value_format` above), and a writer that checks
it.

## format\_value

```perl
my $text = $range->format_value($number);
```

A value as text: with a code reference `value_format`, what it returns
for the value (and its fraction, with `format_percent`); with a format
string, `sprintf` of the value (or of its percentage); else the
`default_format`; else the value with ["decimals"](#decimals) digits.

# SEE ALSO

[Term::Fabulous::Role::HasRange](Role/HasRange.md), [Term::Fabulous::Widget::Slider](Widget/Slider.md),
[Term::Fabulous::Widget::StarRating](Widget/StarRating.md),
[Term::Fabulous::Widget::ProgressBar](Widget/ProgressBar.md).
