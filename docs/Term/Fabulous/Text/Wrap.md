# NAME

Term::Fabulous::Text::Wrap - How many rows a text takes when Clay wraps it

# SYNOPSIS

```perl
use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);

my $rows = wrapped_rows( 'some words to wrap', 8 );    # 3
my $row  = wrapped_row( 'some words to wrap', 11, 8 ); # 1: "to" is on the second row
```

# DESCRIPTION

Clay lays out the text of a [Term::Fabulous::Widget::Text](../Widget/Text.md) and knows
how many rows it took only after the frame. A widget that must know
before, such as a [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) estimating
the height of a paragraph it has not laid out yet, or finding the row
of a search match within a paragraph, wraps the text the way Clay does
with these two functions.

Clay wraps at the spaces, and only there, so a no-break space is part
of its word. Every word is measured in terminal columns together with
the space after it; a word that does not fit on the line starts the
next one, and a word wider than a line has a line of its own, past
whose end it runs. `t/text-wrap.t` checks the functions against a
RichText that Clay laid out on a memory terminal.

Printable ASCII characters take one column each without a lookup; other
characters are measured with ["string\_columns" in Term::Fabulous::Unicode](../Unicode.md#string_columns).

# FUNCTIONS

Nothing is exported by default.

## wrapped\_rows

```perl
my $rows = wrapped_rows( $text, $columns );
```

The rows the text wraps to in that many columns, at least one. The
text must be a string and the columns a positive integer; anything else
dies.

## wrapped\_row

```perl
my $row = wrapped_row( $text, $offset, $columns );
```

The row, from 0, of the character at the offset when the text is
wrapped to that many columns. A space belongs to the word before it; an
offset past the end is on the last row. The offset must be a
non-negative integer.

# SEE ALSO

[Term::Fabulous::Document::Geometry](../Document/Geometry.md), ["wrap\_mode" in Term::Fabulous::Widget::Text](../Widget/Text.md#wrap_mode),
["Wrapping" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#wrapping).
