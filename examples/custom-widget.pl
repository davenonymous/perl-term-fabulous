#!/usr/bin/env perl

# A widget of your own: an on/off switch built on
# Term::Fabulous::Widget::Input. It takes the focus, reacts to keys and
# clicks, fires Change events, and can be used from a KDL layout.
#
#     perl examples/custom-widget.pl

use v5.24;
use warnings;
use strict;
use experimental 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/../lib/";

use Object::Pad 0.825;

use Term::Fabulous;
use Term::Fabulous::Layout;
use Term::Fabulous::Widget::Input;

class My::ToggleSwitch :isa(Term::Fabulous::Widget::Input) :strict(params) {
	use Term::Fabulous::Unicode qw(string_columns);

	use constant ON_MARK  => '[ ON]';
	use constant OFF_MARK => '[OFF]';

	field $on    :param = 0;
	field $label :param = '';

	# Accessor of the state. Like the built-in inputs, a write from the
	# program repaints but fires no Change event.
	method value (@new) {
		return $on unless @new;
		$on = $new[0] ? 1 : 0;
		$self->repaint;
		return $on;
	}

	method label (@new) {
		return $label unless @new;
		$label = $new[0];
		$self->repaint;
		return $label;
	}

	# The names a KDL layout may set, on top of those of every input.
	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(value label) );
	}

	# Columns and rows of content the widget needs when the layout does
	# not size it.
	method natural_size () {
		my $label_columns = length $label ? 1 + string_columns($label) : 0;
		return ( string_columns(ON_MARK) + $label_columns, 1 );
	}

	# Draws into the cleared buffer; called whenever the state, the focus,
	# the colors or the size change.
	method paint () {
		my $bg   = $self->paint_focus_background;
		my $mark = $on ? ON_MARK : OFF_MARK;
		my $x    = $self->paint_text( 0, 0, $mark, $on ? $self->accent_attr : $self->foreground_attr, $bg );
		$self->paint_text( $x + 1, 0, $label, $self->foreground_attr, $bg ) if length $label;
		return;
	}

	# The user changes the state: repaint and tell the listeners.
	method _switch ($new) {
		return if $new == $on;
		$self->value($new);
		$self->fire_change($on);
		return;
	}

	# Return true for keys the widget uses; they stop bubbling. Others
	# (Tab, Escape, ...) bubble on to the ancestors.
	method handle_key ($event) {
		my $name = $event->key_name // return 0;
		my %new_state_by_key = ( Space => !$on, Enter => !$on, Left => 0, Right => 1 );
		return 0 unless exists $new_state_by_key{$name};
		$self->_switch( $new_state_by_key{$name} ? 1 : 0 );
		return 1;
	}

	# A click: the left mouse button pressed and released over the widget.
	method activate () {
		$self->_switch( $on ? 0 : 1 );
		return;
	}
}

# Term::Fabulous::Layout loads the classes a layout names with require.
# This class lives in this script, so mark it as loaded.
$INC{'My/ToggleSwitch.pm'} = __FILE__;

my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text
use My::ToggleSwitch as Toggle

Box "root" {
	layout direction=down gap=1
	sizing width=grow height=grow
	padding left=2 right=2 top=1 bottom=1
	background_color "#141923"

	Text { text "Tab moves, Space, Enter, Left, Right or a click switch. Ctrl+C ends."; text_color "#dcdcdc"; }
	Toggle "wifi" { label "Wi-Fi"; value #true; }
	Toggle "bluetooth" { label "Bluetooth"; }
	Toggle "airplane" { label "Airplane mode"; accent_color "#e5c07b"; }
	Text "status" { text " "; text_color "#96a0b4"; }
}
KDL

my $root = $layout->build;

# The first widget at or below $node whose id is $id, or undef.
sub find_widget ( $node, $id ) {
	return $node if defined $node->id && $node->id eq $id;
	return undef unless $node->can('children');
	foreach my $child ( @{ $node->children } ) {
		my $found = find_widget( $child, $id );
		return $found if defined $found;
	}
	return undef;
}

my $status = find_widget( $root, 'status' );

$root->on(
	Change => sub ($event) {
		$status->text( sprintf '%s switched %s', $event->target->label, $event->value ? 'on' : 'off' );
		return;
	}
);

my $ui = Term::Fabulous->new( width => 80, height => 24, root => $root );
$ui->interaction->focus_next;
$ui->run;
