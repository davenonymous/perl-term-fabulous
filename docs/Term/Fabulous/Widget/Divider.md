# NAME

Term::Fabulous::Widget::Divider - A line between widgets, with an
optional text

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Divider;
use Term::Fabulous::Enum::BorderStyle;

# A line across the parent:
my $rule = Term::Fabulous::Widget::Divider->new;

# With a text in the middle, at the start or at the end:
my $section = Term::Fabulous::Widget::Divider->new( text => 'Settings' );
my $heading = Term::Fabulous::Widget::Divider->new( text => 'Files', text_position => 'start', bold => 1 );
my $footer  = Term::Fabulous::Widget::Divider->new( text => 'end of list', text_position => 'end' );

# Heavier, in color, or vertical between two columns:
my $heavy  = Term::Fabulous::Widget::Divider->new( line_style => Term::Fabulous::Enum::BorderStyle->Double, color => '#61afef' );
my $column = Term::Fabulous::Widget::Divider->new( vertical => 1 );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-divider.svg" alt="Dividers: a plain line, texts at the start, the center and the end, double and heavy lines in colors, and a vertical divider with a text between two columns"></p>
</div>

# DESCRIPTION

The picture shows dividers in their forms: a plain line, lines with a
text at the start, in the center and at the end, lines in other styles
and colors, and a vertical divider with a text between two columns. The
program is `examples/widgets/divider.pl`.

A divider separates the widgets above and below it (or left and right
of it, when it is vertical) with a line:

```text
────────────── Settings ──────────────
── Files ─────────────────────────────
───────────────────────── end of list ──
```

The line is drawn with the horizontal (or vertical) glyph of a
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md), `Solid` unless told otherwise,
or with any glyph of your own. The text sits on the line with
`text_padding` spaces on each side, and, at the start or the end,
`text_margin` cells of line between it and the edge. A vertical
divider writes its text downwards, one character per row. A text that
does not fit is left out, and the line is drawn alone.

A divider takes no input and has no natural length of its own: it
grows along its line to the space its parent gives it (see ["SIZE"](#size)),
and is one cell thick. Being a [Term::Fabulous::Widget::Display](Display.md), it
is painted again only when something about it changed.

# CONSTRUCTOR

## new

```perl
my $divider = Term::Fabulous::Widget::Divider->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Box](Box.md#constructor)
(`id`, `layout`, `background_color`, the border parameters, ...)
and the ones below. All are optional; unknown parameters die.

- `vertical`

    A boolean. Default: 0, a horizontal line. True draws a vertical line
    and writes the text downwards. Stored as 1 or 0; a reference dies.

- `text`

    A character string. Default: `''` (no text). Dies if not a string.

- `text_position`

    `start`, `center` (the default) or `end`: where the text sits along
    the line. Anything else dies.

- `text_margin`

    A non-negative integer. Default: 1. The cells of line between the edge
    and the text when it sits at the start or the end. When the line is
    too short for the margin, the text moves to the edge.

- `text_padding`

    A non-negative integer. Default: 1. The spaces on each side of the
    text.

- `line_style`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item, or the name of one
    (`'Double'`). Default: `Solid`. The line is drawn with the style's
    top glyph, or its left glyph when the divider is vertical:
    `Solid` and `Round` give a thin line, `Heavy` a thick one,
    `Double` a double line, `Dashed` a dashed one, `Ascii` `-` or `|`,
    `Thick`, `Block` and the shade styles block characters. Anything
    else dies, naming the known styles.

- `glyph`

    A single character one column wide, or `undef`. Default: `undef`,
    the glyph of `line_style`. A glyph of your own for the line, such as
    `'='` or `'.'`; it wins over `line_style`. Anything else dies.

- `color`

    The color of the line, in any format
    ["Colors" in Term::Fabulous::Widget::Canvas](Canvas.md#colors) accepts. Default:
    `[90, 96, 110, 255]`, a gray.

- `text_color`

    The color of the text. Default: `[150, 160, 180, 255]`, a lighter
    gray.

- `bold`

    A boolean. Default: 0. Whether the text is bold.

# METHODS

The methods of [Term::Fabulous::Widget::Display](Display.md) (`mark_changed`, the
Box and Canvas methods), plus an accessor for each constructor
parameter. Without an argument each returns the current value; with
one it sets the value, checked as `new` checks it, marks the divider
changed (so the next frame paints it) and returns the new value. An
invalid value dies and leaves the old one.

## vertical

```perl
$divider->vertical(1);
```

Returns 1 or 0.

## text

```perl
$divider->text('Advanced');
```

## text\_position

```perl
$divider->text_position('start');
```

## text\_margin

```perl
$divider->text_margin(4);
```

## text\_padding

```perl
$divider->text_padding(0);
```

## line\_style

```perl
$divider->line_style( Term::Fabulous::Enum::BorderStyle->Heavy );
$divider->line_style('Heavy');
```

The reader returns the [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item, also
when a name was written.

## glyph

```perl
$divider->glyph('=');
$divider->glyph(undef);    # back to the style's glyph
```

## color

```perl
$divider->color('#61afef');
```

The reader returns `[r, g, b, a]`.

## text\_color

```perl
$divider->text_color( [ 255, 255, 255 ] );
```

The reader returns `[r, g, b, a]`.

## bold

```perl
$divider->bold(1);
```

Returns 1 or 0.

## line\_glyph

```perl
my $glyph = $divider->line_glyph;    # "\x{2500}"
```

The glyph the line is drawn with now: `glyph`, or the glyph of
`line_style` for the divider's direction. Read-only.

# SIZE

A divider grows along its line: without a `sizing` in its `layout`
it is as wide (or, vertical, as high) as its parent lets it be, and
one cell thick (a vertical divider is as thick as its widest
character). With a text, the length is at least the text with its
padding, a cell of line on each side and the margin. Inside a parent
that fits its content, a divider without a text has no length to grow
into; give it a fixed sizing then:

```perl
layout => { sizing => { width => sizing_fixed(30) } }
```

A horizontal divider that is more than one row high draws its line in
the middle row; a vertical one that is wider than its line draws it in
the middle column. See ["Size" in Term::Fabulous::Widget::Display](Display.md#size).

# EVENTS

A divider fires no events of its own. It paints every cell of its
line, so it receives `Mouse` events for clicks on it.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`vertical` and `bold` (`#true` / `#false`), `text`,
`text_position`, `text_margin`, `text_padding`, `line_style` (the
name of a border style) and `glyph` (strings), and `color` and
`text_color` (color strings):

```kdl
use Term::Fabulous::Widget::Divider as Divider

Divider "settings" {
        text "Settings"
        text_position "start"
        line_style "Double"
        color "#61afef"
        bold #true
}
```

# EXAMPLES

## A section heading

```perl
my $heading = Term::Fabulous::Widget::Divider->new(
        text          => 'Network',
        text_position => 'start',
        text_margin   => 2,
        bold          => 1,
        text_color    => [ 255, 255, 255, 255 ],
);
```

## Two columns with a line between them

```perl
use Clay::XS qw(sizing_grow);

my $row = Term::Fabulous::Widget::Box->new( layout => { child_gap => 1, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$row->add_child( $left, Term::Fabulous::Widget::Divider->new( vertical => 1 ), $right );
```

# SEE ALSO

[Term::Fabulous::Widget::Display](Display.md), [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md),
["DIVIDERS" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#dividers),
["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders).
