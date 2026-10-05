# NAME

Term::Fabulous::Text::Markup - Parse "\[bold red\]text\[/\]" markup into text
and styled spans

# SYNOPSIS

```perl
use Term::Fabulous::Text::Markup qw(parse_markup);

my ( $text, $spans ) = parse_markup('Press [bold]Enter[/] to [green on #202020]save[/green on #202020].');
# $text  is 'Press Enter to save.'
# $spans is [ [ 6, 11, { set => TB_BOLD, ... } ], [ 15, 19, { color => [ 0, 128, 0, 255 ], ... } ] ]
```

# DESCRIPTION

Markup is text with style tags in square brackets, in the syntax of
Python's `rich` library. [Term::Fabulous::Widget::RichText](../Widget/RichText.md) takes it
as its `markup` parameter; this module does the parsing.

- `[STYLE]`

    Opens a span with a style string of [Term::Fabulous::Text::Style](Style.md):
    `[bold]`, `[italic SteelBlue on #202020]`, `[not bold]`. An invalid
    style dies.

- `[/]`

    Closes the innermost open span.

- `[/STYLE]`

    Closes the innermost open span that was opened with exactly that style
    string: `[/bold]` closes a `[bold]`. Dies when no such span is open.

- `\[`

    A literal `[`. Every other backslash is a backslash.

Brackets that do not look like a tag are text: a tag starts with a
letter, `#` or `/` and contains no brackets, so `[1]`, `[ ]` and
`[]` stay as they are. Spans still open at the end run to the end of
the text. Tags nest: an inner span is applied after the outer one, so
its words win where they overlap.

# FUNCTIONS

Nothing is exported by default.

## parse\_markup

```perl
my ( $text, $spans ) = parse_markup($markup);
```

Returns the text without its tags and the spans as an array reference
of `[ $start, $end, $style ]`: the character offsets of the span in
`$text` (`$end` is the offset after its last character) and its
normalized style hash (see ["Style hashes" in Term::Fabulous::Text::Style](Style.md#style-hashes)).
Spans are ordered by their start, outer spans before inner ones that
start at the same offset; empty spans are dropped. `undef` and
references die with a message starting with
`Term::Fabulous::Text::Markup:`.

# SEE ALSO

[Term::Fabulous::Text::Style](Style.md), [Term::Fabulous::Widget::RichText](../Widget/RichText.md).
