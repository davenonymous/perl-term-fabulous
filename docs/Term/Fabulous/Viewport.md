# NAME

Term::Fabulous::Viewport - The arithmetic of a scrolled view

# SYNOPSIS

```perl
use Term::Fabulous::Viewport qw(max_offset clamp_offset reveal_range scroll_thumb);

# 40 rows of content in a view of 10 rows, scrolled down by 12:
my $limit = max_offset( 40, 10 );                  # 30
my $top   = clamp_offset( 40, 10, $top + 3 );      # within 0 .. 30
$top      = reveal_range( 40, 10, $top, 25, 26 );  # row 25 in view: 16
my ( $first, $size ) = @{ scroll_thumb( 40, 10, $top, 10 ) };    # the thumb of a 10-cell track
```

# DESCRIPTION

Pure functions over the three numbers that describe a scrolled view:
the size of the _content_, the size of the _viewport_ that shows part
of it, and the _offset_, how far the viewport is scrolled from the
start of the content (0 at the start). The unit is up to the caller:
rows of a list, visual rows of a text, cells of a laid out box. Every
widget of Term::Fabulous that scrolls by itself uses them, so a list, a
text area and a table keep a row in view and draw their scrollbars by
the same rules. Nothing is exported by default.

# FUNCTIONS

## max\_offset

```perl
my $limit = max_offset( $content, $viewport );
```

The largest offset: the content minus the viewport, or 0 when the
content fits.

## clamp\_offset

```perl
my $offset = clamp_offset( $content, $viewport, $offset );
```

The offset limited to 0 .. ["max\_offset"](#max_offset).

## reveal\_range

```perl
my $offset = reveal_range( $content, $viewport, $offset, $from, $to );
```

The offset that shows the range from `$from` to before `$to` with the
smallest change: the offset itself when the range is in view, the
start of the range when it lies above, and the offset that puts its end
at the end of the viewport when it lies below. A range larger than the
viewport shows its start. The result is clamped (["clamp\_offset"](#clamp_offset)).

## scroll\_thumb

```perl
my ( $first, $size ) = @{ scroll_thumb( $content, $viewport, $offset, $track ) };
```

The thumb of a scrollbar whose track is `$track` cells long, as an
array reference: the first cell of the thumb and its length in cells.
The length is the viewport's share of the content (at least one cell,
at most the track), the place the offset's share of
["max\_offset"](#max_offset), rounded and kept inside the track. When the content
fits the viewport, or the track has no cells, the thumb is the whole
track (`[0, $track]`, `[0, 0]` for no cells).
["paint\_track" in Term::Fabulous::Widget::Scrollbar](Widget/Scrollbar.md#paint_track) paints it.

# SEE ALSO

[Term::Fabulous::Widget::Scrollbar](Widget/Scrollbar.md), [Term::Fabulous::TextView](TextView.md).
