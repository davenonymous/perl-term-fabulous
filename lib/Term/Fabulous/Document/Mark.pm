package Term::Fabulous::Document::Mark;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document::Mark :strict(params) {
	use Term::Fabulous::Check qw(describe non_negative_integer);

	field $start :param :reader;
	field $end   :param :reader;
	field $kind  :param :reader;
	field $link  :param :reader = undef;

	ADJUST {
		$start = non_negative_integer( $self, start => $start );
		$end   = non_negative_integer( $self, end   => $end );
		die "Term::Fabulous::Document::Mark: end $end lies before start $start" if $end < $start;
		die "Term::Fabulous::Document::Mark: kind must be a word, got " . describe($kind) unless defined $kind && !ref $kind && $kind =~ /\A\w+\z/;
		die "Term::Fabulous::Document::Mark: a link mark needs a link, got undef" if $kind eq 'link' && !defined $link;
		die "Term::Fabulous::Document::Mark: only a link mark has a link" if $kind ne 'link' && defined $link;
	}

	method is_link () {
		return $kind eq 'link' ? 1 : 0;
	}

	method span_length () {
		return $end - $start;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Mark - A kind of styling over a range of a block's text

=head1 SYNOPSIS

	use Term::Fabulous::Document::Mark;

	# "See perlfunc" with "perlfunc" bold:
	my $bold = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'bold' );

	# ... or a link, to whatever the program's links are:
	my $link = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'link', link => 'https://perldoc.perl.org/perlfunc' );

	foreach my $mark ( $block->marks ) {
		say $mark->kind, ' from ', $mark->start, ' to ', $mark->end;
	}

=head1 DESCRIPTION

A mark is what a parser leaves behind once it has taken the formatting
of a paragraph apart: the range of characters a bold phrase, a code
span or a link covered in the text of a L<Term::Fabulous::Document::Block>,
and what I<kind> of thing it is. Marks say what a range is, not how it
looks; L<Term::Fabulous::Widget::DocumentView> turns the kinds into
styles of the current theme with a L<Term::Fabulous::Document::Look>,
so the same document can be shown in any theme.

Every kind but C<link> names a style of the look the view draws with;
the look of a view dies for a kind it does not know (see
L<Term::Fabulous::Document::Look/KINDS>). A C<link> mark carries the
link's destination instead, any defined value the program gives it: a
string, or an object of the program. The view hands it back in the
L<LinkActivate|Term::Fabulous::Event::LinkActivate> event when the user
follows the link.

Nested formatting gives marks that overlap: C<bold> over a whole
phrase and C<italic> over one word of it. The marks of a block are in
the order the parser opened them.

A mark is a value: it is checked when it is created and never changes.

=head1 CONSTRUCTOR

=head2 new

	my $mark = Term::Fabulous::Document::Mark->new( start => 0, end => 4, kind => 'bold' );

Unknown parameters die. The parameters:

=over

=item C<start>, C<end>

Required. The character offsets of the first character the mark
covers and of the one after the last: non-negative integers with
C<< start <= end >>.

=item C<kind>

Required. A word (letters, digits and underscores): C<link>, or the
name of a style of the view's look, such as C<bold>, C<italic>,
C<code>, C<file> or C<strike>.

=item C<link>

The destination, any defined value; required for C<link> marks and
refused for the others.

=back

=head1 METHODS

=head2 start

	my $offset = $mark->start;

The offset of the first character the mark covers.

=head2 end

	my $offset = $mark->end;

The offset after the last character the mark covers.

=head2 span_length

	my $characters = $mark->span_length;

The number of characters the mark covers, C<< end - start >>.

=head2 kind

	my $kind = $mark->kind;    # 'bold', 'link', ...

The kind.

=head2 is_link

	if ( $mark->is_link ) { ... }

1 for a C<link> mark, 0 otherwise.

=head2 link

	my $destination = $mark->link;    # or undef

The destination of a C<link> mark, C<undef> for the other kinds.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Look>,
L<Term::Fabulous::Widget::DocumentView>.

=cut
