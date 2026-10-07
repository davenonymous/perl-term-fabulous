# NAME

Term::Fabulous::Render::Target::Sixel - Role of the cell targets that
show sixel pictures

# SYNOPSIS

```perl
use v5.32;
use Object::Pad 0.825;
use Term::Fabulous::Render::Target::Mask;
use Term::Fabulous::Render::Target::Sixel;

class My::Target
        :does(Term::Fabulous::Render::Target::Mask)
        :does(Term::Fabulous::Render::Target::Sixel)
{
        field @pictures;

        method sixel_cell_size ()              { return ( 10, 20 ) }    # or () without sixel
        method sixel_area ( $width, $height )  { return [ 0, 0, $width, $height ] }
        method show_sixels (@placements)       { @pictures = @placements; return }

        # ... the primitives of Term::Fabulous::Render::Target::Mask
}
```

# DESCRIPTION

Most programs never use this module directly. Read on if you write a
cell target (see ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target)) that can show
the pictures of [Term::Fabulous::Widget::Sixel](../../Widget/Sixel.md).

Sixel pictures are not cells: the terminal draws them over the cells,
from the cell at the cursor on. A cell target that composes this role
tells [Term::Fabulous::Render](../../Render.md) the size of a cell in pixels, and the
renderer hands it the pictures of every frame, with the cells each one
covers, after the frame's cells are painted and before
`end_frame`. A target without this role, or one whose
["sixel\_cell\_size"](#sixel_cell_size) is empty, shows no pictures: the Sixel widgets show
a notice instead.

The role has no methods of its own; the target provides all three.
[Term::Fabulous::Terminal::Termbox::Cells](../../Terminal/Termbox/Cells.md) composes it for the real
terminal, [Term::Fabulous::Render::Target::Grid](Grid.md) for
[Term::Fabulous::Terminal::Memory](../../Terminal/Memory.md) and [Term::Fabulous::Static](../../Static.md).

# REQUIRED METHODS

## sixel\_cell\_size

```perl
my ( $width, $height ) = $target->sixel_cell_size;
```

The width and the height of a cell in pixels, both whole numbers of at
least 1, when the target can show sixel pictures; else an empty list.
The answer may change between frames, for example when the terminal's
font size changes.

## sixel\_area

```perl
my $rect = $target->sixel_area( $width, $height );
```

The `[x0, y0, x1, y1]` rectangle of cells a picture may cover in a
frame of `$width` x `$height` cells, inside the frame. The renderer
cuts every picture to it. A terminal leaves out its last row, for
example, because a picture that reaches it makes the screen scroll.

## show\_sixels

```perl
$target->show_sixels(@placements);
```

Called once per frame, after the frame's cells are painted and before
`end_frame`, with the frame's pictures in paint order, none when the
frame has none. Each placement is a hash reference:

- `x`, `y`

    The cell the picture's top left corner covers.

- `columns`, `rows`

    The cells the picture covers, at least 1 each; the picture is
    `columns` times the cell width wide and `rows` times the cell height
    high.

- `data`

    The picture as SIXEL data: a byte string that starts with `ESC P`.

The pictures of a frame replace those of the frame before: a picture
that is not given again must disappear, and the cells it covered must
show what the frame painted there. Transparent pixels of a picture
leave the cells below them visible; the renderer makes the pixels of
cells that something painted over the picture transparent.

# SEE ALSO

[Term::Fabulous::Widget::Sixel](../../Widget/Sixel.md), ["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target),
[Term::Fabulous::Render::Target::Mask](Mask.md).
