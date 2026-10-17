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

Term::Fabulous::Document - A document as a list of blocks, for a document view

=head1 SYNOPSIS

	use Term::Fabulous::Document;
	use Term::Fabulous::Document::Block::Heading;
	use Term::Fabulous::Document::Block::Paragraph;

	my $document = Term::Fabulous::Document->new(
		blocks => [
			Term::Fabulous::Document::Block::Heading->new( text => 'NAME', level => 1 ),
			Term::Fabulous::Document::Block::Paragraph->new( text => 'Foo::Bar - does things' ),
		],
		source => 'lib/Foo/Bar.pm',
	);

	say $document->count, ' blocks';
	foreach my $heading ( $document->headings ) {
		say '  ' x ( $heading->level - 1 ), $heading->text;
	}

	my $target  = $document->find_section('METHODS');    # a block index, or undef
	my @matches = $document->find_text('frobnicate');    # [ block index, start, end ], ...

=head1 DESCRIPTION

A document is what a parser makes of a source in some documentation
format: the L<blocks|Term::Fabulous::Document::Block> a reader shows,
in order, plus the questions a reader asks about them. It knows nothing
about the screen; L<Term::Fabulous::Widget::DocumentView> shows it, and
knows nothing about the format.

Documents are values: built once, never changed. Opening another page
means parsing another document.

A parser for a format is a function from a source to a document;
L<Pod::Fabulous::Parser> is one for POD, and a subclass of this class
may add what a format knows about itself, as L<Pod::Fabulous::Document>
adds the name and the abstract of a POD page.

=head1 CONSTRUCTOR

=head2 new

	my $document = Term::Fabulous::Document->new( blocks => \@blocks, source => $path );

Unknown parameters die. The parameters:

=over

=item C<blocks>

An array reference of L<Term::Fabulous::Document::Block> objects.
Default: none, an empty document.

=item C<source>

The path of the file the document was read from, or C<undef> (the
default) for a document parsed from a string.

=back

=head1 METHODS

=head2 blocks

	my @blocks = $document->blocks;

The blocks, in the order of the source.

=head2 count

	my $count = $document->count;

The number of blocks.

=head2 block

	my $block = $document->block($index);

The block at an index from 0 to C<count - 1>. Any other index dies.

=head2 source

	my $path = $document->source;

The path of the file the document was read from, or C<undef>.

=head2 heading_indexes

	my @indexes = $document->heading_indexes;

The indexes of the heading blocks (L<Term::Fabulous::Document::Block::Heading>),
in order: the table of contents.

=head2 headings

	my @headings = $document->headings;

The heading blocks themselves, in the same order: section number C<$n>
is C<$headings[$n]>.

=head2 section_at

	my $number = $document->section_at($index);

The number of the section a block is in: the position, in
L</heading_indexes>, of the last heading at or before the block.
C<undef> for blocks before the first heading.

=head2 heading_of_section

	my $heading = $document->heading_of_section($number);
	say $heading->text;

The heading that starts a section, numbered as L</section_at> numbers
them. A number that is not a section of the document dies.

=head2 block_of_section

	my $index = $document->block_of_section($number);

The block index of that heading: where the section starts. A number
that is not a section of the document dies.

=head2 links

	foreach my $link ( $document->links ) {
		my ( $index, $mark ) = @$link;
		say $mark->link, ' in block ', $index;
	}

Every link of the document, in the order of the text, as
C<[ $block_index, $mark ]> with the L<Term::Fabulous::Document::Mark> of
kind C<link>. The array references are copies.

=head2 find_section

	my $index = $document->find_section('open');

The block a link to the named section leads to, or C<undef> when there
is none. Sections are the headings and the terms of definition lists
(L<Term::Fabulous::Document::Block::Term>), compared with runs of
whitespace squeezed to one space. The first of these rules that finds a
block decides, and within a rule headings come before terms and earlier
blocks before later ones:

=over

=item 1.

The text equals the name.

=item 2.

The text equals the name when case is ignored.

=item 3.

The text starts with the name, followed by the end or a character that
is not a word character: C<open> finds C<open FILEHANDLE,EXPR>, the
way L<perlfunc/open> is meant.

=item 4.

As 3., ignoring case.

=back

=head2 find_text

	my @matches = $document->find_text('hash');

Every occurrence of a text in the blocks, as C<[ $block_index, $start,
$end ]> character offsets, in the order of the document; occurrences
do not overlap. A query without capital letters ignores case
(C<hash> finds C<Hash>); one with a capital letter matches case
(C<Hash> does not find C<hash>), as C<less> does with its option
C<-i>. The query is plain text, not a pattern. An empty query finds
nothing.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Mark>,
L<Term::Fabulous::Widget::DocumentView>, L<Pod::Fabulous::Parser>.

=cut
