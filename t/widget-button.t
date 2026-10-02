use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_fixed sizing_grow);
use InputTest;
use Term::Fabulous;
use Term::Fabulous::Layout;
use Term::Fabulous::Termbox qw(TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE);
use Term::Fabulous::Termbox::Event;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;

{
	no warnings 'redefine';
	*Term::Fabulous::Render::Target::Termbox::tb_clear   = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_present = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_print   = sub {0};
}

my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
my $button = Term::Fabulous::Widget::Button->new(
	background_color => [ 2, 2, 2, 255 ],
	border_width     => 1,
	border_color     => [ 5, 5, 5, 255 ],
	layout           => { sizing => { width => sizing_fixed(6), height => sizing_fixed(3) } },
);
$root->add_child($button);
my $ui = Term::Fabulous->new( width => 20, height => 5, root => $root );

my @activations;
my @keys_at_root;
$button->on( Activate => sub { push @activations, $_[0]->target; return } );
$root->on( KeyPress => sub { push @keys_at_root, $_[0]->key_name; return } );

sub mouse ( $key, $x, $y ) {
	$ui->_dispatch_termbox_event( Term::Fabulous::Termbox::Event->new( type => TB_EVENT_MOUSE, key => $key, x => $x, y => $y ) );
	return;
}

subtest 'Enter and Space activate, other keys bubble' => sub {
	press( $button, 'Enter' );
	press( $button, 'Space' );
	press( $button, 'x' );
	is scalar @activations, 2, 'Enter and Space fire Activate';
	ref_is $activations[0], $button, 'on the button';
	is \@keys_at_root, ['x'], 'the used keys do not bubble, the others do';
	$button->activate;
	is scalar @activations, 3, 'activate fires it from code';
};

subtest 'a click activates and shows the pressed look' => sub {
	@activations = ();
	$ui->draw;
	mouse( TB_KEY_MOUSE_LEFT, 2, 1 );
	$ui->_draw_pending;
	ok $button->is_pressed,    'the button is pressed after the frame';
	ok $button->reverse_video, 'and drawn in reverse video';

	mouse( TB_KEY_MOUSE_RELEASE, 2, 1 );
	$ui->_draw_pending;
	is scalar @activations, 1, 'the release over the button fires Activate';
	ok !$button->reverse_video, 'the pressed look is gone';
};

subtest 'the pressed look can be a color or nothing' => sub {
	my $colored = Term::Fabulous::Widget::Button->new( background_color => [ 2, 2, 2, 255 ], pressed_background_color => '#ff0000' );
	is $colored->pressed_background_color, [ 255, 0, 0, 255 ], 'a color is stored as rgba';
	is $colored->reverse_video, 0, 'a colored press is not reverse video';

	my $plain = Term::Fabulous::Widget::Button->new( pressed_background_color => undef );
	is $plain->pressed_background_color, undef, 'undef switches the pressed look off';
	is $button->pressed_background_color, 'reverse', 'the default is reverse video';
	is $plain->pressed_background_color('reverse'), 'reverse', 'and can be set back';
	like dies { Term::Fabulous::Widget::Button->new( pressed_background_color => 'nope' ) }, qr/pressed_background_color is not a color/, 'an invalid color dies';
};

subtest 'the focused button draws its border in the focus color' => sub {
	$ui->interaction->set_focused_widget(undef);
	my $config = sub { $button->to_config->{border}{color} };
	is $config->(), [ 5, 5, 5, 255 ], 'unfocused: the border color';
	$ui->interaction->set_focused_widget($button);
	is $config->(), [ 97, 175, 239, 255 ], 'focused: the focus border color';

	$button->focus_border_color('#ffffff');
	is $config->(), [ 255, 255, 255, 255 ], 'in any color format';
	$button->focus_border_color(undef);
	is $config->(), [ 5, 5, 5, 255 ], 'undef switches the focus look off';
	like dies { $button->focus_border_color('nope') }, qr/focus_border_color is not a color/, 'an invalid color dies';
	$ui->interaction->set_focused_widget(undef);
};

subtest 'KDL properties' => sub {
	my $built = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Button as Button
Button "ok" {
	focus_border_color "#ffffff"
	pressed_background_color "#ff0000"
	can_focus #false
}
KDL
	is [ $built->focus_border_color, $built->pressed_background_color, $built->can_focus ], [ [ 255, 255, 255, 255 ], [ 255, 0, 0, 255 ], 0 ], 'all three properties';
};

done_testing;
