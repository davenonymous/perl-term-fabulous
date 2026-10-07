# NAME

Term::Fabulous::Render::Frame - What one frame paints, command by
command

# SYNOPSIS

```perl
use Term::Fabulous::Render::Frame;

my $frame = Term::Fabulous::Render::Frame->new(
        commands => $ui->render,    # Clay's render commands
        width    => $ui->width,
        height   => $ui->height,
);

foreach my $index ( 0 .. $frame->command_count - 1 ) {
        my $command = $frame->command($index);
        my ( $x0, $y0, $x1, $y1 ) = @{ $frame->clip_rect($index) };
        ...
}

# The commands painted at a cell, the topmost first.
my @indices = $frame->topmost_at( 12, 3 );
```

# DESCRIPTION

Most programs never use this module directly. [Term::Fabulous::Render](../Render.md)
builds a Frame from the render commands Clay laid out, before it paints
any of them, and keeps the Frame of the last frame
(["last\_frame" in Term::Fabulous::Render](../Render.md#last_frame)). [Term::Fabulous](../../../../README.md) hit-tests the
mouse pointer with it, and [Term::Fabulous::Render::Canvas](Canvas.md) uses it to
decide which canvases can keep their cells.

A Frame is read-only. It works out (the painted cells on the first call
that needs them, the rest when it is constructed):

- the paint order

    The order of Clay's commands, with one addition: Clay carries the
    background of a canvas in the canvas's own command, and the frame
    paints it as a rectangle right before that command.

- the clip rect of every command

    The rectangle of cells the command may paint into: the viewport
    (`[0, 0, width, height]`), narrowed to the innermost scissor around
    the command. Clay surrounds the content of a clipping element, such as
    a [scroll box](../Widget/ScrollBox.md), with a `SCISSOR_START`
    and a `SCISSOR_END` command; a scissor nested inside another is
    narrowed to it. Boxes are snapped to whole cells like everywhere else
    (see ["cell\_rect" in Term::Fabulous::Render::Geometry](Geometry.md#cell_rect)).

- the cells every command paints

    Rectangles, text and canvases paint their box, borders the one-cell
    edge of every side whose Clay border width is greater than 0, and
    scissors nothing; all of them only inside their clip rect.

# CONSTRUCTOR

## new

```perl
my $frame = Term::Fabulous::Render::Frame->new( commands => \@commands, width => 80, height => 24 );
```

`commands` is an array reference of render commands in the format of
["RENDER COMMANDS" in Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS#RENDER-COMMANDS), in the order Clay emitted them; `width`
and `height` are the size of the viewport in cells, numbers of at
least 0. The command hashes are kept as they are, not copied.

Dies with a message starting with `Term::Fabulous::Render::Frame:`
when an argument is invalid, when a command has a type other than
rectangle, border, text, scissor start or end and custom
(`unhandled render command type IMAGE`; Term::Fabulous widgets produce
only these), and when a `SCISSOR_END` has no open scissor.

# METHODS

All `$index` arguments are positions in the paint order, from 0 to
`command_count - 1`; any other value dies.

## commands

```perl
my @commands = $frame->commands;
```

The render commands in paint order. The hashes are Clay's own: read
them, do not change them. Use `$ui->widget_for( $command->{userData} )`
to get the widget a command belongs to.

## command\_count

```perl
my $count = $frame->command_count;
```

The number of commands.

## command

```perl
my $command = $frame->command($index);
```

One command, as in ["commands"](#commands).

## width, height

```perl
my ( $columns, $rows ) = ( $frame->width, $frame->height );
```

The size of the viewport the Frame was built for.

## clip\_rect

```perl
my ( $x0, $y0, $x1, $y1 ) = @{ $frame->clip_rect($index) };
```

The rectangle of cells the command may paint into, as a new array
reference `[x0, y0, x1, y1]`. `x1` and `y1` are exclusive, so the
rectangle covers the columns `x0 .. x1 - 1` and the rows
`y0 .. y1 - 1`. When a scissor lies outside the viewport, the
rectangle is empty (`x1 == x0` or `y1 == y0`). A command outside its
clip rect, such as content scrolled out of a scroll container, paints
nothing.

## painted\_rects

```perl
my @rects = $frame->painted_rects($index);
```

The non-empty `[x0, y0, x1, y1]` rectangles the command paints, as new
array references; none for a scissor or for a command outside its clip
rect, up to four (one per edge) for a border.

## painted\_after

```perl
my $covered = $frame->painted_after( $index, [ $x0, $y0, $x1, $y1 ] );
```

1 when a command painted after the one at `$index` paints into the
given rectangle, otherwise 0. A canvas that something is painted over
cannot keep its cells from the last frame.

## painted\_over

```perl
my @rects = $frame->painted_over( $index, [ $x0, $y0, $x1, $y1 ] );
```

The parts of the given rectangle that commands painted after the one at
`$index` paint into, as `[x0, y0, x1, y1]` rectangles, one per
painted rectangle of those commands; they may overlap. Empty when
nothing is painted over the rectangle. A sixel picture leaves these
cells out.

## topmost\_at

```perl
my @indices = $frame->topmost_at( $x, $y );
```

The indices of the commands that paint the cell `($x, $y)`, the
topmost (the one painted last) first. Empty when nothing is painted
there.

# SEE ALSO

[Term::Fabulous::Render](../Render.md), [Term::Fabulous::Render::Geometry](Geometry.md),
[Term::Fabulous::Render::Canvas](Canvas.md).
