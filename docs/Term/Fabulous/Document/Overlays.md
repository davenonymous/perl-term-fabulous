# NAME

Term::Fabulous::Document::Overlays - Track the selected link and the search matches shown over a document

# SYNOPSIS

```perl
use Term::Fabulous::Document::Overlays;

my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );

# Search, starting at the block at the top of the view:
restyle($_) foreach $overlays->search( 'hash', $top_block );
printf "%d of %d\n", $overlays->current_match, $overlays->match_count if $overlays->match_count;
restyle($_) foreach $overlays->step_match(1);
reveal( $overlays->current_match_start );

# Select the next link, given the blocks in view:
if ( my @touched = $overlays->select_link( 1, { first => 10, last => 24 } ) ) {
        restyle($_) foreach @touched;
        say $overlays->selected_link;
}

# When restyling block $index:
$text->stylize( $look->style( $_->[2] ), $_->[0], $_->[1] ) foreach $overlays->spans_of($index);
$text->select_link( $overlays->selected_in_block($index) );
```

# DESCRIPTION

You rarely need this class directly: [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md)
creates and uses it for you. It is useful when you write your own
widget that shows a [Term::Fabulous::Document](../Document.md) and want link selection
and search to behave as they do in the document view.

A document view draws two things on top of the blocks' own styles: the
_selected link_, which is the link that `Enter` follows, and the
_matches_ of a search, with the _current match_ in a style of its own.
This class keeps track of both for one document and implements all the
rules about them: where a search starts, how stepping through the
matches wraps around, which link is selected next, and where the
selection stops.

The class knows nothing of widgets. Instead, every method that changes
the overlays returns the indexes of the blocks it touched, that is, the
blocks whose overlays may have changed. Each index appears once, and
the indexes are sorted in document order. The widget restyles these
blocks and no others. An empty list means that no block changed, so
the widget can report that a key did nothing; the document view's
methods for selecting links and stepping through matches then return
0\. ["clear"](#clear) is an exception, described
there.

Overlays belong to one document for their whole life; there is no way
to give them another one. The document view creates new overlays
whenever it shows a new document.

# CONSTRUCTOR

## new

```perl
my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );
```

Creates overlays for a document, with no search and no selected link.
`document` is a [Term::Fabulous::Document](../Document.md), or `undef` (the default)
for overlays over no document: there are no links to select, and every
search finds nothing. The constructor dies for any other value of
`document` and for unknown parameters.

# METHODS

Methods that take a direction accept `1` for forward and `-1` for
backward, and die for anything else.

## search

```perl
my @touched = $overlays->search( $text, $top );
```

Starts a search for `$text`, replacing any previous search, and marks
every occurrence in the document. ["find\_text" in Term::Fabulous::Document](../Document.md#find_text)
defines what counts as an occurrence.

The current match becomes the first match in block `$top` or in a
later block; if there is none, it is the first match of the document.
The document view passes the index of the block at its top, so that a
search starts where the user is reading.

An empty `$text` ends the search. Returns the blocks that had matches
before the call or have matches after it. Dies when `$text` is not a
string or `$top` is not a non-negative integer.

## step\_match

```perl
my @touched = $overlays->step_match(1);     # or -1
```

Makes the next (`1`) or previous (`-1`) match the current one. The
step wraps around: forward from the last match goes to the first, and
backward from the first goes to the last. Returns the blocks of the
previous and the new current match, or an empty list when there are no
matches.

## query, match\_count, current\_match

```perl
my $text  = $overlays->query;            # undef without a search
my $count = $overlays->match_count;
my $which = $overlays->current_match;    # 1 .. $count, or undef
```

`query` returns the text searched for, or `undef` while there is no
search. `match_count` returns the number of matches, 0 without any.
`current_match` returns the number of the current match, counted from
1, or `undef` while there are no matches.

## current\_match\_start

```perl
my ( $block, $offset ) = $overlays->current_match_start;
```

Returns where the current match starts: the index of its block and the
character offset of the match in the block's text. Returns an empty
list while there is no current match.

## select\_link

```perl
my @touched = $overlays->select_link( 1, { first => 10, last => 24 } );
```

Selects the next (`1`) or previous (`-1`) link of the document. The
second argument tells which blocks are in view, as the hash reference
that ["visible\_items" in Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md#visible_items) returns, or
`undef` while that is not known. The next link is chosen as follows:

- If a link is selected and either its block is in view or the blocks in
view are not known, the selection moves to the link after (or before)
it.
- Otherwise, if the blocks in view are known, the selection moves to the
first link in a block at or after the first block in view (going
forward), or to the last link in a block at or before the last block in
view (going backward).
- Otherwise, with no selected link and no information about the view, it
moves to the first (or last) link of the document.

The selection does not wrap around. When there is no link in the chosen
direction, the selection stays where it is and the method returns an
empty list; it does the same when the document has no links. Otherwise
it returns the blocks of the previously and the newly selected link.
Dies when the second argument is neither `undef` nor a hash reference.

## select\_link\_at

```perl
my @touched = $overlays->select_link_at( $block, $start, $end );
```

Selects the link of block `$block` that runs from character offset
`$start` to `$end`, typically the link the user clicked. Returns the
blocks of the previously and the newly selected link. Dies when an
argument is not a non-negative integer, and when the block has no link
with exactly that range: a click on a link the document does not have
indicates a bug.

## selected\_link

```perl
my $link = $overlays->selected_link;    # the mark's link, or undef
```

Returns the destination of the selected link, which is whatever the
parser stored in the mark (see ["link" in Term::Fabulous::Document::Mark](Mark.md#link)),
or `undef` while no link is selected.

## selected\_mark

```perl
my ( $block, $mark ) = $overlays->selected_mark;
```

Returns the selected link as the index of its block and its
[Term::Fabulous::Document::Mark](Mark.md), which tells where the link starts
and ends. Returns an empty list while no link is selected.

## selected\_in\_block

```perl
my $index = $overlays->selected_in_block($block);
```

Returns the position of the selected link among the links of block
`$block`, counted from 0 in text order. This is the index that the
block's [Term::Fabulous::Widget::Text](../Widget/Text.md) expects in its
[select\_link](../Widget/Text.md#select_link) method.
Returns `undef` when no link is selected or the selected link is in
another block.

## spans\_of

```perl
foreach my $span ( $overlays->spans_of($block) ) {
        my ( $start, $end, $kind ) = @$span;
}
```

Returns the search matches in block `$block`, in text order, each as
an array reference `[ $start, $end, $kind ]` of character offsets and
a kind. The kind is `match_current` for the current match and
`match` for all others; both are kinds of
[Term::Fabulous::Document::Look](Look.md), not styles, so the widget turns them
into styles of its theme with ["style" in Term::Fabulous::Document::Look](Look.md#style).
Returns an empty list for a block without matches.

## clear

```perl
my @touched = $overlays->clear;
```

Ends the search and deselects the selected link. Returns the blocks
that had matches or held the selected link. A search without matches
touched no block, so the list can be empty even though a search ended.
To find out whether there was anything to clear, call ["is\_empty"](#is_empty)
before `clear`.

## is\_empty

```perl
say 'nothing to clear' if $overlays->is_empty;
```

Returns 1 while there is neither a search nor a selected link, and 0
otherwise. A search counts even when it found nothing.

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Document](../Document.md),
[Term::Fabulous::Document::Look](Look.md).
