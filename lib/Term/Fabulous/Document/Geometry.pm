package Term::Fabulous::Document::Geometry;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document::Geometry :strict(params) {
	use List::Util qw(max);
	use Scalar::Util qw(blessed);
	use Term::Fabulous::Check qw(describe non_negative_integer);

	# A block quote takes a bar and a space left of its blocks.
	use constant QUOTE_COLUMNS => 2;

	field $document :param :reader;
	field $indent   :param :reader;

	ADJUST {
		die "Term::Fabulous::Document::Geometry: document must be a Term::Fabulous::Document, got " . describe($document)
			unless blessed $document && $document->isa('Term::Fabulous::Document');
		$indent = non_negative_integer( $self, indent => $indent );
	}

	# The padding left of a block: the quote bars, then the indent of
	# every block but a heading.
	method left_of ($index) {
		my $block = $document->block($index);
		my $left  = $block->quote * QUOTE_COLUMNS;
		return $left if $block->kind eq 'heading';
		return $left + $indent + $block->indent;
	}

	# A blank row between blocks, as between paragraphs on paper, except
	# between the items of a list (the next item, or the first item of a
	# list nested in the item before) and between a term and its
	# definition.
	method space_before ($index) {
		my $block = $document->block($index);
		return 0 if $index == 0;
		my $previous = $document->block( $index - 1 );
		return 0 if $previous->kind eq 'item' && $block->kind eq 'item' && ( $block->position > 1 || $block->indent > $previous->indent );
		return 0 if $previous->kind eq 'term' && $block->kind ne 'term' && $block->indent > $previous->indent;
		return 1;
	}

	# The columns a block's body takes in a box of $box_columns: what the
	# padding and an item's marker leave, at least one.
	method text_columns ( $index, $box_columns ) {
		my $block  = $document->block($index);
		my $marker = $block->kind eq 'item' ? $block->marker_width : 0;
		return max( 1, $box_columns - $self->left_of($index) - $marker );
	}

	# The rows a block takes in a box of $box_columns before it was laid
	# out: the blank row before it, its body, and the rule under a
	# first-level heading.
	method estimated_rows ( $index, $box_columns ) {
		my $block = $document->block($index);
		my $rule  = $block->kind eq 'heading' && $block->level == 1 ? 1 : 0;
		return $self->space_before($index) + $block->body_rows( $self->text_columns( $index, $box_columns ) ) + $rule;
	}

	# The row of the character at $offset in the box of its block, counted
	# from the top of the box: past the blank row before the block, then
	# where the block puts it.
	method row_of_character ( $index, $offset, $box_columns ) {
		my $block = $document->block($index);
		$offset = non_negative_integer( $self, offset => $offset );
		return $self->space_before($index) + $block->row_of_character( $offset, $self->text_columns( $index, $box_columns ) );
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Geometry - The rows and columns of the blocks of a document on the screen

=head1 SYNOPSIS

	use Term::Fabulous::Document::Geometry;

	my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

	my $left  = $geometry->left_of($index);                    # the padding left of the block
	my $space = $geometry->space_before($index);               # 0 or 1 blank row above it
	my $rows  = $geometry->estimated_rows( $index, 78 );       # before it was laid out
	my $row   = $geometry->row_of_character( $index, 120, 78 );

=head1 DESCRIPTION

L<Term::Fabulous::Widget::DocumentView> lays a document out in boxes,
one per block, and lets Clay wrap their text. Before a block is laid
out, the view still needs to know how tall it will be, for the
scrollbar; and to scroll a search match into view, it needs the row of
a character within the block. This class answers both, and the
questions they build on: how far a block is indented, the blank row
above it, and how many columns its body takes. It knows no widget and
no screen.

The height of a body is the block's business
(L<Term::Fabulous::Document::Block/body_rows>): a paragraph wraps its
text as Clay does (L<Term::Fabulous::Text::Wrap>), so its estimate is
exact as long as Clay wraps that way; code takes a row per line; a
block kind of another format answers for itself.

A geometry is a value, for one document and one indent: the view makes
a new one when either changes.

=head1 CONSTRUCTOR

=head2 new

	my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

Both parameters are required: a L<Term::Fabulous::Document>, and the
columns every block but a heading is indented by, a non-negative
integer. Anything else dies, and so do unknown parameters.

=head1 METHODS

The methods that take a block index die for an index the document has
no block for, as L<Term::Fabulous::Document/block> does. Column counts
are those of the block's box: the width of the view inside its border,
padding and scrollbar.

=head2 document, indent

The parameters.

=head2 left_of

	my $columns = $geometry->left_of($index);

The padding left of the block: two columns for every block quote it is
in (L<Term::Fabulous::Document::Block/quote>), then, for every block
but a heading, the indent plus the block's own
(L<Term::Fabulous::Document::Block/indent>).

=head2 space_before

	my $rows = $geometry->space_before($index);

The blank rows above the block: one, as between paragraphs on paper,
except above the first block, between the items of one list (an item
after the first, see L<Term::Fabulous::Document::Block::Item/position>),
between an item and the first item of a list nested in it (an item
indented deeper than the item before it) and between a term and the
indented blocks that define it.

=head2 text_columns

	my $columns = $geometry->text_columns( $index, $box_columns );

The columns the block's body takes: what the box leaves after
L</left_of> and the marker of an item, at least one.

=head2 estimated_rows

	my $rows = $geometry->estimated_rows( $index, $box_columns );

The rows the block takes: L</space_before>, then the block's
L<body_rows|Term::Fabulous::Document::Block/body_rows> in
L</text_columns>, and a row for the rule under a first-level heading.

=head2 row_of_character

	my $row = $geometry->row_of_character( $index, $offset, $box_columns );

The row, counted from the top of the block's box, of the character at
the offset in the block's text: past L</space_before>, where the
block's L<row_of_character|Term::Fabulous::Document::Block/row_of_character>
puts it in L</text_columns>.

=head1 SEE ALSO

L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Document>,
L<Term::Fabulous::Text::Wrap>, L<Term::Fabulous::Widget::VirtualList/estimate>.

=cut
