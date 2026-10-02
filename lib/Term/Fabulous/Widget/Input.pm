package Term::Fabulous::Widget::Input;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

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
	:abstract
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed);
	use Scalar::Util qw(refaddr weaken);
	use Termbox 2 qw(TB_TRUECOLOR_REVERSE);
	use Term::Fabulous::Color;
	use Term::Fabulous::Event::Change;
	use Term::Fabulous::Render::Attr qw(cell_color_attr);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	my @COLOR_NAMES = qw(text_color disabled_color accent_color focus_background_color);

	field $disabled :param = 0;

	field $text_color             :param = [ 220, 223, 228, 255 ];
	field $disabled_color         :param = [ 108, 112, 120, 255 ];
	field $accent_color           :param = [ 97,  175, 239, 255 ];
	field $focus_background_color :param = [ 52,  58,  72,  255 ];

	# The content size a subclass asks for when the layout gives none.
	method natural_size;

	# Draws the widget into the cleared buffer.
	method paint;

	ADJUST {
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
		$disabled = $new[0] ? 1 : 0;
		$self->_sync_focusability;
		$self->repaint;
		return $disabled;
	}

	method is_enabled () {
		return !$disabled;
	}

	method accepts_focus () {
		return 1;
	}

	# A disabled widget cannot take the focus and gives it up.
	method _sync_focusability () {
		$self->can_focus( $self->accepts_focus && !$disabled ? 1 : 0 );
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
		return ( $attr // 0 ) | TB_TRUECOLOR_REVERSE;
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

	method repaint () {
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
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Input - Abstract base class of the input widgets

=head1 SYNOPSIS

	class My::Toggle :isa(Term::Fabulous::Widget::Input) :strict(params) {
		field $on = 0;

		method natural_size () { return ( 3, 1 ) }

		method paint () {
			$self->paint_text( 0, 0, $on ? 'ON' : 'OFF', $self->foreground_attr, undef );
		}

		method activate () {
			$on = !$on;
			$self->repaint;
			$self->fire_change($on);
		}
	}

=head1 DESCRIPTION

The common base of L<Term::Fabulous::Widget::TextField>,
L<Term::Fabulous::Widget::TextArea>, L<Term::Fabulous::Widget::Checkbox>,
L<Term::Fabulous::Widget::RadioButton>, L<Term::Fabulous::Widget::Dropdown>
and L<Term::Fabulous::Widget::Slider>. An input is a
L<Term::Fabulous::Widget::Canvas> that paints itself: it repaints its
buffer whenever its state, its colors, its focus or its size change, so
only the cells that changed reach the terminal. Anything drawn into it
from outside is lost on the next repaint.

An input can take the keyboard focus
(L<Clay::UI::Role::Interaction::Focusable>), and tracks hover and press
state (L<Clay::UI::Role::Interaction::Hoverable>,
L<Clay::UI::Role::Interaction::Pressable>). Under L<Term::Fabulous>,
Tab and Shift-Tab move the focus between inputs and clicking an input
focuses it. The focused input receives the key presses; keys it uses
do not bubble further, so shortcuts of the application keep working
while the user types, as long as they are keys the input does not use
(Escape, Tab, function keys, ...). The input's own C<KeyPress>
listeners still see every key.

=head1 CONSTRUCTOR

Unknown parameters die. Besides the parameters of
L<Term::Fabulous::Widget::Canvas>, every input accepts:

=over

=item C<disabled>

Boolean, default 0. See L</disabled>.

=item C<can_focus>

Boolean, default 1 (see L<Clay::UI::Role::Interaction::Focusable>);
setting C<disabled> overrides it.

=item C<text_color>, C<disabled_color>, C<accent_color>, C<focus_background_color>

The colors of normal text, of all text while disabled, of the accent
(check marks, selected items, the filled part of a slider) and of the
content background while the input has the focus. Each takes anything
L<Term::Fabulous::Widget::Canvas/Colors> accepts; C<undef> or an invalid
color dies. Every color has a reader and writer of the same name; a
write repaints the input.

=back

=head1 SIZE

An input has a natural content size, for example one row and as many
columns as its label needs. When the C<layout> gives no C<sizing> for
an axis, the input is sized to fit its natural size plus its padding
and border on that axis. A sizing given in the C<layout> always wins.

=head1 METHODS

=head2 disabled

	$input->disabled(1);

Reader and writer. A disabled input is painted in C<disabled_color>,
ignores keys, clicks and the mouse wheel, fires no events, and cannot
take the focus (its C<can_focus> becomes 0); disabling the focused input
removes the focus. Enabling it sets C<can_focus> back to 1.

=head2 is_enabled

The opposite of C<disabled>.

=head2 repaint

Clears the buffer and paints the input again. Called automatically;
returns the input.

=head1 EVENTS

Inputs fire L<Term::Fabulous::Event::Change> on themselves when the user
changes their value. Setting a value from the program fires nothing.

=head1 SUBCLASS INTERFACE

=over

=item C<natural_size> (required)

C<($columns, $rows)> of content the input needs.

=item C<paint> (required)

Draws the input into its buffer, which is cleared and has at least one
cell. Use C<columns> and C<rows> for its size.

=item C<handle_key($event)>, C<handle_mouse($event)>

Receive the L<Term::Fabulous::Event::KeyPress> and
L<Term::Fabulous::Event::Mouse> events fired on the input (or bubbling
up to it) while it is enabled. Return true when the event was used: it
then stops bubbling. The defaults use nothing.

=item C<activate>

Called when the input is clicked (pressed and released with the left
button) while enabled. Does nothing by default.

=item C<focus_changed($is_focused)>

Called after the input gained or lost the focus; repaints by default.

=item C<size_changed>

Called when the layout gave the input's buffer a new size (on
L<Term::Fabulous::Event::CanvasResize>); repaints by default.

=item C<accepts_focus>

Whether the input can ever take the focus; 1 by default. An input that
returns 0 has C<can_focus> 0 even when enabled.

=item C<fire_change($value)>

Fires a L<Term::Fabulous::Event::Change>.

=item C<foreground_attr>, C<accent_attr>, C<color_attr($color)>, C<reverse_attr($attr)>

termbox2 attributes for painting with C<put_attrs>: the text color and
the accent color (both the disabled color while disabled), any color
(undef for none), and an attribute in reverse video.

=item C<rgba_of($color)>

Any color as the C<[r, g, b, a]> arrayref Clay takes for
C<background_color> and C<border_color>.

=item C<paint_text($x, $y, $text, $fg, $bg, $limit = columns)>

Paints a character string with attributes from C<($x, $y)> and returns
the column after it. A cluster that would cross column C<$limit> ends
the text.

=item C<fill_attrs($x, $y, $width, $glyph, $fg, $bg)>

Repeats a one-column glyph over C<$width> cells.

=item C<focus_background_attr>, C<paint_focus_background>

The attribute of C<focus_background_color> while the input shows the
focus, C<undef> otherwise; subclasses may override when to show it.
C<paint_focus_background> fills the buffer with it (when defined) and
returns it.

=back

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Box/KDL PROPERTIES> plus C<disabled>,
C<can_focus> (C<#true> / C<#false>) and the colors above.

Properties are applied in the order they appear in the layout, with the
same checks as the writers of the same name. Give what a value depends
on before the value: a dropdown's options, a slider's range, a text
field's C<max_length>.

=cut
