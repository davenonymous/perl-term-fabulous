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

Term::Fabulous::Document::Geometry - Where the blocks of a document go on the screen, in rows and columns

=head1 SYNOPSIS

	use Term::Fabulous::Document::Geometry;

	my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

	my $left  = $geometry->left_of($index);                     # columns of padding left of the block
	my $space = $geometry->space_before($index);                # 0 or 1 blank row above it
	my $width = $geometry->text_columns( $index, 78 );          # columns left for its body
	my $rows  = $geometry->estimated_rows( $index, 78 );        # its height before it is laid out
	my $row   = $geometry->row_of_character( $index, 120, 78 ); # the row of character 120 in its box

=head1 DESCRIPTION

You rarely need this class directly: L<Term::Fabulous::Widget::DocumentView>
creates and uses it for you. It matters when you write a new kind of
block (see L<Term::Fabulous::Document::Block>), because the geometry
relies on the block to report how many rows its body takes and on which
row a character lies, or when you build your own widget that lays out a
L<Term::Fabulous::Document> the way the view does.

The view lays a document out as a column of boxes, one per block, and
lets Clay wrap the text inside them. Clay knows the height of a box
only after it has laid the box out, but the view needs heights earlier:
it estimates the height of every block it has not laid out yet, so that
the scrollbar reflects the whole document (see
L<Term::Fabulous::Widget::VirtualList/estimate>). To scroll a search
match or a selected link into view, it also needs the row of a
character within its block. This class answers both questions, and the
ones they depend on: how far a block is indented, whether a blank row
separates it from the block above, and how many columns remain for its
body. It works on numbers only and knows nothing of widgets or the
screen.

The height of a block's body is up to the block itself
(L<Term::Fabulous::Document::Block/body_rows>). A paragraph wraps its
text the way Clay does (L<Term::Fabulous::Text::Wrap>), so its estimate
is exact as long as Clay keeps wrapping that way. A verbatim block
takes one row per line. A block kind added for another format computes
its own height.

A geometry belongs to one document and one indent and never changes.
The view creates a new geometry whenever either of them changes.

=head1 CONSTRUCTOR

=head2 new

	my $geometry = Term::Fabulous::Document::Geometry->new( document => $document, indent => 2 );

Creates the geometry of a document. Both parameters are required:

=over

=item C<document>

The L<Term::Fabulous::Document> whose blocks are measured.

=item C<indent>

A non-negative integer: the number of columns by which every block
except a heading is indented from the left edge of its box, in addition
to the block's own indent.

=back

The constructor dies when C<document> is not a Term::Fabulous::Document,
when C<indent> is not a non-negative integer, and when it gets an
unknown parameter.

=head1 METHODS

The methods that take a block index die when the document has no block
with that index, as L<Term::Fabulous::Document/block> does.

C<$box_columns> is the width of the block's box, in columns. In the
document view, a block's box spans the inside of the view: its width
less its border, padding and scrollbar.

=head2 document, indent

	my $document = $geometry->document;
	my $columns  = $geometry->indent;

Return the values given to the constructor.

=head2 left_of

	my $columns = $geometry->left_of($index);

Returns the number of columns between the left edge of the block's box
and the start of the block. This is two columns for every block quote
the block is in (L<Term::Fabulous::Document::Block/quote>), room for
the quote bar and a space. Every block except a heading is then
indented further by the geometry's L</indent> plus the block's own
indent (L<Term::Fabulous::Document::Block/indent>). A heading is
indented by its quote columns only.

=head2 space_before

	my $rows = $geometry->space_before($index);

Returns the number of blank rows above the block: 1 to separate it from
the block above, as paragraphs are separated on paper, or 0 in these
cases:

=over

=item *

the block is the first block of the document;

=item *

the block and the block before it are both list items, and the block
is either not the first item of its list (see
L<Term::Fabulous::Document::Block::Item/position>) or indented deeper
than the item before it, which makes it the first item of a list nested
in that item;

=item *

the block directly follows a term of a definition list, is not a term
itself and is indented deeper than the term, which makes it the start
of the term's definition.

=back

=head2 text_columns

	my $columns = $geometry->text_columns( $index, $box_columns );

Returns the number of columns left for the block's body in a box that
is C<$box_columns> wide: the box width less L</left_of> and, for an
item, the width of its marker
(L<Term::Fabulous::Document::Block::Item/marker_width>). The result is
at least 1, however narrow the box.

=head2 estimated_rows

	my $rows = $geometry->estimated_rows( $index, $box_columns );

Returns the number of rows the block takes in a box that is
C<$box_columns> wide, computed without laying it out. It is the sum of
L</space_before>, the block's
L<body_rows|Term::Fabulous::Document::Block/body_rows> for
L</text_columns> columns, and one row for the rule under a first-level
heading. The view uses it as the estimate of its
L<Term::Fabulous::Widget::VirtualList>.

=head2 row_of_character

	my $row = $geometry->row_of_character( $index, $offset, $box_columns );

Returns the row of the character at C<$offset> (counted in characters
from 0) in the block's text, counted from 0 at the top of the block's
box in a box that is C<$box_columns> wide. It is L</space_before> plus
the row the block's
L<row_of_character|Term::Fabulous::Document::Block/row_of_character>
reports for L</text_columns> columns. The view adds the result to the
top of the block's box on the screen to find the screen row it has to
scroll into view. Dies when C<$offset> is not a non-negative integer.

=head1 SEE ALSO

L<Term::Fabulous::Cookbook::Documents>, L<Term::Fabulous::Widget::DocumentView>,
L<Term::Fabulous::Document>, L<Term::Fabulous::Document::Block>,
L<Term::Fabulous::Text::Wrap>, L<Term::Fabulous::Widget::VirtualList/estimate>.

=cut
