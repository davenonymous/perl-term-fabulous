package Term::Fabulous::Event::Change;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::Change :isa(Clay::UI::Events::Event) :strict(params) {
	field $value :param :reader;

	method event_name :common { 'Change' }
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::Change - The user changed the value of an input widget

=head1 SYNOPSIS

	$text_field->on( Change => sub ($event) {
		say 'now: ', $event->value;
		return Clay::UI::Enum::Result->CONTINUE;
	} );

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<Change>. The input widgets fire it
on themselves after the user changed their value by typing, clicking or
dragging, never when the program sets the value. Like every event it
bubbles to the ancestors while the handlers return
C<Clay::UI::Enum::Result-E<gt>CONTINUE>, so a form can listen for the
changes of all its inputs in one place. Unknown constructor parameters
die.

=head2 value

The new value, as the widget's C<value> reader returns it.

=cut
