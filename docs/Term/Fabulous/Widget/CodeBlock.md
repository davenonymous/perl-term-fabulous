# NAME

Term::Fabulous::Widget::CodeBlock - Code on a background of its own, clipped and scrolled sideways

# SYNOPSIS

```perl
use Term::Fabulous::Widget::CodeBlock;

my $code = Term::Fabulous::Widget::CodeBlock->new(
        code     => "my \$x = 1;\nsay \$x;",
        language => 'perl',
);

# Color the keyword "my":
$code->spans( [ [ 0, 2, 'bold #c678dd' ] ] );

# Syntax highlighting: a function from the code to spans.
$code->highlighter( sub ( $text, $language ) { return [ my_highlighter( $text, $language ) ] } );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-code-block.svg" alt="Three code blocks on a darker background: a short Perl snippet with a highlighted keyword and a colored variable, a block whose long lines are cut at the right edge with a mark, and the same block scrolled sideways with marks on both sides"></p>
</div>

The program is `examples/widgets/code-block.pl`.

# DESCRIPTION

A code block shows a verbatim paragraph: lines of code, never wrapped,
on a background that sets them apart from the prose around them. It is
a [Term::Fabulous::Widget::Display](Display.md), a widget that paints its cells
itself (see ["A widget that draws itself" in Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md#a-widget-that-draws-itself)),
for two reasons:

- Code must not wrap, and a line that is wider than the block must end
at the block's edge, not run on into the border of the document
around it. A Display owns exactly its cells, so nothing it paints can
leave them. Clipped lines show a mark in the margin: `›` where a line
goes on to the right, `‹` where it is scrolled to the left.
- Every character can be painted in a look of its own, from the
highlighter and from the program's spans, without asking Clay to lay
the text out.

The block is as tall as its code has lines and as wide as its parent
allows (`natural_size` asks for `sizing_grow` in width). Its colors
are the `code_block` and `clipped` styles of
[Term::Fabulous::Document::Look](../Document/Look.md), taken from the theme; one column on
either side is margin.

The block shows its code shifted to the left by ["offset"](#offset) columns. It
does not scroll by itself: the widget it is shown in decides, so that
several blocks can move together.
[Term::Fabulous::Widget::DocumentView](DocumentView.md) scrolls all its code blocks
sideways with the keys and the horizontal wheel.

# CONSTRUCTOR

## new

```perl
my $code = Term::Fabulous::Widget::CodeBlock->new( code => $text, %parameters );
```

All parameters of [Term::Fabulous::Widget::Display](Display.md) (`id`,
`layout`, ...) plus the following. Unknown parameters die, and so do
invalid values, with a message that names the parameter.

- `code`

    The code, a string; lines are separated by `"\n"`. Default: empty.
    Tabs should be expanded beforehand (a tab is shown as one space).

- `language`

    `undef` (the default) or a non-empty string: the language the code is
    written in. The block itself does nothing with it but pass it to the
    `highlighter`.

- `highlighter`

    `undef` (the default) or a code reference, called as
    `$highlighter->( $code, $language )` when the block is painted
    for the first time after the code, the language or the highlighter
    changed. It returns an array reference of spans
    `[ $start, $end, $style ]`: character offsets into the code and a
    style string or hash of [Term::Fabulous::Text::Style](../Text/Style.md)
    (`'bold #c678dd'`), the format of the spans of a
    [Term::Fabulous::Widget::RichText](RichText.md). The result is kept until one of
    the three changes. A result that is not such an array dies when the
    block is painted. See ["SYNTAX HIGHLIGHTING"](#syntax-highlighting).

- `spans`

    An array reference of spans in the same format, applied after the
    highlighter's, so they win where both style a character: a search
    match stays visible in highlighted code. Default: none.

- `offset`

    A non-negative integer, default 0: how many columns the code is
    scrolled to the left. It is kept as given; the block shows at most the
    offset that brings its widest line's end into view (["shown\_offset"](#shown_offset)).

# METHODS

The methods of [Term::Fabulous::Widget::Display](Display.md), plus the accessors
of the parameters, which return the value without an argument and set
it with one, check it like the constructor and show the change in the
next frame:

## code

```perl
$code->code("print 42;\n");
```

Setting the code drops the spans, which pointed into the old code.

## language

```perl
$code->language('perl');
```

## highlighter

```perl
$code->highlighter( \&highlight );
```

## spans

```perl
my $spans = $code->spans;    # [ [ 0, 2, { set => ..., clear => ..., color => ..., background => ... } ], ... ]
```

Reading returns a copy, with each style normalized to a style hash.

## offset

```perl
$code->offset(8);
```

## shown\_offset

```perl
my $columns = $code->shown_offset;
```

The offset the block is painted with: ["offset"](#offset), but no more than
["max\_offset"](#max_offset).

## max\_offset

```perl
my $columns = $code->max_offset;
```

How far the code can scroll: the width of its widest line less the
columns the last frame showed of it, or 0. Before the first frame, when
the block has no columns yet, it is the width of the widest line.

## line\_count

```perl
my $lines = $code->line_count;
```

The number of lines of the code (at least 1).

## widest\_line\_columns

```perl
my $columns = $code->widest_line_columns;
```

The width of the widest line, in terminal columns.

# SYNTAX HIGHLIGHTING

The block does not know any programming language. A highlighter is any
function from code and a language name to spans, so syntax
highlighting plugs in from outside: through the `highlighter`
parameter of ["new" in Term::Fabulous::Widget::DocumentView](DocumentView.md#new), which hands
it to every code block of the view, or to a single block. A highlighter
for Perl could use [PPI](https://metacpan.org/pod/PPI) to find the tokens and give each kind of
token a style; one that does not know the language returns `[]`.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Box.md#kdl-properties), plus
`code`, `language` and `offset`:

```kdl
use Term::Fabulous::Widget::CodeBlock as CodeBlock

CodeBlock "example" {
        code "my $x = 1;\nsay $x;"
        language "perl"
}
```

# SEE ALSO

[Term::Fabulous::Document::Block::Verbatim](../Document/Block/Verbatim.md), [Term::Fabulous::Widget::DocumentView](DocumentView.md),
[Term::Fabulous::Widget::Display](Display.md), [Term::Fabulous::Text::Style](../Text/Style.md).
