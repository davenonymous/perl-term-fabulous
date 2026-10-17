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

	# The link marks in the order of the text, as the view's Text
	# counts its links.
	field @links;

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
		@links = $self->_checked_links;
	}

	# A link covers text and shares none of it with another link: the
	# Text that shows the block refuses both, so the block does first.
	method _checked_links () {
		my @sorted = sort { $a->start <=> $b->start } grep { $_->is_link } @$marks;
		foreach my $index ( 0 .. $#sorted ) {
			my $link = $sorted[$index];
			die ref($self) . ": the link mark at " . $link->start . " covers no text" if $link->start == $link->end;
			next unless $index;
			my $before = $sorted[ $index - 1 ];
			die ref($self) . ": the link marks " . $before->start . " to " . $before->end . " and " . $link->start . " to " . $link->end . " overlap" if $link->start < $before->end;
		}
		return @sorted;
	}

	method kind;

	method marks () {
		return @$marks;
	}

	method links () {
		return @links;
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

Term::Fabulous::Document::Block - Base class for the blocks of a document

=head1 SYNOPSIS

	foreach my $block ( $document->blocks ) {
		say $block->kind, ' at indent ', $block->indent, ': ', $block->text;
		say '  ', $_->kind, ' ', $_->start, '..', $_->end foreach $block->marks;
	}

=head1 DESCRIPTION

A L<Term::Fabulous::Document> is an ordered list of blocks. A block is
one paragraph-like unit of the document, such as a heading, a paragraph
or a list item, and the L<Term::Fabulous::Widget::DocumentView> shows
each block as a unit of its own, separated from its neighbors by a
blank row in most cases.

A block holds plain data that the view can show without knowing the
source format. The parser that created it (L<Pod::Fabulous::Parser> for
POD, L<Term::Fabulous::Widget::Markdown> for Markdown) has already
resolved everything a formatter would otherwise work out: the
formatting codes are removed from the text and recorded as
L<marks|Term::Fabulous::Document::Mark>, entities are replaced by the
characters they stand for, and the nesting of lists and block quotes is
recorded in the L</indent> and the L</quote> of each block. See
L<Term::Fabulous::Document/Writing a parser> for the full list.

A block is immutable: its parameters are checked when it is created and
never change afterwards.

=head2 Built-in kinds

This class is abstract; every block is an object of a subclass, and the
subclass determines the block's L</kind>. Term::Fabulous ships five
kinds:

=over

=item L<Term::Fabulous::Document::Block::Heading>

Kind C<heading>: a heading of level 1 to 6.

=item L<Term::Fabulous::Document::Block::Paragraph>

Kind C<paragraph>: an ordinary paragraph of text.

=item L<Term::Fabulous::Document::Block::Item>

Kind C<item>: an item of a bulleted or numbered list, with its marker.

=item L<Term::Fabulous::Document::Block::Term>

Kind C<term>: the term that an entry of a definition list defines.

=item L<Term::Fabulous::Document::Block::Verbatim>

Kind C<verbatim>: a verbatim paragraph, usually code, shown line by
line without wrapping.

=back

=head2 Adding a kind

A format that has blocks the built-in kinds do not cover, such as a
table or a horizontal rule, adds kinds of its own. A new kind needs two
parts:

=over

=item *

A subclass of this class that returns a new word from L</kind>. If the
body of the block is not text that wraps like a paragraph, the subclass
also overrides L</body_rows>, and L</row_of_character> if the block has
text that can be searched.

=item *

A subclass of L<Term::Fabulous::Widget::DocumentView> with a method
C<view_of_KIND> that builds the widget for blocks of the new kind (see
L<Term::Fabulous::Widget::DocumentView/BLOCK KINDS>). The view dies
when it has to show a block for whose kind it has no such method.

=back

For example, a horizontal rule has no text and always takes one row:

	use v5.32;
	use feature 'signatures';
	no warnings 'experimental::signatures';
	use Object::Pad 0.825;
	use Term::Fabulous::Document::Block;

	class My::Block::Rule :isa(Term::Fabulous::Document::Block) :strict(params) {
		ADJUST {
			die "My::Block::Rule: a rule has no text" if length $self->text;
		}

		method kind () {
			return 'rule';
		}

		method body_rows :override ($columns) {
			return 1;
		}
	}

	my $rule = My::Block::Rule->new( text => '' );

L<Term::Fabulous::Cookbook::Documents> shows complete examples,
including the matching view subclass.

=head1 CONSTRUCTOR

=head2 new

	my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Some text.', marks => [$mark], indent => 2 );

Creates a block. Because this class is abstract, C<new> must be called
on a subclass; each subclass may accept further parameters. Unknown
parameters die. The parameters every block accepts are:

=over

=item C<text>

Required. The text of the block, a string with all formatting removed.
For a heading, paragraph, item or term, the text is a single line: the
view wraps it to the width available, breaking lines only at spaces,
so a parser joins the source lines of a paragraph with single spaces.
A verbatim block keeps its lines, separated by C<"\n">. A missing,
undefined or reference value dies.

=item C<marks>

An array reference of L<Term::Fabulous::Document::Mark> objects. The
default is an empty array. Every mark must lie within the text: a mark
whose end offset is greater than the length of the text dies, and so
does an element that is not a mark object. The order of the marks
matters; see L</marks>. Link marks are checked further: one that
covers no text (C<start> equal to C<end>) dies, and so do two link
marks that overlap, because the view shows them as the links of a
L<Term::Fabulous::Widget::Text>, which refuses both. The block
keeps a copy of the array.

=item C<indent>

A non-negative integer, default 0: the number of columns by which the
block is indented, in addition to the view's own
L<indent|Term::Fabulous::Widget::DocumentView/indent>. A parser sets it
from the lists the block is nested in.

=item C<quote>

A non-negative integer, default 0: the number of block quotes the block
is nested in. The view draws a vertical bar to the left of the block
for each level, followed by a space (see
L<Term::Fabulous::Widget::DocumentView/How blocks are shown>).

=back

=head1 METHODS

=head2 kind

	my $kind = $block->kind;    # 'heading', 'paragraph', 'item', 'term', 'verbatim', ...

Returns the kind of the block: a word that each subclass defines. The
document view uses it to choose how to show the block, and
L<Term::Fabulous::Document> uses it to find headings and terms. Every
subclass must implement this method.

=head2 text

	my $text = $block->text;

Returns the text of the block, without formatting.

=head2 marks

	my @marks = $block->marks;

Returns the marks of the block in the order they were given to the
constructor. The order matters where marks overlap: the view applies
the styles of the marks in this order, so a later mark wins where two
marks set the same attribute, such as the text color. A parser usually
adds the marks in the order the formatting opens in the source.

=head2 links

	my @links = $block->links;

Returns the marks of kind C<link>, ordered by their start offset,
whatever order they were given in. This is the order in which the view
counts the links of a block; link marks never overlap, so the order is
unambiguous.

=head2 indent

	my $columns = $block->indent;

Returns the indent of the block, in columns.

=head2 quote

	my $depth = $block->quote;

Returns the number of block quotes the block is nested in.

=head2 body_rows

	my $rows = $block->body_rows($columns);

Returns the number of rows the body of the block takes when it is laid
out C<$columns> columns wide, which must be a positive integer. The
body is the block's content without the blank row the view may put
above it. L<Term::Fabulous::Document::Geometry> calls this method to
estimate the height of a block the view has not laid out yet.

This implementation wraps the text at spaces the way Clay does (see
L<Term::Fabulous::Text::Wrap/wrapped_rows>) and returns at least 1.
L<Term::Fabulous::Document::Block::Verbatim> overrides it to return
one row per line. A subclass whose body is not wrapped text, such as a
table, overrides it too.

=head2 row_of_character

	my $row = $block->row_of_character( $offset, $columns );

Returns the row, counted from 0, on which the character at character
offset C<$offset> appears when the body is laid out C<$columns> columns
wide. The offset must be a non-negative integer and the columns a
positive integer. The view uses this to scroll a search match or a
selected link into view.

This implementation wraps the text as L</body_rows> does (see
L<Term::Fabulous::Text::Wrap/wrapped_row>): a space belongs to the word
before it, and an offset past the end of the text is on the last row.
In a verbatim block, the row is the number of line breaks before the
offset.

=head1 SEE ALSO

L<Term::Fabulous::Document>, L<Term::Fabulous::Document::Mark>,
L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Widget::DocumentView>,
L<Term::Fabulous::Cookbook::Documents>.

=cut
