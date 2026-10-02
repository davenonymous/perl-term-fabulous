#!/usr/bin/env perl

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Checkbox;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;
use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM CLAY_ALIGN_X_CENTER CLAY_ALIGN_Y_CENTER);

my $root = Term::Fabulous::Widget::Box->new(
	background_color => [ 20, 25, 35, 255 ],
	layout           => {
		sizing          => { width => sizing_grow(), height => sizing_grow() },
		child_alignment => { x => CLAY_ALIGN_X_CENTER, y => CLAY_ALIGN_Y_CENTER },
	},
);

my $dialog = Term::Fabulous::Widget::Box->new(
	background_color => [ 28, 33, 45, 255 ],
	border_width     => 1,
	border_color     => [ 97, 175, 239, 255 ],
	border_style     => Term::Fabulous::Enum::BorderStyle->Round,
	layout           => {
		layout_direction => CLAY_TOP_TO_BOTTOM,
		sizing           => { width => sizing_fixed(44) },
		padding          => { left => 1, right => 1, top => 1, bottom => 1 },
		child_gap        => 1,
	},
);
$root->add_child($dialog);

sub text ( $string, $color = [ 220, 220, 220, 255 ] ) {
	return Term::Fabulous::Widget::Text->new( text => $string, text_color => $color );
}

my $user    = Term::Fabulous::Widget::TextField->new( id => 'user',     placeholder => 'User name', layout => { sizing => { width => sizing_grow() } } );
my $password = Term::Fabulous::Widget::TextField->new( id => 'password', placeholder => 'Password',  layout => { sizing => { width => sizing_grow() } }, mask => '*' );
my $remember = Term::Fabulous::Widget::Checkbox->new( id => 'remember', label => 'Remember me' );
my $message  = text( 'Enter in a field logs in.', [ 150, 160, 180, 255 ] );
$dialog->add_child( text('Log in'), $user, $password, $remember, $message );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

sub log_in () {
	if ( $user->value eq '' || $password->value eq '' ) {
		$message->text('Please fill in both fields.');
		$ui->interaction->set_focused_widget( $user->value eq '' ? $user : $password );
		return;
	}
	$message->text( sprintf 'Welcome, %s!%s', $user->value, $remember->checked ? ' (remembered)' : '' );
	return;
}

# Enter in either field fires Submit on that field; both bubble to the dialog.
$dialog->on( Submit => sub ($event) { log_in(); return } );

$ui->interaction->set_focused_widget($user);
$ui->run;
