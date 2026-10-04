# NAME

Term::Fabulous::Render::Target::Mask - Base role of the cell targets:
protect kept cells during a frame

# SYNOPSIS

```perl
use v5.32;
use Object::Pad 0.825;
use Term::Fabulous::Render::Target::Mask;

# A cell target that records which cells were written.
class My::Target::Log :does(Term::Fabulous::Render::Target::Mask) {
        field @written;

        method clear_cells (@kept_rects)            { @written = (); return }
        method present_cells ()                     { say scalar(@written), ' cells'; return }
        method put_cell ( $x, $y, $glyph, $fg, $bg ) { push @written, [ $x, $y, $glyph ]; return }
        method put_extension ( $x, $y, $character ) { $written[-1][2] .= $character; return }
        method put_row ( $x, $y, $columns, $bg )    { push @written, map { [ $_, $y, ' ' ] } $x .. $x + $columns - 1; return }

        # Not a primitive of this role, but every target needs it.
        method painted_cell ( $x, $y ) {
                my ($cell) = grep { $_->[0] == $x && $_->[1] == $y } reverse @written;
                return defined $cell ? ( $cell->[2], 0, 0 ) : ();
        }
}
```

# DESCRIPTION

Most programs never use this module directly. Read on if you want to
paint Term::Fabulous frames somewhere other than the terminal
([Term::Fabulous::Terminal::Termbox::Cells](../../Terminal/Termbox/Cells.md)) or memory
([Term::Fabulous::Render::Target::Grid](Grid.md)).

A _cell target_ is the object that receives the cells
[Term::Fabulous::Render](../../Render.md) paints (see
["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target)). The class of a cell target
composes this role. This role implements the
target methods the renderer calls (`begin_frame`, `end_frame`,
`release_rect`, `set_cell`, `extend_cell`, `fill_row`) on top of
five simple primitives that a concrete target provides; the target
also provides `painted_cell` (see ["REQUIRED METHODS"](#required-methods)). On the way, it
implements _kept rectangles_: parts of the previous frame that must
stay as they are, because an unchanged canvas is there (see
["Painting only the changes" in Term::Fabulous::Render::Canvas](../Canvas.md#painting-only-the-changes)). Writes
into a kept rectangle are dropped until the rectangle is released.

# METHODS

## begin\_frame

```perl
$target->begin_frame(@kept_rects);
```

Remembers the kept `[x0, y0, x1, y1]` rectangles and calls
["clear\_cells"](#clear_cells) with them.

## end\_frame

```perl
$target->end_frame;
```

Forgets all kept rectangles and calls ["present\_cells"](#present_cells).

## release\_rect

```perl
$target->release_rect($rect);
```

Stops protecting one kept rectangle. `$rect` must be the same array
reference that was given to ["begin\_frame"](#begin_frame).

## set\_cell

```perl
$target->set_cell( $x, $y, $glyph, $fg, $bg );
```

Calls ["put\_cell"](#put_cell), unless the cell lies in a kept rectangle.

## extend\_cell

```perl
$target->extend_cell( $x, $y, $character );
```

Calls ["put\_extension"](#put_extension), unless the cell lies in a kept rectangle.

## fill\_row

```perl
$target->fill_row( $x, $y, $columns, $bg );
```

Calls ["put\_row"](#put_row) for the parts of the row that lie outside every kept
rectangle.

# REQUIRED METHODS

A role or class composing this role provides these primitives. They are
called with coordinates inside the viewport only.

## clear\_cells

```perl
method clear_cells (@kept_rects) { ... }
```

Resets every cell outside the given rectangles to empty (a space in the
terminal default colors), and leaves the cells inside them as the
previous frame left them. Without rectangles, resets everything.

## present\_cells

```perl
method present_cells () { ... }
```

Shows the finished frame, if the target needs a step for that.

## put\_cell

```perl
method put_cell ( $x, $y, $glyph, $fg, $bg ) { ... }
```

Writes one cell: `$glyph` is a character string of one character,
`$fg` and `$bg` are termbox2 attributes (see
[Term::Fabulous::Render::Attr](../Attr.md)).

## put\_extension

```perl
method put_extension ( $x, $y, $character ) { ... }
```

Appends a combining character (a character string of length one) to the
cell written last at that position.

## put\_row

```perl
method put_row ( $x, $y, $columns, $bg ) { ... }
```

Writes `$columns` cells of spaces with the background attribute `$bg`
and the terminal default foreground, from `($x, $y)` to the right.

## painted\_cell

```perl
method painted_cell ( $x, $y ) { ... }
```

Not used by this role, but the renderer calls it on every target (see
["painted\_cell" in Term::Fabulous::Render](../../Render.md#painted_cell)): returns the glyph, foreground
and background attribute painted at a cell in this frame, or an empty
list. It is called only for a translucent background with
`glyphs_show_through`, but a target without it dies there.

# SEE ALSO

["CELL TARGET" in Term::Fabulous::Render](../../Render.md#cell-target),
[Term::Fabulous::Terminal::Termbox::Cells](../../Terminal/Termbox/Cells.md),
[Term::Fabulous::Render::Target::Grid](Grid.md).
