# NAME

Term::Fabulous::Render::Border - Paint widget borders in their border styles

# SYNOPSIS

```perl
# Composed by Term::Fabulous::Render; called from draw for every
# border render command:
$ui->render_border( $command, $widget, $buffer );
```

# DESCRIPTION

Most programs never use this module directly, and neither do widgets
of your own: a widget gets its border from the parameters described in
["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders). This module is one of the
roles [Term::Fabulous::Render](../Render.md) is made of, and it paints the border render
commands Clay emits for widgets with a `border_width`, using the
widget's border styles (see [Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md) and
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md)).

# METHODS

## render\_border

```perl
$ui->render_border( $command, $widget, $buffer );
```

Paints the border of `$widget`:

- Nothing is painted unless `$widget` composes
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md).
- A side is painted when its border width in the command is positive.
Whatever the width, a side is one cell thick: it is drawn on the
outermost row or column of the widget's box. Corners are drawn where a
painted top or bottom side meets a painted left or right side;
otherwise the top or bottom edge glyph continues to the end of the row.
In a box only one cell high, the top and bottom sides would share the
same row: when both are to be drawn, only the top side is. Likewise in
a box one cell wide only the left side is drawn when both the left and
the right side are to be drawn. A side with the `Hidden` style arrives
with a width of 0 (see [Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md)), so it
is not painted and the neighboring sides treat it like a side without a
width.
- Each side uses the style it is drawn in, as
["border\_style\_of" in Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md#border_style_of) answers: the
widget's own style for that side, else the one the widget derives,
else the theme's style for the widget's family, else the `Blank`
style (spaces). A corner
the widget names in `border_corners` is drawn with that glyph instead
(see ["border\_corners" in Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md#border_corners)), in the
colors of the style's corner.
- Each glyph is colored according to its style's location code (see
["locations" in Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md#locations)): the border color in
front of either the widget's own background (the background already
painted in that cell, read from `$buffer`) or the parent's background
(the background of the cell just outside the box, also read from
`$buffer`), possibly in reverse video.
- A side the widget lists in `outer_border_sides` (see
["outer\_border\_sides" in Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md#outer_border_sides)) is drawn on
the parent's background: its glyphs with location code 0 are drawn as
code 1, those with code 3 as code 2, and codes 1 and 2 stay. A corner is
drawn this way, with the background of the cell beside the box, when
the left or right side next to it is listed; otherwise it follows its
top or bottom side.
- Only cells inside the current clip area are painted.

`$command` is a Clay render command hash (see
["RENDER COMMANDS" in Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS#RENDER-COMMANDS)); `$buffer` is the array reference of rows
of background attributes, `$buffer->[$y][$x]`, that
[Term::Fabulous::Render::Rectangle](Rectangle.md) and the other paint roles fill
during the frame.

# REQUIRED METHODS

The consuming class provides `cell_target`, which returns the cell
target the border is painted into (its `set_cell` is called; see
["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target)), and `clip_rect` (from
[Term::Fabulous::Render](../Render.md), see ["clip\_rect" in Term::Fabulous::Render](../Render.md#clip_rect)).

# SEE ALSO

[Term::Fabulous::Render](../Render.md), [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md),
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md), ["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders).
