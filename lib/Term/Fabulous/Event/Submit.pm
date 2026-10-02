package Term::Fabulous::Event::Submit;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Submit :isa(Clay::UI::Events::Event) :strict(params) {
	field $value :param :reader;

	method event_name :common { 'Submit' }
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::Submit - Enter was pressed in a text field

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<Submit>, fired by a
L<Term::Fabulous::Widget::TextField> on itself when the user presses
Enter in it. Unknown constructor parameters die.

=head2 value

The text of the field.

=cut
