use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use Clay::XS qw(sizing_fixed sizing_grow);
use InputTest;
use Scalar::Util qw(refaddr);
use Term::Fabulous;
use Term::Fabulous::Layout;
use Term::Fabulous::Termbox qw(TB_EVENT_KEY TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT TB_KEY_TAB);
use Term::Fabulous::Termbox::Event;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Dialog;

{
	no warnings 'redefine';
	*Term::Fabulous::Render::Target::Termbox::tb_clear   = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_present = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_print   = sub {0};
}

sub button () {
	return Term::Fabulous::Widget::Button->new( background_color => [ 2, 2, 2, 255 ], layout => { sizing => { width => sizing_fixed(4), height => sizing_fixed(1) } } );
}

my $root   = Term::Fabulous::Widget::Box->new( background_color => [ 1, 1, 1, 255 ], layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
my $behind = button();
$root->add_child($behind);
my $ui = Term::Fabulous->new( width => 30, height => 9, root => $root );

my $dialog = Term::Fabulous::Widget::Dialog->new( layout => { sizing => { width => sizing_fixed(12) } } );
my @inside = ( button(), button() );
$dialog->add_child(@inside);
my @closes;
$dialog->on( Close => sub { push @closes, $_[0]->target; return } );

sub dispatch (%fields) {
	$ui->_dispatch_termbox_event( Term::Fabulous::Termbox::Event->new(%fields) );
	return;
}

subtest 'open puts the dialog over the root and focuses inside' => sub {
	$ui->interaction->set_focused_widget($behind);
	$dialog->open($ui);
	ok $dialog->is_open, 'open';
	ref_is $dialog->parent, $dialog->backdrop, 'the dialog sits in its backdrop';
	ref_is $dialog->backdrop->parent, $root, 'which is a child of the root';
	ref_is $ui->interaction->get_focused_widget, $inside[0], 'the first focusable widget inside has the focus';
	ref_is $dialog->open($ui), $dialog, 'opening again is a no-op that returns the dialog';
};

subtest 'Tab stays inside the dialog' => sub {
	dispatch( type => TB_EVENT_KEY, key => TB_KEY_TAB );
	ref_is $ui->interaction->get_focused_widget, $inside[1], 'Tab moves to the next widget inside';
	dispatch( type => TB_EVENT_KEY, key => TB_KEY_TAB );
	ref_is $ui->interaction->get_focused_widget, $inside[0], 'and wraps around inside the dialog';
};

subtest 'the backdrop takes clicks outside the dialog' => sub {
	$ui->draw;
	my @mouse_targets;
	$root->on( Mouse => sub { push @mouse_targets, $_[0]->target; return } );
	dispatch( type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 0 );
	ref_is $mouse_targets[0], $dialog->backdrop, 'the button behind the dialog does not get the click';
	ref_is $ui->interaction->get_focused_widget, $dialog->backdrop, 'the backdrop takes the focus';
	is $dialog->backdrop->layout->{sizing}, { width => sizing_grow(), height => sizing_grow() }, 'the backdrop fills the screen';
};

subtest 'Escape closes and the focus goes back' => sub {
	press( $inside[0], 'Escape' );
	ok !$dialog->is_open, 'closed';
	is $dialog->parent, undef, 'the dialog has no parent any more';
	is scalar( grep { $_->isa('Term::Fabulous::Widget::Dialog::Backdrop') } $root->children->@* ), 0, 'the backdrop is gone from the root';
	ref_is $ui->interaction->get_focused_widget, $behind, 'the focus is back where it was';
	is scalar @closes, 1, 'Close fired once';
	ref_is $closes[0], $dialog, 'on the dialog';
	ref_is $dialog->close, $dialog, 'closing again does nothing';
	is scalar @closes, 1, 'and fires nothing';
};

subtest 'a dialog opens again' => sub {
	$dialog->open($ui);
	ok $dialog->is_open, 'open a second time';
	ref_is $ui->interaction->get_focused_widget, $inside[0], 'with the focus inside';
	$dialog->close_on_escape(0);
	press( $inside[0], 'Escape' );
	ok $dialog->is_open, 'Escape is ignored when close_on_escape is off';
	$dialog->close;
	is scalar @closes, 2, 'close from code fires Close too';
};

subtest 'defaults and errors' => sub {
	is $dialog->border_width, 1, 'a border by default';
	is $dialog->layout->{padding}, { left => 1, right => 1, top => 1, bottom => 1 }, 'padding by default';
	is $dialog->layout->{sizing}{width}, sizing_fixed(12), 'the given layout keys win';
	my $fresh = Term::Fabulous::Widget::Dialog->new;
	is [ $fresh->backdrop_color, $fresh->z_index, $fresh->close_on_escape ], [ [ 0, 0, 0, 128 ], 1000, 1 ], 'the dialog parameters';
	like dies { $dialog->open('nope') }, qr/open needs the Term::Fabulous object/, 'open wants the UI';
	like dies { Term::Fabulous::Widget::Dialog->new( z_index => 'top' ) }, qr/z_index must be an integer/, 'z_index is checked';
	like dies { Term::Fabulous::Widget::Dialog->new( backdrop_color => 'nope' ) }, qr/backdrop_color is not a color/, 'backdrop_color is checked';

	my $child  = Term::Fabulous::Widget::Dialog->new;
	my $holder = Term::Fabulous::Widget::Box->new;
	$holder->add_child($child);
	like dies { $child->open($ui) }, qr/child of another widget cannot open/, 'a dialog inside the tree cannot open';
};

subtest 'KDL properties' => sub {
	my $built = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Dialog as Dialog
Dialog "about" {
	backdrop_color "#000000"
	z_index 7
	close_on_escape #false
}
KDL
	is [ $built->backdrop_color, $built->z_index, $built->close_on_escape ], [ [ 0, 0, 0, 255 ], 7, 0 ], 'all three properties';
};

done_testing;
