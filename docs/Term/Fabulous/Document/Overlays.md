# NAME

Term::Fabulous::Document::Overlays - The selected link and the search matches drawn over a document

# SYNOPSIS

```perl
use Term::Fabulous::Document::Overlays;

my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );

restyle($_) foreach $overlays->search( 'hash', $top_block );
printf "%d of %d\n", $overlays->current_match, $overlays->match_count;
restyle($_) foreach $overlays->step_match(1);
reveal( $overlays->current_match_start );

if ( my @touched = $overlays->select_link( 1, { first => 10, last => 24 } ) ) {
        restyle($_) foreach @touched;
        say $overlays->selected_link;
}

# In the restyle of a block:
$text->stylize( $look->style( $_->[2] ), $_->[0], $_->[1] ) foreach $overlays->spans_of($index);
$text->select_link( $overlays->selected_in_block($index) );
```

# DESCRIPTION

A [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) draws two things over the
blocks' own styles: the _selected link_, the one `Enter` follows, and
the matches of a _search_, the current one in a style of its own. This
class holds both for one [Term::Fabulous::Document](../Document.md), and every rule
about them: where a search starts, how the matches go around, where the
selection goes next and where it stops.

It knows no widgets. Every operation that changes something returns
the indexes of the blocks whose look changed, each once and in the
order of the document; the view restyles those and no other. An empty
list means that no block changed: the view tells its key table that
nothing happened. ["clear"](#clear) is the one exception, see there.

A new document gets new overlays. That is the one way to forget them
all; there is no reset.

# CONSTRUCTOR

## new

```perl
my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );
```

`document` is a [Term::Fabulous::Document](../Document.md), or `undef` (the default)
for overlays over nothing: no links, and searches that find nothing.
Anything else dies, and so do unknown parameters.

# METHODS

## search

```perl
my @touched = $overlays->search( $text, $top );
```

Marks every occurrence of the text (see
["find\_text" in Term::Fabulous::Document](../Document.md#find_text) for the rules). The current match
is the first one in the block `$top` or after it, else the first one:
the view gives the block at its top, so that a search starts where the
user is. An empty text ends the search. Returns the blocks that had or
have matches. A text that is not a string, or a `$top` that is not a
non-negative integer, dies.

## step\_match

```perl
my @touched = $overlays->step_match(1);     # or -1
```

Makes the next (`1`) or previous (`-1`) match current, around from
the last to the first and back. Returns the blocks of the match left
and of the match reached; nothing while there are no matches.

## query, match\_count, current\_match

The text searched for, or `undef`; the number of matches; and the
number of the current match from 1, or `undef`.

## current\_match\_start

```perl
my ( $block, $offset ) = $overlays->current_match_start;
```

Where the current match starts: the index of its block and the
character offset in the block's text. An empty list without a current
match.

## select\_link

```perl
my @touched = $overlays->select_link( 1, { first => 10, last => 24 } );
```

Selects the next (`1`) or previous (`-1`) link. The second argument
says which blocks are in view, as the hash of
["visible\_items" in Term::Fabulous::Widget::VirtualList](../Widget/VirtualList.md#visible_items), or `undef` while
that is unknown. The selection goes on from the selected link while its
block is in view (or the view is unknown); otherwise it starts at the
first link in or below the view, or the last link in or above it going
back. It stops at the first
and the last link of the document: there, it returns nothing. Otherwise
it returns the blocks the selection left and entered.

## select\_link\_at

```perl
my @touched = $overlays->select_link_at( $block, $start, $end );
```

Selects the link of the block from `$start` to `$end`, the one a
click hit. Dies when the block has no such link: a click on a link the
document does not have is a bug.

## selected\_link

```perl
my $link = $overlays->selected_link;    # the mark's link, or undef
```

The destination of the selected link, whatever the parser gave the
mark (["link" in Term::Fabulous::Document::Mark](Mark.md#link)), or `undef`.

## selected\_mark

```perl
my ( $block, $mark ) = $overlays->selected_mark;
```

The selected link as the index of its block and its
[Term::Fabulous::Document::Mark](Mark.md), which tells where it starts and
ends. An empty list without a selected link.

## selected\_in\_block

```perl
my $index = $overlays->selected_in_block($block);
```

Where the selected link is among the links of the block, from 0, as
the block's [Term::Fabulous::Widget::RichText](../Widget/RichText.md) counts its links (see
[select\_link](../Widget/RichText.md#select_link)); `undef`
when the selected link is in another block, or there is none.

## spans\_of

```perl
foreach my $span ( $overlays->spans_of($block) ) {
        my ( $start, $end, $kind ) = @$span;
}
```

The matches in the block, in the order of the text, as
`[ $start, $end, $kind ]`: the kind is `match`, or `match_current`
for the current match, a kind of [Term::Fabulous::Document::Look](Look.md). The
view turns the kinds into styles of its theme.

## clear

```perl
my @touched = $overlays->clear;
```

Ends the search and drops the selected link. Returns the blocks that
had matches or the selected link. A search without matches touched no
block, so the list can be empty although a search ended: ask
["is\_empty"](#is_empty) before to know whether there was anything to drop.

## is\_empty

```perl
say 'nothing to drop' if $overlays->is_empty;
```

True while there is neither a search nor a selected link.

# SEE ALSO

[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md), [Term::Fabulous::Document](../Document.md),
[Term::Fabulous::Document::Look](Look.md).
