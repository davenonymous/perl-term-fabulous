package Term::Fabulous::Document::Block::Paragraph;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block::Paragraph :isa(Term::Fabulous::Document::Block) :strict(params) {

	method kind () {
		return 'paragraph';
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block::Paragraph - An ordinary paragraph block

=head1 SYNOPSIS

	my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Hello, world.', indent => 0 );

=head1 DESCRIPTION

A paragraph block holds an ordinary paragraph of text. This includes
paragraphs inside a list item, inside the definition of a term or
inside a block quote: the C<indent> and C<quote> parameters record how
deeply the paragraph is nested (see
L<Term::Fabulous::Document::Block/new>).

The text is a single line, which the document view wraps to the width
available, breaking lines only at spaces. A parser therefore joins the
source lines of a paragraph with single spaces.

A paragraph block has the constructor parameters and methods of
L<Term::Fabulous::Document::Block> and nothing more; its
L<kind|Term::Fabulous::Document::Block/kind> is C<paragraph>.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>.

=cut
