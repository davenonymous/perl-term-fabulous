package Term::Fabulous::Document::Block::Item;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block::Item :isa(Term::Fabulous::Document::Block) :strict(params) {
	use Term::Fabulous::Check qw(positive_integer string);
	use Term::Fabulous::Unicode qw(string_columns);

	field $marker       :param :reader;
	field $marker_width :param :reader;
	field $position     :param :reader = 1;

	ADJUST {
		$marker       = string( $self, marker => $marker );
		$marker_width = positive_integer( $self, marker_width => $marker_width );
		$position     = positive_integer( $self, position     => $position );
		die "Term::Fabulous::Document::Block::Item: marker must not be empty" unless length $marker;
		my $columns = string_columns($marker);
		die "Term::Fabulous::Document::Block::Item: marker_width $marker_width leaves no space after the marker '$marker' ($columns columns)" if $marker_width <= $columns;
	}

	method kind () {
		return 'item';
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block::Item - An item block of a bulleted or numbered list

=head1 SYNOPSIS

	my $item = Term::Fabulous::Document::Block::Item->new( marker => "\x{2022}", marker_width => 2, position => 1, text => 'First point.' );

=head1 DESCRIPTION

An item block holds the first paragraph of an item of a bulleted or
numbered list, together with the item's I<marker>: the bullet or the
number shown before the text. The document view shows the marker in a
column of its own, C<marker_width> columns wide, and wraps the text in
the remaining width, so that every line of the text starts after the
marker (a hanging indent).

Any further blocks that belong to the item, such as more paragraphs,
code or a nested list, follow the item block as blocks of their own.
A parser gives them an C<indent> of the item's C<indent> plus its
C<marker_width>, so that they line up with the item's text.

=head2 Lists

The document has no list object; a list is a run of item blocks. A
parser gives all items of one list the same C<marker_width>, wide
enough for the widest marker of the list plus at least one space, so
that the texts of all items line up, as with C<9.> and C<10.>:

	use List::Util qw(max);
	use Term::Fabulous::Unicode qw(string_columns);

	my @texts   = map { "Point $_." } 1 .. 10;
	my @markers = map { "$_." } 1 .. @texts;
	my $width   = 1 + max map { string_columns($_) } @markers;    # 4

	my @items = map {
		Term::Fabulous::Document::Block::Item->new(
			marker       => $markers[$_],
			marker_width => $width,
			position     => $_ + 1,
			text         => $texts[$_],
		)
	} 0 .. $#texts;

The C<position> of an item is its ordinal in the list, counted from 1,
regardless of the number its marker shows: the first item of a list
that starts at 5 still has position 1. The view uses it to decide where
a list begins. It leaves no blank row before an item when the block
before it is also an item and either the item is not the first of its
list (its position is greater than 1) or it is indented deeper than the
item before it (it is the first item of a nested list). Every other
item, in particular the first item of a list that directly follows
another list at the same indent, gets a blank row before it, so the two
lists stay apart.

=head1 CONSTRUCTOR

=head2 new

	my $item = Term::Fabulous::Document::Block::Item->new( marker => '10.', marker_width => 4, position => 10, text => 'Tenth.' );

Creates an item block. It accepts the parameters of
L<Term::Fabulous::Document::Block/new>, plus:

=over

=item C<marker>

Required. The marker, a non-empty string, such as a bullet character
(C<"\x{2022}">) or a number with its dot (C<'10.'>). An empty string,
an undefined value or a reference dies.

=item C<marker_width>

Required. The width of the marker column in terminal columns, including
the space after the marker: a positive integer greater than the width
of the marker in columns. A value that leaves no space after the marker
dies.

=item C<position>

The ordinal of the item in its list, a positive integer counted from 1.
The default is 1.

=back

=head1 METHODS

An item block has the methods of L<Term::Fabulous::Document::Block>;
its L<kind|Term::Fabulous::Document::Block/kind> is C<item>. It adds
these methods:

=head2 marker

	my $marker = $item->marker;

Returns the marker.

=head2 marker_width

	my $columns = $item->marker_width;

Returns the width of the marker column in columns: the distance from
the start of the marker to the start of the text.

=head2 position

	my $position = $item->position;

Returns the ordinal of the item in its list, counted from 1.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Block::Term>.

=cut
