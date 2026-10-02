#!/usr/bin/env perl

# Buttons that react to the mouse and the keyboard, application key
# bindings and a clock that a timer updates once per second.
#
#     perl examples/buttons-and-keys.pl

use v5.24;
use warnings;
use strict;
use experimental 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/../lib/";

use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use POSIX qw(strftime);
use Term::Fabulous;
use Term::Fabulous::Color;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $CONTINUE = Clay::UI::Enum::Result->CONTINUE;

my $button_color = Term::Fabulous::Color->new( color => '#2b3a55' );
my $press_color  = $button_color->lighten(0.15);
my $border_color = Term::Fabulous::Color->new( color => '#5a6b8c' );
my $focus_color  = Term::Fabulous::Color->new( color => '#61afef' );

my $root = Term::Fabulous::Widget::Box->new(
	background_color => [ 20, 25, 35, 255 ],
	layout           => {
		layout_direction => CLAY_TOP_TO_BOTTOM,
		sizing           => { width => sizing_grow(), height => sizing_grow() },
		padding          => { left => 2, right => 2, top => 1, bottom => 1 },
		child_gap        => 1,
	},
);

sub label ( $text, $color = [ 220, 220, 220, 255 ] ) {
	return Term::Fabulous::Widget::Text->new( text => $text, text_color => $color );
}

my $clock   = label( 'Time: --:--:--', [ 150, 160, 180, 255 ] );
my $counter = label('Counter: 0');
my $status  = label('Tab focuses a button, Enter or Space presses it. + - r change the counter, q or Ctrl+Q quits.');
$root->add_child( $clock, $counter );

my $count = 0;

sub set_count ($new) {
	$count = $new;
	$counter->text("Counter: $count");
	return;
}

# A Button is a Box that can take the focus and tracks hover and press
# state. It has no look of its own, so the listeners below give it one:
# a bright border while it has the focus, a lighter background while the
# mouse button is held on it. Terminals report the mouse only when a
# button is pressed, released or dragged, or the wheel turns, so there is
# no live hover highlight; OnHoverStopped fires when a press is dragged
# off the button or released elsewhere.
sub button ( $id, $caption, $action ) {
	my $button = Term::Fabulous::Widget::Button->new(
		id               => $id,
		background_color => $button_color,
		border_color     => $border_color,
		border_width     => 1,
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
		layout           => { padding => { left => 1, right => 1 } },
	);
	$button->add_child( label($caption) );

	my $look_normal = sub { $button->background_color( $button_color ); return };
	$button->on( OnFocus        => sub ($event) { $button->border_color( $focus_color );  return $CONTINUE } );
	$button->on( OnBlur         => sub ($event) { $button->border_color( $border_color ); return $CONTINUE } );
	$button->on( OnPress        => sub ($event) { $button->background_color( $press_color ); return } );
	$button->on( OnHoverStopped => sub ($event) { $look_normal->(); return } );

	# A click: the left button pressed and released over the button.
	$button->on( OnRelease => sub ($event) { $look_normal->(); $action->(); return } );

	# Enter and Space press the focused button; every other key bubbles
	# on to the root, where the application shortcuts live.
	$button->on(
		KeyPress => sub ($event) {
			my $key = $event->key_name // '';
			return $CONTINUE unless $key eq 'Enter' || $key eq 'Space';
			$action->();
			return;
		}
	);
	return $button;
}

my $buttons = Term::Fabulous::Widget::Box->new( layout => { child_gap => 2 } );
$buttons->add_child(
	button( increase => 'Increase', sub { set_count( $count + 1 ) } ),
	button( decrease => 'Decrease', sub { set_count( $count - 1 ) } ),
	button( reset    => 'Reset',    sub { set_count(0) } ),
);
$root->add_child( $buttons, $status );

my $ui = Term::Fabulous->new( width => 80, height => 24, root => $root );

# Application shortcuts. KeyPress reaches the root when nothing has the
# focus, or when the focused widget's listeners let it bubble. Escape is
# not used to quit: terminals send Alt plus a key as Escape followed by
# the key, so any Alt combination would end the program.
my %action_by_key = (
	'+'      => sub { set_count( $count + 1 ) },
	'-'      => sub { set_count( $count - 1 ) },
	'r'      => sub { set_count(0) },
	'q'      => sub { $ui->loop->stop },
	'Ctrl+Q' => sub { $ui->loop->stop },
);
$root->on(
	KeyPress => sub ($event) {
		my $action = $action_by_key{ $event->key_name // '' } or return;
		$action->();
		return;
	}
);

# The screen is redrawn 30 times per second, so changing the text is all
# the timer has to do.
my $timer = IO::Async::Timer::Periodic->new(
	interval       => 1,
	first_interval => 0,
	on_tick        => sub { $clock->text( strftime( 'Time: %H:%M:%S', localtime ) ); return },
);
$timer->start;
IO::Async::Loop->new->add($timer);

$ui->run;
