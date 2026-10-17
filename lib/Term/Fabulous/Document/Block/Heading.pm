package Term::Fabulous::Document::Block::Heading;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block::Heading :isa(Term::Fabulous::Document::Block) :strict(params) {
	use Term::Fabulous::Check qw(describe);

	field $level :param :reader;

	ADJUST {
		die "Term::Fabulous::Document::Block::Heading: level must be an integer from 1 to 6, got " . describe($level)
			unless defined $level && !ref $level && $level =~ /\A[1-6]\z/;
		$level += 0;
		die "Term::Fabulous::Document::Block::Heading: a heading is not indented" if $self->indent;
	}

	method kind () {
		return 'heading';
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block::Heading - A heading block of level 1 to 6

=head1 SYNOPSIS

	my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'DESCRIPTION', level => 1 );
	say $heading->level;    # 1

=head1 DESCRIPTION

A heading block holds a heading of a document, such as C<=head1> in POD
or C<#> in Markdown. Its level runs from 1, the top level, to 6.

Headings divide a document into sections: L<Term::Fabulous::Document>
lists them in L<Term::Fabulous::Document/heading_indexes> and
L<Term::Fabulous::Document/headings>, and treats them as targets for
links to sections (see L<Term::Fabulous::Document/find_section>).

The document view shows the whole text of a heading in the style of
its level (C<heading1> to C<heading6> of
L<Term::Fabulous::Document::Look/KINDS>), with marks applied on top,
and draws a horizontal rule under a first-level heading. A heading is
never indented: it starts at the left edge of the view's text area and
ignores the view's L<indent|Term::Fabulous::Widget::DocumentView/indent>.
It can, however, be inside a block quote.

=head1 CONSTRUCTOR

=head2 new

	my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'Methods', level => 2 );

Creates a heading block. It accepts the parameters of
L<Term::Fabulous::Document::Block/new>, plus:

=over

=item C<level>

Required. The level of the heading, an integer from 1 to 6. Any other
value dies.

=back

A heading cannot be indented: an C<indent> other than 0 dies. The
C<quote> parameter is allowed.

=head1 METHODS

A heading block has the methods of L<Term::Fabulous::Document::Block>;
its L<kind|Term::Fabulous::Document::Block/kind> is C<heading>. It adds
one method:

=head2 level

	my $level = $heading->level;

Returns the level of the heading, an integer from 1 to 6.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document/heading_indexes>.

=cut
