# NAME

Term::Fabulous::Render::Text - Paint lines of text

# SYNOPSIS

```perl
# Composed by Term::Fabulous::Render; called from draw for every
# text render command:
$ui->render_text( $command, $widget, $buffer );
```

# DESCRIPTION

Most programs never use this module directly, and neither do widgets
of your own. It is one of the roles [Term::Fabulous::Render](../Render.md) is made
of, and it paints the text render commands Clay emits for
[Term::Fabulous::Widget::Text](../Widget/Text.md) widgets. Clay breaks a widget's text
into lines; each text command is one line. Read it if you write your
own UI class or want to know exactly how text is drawn.

# METHODS

## render\_text

```perl
$ui->render_text( $command, $widget, $buffer );
```

Paints one line of text, starting at the top-left cell of the command's
bounding box, in the command's text color with the style bits of the
widget (bold, italic, underline; see
["style\_attrs" in Term::Fabulous::Widget::Text](../Widget/Text.md#style_attrs)), when the widget has any:

- The text (`stringContents`, a character string) has its control
characters replaced (see ["sanitize\_text" in Term::Fabulous::Unicode](../Unicode.md#sanitize_text)) and
is split into grapheme clusters.
- Every cluster advances by the number of columns termbox2 uses for it
(see ["cluster\_columns" in Term::Fabulous::Unicode](../Unicode.md#cluster_columns)), so measuring and
drawing agree.
- The line ends before the first cluster that would cross the right edge
of the bounding box or of the clip area. Clusters left of the clip area
are not painted but still advance.
- The background of each cell is the one recorded in `$buffer` (an array
reference of rows of attributes, `$buffer->[$y][$x]`) by whatever
was painted there before in this frame, or the terminal default.

The line is skipped when its row lies outside the clip area. Segmented
lines are cached by their text (the cache is emptied when it reaches
4096 entries), because texts rarely change between frames.

# REQUIRED METHODS

The consuming class provides `cell_target`, which returns the cell
target the text is painted into (its `set_cell` and `extend_cell` are
called; see ["CELL TARGET" in Term::Fabulous::Render](../Render.md#cell-target)), and `clip_rect`
(from [Term::Fabulous::Render](../Render.md), see ["clip\_rect" in Term::Fabulous::Render](../Render.md#clip_rect)).

# SEE ALSO

[Term::Fabulous::Render](../Render.md), [Term::Fabulous::Widget::Text](../Widget/Text.md),
[Term::Fabulous::Unicode](../Unicode.md).
