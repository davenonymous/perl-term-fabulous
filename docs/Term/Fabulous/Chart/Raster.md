# NAME

Term::Fabulous::Chart::Raster - A drawing surface with several subpixels
per terminal cell

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Marker;
use Term::Fabulous::Chart::Raster;

my $raster = Term::Fabulous::Chart::Raster->new(
        marker  => Term::Fabulous::Chart::Marker->named('braille'),
        columns => 40,    # cells
        rows    => 10,
);
# 80 x 40 subpixels
$raster->line( 0, 39, 79, 0, 0x3987e5, 'sales' );
$raster->start_pattern( [ 3, 2 ] )->line( 0, 20, 79, 20, 0xd95926 );
$raster->fill_rect( 10, 30, 20, 40, 0x199e70, undef, 0.4, 0x141923 );

$raster->each_cell( sub ( $x, $y, $colors, $owners, $drawn ) {
        my ( $glyph, $fg, $bg ) = $raster->marker->cell( $colors, 0x141923, $drawn );
        ...
} );
```

# DESCRIPTION

The chart widgets draw their series into rasters: grids of subpixels
whose size depends on the [Term::Fabulous::Chart::Marker](Marker.md) (2 x 4 per cell
for Braille, 1 x 8 for eighth blocks, ...). Each subpixel holds a color
(a packed `0xRRGGBB` integer) or nothing, and an owner: a value the chart
uses to find what is under the mouse.

Coordinates are in subpixels, from 0 at the top-left corner. Lines take
the subpixels they pass; fills take the subpixels whose centers lie
inside the shape, so two shapes that share an edge do not overlap. Drawing
outside the raster is ignored. A translucent fill (`$opacity` below 1)
mixes its color into the subpixel's color, or into `$base` where nothing
was drawn yet.

# CONSTRUCTOR

```perl
my $raster = Term::Fabulous::Chart::Raster->new( marker => $marker, columns => $cells, rows => $cells );
```

`marker` is a [Term::Fabulous::Chart::Marker](Marker.md) object; `columns` and
`rows` are the size in cells, non-negative integers. All three are
required.

# METHODS

## set, blend

```perl
$raster->set( $x, $y, $color, $owner );
$raster->blend( $x, $y, $color, $opacity, $base, $owner );
```

Draws one subpixel (whole coordinates). `blend` mixes `$opacity` (0 to
1) of `$color` into the subpixel's color, or into `$base` where nothing
was drawn yet. `$owner` is optional.

## line

```perl
$raster->line( $x0, $y0, $x1, $y1, $color, $owner, $opacity, $base );
```

Draws the subpixels on the line between two points (continuous
coordinates; the subpixels of both end points included), following the
dash pattern of ["start\_pattern"](#start_pattern). With `$opacity` below 1 the line is
blended as ["set, blend"](#set-blend) describes. Returns the raster.

## start\_pattern

```perl
$raster->start_pattern( [ $on, $off, ... ] );
$raster->start_pattern(undef);    # solid
```

Sets the dash pattern of the following lines and restarts it: run
lengths in subpixel steps, alternately drawn and skipped (`[ 3, 2 ]`:
three on, two off). The pattern runs on from one line to the next.
Returns the raster, so a line can follow.

## fill\_rect

```perl
$raster->fill_rect( $x0, $y0, $x1, $y1, $color, $owner, $opacity, $base );
```

The subpixels whose centers lie in the rectangle between two corners
(continuous coordinates, in either order). `$owner`, `$opacity`
(default 1) and `$base` work as for ["set, blend"](#set-blend).

## fill\_column

```perl
$raster->fill_column( $x, $top, $bottom, $color, $owner, $opacity, $base );
```

The subpixels of column `$x` whose centers lie between two heights
(continuous, in either order).

## fill\_polygon

```perl
$raster->fill_polygon( [ [ $x, $y ], ... ], $color, $owner, $opacity, $base );
```

The subpixels whose centers lie inside the polygon of the corners
(continuous coordinates), by the even-odd rule. Fewer than three
corners draw nothing.

## paint\_area

```perl
$raster->paint_area( $x0, $y0, $x1, $y1, sub ( $x, $y ) { return ( $color, $owner ) } );
```

Asks a function for the color of every subpixel from `($x0, $y0)` up
to, but not including, `($x1, $y1)` (whole numbers, cut to the
raster). A function that returns the empty list leaves the subpixel as
it is. Pie charts use it.

## color\_at, owner\_at

What one subpixel holds.

## each\_cell

```perl
$raster->each_cell( sub ( $cell_x, $cell_y, $colors, $owners, $drawn ) { ... } );
```

Visits every cell that has drawn subpixels, with the colors and owners of
its subpixels row by row (`undef` where nothing was drawn), and when each
was drawn: a number that is larger for later drawing.

## is\_empty

True while nothing was drawn.

## marker, columns, rows, width, height

The marker, the size in cells and the size in subpixels.

# SEE ALSO

[Term::Fabulous::Chart::Marker](Marker.md), [Term::Fabulous::Chart::Surface](Surface.md).
