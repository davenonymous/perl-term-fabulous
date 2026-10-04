#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Color;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

# Two themes derived from one base color each.
sub theme ($base_spec) {
	my $base    = Term::Fabulous::Color->new( color => $base_spec );
	my $is_dark = ( $base->to_hsl )[2] < 50;
	return {
		background => $base,
		panel      => $is_dark ? $base->lighten(0.06)                        : $base->darken(0.06),
		border     => $is_dark ? $base->lighten(0.35)                        : $base->darken(0.35),
		text       => $is_dark ? Term::Fabulous::Color->rgb( 230, 230, 230 ) : Term::Fabulous::Color->rgb( 30, 30, 30 ),
		accent     => Term::Fabulous::Color->hsl( 210, 80, $is_dark ? 65 : 40 ),
	};
}
my @themes  = ( theme('#141923'), theme('hsl(40, 30%, 92%)') );
my $current = 0;

my $root = Term::Fabulous::Widget::Box->new(
	layout => {
		layout_direction => CLAY_TOP_TO_BOTTOM,
		sizing           => { width => sizing_grow(), height => sizing_grow() },
		padding          => { left  => 2, right => 2, top => 1, bottom => 1 },
	},
);
my $panel = Term::Fabulous::Widget::Box->new(
	border_width => 1,
	border_style => Term::Fabulous::Enum::BorderStyle->Round,
	layout       => {
		layout_direction => CLAY_TOP_TO_BOTTOM,
		sizing           => { width => sizing_grow() },
		padding          => { left  => 1, right => 1 },
		child_gap        => 1,
	},
);
my $label = Term::Fabulous::Widget::Text->new( text => 'Press F2 to switch between the dark and the light theme.' );
my $field = Term::Fabulous::Widget::TextField->new( placeholder => 'Type here' );
$panel->add_child( $label, $field );
$root->add_child($panel);

# Every color accessor takes a Color object as it is.
sub apply_theme ($theme) {
	$root->background_color( $theme->{background} );
	$panel->background_color( $theme->{panel} );
	$panel->border_color( $theme->{border} );
	$label->text_color( $theme->{text} );
	$field->background_color( $theme->{background} );
	$field->text_color( $theme->{text} );
	$field->accent_color( $theme->{accent} );
	$field->focus_background_color( $theme->{background}->blend( $theme->{accent}, 0.2 ) );
	return;
}
apply_theme( $themes[$current] );

$root->on(
	KeyPress => sub ($event) {
		return unless ( $event->key_name // '' ) eq 'F2';
		$current = 1 - $current;
		apply_theme( $themes[$current] );
		return;
	}
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->interaction->set_focused_widget($field);
$ui->run;
