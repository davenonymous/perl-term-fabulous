package Term::Fabulous::Event::ViewChange;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::ViewChange :isa(Clay::UI::Events::Event) :strict(params) {
	use Term::Fabulous::Check qw(non_negative_integer string);

	field $top           :param :reader = undef;
	field $bottom        :param :reader = undef;
	field $section       :param :reader = undef;
	field $section_title :param :reader = undef;
	field $percent       :param :reader = 0;
	field $link          :param :reader = undef;
	field $query         :param :reader = undef;
	field $match         :param :reader = undef;
	field $matches       :param :reader = 0;

	ADJUST {
		$top           = non_negative_integer( $self, top     => $top ) if defined $top;
		$bottom        = non_negative_integer( $self, bottom  => $bottom ) if defined $bottom;
		$section       = non_negative_integer( $self, section => $section ) if defined $section;
		$match         = non_negative_integer( $self, match   => $match ) if defined $match;
		$section_title = string( $self, section_title => $section_title ) if defined $section_title;
		die "Term::Fabulous::Event::ViewChange: section and section_title go together; give both or neither" if defined $section != defined $section_title;
		$percent = non_negative_integer( $self, percent => $percent );
		$matches = non_negative_integer( $self, matches => $matches );
		die "Term::Fabulous::Event::ViewChange: percent must be at most 100, got $percent" if $percent > 100;
		die "Term::Fabulous::Event::ViewChange: match $match lies beyond the $matches matches" if defined $match && ( $match < 1 || $match > $matches );

		# A search may find nothing, but every match is of a search.
		$query = string( $self, query => $query ) if defined $query;
		die "Term::Fabulous::Event::ViewChange: query must not be empty" if defined $query && !length $query;
		die "Term::Fabulous::Event::ViewChange: $matches matches without a query" unless defined $query || !$matches;
	}

	method event_name :common () {
		return 'ViewChange';
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Event::ViewChange - What a document view shows has changed

=head1 SYNOPSIS

	$view->on( ViewChange => sub ($event) {
		my $where = $event->section_title // 'top';
		$status->text( sprintf '%s  %d%%', $where, $event->percent );
		return;
	} );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::DocumentView> fires C<ViewChange> on itself
after a frame whose view differs from the one it reported last: the
user scrolled, selected another link, searched, or the program gave it
another document. It carries a summary of the view, everything a status
line or a table of contents needs, so they never have to ask the
widget.

The widget learns what a frame showed only after the frame was drawn,
so the event comes after the frame it describes, and what its
listeners change shows in the next one.

It is a L<Clay::UI::Events::Event> whose name is C<ViewChange>; it
bubbles to the widget's ancestors like every event, and
C<< $event->target >> is the document view.

=head1 CONSTRUCTOR

=head2 new

	my $event = Term::Fabulous::Event::ViewChange->new( top => 0, bottom => 20, percent => 0 );

The widget builds these events itself; build one yourself only to test
your listeners. Every parameter is optional; unknown parameters and
values out of their ranges die. The C<name> and C<bubble_mode>
parameters of L<Clay::UI::Events::Event> are accepted.

=head1 METHODS

=head2 top

	my $index = $event->top;

The index of the first block in view, or C<undef> while the view shows
no document.

=head2 bottom

	my $index = $event->bottom;

The index of the last block in view, or C<undef>.

=head2 section

	my $number = $event->section;

The number of the section the top block is in, as
L<Term::Fabulous::Document/section_at> counts it (the position in
L<heading_indexes|Term::Fabulous::Document/heading_indexes>), or
C<undef> above the first heading.

=head2 section_title

	my $title = $event->section_title;

The text of the heading of that section, defined exactly when
L</section> is, so that a status line can name the section from the
event alone.

=head2 percent

	my $percent = $event->percent;

How far the view is scrolled, 0 at the top to 100 at the end, as
C<less> shows it. A document that fits shows 100.

=head2 link

	my $link = $event->link;

The destination of the selected link, as the parser gave it to the
mark (L<Term::Fabulous::Document::Mark/link>), or C<undef> when no link
is selected.

=head2 query

	my $text = $event->query;

The text of the search, or C<undef> without a search. A search may
find nothing, so a query can come with no matches; matches never come
without their query.

=head2 match, matches

	printf "match %d of %d\n", $event->match, $event->matches if $event->matches;

The number of search matches (0 without a search), and which of them
the view is at, from 1, or C<undef> when none is current.

=head1 SEE ALSO

L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Manual::Events>.

=cut
