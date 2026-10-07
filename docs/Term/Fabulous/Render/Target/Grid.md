# NAME

Term::Fabulous::Render::Target::Grid - Cell target that keeps the
painted cells in memory

# SYNOPSIS

```perl
use Term::Fabulous::Render::Target::Grid;

my $grid = Term::Fabulous::Render::Target::Grid->new;

# Term::Fabulous::Static and Term::Fabulous::Terminal::Memory paint
# into one; read it back:
my ( $glyph, $fg, $bg ) = @{ $grid->cell( 0, 0 ) };
my $line = $grid->row_text( 0, columns => 20, colors => 0 );
```

# DESCRIPTION

Most programs never use this module directly:
[Term::Fabulous::Static](../../Static.md) and [Term::Fabulous::Terminal::Memory](../../Terminal/Memory.md) paint
into a Grid and read it back as text. Use their `cell_target` to
inspect exactly what was painted into each cell, for example in tests.

This is a cell target (see ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target)) that
stores every painted cell instead of drawing it, built on
[Term::Fabulous::Render::Target::Mask](Mask.md). Each frame starts from an
empty grid, except for the kept rectangles of unchanged canvases.

# CONSTRUCTOR

## new

```perl
my $grid = Term::Fabulous::Render::Target::Grid->new;
my $grid = Term::Fabulous::Render::Target::Grid->new( sixel_cell_size => [ 10, 20 ] );
```

An empty grid; it grows to whatever is painted into it. With
`sixel_cell_size`, `[width, height]` in pixels, both whole numbers of
at least 1, it stands for a terminal that shows sixel graphics with
cells of that size, and records the pictures of every frame (see
["sixels"](#sixels)); without it, the default, it shows none, and
[Term::Fabulous::Widget::Sixel](../../Widget/Sixel.md) shows a notice. Unknown parameters
die.

# METHODS

## cell

```perl
my $cell = $grid->cell( $x, $y );
my ( $glyph, $fg, $bg ) = @$cell if $cell;
```

The cell at column `$x`, row `$y` (from 0) as an array reference
`[ $glyph, $fg, $bg ]`, or `undef` if nothing painted it in the last
frame.

- `$glyph` is a character string: the base character plus any combining
characters of its grapheme cluster.
- `$fg` and `$bg` are the termbox2 attributes the render roles computed
(see [Term::Fabulous::Render::Attr](../Attr.md)): `0xRRGGBB`, `TB_DEFAULT` (0) for
the terminal default color, `TB_HI_BLACK` for black, possibly
combined with flags such as `TB_REVERSE`. Background fills
store `TB_DEFAULT` as the foreground.
- A wide cluster (two columns) is stored in the cell it starts in only.
The cell to its right is not written for it: it holds whatever was
painted there earlier in the frame (usually the background fill, a
space) or `undef`. When you read a row cell by cell, skip as many cells
after a glyph as ["cluster\_columns" in Term::Fabulous::Unicode](../../Unicode.md#cluster_columns) reports for
it, as ["row\_text"](#row_text) does.

## row\_text

```perl
my $line = $grid->row_text( $y, columns => 80 );
my $line = $grid->row_text( $y, columns => 80, colors => 1, trim_trailing_whitespace => 0 );
```

Row `$y` as a line of text, `columns` cells wide (required); cells
nothing painted read as spaces, and a wide glyph takes the cells it
covers. Options:

- `colors`

    A boolean, default 0. When true, every run of cells with the same
    colors is preceded by an ANSI SGR sequence with 24-bit colors
    (`ESC [ 38;2;R;G;B m` for the foreground, `48;2;...` for the
    background), `7` (reverse video) for cells in reverse video, and `1`
    (bold), `2` (dim), `3` (italic), `4` (underline), `5` (blink), `8`
    (conceal), `9` (strikeout), `21` (double underline) and `53`
    (overline) for those termbox2 flags (the table
    ["STYLE\_FLAGS" in Term::Fabulous::Render::Attr](../Attr.md#style_flags)); the line ends with
    `ESC [ 0 m` when it set any. The terminal's default colors get no
    sequence.

- `trim_trailing_whitespace`

    A boolean, default 1. When true, cells at the end of the row that would
    print as plain spaces are left out: cells nothing painted, and spaces
    in the terminal's default background and not in reverse video.

Unknown options die. The
[`render_lines`](../../Static.md#render_lines) method of
Term::Fabulous::Static and the [`lines`](../../Terminal/Memory.md#lines)
method of Term::Fabulous::Terminal::Memory are built on it.

## grid\_height

```perl
my $rows = $grid->grid_height;
```

The number of rows up to and including the last row anything was
painted in.

## grid\_row

```perl
my $cells = $grid->grid_row($y);
```

The cells of row `$y` as an array reference of the values ["cell"](#cell)
returns, which may contain `undef` holes; an empty array reference for
a row nothing was painted in.

## painted\_cell

```perl
my ( $glyph, $fg, $bg ) = $grid->painted_cell( $x, $y );
```

The contents of ["cell"](#cell) as a list, or an empty list when the cell is
`undef`. See ["painted\_cell" in Term::Fabulous::Render](../../Render.md#painted_cell).

## sixels

```perl
foreach my $picture ( $grid->sixels ) {
        my ( $x, $y, $columns, $rows, $data ) = @{$picture}{qw(x y columns rows data)};
}
```

The sixel pictures of the last frame, as copies of the placements
["show\_sixels" in Term::Fabulous::Render::Target::Sixel](Sixel.md#show_sixels) describes: the
cell of the top left corner, the cells covered and the SIXEL data.
Empty without `sixel_cell_size`.

## Cell target methods

`begin_frame`, `end_frame`, `release_rect`, `set_cell`,
`extend_cell` and `fill_row` come from
[Term::Fabulous::Render::Target::Mask](Mask.md), which builds them on the
primitives below.

## clear\_cells

```perl
$grid->clear_cells(@kept_rects);
```

Primitive: forgets every cell outside the given `[x0, y0, x1, y1]`
rectangles (all cells without rectangles).

## present\_cells

Primitive. Does nothing.

## put\_cell

```perl
$grid->put_cell( $x, $y, $glyph, $fg, $bg );
```

Primitive: stores one cell.

## put\_extension

```perl
$grid->put_extension( $x, $y, $character );
```

Primitive: appends a combining character to a stored cell. Dies if
nothing was stored there.

## put\_row

```perl
$grid->put_row( $x, $y, $columns, $bg );
```

Primitive: stores `$columns` spaces with the background `$bg`.

## sixel\_cell\_size, sixel\_area, show\_sixels

The methods of [Term::Fabulous::Render::Target::Sixel](Sixel.md):
`sixel_cell_size` is the `sixel_cell_size` given to ["new"](#new), or empty;
`sixel_area` is the whole frame; `show_sixels` records the pictures
["sixels"](#sixels) returns.

# SEE ALSO

[Term::Fabulous::Static](../../Static.md), [Term::Fabulous::Terminal::Memory](../../Terminal/Memory.md),
["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target),
[Term::Fabulous::Render::Target::Mask](Mask.md).
