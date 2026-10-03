package Term::Fabulous::Widget::Input;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Disableable;
use Clay::UI::Role::Interaction::Focusable;
use Clay::UI::Role::Interaction::Hoverable;
use Clay::UI::Role::Interaction::Pressable;
use Term::Fabulous::Widget::Canvas;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Input
	:isa(Term::Fabulous::Widget::Canvas)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:does(Clay::UI::Role::Interaction::Pressable)
	:does(Clay::UI::Role::Interaction::Disableable)
	:abstract
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed);
	use Scalar::Util qw(refaddr weaken);
	use Term::Fabulous::Termbox qw(TB_REVERSE);
	use Term::Fabulous::Check qw(cell_color);
	use Term::Fabulous::Color;
	use Term::Fabulous::Event::Change;
	use Term::Fabulous::Render::Attr qw(cell_color_attr);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	my @COLOR_NAMES = qw(text_color disabled_color accent_color focus_background_color);

	# Counts mark_changed calls, the changes of the widget's own state; with
	# the rest of the paint key, what the cells were last painted for.
	field $_change_count = 0;
	field $_painted_key;

	field $text_color             :param = [ 220, 223, 228, 255 ];
	field $disabled_color         :param = [ 108, 112, 120, 255 ];
	field $accent_color           :param = [ 97,  175, 239, 255 ];
	field $focus_background_color :param = [ 52,  58,  72,  255 ];

	# The content size a subclass asks for when the layout gives none.
	method natural_size;

	# Draws the widget into the cleared buffer.
	method paint;

	ADJUST {
		$text_color             = cell_color( $self, text_color             => $text_color );
		$disabled_color         = cell_color( $self, disabled_color         => $disabled_color );
		$accent_color           = cell_color( $self, accent_color           => $accent_color );
		$focus_background_color = cell_color( $self, focus_background_color => $focus_background_color );

		weaken( my $weak_self = $self );
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		my $own      = sub ($event) { defined $weak_self && refaddr( $event->target ) == refaddr($weak_self) };

		$self->on( OnFocus      => sub ($event) { $weak_self->focus_changed(1) if $own->($event); return $continue } );
		$self->on( OnBlur       => sub ($event) { $weak_self->focus_changed(0) if $own->($event); return $continue } );
		$self->on( KeyPress     => sub ($event) { return $weak_self->_dispatch( handle_key => $event ) } );
		$self->on( Mouse        => sub ($event) { return $weak_self->_dispatch( handle_mouse => $event ) } );
		$self->on(
			OnRelease => sub ($event) {
				$weak_self->activate if $own->($event) && $weak_self->is_enabled;
				return $continue;
			}
		);
	}

	# ---------------------------------------------------------------------
	# Colors: anything Term::Fabulous::Widget::Canvas accepts for a cell,
	# kept as [r, g, b, a]
	# ---------------------------------------------------------------------

	method _set_color ( $name, $field_ref, $value ) {
		$$field_ref = cell_color( $self, $name => $value );
		$self->mark_changed;
		return $$field_ref;
	}

	method text_color (@new) {
		return @new ? $self->_set_color( text_color => \$text_color, @new ) : $text_color;
	}

	method disabled_color (@new) {
		return @new ? $self->_set_color( disabled_color => \$disabled_color, @new ) : $disabled_color;
	}

	method accent_color (@new) {
		return @new ? $self->_set_color( accent_color => \$accent_color, @new ) : $accent_color;
	}

	method focus_background_color (@new) {
		return @new ? $self->_set_color( focus_background_color => \$focus_background_color, @new ) : $focus_background_color;
	}

	# The termbox2 attribute of a color, undef for none.
	method color_attr ($color) {
		return cell_color_attr( color => $color );
	}

	# The attribute for normal text: the text color, or the disabled color.
	method foreground_attr () {
		return $self->color_attr( $self->is_enabled ? $text_color : $disabled_color );
	}

	method accent_attr () {
		return $self->color_attr( $self->is_enabled ? $accent_color : $disabled_color );
	}

	method reverse_attr ($attr) {
		return ( $attr // 0 ) | TB_REVERSE;
	}

	# A color as the [r, g, b, a] that Clay takes for backgrounds and
	# borders. A packed 0xRRGGBB integer is opaque.
	method rgba_of ($color) {
		return [ ( $color >> 16 ) & 0xFF, ( $color >> 8 ) & 0xFF, $color & 0xFF, 255 ] if !ref $color && $color =~ /\A[0-9]+\z/;
		return [ Term::Fabulous::Color->new( color => $color )->to_rgba ];
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method mark_changed :override () {
		$_change_count++;
		return $self->SUPER::mark_changed;
	}

	# Paints the cells again when anything paint reads changed since they
	# were last painted.
	method refresh :override () {
		return unless $self->columns > 0 && $self->rows > 0;
		my $key = join "\x{1F}", map { $_ // "\x{0}" } $self->paint_key;
		return if defined $_painted_key && $key eq $_painted_key;
		$_painted_key = $key;
		$self->clear;
		$self->paint;
		return;
	}

	# What paint reads: the size, the widget's own state (every setter
	# calls mark_changed) and what other objects decide, the focus and
	# whether the widget is enabled. A subclass that paints from the state
	# of other widgets adds it.
	method paint_key () {
		return ( $self->columns, $self->rows, $_change_count, $self->is_focused, $self->is_enabled );
	}

	method focus_changed ($is_focused) {
		return;
	}

	# Paints a character string from ($x, $y) with termbox2 attributes,
	# stopping before a cluster that would cross column $limit; returns the
	# column after the last painted cluster.
	method paint_text ( $x, $y, $text, $fg, $bg, $limit = $self->columns ) {
		foreach my $cluster ( grapheme_clusters($text) ) {
			my $columns = cluster_columns($cluster);
			last if $x + $columns > $limit;
			$self->put_attrs( $x, $y, $cluster, $fg, $bg );
			$x += $columns;
		}
		return $x;
	}

	method fill_attrs ( $x, $y, $width, $glyph, $fg, $bg ) {
		$self->put_attrs( $_, $y, $glyph, $fg, $bg ) foreach $x .. $x + $width - 1;
		return;
	}

	# The background of the content while the input shows the focus,
	# otherwise undef: the widget's own background shows.
	method focus_background_attr () {
		return $self->is_focused ? $self->color_attr($focus_background_color) : undef;
	}

	# Paints the focus background under the whole buffer, when there is one,
	# and returns it.
	method paint_focus_background () {
		my $bg = $self->focus_background_attr // return undef;
		$self->fill_attrs( 0, $_, $self->columns, ' ', undef, $bg ) foreach 0 .. $self->rows - 1;
		return $bg;
	}

	# ---------------------------------------------------------------------
	# Natural size: fills the sizing axes the layout leaves open. Clay::UI
	# runs the contributors in alphabetical order, so this one runs after
	# contribute_layout and contribute_layout_inset and sees the final
	# padding, border included.
	# ---------------------------------------------------------------------

	method contribute_layout_size ($config) {
		my $layout = $config->{layout} // {};
		my $sizing = $layout->{sizing} // {};
		my @open   = grep { !defined $sizing->{$_} } qw(width height);
		return unless @open;

		my $padding = $layout->{padding} // {};
		my ( $columns, $rows ) = $self->natural_size;
		my %total = (
			width  => $columns + ( $padding->{left} // 0 ) + ( $padding->{right}  // 0 ),
			height => $rows +    ( $padding->{top}  // 0 ) + ( $padding->{bottom} // 0 ),
		);
		$config->{layout} = { %$layout, sizing => { %$sizing, map { $_ => sizing_fixed( $total{$_} ) } @open } };
		return;
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	# Disabled widgets ignore input; a handler returns true when it used the
	# event, which then stops bubbling.
	method _dispatch ( $handler, $event ) {
		my $result = Clay::UI::Enum::Result->CONTINUE;
		return $result unless $self->is_enabled && $self->$handler($event);
		return Clay::UI::Enum::Result->HANDLED;
	}

	method handle_key ($event) {
		return 0;
	}

	method handle_mouse ($event) {
		return 0;
	}

	# A click: the left button pressed and released over the widget.
	method activate () {
		return;
	}

	method fire_change ($value) {
		$self->fire_event( Term::Fabulous::Event::Change->new( value => $value ) );
		return;
	}

	method layout_properties :common () {
		return ( $class->SUPER::layout_properties, can_focus => 'boolean', disabled => 'boolean', map { $_ => 'color' } @COLOR_NAMES );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Input - Common base class of the input widgets

=head1 SYNOPSIS

	use Term::Fabulous::Widget::TextField;

	# Every input widget accepts these parameters:
	my $field = Term::Fabulous::Widget::TextField->new(
		id                     => 'name',
		disabled               => 0,
		text_color             => '#dcdfe4',
		accent_color           => [ 97, 175, 239, 255 ],
		disabled_color         => 0x6c7078,
		focus_background_color => 'rgb(52, 58, 72)',
	);

	$field->disabled(1);                   # gray, ignores input, loses the focus
	$field->accent_color('#ff8800');      # shows in the next frame

	# A widget of your own (see SUBCLASS INTERFACE):
	use Object::Pad;
	use Term::Fabulous::Widget::Input;

	class My::Toggle :isa(Term::Fabulous::Widget::Input) :strict(params) {
		field $on = 0;

		method value () { return $on }

		method natural_size () { return ( 5, 1 ) }    # columns, rows

		method paint () {
			my $bg = $self->paint_focus_background;
			$self->paint_text( 0, 0, $on ? '[ON]' : '[OFF]', $self->accent_attr, $bg );
			return;
		}

		method activate () {                       # a click
			$on = $on ? 0 : 1;
			$self->mark_changed;                    # the next frame paints it
			$self->fire_change($on);
			return;
		}

		method handle_key ($event) {
			return 0 unless ( $event->main_key_name // '' ) eq 'Space';
			$self->activate;
			return 1;                               # used: stops bubbling
		}
	}

=head1 DESCRIPTION

C<Term::Fabulous::Widget::Input> is the abstract base class of all
input widgets:

=over

=item *

L<Term::Fabulous::Widget::TextField> - one line of text

=item *

L<Term::Fabulous::Widget::TextArea> - several lines of text

=item *

L<Term::Fabulous::Widget::Checkbox> - a box to check

=item *

L<Term::Fabulous::Widget::RadioButton> - one choice of a
L<Term::Fabulous::Widget::RadioGroup>

=item *

L<Term::Fabulous::Widget::Dropdown> - one choice from a list that opens

=item *

L<Term::Fabulous::Widget::Slider> - a number from a range

=back

You do not create an C<Input> directly (the class is abstract and
C<new> dies); this page describes what all input widgets have in
common, and how to write an input widget of your own.

What every input widget does:

=over

=item *

It takes the keyboard focus. Under L<Term::Fabulous>, C<Tab> and
C<BackTab> (Shift+Tab) move the focus from input to input, and a click on an
input focuses it. The focused input shows its content on
C<focus_background_color>. A radio button is the exception: its radio
group takes the focus for all its buttons.

=item *

It receives the key presses while it has the focus. Keys it uses (for
example letters in a text field) stop there; keys it does not use (for
example C<Escape>, C<Tab> or C<F1>) bubble on to its ancestors, so
application shortcuts on an outer box keep working while the user types.
Each widget's KEYS section lists the keys it uses. See
L<Term::Fabulous::Manual::Events/KEYBOARD>.

=item *

It works with the mouse: clicks, drags and the mouse wheel, as described
in each widget's MOUSE section. The terminal reports the mouse only when
a button is pressed or released, while it is dragged, and when the wheel
turns; plain pointer movement is not reported. The hover state of an
input (C<is_hovered>, the C<OnHoverStart> and C<OnHoverStopped> events)
therefore changes only at those moments, not while the pointer merely
moves.

=item *

It fires a L<Term::Fabulous::Event::Change> when the user changes its
value (see L</EVENTS>).

=item *

It sizes itself to its content unless the C<layout> says otherwise (see
L</SIZE>).

=item *

It can be disabled (see L</disabled>).

=item *

It has the derived states C<focused>, C<hovered>, C<pressed> and
C<disabled>, which C<< $input->has_state('focused') >> and
C<< $input->states >> report (see L<Term::Fabulous::Widget/has_state>).

=item *

It can be built from a KDL layout file (see L</KDL PROPERTIES>).

=back

Technically, an input is a L<Term::Fabulous::Widget::Canvas> that paints
itself when a frame is drawn (see L</Painting>): setters only record the
new state, and the frame paints whatever changed since the last one, so
only cells that really changed are sent to the terminal. Anything you
draw into an input with the canvas methods (C<put>, C<put_text>, ...)
is lost the next time it paints.

=head2 Painting

Every setter of an input records the new value and calls
C<mark_changed> (L<Clay::UI::Role::Core::Element/mark_changed>), so a
frame becomes due; nothing is painted at once. When the frame is drawn,
the renderer calls the input's C<refresh>
(L<Term::Fabulous::Widget::Canvas/refresh>), which compares the input's
I<paint key> (see L</paint_key>) with the one it last painted for: the
size of its buffer, how often the input was marked changed, whether it
has the focus and whether it is enabled, and what a subclass adds, such
as the state of its radio group. Only when the key differs does it
clear the buffer and call L</paint>. So the cells always show the state
of the frame they are drawn in, also when the state was changed by
another widget, and a frame that changes nothing about an input paints
nothing of it. The cells read with C<cell> show the state of the last
frame.

=head1 CONSTRUCTOR

=head2 new

	my $input = Term::Fabulous::Widget::TextField->new(%parameters);    # or any other input

Every input widget's C<new> accepts the parameters below, in addition to
its own. Unknown parameters die. C<Term::Fabulous::Widget::Input>
itself is abstract: calling C<< Term::Fabulous::Widget::Input->new >>
dies.

=over

=item C<id>

A string. Optional. Identifies the widget for Clay, which needs a unique
id per widget; it is also handy for telling inputs apart in a form-wide
C<Change> listener (C<< $event->target->id >>). Ids must be unique in a
widget tree.

=item C<layout>

A hash reference of layout options, as for every widget: C<sizing>,
C<padding>, C<child_gap>, C<child_alignment>, C<layout_direction>. See
L<Term::Fabulous::Manual::Layout/LAYOUT>. A C<sizing> you give here overrides
the natural size of the input on that axis (see L</SIZE>).

=item C<background_color>

The widget's background, in any format L<Term::Fabulous::Color> accepts
(see L<Term::Fabulous::Manual::Looks/Color formats>); it is stored as an
C<[r, g, b, a]> array reference. Text inputs and the dropdown
default to a dark gray (C<[36, 40, 48, 255]>); the other inputs have no
background of their own and show the background of their parent.

=item C<border_width>

=item C<border_color>

=item C<border_style>

A border around the input, exactly as for
L<Term::Fabulous::Widget::Box>; see L<Term::Fabulous::Manual::Looks/BORDERS>.
The border takes cells inside the widget's box; the natural size is
grown accordingly.

=item C<disabled>

A boolean, stored as 1 or 0. Default: 0. A disabled input is painted in
C<disabled_color>, ignores keys, clicks and the mouse wheel, and cannot
take the focus; since the user cannot change it, it fires no C<Change>
or C<Submit> of its own accord. See L</disabled>.

=item C<can_focus>

A boolean. Default: 1. Whether the input may take the keyboard focus
(see L<Clay::UI::Role::Interaction::Focusable>). It counts while the
input is enabled: a disabled input cannot take the focus, whatever this
says (see L</can_focus>). A L<Term::Fabulous::Widget::RadioButton> never
takes the focus (it does not accept it, see L</accepts_focus>), so for
it the parameter has no effect.

=item C<text_color>

The color of the input's text. Default: C<[220, 223, 228, 255]>, a light
gray.

=item C<disabled_color>

The color of all text while the input is disabled, and of inactive parts
such as scrollbar tracks. Default: C<[108, 112, 120, 255]>, a medium
gray.

=item C<accent_color>

The color of highlights: check marks, the selected radio button's mark,
the filled part of a slider, the dropdown's arrow and the border of its
open list. Default: C<[97, 175, 239, 255]>, a light blue.

=item C<focus_background_color>

The background of the input's content while it has the focus. Default:
C<[52, 58, 72, 255]>, a dark blue-gray.

=back

The four colors accept every color format of the canvas: a packed
C<0xRRGGBB> integer, an C<[r, g, b]> or C<[r, g, b, a]> array reference,
a C<{ r, g, b }> hash reference, a string such as C<'#ff8800'>,
C<'rgb(255, 136, 0)'> or C<'hsl(32, 100%, 50%)'>, or a
L<Term::Fabulous::Color> object (see
L<Term::Fabulous::Widget::Canvas/Colors>). C<undef> and invalid colors
die. A color with alpha 0 means "no color": the terminal's default color
is used.

An input is a L<Term::Fabulous::Widget::Box>, so it also takes the
other parameters of a Box, described in L<Term::Fabulous::Widget/new>:
C<floating>, C<width_group> and C<height_group> (to line up the inputs
of a form), C<classes>, C<glyphs_show_through>, the per-side border
styles (C<border_style_top> and so on), C<border_corners> and
C<outer_border_sides>.

=head1 METHODS

=head2 disabled

	my $is_disabled = $input->disabled;
	$input->disabled(1);
	$input->disabled(0);

Accessor, from L<Clay::UI::Role::Interaction::Disableable>. Returns 1
or 0; any plain true or false value may be written, also through
C<new>; a reference dies (C<Clay::UI: 'disabled' must be a plain boolean
value>).

Writing a true value disables the input: it is painted in
C<disabled_color>, ignores keys, clicks and the mouse wheel (so the user
causes no C<Change> or C<Submit>), cannot take the focus (C<can_focus>
reads 0) and, if it has the focus, gives the focus up at once (no widget is focused afterwards,
unless the input is inside an open L<Term::Fabulous::Widget::Dialog>,
whose backdrop takes it). Clay::UI never presses a disabled widget: a
click on it fires no C<OnPress> or C<OnRelease>. C<KeyPress> and
C<Mouse> events fired on a disabled input still bubble on to its
ancestors, and it is still hovered (C<OnHoverStart>,
C<OnHoverStopped>), so listeners you add yourself for these still run.
It has the derived state C<disabled>
(L<Clay::UI::Role::Style::HasStates/DERIVED STATES>).

Writing a false value enables the input again: it can take the focus
when C<can_focus> was last set to a true value, through C<new>, a
layout file or the accessor, also while the input was disabled. A
L<Term::Fabulous::Widget::RadioButton>, which never takes the focus,
keeps 0. Writing the value the input already has changes nothing.
Returns the new value (1 or 0).

A radio button also counts as disabled while its radio group is
disabled: its C<is_enabled> is then false, while its own C<disabled>
stays 0.

=head2 is_enabled

	if ( $input->is_enabled ) { ... }

True when the input accepts input, the opposite of C<disabled>.

=head2 text_color

	my $color = $input->text_color;
	$input->text_color('#ffffff');

Accessor for the C<text_color> parameter. The reader returns the color
as C<[r, g, b, a]>, whatever form it was given in (see
L<Term::Fabulous::Check/cell_color>). Writing marks the input changed and
returns the new color. An invalid color, or C<undef>, dies and leaves
the old color.

=head2 disabled_color

	$input->disabled_color([ 90, 90, 90 ]);

Accessor for the C<disabled_color> parameter; works like
L</text_color>.

=head2 accent_color

	$input->accent_color(0xFF8800);

Accessor for the C<accent_color> parameter; works like L</text_color>.

=head2 focus_background_color

	$input->focus_background_color('rgb(40, 44, 60)');

Accessor for the C<focus_background_color> parameter; works like
L</text_color>.

=head2 mark_changed

	$input->mark_changed;

Marks the input changed: a frame becomes due (see
L<Clay::UI::Role::Core::Element/mark_changed>), and that frame paints
the input again from its current state and sizes it again, also when
the change was made from a timer. The setters call it, so you only need
it after changing state behind the widget's back, for example through
L<Term::Fabulous::Widget::TextInput/editor>. Returns the input.

=head2 can_focus

	$input->can_focus(0);
	if ( $input->can_focus ) { ... }

Whether the input can take the focus now: 1 when it may (the last
value written, through C<new>, a layout file or this accessor, was
true), it is enabled and it accepts the focus at all (a radio button
does not); 0 otherwise. Writing records whether the input may take the
focus and returns what reading returns now: C<can_focus(1)> on a
disabled input returns 0, and the input takes the focus once it is
enabled. The order of C<can_focus> and C<disabled> does not matter.
Writing a false value to the focused input takes the focus away at
once. From L<Clay::UI::Role::Interaction::Focusable>.

=head2 is_focused

	if ( $input->is_focused ) { ... }

True while the input has the keyboard focus. Inherited from
L<Clay::UI::Role::Interaction::Focusable>. Give an input the focus with
C<< $ui->interaction->set_focused_widget($input) >>.

=head1 SIZE

Every input has a natural content size: for example one row and as many
columns as its label needs (a checkbox), or C<preferred_columns> by one
row (a text field). When the C<layout> gives no C<sizing> for an axis,
the input is given a fixed size on that axis: its natural size plus its
padding and border width. A C<sizing> in the C<layout> always wins:

	# 20 columns wide (the default preferred_columns), one row high:
	Term::Fabulous::Widget::TextField->new;

	# As wide as the parent allows, still one row high:
	Term::Fabulous::Widget::TextField->new( layout => { sizing => { width => sizing_grow() } } );

The natural size is a C<fixed> sizing, and a C<width_group> or
C<height_group> (L<Term::Fabulous::Widget/new>) lines up C<fit> and
C<grow> sizings only. An input has no content Clay could fit, so a
plain C<fit> sizing gives it no columns at all; to line up inputs, give
each a C<fit> sizing with its natural size as the minimum:

	# Both 30 columns wide, the width of the wider one:
	Term::Fabulous::Widget::TextField->new( width_group => 1, layout => { sizing => { width => sizing_fit(20) } } );
	Term::Fabulous::Widget::TextField->new( width_group => 1, layout => { sizing => { width => sizing_fit(30) } } );

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change>, fired on the input when the user
changes its value. Setting the value from the program never fires it.
It bubbles to the input's ancestors unless a listener on the way
returns something other than C<< Clay::UI::Enum::Result->CONTINUE >>.

=item C<OnFocus>, C<OnBlur>

L<Clay::UI::Events::OnFocus> and L<Clay::UI::Events::OnBlur>, fired by
Clay::UI when the input gains or loses the focus.

=item C<OnHoverStart>, C<OnHoverStopped>, C<OnPress>, C<OnRelease>

The pointer events of L<Clay::UI>; see L<Term::Fabulous::Manual::Events/MOUSE>.
A completed click (C<OnRelease> after a press on the same input) is what
toggles a checkbox or selects a radio button.

=item C<CanvasResize>

L<Term::Fabulous::Event::CanvasResize>, fired when the layout gives the
input a new size. The input paints itself for the new size in the same
frame.

=back

The input registers its own listeners for C<KeyPress>, C<Mouse>,
C<OnFocus>, C<OnBlur> and C<OnRelease> when it is constructed. Listeners you add with C<on> run after them, on the same
widget, and see every event, including keys the input used. Keep in mind
that your listener's return value also decides whether the event
bubbles further.

=head1 KDL PROPERTIES

In a layout file (see L<Term::Fabulous::Layout>), every input accepts
the properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>
(C<layout>, C<sizing>, C<padding>, C<border>, C<background_color>,
C<border_color>, C<border_width>, C<width_group>, C<height_group>) and
the following ones. The string after the widget name is its C<id>
(C<TextField "name"> is the C<id> C<name>).

=over

=item C<disabled>

Takes C<#true> or C<#false>, like the C<disabled> parameter.

=item C<can_focus>

Takes C<#true> or C<#false>, like the C<can_focus> parameter; with
C<disabled #true> in the same block the order does not matter.

=item C<text_color>, C<disabled_color>, C<accent_color>, C<focus_background_color>

Any L<Term::Fabulous::Color> string, such as C<"#ff8800"> or
C<"rgb(255, 136, 0)">.

=back

A complete layout with one disabled text field:

	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::TextField as TextField

	Box "form" {
		TextField "name" {
			disabled #true
			accent_color "#ff8800"
			sizing width=grow
		}
	}

Properties are applied after the widget was constructed, with the same
checks as the accessors of the same name. Values that depend on each
other are applied together, so their order in the layout does not
matter: a dropdown's C<options> come before its C<value>, a slider's
C<min>, C<max> and C<step> are one range set before its C<value>, and a
text input's C<max_length> comes before its C<value>. Everything else is
applied in the order of the layout.

=head1 SUBCLASS INTERFACE

To write an input widget of your own, subclass
C<Term::Fabulous::Widget::Input> with L<Object::Pad> (see the
L</SYNOPSIS>). You must implement C<natural_size> and C<paint>; override
the other methods as needed. Paint with C<put_attrs>
(L<Term::Fabulous::Widget::Canvas/put_attrs>) and the helpers below,
which take termbox2 attributes (the integers returned by
C<foreground_attr>, C<color_attr> and friends) instead of colors.

Term::Fabulous draws a frame only when something changed, and the frame
paints the input (see L</Painting>). Whenever your widget changes state
that C<paint> or C<natural_size> uses, call C<< $self->mark_changed >>
and do not paint: the next frame calls C<paint>. When C<paint> also
reads state of other objects that change without telling your widget,
add that state to L</paint_key>. Without either, the change shows only
when something else makes the input paint.

=head2 natural_size

	method natural_size () { return ( $columns, $rows ) }

Required. The content size, in cells, the input wants when the layout
does not size it (see L</SIZE>). Called for every frame.

=head2 paint

	method paint () { ... }

Required. Draws the input into its buffer. It is called while a frame is
drawn, when the L</paint_key> changed, with a cleared buffer that has at
least one cell; use C<< $self->columns >> and C<< $self->rows >> for
its size. Cell writes made here belong to the frame being drawn and make
no further frame due.

=head2 paint_key

	method paint_key :override () {
		my $group = $self->group;
		return ( $self->SUPER::paint_key, $group->value, $group->is_focused );
	}

The list of values L</paint> depends on; the input paints again when
any of them changed since it last painted. The default holds the size of
the buffer, a count of the input's C<mark_changed> calls, whether it has
the focus and whether it is enabled. Extend it with what C<paint> reads
from other objects, which do not mark this input changed:
L<Term::Fabulous::Widget::RadioButton> adds its group's value, focus and
cursor button, L<Term::Fabulous::Widget::TextInput> its editor's
revision. The values are compared as strings; keep them cheap to
compute, since the key is computed for every frame.

=head2 handle_key

	method handle_key ($event) { return $used }

Receives every L<Term::Fabulous::Event::KeyPress> fired on the input
(or bubbling up to it) while it is enabled. Return true when you used
the key: the event then stops. Return false to let it bubble on. The
default uses nothing.

=head2 handle_mouse

	method handle_mouse ($event) { return $used }

Receives every L<Term::Fabulous::Event::Mouse> fired on the input (or
bubbling up to it) while it is enabled. Return value as for
C<handle_key>. The default uses nothing.

The event carries terminal coordinates. Use
L<Term::Fabulous::Widget::Canvas/cell_at> to turn them into a cell of
the input's buffer; it returns the empty list when the pointer is
outside the buffer (on the border or padding):

	method handle_mouse ($event) {
		my ( $column, $row ) = $self->cell_at($event) or return 0;
		...
	}

=head2 activate

	method activate () { ... }

Called when the input is clicked (the left button pressed and released
over it) while it is enabled. The default does nothing.

=head2 focus_changed

	method focus_changed ($is_focused) { ... }

Called after the input gained (C<$is_focused> true) or lost the focus,
for what a widget does then besides painting (a dropdown closes its
list). The default does nothing; the focus is part of the
L</paint_key>.

=head2 layout_properties

	method layout_properties :common () {
		return ( $class->SUPER::layout_properties, on_label => 'scalar', off_label => 'scalar', on_color => 'color' );
	}

The table of the properties a KDL layout may set and how each is read
(see L<Term::Fabulous::Role::CanParseLayout/layout_properties>). To
make parameters of your widget settable from a layout file, declare it
as a class method (C<:common>), keep the inherited table through
C<< $class->SUPER::layout_properties >> and add an accessor (reader and
writer) of the same name for each new property. Every input inherits
C<can_focus> and C<disabled> (booleans) and its four colors.

=head2 accepts_focus

	method accepts_focus :override () { return 0 }

Whether the input can ever take the focus. Default: 1 (from
L<Clay::UI::Role::Interaction::Focusable>). An input that returns 0
(like L<Term::Fabulous::Widget::RadioButton>) gets C<can_focus> 0 even
when enabled.

=head2 fire_change

	$self->fire_change($new_value);

Fires a L<Term::Fabulous::Event::Change> with that value on the input.
Call it after the user changed the value, never when the program did.

=head2 foreground_attr

	my $fg = $self->foreground_attr;

The termbox2 attribute of C<text_color>, or of C<disabled_color> while
the input is disabled.

=head2 accent_attr

	my $fg = $self->accent_attr;

The termbox2 attribute of C<accent_color>, or of C<disabled_color>
while the input is disabled.

=head2 color_attr

	my $attr = $self->color_attr('#ff0000');

The termbox2 attribute of any color the canvas accepts, C<undef> for
C<undef> or a color with alpha 0 (no color of its own).

=head2 reverse_attr

	my $cursor_fg = $self->reverse_attr($fg);

An attribute in reverse video (foreground and background swapped), as
used for the text cursor. C<undef> counts as the terminal default.

=head2 rgba_of

	my $rgba = $self->rgba_of($color);

Any color the canvas accepts, as the C<[r, g, b, a]> array reference
that C<background_color> and C<border_color> take. A packed integer is
opaque.

=head2 paint_text

	my $next_x = $self->paint_text( $x, $y, $text, $fg, $bg, $limit );

Paints a character string from cell (C<$x>, C<$y>) with the attributes
C<$fg> and C<$bg> (either may be C<undef>). C<$limit> defaults to
C<< $self->columns >>; a grapheme cluster that would reach past it ends
the text. Returns the column after the last cluster painted.

=head2 fill_attrs

	$self->fill_attrs( $x, $y, $width, $glyph, $fg, $bg );

Puts a one-column glyph into C<$width> cells of row C<$y>, starting at
C<$x>.

=head2 focus_background_attr

	my $bg = $self->focus_background_attr;

The attribute of C<focus_background_color> while the input has the
focus, C<undef> otherwise. Override it to change when the focus
background is shown (L<Term::Fabulous::Widget::RadioButton> shows it
only on the button the keyboard is on).

=head2 paint_focus_background

	my $bg = $self->paint_focus_background;

Fills the whole buffer with C<focus_background_attr> when it is defined,
and returns it (C<undef> when the input shows no focus background).
Pass the result on as the background of everything you paint after it.

=head1 CAVEATS

=over

=item *

A disabled input does not use the mouse wheel; inside a
L<Term::Fabulous::Widget::ScrollBox> the wheel over it scrolls the
scroll box. So does the wheel over a text area, a slider or an open
dropdown list that cannot move any further.

=back

=head1 SEE ALSO

L<Term::Fabulous::Manual::Forms/FORMS AND INPUT WIDGETS>,
L<Term::Fabulous::Event::Change>, L<Term::Fabulous::Widget::Canvas>,
L<Term::Fabulous::Widget::TextInput>.

=cut
