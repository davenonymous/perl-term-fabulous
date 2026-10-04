# NAME

Term::Fabulous::Terminal::Termbox::Cells - Cell target that paints into
the terminal through termbox2

# SYNOPSIS

```perl
# Created and placed by Term::Fabulous::Terminal::Termbox:
my $cells = $terminal->cell_target;
$cells->place_region( $top, $rows );    # inline mode
$cells->place_region( undef, undef );   # full screen
```

# DESCRIPTION

Most programs never use this module directly. It is the cell target
(see ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target)) of
[Term::Fabulous::Terminal::Termbox](../Termbox.md): it writes the painted cells into
termbox2's back buffer and shows the frame with `tb_present`, which
sends only the cells that changed since the last frame. It builds on
[Term::Fabulous::Render::Target::Mask](../../Render/Target/Mask.md), so it also provides
`begin_frame`, `end_frame`, `release_rect`, `set_cell`,
`extend_cell` and `fill_row`.

In inline mode, row 0 of a frame is the first row of the region, and
the hidden cursor is left at the start of that row after every frame.
The terminal must be open (`tb_init` or `tf_init_inline`);
otherwise termbox2 ignores the drawing.

# METHODS

## place\_region

```perl
$cells->place_region( $top, $rows );
```

Paints into the `$rows` rows of an inline region starting at the
terminal row `$top` (from 0); with `undef` for both, into the whole
screen, which is the default. Dies when only one of them is given.

## region\_top, region\_rows

The values of the last ["place\_region"](#place_region): `undef` for the full screen.

## clear\_cells

Primitive for [Term::Fabulous::Render::Target::Mask](../../Render/Target/Mask.md). Without kept
rectangles, clears the back buffer (`tb_clear`); otherwise overwrites
every cell of the screen (or region) outside them with a space in the
default colors, so that the kept cells hold what the previous frame
painted.

## present\_cells

Primitive: `tb_present`, then in inline mode the cursor goes to the
start of the region.

## put\_cell, put\_extension, put\_row

Primitives: `tb_set_cell`, `tb_extend_cell` and `tb_print` of
spaces, at the terminal row of the frame row.

## painted\_cell

```perl
my ( $glyph, $fg, $bg ) = $cells->painted_cell( $x, $y );
```

Reads a cell back from termbox2's back buffer (`tb_get_cell`). See
["painted\_cell" in Term::Fabulous::Render](../../Render.md#painted_cell).

# SEE ALSO

[Term::Fabulous::Terminal::Termbox](../Termbox.md), ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target),
[Term::Fabulous::Render::Target::Mask](../../Render/Target/Mask.md), [Term::Fabulous::Termbox](../../Termbox.md).
