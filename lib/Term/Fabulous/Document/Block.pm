package Term::Fabulous::Document::Block;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block :abstract :strict(params) {
	use Scalar::Util qw(blessed);
	use Term::Fabulous::Check qw(describe non_negative_integer string);
	use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);

	field $text   :param :reader;
	field $marks  :param = [];
	field $indent :param :reader = 0;
	field $quote  :param :reader = 0;

	ADJUST {
		$text   = string( $self, text => $text );
		$indent = non_negative_integer( $self, indent => $indent );
		$quote  = non_negative_integer( $self, quote  => $quote );
		die ref($self) . ": marks must be an array reference of Term::Fabulous::Document::Mark, got " . describe($marks) unless ref $marks eq 'ARRAY';
		my $length = length $text;
		foreach my $mark (@$marks) {
			die ref($self) . ": marks must be Term::Fabulous::Document::Mark objects, got " . describe($mark) unless blessed $mark && $mark->isa('Term::Fabulous::Document::Mark');
			die ref($self) . ": a mark ends at " . $mark->end . ", past the text ($length characters)" if $mark->end > $length;
		}
		$marks = [@$marks];
	}

	method kind;

	method marks () {
		return @$marks;
	}

	method links () {
		return grep { $_->is_link } @$marks;
	}

	# The rows the block's body takes when its text wraps to $columns,
	# and the row of a character in it. A block whose body is not wrapped
	# text (code, a table) overrides both.
	method body_rows ($columns) {
		return wrapped_rows( $text, $columns );
	}

	method row_of_character ( $offset, $columns ) {
		return wrapped_row( $text, $offset, $columns );
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block - One paragraph of a document, ready to be shown

=head1 SYNOPSIS

	foreach my $block ( $document->blocks ) {
		say $block->kind, ' at indent ', $block->indent, ': ', $block->text;
		say '  ', $_->kind, ' ', $_->start, '..', $_->end foreach $block->marks;
	}

=head1 DESCRIPTION

A L<Term::Fabulous::Document> is a list of blocks, one for every
paragraph a L<Term::Fabulous::Widget::DocumentView> shows. A parser
(L<Pod::Fabulous::Parser> for POD, L<Term::Fabulous::Widget::Markdown>
for Markdown) has already resolved everything the source format leaves
to a formatter: the formatting codes are gone from the text and became
L<marks|Term::Fabulous::Document::Mark>, entities are characters, lists
became indents and markers. What remains is plain data that a widget
shows without knowing the format.

This class is abstract. Term::Fabulous ships these kinds of block:

=over

=item L<Term::Fabulous::Document::Block::Heading>

a heading of level 1 to 6;

=item L<Term::Fabulous::Document::Block::Paragraph>

an ordinary paragraph;

=item L<Term::Fabulous::Document::Block::Item>

an item of a bulleted or numbered list, with its marker;

=item L<Term::Fabulous::Document::Block::Term>

the term of an item in a list of definitions;

=item L<Term::Fabulous::Document::Block::Verbatim>

a verbatim paragraph (code), shown line by line without wrapping.

=back

A viewer for another format adds kinds of its own by subclassing this
class: the document view builds a block of kind C<KIND> with its
C<view_of_KIND> method (see
L<Term::Fabulous::Widget::DocumentView/BLOCK KINDS>), and the geometry
asks the block how tall its body is (L</body_rows>).

Blocks are values: they are checked when they are created and never
change.

=head1 CONSTRUCTOR

=head2 new

	my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Some text.', marks => [$mark], indent => 2 );

Called on a subclass; unknown parameters die. The parameters every
block takes:

=over

=item C<text>

Required. The text, a string without formatting codes. Paragraphs are
one line; their line breaks are the viewer's business. A verbatim
block keeps its lines.

=item C<marks>

An array reference of L<Term::Fabulous::Document::Mark> objects, each
within the text. Default: none.

=item C<indent>

A non-negative integer, default 0: how many columns the block is
indented relative to the document's body, from the lists it is in.

=item C<quote>

A non-negative integer, default 0: how many block quotes the block is
inside. The view draws a bar left of the block for each level (see
L<Term::Fabulous::Widget::DocumentView/How blocks are shown>).

=back

=head1 METHODS

=head2 kind

	my $kind = $block->kind;    # 'heading', 'paragraph', 'item', 'term', 'verbatim', ...

The kind of block, one word per subclass.

=head2 text

	my $text = $block->text;

The text.

=head2 marks

	my @marks = $block->marks;

The marks, in the order their formatting codes were opened.

=head2 links

	my @links = $block->links;

The marks of kind C<link>, in the order of the text.

=head2 indent

	my $columns = $block->indent;

The indent, in columns.

=head2 quote

	my $depth = $block->quote;

How many block quotes the block is inside.

=head2 body_rows

	my $rows = $block->body_rows($columns);

The rows the block's body takes in that many columns: its text wrapped
as Clay wraps it (L<Term::Fabulous::Text::Wrap/wrapped_rows>). A
verbatim block takes a row per line instead; a subclass whose body is
not wrapped text overrides this.

=head2 row_of_character

	my $row = $block->row_of_character( $offset, $columns );

The row, from 0, of the character at the offset when the body is laid
out in that many columns (L<Term::Fabulous::Text::Wrap/wrapped_row>);
in a verbatim block, the number of line breaks before it.

=head1 SEE ALSO

L<Term::Fabulous::Document>, L<Term::Fabulous::Document::Mark>,
L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Widget::DocumentView>.

=cut
