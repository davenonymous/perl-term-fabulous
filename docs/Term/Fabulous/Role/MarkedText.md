# NAME

Term::Fabulous::Role::MarkedText - The spans and highlights of a widget
that shows one text

# SYNOPSIS

```perl
use Object::Pad 0.825;
use Term::Fabulous::Role::MarkedText;
use Term::Fabulous::Text::Marks;
use Term::Fabulous::Widget::Display;

class My::Banner :isa(Term::Fabulous::Widget::Display) :does(Term::Fabulous::Role::MarkedText) {
        field $marks;

        ADJUST :params ( :$text = '' ) {
                $marks = Term::Fabulous::Text::Marks->new( owner => ref($self), text => $text );
        }

        method text_marks () { return $marks }

        method marks_changed ($is_content) {
                $self->mark_changed;    # paint again with the new runs
                return;
        }

        method reveal_text ( $key, $offset ) { return [ $self, 0 ] }
        method natural_size () { return ( length $marks->text, 1 ) }
        method paint () { ... }    # with $marks->runs( theme => $self->drawing_theme )
}
```

# DESCRIPTION

[Term::Fabulous::Widget::Text](../Widget/Text.md) and [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md)
show one text each, with spans that style it and highlights that a
search paints over them. Both keep these in a
[Term::Fabulous::Text::Marks](../Text/Marks.md) and present the same methods through
this role, which also answers [Term::Fabulous::Role::Searchable](Searchable.md) for
the one text (its key is `undef`). A widget that composes it provides
["text\_marks"](#text_marks), ["marks\_changed"](#marks_changed) and ["reveal\_text"](#reveal_text), which differs
from widget to widget.

The _marks_ are those of [Term::Fabulous::Text::Marks](../Text/Marks.md); this role
handles the spans and highlights; the widget handles its links itself.

# REQUIRED METHODS

## text\_marks

```perl
method text_marks () { return $marks }
```

The [Term::Fabulous::Text::Marks](../Text/Marks.md) of the text the widget shows.

## marks\_changed

```perl
method marks_changed ($is_content) { ... }
```

Called after the role changed the marks: `$is_content` is 1 after the
spans changed, 0 after the highlights did. The widget drops what it made
from the old marks (its runs) and makes the next frame paint again (a
Text drops its runs and bumps the revision of [Clay::UI::Revision](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARevision); a
CodeBlock, like the SYNOPSIS, calls `mark_changed`).

## reveal\_text

```perl
method reveal_text ( $key, $offset ) { ... }
```

The `reveal_text` of ["reveal\_text" in Term::Fabulous::Role::Searchable](Searchable.md#reveal_text): a
Text returns `[ $self, undef ]`, a CodeBlock `[ $self, $line ]` with
the line of the offset.

# PROVIDED METHODS

## spans

```perl
my $spans = $widget->spans;              # [ [ $start, $end, \%style ], ... ]
$widget->spans( [ [ 0, 4, 'bold' ] ] );
```

Accessor: the spans (a copy), or replaces them and returns the new
ones. See ["set\_spans" in Term::Fabulous::Text::Marks](../Text/Marks.md#set_spans) for the checks.

## stylize

```perl
$widget->stylize( 'underline', 7, 17 );
$widget->stylize('dim');                 # the whole text
```

Appends a span from `$start` (default 0) up to `$end` (default the end
of the text). Returns the widget.

## clear\_spans

Removes every span. Returns the widget.

## highlights

```perl
my $highlights = $widget->highlights;
$widget->highlights( [ [ 3, 5, 'on accent' ] ] );
```

Accessor for the highlights, painted over the spans; setting them does
not change ["content\_revision"](#content_revision).

## clear\_highlights

Removes every highlight. Returns the widget.

## content\_revision

The ["content\_revision" in Term::Fabulous::Text::Marks](../Text/Marks.md#content_revision): it grows with every
change of the text, the spans (and a text's links and markup), never
with the highlights.

## search\_texts, search\_revision, highlight\_text, clear\_text\_highlights

The methods of [Term::Fabulous::Role::Searchable](Searchable.md) for the one text: its
key is `undef`, its revision is ["content\_revision"](#content_revision), and
`highlight_text` sets ["highlights"](#highlights). `search_serial` comes from
["search\_serial" in Term::Fabulous::Role::Searchable](Searchable.md#search_serial).

# SEE ALSO

[Term::Fabulous::Text::Marks](../Text/Marks.md), [Term::Fabulous::Role::Searchable](Searchable.md),
[Term::Fabulous::Widget::Text](../Widget/Text.md), [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md).
