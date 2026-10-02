use v5.22;
use warnings;

use Test2::V0;

use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM CLAY_RENDER_COMMAND_TYPE_RECTANGLE);
use Scalar::Util qw(refaddr);
use Termbox 2 qw(
	TB_EVENT_KEY TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_DOWN TB_KEY_BACK_TAB TB_KEY_ARROW_LEFT
	TB_MOD_ALT TB_MOD_CTRL TB_MOD_SHIFT TB_MOD_MOTION
);
use Term::Fabulous;
use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Canvas;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

{
	no warnings 'redefine';
	*Term::Fabulous::Render::Target::Termbox::tb_clear            = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_present          = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_print = sub {0};
}

my $root = Term::Fabulous::Widget::Box->new(
	background_color => [ 1, 1, 1, 255 ],
	layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);
my $button = Term::Fabulous::Widget::Button->new(
	background_color => [ 2, 2, 2, 255 ],
	layout           => { sizing => { width => sizing_fixed(4), height => sizing_fixed(2) } },
);
$root->add_child($button);

my $ui = Term::Fabulous->new( width => 20, height => 5, root => $root );

# Handlers on the root see every event through bubbling; record the widget
# each event was fired on.
my %targets;
foreach my $name (qw(KeyPress Mouse OnPress)) {
	$root->on( $name => sub { push @{ $targets{$name} }, $_[0]->target; return } );
}

sub dispatch {
	my ( $target_ui, %fields ) = @_;
	$target_ui->_dispatch_termbox_event( Termbox::Event->new(%fields) );
	return;
}

subtest 'KeyPress targets the focused widget' => sub {
	%targets = ();
	dispatch( $ui, type => TB_EVENT_KEY, ch => ord 'a' );
	ref_is $targets{KeyPress}[0], $root, 'nothing focused: the root';

	$ui->interaction->set_focused_widget($button);
	dispatch( $ui, type => TB_EVENT_KEY, ch => ord 'a' );
	ref_is $targets{KeyPress}[1], $button, 'the focused button';
	$ui->interaction->set_focused_widget(undef);
};

subtest 'Mouse targets the widget under the pointer' => sub {
	$ui->draw;
	%targets = ();
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	ref_is $targets{Mouse}[0], $button, 'inside the button';
	is $ui->pointer_state, { x => 1, y => 1, down => 1 }, 'left press sets the pointer down';

	$ui->draw;
	ref_is $targets{OnPress}[0], $button, 'draw hands the pointer to Clay: the button is pressed';

	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 10, y => 3 );
	ref_is $targets{Mouse}[1], $root, 'outside the button: the root';
	is $ui->pointer_state->{down}, 0, 'release clears the pointer';
};

subtest 'Mouse targets a canvas without a background' => sub {
	my $canvas_root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	my $canvas      = Term::Fabulous::Widget::Canvas->new( layout => { sizing => { width => sizing_fixed(4), height => sizing_fixed(2) } } );
	$canvas_root->add_child($canvas);
	my $canvas_ui = Term::Fabulous->new( width => 20, height => 5, root => $canvas_root );
	my @mouse_targets;
	$canvas_root->on( Mouse => sub { push @mouse_targets, $_[0]->target; return } );

	$canvas_ui->draw;
	dispatch( $canvas_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 3, y => 1 );
	ref_is $mouse_targets[0], $canvas, 'the canvas paints its box';
};

subtest 'a left press focuses the widget under the pointer' => sub {
	my $focus_root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
	my @buttons    = map { Term::Fabulous::Widget::Button->new( background_color => [ $_, $_, $_, 255 ], layout => { sizing => { width => sizing_fixed(4), height => sizing_fixed(1) } } ) } 1 .. 2;
	my $inner = Term::Fabulous::Widget::Box->new( background_color => [ 9, 9, 9, 255 ], layout => { sizing => { width => sizing_fixed(2), height => sizing_fixed(1) } } );
	$buttons[1]->add_child($inner);
	$focus_root->add_child(@buttons);
	my $focus_ui = Term::Fabulous->new( width => 20, height => 5, root => $focus_root );
	my @focused_at_mouse;
	$focus_root->on( Mouse => sub { push @focused_at_mouse, $focus_ui->interaction->get_focused_widget; return } );
	$focus_ui->draw;

	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 0 );
	ref_is $focused_at_mouse[0], $buttons[0], 'the button is focused before the Mouse event';
	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 0, y => 1 );
	ref_is $focus_ui->interaction->get_focused_widget, $buttons[1], 'a press on a child focuses its focusable ancestor';
	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 0, mod => TB_MOD_MOTION );
	ref_is $focus_ui->interaction->get_focused_widget, $buttons[1], 'dragging does not move the focus';
	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 10, y => 3 );
	is $focus_ui->interaction->get_focused_widget, undef, 'a press on nothing focusable blurs';

	my @pressed;
	$_->on( OnPress => sub { push @pressed, $_[0]->target; return } ) foreach @buttons;
	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 1, y => 1 );
	$focus_ui->draw;
	dispatch( $focus_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 3, y => 1 );
	$focus_ui->draw;
	is [ map { refaddr $_ } @pressed ], [ refaddr $buttons[1] ], 'Clay hit-tests the cell, not the edge it shares with the widget above';
};

subtest 'key names' => sub {
	my $name = sub { Term::Fabulous::Event::KeyPress->new( key => $_[0], char => $_[1], modifiers => $_[2] // 0 ) };
	is $name->( 0, ord 'a' )->key_name, 'a', 'a character';
	is [ $name->( 0, ord 'a' )->text, $name->( 0, ord 'a', TB_MOD_ALT )->text ], [ 'a', undef ], 'text without Ctrl or Alt only';
	is $name->( TB_KEY_ARROW_LEFT, 0, TB_MOD_CTRL | TB_MOD_SHIFT )->key_name, 'Ctrl+Shift+Left', 'modifiers in a fixed order';
	is $name->( 0x17, 0 )->key_name, 'Ctrl+W', 'a control byte is Ctrl and a letter';
	is [ map { $name->( $_, 0, TB_MOD_CTRL )->key_name } 0x7F, 0x0D, 0x1B, 0x09 ], [qw(Backspace Enter Escape Tab)],
		'named control keys, without the Ctrl bit termbox2 sets on them';
	is [ $name->( 0x20, 0 )->key_name, $name->( 0, 0x20 )->key_name, $name->( 0x20, 0 )->text ], [ 'Space', 'Space', ' ' ], 'Space either way';
};

subtest 'Tab and Shift-Tab move focus' => sub {
	my $focus_root = Term::Fabulous::Widget::Box->new;
	my @buttons    = map { Term::Fabulous::Widget::Button->new } 1 .. 2;
	$focus_root->add_child($_) foreach @buttons;
	my $focus_ui = Term::Fabulous->new( width => 20, height => 5, root => $focus_root );
	my @key_targets;
	$focus_root->on( KeyPress => sub { push @key_targets, $_[0]->target; return } );

	dispatch( $focus_ui, type => TB_EVENT_KEY, key => 0x09 );
	ref_is $key_targets[0], $focus_root, 'the KeyPress goes to the widget focused before the move';
	ref_is $focus_ui->interaction->get_focused_widget, $buttons[0], 'Tab focuses the first button';

	dispatch( $focus_ui, type => TB_EVENT_KEY, key => 0x09 );
	ref_is $focus_ui->interaction->get_focused_widget, $buttons[1], 'Tab moves to the next button';

	dispatch( $focus_ui, type => TB_EVENT_KEY, key => TB_KEY_BACK_TAB );
	ref_is $focus_ui->interaction->get_focused_widget, $buttons[0], 'Shift-Tab moves back';
	is scalar @key_targets, 3, 'every Tab still fires a KeyPress';
};

subtest 'scroll boxes' => sub {
	my $scroll_root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
	my $header = Term::Fabulous::Widget::Box->new( background_color => [ 3, 3, 3, 255 ], layout => { sizing => { width => sizing_fixed(6), height => sizing_fixed(2) } } );
	my $log    = Term::Fabulous::Widget::ScrollBox->new(
		id     => 'log',
		layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed(6), height => sizing_fixed(3) } },
	);
	my @rows = map { Term::Fabulous::Widget::Box->new( background_color => [ $_, $_, $_, 255 ], layout => { sizing => { width => sizing_grow(), height => sizing_fixed(1) } } ) } 10 .. 15;
	$log->add_child($_)         foreach @rows;
	$scroll_root->add_child($_) foreach $header, $log;
	my $scroll_ui = Term::Fabulous->new( width => 20, height => 5, root => $scroll_root );
	my @mouse_targets;
	$scroll_root->on( Mouse => sub { push @mouse_targets, $_[0]->target; return } );

	my $row_top = sub {
		my ($row) = @_;
		my ($command) = grep { $_->{commandType} == CLAY_RENDER_COMMAND_TYPE_RECTANGLE && refaddr( $scroll_ui->widget_for( $_->{userData} ) // 0 ) == refaddr($row) }
			$scroll_ui->get_last_commands;
		return $command->{boundingBox}{y};
	};

	$scroll_ui->draw;
	is $row_top->( $rows[0] ), 2, 'the first row starts at the top of the box';

	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_DOWN, x => 1, y => 3 );
	$scroll_ui->draw( scroll_cells => [ 0, -3 ] );
	is $row_top->( $rows[3] ), 2, 'scroll_cells scrolls the box under the pointer by whole rows';

	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	ref_is $mouse_targets[-1], $header, 'content scrolled out of the box does not take the pointer';

	like dies { $scroll_ui->draw( scroll_cells => 3 ) }, qr/scroll_cells must be \[columns, rows\]/, 'scroll_cells must be a pair';
	like dies { $scroll_ui->draw( scroll => [ 0, 1 ] ) },  qr/unknown argument\(s\): scroll/,       'unknown draw arguments die';
};

subtest 'root must be an event emitter' => sub {
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Text->new ) },
		qr/root must consume Clay::UI::Role::Events::Emitter/, 'a Text root is rejected';
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new, use_termbox => 1 ) },
		qr/Unrecognised parameters.*use_termbox/, 'unknown constructor parameters are rejected';
};

done_testing;
