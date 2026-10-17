package Term::Fabulous::Document::Overlays;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document::Overlays :strict(params) {
	use List::Util qw(first uniqnum);
	use Scalar::Util qw(blessed refaddr);
	use Term::Fabulous::Check qw(describe non_negative_integer);

	field $document :param = undef;

	# Every link of the document as [ block index, mark ], and the
	# selected one, an index into @links.
	field @links;
	field $selected;

	# The search: the text, every match as [ block index, start, end ],
	# the current one an index into @matches, and the matches of each
	# block as [ start, end, index into @matches ].
	field $query;
	field @matches;
	field $match;
	field %matches_of_block;

	ADJUST {
		die "Term::Fabulous::Document::Overlays: document must be a Term::Fabulous::Document or undef, got " . describe($document)
			if defined $document && !( blessed $document && $document->isa('Term::Fabulous::Document') );
		@links = defined $document ? $document->links : ();
	}

	sub _checked_direction ( $method, $direction ) {
		die "Term::Fabulous::Document::Overlays: $method needs a direction of 1 or -1, got " . describe($direction)
			unless defined $direction && !ref $direction && ( $direction eq '1' || $direction eq '-1' );
		return $direction;
	}

	# The blocks an operation touched, each once, in the order of the
	# document.
	sub _blocks (@indexes) {
		my @blocks = sort { $a <=> $b } uniqnum grep { defined } @indexes;
		return @blocks;
	}

	method _block_of_selection () {
		return defined $selected ? $links[$selected][0] : undef;
	}

	method _blocks_of_matches () {
		return keys %matches_of_block;
	}

	method is_empty () {
		return defined $selected || defined $query ? 0 : 1;
	}

	# ---------------------------------------------------------------------
	# Searching
	# ---------------------------------------------------------------------

	method query () {
		return $query;
	}

	method match_count () {
		return scalar @matches;
	}

	method current_match () {
		return defined $match ? $match + 1 : undef;
	}

	method current_match_start () {
		return () unless defined $match;
		return @{ $matches[$match] }[ 0, 1 ];
	}

	# Marks every occurrence; the current match is the first one at or
	# after the block $top, else the first one. An empty text ends the
	# search.
	method search ( $text, $top ) {
		die "Term::Fabulous::Document::Overlays: search needs a string, got " . describe($text) unless defined $text && !ref $text;
		$top = non_negative_integer( $self, top => $top );
		my @had_matches = $self->_blocks_of_matches;

		$query            = length $text                        ? $text                        : undef;
		@matches          = defined $document && defined $query ? $document->find_text($query) : ();
		%matches_of_block = ();
		push @{ $matches_of_block{ $matches[$_][0] } }, [ @{ $matches[$_] }[ 1, 2 ], $_ ] foreach 0 .. $#matches;
		my $from_top = first { $matches[$_][0] >= $top } 0 .. $#matches;
		$match = @matches ? $from_top // 0 : undef;

		return _blocks( @had_matches, $self->_blocks_of_matches );
	}

	# Around from the last match to the first, and back.
	method step_match ($direction) {
		_checked_direction( step_match => $direction );
		return () unless @matches;
		my $before = $matches[$match][0];
		$match = ( $match + $direction ) % @matches;
		return _blocks( $before, $matches[$match][0] );
	}

	# ---------------------------------------------------------------------
	# The selected link
	# ---------------------------------------------------------------------

	method selected_link () {
		return defined $selected ? $links[$selected][1]->link : undef;
	}

	method selected_mark () {
		return () unless defined $selected;
		return @{ $links[$selected] };
	}

	# From the selected link while it is in view, otherwise from the first
	# (or last) link in view; the selection stops at the ends. $visible is
	# { first, last }, the blocks in view, or undef while that is unknown.
	method select_link ( $direction, $visible ) {
		_checked_direction( select_link => $direction );
		die "Term::Fabulous::Document::Overlays: select_link needs the blocks in view as { first, last } or undef, got " . describe($visible)
			if defined $visible && ref $visible ne 'HASH';
		return () unless @links;

		my $next;
		if ( defined $selected && ( !defined $visible || _within( $links[$selected][0], $visible ) ) ) {
			$next = $selected + $direction;
		}
		elsif ( defined $visible ) {
			$next = $direction > 0 ? first { $links[$_][0] >= $visible->{first} } 0 .. $#links : first { $links[$_][0] <= $visible->{last} } reverse 0 .. $#links;
		}
		else {
			$next = $direction > 0 ? 0 : $#links;
		}
		return () unless defined $next && $next >= 0 && $next <= $#links;
		return $self->_select($next);
	}

	sub _within ( $index, $visible ) {
		return $index >= $visible->{first} && $index <= $visible->{last} ? 1 : 0;
	}

	# The link a click hit: the one of the block from $start to $end.
	method select_link_at ( $block, $start, $end ) {
		$block = non_negative_integer( $self, block => $block );
		$start = non_negative_integer( $self, start => $start );
		$end   = non_negative_integer( $self, end   => $end );
		my $position = first { $links[$_][0] == $block && $links[$_][1]->start == $start && $links[$_][1]->end == $end } 0 .. $#links;
		die "Term::Fabulous::Document::Overlays: block $block has no link from $start to $end" unless defined $position;
		return $self->_select($position);
	}

	# The blocks the selection leaves and enters show it.
	method _select ($position) {
		my $before = $self->_block_of_selection;
		$selected = $position;
		return _blocks( $before, $self->_block_of_selection );
	}

	# Where the selected link is among the links of the block, as the
	# block's RichText counts them: both are in the order of the text.
	method selected_in_block ($block) {
		my $selected_block = $self->_block_of_selection;
		return undef unless defined $selected_block && $selected_block == $block;
		my $mark  = $links[$selected][1];
		my @marks = $document->block($block)->links;
		return first { refaddr( $marks[$_] ) == refaddr($mark) } 0 .. $#marks;
	}

	# ---------------------------------------------------------------------
	# Both
	# ---------------------------------------------------------------------

	# The overlay spans of a block, in the order of the text: kinds of
	# Term::Fabulous::Document::Look, not styles.
	method spans_of ($block) {
		return map { [ $_->[0], $_->[1], defined $match && $_->[2] == $match ? 'match_current' : 'match' ] } @{ $matches_of_block{$block} // [] };
	}

	method clear () {
		my @touched = ( $self->_blocks_of_matches, $self->_block_of_selection );
		( $selected, $query, $match, @matches, %matches_of_block ) = ();
		return _blocks(@touched);
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Overlays - Track the selected link and the search matches shown over a document

=head1 SYNOPSIS

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

=head1 DESCRIPTION

You rarely need this class directly: L<Term::Fabulous::Widget::DocumentView>
creates and uses it for you. It is useful when you write your own
widget that shows a L<Term::Fabulous::Document> and want link selection
and search to behave as they do in the document view.

A document view draws two things on top of the blocks' own styles: the
I<selected link>, which is the link that C<Enter> follows, and the
I<matches> of a search, with the I<current match> in a style of its own.
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
0. L</clear> is an exception, described
there.

Overlays belong to one document for their whole life; there is no way
to give them another one. The document view creates new overlays
whenever it shows a new document.

=head1 CONSTRUCTOR

=head2 new

	my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );

Creates overlays for a document, with no search and no selected link.
C<document> is a L<Term::Fabulous::Document>, or C<undef> (the default)
for overlays over no document: there are no links to select, and every
search finds nothing. The constructor dies for any other value of
C<document> and for unknown parameters.

=head1 METHODS

Methods that take a direction accept C<1> for forward and C<-1> for
backward, and die for anything else.

=head2 search

	my @touched = $overlays->search( $text, $top );

Starts a search for C<$text>, replacing any previous search, and marks
every occurrence in the document. L<Term::Fabulous::Document/find_text>
defines what counts as an occurrence.

The current match becomes the first match in block C<$top> or in a
later block; if there is none, it is the first match of the document.
The document view passes the index of the block at its top, so that a
search starts where the user is reading.

An empty C<$text> ends the search. Returns the blocks that had matches
before the call or have matches after it. Dies when C<$text> is not a
string or C<$top> is not a non-negative integer.

=head2 step_match

	my @touched = $overlays->step_match(1);     # or -1

Makes the next (C<1>) or previous (C<-1>) match the current one. The
step wraps around: forward from the last match goes to the first, and
backward from the first goes to the last. Returns the blocks of the
previous and the new current match, or an empty list when there are no
matches.

=head2 query, match_count, current_match

	my $text  = $overlays->query;            # undef without a search
	my $count = $overlays->match_count;
	my $which = $overlays->current_match;    # 1 .. $count, or undef

C<query> returns the text searched for, or C<undef> while there is no
search. C<match_count> returns the number of matches, 0 without any.
C<current_match> returns the number of the current match, counted from
1, or C<undef> while there are no matches.

=head2 current_match_start

	my ( $block, $offset ) = $overlays->current_match_start;

Returns where the current match starts: the index of its block and the
character offset of the match in the block's text. Returns an empty
list while there is no current match.

=head2 select_link

	my @touched = $overlays->select_link( 1, { first => 10, last => 24 } );

Selects the next (C<1>) or previous (C<-1>) link of the document. The
second argument tells which blocks are in view, as the hash reference
that L<Term::Fabulous::Widget::VirtualList/visible_items> returns, or
C<undef> while that is not known. The next link is chosen as follows:

=over

=item *

If a link is selected and either its block is in view or the blocks in
view are not known, the selection moves to the link after (or before)
it.

=item *

Otherwise, if the blocks in view are known, the selection moves to the
first link in a block at or after the first block in view (going
forward), or to the last link in a block at or before the last block in
view (going backward).

=item *

Otherwise, with no selected link and no information about the view, it
moves to the first (or last) link of the document.

=back

The selection does not wrap around. When there is no link in the chosen
direction, the selection stays where it is and the method returns an
empty list; it does the same when the document has no links. Otherwise
it returns the blocks of the previously and the newly selected link.
Dies when the second argument is neither C<undef> nor a hash reference.

=head2 select_link_at

	my @touched = $overlays->select_link_at( $block, $start, $end );

Selects the link of block C<$block> that runs from character offset
C<$start> to C<$end>, typically the link the user clicked. Returns the
blocks of the previously and the newly selected link. Dies when an
argument is not a non-negative integer, and when the block has no link
with exactly that range: a click on a link the document does not have
indicates a bug.

=head2 selected_link

	my $link = $overlays->selected_link;    # the mark's link, or undef

Returns the destination of the selected link, which is whatever the
parser stored in the mark (see L<Term::Fabulous::Document::Mark/link>),
or C<undef> while no link is selected.

=head2 selected_mark

	my ( $block, $mark ) = $overlays->selected_mark;

Returns the selected link as the index of its block and its
L<Term::Fabulous::Document::Mark>, which tells where the link starts
and ends. Returns an empty list while no link is selected.

=head2 selected_in_block

	my $index = $overlays->selected_in_block($block);

Returns the position of the selected link among the links of block
C<$block>, counted from 0 in text order. This is the index that the
block's L<Term::Fabulous::Widget::RichText> expects in its
L<select_link|Term::Fabulous::Widget::RichText/select_link> method.
Returns C<undef> when no link is selected or the selected link is in
another block.

=head2 spans_of

	foreach my $span ( $overlays->spans_of($block) ) {
		my ( $start, $end, $kind ) = @$span;
	}

Returns the search matches in block C<$block>, in text order, each as
an array reference C<[ $start, $end, $kind ]> of character offsets and
a kind. The kind is C<match_current> for the current match and
C<match> for all others; both are kinds of
L<Term::Fabulous::Document::Look>, not styles, so the widget turns them
into styles of its theme with L<Term::Fabulous::Document::Look/style>.
Returns an empty list for a block without matches.

=head2 clear

	my @touched = $overlays->clear;

Ends the search and deselects the selected link. Returns the blocks
that had matches or held the selected link. A search without matches
touched no block, so the list can be empty even though a search ended.
To find out whether there was anything to clear, call L</is_empty>
before C<clear>.

=head2 is_empty

	say 'nothing to clear' if $overlays->is_empty;

Returns 1 while there is neither a search nor a selected link, and 0
otherwise. A search counts even when it found nothing.

=head1 SEE ALSO

L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Document>,
L<Term::Fabulous::Document::Look>.

=cut
