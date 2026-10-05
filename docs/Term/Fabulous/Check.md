# NAME

Term::Fabulous::Check - Validate the values of widget properties

# SYNOPSIS

```perl
use Term::Fabulous::Check qw(positive_integer string color);

# In a widget class: each check returns the value to store, or dies.
$columns = positive_integer( $self, preferred_columns => $new[0] );
$label   = string( $self, label => $new[0] );
$color   = color( $self, accent_color => '#ff8800' );    # [ 255, 136, 0, 255 ]
```

# DESCRIPTION

Most programs never use this module directly. The widgets of
Term::Fabulous check the values of their constructor parameters and
accessors with it, so every property of a kind is checked the same way
and fails with the same wording. Use it in widget classes of your own
for the same reason.

Every function takes the _owner_ (the widget, or its class name), the
property name and the value. It returns the value as the widget stores
it (numbers as numbers, booleans as 1 or 0, colors as
`[r, g, b, a]`), or dies with a message in one wording:

```text
My::Widget: preferred_columns must be a positive integer, got '0'
My::Widget: label must be a string, got a HASH reference
My::Widget: accent_color must be a color, got 'nope' (unrecognized color string 'nope')
```

The message starts with the owner's class name and names the line that
called the check. Nothing is exported by default.

# FUNCTIONS

## positive\_integer

An integer of at least 1, written with digits only (`'12'`, `12`).

## non\_negative\_integer

An integer of at least 0, written with digits only.

## integer

An integer, written with digits and an optional leading minus.

## number

A finite number: no `inf`, no `nan`, no reference.

## string

A defined value that is not a reference. Numbers count as strings.

## boolean

Any plain value, stored as 1 (true in Perl) or 0. A reference dies, so
that a mistaken `[]` or `{}` does not count as true.

## glyph

A string of exactly one grapheme cluster that takes one terminal column
(see [Term::Fabulous::Unicode](Unicode.md)): the marks and track pieces of the
widgets.

## color

Any color [Term::Fabulous::Color](Color.md) accepts: a color string such as
`'#ff8800'`, `'rgb(255, 136, 0)'` or `'hsl(32, 100%, 50%)'`, an `[r, g, b, a]`
array, an `{ r, g, b, a }` hash or a Term::Fabulous::Color object.
Returns `[r, g, b, a]`, the form Clay::UI takes. `undef` dies; a
property that can be switched off handles `undef` before it checks.

## sizing

```perl
my $width = sizing( $self, 'width', 'fit(4, 30)' );    # the hash sizing_fit(4, 30) returns
```

One axis of a Clay sizing, as the `sizing` of a
["new" in Term::Fabulous::Widget](Widget.md#new) layout takes it: a hash returned by
`sizing_fit`, `sizing_grow`, `sizing_fixed` or `sizing_percent` of
[Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) (copied), or a string in the notation of KDL layouts:
`fit`, `grow`, `fit(MIN)`, `fit(MIN, MAX)`, `grow(MIN)`,
`grow(MIN, MAX)`, `fixed(N)` or `percent(P)` with `P` from 0 to 100.
Its messages differ from the others: `invalid NAME 'SPEC' (expected
...)`, `NAME minimum MIN is greater than maximum MAX in 'SPEC'` and
`NAME percentage must be in 0..100, got 'SPEC'`.

## cell\_color

Like ["color"](#color), and also a packed `0xRRGGBB` integer, opaque, as the
cells of a [Term::Fabulous::Widget::Canvas](Widget/Canvas.md) take it. Returns
`[r, g, b, a]`.

## one\_of

```perl
my $side = one_of( $self, side => $value, qw(top right bottom left) );
```

One of a fixed set of words, given after the value. Anything else
dies, listing the words in sorted order:
`My::Widget: side must be one of bottom, left, right, top, got 'middle'`.

## border\_style

```perl
my $style = border_style( $self, line_style => 'Double' );
my $line  = border_style( $self, column_lines => 'none', none => Term::Fabulous::Enum::BorderStyle->Hidden );
my $grid  = border_style( $self, line_style => $value, grid => 1 );
```

A [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item, given as the item or its
name (case sensitive, `'Round'`). Returns the item. Options:

- `none => $meaning`

    Also accept the word `'none'` and return `$meaning` for it (an item
    such as `Hidden`, or `undef`). Without this option `'none'` dies.

- `grid => 1`

    Accept only the styles with grid joints (see
    ["get\_grid\_styles" in Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md#get_grid_styles)).

The message lists the names it accepts:
`My::Widget: line_style must be a border style or its name, got 'Fancy' (known: Ascii, Blank, ...)`.

## value\_format

How a widget writes a number: `undef` (the widget's default), a
`sprintf` format string such as `'%d%%'` or a code reference.
Returns the value; anything else dies.

## optional

```perl
my $icon  = optional( \&string, $self, icon => $value );
my $style = optional( \&border_style, $self, border_style_top => $value );
```

Runs the check given as a code reference for a defined value, with the
owner, the name, the value and any further arguments; returns `undef`
for `undef`. For properties where `undef` means "none".

## describe

```perl
croak ref($self) . ": a slice label must be a string, got " . describe($label);
```

Not a check: the words the messages of this module use for a value, for
messages of your own. `undef` for an undefined value, `an ARRAY
reference`, `a HASH reference` and so on for references, and the value
in single quotes otherwise (`'nope'`).

# SEE ALSO

[Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md), [Term::Fabulous::Color](Color.md),
["WRITING YOUR OWN WIDGETS" in Term::Fabulous::Manual::CustomWidgets](Manual/CustomWidgets.md#writing-your-own-widgets).
