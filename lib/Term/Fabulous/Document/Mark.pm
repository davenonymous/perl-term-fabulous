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

Term::Fabulous::Document::Mark - A formatted range of characters in the text of a block

=head1 SYNOPSIS

	use Term::Fabulous::Document::Mark;

	# In the text "See perlfunc", make "perlfunc" (characters 4 to 11) bold:
	my $bold = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'bold' );

	# Or make it a link; the destination can be any value the program understands:
	my $link = Term::Fabulous::Document::Mark->new( start => 4, end => 12, kind => 'link', link => 'https://perldoc.perl.org/perlfunc' );

	foreach my $mark ( $block->marks ) {
		say $mark->kind, ' from ', $mark->start, ' to ', $mark->end;
	}

=head1 DESCRIPTION

A mark records that a range of the text of a
L<Term::Fabulous::Document::Block> is formatted in some way. When a
parser removes the formatting from a paragraph, such as a bold phrase,
a code span or a link, it keeps the plain text in the block and
describes each formatted range with a mark: where the range starts and
ends, and what I<kind> of formatting it is.

Offsets are character offsets into the block's text, counted from 0, as
Perl's C<substr> and C<length> count them; they are not byte offsets
and not terminal columns. The start offset is the first character the
mark covers, and the end offset is exclusive: it is the offset of the
first character after the range. The characters a mark covers are
therefore C<< substr( $text, $mark->start, $mark->span_length ) >>.

A mark describes what a range I<is>, not how it looks.
L<Term::Fabulous::Widget::DocumentView> maps each kind to a style of
the current theme through a L<Term::Fabulous::Document::Look>, so the
same document can be shown in any theme.

A mark is immutable: its parameters are checked when it is created and
never change afterwards.

=head2 Kinds

Every kind except C<link> must name a style of the look the view draws
with. The built-in look provides C<bold>, C<italic>, C<strike>, C<code>
and C<file> for formatting within a paragraph (see
L<Term::Fabulous::Document::Look/KINDS> for the full list). The mark
itself accepts any word as its kind; the view dies when it is given a
document (in C<new> or C<document>) with a mark whose kind its look
does not know. A format that
needs further kinds adds them with a subclass of the look (see
L<Term::Fabulous::Widget::DocumentView/BLOCK KINDS>).

=head2 Link marks

A mark of kind C<link> carries the destination of the link in its
L</link> attribute instead of naming a style. The destination can be
any defined value: a URL or a page name as a string, a hash reference
with several fields, or an object of the program. The view does not
interpret it. When the user follows the link, the view hands the value
back unchanged in the L<LinkActivate|Term::Fabulous::Event::LinkActivate>
event, and the program decides what to do with it.

The view shows link marks as links of a L<Term::Fabulous::Widget::RichText>,
so a link mark must cover text (C<start> less than C<end>) and must not
overlap another link mark of the same block. The mark itself accepts
an empty range, as it does for the other kinds; the block checks both
rules when it is built (see L<Term::Fabulous::Document::Block/new>)
and orders the link marks by their start
(L<Term::Fabulous::Document::Block/links>).

=head2 Overlapping marks

Nested formatting produces marks that overlap, for example C<bold> over
a whole phrase and C<italic> over one word of it. Marks of other kinds
may overlap freely, and a link mark may overlap marks of other kinds.
The view applies the marks of a block in the order the block holds
them, so where two marks set the same attribute, the later one wins
(see L<Term::Fabulous::Document::Block/marks>).

=head1 CONSTRUCTOR

=head2 new

	my $mark = Term::Fabulous::Document::Mark->new( start => 0, end => 4, kind => 'bold' );

Creates a mark. Unknown parameters die, and so does a missing required
parameter. The parameters are:

=over

=item C<start>, C<end>

Required. The offset of the first character the mark covers and the
offset of the first character after it, as non-negative integers. An
C<end> less than C<start> dies; an C<end> equal to C<start> gives an
empty mark. Whether the range lies within the text is checked when the
mark is given to a block (see L<Term::Fabulous::Document::Block/new>).

=item C<kind>

Required. A word, made of letters, digits and underscores: C<link>, or
the name of a style of the view's look, such as C<bold>, C<italic>,
C<strike>, C<code> or C<file>. Anything else dies.

=item C<link>

The destination of a link: any defined value. It is required for a mark
of kind C<link>, and giving a defined value for any other kind dies.

=back

=head1 METHODS

=head2 start

	my $offset = $mark->start;

Returns the character offset of the first character the mark covers.

=head2 end

	my $offset = $mark->end;

Returns the character offset of the first character after the range,
which is one more than the offset of the last character the mark
covers.

=head2 span_length

	my $characters = $mark->span_length;

Returns the number of characters the mark covers, C<< end - start >>.

=head2 kind

	my $kind = $mark->kind;    # 'bold', 'link', ...

Returns the kind of the mark.

=head2 is_link

	if ( $mark->is_link ) { ... }

Returns 1 for a mark of kind C<link>, and 0 for every other kind.

=head2 link

	my $destination = $mark->link;    # or undef

Returns the destination of a C<link> mark, exactly as it was given to
the constructor, or C<undef> for marks of other kinds.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Document::Look>,
L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Event::LinkActivate>,
L<Term::Fabulous::Cookbook::Documents>.

=cut
