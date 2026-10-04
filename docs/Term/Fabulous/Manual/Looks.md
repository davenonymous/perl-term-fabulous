# NAME

Term::Fabulous::Manual::Looks - Text, colors and borders

# DESCRIPTION

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Layout](Layout.md). Next page: [Term::Fabulous::Manual::Events](Events.md).

This page explains how widgets look: how a Text widget shows text
(character strings, wrapping, alignment, line height, bold, italic and
underlined text, wide characters and control characters), how colors
are written and how translucent colors are blended, how borders are
drawn (border styles, per-side styles, widths, colors and borders that
join the lines around them), and how a theme colors every widget at
once (the built-in themes, theme files, variants, switching at run
time). Every feature is shown in a picture, with the Perl code and,
where a layout file can set it, the form it takes in a
[KDL layout file](KDL.md#kdl-layout-files).

The reference pages for this topic are
[Term::Fabulous::Widget::Text](../Widget/Text.md), [Term::Fabulous::Color](../Color.md),
[Term::Fabulous::Enum::WebColor](../Enum/WebColor.md), [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md),
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md) and [Term::Fabulous::Theme](../Theme.md).
Complete programs are in [Term::Fabulous::Cookbook::GettingStarted](../Cookbook/GettingStarted.md)
(non-ASCII text, wrapping and alignment) and
[Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md) (per-side border styles, switching
themes).

# TEXT

[Term::Fabulous::Widget::Text](../Widget/Text.md) shows text in one color. Text wraps at
spaces when it is wider than the room its parent gives it, and a `"\n"`
in the text starts a new line.

```perl
my $label = Term::Fabulous::Widget::Text->new(
        text       => 'Disk usage: 42%',
        text_color => [ 230, 230, 230, 255 ],
);
$label->text('Disk usage: 43%');    # shown in the next frame
```

In a KDL layout file:

```kdl
Text "usage" {
        text "Disk usage: 42%"
        text_color "#e6e6e6"
}
```

Without a `text_color`, a Text is drawn in the theme's text color
(["THEMES"](#themes)): a light gray in the built-in `dark` theme, a dark gray
in `light`. To use the terminal's default text color instead, pass
`[0, 0, 0, 0]` (see ["Alpha and the terminal default color"](#alpha-and-the-terminal-default-color)).

A Text widget has no background, border or padding of its own; put it in
a [Term::Fabulous::Widget::Box](../Widget/Box.md) for those. The program
`examples/text-features.pl` shows the text features described in this
section side by side; the panels behind the texts show how much room each Text
takes:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-text-features.svg" alt="Text wrapped at spaces in a narrow panel and text broken only at newlines; a two-line text with line height 2; plain, bold, italic, underlined and combined styles; Latin, Japanese, emoji and combining accents ending in the same column; a tab shown as a space and control characters shown as replacement characters"></p>
</div>

## Text is character strings

**The `text` of a Text widget is a Perl character string**, like all text
in Term::Fabulous: the input widgets (`value`, `label`, `placeholder`,
options), the canvas drawing methods, [Term::Fabulous::Editor](../Editor.md),
[Term::Fabulous::Unicode](../Unicode.md) and
`Term::Fabulous::Layout->new( string => ... )`. With `use utf8;`,
non-ASCII literals in your source work directly:

```perl
use utf8;                 # this source file contains non-ASCII text

my $greeting = Term::Fabulous::Widget::Text->new(
        text       => 'Grüße aus München',
        text_color => [ 255, 255, 255, 255 ],
);
$greeting->text('Schöne Grüße');
```

Text that comes from outside the program (files, command output,
sockets, `@ARGV`) is bytes. Decode it first with
`Encode::decode('UTF-8', ...)`; otherwise each byte shows as a
character of its own, so "ü" shows as two wrong characters:

```perl
use Encode qw(decode);

chomp( my $hostname = `hostname` );    # bytes
$label->text( decode( 'UTF-8', $hostname ) );
```

Text in a KDL layout file is already a character string and is passed
to the Text widget as is. The recipe
[Show non-ASCII text](../Cookbook/GettingStarted.md#show-non-ascii-text-umlauts-cjk-combining-accents)
is a complete program.

## Wrapping

The `wrap_mode` parameter of a Text widget decides where lines break.
Import the constants from [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS):

- `CLAY_TEXT_WRAP_WORDS` (the default)

    Breaks at spaces when the text is wider than the room it gets, and at
    every `"\n"`. The first panel of the picture at the start of
    ["TEXT"](#text) shows it: a text in a box 24 columns wide, wrapped at spaces.

- `CLAY_TEXT_WRAP_NEWLINES`

    Breaks only at `"\n"`. The Text is as wide as its longest line: a parent
    with `fit` sizing grows to it (the second panel in the picture), while
    a line that is wider than a fixed-size parent runs past the parent's
    right edge and is cut off only at the edge of the terminal or of an
    enclosing [Term::Fabulous::Widget::ScrollBox](../Widget/ScrollBox.md).

- `CLAY_TEXT_WRAP_NONE`

    The same as `CLAY_TEXT_WRAP_NEWLINES`: `"\n"` still starts a new
    line, and nothing else does. The layout engine Clay lays out both modes
    alike (it only distinguishes `CLAY_TEXT_WRAP_WORDS` from the others), so
    use `CLAY_TEXT_WRAP_NEWLINES`; to show text on one line, remove its
    newlines.

```perl
use Clay::XS qw(CLAY_TEXT_WRAP_NEWLINES);

my $listing = Term::Fabulous::Widget::Text->new(
        text       => join( "\n", @lines ),
        text_color => [ 230, 230, 230, 255 ],
        wrap_mode  => CLAY_TEXT_WRAP_NEWLINES,
);
```

Only spaces are break points. A word longer than the available width
is not broken, and neither is text without spaces, such as a Japanese
sentence: it runs past the right edge of its parent and is cut off only
at the edge of the terminal or of an enclosing ScrollBox. A tab is not a
break point either (see ["Control characters"](#control-characters)).

In a KDL layout file, write `wrap_mode newlines` (`words`,
`newlines` or `none`).

## Alignment

`text_alignment` aligns each line within the width of the Text widget:
`CLAY_TEXT_ALIGN_LEFT` (the default), `CLAY_TEXT_ALIGN_CENTER` or
`CLAY_TEXT_ALIGN_RIGHT`, from [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS).

```perl
use Clay::XS qw(CLAY_TEXT_ALIGN_CENTER);

my $notice = Term::Fabulous::Widget::Text->new(
        text           => "Saved.\nThe file was written to disk.",
        text_color     => [ 230, 230, 230, 255 ],
        text_alignment => CLAY_TEXT_ALIGN_CENTER,
);
```

The Text widget is as wide as its longest line (or as the room it
gets, when it wraps), so alignment is visible on text with several
lines. The picture of [Term::Fabulous::Widget::Text](../Widget/Text.md) shows the same
wrapped sentence aligned left, centered and aligned right:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text.svg" alt="Colored words, a sentence wrapped left-aligned, centered and right-aligned, and text in five scripts"></p>
</div>

To center a single line, or any widget, in a wider box, use the box's
`child_alignment` (see
["Aligning and centering children" in Term::Fabulous::Manual::Layout](Layout.md#aligning-and-centering-children)). In
a KDL layout file, write `text_alignment center` (`left`, `center`
or `right`). The recipe
[Wrap, align and space text](../Cookbook/GettingStarted.md#wrap-align-and-space-text)
prints every wrap mode and alignment.

## Line height

`line_height` is the number of rows each line of text takes, an
integer. The default, 0, means one row, like 1. With a larger value the
line is drawn in the middle row of its rows (the upper middle row when
the number is even), so `line_height => 2` leaves an empty row
below every line:

```perl
my $spaced = Term::Fabulous::Widget::Text->new(
        text        => "First line\nSecond line",
        text_color  => [ 230, 230, 230, 255 ],
        line_height => 2,
);
```

In a KDL layout file, write `line_height 2`.

## Bold, italic and underline

The boolean parameters `bold`, `italic` and `underline` draw the
characters of a Text widget in these styles; they can be combined, and
they take no space. The terminal draws them with its font, so a font
without an italic face shows italic text upright.

```perl
my $warning = Term::Fabulous::Widget::Text->new(
        text       => 'Unsaved changes',
        text_color => [ 255, 200, 80, 255 ],
        bold       => 1,
);
$warning->underline(1);    # shown in the next frame
```

In a KDL layout file:

```kdl
Text {
        text "Unsaved changes"
        text_color "#ffc850"
        bold #true
        underline #true
}
```

These are the only text styles a Text widget has. To show text in
reverse video (swapped colors), give its box a `background_color` and
the Text a dark `text_color` instead.

## Wide characters and emoji

A terminal cell holds one character. Some characters, most CJK
characters and many emoji, take two cells. Term::Fabulous measures text
the same way termbox2 draws it (with termbox2's own width tables, see
[Term::Fabulous::Unicode](../Unicode.md)), so wide characters line up as long as the
locale is UTF-8 and the terminal agrees with termbox2 about each
character's width. In the picture at the start of ["TEXT"](#text), four lines
of Latin letters, Japanese, emoji and combining accents all end in the
same column.

Characters made of several code points (a _grapheme cluster_), such as
a letter with a combining accent or a flag, are kept together and take
the width of the whole cluster: `"e\x{301}"` (an e and a combining
acute accent) takes one cell. An emoji presentation selector (U+FE0F),
a zero-width joiner or a pair of regional indicators makes a cluster two
cells wide. Use
[string\_columns](../Unicode.md#string_columns) from
[Term::Fabulous::Unicode](../Unicode.md) to find out
how many columns a string takes, for example to pad a label:

```perl
use Term::Fabulous::Unicode qw(string_columns);

my $columns = string_columns('日本語');    # 6
```

## Control characters

Control characters in text are never sent to the terminal, because they
could move the cursor or change terminal settings. A tab becomes one
space; every other control character (U+0000 to U+001F except tab and
newline, U+007F to U+009F) is shown as U+FFFD, the replacement
character. That includes a carriage return: remove the `"\r"` of
Windows line ends (`s/\r\n/\n/g`) before you show such text. In Text
widgets, a newline starts a new line, as described in ["Wrapping"](#wrapping).
The last line of the picture at the start of ["TEXT"](#text) shows a tab, a
bell character and an escape sequence. See
["sanitize\_text" in Term::Fabulous::Unicode](../Unicode.md#sanitize_text) for the exact rules.

## Font parameters

The parameters `font_id`, `font_size` and `letter_spacing` exist
because [Clay::UI::Text](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AText) supports graphical fonts. They have no effect
in a terminal, where every character is drawn in the terminal's font.

# COLORS

Colors are red, green, blue and alpha (opacity) channels, each from 0 to
255\. Term::Fabulous always draws with 24-bit colors.

## Color formats

Every color a widget takes, and every color argument of the canvas
drawing methods, accepts the same formats: anything
`Term::Fabulous::Color->new( color => ... )` accepts.

- Perl code

    | Format                 | Example                         | Alpha          |
    | ---------------------- | ------------------------------- | -------------- |
    | hex string             | '#ff8800' or 'ff8800'           | 255            |
    | hex string with alpha  | '#ff880080'                     | the last pair  |
    | rgb() string           | 'rgb(255, 136, 0)'              | 255            |
    | rgba() string          | 'rgba(255, 136, 0, 0.5)'        | the 4th value  |
    | hsl() string           | 'hsl(32, 100%, 50%)'            | 255            |
    | hsla() string          | 'hsla(32, 100%, 50%, 50%)'      | the 4th value  |
    | array reference        | [ 255, 136, 0 ] or [ ..., 128 ] | 255 or the 4th |
    | hash reference         | { r => 255, g => 136, b => 0 }  | 255 or a/alpha |
    | packed integer         | 0xFF8800                        | 255            |
    | Term::Fabulous::Color  | Term::Fabulous::Color->hex(...) | its alpha      |
    | named color (WebColor) | WebColor->DarkOrange            | 255            |

    A hash takes either the keys `r`, `g`, `b` (and `a`) or `red`,
    `green`, `blue` (and `alpha`). The alpha of `rgba()` and `hsla()`
    can be a channel value (`128`), a fraction with a decimal point
    (`0.5`) or a percentage (`50%`); see ["new" in Term::Fabulous::Color](../Color.md#new) for
    all rules. Color names as strings (`'orange'`) and three-digit hex
    (`'#f80'`) are not accepted; use [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md) for
    named colors. An invalid color dies with the name of the parameter:

    ```text
    Term::Fabulous::Widget::Box: background_color must be a color, got 'red' (unrecognized color string 'red')
    ```

    Colors in some of these formats:

    ```perl
    use Term::Fabulous::Enum::WebColor;

    my $box = Term::Fabulous::Widget::Box->new(
            background_color => '#14192b',
            border_color     => Term::Fabulous::Enum::WebColor->SteelBlue,
    );
    my $text = Term::Fabulous::Widget::Text->new( text => 'Hello', text_color => 'hsl(210, 20%, 90%)' );
    ```

    The widgets store their colors as an array reference `[r, g, b, a]`,
    whatever format was given, and their accessors return that array:
    `$box->background_color` returns `[20, 25, 43, 255]` above.

- KDL layout files

    Every property whose name ends in `_color`, and the `color` of a
    `border` node, takes a string in any of the string formats above:

    ```kdl
    background_color "#14192b"
    text_color "rgb(220, 220, 220)"
    border color="hsl(210, 80%, 60%)"
    ```

    For a named color, write its hex value; the
    [table of named colors](../Enum/WebColor.md#colors) lists them.

The program `examples/colors.pl` shows one orange in six formats, the
color functions of ["Working with colors"](#working-with-colors), red backgrounds with less
and less alpha, and the terminal's default text color:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-colors.svg" alt="Six orange swatches written in different formats; a blue darkened, lightened and blended with white in steps; red swatches with alpha 255, 192, 128, 64 and 0 over a light panel; a line in the terminal's default text color"></p>
</div>

## Named colors

[Term::Fabulous::Enum::WebColor](../Enum/WebColor.md) has the 148 named colors of CSS as
[Term::Fabulous::Color](../Color.md) objects. Give one wherever a color is
expected, or derive new colors from it:

```perl
use Term::Fabulous::Enum::WebColor;

my $box = Term::Fabulous::Widget::Box->new( background_color => Term::Fabulous::Enum::WebColor->MidnightBlue );
my $by_name = Term::Fabulous::Enum::WebColor->from_name('Tomato');    # undef for unknown names
```

`examples/web-colors.pl` shows all of them; see the picture on
[Term::Fabulous::Enum::WebColor](../Enum/WebColor.md).

## Alpha and the terminal default color

Alpha has three meanings:

- Alpha 0

    "No color": the terminal's default color is used (the color the
    terminal shows when a program sets none). A box with
    `background_color => [0, 0, 0, 0]`, or without a background color,
    paints no background, so whatever is behind it shows, text and borders
    included. A `text_color` or `border_color` with alpha 0 draws in the
    terminal's default text color.

- Alpha 255

    The color is drawn opaque.

- Alpha 1 to 254

    Translucent. A `background_color` with such an alpha is blended, cell
    by cell, with whatever was drawn below the widget, like a sheet of
    tinted glass: `[0, 0, 0, 128]` dims the area below to half its
    brightness. What happens to the text and borders below is up to the
    widget's [glyphs\_show\_through](../Widget.md#glyphs_show_through).
    Off, the default, covers them with spaces in the blended color. On,
    they stay visible through the background, with their colors tinted the
    same way, until the widget draws its own content over them.

    Only backgrounds are blended. Text colors, border colors, the colors of
    the input widgets and the cell colors of a canvas with such an alpha
    are drawn opaque.

```perl
my $dimmer = Term::Fabulous::Widget::Box->new(
        background_color    => [ 0, 0, 0, 128 ],    # half-transparent black
        glyphs_show_through => 1,                   # the text below stays readable
);
```

In a KDL layout file: `background_color "rgba(0, 0, 0, 0.5)"` and
`glyphs_show_through #true`.

The terminal default color cannot be blended, because only the terminal
knows which color it shows for it. Where the color below a translucent
background is the default, the background is drawn opaque, and a glyph
showing through with the default text color keeps it.
`examples/translucency.pl` shows all of this, with translucent boxes
orbiting over a screen of text:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-translucency.svg" alt="A green, a red and a blue translucent box over a screen of text; the text shows through the green and the blue one"></p>
</div>

Black is a real color: `[0, 0, 0, 255]` is drawn as black, not as the
terminal's default.

## Working with colors

[Term::Fabulous::Color](../Color.md) parses colors and derives new ones, which is
useful for themes. Colors are immutable; every method returns a new
object.

```perl
use Term::Fabulous::Color;

my $accent  = Term::Fabulous::Color->hex('#3b82f6');
my $hover   = $accent->lighten(0.1);                                     # 10 percentage points lighter
my $pressed = $accent->darken(0.1);                                      # 10 percentage points darker
my $muted   = $accent->blend( Term::Fabulous::Color->rgb( 128, 128, 128 ), 0.5 );    # halfway to gray
my $glass   = $accent->with_alpha(128);                                  # translucent

$box->background_color($hover);
my ( $r, $g, $b, $a ) = $pressed->to_rgba;
my $hex = $muted->hexString;                                             # '#5e81bbff'
```

The other constructors are `rgb`, `rgba`, `hsl` and `hsla`; the
other methods read channels (`red`, `to_hsl`, `rgb_int`, ...) and
write ANSI escape sequences (`ansi`, `fg_sgr`, ...). See
[Term::Fabulous::Color](../Color.md) for all of them. To color every widget at
once, and to switch all the colors at run time, use a theme
(["THEMES"](#themes)).

# BORDERS

Every widget except [Term::Fabulous::Widget::Text](../Widget/Text.md) can have a border:
boxes, buttons, scroll boxes, dialogs, canvases, charts, tables and the
input widgets. Three parameters control it:

- `border_width`

    Which sides have a border, and how much room it takes: a number for
    all four sides, or a hash reference such as
    `{ left => 1, top => 1 }` (missing sides have no border).
    See ["Border width and space"](#border-width-and-space).

- `border_style`

    A [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) item that decides the characters
    of all four sides; `border_style_top`, `border_style_right`,
    `border_style_bottom` and `border_style_left` set one side each. See
    ["Border styles"](#border-styles) and ["Use a different border style on each side"](#use-a-different-border-style-on-each-side).

- `border_color`

    The color of the border characters, in the formats described in
    ["Color formats"](#color-formats). Without one, the border is drawn in the terminal's
    default text color.

```perl
use Term::Fabulous::Enum::BorderStyle;

my $panel = Term::Fabulous::Widget::Box->new(
        border_width => 1,
        border_style => Term::Fabulous::Enum::BorderStyle->Round,
        border_color => [ 120, 170, 255, 255 ],
);
```

In a KDL layout file, the style and the color are attributes of the
`border` node, and the width is a property of its own:

```kdl
Box "panel" {
        border style=Round color="#78aaff"
        border_width 1
}
```

A border needs both a width and a style: a style without a width draws
nothing, and a side with a width but no style is drawn with spaces (the
`Blank` style).

## Border styles

[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) has 20 styles: `Ascii`,
`Blank`, `Block`, `DarkShade`, `Dashed`, `Double`, `Heavy`,
`Hidden`, `Hkey`, `Inner`, `LightShade`, `MediumShade`, `Outer`,
`Panel`, `Round`, `Solid`, `Tall`, `Thick`, `Vkey` and `Wide`.
Each is a class method that returns the style object; to look one up by
name (for example from a configuration file), use `from_name`:

```perl
my $style = Term::Fabulous::Enum::BorderStyle->from_name('Double')
        // die "unknown border style\n";
```

`Hidden` switches a side off: it draws nothing and takes no space,
whatever its width. Some styles (`Block`, `Panel`, `Tall`, `Wide`,
`Inner`) draw half of their characters on the background outside the
widget, so that the border blends into the parent; they look best when
the widget and its parent have different background colors.
`examples/border-showcase.pl` shows all styles:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-border-showcase.svg" alt="Twenty boxes, one in each border style, labeled with the style's name"></p>
</div>

## Use a different border style on each side

The four side parameters set the style of one side each. A side
parameter wins over `border_style` for its side, also when both are
given to `new`; `border_style` fills the sides that have no style of
their own. The side accessors change one side afterwards:

```perl
my $card = Term::Fabulous::Widget::Box->new(
        border_width      => 1,
        border_style      => Term::Fabulous::Enum::BorderStyle->Solid,    # all four sides ...
        border_style_left => Term::Fabulous::Enum::BorderStyle->Thick,    # ... except the left one
);
$card->border_style_top( Term::Fabulous::Enum::BorderStyle->Double );    # then change the top
```

In a KDL layout file, the side styles are the attributes `style-top`,
`style-right`, `style-bottom` and `style-left` of the `border` node:

```kdl
border style=Solid style-left=Thick style-top=Double
```

The top and bottom sides own the corners: where the top or bottom row
meets a drawn left or right side, the corner glyph comes from the style
of the top or bottom side. There is no `border_style` accessor; to
change all four sides, call the four side accessors. The recipe
[Use a different border style on each side](../Cookbook/Layout.md#use-a-different-border-style-on-each-side) is a
complete program.

## Border width and space

A border is drawn on the outermost cells of the widget, inside its box,
and takes room in the layout: Term::Fabulous adds the width of every
side to that side's padding, so the content always starts inside the
border, and the `padding` of the widget's `layout` is extra room
between the border and the content. A widget with `fit` sizing grows
by the border. See also
["Borders take space" in Term::Fabulous::Manual::Layout](Layout.md#borders-take-space).

Only one line of border characters is drawn per side. A width larger
than 1 adds empty cells inside the line: `border_width => 2` is a
border plus one cell of padding. Each width is an integer from 0 to
65535; any other value dies. A hash takes the keys `left`, `right`,
`top` and `bottom`; Clay's `between_children` key is not supported.
A side with the `Hidden` style takes no space, whatever its width, so
the content reaches that edge of the widget; use it to switch a side
off without changing `border_width`.

```perl
my $rule = Term::Fabulous::Widget::Box->new(    # a line above and at the left only
        border_width => { left => 1, top => 1 },
        border_style => Term::Fabulous::Enum::BorderStyle->Solid,
);
```

In a KDL layout file: `border_width left=1 top=1`.

`examples/border-options.pl` shows a border on two sides, per-side
styles, `border_width => 2`, a `Hidden` side and the two
parameters of ["Joining borders"](#joining-borders):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-border-options.svg" alt="Six bordered panels: a border on the left and top only; a solid border with a double top and a thick left side; a round border of width 2 with an empty cell inside; a round border with a hidden bottom side; a title box and a body box sharing one line; a round border drawn on the parent's background"></p>
</div>

## Border colors

The characters of a border are drawn in the `border_color`. Their
background is usually the widget's own background. Some styles use the
background just outside the widget, or reverse video, for some
characters so that the border blends with its surroundings; the
[location codes](../Enum/BorderStyle.md#locations) of the
border styles say which. Change the color like any other color:

```perl
$panel->border_color('#ff5050');    # shown in the next frame
```

A widget that was given no `border_color` or no `border_style` takes
them from the theme, where the theme has them for the widget's family
(a button, a dialog, a toast, ...); see ["THEMES"](#themes). A plain Box has
none in the built-in themes, so its border is drawn in the terminal's
default color and, without a style, with spaces.

## Joining borders

Two more parameters let a border join the lines around it. Both are set
in Perl code only; KDL layout files have no property for them.

- `border_corners`

    Replaces the glyph of any corner, for example `├` instead of `┌`
    where a line comes in from above. The class method
    [junction](../Enum/BorderStyle.md#junction) of
    [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) returns the glyph where
    lines of given styles meet: a line, a corner, a T or a cross, also
    where lines of different styles meet (a light line into a heavy one).

- `outer_border_sides`

    Draws some sides on the background just outside the widget instead of
    the widget's own, so the border looks like part of its surroundings and
    a colored widget starts inside it (the last panel in the picture of
    ["Border width and space"](#border-width-and-space)).

This box sits directly below a box that has a border on its left, right
and top sides; its top corners join the side lines of the upper box, so
the two boxes share one line (the middle panel of the second row in the
picture of ["Border width and space"](#border-width-and-space)):

```perl
my $solid = Term::Fabulous::Enum::BorderStyle->Solid;
my $body  = Term::Fabulous::Widget::Box->new(
        border_width   => 1,
        border_style   => $solid,
        border_corners => {
                top_left  => Term::Fabulous::Enum::BorderStyle->junction( up => $solid, right => $solid, down => $solid ),    # ├
                top_right => Term::Fabulous::Enum::BorderStyle->junction( up => $solid, left  => $solid, down => $solid ),    # ┤
        },
);
```

[Term::Fabulous::Widget::Table](../Widget/Table.md) draws its grid lines this way. See
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md) for the exact rules.

# THEMES

A _theme_ decides the colors and the border styles of every widget
that does not set them itself: the text color of a Text, the
background of a text field, the border of a focused button, the lines
of a table. Term::Fabulous comes with two themes, `dark` (the colors
the pictures on these pages show) and `light`, for terminals with a
light background. A theme is set per UI and can be switched at any
time:

```perl
my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24, theme => 'light' );
$ui->theme('dark');    # every widget takes the new colors in the next frame
```

[Term::Fabulous::Static](../Static.md) takes the same parameter. Without one, a UI
uses `dark`. The program `examples/themes.pl` shows the same panel
under both built-in themes and under a theme file (F2 switches):

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-themes.svg" alt="A panel in the ocean theme: teal accents on a deep blue background, a text field holding Ada, a checked check box, a progress bar at 65 percent, a Save button in the accent and a Cancel button with a red border"></p>
</div>

## What a theme colors

A theme has two layers. The _palette_ is a set of named colors, the
_tokens_: `background`, `surface`, `border`, `text`,
`text_muted`, `accent`, `focus_background`, `success`, `warning`,
`danger` and some twenty more (the full list is in
["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens)). Above it, every kind of widget, a
_family_, has _slots_, one for each colored or styled part: a
button has `background`, `border.color`, `border.style` and
`text`; an input has `text`, `accent`, `placeholder`, `selection`
and more; a table has `header.background`, `cursor`, `line.color`,
... Each slot defaults to a token, so a theme that changes the
`accent` token changes the focus borders, the check marks, the
scrollbar thumbs and the group headers of tables at once, while a
theme that sets `button.border.color` changes buttons only.

A slot can have a different value in a _state_ of the widget:
`hovered`, `focused`, `pressed`, `disabled`, `selected` or
`active`, where the widget shows such a state. `button.border.color`
in the `focused` state is the accent by default; a state a theme
does not set looks like the normal state.
["Families, slots and states" in Term::Fabulous::Theme](../Theme.md#families-slots-and-states) lists every
family with its slots and their states, and the parameter of each
widget class says which slot it reads (for example
["new" in Term::Fabulous::Widget::Button](../Widget/Button.md#new)).

## Your own colors win

A color or a border style given to a widget, in `new`, through an
accessor or in a layout file, stays whatever the theme says. So a
program that colors its widgets as the earlier sections describe
looks the same under every theme, and a program that leaves the
colors to the theme follows it. The reader of a themed parameter
returns the color in use, the given one or the theme's. To return a
given color to the theme, call ["reset\_look" in Term::Fabulous::Widget](../Widget.md#reset_look)
with the parameter's name:

```perl
$button->border_color('#ff5050');    # red under every theme
$button->reset_look('border_color');  # the theme's again
```

Only the colors and border styles are themed. Layout, text and the
glyphs of a widget (the marks of a check box, the frames of a
spinner) are the widget's own.

## Variants and classes

A theme may define _variants_ of a family, named after the classes a
widget can be given (["classes" in Term::Fabulous::Widget](../Widget.md#classes)): a button with
`classes => ['primary']` draws with the `primary` variant of the
`button` family where the theme has one, and like every other button
where it has none. A variant sets any slots and states of its family;
the rest stay the family's. A widget with several classes takes the
variants of all of them, later classes winning where two set the same
slot. The classes can be changed at run time
(`$button->classes(['primary', 'wide'])`), and a layout file
sets them with `classes "primary" "wide"`. Text widgets have
classes too, so a theme can define `text.muted` or `text.heading`.

## Theme files

A theme is a KDL file ([https://kdl.dev](https://kdl.dev), the language of the layout
files) with a `theme` node that names the theme and the built-in
theme it starts from, a `palette` node, and one node per family. In
a family node, `name "value"` sets a slot (a token name or any color
string), `border style=Round color="border"` sets `border.style`
and `border.color` at once, a node named after a state holds the
slots of that state, and `variant "NAME"` holds a variant:

```kdl
theme "ocean" extends="dark"

palette {
        accent "#5fd3c0"
        surface "#10242f"
        text "#d8e8ee"
}

button {
        border style=Round
        focused { border color="accent" }
        variant "primary" {
                border color="accent"
                text "accent"
        }
}

divider {
        line style=Double
}
```

`none` switches a color or a style off, and `reverse` (for
`button.background` in the `pressed` state) draws the button in
reverse video. Unknown tokens, families, slots, states and styles die
with the known names. The program loads the file and gives the theme
to the UI:

```perl
use Term::Fabulous::Theme;

my $ocean = Term::Fabulous::Theme->from_file('ocean.kdl');
my $ui    = Term::Fabulous->new( root => $root, width => 80, height => 24, theme => $ocean );
```

`examples/ocean.kdl` is a complete theme file, and the recipe
[Switch themes at run time](../Cookbook/Layout.md#switch-themes-at-run-time-built-in-themes-and-a-theme-file)
a complete program. The grammar is described in
["THEME FILES" in Term::Fabulous::Theme](../Theme.md#theme-files).

## Themes in Perl

A theme can be built in Perl as well, with the same parts: the theme
it extends, palette tokens, slots (under `family.slot` or
`family.slot.state` keys) and variants:

```perl
my $theme = Term::Fabulous::Theme->new(
        name     => 'ocean',
        extends  => 'dark',
        palette  => { accent => '#5fd3c0', surface => '#10242f' },
        slots    => { 'button.border.style' => 'Round', 'button.border.color.focused' => 'accent' },
        variants => { 'button.primary' => { 'border.color' => 'accent', text => 'accent' } },
);
```

A theme may extend another theme object, so a program can derive a
variation of a theme it loaded. [Term::Fabulous::Color](../Color.md) helps with
the colors (["Working with colors"](#working-with-colors)): `$accent->lighten(0.1)` is
a color like any other. See ["CONSTRUCTORS" in Term::Fabulous::Theme](../Theme.md#constructors).

## Widgets of your own

A widget class of your own inherits the family of its base class, so
a widget derived from [Term::Fabulous::Widget::Input](../Widget/Input.md) draws with the
`input` slots, and declares which of its parameters the theme
supplies. ["Colors from the theme" in Term::Fabulous::Manual::CustomWidgets](CustomWidgets.md#colors-from-the-theme)
explains it, and [Term::Fabulous::Role::Themed](../Role/Themed.md) is the reference.

# SEE ALSO

This page is part of [Term::Fabulous::Manual](../Manual.md). Previous page: [Term::Fabulous::Manual::Layout](Layout.md). Next page: [Term::Fabulous::Manual::Events](Events.md).

[Term::Fabulous::Widget::Text](../Widget/Text.md), [Term::Fabulous::Color](../Color.md),
[Term::Fabulous::Enum::WebColor](../Enum/WebColor.md), [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md),
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md), [Term::Fabulous::Theme](../Theme.md),
[Term::Fabulous::Role::Themed](../Role/Themed.md), [Term::Fabulous::Unicode](../Unicode.md),
[Term::Fabulous::Cookbook::GettingStarted](../Cookbook/GettingStarted.md),
[Term::Fabulous::Cookbook::Layout](../Cookbook/Layout.md).
