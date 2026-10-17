package Term::Fabulous::Document::Block::Term;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block::Term :isa(Term::Fabulous::Document::Block) :strict(params) {

	method kind () {
		return 'term';
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block::Term - A term block of a definition list

=head1 SYNOPSIS

	my $term = Term::Fabulous::Document::Block::Term->new( text => 'open FILEHANDLE,EXPR', indent => 0 );

=head1 DESCRIPTION

A term block holds the term that an entry of a definition list
defines, such as C<=item open FILEHANDLE,EXPR> in L<perlfunc>, or a
term of a description list in other formats. The document view shows
its whole text in the C<term> style of
L<Term::Fabulous::Document::Look/KINDS>, with marks applied on top.

The blocks that define the term follow the term block as blocks of
their own, with an C<indent> greater than the term's. L<Pod::Fabulous::Parser>,
for example, indents them by the indent of the C<=over>, 4 columns by
default. The view leaves no blank row between a term and the block
after it if that block is not a term and is indented deeper than the
term. Two terms that follow each other directly are separated by a
blank row.

Terms are targets for links to sections, just like headings (see
L<Term::Fabulous::Document/find_section>), but they do not start
sections of their own.

A term block has the constructor parameters and methods of
L<Term::Fabulous::Document::Block> and nothing more; its
L<kind|Term::Fabulous::Document::Block/kind> is C<term>.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Block::Item>.

=cut
