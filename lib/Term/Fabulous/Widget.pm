package Term::Fabulous::Widget;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

class Term::Fabulous::Widget
	:does(Clay::UI::Role::Core::Container)

	:does(Clay::UI::Role::Events::Listener)
	:does(Clay::UI::Role::Events::Emitter)

	:does(Clay::UI::Role::Layout::HasLayout)
	:does(Clay::UI::Role::Layout::HasParent)
	:does(Clay::UI::Role::Layout::HasSizingGroup)

	:does(Clay::UI::Role::Style::HasBackground)
	:does(Clay::UI::Role::Style::HasStates)

	:does(Clay::UI::Role::Style::HasBorder)
	:does(Term::Fabulous::Role::HasBorderStyle)
	:abstract
{
	field $classes             :param = [];
	field $glyphs_show_through :param = 0;

	ADJUST {
		$glyphs_show_through = _boolean( glyphs_show_through => $glyphs_show_through );
	}

	sub _boolean ( $name, $value ) {
		die "Term::Fabulous::Widget: $name must be a boolean, got a " . ref($value) . " reference" if ref $value;
		return $value ? 1 : 0;
	}

	method get_classes () {
		return (@$classes, map { 'state_' . lc($_) } $self->states);
	}

	method glyphs_show_through (@new) {
		return $glyphs_show_through unless @new;
		return $glyphs_show_through = _boolean( glyphs_show_through => $new[0] );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget - Abstract base class of the Term::Fabulous
container widgets

=head1 SYNOPSIS

	# Term::Fabulous::Widget is abstract; you use its subclasses:
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

	my $panel = Term::Fabulous::Widget::Box->new(
		id               => 'panel',
		layout           => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_fit() },
			padding          => { left => 1, right => 1 },
			child_gap        => 1,
		},
		background_color => [ 30, 35, 50, 255 ],
		border_width     => 1,
		border_color     => [ 120, 160, 220, 255 ],
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
		classes          => ['sidebar'],
	);

	# Writing a widget class of your own:
	use Object::Pad;
	class My::Panel :isa(Term::Fabulous::Widget) :strict(params) { }

=head1 DESCRIPTION

C<Term::Fabulous::Widget> is the common base of every Term::Fabulous
widget that is a rectangle on the screen and can hold other widgets:
L<Term::Fabulous::Widget::Box> and everything built on it
(L<Term::Fabulous::Widget::Button>, L<Term::Fabulous::Widget::ScrollBox>,
L<Term::Fabulous::Widget::Canvas>, the input widgets, ...).
L<Term::Fabulous::Widget::Text> is not one of them: text is a leaf that
always lives inside such a widget.

The class is abstract: C<< Term::Fabulous::Widget->new >> dies. Create a
L<Term::Fabulous::Widget::Box> when you need a plain container, or
subclass this class (or Box) for a widget of your own.

This page is the reference for everything these widgets have in common:
the constructor parameters for layout, background, border and ids, and
the methods for children, events and states. Most of it comes from
L<Clay::UI>, the widget layer on top of the Clay layout engine, through
the roles this class composes:

=over

=item * L<Clay::UI::Role::Core::Container>: children (C<add_child>, ...)

=item * L<Clay::UI::Role::Events::Listener> and L<Clay::UI::Role::Events::Emitter>: events (C<on>, C<fire_event>)

=item * L<Clay::UI::Role::Layout::HasLayout>: the C<layout> hash

=item * L<Clay::UI::Role::Layout::HasParent>: C<parent>, C<root>, C<ui>

=item * L<Clay::UI::Role::Layout::HasSizingGroup>: C<width_group>, C<height_group>

=item * L<Clay::UI::Role::Style::HasBackground>: C<background_color>

=item * L<Clay::UI::Role::Style::HasBorder>: C<border_width>, C<border_color>

=item * L<Clay::UI::Role::Style::HasStates>: C<add_state>, C<states>, ...

=item * L<Term::Fabulous::Role::HasBorderStyle>: the border glyphs (C<border_style>, ...)

=back

The sections below summarize what you need for everyday use; the role
pages have the full details.

=head1 CONSTRUCTOR

=head2 new

	my $box = Term::Fabulous::Widget::Box->new(%parameters);

C<new> is called on a concrete subclass. All parameters are optional.
The concrete classes reject unknown parameters: a typo dies with
C<Unrecognised parameters for ... constructor>. Widgets are created
empty; add children afterwards with L</add_child>.

=over

=item C<id>

A non-empty string. Default: none. Names the widget: L</remove_child>
removes children by id, listeners can tell widgets apart with
C<< $event->target->id >>, and Clay keeps state (such as a scroll
position) for it between frames. There is no lookup by id; see
L<Term::Fabulous::Layout/Finding widgets by id> for walking the tree.
Ids must be unique in a widget tree: two widgets with the same id make
drawing die with a C<Clay error>. Ids starting with C<anon:> are
reserved and die. Widgets without an id get one generated from their
position in the tree. L<Term::Fabulous::Widget::ScrollBox> requires an
id.

=item C<layout>

A hash reference of layout options. Default: C<{}>, which sizes the
widget to fit its content and stacks children from left to right. The
keys are:

=over

=item C<sizing>

C<< { width => $sizing, height => $sizing } >>, each built with a
function from L<Clay::XS>: C<sizing_fit($min, $max)> (as big as the
content, the default), C<sizing_grow($min, $max)> (take the space left
over in the parent), C<sizing_fixed($cells)> and
C<sizing_percent($fraction)> (a share of the parent, a number from 0 to
1; C<0.5> is half). A fraction above 1 is accepted by C<new> but makes
drawing die with a C<Clay error>. C<$min> and C<$max> are optional
limits in cells. Either axis may be
left out.

=item C<padding>

C<< { left => $n, right => $n, top => $n, bottom => $n } >>, any
subset, in cells; C<padding_all($n)> from L<Clay::XS> builds one with
all four sides. The padding lies inside the border (see
L<Term::Fabulous::Role::HasBorderStyle/Border space>).

=item C<child_gap>

The number of empty cells between two neighboring children.

=item C<layout_direction>

C<CLAY_LEFT_TO_RIGHT> (the default) or C<CLAY_TOP_TO_BOTTOM>, constants
exported by L<Clay::XS>.

=item C<child_alignment>

C<< { x => $x, y => $y } >> with C<CLAY_ALIGN_X_LEFT>,
C<CLAY_ALIGN_X_CENTER> or C<CLAY_ALIGN_X_RIGHT> and C<CLAY_ALIGN_Y_TOP>,
C<CLAY_ALIGN_Y_CENTER> or C<CLAY_ALIGN_Y_BOTTOM>. Default: left and top.

=back

Any other key, or a value of the wrong shape, dies. See
L<Term::Fabulous::Manual/LAYOUT> for how these work together.

=item C<background_color>

The color of the widget's area. An array reference C<[r, g, b, a]> of
exactly four numbers from 0 to 255, or a hash reference
C<{ r => ..., g => ..., b => ..., a => ... }>. Default: none, so the
widget's area shows what is behind it. Strings such as C<'#ff0000'> are
not accepted here (they are in KDL layouts); convert them with
C<< [ Term::Fabulous::Color->new( color => '#ff0000' )->to_rgba ] >>.
An alpha of 0 means no color, 255 is opaque, and 1 to 254 is
translucent: the color is blended with whatever is below the widget
(see C<glyphs_show_through>). See L<Term::Fabulous::Manual/COLORS>.

A widget with neither a background color nor a border paints nothing,
so it is also invisible to the mouse: clicks on it go to the widget
behind it. A widget with only a border receives clicks on its border
cells.

=item C<glyphs_show_through>

Only matters with a translucent C<background_color> (alpha 1 to 254).
False (the default): the widget's area is covered with spaces in the
blended color, so text and borders below it disappear. True: they stay
visible through the background, with their colors tinted by it, until
the widget paints its own content over them. Where the color below is
the terminal default, which cannot be blended, the background is drawn
opaque and a glyph's default foreground stays as it is. Any true or
false value; references die. See
L<Term::Fabulous::Manual/Alpha and the terminal default color>.

=item C<border_width>

The border's thickness: a number for all four sides, or a hash
reference C<< { left => $n, right => $n, top => $n, bottom => $n } >>
(missing sides are 0). Default: no border. In a terminal a drawn border
is always one cell thick; any positive width draws the side, and the
width is the space the side takes from the widget. Use C<1>.

=item C<border_color>

The color of the border glyphs, in the same formats as
C<background_color>. Default: the terminal's default foreground color.

=item C<border_style>

A L<Term::Fabulous::Enum::BorderStyle> item, such as
C<< Term::Fabulous::Enum::BorderStyle->Round >>, used for all four
sides. Default: none; a side that has a width but no style is drawn
with the C<Blank> style (spaces). See
L<Term::Fabulous::Role::HasBorderStyle>.

=item C<border_style_top>

=item C<border_style_right>

=item C<border_style_bottom>

=item C<border_style_left>

The style of one side, a L<Term::Fabulous::Enum::BorderStyle> item.
Ignored when C<border_style> is given as well; see
L<Term::Fabulous::Role::HasBorderStyle/CAVEATS>.

=item C<width_group>

=item C<height_group>

An integer from 0 to 1048575. Default: 0 (no group). Widgets anywhere
in the tree with the same non-zero group number get the same width (or
height): the largest content size among them. Useful to line up form
labels. Only C<fit> and C<grow> sizing take part. See
L<Clay::UI::Role::Layout::HasSizingGroup>.

=item C<classes>

An array reference of strings. Default: C<[]>. Free-form names for
your own use, returned by L</get_classes>. Term::Fabulous itself does
not read them.

=back

=head1 METHODS

The methods fall into four groups: children (C<add_child> to C<ui>),
events (C<on>, C<fire_event>, C<handlers_for>), layout and style
accessors (C<layout> to C<height_group>) and states (C<add_state> to
C<get_classes>).

States: every widget has a set of state names. C<hovered>, C<pressed>
and C<focused> are maintained automatically for widgets that can be
hovered, pressed or focused (for example
L<Term::Fabulous::Widget::Button>) and cannot be set by hand; you may
add names of your own, for example C<selected>. See
L<Clay::UI::Role::Style::HasStates>.

=head2 add_child

	$box->add_child($widget);
	$box->add_child( $header, $body, $footer );

Appends one or more widgets (or L<Term::Fabulous::Widget::Text>s) as
children, in order. Returns the widget, so calls chain:
C<< $root->add_child($a)->add_child($b) >>.

A widget can be attached only once in its life. Adding a widget that
already has (or had) a parent dies, and so does adding the root of a
L<Term::Fabulous> or a widget to itself or one of its descendants.
Create a new widget instead of moving one. See
L<Clay::UI::Role::Core::Container/add_child>.

=head2 remove_child

	$box->remove_child('status');

Removes every direct child whose C<id> equals the argument. Unknown ids
are ignored. Text widgets are never removed this way, even when they
have an C<id> (use L</remove_children_with>). Removed widgets cannot be
added again. Returns the widget.

Removing a subtree that holds the focused widget or a hovered widget
fires C<OnBlur> or C<OnHoverStopped> on it during the call; C<OnBlur>
still bubbles through the old parents. When an C<OnBlur> listener dies,
the removal is completed first and the error is rethrown afterwards.

=head2 remove_children_with

	$box->remove_children_with( sub { $_->isa('Term::Fabulous::Widget::Text') } );

Removes every direct child for which the code reference returns true.
The child is passed as the argument and in C<$_>. Returns the widget.
Removal works as described in L</remove_child>.

=head2 clear_children

	$box->clear_children;

Removes all children. Returns the widget. Removal works as described
in L</remove_child>.

=head2 id

	my $id = $widget->id;

The C<id> given to the constructor, or C<undef> when none was given
(the generated id is not returned). There is no writer.

=head2 children

	my @kids = @{ $box->children };

A new array reference with the direct children, in order. Changing the
array does not change the widget.

=head2 get_children_with

	my @buttons = $box->get_children_with( sub { $_->isa('Term::Fabulous::Widget::Button') } );

The direct children for which the code reference returns true (as a
list). Does not look at grandchildren.

=head2 parent

	my $owner = $widget->parent;

The widget that contains this one, or C<undef> for the root and for
widgets that were never added or were removed.

=head2 root

	my $top = $widget->root;

The topmost widget above this one (the widget itself when it has no
parent).

=head2 ui

	my $ui = $widget->ui;

The L<Term::Fabulous> (or L<Term::Fabulous::Static>) object whose tree
contains the widget, or C<undef> when it is not part of one. Useful in
listeners, for example C<< $widget->ui->interaction->set_focused_widget(...) >>.

=head2 on

	$widget->on( KeyPress => sub ($event) { ...; return } );

Registers a listener: a code reference called with the event object
whenever an event of that name is fired on this widget or bubbles up
to it from a descendant. Several listeners per name are allowed; they
run in the order they were added. Returns the widget.

What the listener returns decides whether the event continues to the
parent: only C<< Clay::UI::Enum::Result->CONTINUE >> lets it go on, any
other value (including a plain C<return;>) stops it after this widget.
See L<Term::Fabulous::Manual/EVENTS> for the event names and the rules.

=head2 fire_event

	$widget->fire_event( Term::Fabulous::Event::Change->new( value => 42 ) );

Delivers an event object to this widget's listeners and then up the
parent chain as described in L</on>. An event object can be fired only
once. Term::Fabulous calls this for you; call it yourself for events of
your own or in tests. See L<Clay::UI::Role::Events::Emitter>.

=head2 handlers_for

	my $listeners = $widget->handlers_for('KeyPress');
	printf "%d KeyPress listeners\n", scalar @$listeners;

A new array reference with the listeners registered on this widget for
an event name, in the order they were added (an empty array reference
when there are none). Changing the array does not change the widget.
Mostly useful in tests.

=head2 layout

	my $layout = $box->layout;
	$box->layout( { %{ $box->layout }, child_gap => 2 } );

Accessor for the C<layout> hash (see L</new>). Without an argument it
returns the stored hash reference; with an argument it replaces the
whole hash and returns the new one. An invalid hash dies like the
constructor parameter. The change shows in the next frame. Copy the old
hash as above to change a single key.

=head2 background_color

	$box->background_color( [ 60, 90, 140, 255 ] );

Accessor. Without an argument it returns the current value (C<undef>
when none is set); with an argument it sets the value and returns the
new value. C<undef> removes the background color. An invalid value dies
like the constructor parameter of the same name. The change shows in the
next frame.

=head2 glyphs_show_through

	$box->glyphs_show_through(1);

Accessor for the constructor parameter of the same name (0 or 1).
Without an argument it returns the current value; with an argument it
sets the value and returns the new one. The change shows in the next
frame.

=head2 border_color

	$box->border_color( [ 97, 175, 239, 255 ] );

Accessor. Without an argument it returns the current value (C<undef>
when none is set); with an argument it sets the value and returns the
new value. C<undef> returns to the terminal's default color. An invalid
value dies like the constructor parameter of the same name. The change
shows in the next frame.

=head2 border_width

	$box->border_width(1);

Accessor. Without an argument it returns the current value (C<undef>
when none is set); with an argument it sets the value and returns the
new value. C<undef> removes the border. An invalid value dies like the
constructor parameter of the same name. The change shows in the next
frame. Changing it changes the layout, because borders take space.

=head2 border_style_top

	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the top side. Returns and takes C<undef>
or a L<Term::Fabulous::Enum::BorderStyle> item; the writer returns the
new value and anything else dies. The change shows in the next frame.
There is no C<border_style> accessor; set the sides one by one. See
L<Term::Fabulous::Role::HasBorderStyle>.

=head2 border_style_right

	$box->border_style_right( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the right side. Returns and takes C<undef>
or a L<Term::Fabulous::Enum::BorderStyle> item; the writer returns the
new value and anything else dies. The change shows in the next frame.
There is no C<border_style> accessor; set the sides one by one. See
L<Term::Fabulous::Role::HasBorderStyle>.

=head2 border_style_bottom

	$box->border_style_bottom( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the bottom side. Returns and takes C<undef>
or a L<Term::Fabulous::Enum::BorderStyle> item; the writer returns the
new value and anything else dies. The change shows in the next frame.
There is no C<border_style> accessor; set the sides one by one. See
L<Term::Fabulous::Role::HasBorderStyle>.

=head2 border_style_left

	$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the left side. Returns and takes C<undef>
or a L<Term::Fabulous::Enum::BorderStyle> item; the writer returns the
new value and anything else dies. The change shows in the next frame.
There is no C<border_style> accessor; set the sides one by one. See
L<Term::Fabulous::Role::HasBorderStyle>.

=head2 width_group

	$label->width_group(1);

Accessor. Without an argument it returns the group number (0 when the
widget is in no group); with an argument it sets it and returns the new
value. An invalid value dies like the constructor parameter. The change
shows in the next frame.

=head2 height_group

	$row->height_group(2);

Accessor for the height group, used like L</width_group>.

=head2 add_state

	$row->add_state('selected');

Adds a state name of your own. Returns the widget. Dies for
C<hovered>, C<pressed> and C<focused>.

=head2 remove_state

	$row->remove_state('selected');

Removes a state name of your own. Returns the widget. Dies for
C<hovered>, C<pressed> and C<focused>.

=head2 toggle_state

	$row->toggle_state('selected');

Adds the name when it is missing, removes it otherwise. Returns the
widget. Dies for C<hovered>, C<pressed> and C<focused>.

=head2 clear_states

	$row->clear_states;

Removes all state names of your own. The automatic states
(C<hovered>, C<pressed>, C<focused>) are not affected. Returns the
widget.

=head2 has_state

	if ( $row->has_state('selected') ) { ... }

True when the state is active, including the automatic ones.

=head2 states

	my @active = $row->states;

The active state names, in no particular order.

=head2 get_classes

	my @classes = $widget->get_classes;    # ('sidebar', 'state_focused')

The names from the C<classes> parameter, followed by C<state_NAME> for
every active state (C<state_hovered>, C<state_selected>, ...).

=head1 SEE ALSO

L<Term::Fabulous::Widget::Box>, L<Term::Fabulous::Manual>,
L<Term::Fabulous::Role::HasBorderStyle>, L<Clay::UI>.

=cut
