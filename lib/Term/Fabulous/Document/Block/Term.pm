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

Term::Fabulous::Document::Block::Term - The term of an item in a list of definitions

=head1 SYNOPSIS

	my $term = Term::Fabulous::Document::Block::Term->new( text => 'open FILEHANDLE,EXPR', indent => 0 );

=head1 DESCRIPTION

The term a list of definitions defines, such as C<=item open FILEHANDLE>
in L<perlfunc>. The paragraphs that describe it follow as blocks of
their own, indented one level deeper, and the view leaves no blank row
between the term and the first of them. Terms are link targets just
like headings (see L<Term::Fabulous::Document/find_section>).

It has the parameters and methods of L<Term::Fabulous::Document::Block>
and nothing more; its L<kind|Term::Fabulous::Document::Block/kind> is
C<term>.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Block::Item>.

=cut
