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

Term::Fabulous::Document::Overlays - The selected link and the search matches drawn over a document

=head1 SYNOPSIS

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

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::DocumentView> draws two things over the
blocks' own styles: the I<selected link>, the one C<Enter> follows, and
the matches of a I<search>, the current one in a style of its own. This
class holds both for one L<Term::Fabulous::Document>, and every rule
about them: where a search starts, how the matches go around, where the
selection goes next and where it stops.

It knows no widgets. Every operation that changes something returns
the indexes of the blocks whose look changed, each once and in the
order of the document; the view restyles those and no other. An empty
list means that no block changed: the view tells its key table that
nothing happened. L</clear> is the one exception, see there.

A new document gets new overlays. That is the one way to forget them
all; there is no reset.

=head1 CONSTRUCTOR

=head2 new

	my $overlays = Term::Fabulous::Document::Overlays->new( document => $document );

C<document> is a L<Term::Fabulous::Document>, or C<undef> (the default)
for overlays over nothing: no links, and searches that find nothing.
Anything else dies, and so do unknown parameters.

=head1 METHODS

=head2 search

	my @touched = $overlays->search( $text, $top );

Marks every occurrence of the text (see
L<Term::Fabulous::Document/find_text> for the rules). The current match
is the first one in the block C<$top> or after it, else the first one:
the view gives the block at its top, so that a search starts where the
user is. An empty text ends the search. Returns the blocks that had or
have matches. A text that is not a string, or a C<$top> that is not a
non-negative integer, dies.

=head2 step_match

	my @touched = $overlays->step_match(1);     # or -1

Makes the next (C<1>) or previous (C<-1>) match current, around from
the last to the first and back. Returns the blocks of the match left
and of the match reached; nothing while there are no matches.

=head2 query, match_count, current_match

The text searched for, or C<undef>; the number of matches; and the
number of the current match from 1, or C<undef>.

=head2 current_match_start

	my ( $block, $offset ) = $overlays->current_match_start;

Where the current match starts: the index of its block and the
character offset in the block's text. An empty list without a current
match.

=head2 select_link

	my @touched = $overlays->select_link( 1, { first => 10, last => 24 } );

Selects the next (C<1>) or previous (C<-1>) link. The second argument
says which blocks are in view, as the hash of
L<Term::Fabulous::Widget::VirtualList/visible_items>, or C<undef> while
that is unknown. The selection goes on from the selected link while its
block is in view (or the view is unknown); otherwise it starts at the
first link in or below the view, or the last link in or above it going
back. It stops at the first
and the last link of the document: there, it returns nothing. Otherwise
it returns the blocks the selection left and entered.

=head2 select_link_at

	my @touched = $overlays->select_link_at( $block, $start, $end );

Selects the link of the block from C<$start> to C<$end>, the one a
click hit. Dies when the block has no such link: a click on a link the
document does not have is a bug.

=head2 selected_link

	my $link = $overlays->selected_link;    # the mark's link, or undef

The destination of the selected link, whatever the parser gave the
mark (L<Term::Fabulous::Document::Mark/link>), or C<undef>.

=head2 selected_mark

	my ( $block, $mark ) = $overlays->selected_mark;

The selected link as the index of its block and its
L<Term::Fabulous::Document::Mark>, which tells where it starts and
ends. An empty list without a selected link.

=head2 selected_in_block

	my $index = $overlays->selected_in_block($block);

Where the selected link is among the links of the block, from 0, as
the block's L<Term::Fabulous::Widget::RichText> counts its links (see
L<select_link|Term::Fabulous::Widget::RichText/select_link>); C<undef>
when the selected link is in another block, or there is none.

=head2 spans_of

	foreach my $span ( $overlays->spans_of($block) ) {
		my ( $start, $end, $kind ) = @$span;
	}

The matches in the block, in the order of the text, as
C<[ $start, $end, $kind ]>: the kind is C<match>, or C<match_current>
for the current match, a kind of L<Term::Fabulous::Document::Look>. The
view turns the kinds into styles of its theme.

=head2 clear

	my @touched = $overlays->clear;

Ends the search and drops the selected link. Returns the blocks that
had matches or the selected link. A search without matches touched no
block, so the list can be empty although a search ended: ask
L</is_empty> before to know whether there was anything to drop.

=head2 is_empty

	say 'nothing to drop' if $overlays->is_empty;

True while there is neither a search nor a selected link.

=head1 SEE ALSO

L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Document>,
L<Term::Fabulous::Document::Look>.

=cut
