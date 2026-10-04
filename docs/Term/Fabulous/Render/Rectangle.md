# NAME

Term::Fabulous::Render::Rectangle - Paint widget backgrounds

# SYNOPSIS

```perl
# Composed by Term::Fabulous::Render; called from draw for every
# rectangle render command:
$ui->render_rectangle( $command, $widget, $buffer );
```

# DESCRIPTION

Most programs never use this module directly, and neither do widgets
of your own. It is one of the roles [Term::Fabulous::Render](../Render.md) is made
of, and it paints the rectangle render commands Clay emits for widget
backgrounds (`background_color`). Read it if you write your own UI
class or want to know exactly how backgrounds are painted and blended.

# METHODS

## render\_rectangle

```perl
$ui->render_rectangle( $command, $widget, $buffer );
```

Paints the cells of the command's bounding box that lie inside the
command's clip rect (see ["clip\_rect" in Term::Fabulous::Render](../Render.md#clip_rect)) in
the command's background color. It also records the resulting
background of every painted cell in `$buffer`, an array reference of
rows of attributes indexed `$buffer->[$y][$x]`, so that text and
borders drawn on top later in the frame know the background below them.

An opaque color (alpha 255) fills the cells with spaces, using the
target's `fill_row`. A translucent color (alpha 1 to 254) is blended
with the background `$buffer` holds for each cell
(["blended\_bg\_attr" in Term::Fabulous::Render::Attr](Attr.md#blended_bg_attr)), and then one of two
things happens, depending on the widget's `glyphs_show_through`
(["glyphs\_show\_through" in Term::Fabulous::Widget](../Widget.md#glyphs_show_through)):

- Off (the default, also when `$widget` is not a
[Term::Fabulous::Widget](../Widget.md)): the cells are covered with spaces in the
blended colors, one `fill_row` per run of equal color.
- On: every cell is read back from the target (`painted_cell`) and
repainted with the glyph found there, its foreground tinted with the
same color (["blended\_fg\_attr" in Term::Fabulous::Render::Attr](Attr.md#blended_fg_attr)); a cell
holding nothing or a space becomes a space. The cells a wide glyph
covers are not touched.

When `$widget` is a [Term::Fabulous::Widget](../Widget.md) whose
`reverse_video` method returns true (a pressed
[Term::Fabulous::Widget::Button](../Widget/Button.md), see
["reverse\_video" in Term::Fabulous::Widget::Button](../Widget/Button.md#reverse_video)), every background attribute
gets the `TB_REVERSE` flag. The text and borders painted on top later
take their background from `$buffer`, flag included, so the whole
widget is shown with swapped colors.

Clay never emits a rectangle for a color with alpha 0.

`$command` is a Clay render command hash (see
["RENDER COMMANDS" in Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS#RENDER-COMMANDS)); `$widget` is the widget it belongs to.

# REQUIRED METHODS

The consuming class provides `cell_target`, which returns the cell
target the background is painted into (its `fill_row`, `set_cell`,
`extend_cell` and `painted_cell` are called; see
["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target)), and `clip_rect` (from
[Term::Fabulous::Render](../Render.md), see ["clip\_rect" in Term::Fabulous::Render](../Render.md#clip_rect)).

# SEE ALSO

[Term::Fabulous::Render](../Render.md), [Term::Fabulous::Render::Frame](Frame.md).
