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

Primitive: `tb_present`, then the sixel pictures that must be sent
(see ["show\_sixels"](#show_sixels)), each after a cursor move to its top left cell;
then in inline mode the cursor goes to the start of the region.

## put\_cell, put\_extension, put\_row

Primitives: `tb_set_cell`, `tb_extend_cell` and `tb_print` of
spaces, at the terminal row of the frame row.

## painted\_cell

```perl
my ( $glyph, $fg, $bg ) = $cells->painted_cell( $x, $y );
```

Reads a cell back from termbox2's back buffer (`tb_get_cell`). See
["painted\_cell" in Term::Fabulous::Render](../../Render.md#painted_cell).

## set\_sixel\_cell\_size

```perl
$cells->set_sixel_cell_size( 10, 20 );
$cells->set_sixel_cell_size;
```

Called by [Term::Fabulous::Terminal::Termbox](../Termbox.md): the terminal shows
sixel graphics with cells of the given width and height in pixels,
whole numbers of at least 1; without arguments, it shows none. Anything
else dies.

## sixel\_cell\_size

```perl
my ( $width, $height ) = $cells->sixel_cell_size;
```

From [Term::Fabulous::Render::Target::Sixel](../../Render/Target/Sixel.md): the last
["set\_sixel\_cell\_size"](#set_sixel_cell_size), empty at first.

## sixel\_area

```perl
my $rect = $cells->sixel_area( $width, $height );
```

From [Term::Fabulous::Render::Target::Sixel](../../Render/Target/Sixel.md): the frame without the
terminal's last row. A picture that reaches it makes the terminal
scroll the screen up, as the cursor moves below the picture.

## show\_sixels

```perl
$cells->show_sixels(@placements);
```

From [Term::Fabulous::Render::Target::Sixel](../../Render/Target/Sixel.md): the pictures of the
frame being painted, which ["present\_cells"](#present_cells) shows. termbox2 sends only
the cells that changed since the last frame, and knows nothing of the
pictures, so ["present\_cells"](#present_cells):

- makes termbox2 draw the cells of a picture of the last frame that is
not shown again at the same place with the same data
(`tf_invalidate_cells`), which erases it;
- sends a picture that is new, moved or changed, or whose cells termbox2
draws in this frame (`tf_cells_differ`), since drawing a cell erases
the picture's pixels there.

## forget\_sixels

```perl
$cells->forget_sixels;
```

Forgets the pictures on the screen and those of the frame being
painted, for a new termbox2 session, which starts with a clear screen.

# SEE ALSO

[Term::Fabulous::Terminal::Termbox](../Termbox.md), ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target),
[Term::Fabulous::Render::Target::Mask](../../Render/Target/Mask.md), [Term::Fabulous::Termbox](../../Termbox.md).
