# NAME

Term::Fabulous::Event::ViewChange - What a document view shows has changed

# SYNOPSIS

```perl
$view->on( ViewChange => sub ($event) {
        my $where = $event->section_title // 'top';
        $status->text( sprintf '%s  %d%%', $where, $event->percent );
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) fires `ViewChange` on itself
after a frame whose view differs from the one it reported last: the
user scrolled, selected another link, searched, or the program gave it
another document. It carries a summary of the view, everything a status
line or a table of contents needs, so they never have to ask the
widget.

The widget learns what a frame showed only after the frame was drawn,
so the event comes after the frame it describes, and what its
listeners change shows in the next one.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `ViewChange`; it
bubbles to the widget's ancestors like every event, and
`$event->target` is the document view.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::ViewChange->new( top => 0, bottom => 20, percent => 0 );
```

The widget builds these events itself; build one yourself only to test
your listeners. Every parameter is optional; unknown parameters and
values out of their ranges die. The `name` and `bubble_mode`
parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# METHODS

## top

```perl
my $index = $event->top;
```

The index of the first block in view, or `undef` while the view shows
no document.

## bottom

```perl
my $index = $event->bottom;
```

The index of the last block in view, or `undef`.

## section

```perl
my $number = $event->section;
```

The number of the section the top block is in, as
["section\_at" in Term::Fabulous::Document](../Document.md#section_at) counts it (the position in
[heading\_indexes](../Document.md#heading_indexes)), or
`undef` above the first heading.

## section\_title

```perl
my $title = $event->section_title;
```

The text of the heading of that section, defined exactly when
["section"](#section) is, so that a status line can name the section from the
event alone.

## percent

```perl
my $percent = $event->percent;
```

How far the view is scrolled, 0 at the top to 100 at the end, as
`less` shows it. A document that fits shows 100.

## link

```perl
my $link = $event->link;
```

The destination of the selected link, as the parser gave it to the
mark (["link" in Term::Fabulous::Document::Mark](../Document/Mark.md#link)), or `undef` when no link
is selected.

## query

```perl
my $text = $event->query;
```

The text of the search, or `undef` without a search. A search may
find nothing, so a query can come with no matches; matches never come
without their query.

## match, matches

```perl
printf "match %d of %d\n", $event->match, $event->matches if $event->matches;
```

The number of search matches (0 without a search), and which of them
the view is at, from 1, or `undef` when none is current.

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Manual::Events](../Manual/Events.md).
