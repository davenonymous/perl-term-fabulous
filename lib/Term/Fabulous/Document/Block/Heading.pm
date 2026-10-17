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

Term::Fabulous::Document::Block::Heading - A heading, level 1 to 6

=head1 SYNOPSIS

	my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'DESCRIPTION', level => 1 );
	say $heading->level;    # 1

=head1 DESCRIPTION

A heading of a document: C<=head1> in POD, C<#> in Markdown. Headings
are never indented by a list, but may be inside a block quote.

=head1 CONSTRUCTOR

=head2 new

	my $heading = Term::Fabulous::Document::Block::Heading->new( text => 'Methods', level => 2 );

The parameters of L<Term::Fabulous::Document::Block/new> plus:

=over

=item C<level>

Required. An integer from 1 to 6.

=back

An C<indent> other than 0 dies.

=head1 METHODS

The methods of L<Term::Fabulous::Document::Block>, whose
L<kind|Term::Fabulous::Document::Block/kind> is C<heading>, plus:

=head2 level

	my $level = $heading->level;

The level, 1 to 6.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document/heading_indexes>.

=cut
