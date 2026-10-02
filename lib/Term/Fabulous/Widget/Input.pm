package Term::Fabulous::Widget::Input;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Input::Element;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Input
	:isa(Term::Fabulous::Widget::Input::Element)
	:abstract
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed);
	use Scalar::Util qw(refaddr weaken);
	use Term::Fabulous::Termbox qw(TB_REVERSE);
	use Term::Fabulous::Color;
	use Term::Fabulous::Event::Change;
	use Term::Fabulous::Render::Attr qw(cell_color_attr);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	my @COLOR_NAMES = qw(text_color disabled_color accent_color focus_background_color);

	field $disabled :param = 0;

	# The can_focus last asked for (new, KDL or the accessor), whether or
	# not the input is disabled; undef until something asks, which leaves
	# the constructor's can_focus in force.
	field $wants_focus;

	field $text_color             :param = [ 220, 223, 228, 255 ];
	field $disabled_color         :param = [ 108, 112, 120, 255 ];
	field $accent_color           :param = [ 97,  175, 239, 255 ];
	field $focus_background_color :param = [ 52,  58,  72,  255 ];

	# The content size a subclass asks for when the layout gives none.
	method natural_size;

	# Draws the widget into the cleared buffer.
	method paint;

	ADJUST {
		$disabled = $disabled ? 1 : 0;
		$self->_checked_color( $_ => $self->$_ ) foreach @COLOR_NAMES;
		$self->_sync_focusability;

		weaken( my $weak_self = $self );
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		my $own      = sub ($event) { defined $weak_self && refaddr( $event->target ) == refaddr($weak_self) };

		$self->on( CanvasResize => sub ($event) { $weak_self->size_changed; return $continue } );
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
	# State
	# ---------------------------------------------------------------------

	method disabled (@new) {
		return $disabled unless @new;
		my $disable = $new[0] ? 1 : 0;
		return $disabled if $disable == $disabled;
		$disabled = $disable;
		$self->_sync_focusability;
		$self->repaint;
		return $disabled;
	}

	# Reads whether the input can take the focus now; a write records the
	# wish, which counts while the input is enabled.
	method can_focus :override (@new) {
		return $self->SUPER::can_focus unless @new;
		die ref($self) . ": can_focus takes one value, got " . scalar(@new) . "\n" unless @new == 1;
		die ref($self) . ": can_focus must be a plain boolean value, got a " . ref( $new[0] ) . " reference\n" if ref $new[0];
		$wants_focus = $new[0] ? 1 : 0;
		$self->_sync_focusability;
		return $self->SUPER::can_focus;
	}

	method is_enabled () {
		return !$disabled;
	}

	method accepts_focus () {
		return 1;
	}

	# A disabled widget cannot take the focus and gives it up; an enabled
	# one can when can_focus asked for it and the widget accepts focus.
	method _sync_focusability () {
		$wants_focus //= $self->SUPER::can_focus ? 1 : 0;
		$self->SUPER::can_focus( $wants_focus && $self->accepts_focus && !$disabled ? 1 : 0 );
		my $ui = $self->ui;
		$ui->interaction->set_focused_widget(undef) if $disabled && defined $ui && $self->is_focused;
		return;
	}

	# ---------------------------------------------------------------------
	# Colors: anything Term::Fabulous::Widget::Canvas accepts for a cell
	# ---------------------------------------------------------------------

	method _checked_color ( $name, $value ) {
		die ref($self) . ": $name must be a color, got undef" unless defined $value;
		cell_color_attr( $name => $value );
		return $value;
	}

	method _set_color ( $name, $field_ref, $value ) {
		$$field_ref = $self->_checked_color( $name => $value );
		$self->repaint;
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

	# Marks the widget changed even before it has a buffer to paint: what
	# it paints from may also be what it sizes itself by (natural_size).
	method repaint () {
		$self->mark_changed;
		return $self unless $self->columns > 0 && $self->rows > 0;
		$self->clear;
		$self->paint;
		return $self;
	}

	method focus_changed ($is_focused) {
		$self->repaint;
		return;
	}

	method size_changed () {
		$self->repaint;
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

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, 'can_focus', 'disabled', @COLOR_NAMES );
	}

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, qw(can_focus disabled) );
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
	$field->accent_color('#ff8800');      # repaints at once

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
			$self->repaint;
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
L<Term::Fabulous::Manual/KEYBOARD>.

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

It can be built from a KDL layout file (see L</KDL PROPERTIES>).

=back

Technically, an input is a L<Term::Fabulous::Widget::Canvas> that paints
itself: it clears and repaints its cell buffer whenever its value, its
colors, its focus or its size change, so only cells that really changed
are sent to the terminal. Anything you draw into an input with the
canvas methods (C<put>, C<put_text>, ...) is lost at the next repaint.

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
L<Term::Fabulous::Manual/LAYOUT>. A C<sizing> you give here overrides
the natural size of the input on that axis (see L</SIZE>).

=item C<background_color>

The widget's background, in any format L<Term::Fabulous::Color> accepts
(see L<Term::Fabulous::Manual/Color formats>); it is stored as an
C<[r, g, b, a]> array reference. Text inputs and the dropdown
default to a dark gray (C<[36, 40, 48, 255]>); the other inputs have no
background of their own and show the background of their parent.

=item C<border_width>

=item C<border_color>

=item C<border_style>

A border around the input, exactly as for
L<Term::Fabulous::Widget::Box>; see L<Term::Fabulous::Manual/BORDERS>.
The border takes cells inside the widget's box; the natural size is
grown accordingly.

=item C<disabled>

A boolean, stored as 1 or 0. Default: 0. A disabled input is painted in
C<disabled_color>, ignores keys, clicks and the mouse wheel, never
fires C<Change> (or C<Submit>) and cannot take the focus. See
L</disabled>.

=item C<can_focus>

A boolean. Default: 1. Whether the input may take the keyboard focus
(see L<Clay::UI::Role::Interaction::Focusable>). It counts while the
input is enabled: a disabled input cannot take the focus, whatever this
says (see L</can_focus>). A L<Term::Fabulous::Widget::RadioButton> never
takes the focus, so for it the parameter has no effect.

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

=head1 METHODS

=head2 disabled

	my $is_disabled = $input->disabled;
	$input->disabled(1);
	$input->disabled(0);

Accessor. Returns 1 or 0; any true or false value may be written, also
through C<new>.

Writing a true value disables the input: it is painted in
C<disabled_color>, ignores keys, clicks and the mouse wheel, never fires
C<Change> or C<Submit>, cannot take the focus (C<can_focus> reads 0) and, if it has the
focus, gives the focus up (no widget is focused afterwards, unless the
input is inside an open L<Term::Fabulous::Widget::Dialog>, whose
backdrop takes it). The events
themselves are still delivered: C<KeyPress> and C<Mouse> events fired on
a disabled input bubble on to its ancestors, and Clay::UI still fires
C<OnHoverStart>, C<OnHoverStopped>, C<OnPress> and C<OnRelease> on it,
so listeners you add yourself still run.

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

Accessor for the C<text_color> parameter. The reader returns the value
exactly as it was given (it is not converted). Writing repaints the
input and returns the new value. An invalid color, or C<undef>, dies
and leaves the old color.

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

=head2 repaint

	$input->repaint;

Clears the input's buffer, paints it again from its current state and
marks the input changed (see
L<Clay::UI::Role::Core::Element/mark_changed>), so that the next frame
shows it and sizes it again, also when the change was made from a
timer. The input calls it whenever something visible changes, so you
only need it after changing state behind the widget's back (for
example through L<Term::Fabulous::Widget::TextInput/editor>). Before
the input has been laid out for the first time it only marks the input
changed. Returns the input.

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

The pointer events of L<Clay::UI>; see L<Term::Fabulous::Manual/MOUSE>.
A completed click (C<OnRelease> after a press on the same input) is what
toggles a checkbox or selects a radio button.

=item C<CanvasResize>

L<Term::Fabulous::Event::CanvasResize>, fired when the layout gives the
input a new size. The input repaints itself.

=back

The input registers its own listeners for C<KeyPress>, C<Mouse>,
C<OnFocus>, C<OnBlur>, C<OnRelease> and C<CanvasResize> when it is
constructed. Listeners you add with C<on> run after them, on the same
widget, and see every event, including keys the input used. Keep in mind
that your listener's return value also decides whether the event
bubbles further.

=head1 KDL PROPERTIES

In a layout file (see L<Term::Fabulous::Layout>), every input accepts
the properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>
(C<layout>, C<sizing>, C<padding>, C<border>, C<background_color>,
C<border_color>, C<border_width>, C<width_group>, C<height_group>) and:

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

Properties are applied one after the other, in the order they appear in
the layout, with the same checks as the accessors of the same name. A
property whose valid values depend on another one must therefore come
after it: a dropdown's C<options> before its C<value>, a slider's C<min>,
C<max> and C<step> before its C<value>, a text input's C<max_length>
before its C<value>. In the wrong order, one of two things happens:

=over

=item *

If a property is invalid given the properties before it, building the
layout dies: a dropdown C<value> before any C<options> ("no option has
the value"), a slider C<value 150> while C<max> is still the default
100, a C<max_length 3> after a longer C<value>.

=item *

Otherwise the earlier value is accepted and then silently adjusted by
the later property: a slider C<value 5> followed by C<min 10> ends up
with the value 10.

=back

=head1 SUBCLASS INTERFACE

To write an input widget of your own, subclass
C<Term::Fabulous::Widget::Input> with L<Object::Pad> (see the
L</SYNOPSIS>). You must implement C<natural_size> and C<paint>; override
the other methods as needed. Paint with C<put_attrs>
(L<Term::Fabulous::Widget::Canvas/put_attrs>) and the helpers below,
which take termbox2 attributes (the integers returned by
C<foreground_attr>, C<color_attr> and friends) instead of colors.

Term::Fabulous draws a frame only when something changed. Whenever your
widget changes state that C<paint> or C<natural_size> uses, call
L</repaint>: it paints the new state and marks the widget changed. State
that only C<natural_size> uses may instead call
C<< $self->mark_changed >> (see
L<Clay::UI::Role::Core::Element/mark_changed>). Without either, the
change shows only when something else causes a frame.

=head2 natural_size

	method natural_size () { return ( $columns, $rows ) }

Required. The content size, in cells, the input wants when the layout
does not size it (see L</SIZE>). Called for every frame.

=head2 paint

	method paint () { ... }

Required. Draws the input into its buffer. It is called by L</repaint>
with a cleared buffer that has at least one cell; use
C<< $self->columns >> and C<< $self->rows >> for its size.

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

Called after the input gained (C<$is_focused> true) or lost the focus.
The default repaints.

=head2 size_changed

	method size_changed () { ... }

Called when the layout gave the input's buffer a new size. The default
repaints.

=head2 layout_properties

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(on_label off_label) );
	}

The names of the accessors a KDL layout may set (see
L<Term::Fabulous::Role::CanParseLayout/layout_properties>). To make
parameters of your widget settable from a layout file, override it with
C<:override>, keep the inherited names through C<SUPER::layout_properties>
and add an accessor (reader and writer) of the same name for each new
property. Names ending in C<_color> are parsed as colors.

=head2 accepts_focus

	method accepts_focus () { return 0 }

Whether the input can ever take the focus. Default: 1. An input that
returns 0 (like L<Term::Fabulous::Widget::RadioButton>) gets
C<can_focus> 0 even when enabled.

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

L<Term::Fabulous::Manual/FORMS AND INPUT WIDGETS>,
L<Term::Fabulous::Event::Change>, L<Term::Fabulous::Widget::Canvas>,
L<Term::Fabulous::Widget::TextInput>.

=cut
