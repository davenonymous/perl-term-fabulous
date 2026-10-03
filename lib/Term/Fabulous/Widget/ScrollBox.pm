package Term::Fabulous::Widget::ScrollBox;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Role::Layout::HasScroll;
use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::ScrollBox
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Layout::HasScroll)
	:strict(params)
{
	# Clay::UI stores these as given; the constructor takes any truth value.
	sub BUILDARGS ( $class, %params ) {
		$params{$_} = $params{$_} ? 1 : 0 foreach grep { exists $params{$_} } qw(horizontal vertical);
		return $class->SUPER::BUILDARGS(%params);
	}

	method layout_properties :common () {
		return ( $class->SUPER::layout_properties, horizontal => 'boolean', vertical => 'boolean' );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::ScrollBox - A box whose content scrolls

=head1 SYNOPSIS

	use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Widget::ScrollBox;
	use Term::Fabulous::Widget::Text;

	my $log = Term::Fabulous::Widget::ScrollBox->new(
		id               => 'log',                  # required
		layout           => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_fixed(10) },
			padding          => { left => 1, right => 1 },
		},
		background_color => [ 30, 35, 50, 255 ],
		border_width     => 1,
		border_color     => [ 120, 160, 220, 255 ],
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
	);
	$log->add_child( Term::Fabulous::Widget::Text->new( text => "Line $_", text_color => [ 220, 220, 220, 255 ] ) )
		foreach 1 .. 100;

	$log->on( OnScroll => sub ($event) {
		printf STDERR "scrolled by %d rows\n", $event->delta_y;
		return;
	} );

=begin html

<p><img src="/screenshots/example-scroll-box.svg" alt="Two framed boxes scrolled down, one with numbered lines, one with squares"></p>

=end html

=head1 DESCRIPTION

A ScrollBox is a L<Term::Fabulous::Widget::Box> for content that is
larger than the box: everything that does not fit is clipped, and the
user scrolls through it with the mouse wheel. Typical uses are logs,
long lists and help texts.

The size of a ScrollBox comes from its own C<sizing>, not from its
content, so give it a C<fixed>, C<grow> or C<percent> height (and
width, when it scrolls sideways). With the default C<fit> sizing the
box grows with its content instead of scrolling it.

Under L<Term::Fabulous>, every notch of the mouse wheel scrolls the
ScrollBox under the pointer by three rows, and every notch of a
horizontal wheel (or a sideways tilt of the wheel) by three columns,
unless a widget under the pointer used the notch to scroll itself (see
L</CAVEATS>). The scroll position is
clamped, so the content cannot be scrolled past its first or last row.
The position is applied when the next frame is drawn. Keys do not
scroll a ScrollBox.

The content is clipped to the whole box, border included: scrolled
content passes under the border, which is drawn on top of it. Content
scrolled out of view receives no mouse events.

=head1 CONSTRUCTOR

=head2 new

	my $box = Term::Fabulous::Widget::ScrollBox->new( id => 'log', %parameters );

Unknown parameters die. A ScrollBox takes every parameter of
L<Term::Fabulous::Widget::Box> (see L<Term::Fabulous::Widget/new>) plus:

=over

=item C<id>

A non-empty string, unique in the widget tree. B<Required>: without it
the constructor dies, because the scroll position is stored by id from
one frame to the next.

=item C<vertical>

A boolean, stored as 1 or 0. Default: 1. Whether the content scrolls
up and down.

=item C<horizontal>

A boolean, stored as 1 or 0. Default: 0. Whether the content scrolls
sideways, with a horizontal wheel or with C<child_offset>.

=item C<child_offset>

C<undef> or a hash reference C<< { x => $columns, y => $rows } >>.
Default: C<undef>, which lets the mouse wheel control the position.
A hash takes over: the content is drawn shifted by that many cells, and
the wheel no longer moves it. Negative values move the content up and
left, so C<< { x => 0, y => -3 } >> shows the content from its fourth
row on. Set it back to C<undef> to give control back to the wheel. The wheel
keeps moving the hidden scroll position while C<child_offset> is set,
so the content may jump when you set it back to C<undef>.

=back

=head1 METHODS

A ScrollBox has all methods of L<Term::Fabulous::Widget> plus these
accessors (from L<Clay::UI::Role::Layout::HasScroll>):

=head2 vertical

	$box->vertical(0);

Accessor. Without an argument it returns the stored value; with an
argument it stores it (unchecked, treated as a boolean) and returns it.
The change shows in the next frame.

=head2 horizontal

	$box->horizontal(1);

Accessor for C<horizontal>, used like L</vertical>.

=head2 child_offset

	$box->child_offset( { x => 0, y => -20 } );    # show from row 21 on
	$box->child_offset(undef);                      # back to the wheel

Accessor. Without an argument it returns the hash reference, or
C<undef> while the wheel controls the position; with an argument it
sets it and returns the new value. An invalid value dies like the
constructor parameter. The change shows in the next frame.

=head1 EVENTS

=over

=item C<OnScroll> (L<Clay::UI::Events::OnScroll>)

Fired on the ScrollBox in every frame in which its scroll position
changed. C<< $event->delta_y >> is how far the content moved, in rows:
negative when the user scrolled down (the content moved up), positive
when scrolled up. C<< $event->delta_x >> is the same for columns.
While C<child_offset> is set, C<OnScroll> still reports the movement of
the hidden scroll position that the wheel moves, even though the
content does not move.

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

Fired for wheel notches and clicks over the box, like on any Box (see
L<Term::Fabulous::Manual/MOUSE>). The scrolling does not depend on what
your listeners return: a listener that stops the event from bubbling
does not stop the scrolling. Only a call to
L<Term::Fabulous::Event::Mouse/use_wheel> keeps a notch from scrolling
the box.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<horizontal> and C<vertical> (C<#true> or C<#false>). The node needs an
id argument:

	ScrollBox "log" {
		layout direction=down
		sizing width=grow height="fixed(10)"
		vertical #true
	}

C<child_offset> cannot be set from KDL.

=head1 CAVEATS

A widget inside a ScrollBox that uses the mouse wheel itself (a
L<Term::Fabulous::Widget::TextArea>, a L<Term::Fabulous::Widget::Slider>,
an open L<Term::Fabulous::Widget::Dropdown> list) takes the notches
over it while it can move, and the ScrollBox stays put; once the widget
is at its end, the notches scroll the ScrollBox again. So a long form
scrolls past a text area as soon as the text area shows its last rows.

=head1 SEE ALSO

L<Term::Fabulous::Manual/SCROLLING>,
L<Term::Fabulous::Cookbook/Scroll a ScrollBox from code (keep a log at the newest line)>,
L<Term::Fabulous::Widget::Box>, L<Clay::UI::Role::Layout::HasScroll>,
the example program F<examples/scroll-box.pl>.

=cut
