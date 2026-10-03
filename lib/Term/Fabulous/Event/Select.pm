package Term::Fabulous::Event::Select;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Select :isa(Clay::UI::Events::Event) :strict(params) {
	field $item  :param :reader;
	field $index :param :reader;
	field $open  :param :reader = 1;

	ADJUST {
		die "Term::Fabulous::Event::Select: index must be a non-negative integer, got " . ( defined $index ? "'$index'" : 'undef' )
			unless defined $index && !ref $index && $index =~ /\A[0-9]+\z/;
		$open = $open ? 1 : 0;
	}

	method event_name :common { 'Select' }
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::Select - The user opened or closed an item of an accordion

=head1 SYNOPSIS

	$accordion->on( Select => sub ($event) {
		my $item = $event->item;
		$status->text( $event->open ? 'Opened ' . $item->title : 'Closed ' . $item->title );
		return;
	} );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Accordion> fires C<Select> on itself when
the user opens or closes one of its items: with a click on the item's
header, with C<Enter> or C<Space> while the header has the focus, or
through C<< $accordion->choose($index) >>, which acts as the user
does. Opening and closing from your program (C<open>, C<close>,
C<open_all>, C<close_all>, C<< $item->open(1) >>) fires nothing. When
opening one item closes another, because the accordion allows one
open item at a time, only the item the user acted on fires.

It is a L<Clay::UI::Events::Event> whose name is C<Select>; listen for
it with C<< $accordion->on( Select => sub ($event) { ... } ) >>. It
bubbles to the accordion's ancestors like every event (see
L<Term::Fabulous::Manual::Events/Return values and bubbling>), and
C<< $event->target >> is the accordion.

=head1 CONSTRUCTOR

=head2 new

	my $event = Term::Fabulous::Event::Select->new( item => $item, index => 2, open => 1 );

The accordion builds these events itself; build one yourself only to
test your listeners, or to fire C<Select> from a widget of your own.
Unknown parameters die, and so does an C<index> that is not a
non-negative integer.

=over

=item C<item>

Required. See L</item>.

=item C<index>

Required. See L</index>.

=item C<open>

A boolean. Default: 1. See L</open>.

=back

=head1 METHODS

=head2 item

The L<Term::Fabulous::Widget::Accordion::Item> the user acted on.

=head2 index

Its position among the accordion's items, from 0.

=head2 open

1 when the item was opened, 0 when it was closed.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Accordion>, L<Term::Fabulous::Manual::Events/EVENTS>,
L<Term::Fabulous::Manual::Layout/ACCORDIONS>.

=cut
