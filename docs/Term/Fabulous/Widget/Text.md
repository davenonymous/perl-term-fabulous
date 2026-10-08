# NAME

Term::Fabulous::Widget::Text - A piece of text inside a box

# SYNOPSIS

```perl
use utf8;    # this source file contains non-ASCII text
use Term::Fabulous::Widget::Text;

my $title = Term::Fabulous::Widget::Text->new(
        text       => 'Settings',
        text_color => [ 255, 255, 255, 255 ],
);

# Text is a character string, like everywhere in Term::Fabulous:
my $greeting = Term::Fabulous::Widget::Text->new(
        id         => 'greeting',
        text       => 'Grüße',
        text_color => [ 230, 230, 230, 255 ],
);

# Later, change what it shows:
$greeting->text('Hello again');
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-text.svg" alt="Colored words, a sentence wrapped left-aligned, centered and right-aligned, and text in five scripts"></p>
</div>

The program is `examples/widgets/text.pl`.

# DESCRIPTION

A Text widget shows text inside its parent widget, usually a
[Term::Fabulous::Widget::Box](Box.md). The layout makes it as wide as its
longest line, wraps it at spaces when the parent is too narrow, and
starts a new line at every `"\n"`. Text has a color but no background
of its own: every cell shows the background that was painted below it.

A Text widget is a leaf: it cannot have children, and it has no
border, padding or background. To give text a background, a border or
a fixed size, put it in a Box. Mouse events (`Mouse`, `MouseMove`)
go to the box behind a text, and a Text never has the keyboard focus
(a [Term::Fabulous::Widget::RichText](RichText.md) with links does). A mouse button
pressed on a character of the text also fires
[TextClick](../Event/TextClick.md) on the Text, with the
character and the word under the pointer, so that the widgets around
it can react to the words that were clicked (see ["click\_at"](#click_at)).

`examples/text-features.pl` shows the wrap modes, line height, bold,
italic and underlined text, wide characters and control characters:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-text-features.svg" alt="Text wrapped at spaces in a narrow panel and text broken only at newlines; a two-line text with line height 2; plain, bold, italic, underlined and combined styles; Latin, Japanese, emoji and combining accents ending in the same column; a tab shown as a space and control characters shown as replacement characters"></p>
</div>

[The text section of the looks guide](../Manual/Looks.md#text)
explains all of this with examples. The class is built on [Clay::UI::Text](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AText).

# CONSTRUCTOR

## new

```perl
my $text = Term::Fabulous::Widget::Text->new(%parameters);
```

All parameters are optional; unknown parameters die. Every parameter
except `id` also has an accessor of the same name.

- `text`

    A character string, like all text in Term::Fabulous. Default: `''`.

    Bytes read from a file, a command or a socket must be decoded first
    with `Encode::decode('UTF-8', $bytes)`; otherwise each byte is shown
    as one Latin-1 character. Text read from a KDL layout is used as is.
    See ["Text is character strings" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#text-is-character-strings).

    Control characters are never sent to the terminal: a TAB is shown as
    one space and every other control character, a carriage return
    included, as U+FFFD (see ["Control characters" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#control-characters)).
    Wide characters (most CJK characters and emoji) take two cells (see
    ["Wide characters and emoji" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#wide-characters-and-emoji)). `undef`
    and references die.

- `text_color`

    The color of the characters, in any format [Term::Fabulous::Color](../Color.md)
    accepts: `[r, g, b, a]` (or `[r, g, b]`), `{ r, g, b, a }`, a string
    such as `'#ffffff'` or `'rgb(255, 255, 255)'`, a packed `0xRRGGBB`
    integer, or a Term::Fabulous::Color object such as an item of
    [Term::Fabulous::Enum::WebColor](../Enum/WebColor.md); it is stored as `[r, g, b, a]`. An
    alpha from 1 to 254 is drawn opaque. Default: the theme's `text.color`
    (`[220, 223, 228, 255]` in the dark theme), or, inside a widget that
    colors its texts (a [Term::Fabulous::Widget::Button](Button.md)), that widget's
    text look. Pass `[0, 0, 0, 0]` (alpha 0) for the terminal's default
    foreground color. See ["COLORS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#colors) and
    ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes).

- `classes`

    An array reference of strings. Default: `[]`. Names that select the
    theme's variants of the `text` family, as for
    ["classes" in Term::Fabulous::Widget](../Widget.md#classes).

    Inside a disabled [Term::Fabulous::Widget::Button](Button.md), the text is drawn
    in the button's `disabled_color` instead, whatever its `text_color`.

- `bold`
- `italic`
- `underline`

    Booleans, default 0: draw the characters bold, italic or underlined.
    Any true or false value; references die. Terminals show these styles
    with the font they have, so a font without an italic face may show
    italic text upright. They take no space and do not change the layout.
    These three are the only text styles, and they apply to the whole
    text; a [Term::Fabulous::Widget::RichText](RichText.md) styles ranges of it. See
    ["Bold, italic and underline" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#bold-italic-and-underline).

- `id`

    A string naming the widget, for your own use (for example to find a
    Text in a tree built from a layout). Default: none. Unlike a Box's id,
    it is not passed to Clay and does not need to be unique, and
    ["remove\_child\_with\_id" in Term::Fabulous::Widget](../Widget.md#remove_child_with_id) does not remove Text
    widgets by id (["remove\_child" in Term::Fabulous::Widget](../Widget.md#remove_child) removes the widget
    itself). Read it with `$text->id`; there is no writer.
    [`find_by_id`](../Widget.md#find_by_id) finds Text widgets by this id.

- `wrap_mode`

    How lines are broken, one of the [Clay::XS](https://metacpan.org/pod/Clay%3A%3AXS) constants:
    `CLAY_TEXT_WRAP_WORDS` (the default: break at `"\n"` and, where the
    text does not fit, at spaces), `CLAY_TEXT_WRAP_NEWLINES` (break only
    at `"\n"`) and `CLAY_TEXT_WRAP_NONE` (the same as `CLAY_TEXT_WRAP_NEWLINES`, because
    Clay lays out both alike). A line
    that is not broken may be wider than the parent; it is cut off at the
    right edge of the terminal.

    With every mode, only spaces are break points: a single word that is
    wider than the space available, or text without spaces such as a
    Japanese sentence, is never broken: it runs past the right edge of its parent and is cut
    off only at the edge of the terminal or of an enclosing
    [Term::Fabulous::Widget::ScrollBox](ScrollBox.md). See
    ["Wrapping" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#wrapping).

- `text_alignment`

    `CLAY_TEXT_ALIGN_LEFT` (the default), `CLAY_TEXT_ALIGN_CENTER` or
    `CLAY_TEXT_ALIGN_RIGHT`. Aligns the lines of a multi-line text against
    each other, within the width of its longest line. It has no visible
    effect on a single line: to center a Text in its box, set
    `child_alignment` in the box's `layout` (see
    ["new" in Term::Fabulous::Widget](../Widget.md#new)).

- `line_height`

    The number of rows each line takes, an integer from 0 to 65535; other
    values (such as `1.5`) die. Default: 0, which means one row, like 1.
    A line is drawn in the middle row of its rows (the upper middle row
    when the number is even), so with `2` an empty row follows every line.
    See ["Line height" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#line-height).

- `font_id`
- `font_size`
- `letter_spacing`

    Accepted because Clay::UI supports them, but without effect in a
    terminal: every character is drawn in the terminal's font, one
    character per cell. Each is an integer from 0 to 65535; other values
    die. Defaults: `font_id` 0, `font_size` 16, `letter_spacing` 0.

# METHODS

Besides the accessors below, a Text widget has the methods `parent`,
`root`, `ui` and `on` that every widget has (see
[Term::Fabulous::Widget](../Widget.md)); `on` is rarely useful, because no events
are fired on Text widgets.

## text

```perl
my $text = $label->text;
$label->text($new_text);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
text is a character string; the layout adapts to the new length.

## text\_color

```perl
my $rgba = $label->text_color;
$label->text_color( [ 255, 80, 80, 255 ] );
$label->text_color('#ff5050');
```

Accessor. Without an argument it returns the color in use, the given
one or the theme's, as `[r, g, b, a]`; with an argument it sets it, in
any format the constructor parameter accepts, and returns the stored
`[r, g, b, a]`. An invalid value dies like the constructor parameter,
and so does `undef`: `$label->reset_look('text_color')` returns
the text to the theme. The change shows in the next frame.

## classes

```perl
$label->classes( ['muted'] );
```

Accessor for the `classes` parameter, as
["classes" in Term::Fabulous::Widget](../Widget.md#classes).

## reset\_look

```perl
$label->reset_look('text_color');
```

Drops the given `text_color`, so the theme's text color is drawn
again; see ["reset\_look" in Term::Fabulous::Widget](../Widget.md#reset_look).

## bold

```perl
$label->bold(1);
```

## italic

```perl
$label->italic(1);
```

## underline

```perl
$label->underline(1);
```

Accessors for the constructor parameters of the same names (0 or 1).
Without an argument they return the current value; with an argument
they set it and return the new value. The change shows in the next
frame.

## style\_attrs

```perl
my $bits = $label->style_attrs;
```

The termbox2 style bits (`TB_BOLD`, `TB_ITALIC`, `TB_UNDERLINE`, see
[Term::Fabulous::Termbox](../Termbox.md)) of the current `bold`, `italic` and
`underline` values, combined; 0 for plain text. The renderer adds them
to the text color.

## id

```perl
my $id = $label->id;
```

The `id` given to the constructor, or `undef`. There is no writer.

## wrap\_mode

```perl
$label->wrap_mode(CLAY_TEXT_WRAP_NONE);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
reader returns `undef` when it was never set, which behaves as
`CLAY_TEXT_WRAP_WORDS`.

## text\_alignment

```perl
$label->text_alignment(CLAY_TEXT_ALIGN_RIGHT);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
reader returns `undef` when it was never set, which behaves as
`CLAY_TEXT_ALIGN_LEFT`.

## line\_height

```perl
$label->line_height(2);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame.

## font\_id

```perl
$label->font_id(1);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. It has no effect in a terminal.

## font\_size

```perl
$label->font_size(16);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. It has no effect in a terminal; the
default is 16.

## letter\_spacing

```perl
$label->letter_spacing(0);
```

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. It has no effect in a terminal.

## tree\_changed

Clay::UI calls it on every widget of a subtree whose place in a tree
changed (see ["tree\_changed" in Clay::UI::Role::Layout::HasParent](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3ALayout%3A%3AHasParent#tree_changed)). A Text
forgets the looks it fetched here, as
["tree\_changed" in Term::Fabulous::Widget](../Widget.md#tree_changed) does.

## click\_at

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT);

$text->click_at( $offset, TB_KEY_MOUSE_LEFT, $x, $y );
```

Fires [TextClick](../Event/TextClick.md) on the widget for a
press of the mouse button (`TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE`
or `TB_KEY_MOUSE_RIGHT`) on the character at `$offset` of the text,
with the pointer at the cell `$x`, `$y`. The event carries the word
the character belongs to (the run of non-blank characters around it).
[Term::Fabulous](../../../../README.md) calls it after the `Mouse` event of every button
press on a character of the text; call it yourself to click a text in
a test. An offset that is not a character of the text dies. Returns
the widget.

# EVENTS

A Text fires `TextClick` ([Term::Fabulous::Event::TextClick](../Event/TextClick.md)) when a
mouse button is pressed on one of its characters; it bubbles to the
widgets around the text. The recipe
["React to a click on a word (TextClick)" in Term::Fabulous::Cookbook::KeyboardAndMouse](../Cookbook/KeyboardAndMouse.md#react-to-a-click-on-a-word-textclick)
looks up the clicked word. A Text can fire events of your own with
`fire_event` ([Clay::UI::Role::Events::Emitter](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AEvents%3A%3AEmitter)), and `on` adds
listeners to it.

# KDL PROPERTIES

```kdl
Text "greeting" {
        text "Gr\u{fc}\u{df}e, world"
        text_color "#e6e6e6"
        bold #true
        line_height 2
        wrap_mode newlines
        text_alignment center
}
```

The node's argument (`"greeting"`) is the `id`. Inside the block:

- `text "..."`

    Exactly one string. It is used as is, so write any characters directly
    (KDL files are UTF-8).

- `text_color "..."`

    Exactly one argument: any color string [Term::Fabulous::Color](../Color.md)
    understands, such as `"#ffffff"`, `"rgb(255, 255, 255)"` or
    `"hsl(0, 0%, 100%)"`.

- `bold #true`
- `italic #true`
- `underline #true`

    Exactly one boolean each: `#true`, `#false`, `1` or `0`.

- `wrap_mode words`

    Exactly one name: `words` (`CLAY_TEXT_WRAP_WORDS`), `newlines`
    (`CLAY_TEXT_WRAP_NEWLINES`) or `none` (`CLAY_TEXT_WRAP_NONE`). See
    the `wrap_mode` parameter of ["new"](#new).

- `text_alignment left`

    Exactly one name: `left` (`CLAY_TEXT_ALIGN_LEFT`), `center`
    (`CLAY_TEXT_ALIGN_CENTER`) or `right` (`CLAY_TEXT_ALIGN_RIGHT`). See
    the `text_alignment` parameter of ["new"](#new).

- `line_height N`
- `font_id N`
- `font_size N`
- `letter_spacing N`

    One integer each; see ["new"](#new). `font_id`, `font_size` and
    `letter_spacing` have no effect in a terminal.

An unknown `wrap_mode` or `text_alignment` name dies with the known
names. Any other property dies. A Text node cannot have child widgets.

# SUBCLASS INTERFACE

These methods are used by [Term::Fabulous::Layout](../Layout.md); you do not call
them yourself.

## layout\_properties

```perl
my %kind_of = Term::Fabulous::Widget::Text->layout_properties;
```

The table of the properties a layout may set (see
["layout\_properties" in Term::Fabulous::Role::CanParseLayout](../Role/CanParseLayout.md#layout_properties)): `font_id`,
`font_size`, `letter_spacing` and `line_height` are scalars,
`text_color` is a color, `bold`, `italic` and `underline` are
booleans, and `text`, `wrap_mode` and
`text_alignment` are structured properties the Text parses itself; see
["KDL PROPERTIES"](#kdl-properties).

# SEE ALSO

["TEXT" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#text), [Term::Fabulous::Widget::Box](Box.md),
[Term::Fabulous::Widget::RichText](RichText.md), [Term::Fabulous::Unicode](../Unicode.md),
[Clay::UI::Text](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AText),
["Wrap, align and space text" in Term::Fabulous::Cookbook::GettingStarted](../Cookbook/GettingStarted.md#wrap-align-and-space-text),
["Show non-ASCII text (umlauts, CJK, combining accents)" in Term::Fabulous::Cookbook::GettingStarted](../Cookbook/GettingStarted.md#show-non-ascii-text-umlauts-cjk-combining-accents).
