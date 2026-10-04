# NAME

Term::Fabulous::Chart::Surface - The cells of a chart while it is drawn

# SYNOPSIS

```perl
use Term::Fabulous::Chart::Surface;
use Term::Fabulous::Termbox qw(TB_BOLD);

# $raster is a Term::Fabulous::Chart::Raster, $canvas the chart's canvas.
my $surface = Term::Fabulous::Chart::Surface->new( columns => 40, rows => 12, background => 0x141923 );
$surface->text( 0, 0, 'Sales', 0xFFFFFF, flags => TB_BOLD );
$surface->put( $_, 5, "\x{2500}", 0x2c3340 ) foreach 0 .. 39;    # a grid line
$surface->composite( $raster, 'stroke' );                       # lines over it
my $owner = $surface->owner_near( 12, 4 );                        # what the mouse is on
$surface->paint($canvas);
```

# DESCRIPTION

A chart widget draws a frame in a surface first and copies it into its
canvas cells at the end. A surface holds a glyph, a foreground color, a
background color and style bits per cell (colors as packed `0xRRGGBB`
integers), and two owner maps that record what was drawn where: lines and
points in the `stroke` layer, fills (bars, areas, slices, legend entries)
in the `fill` layer. The owners let the chart find what the mouse
pointer is on.

Rasters ([Term::Fabulous::Chart::Raster](Raster.md)) are drawn over the cells with
["composite"](#composite): their marker turns each cell's subpixels into a glyph over
the background the cell has at that moment, so a line drawn over an area
fill keeps the fill as its background.

# METHODS

## new

```perl
Term::Fabulous::Chart::Surface->new( columns => $columns, rows => $rows, background => $rgb );
```

`columns` and `rows` (non-negative integers) are required.
`background` is what every cell shows at first (`undef` for the
terminal's default background).

## columns, rows, background

The size and the background given to the constructor.

## fill

```perl
$surface->fill( $x, $y, $width, $height, $rgb );
```

Sets the background of a rectangle and removes its glyphs.

## put

```perl
$surface->put( $x, $y, $glyph, $fg, $bg, $flags );
```

Sets one cell to a glyph one column wide. An `undef` background keeps the
cell's background; `$flags` are termbox2 style bits such as `TB_BOLD`.

## text

```perl
my $columns = $surface->text( $x, $y, $text, $fg, bg => $rgb, flags => TB_BOLD, max => 20 );
```

Writes a character string, two cells per wide character. With `max`, text
wider than that is cut and ends in an ellipsis. Returns the number of
columns written; text that would cross the right edge is cut there.

## text\_columns

```perl
my $width = Term::Fabulous::Chart::Surface->text_columns($text);
```

The columns `text` takes for a string (a class method).

## composite

```perl
$surface->composite( $raster, $layer, $left, $top );
```

Draws a raster over the surface, the raster's cell (0, 0) at
`($left, $top)` (default: 0, 0). `$layer` is `stroke` or `fill`:
each drawn cell is owned in that layer by the owner most of its
subpixels have. Dies for another layer.

## set\_owner, owner

```perl
$surface->set_owner( $x, $y, $layer, $owner );
my $owner = $surface->owner( $x, $y, $layer );
```

Set and read the owner of one cell in a layer (`stroke` or `fill`);
charts set the owners of the points they draw as characters.

## owner\_near

The owner the pointer at a cell points at: a stroke in the cell, else a
fill in the cell, else a stroke in one of the eight neighbors. `undef`
when there is none.

## glyph\_at, fg\_at, bg\_at, flags\_at, contains

Read one cell.

## paint

```perl
$surface->paint($canvas);
```

Clears the canvas and writes every cell into it. Cells that only show the
surface's background stay unset.

## lines

The glyphs as one string per row; for tests.

# SEE ALSO

[Term::Fabulous::Chart::Raster](Raster.md), [Term::Fabulous::Widget::Chart](../Widget/Chart.md).
