# NAME

Term::Fabulous::Text::Wrap - Predict how many rows a text takes when Clay wraps it

# SYNOPSIS

```perl
use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);

# In 8 columns, 'some words to wrap' wraps to "some", "words", "to wrap".
my $rows = wrapped_rows( 'some words to wrap', 8 );     # 3
my $row  = wrapped_row( 'some words to wrap', 11, 8 );  # 2: character 11 starts "to", on the third row
```

# DESCRIPTION

Clay lays out the text of a [Term::Fabulous::Widget::Text](../Widget/Text.md) or
[Term::Fabulous::Widget::RichText](../Widget/RichText.md) during a frame, so the number of
rows the text takes is known only after that frame. Some widgets need
it earlier. A [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), for example,
estimates the height of every paragraph it has not laid out yet, and
needs the row of a search match within a paragraph to scroll it into
view. These two functions wrap a text the way Clay does and give those
answers without a frame.

The functions matter mostly to authors of block kinds whose body is
wrapped text: the default
[body\_rows](../Document/Block.md#body_rows) and
[row\_of\_character](../Document/Block.md#row_of_character)
of [Term::Fabulous::Document::Block](../Document/Block.md) call them.

## How Clay wraps

The functions follow these rules, which are Clay's for a text of a
single line:

- Lines break at space characters (U+0020). Every other character
belongs to a word, including a no-break space, which keeps the words on
either side together. Clay also starts a new line at `"\n"`, but these
functions do not: they count a line break as part of a word. Pass them
a single line, as the text of a document's blocks is.
- Every word is measured in terminal columns together with the space
that follows it. The last word of the text has no space after it and is
measured alone.
- A word that does not fit on the current line starts the next line.
- A word that is wider than the line gets a line of its own and runs past
the end of that line.

`t/text-wrap.t` checks the functions against RichText widgets that
Clay laid out on a memory terminal, so a change in Clay's wrapping
shows up as a test failure.

Printable ASCII characters count as one column each and need no
lookup. Other characters are measured with
["string\_columns" in Term::Fabulous::Unicode](../Unicode.md#string_columns), so wide characters such as
CJK ideographs count as two columns.

# FUNCTIONS

Nothing is exported by default.

## wrapped\_rows

```perl
my $rows = wrapped_rows( $text, $columns );
```

Returns the number of rows `$text` takes when it is wrapped to
`$columns` columns. The result is at least 1, even for an empty text.
Dies when `$text` is not a string or `$columns` is not a positive
integer.

## wrapped\_row

```perl
my $row = wrapped_row( $text, $offset, $columns );
```

Returns the row, counted from 0, of the character at `$offset` when
`$text` is wrapped to `$columns` columns. `$offset` counts
characters from 0, not columns. A space belongs to the row of the word
before it, and an offset at or past the end of the text lies on the
last row. Dies when `$text` is not a string, `$offset` is not a
non-negative integer or `$columns` is not a positive integer.

# SEE ALSO

[Term::Fabulous::Document::Geometry](../Document/Geometry.md), ["wrap\_mode" in Term::Fabulous::Widget::Text](../Widget/Text.md#wrap_mode),
["Wrapping" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#wrapping).
