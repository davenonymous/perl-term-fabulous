#!/usr/bin/env perl

# Themes: the same widgets in the built-in dark and light themes and in
# a theme loaded from a file (examples/ocean.kdl). F2 switches to the
# next theme; the widgets that were given a color of their own keep it.
# See Term::Fabulous::Manual::Looks and Term::Fabulous::Theme.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM);
use Term::Fabulous;
use Term::Fabulous::Theme;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Checkbox;
use Term::Fabulous::Widget::Divider;
use Term::Fabulous::Widget::ProgressBar;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;

my @themes  = ( 'dark', 'light', Term::Fabulous::Theme->from_file("$FindBin::Bin/ocean.kdl") );
my $current = 0;

# A panel: the frame and the background come from the theme, the title
# is a Text without a color of its own, so it is drawn in the theme's
# text color.
my $panel = Term::Fabulous::Widget::Box->new(
	border_width => 1,
	layout       => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed(50) }, padding => { left => 1, right => 1 }, child_gap => 1 },
);
my $title = Term::Fabulous::Widget::Text->new( text => 'Theme: dark (F2 switches, Ctrl+C quits)' );

my $name  = Term::Fabulous::Widget::TextField->new( placeholder => 'Your name', layout => { sizing => { width => sizing_grow() } } );
my $agree = Term::Fabulous::Widget::Checkbox->new( label => 'Subscribe to the newsletter', checked => 1 );
my $bar   = Term::Fabulous::Widget::ProgressBar->new( value => 65, layout => { sizing => { width => sizing_grow() } } );

# Two buttons: the first is 'primary', which the ocean theme styles in
# its accent; the second keeps its own border color under every theme.
my $save = Term::Fabulous::Widget::Button->new( classes => ['primary'], border_width => 1, layout => { padding => { left => 2, right => 2 } } );
$save->add_child( Term::Fabulous::Widget::Text->new( text => 'Save' ) );
my $cancel = Term::Fabulous::Widget::Button->new( border_width => 1, border_color => '#e06c75', layout => { padding => { left => 2, right => 2 } } );
$cancel->add_child( Term::Fabulous::Widget::Text->new( text => 'Cancel' ) );
my $buttons = Term::Fabulous::Widget::Box->new( layout => { child_gap => 2 } );
$buttons->add_child( $save, $cancel );

$panel->add_child( $title, Term::Fabulous::Widget::Divider->new( text => 'Account' ), $name, $agree, $bar, $buttons );

my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 2, right => 2, top => 1, bottom => 1 } } );
$root->add_child($panel);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24, theme => $themes[$current] );
$root->on(
	KeyPress => sub ($event) {
		return unless ( $event->key_name // '' ) eq 'F2';
		$current = ( $current + 1 ) % @themes;
		$ui->theme( $themes[$current] );
		$title->text( 'Theme: ' . $ui->theme->name . ' (F2 switches, Ctrl+C quits)' );
		return;
	}
);
$ui->interaction->set_focused_widget($name);
$ui->run;
