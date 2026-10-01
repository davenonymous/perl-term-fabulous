package Term::Fabulous::Event::CanvasResize;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Events::Event;

class Term::Fabulous::Event::CanvasResize :isa(Clay::UI::Events::Event) :strict(params) {
	field $columns :param :reader;
	field $rows    :param :reader;

	method event_name :common { 'CanvasResize' }
}

1;

__END__

=head1 NAME

Term::Fabulous::Event::CanvasResize - A canvas got a new cell size

=head1 DESCRIPTION

A L<Clay::UI::Events::Event> named C<CanvasResize>, fired by a
L<Term::Fabulous::Widget::Canvas> when the layout gives it a new size,
before the frame that shows the new size is painted. Unknown
constructor parameters die.

=head2 columns, rows

The new size of the canvas buffer in cells.

=cut
