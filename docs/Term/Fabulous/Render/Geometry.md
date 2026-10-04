# NAME

Term::Fabulous::Render::Geometry - Snap Clay's layout boxes to terminal cells

# SYNOPSIS

```perl
use Term::Fabulous::Render::Geometry qw(cell_rect intersect_cell_rects visible_cell_rect);

my ( $x0, $y0, $x1, $y1 ) = cell_rect( { x => 1.7, y => 2, width => 3.6, height => 2 } );    # (1, 2, 5, 4)
my $both    = intersect_cell_rects( [ 0, 0, 10, 5 ], [ 8, 3, 12, 9 ] );                      # [8, 3, 10, 5]
my @visible = visible_cell_rect( $command->{boundingBox}, $ui->clip_rect );
```

# DESCRIPTION

Most programs never use this module directly. It is used by the render
roles and the canvas widgets.

Clay places boxes at fractional positions, which may be negative or
reach past the viewport. Terminal output needs whole cells. These
functions convert boxes to cells the same way everywhere: the left edge
is `floor(x)`, the right edge `floor(x + width)`, and likewise for the
top and bottom.

Cell rectangles are written `[x0, y0, x1, y1]`: `x0`, `y0` is the
top-left cell, and `x1`, `y1` are _exclusive_, so the rectangle
covers the columns `x0 .. x1 - 1` and the rows `y0 .. y1 - 1`. A
rectangle with `x1 == x0` or `y1 == y0` is empty.

# FUNCTIONS

Nothing is exported by default. Import the functions you need by name.

## cell\_rect

```perl
my ( $x0, $y0, $x1, $y1 ) = cell_rect($bbox);
```

The cell rectangle of a Clay bounding box, a hash reference with `x`,
`y`, `width` and `height`, as a list. It is not clipped, so it may
lie partly or fully outside the viewport.

## intersect\_cell\_rects

```perl
my $common = intersect_cell_rects( $first, $second );
```

The cells two rectangles have in common, as a new array reference
`[x0, y0, x1, y1]`. When they do not overlap, the result is an empty
rectangle (`x1 == x0` or `y1 == y0`).

## visible\_cell\_rect

```perl
my ( $x0, $y0, $x1, $y1 ) = visible_cell_rect( $bbox, $clip );
```

["cell\_rect"](#cell_rect) of `$bbox`, intersected with the rectangle `$clip`
(usually ["clip\_rect" in Term::Fabulous::Render](../Render.md#clip_rect)), as a list. Returns
the empty list when nothing of the box is visible.

## rects\_overlap

```perl
if ( rects_overlap( $first, $second ) ) { ... }
```

True if the two rectangles share at least one cell. Rectangles that
only touch (one ends where the other starts) do not overlap.

## row\_spans\_outside

```perl
my @spans = row_spans_outside( $y, $x0, $x1, @rects );
```

The parts of row `$y` between the columns `$x0` (inclusive) and
`$x1` (exclusive) that none of the rectangles `@rects` covers, as a
list of `[from, to]` pairs (`to` exclusive), from left to right.
Without rectangles it returns the whole span `[$x0, $x1]`.

```perl
row_spans_outside( 1, 0, 10, [ 2, 0, 4, 3 ], [ 6, 1, 8, 2 ] );    # ([0, 2], [4, 6], [8, 10])
```

## cell\_coordinate

```perl
my $column = cell_coordinate( x => $x );
```

A coordinate or size given to a canvas drawing method, rounded down to
a whole cell: `3.9` becomes 3, `-0.5` becomes -1. Dies unless the
value is a finite number (NaN and infinities die); the first argument
names the value in the message:

```text
Term::Fabulous::Render::Geometry: x must be a finite number, got 'inf'
```

# SEE ALSO

[Term::Fabulous::Render](../Render.md), [Term::Fabulous::Render::Frame](Frame.md).
