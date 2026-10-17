package Term::Fabulous::Document;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document :strict(params) {
	use List::Util qw(first);
	use Scalar::Util qw(blessed);
	use Term::Fabulous::Check qw(describe string);

	field $blocks :param = [];
	field $source :param :reader = undef;

	# What viewers ask for again and again, worked out once: the indexes
	# of the headings, and every link with the block it is in.
	field @heading_indexes;
	field @links;

	ADJUST {
		die "Term::Fabulous::Document: blocks must be an array reference of Term::Fabulous::Document::Block, got " . describe($blocks) unless ref $blocks eq 'ARRAY';
		foreach my $block (@$blocks) {
			die "Term::Fabulous::Document: blocks must be Term::Fabulous::Document::Block objects, got " . describe($block) unless blessed $block && $block->isa('Term::Fabulous::Document::Block');
		}
		$blocks = [@$blocks];
		$source = string( $self, source => $source ) if defined $source;

		@heading_indexes = grep { $blocks->[$_]->kind eq 'heading' } 0 .. $#$blocks;
		@links           = map {
			my $index = $_;
			map { [ $index, $_ ] } $blocks->[$index]->links
		} 0 .. $#$blocks;
	}

	method blocks () {
		return @$blocks;
	}

	method count () {
		return scalar @$blocks;
	}

	method block ($index) {
		return $blocks->[ $self->_checked_index( block => $index ) ];
	}

	# The index of a block of the document, or a death that says why not.
	method _checked_index ( $method, $index ) {
		die "Term::Fabulous::Document: $method needs an index, got " . describe($index) unless defined $index && !ref $index && $index =~ /\A[0-9]+\z/;
		die "Term::Fabulous::Document: block $index does not exist, the document has " . scalar(@$blocks) . " blocks" unless $index < @$blocks;
		return $index;
	}

	method heading_indexes () {
		return @heading_indexes;
	}

	method headings () {
		return map { $blocks->[$_] } @heading_indexes;
	}

	# A section number, as section_at returns it, or a death that says why
	# not.
	method _checked_section ( $method, $number ) {
		die "Term::Fabulous::Document: $method needs a section number, got " . describe($number) unless defined $number && !ref $number && $number =~ /\A[0-9]+\z/;
		die "Term::Fabulous::Document: section $number does not exist, the document has " . scalar(@heading_indexes) . " sections" unless $number < @heading_indexes;
		return $number;
	}

	method block_of_section ($number) {
		return $heading_indexes[ $self->_checked_section( block_of_section => $number ) ];
	}

	method heading_of_section ($number) {
		return $blocks->[ $heading_indexes[ $self->_checked_section( heading_of_section => $number ) ] ];
	}

	method links () {
		return map { [@$_] } @links;
	}

	# The number of the heading whose section the block is in: the last
	# heading at or before it. undef for blocks before the first heading.
	method section_at ($index) {
		$index = $self->_checked_index( section_at => $index );
		my ( $low, $high ) = ( 0, $#heading_indexes );
		return undef if $high < 0 || $heading_indexes[0] > $index;
		while ( $low < $high ) {
			my $middle = int( ( $low + $high + 1 ) / 2 );
			if   ( $heading_indexes[$middle] <= $index ) { $low  = $middle }
			else                                         { $high = $middle - 1 }
		}
		return $low;
	}

	# ---------------------------------------------------------------------
	# Sections, as links name them
	# ---------------------------------------------------------------------

	sub _normalized ($text) {
		return join ' ', split ' ', $text;
	}

	# The block a link to the section leads to. Headings come before
	# terms, exact matches before matches that ignore case, and those
	# before a heading or term that starts with the name as a word
	# ("open" finds "open FILEHANDLE,EXPR" in perlfunc).
	method find_section ($name) {
		die "Term::Fabulous::Document: find_section needs a section name, got " . describe($name) unless defined $name && !ref $name;
		my $wanted = _normalized($name);
		return undef unless length $wanted;

		my @targets = ( @heading_indexes, grep { $blocks->[$_]->kind eq 'term' } 0 .. $#$blocks );
		my %text_of = map { $_ => _normalized( $blocks->[$_]->text ) } @targets;
		my @rules   = (
			sub ($text) { $text eq $wanted },
			sub ($text) { fc($text) eq fc($wanted) },
			sub ($text) { $text =~ /\A\Q$wanted\E(?!\w)/ },
			sub ($text) { $text =~ /\A\Q$wanted\E(?!\w)/i },
		);
		foreach my $rule (@rules) {
			my $found = first { $rule->( $text_of{$_} ) } @targets;
			return $found if defined $found;
		}
		return undef;
	}

	# ---------------------------------------------------------------------
	# Searching
	# ---------------------------------------------------------------------

	# Every occurrence of the text, as [ block index, start, end ], in the
	# order of the document. A query without capital letters ignores case.
	method find_text ($query) {
		die "Term::Fabulous::Document: find_text needs a string, got " . describe($query) unless defined $query && !ref $query;
		return () unless length $query;
		my $pattern = $query =~ /\p{Lu}/ ? qr/\Q$query\E/ : qr/\Q$query\E/i;

		my @matches;
		foreach my $index ( 0 .. $#$blocks ) {
			my $text = $blocks->[$index]->text;
			push @matches, [ $index, $-[0], $+[0] ] while $text =~ /$pattern/g;
		}
		return @matches;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document - A format-independent document model for the document view

=head1 SYNOPSIS

	use Term::Fabulous::Document;
	use Term::Fabulous::Document::Block::Heading;
	use Term::Fabulous::Document::Block::Paragraph;
	use Term::Fabulous::Document::Mark;

	my $document = Term::Fabulous::Document->new(
		blocks => [
			Term::Fabulous::Document::Block::Heading->new( text => 'NAME', level => 1 ),
			Term::Fabulous::Document::Block::Paragraph->new(
				text  => 'Call frobnicate() or see perlfunc.',
				marks => [
					Term::Fabulous::Document::Mark->new( start => 5,  end => 17, kind => 'code' ),
					Term::Fabulous::Document::Mark->new( start => 25, end => 33, kind => 'link', link => 'perlfunc' ),
				],
			),
		],
		source => 'lib/Foo/Bar.pm',
	);

	say $document->count, ' blocks';
	foreach my $heading ( $document->headings ) {
		say '  ' x ( $heading->level - 1 ), $heading->text;
	}

	my $target  = $document->find_section('NAME');        # 0, the index of the heading
	my @matches = $document->find_text('frobnicate');    # ( [ 1, 5, 15 ] )

=head1 DESCRIPTION

A document holds the content of a page in a form that
L<Term::Fabulous::Widget::DocumentView> can show without knowing the
format it was written in. A parser reads a source, such as a POD file or
a Markdown file, and turns it into a document; the view displays the
document. The document itself knows nothing about the screen, and the
view knows nothing about POD or Markdown.

Besides holding the blocks, a document answers the questions a reader
program asks about them: where the headings are, which section a block
belongs to, which block a link to a named section leads to, and where a
text occurs.

A document is immutable: its blocks are checked when it is built and
never change afterwards. To show different content, build a new
document and give it to the view (see
L<Term::Fabulous::Widget::DocumentView/document>).

=head2 The model

The model has three levels:

=over

=item *

A I<document> is an ordered list of blocks, in reading order.

=item *

A I<block> (L<Term::Fabulous::Document::Block>) is one paragraph-like
unit: a heading, a paragraph, a list item, the term of a definition
list or a verbatim (code) paragraph. A format can add kinds of its own
(see L<Term::Fabulous::Document::Block/Adding a kind>). Every block has a I<kind>, its
plain I<text> with all formatting removed, and a list of marks. Two
numbers place it in the nesting of the source: its I<indent> in columns,
which comes from the lists it is in, and its I<quote> depth, the number
of block quotes it is in.

=item *

A I<mark> (L<Term::Fabulous::Document::Mark>) records that a range of a
block's text is formatted in some way: bold, italic, code, a link, and
so on. The range is given by a start offset and an end offset. Offsets
count characters of the Perl string (as C<substr> and C<length> do),
not bytes and not terminal columns, and the end offset is exclusive:
the mark covers the characters from C<start> up to, but not including,
C<end>.

=back

The document has no tree structure. Nesting in the source, such as a
list inside a list item or a paragraph inside a block quote, is
flattened into the indent and the quote depth of each block.

=head2 Writing a parser

A parser for a new format reads the source and produces the list of
blocks. The parser resolves everything a formatter would normally work
out, so that the blocks hold plain data:

=over

=item *

Formatting codes are removed from the text and recorded as marks of
kinds such as C<bold>, C<italic> or C<code> (see
L<Term::Fabulous::Document::Mark/Kinds>). The offsets of a mark refer
to the text I<after> all formatting has been removed.

=item *

Links become marks of kind C<link> that carry the link's destination,
in any form the program understands (see
L<Term::Fabulous::Document::Mark/link>).

=item *

Entities and escapes, such as C<< EE<lt>gtE<gt> >> in POD or C<&amp;> in
Markdown, are replaced by the characters they stand for before offsets
are computed.

=item *

The text of a heading, paragraph, item or term is a single line. The
view wraps it at spaces to the width available, so the parser joins
the source lines of a paragraph with single spaces.

=item *

List nesting becomes the C<indent> of the blocks: an item has the
indent of its list, and the blocks inside the item, including the items
of a nested list, are indented further by the item's C<marker_width>,
so that they line up with the item's text.

=item *

Block quote nesting becomes the C<quote> depth of every block inside
the quote.

=item *

Each list item gets a marker (a bullet or a number such as C<3.>), and
all items of one list share one C<marker_width> (see
L<Term::Fabulous::Document::Block::Item>).

=item *

In a definition list, each term becomes a
L<Term::Fabulous::Document::Block::Term>, followed by the blocks that
define it, indented deeper than the term.

=item *

Verbatim paragraphs keep their lines, separated by C<"\n">, with the
indentation all lines share removed and tabs expanded to spaces (see
L<Term::Fabulous::Document::Block::Verbatim>).

=back

L<Pod::Fabulous::Parser> is such a parser for POD. A format can also add
information of its own by subclassing this class, as
L<Pod::Fabulous::Document> adds the name and the abstract of a POD page.
L<Term::Fabulous::Cookbook::Documents> builds documents step by step and
walks through writing a parser for a new format.

=head2 Sections

Several methods work with I<sections>. A section starts at a heading
and runs up to the next heading of any level, so sections are not
nested. Sections are numbered from 0 in document order: section C<$n>
starts with the heading at block index C<< ($document->heading_indexes)[$n] >>.
Blocks before the first heading belong to no section.

=head1 CONSTRUCTOR

=head2 new

	my $document = Term::Fabulous::Document->new( blocks => \@blocks, source => $path );

Creates a document. Unknown parameters die. The parameters are:

=over

=item C<blocks>

An array reference of L<Term::Fabulous::Document::Block> objects, in
reading order. The default is an empty array: a document without
blocks. The document keeps a copy of the array, so changing the array
afterwards does not change the document. A value that is not an array
reference, or an element that is not a block object, dies.

=item C<source>

A string that identifies where the document came from, usually the path
of the file it was read from, or C<undef> (the default), for example
for a document parsed from a string. Term::Fabulous does not use the
value; it is there for the program. A reference dies.

=back

=head1 METHODS

=head2 blocks

	my @blocks = $document->blocks;

Returns the list of blocks, in reading order.

=head2 count

	my $count = $document->count;

Returns the number of blocks.

=head2 block

	my $block = $document->block($index);

Returns the block at a block index, from 0 to C<< $document->count - 1 >>.
An index that is not a non-negative integer, or that is not less than
the number of blocks, dies.

=head2 source

	my $path = $document->source;

Returns the C<source> given to the constructor, or C<undef>.

=head2 heading_indexes

	my @indexes = $document->heading_indexes;

Returns the block indexes of all headings (blocks whose
L<kind|Term::Fabulous::Document::Block/kind> is C<heading>, see
L<Term::Fabulous::Document::Block::Heading>), in document order. This
is the table of contents of the document: the position of an index in
this list is the number of its L<section|/Sections>.

=head2 headings

	my @headings = $document->headings;

Returns the heading blocks themselves, in the same order as
L</heading_indexes>: the heading of section C<$n> is C<$headings[$n]>.

	# A table of contents, indented by heading level:
	foreach my $heading ( $document->headings ) {
		say '  ' x ( $heading->level - 1 ), $heading->text;
	}

=head2 section_at

	my $number = $document->section_at($index);

Returns the number of the L<section|/Sections> that the block at
C<$index> belongs to: the position, in L</heading_indexes>, of the last
heading at or before the block. A heading belongs to the section it
starts. Returns C<undef> for a block before the first heading, and for
every block of a document without headings. An invalid block index
dies, as in L</block>.

=head2 heading_of_section

	my $heading = $document->heading_of_section($number);
	say $heading->text;

Returns the heading block that starts section C<$number>, with sections
numbered as L</section_at> returns them. A number that is not a
non-negative integer less than the number of sections dies.

=head2 block_of_section

	my $index = $document->block_of_section($number);

Returns the block index of the heading that starts section C<$number>,
which is where the section begins. A number that is not a non-negative
integer less than the number of sections dies.

=head2 links

	foreach my $link ( $document->links ) {
		my ( $index, $mark ) = @$link;
		say $mark->link, ' in block ', $index;
	}

Returns every link of the document as a list of array references
C<[ $block_index, $mark ]>, where C<$mark> is a
L<Term::Fabulous::Document::Mark> of kind C<link>. The links are in
the order of the text: by block, and within a block by start offset
(see L<Term::Fabulous::Document::Block/links>). Each call returns new
array references, so the caller may change them.

=head2 find_section

	my $index = $document->find_section('open');

Returns the block index that a link to the named section leads to, or
C<undef> when no block matches. The candidates are the headings and the
terms of definition lists (L<Term::Fabulous::Document::Block::Term>).
Before comparing, leading and trailing whitespace is removed from the
name and from the text of each candidate, and every run of whitespace
inside is replaced by a single space. A name that is empty after this
returns C<undef>; an undefined name or a reference dies.

The rules below are tried in order, and the first rule that matches any
candidate decides. Within a rule, headings are preferred to terms, and
an earlier block to a later one.

=over

=item 1.

The text equals the name exactly.

=item 2.

The text equals the name when case is ignored (compared with C<fc>).

=item 3.

The text starts with the name, and the name is followed either by the
end of the text or by a character that is not a word character. This
lets C<open> find the term C<open FILEHANDLE,EXPR>, as a link to
L<perlfunc/open> intends.

=item 4.

The same as rule 3, but ignoring case.

=back

=head2 find_text

	my @matches = $document->find_text('hash');
	foreach my $match (@matches) {
		my ( $index, $start, $end ) = @$match;
		say "block $index: ", substr( $document->block($index)->text, $start, $end - $start );
	}

Searches the text of every block for a query and returns every
occurrence as an array reference C<[ $block_index, $start, $end ]>,
where C<$start> and C<$end> are character offsets into the block's
text, with C<$end> exclusive. The occurrences are in document order and
do not overlap.

The query is plain text, not a regular expression. Case is handled as
C<less -i> handles it: a query without uppercase letters ignores case
(C<hash> finds C<Hash>), and a query with at least one uppercase letter
matches case exactly (C<Hash> does not find C<hash>). An empty query
returns an empty list; an undefined query or a reference dies.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Mark>,
L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Cookbook::Documents>,
L<Pod::Fabulous::Parser>.

=cut
