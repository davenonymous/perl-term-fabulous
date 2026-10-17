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

Term::Fabulous::Document::Block::Paragraph - An ordinary paragraph

=head1 SYNOPSIS

	my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'Hello, world.', indent => 0 );

=head1 DESCRIPTION

An ordinary paragraph of a document, or a paragraph inside a list item
or a block quote, with C<indent> and C<quote> telling how deep. It has
the parameters and methods of L<Term::Fabulous::Document::Block> and
nothing more; its L<kind|Term::Fabulous::Document::Block/kind> is
C<paragraph>.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>.

=cut
