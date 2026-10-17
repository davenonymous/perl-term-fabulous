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

Term::Fabulous::Document::Block::Item - An item of a bulleted or numbered list

=head1 SYNOPSIS

	my $item = Term::Fabulous::Document::Block::Item->new( marker => "\x{2022}", marker_width => 2, position => 1, text => 'First point.' );

=head1 DESCRIPTION

An item of a list: a marker (a bullet or the number) followed by the
item's text, which wraps with a hanging indent so that every line
starts after the marker. The paragraphs that belong to the item follow
as blocks of their own, indented by the marker's width.

All items of one list have the same C<marker_width>, wide enough for
the widest marker of the list plus a space, so that their texts line
up (C<9.> and C<10.>). The view leaves no blank row between the items
of one list, nor between an item and the first item of a list nested
in it; two lists that follow each other stay apart, because the first
item of a list has C<position> 1.

=head1 CONSTRUCTOR

=head2 new

	my $item = Term::Fabulous::Document::Block::Item->new( marker => '10.', marker_width => 4, text => 'Tenth.' );

The parameters of L<Term::Fabulous::Document::Block/new> plus:

=over

=item C<marker>

Required. The marker, a non-empty string: the bullet character or the
number with its dot.

=item C<marker_width>

Required. The columns the marker takes, the space after it included:
an integer greater than the marker's width in columns.

=item C<position>

The position of the item in its list, from 1 (the default).

=back

=head1 METHODS

The methods of L<Term::Fabulous::Document::Block>, whose
L<kind|Term::Fabulous::Document::Block/kind> is C<item>, plus:

=head2 marker

	my $marker = $item->marker;

The marker.

=head2 marker_width

	my $columns = $item->marker_width;

The columns between the start of the marker and the start of the text.

=head2 position

	my $position = $item->position;

The position of the item in its list, from 1.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Block::Term>.

=cut
