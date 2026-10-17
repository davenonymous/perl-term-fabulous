# NAME

Term::Fabulous::Event::ViewChange - Reports that what a document view shows has changed

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
after a frame in which what it shows differs from what it reported
last: for example, the user scrolled, selected another link or
searched, or the program gave the view another document. The event
carries a summary of the view with everything a status line or a table
of contents needs, so their listeners do not have to query the view.

The view learns what a frame showed only after the frame has been
drawn. The event therefore arrives after the frame it describes, and
whatever its listeners change shows in the following frame.

The event is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) named `ViewChange`. Like
every event, it bubbles up to the view's ancestors, and
`$event->target` is the document view.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::ViewChange->new( top => 0, bottom => 20, percent => 0 );
```

The document view creates these events itself; create one yourself
only to test your listeners. Every parameter is optional: `percent`
and `matches` default to 0, all others to `undef`. The `name` and
`bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted
as well. Unknown parameters die, and so do values that are out of
range or inconsistent:

- `top`, `bottom`, `section` and `match` must be non-negative
integers or `undef`;
- `section` and `section_title` must be given together, or both left
out;
- `percent` must be an integer from 0 to 100;
- `matches` must be a non-negative integer, and `match`, if given, a
number from 1 to `matches`;
- `query`, if given, must be a non-empty string, and `matches` greater
than 0 requires a `query`.

# METHODS

## top

```perl
my $index = $event->top;
```

Returns the index of the block at the top of the view, which may be
only partly visible. Returns `undef` when the view has no document,
when the document has no blocks, or when the view has not been laid
out yet.

## bottom

```perl
my $index = $event->bottom;
```

Returns the index of the block at the bottom of the view, which may be
only partly visible, or `undef` in the same cases as ["top"](#top).

## section

```perl
my $number = $event->section;
```

Returns the number of the section the top block belongs to, as
["section\_at" in Term::Fabulous::Document](../Document.md#section_at) counts it: the position of the
section's heading in
[heading\_indexes](../Document.md#heading_indexes), from 0.
Returns `undef` when the top block comes before the first heading, or
when ["top"](#top) is `undef`.

## section\_title

```perl
my $title = $event->section_title;
```

Returns the text of that section's heading. It is defined exactly when
["section"](#section) is, so that a status line can name the section from the
event alone.

## percent

```perl
my $percent = $event->percent;
```

Returns how far the view is scrolled, as a rounded integer from 0 at
the top to 100 at the end, the way `less` shows it. The view reports
100 for a document that fits into the view entirely, and before it has
been laid out.

## link

```perl
my $link = $event->link;
```

Returns the target of the selected link, as the parser stored it in the
link mark (["link" in Term::Fabulous::Document::Mark](../Document/Mark.md#link)), or `undef` when no
link is selected.

## query

```perl
my $text = $event->query;
```

Returns the text of the current search, or `undef` when there is no
search. A search may find nothing, so an event can have a query and no
matches, but it never has matches without a query.

## match, matches

```perl
printf "match %d of %d\n", $event->match, $event->matches if $event->matches;
```

`matches` returns the number of search matches, 0 without a search.
`match` returns the number of the current match, counted from 1, or
`undef` when there is no current match. The view always has a current
match while there are matches.

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Manual::Events](../Manual/Events.md).
