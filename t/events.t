use v5.24;
use warnings;

use Test2::V0;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM CLAY_BACK_TO_FRONT CLAY_RENDER_COMMAND_TYPE_RECTANGLE);
use Scalar::Util qw(refaddr);
use Time::HiRes ();
use Term::Fabulous::Termbox qw(
	TB_EVENT_KEY TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_MIDDLE TB_KEY_MOUSE_RIGHT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN TB_KEY_BACK_TAB TB_KEY_ARROW_LEFT
	TF_KEY_MOUSE_MOVE TF_KEY_MOUSE_WHEEL_RIGHT TF_KEY_F13 TF_KEY_KP_LEFT TF_KEY_KP_7 TF_KEY_KP_BEGIN
	TB_MOD_ALT TB_MOD_CTRL TB_MOD_SHIFT TB_MOD_MOTION TF_MOD_SUPER TF_MOD_HYPER TF_MOD_META
);
use Clay::UI::Revision qw(current_revision);
use Term::Fabulous;
use Term::Fabulous::Termbox::Event;
use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Event::Mouse;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Canvas;
use Term::Fabulous::Widget::Checkbox;
use Term::Fabulous::Widget::TextArea;
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
foreach my $name (qw(KeyPress Mouse MouseMove OnPress OnRelease)) {
	$root->on( $name => sub { push @{ $targets{$name} }, $_[0]->target; return } );
}

sub dispatch {
	my ( $target_ui, %fields ) = @_;
	$target_ui->_dispatch_termbox_event( Term::Fabulous::Termbox::Event->new(%fields) );
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

subtest 'a press and a release within one frame both reach Clay' => sub {
	$ui->_draw_pending;
	%targets = ();
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT,    x => 1, y => 1 );
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 2, y => 1 );
	is $ui->pointer_state, { x => 2, y => 1, down => 0 }, 'pointer_state is the newest report';

	$ui->_draw_pending;
	is [ map { refaddr $_ } $targets{OnPress}[0], $targets{OnRelease}[0] ], [ ( refaddr $button ) x 2 ], 'the frame shows the press and then the release';
	is $ui->pointer_state, { x => 2, y => 1, down => 0 }, 'and leaves the newest report as the pointer';
};

subtest 'MouseMove follows the pointer without a button' => sub {
	$ui->_draw_pending;
	%targets = ();
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TF_KEY_MOUSE_MOVE, x => 1, y => 1, mod => TB_MOD_MOTION );
	ref_is $targets{MouseMove}[0], $button, 'MouseMove goes to the widget under the pointer';
	is $targets{Mouse}, undef, 'and is no Mouse event';
	is $ui->pointer_state, { x => 1, y => 1, down => 0 }, 'the pointer position follows the move';
	ok $ui->_frame_is_due( Time::HiRes::time() + 1 ), 'a frame shows the new position to Clay';
	$ui->_draw_pending;
	ok $button->is_hovered, 'so the widget is hovered';
};

subtest 'pointer motion alone gets at most every other slice of time' => sub {
	my ( $seconds, $ended ) = ( 0.05, 1000.05 );
	{
		my $calls = 0;
		no warnings 'redefine';
		local *Time::HiRes::time = sub { $calls++ ? $ended : $ended - $seconds };
		$ui->_draw_pending;    # a frame that took 0.05 s
	}
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TF_KEY_MOUSE_MOVE, x => 5, y => 3, mod => TB_MOD_MOTION );
	ok !$ui->_frame_is_due( $ended + $seconds / 2 ), 'a move waits while less time passed than the last frame took';
	ok $ui->_frame_is_due( $ended + $seconds ),       'and is drawn after that';

	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 5, y => 3 );
	ok $ui->_frame_is_due( $ended + $seconds / 2 ), 'a press does not wait';
	$ui->_draw_pending;
	dispatch( $ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 5, y => 3 );
	ok $ui->_frame_is_due( $ended ), 'nor does a release';
	$ui->_draw_pending;
};

subtest 'frames are drawn only when something changed' => sub {
	$ui->_draw_pending;
	ok !$ui->_frame_is_due, 'nothing changed since the last frame';
	$button->background_color( [ 3, 3, 3, 255 ] );
	ok $ui->_frame_is_due, 'a widget setter makes a frame due';
	$ui->_draw_pending;
	ok !$ui->_frame_is_due, 'and the frame clears it';
	dispatch( $ui, type => TB_EVENT_KEY, ch => ord 'a' );
	ok $ui->_frame_is_due, 'input makes a frame due';
	$ui->_draw_pending;
	ref_is $ui->invalidate, $ui, 'invalidate returns the UI';
	ok $ui->_frame_is_due, 'and makes a frame due';
	$ui->_draw_pending;
	my $revision = current_revision();
	$ui->_draw_pending;
	is current_revision(), $revision, 'drawing an unchanged tree changes nothing';
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

subtest 'a click where stacked buttons overlap goes to the one on top' => sub {
	my $stack   = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_BACK_TO_FRONT } );
	my @buttons = map { Term::Fabulous::Widget::Button->new( background_color => [ $_, $_, $_, 255 ], layout => { sizing => { width => sizing_fixed( 6 - 2 * $_ ), height => sizing_fixed(1) } } ) } 1 .. 2;
	$stack->add_child(@buttons);
	my $stack_ui = Term::Fabulous->new( width => 20, height => 5, root => $stack );
	my ( @pressed, @mouse_targets );
	$_->on( OnPress => sub { push @pressed, $_[0]->target; return } ) foreach @buttons;
	$stack->on( Mouse => sub { push @mouse_targets, $_[0]->target; return } );
	$stack_ui->draw;

	dispatch( $stack_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 0, y => 0 );
	$stack_ui->draw;
	ref_is $mouse_targets[0], $buttons[1], 'Mouse goes to the later child, drawn on top';
	ref_is $stack_ui->interaction->get_focused_widget, $buttons[1], 'the press focuses it';
	is [ map { refaddr $_ } @pressed ], [ refaddr $buttons[1] ], 'and only it is pressed';

	dispatch( $stack_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 0, y => 0 );
	$stack_ui->draw;
	dispatch( $stack_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 3, y => 0 );
	$stack_ui->draw;
	is [ map { refaddr $_ } @pressed[ 1 .. $#pressed ] ], [ refaddr $buttons[0] ], 'the uncovered part of the lower button is still pressable';
};

subtest 'a click where a removed widget was goes to what is left' => sub {
	my $removal_root = Term::Fabulous::Widget::Box->new( background_color => [ 1, 1, 1, 255 ], layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	my $doomed       = Term::Fabulous::Widget::Button->new( background_color => [ 2, 2, 2, 255 ], layout => { sizing => { width => sizing_fixed(4), height => sizing_fixed(2) } } );
	$removal_root->add_child($doomed);
	my $removal_ui = Term::Fabulous->new( width => 20, height => 5, root => $removal_root );
	my @mouse_targets;
	$removal_root->on( Mouse => sub { push @mouse_targets, $_[0]->target; return } );
	$removal_ui->draw;

	$removal_root->clear_children;    # after the frame that still shows the button
	ok lives { dispatch( $removal_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 ) }, 'the click does not die';
	ref_is $mouse_targets[0], $removal_root, 'the Mouse event goes to the widget below it';
	is $removal_ui->interaction->get_focused_widget, undef, 'and nothing is focused';
};

subtest 'only a release of the left button ends a press' => sub {
	my $press_ui = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, ch => TB_KEY_MOUSE_RIGHT, x => 2, y => 1 );
	is $press_ui->pointer_state->{down}, 1, 'a right release keeps the left button down';
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, ch => TB_KEY_MOUSE_LEFT, x => 2, y => 1 );
	is $press_ui->pointer_state->{down}, 0, 'a left release ends it';
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 2, y => 1 );
	is $press_ui->pointer_state->{down}, 0, 'so does a release that names no button';

	my @released;
	$press_ui->root->on( Mouse => sub { push @released, $_[0]->released_button; return } );
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, ch => TB_KEY_MOUSE_MIDDLE, x => 2, y => 1 );
	dispatch( $press_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 2, y => 1 );
	is \@released, [ TB_KEY_MOUSE_MIDDLE, undef ], 'the Mouse event names the released button, and only for a release';
	like dies { Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_LEFT, x => 0, y => 0, released_button => TB_KEY_MOUSE_LEFT ) },
		qr/released_button needs the key TB_KEY_MOUSE_RELEASE/, 'released_button belongs to a release';
	like dies { Term::Fabulous::Event::Mouse->new( key => TB_KEY_MOUSE_RELEASE, x => 0, y => 0, released_button => 42 ) },
		qr/released_button must be TB_KEY_MOUSE_LEFT/, 'and names a button';
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
	is [ $name->( 0, 0x85 )->key_name, $name->( 0, 0x85 )->text ], [ undef, undef ], 'a C1 control character has neither a name nor a text';
};

subtest 'key names of the kitty keyboard protocol' => sub {
	my $name = sub { Term::Fabulous::Event::KeyPress->new( key => $_[0], char => $_[1], modifiers => $_[2] // 0 ) };
	is [ map { $_->key_name } $name->( 0, ord 'i', TB_MOD_CTRL ), $name->( 0, ord '1', TB_MOD_CTRL | TB_MOD_SHIFT ) ], [ 'Ctrl+I', 'Ctrl+Shift+1' ],
		'a Ctrl combination in char is named in upper case';
	is $name->( 0, 0x0D, TB_MOD_CTRL )->key_name, 'Ctrl+Enter', 'a named control key in char takes the Ctrl bit as it is';
	is $name->( 0x17, 0, TB_MOD_CTRL | TB_MOD_SHIFT )->key_name, 'Ctrl+Shift+W', 'Shift with a control byte';
	is $name->( TB_KEY_ARROW_LEFT, 0, TB_MOD_CTRL | TB_MOD_SHIFT | TF_MOD_SUPER | TF_MOD_HYPER | TF_MOD_META )->key_name, 'Ctrl+Shift+Super+Hyper+Meta+Left',
		'Super, Hyper and Meta after Shift';
	is [ $name->( 0, ord 'a', TF_MOD_SUPER )->key_name, $name->( 0, ord 'a', TF_MOD_SUPER )->text ], [ 'Super+a', undef ], 'Super types nothing';
	is $name->( TF_KEY_F13, 0 )->key_name, 'F13', 'keys without a legacy encoding';
	is [ map { [ $_->key_name, $_->main_key_name ] } $name->( TF_KEY_KP_LEFT, 0, TB_MOD_CTRL ), $name->( TF_KEY_KP_7, 0, TB_MOD_ALT ), $name->( TF_KEY_KP_BEGIN, 0 ) ],
		[ [ 'Ctrl+KeypadLeft', 'Ctrl+Left' ], [ 'Alt+Keypad7', 'Alt+7' ], [ 'KeypadBegin', 'KeypadBegin' ] ],
		'main_key_name names the keypad keys after the main keyboard keys';
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
	my @rows = map { Term::Fabulous::Widget::Box->new( background_color => [ $_, $_, $_, 255 ], layout => { sizing => { width => sizing_grow(), height => sizing_fixed(1) } } ) } 10 .. 19;
	$log->add_child($_)         foreach @rows;
	$scroll_root->add_child($_) foreach $header, $log;
	my $scroll_ui = Term::Fabulous->new( width => 20, height => 5, root => $scroll_root );
	my @mouse_targets;
	$scroll_root->on( Mouse => sub { push @mouse_targets, $_[0]->target; return Clay::UI::Enum::Result->CONTINUE } );

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

	$scroll_ui->_draw_pending;
	is $row_top->( $rows[3] ), -1, 'a frame applies the wheel notches reported since the last one';

	my $stop_bubbling = 1;
	$log->on( Mouse => sub { return $stop_bubbling ? () : Clay::UI::Enum::Result->CONTINUE } );
	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_UP, x => 1, y => 3 );
	$scroll_ui->_draw_pending;
	is $row_top->( $rows[3] ), 2, 'a listener that stops the bubbling does not stop the scrolling';
	$stop_bubbling = 0;
	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_DOWN, x => 1, y => 3 );
	$scroll_ui->_draw_pending;

	$log->on( Mouse => sub { $_[0]->use_wheel; return Clay::UI::Enum::Result->CONTINUE } );
	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_DOWN, x => 1, y => 3 );
	$scroll_ui->_draw_pending;
	is $row_top->( $rows[3] ), -1, 'a notch a widget used scrolls no scroll box';

	dispatch( $scroll_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	ref_is $mouse_targets[-1], $header, 'content scrolled out of the box does not take the pointer';

	my $sideways = Term::Fabulous::Widget::ScrollBox->new(
		id         => 'sideways',
		horizontal => 1,
		vertical   => 0,
		layout     => { sizing => { width => sizing_fixed(6), height => sizing_fixed(1) } },
	);
	my @columns = map { Term::Fabulous::Widget::Box->new( background_color => [ $_, $_, $_, 255 ], layout => { sizing => { width => sizing_fixed(2), height => sizing_fixed(1) } } ) } 20 .. 29;
	$sideways->add_child(@columns);
	my $sideways_root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$sideways_root->add_child($sideways);
	my $sideways_ui = Term::Fabulous->new( width => 20, height => 5, root => $sideways_root );
	$sideways_ui->draw;
	dispatch( $sideways_ui, type => TB_EVENT_MOUSE, key => TF_KEY_MOUSE_WHEEL_RIGHT, x => 1, y => 0 );
	$sideways_ui->_draw_pending;
	my ($first) = grep { $_->{commandType} == CLAY_RENDER_COMMAND_TYPE_RECTANGLE && refaddr( $sideways_ui->widget_for( $_->{userData} ) // 0 ) == refaddr( $columns[1] ) } $sideways_ui->get_last_commands;
	is $first->{boundingBox}{x}, -1, 'a horizontal wheel notch scrolls the box under the pointer by three columns';

	like dies { $scroll_ui->draw( scroll_cells => 3 ) }, qr/scroll_cells must be \[columns, rows\]/, 'scroll_cells must be a pair';
	like dies { $scroll_ui->draw( scroll => [ 0, 1 ] ) },  qr/unknown argument\(s\): scroll/,       'unknown draw arguments die';
};

subtest 'a text area in a scroll box passes on the notches it cannot use' => sub {
	my $box  = Term::Fabulous::Widget::ScrollBox->new( id => 'form', layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed(12), height => sizing_fixed(4) } } );
	my $area = Term::Fabulous::Widget::TextArea->new( value => join( "\n", 1 .. 6 ), layout => { sizing => { width => sizing_fixed(12), height => sizing_fixed(3) } } );
	my $rest = Term::Fabulous::Widget::Box->new( background_color => [ 5, 5, 5, 255 ], layout => { sizing => { width => sizing_grow(), height => sizing_fixed(6) } } );
	$box->add_child( $area, $rest );
	my $form_root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$form_root->add_child($box);
	my $form_ui = Term::Fabulous->new( width => 20, height => 5, root => $form_root );
	my $rest_top = sub {
		my ($command) = grep { $_->{commandType} == CLAY_RENDER_COMMAND_TYPE_RECTANGLE && refaddr( $form_ui->widget_for( $_->{userData} ) // 0 ) == refaddr($rest) } $form_ui->get_last_commands;
		return $command->{boundingBox}{y};
	};
	$form_ui->draw;
	is [ $area->top_row, $rest_top->() ], [ 3, 3 ], 'the text area shows its last rows at the top of the box';

	dispatch( $form_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_UP, x => 1, y => 1 );
	$form_ui->_draw_pending;
	is [ $area->top_row, $rest_top->() ], [ 0, 3 ], 'a notch the text area can use scrolls the text area only';

	dispatch( $form_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_DOWN, x => 1, y => 1 );
	$form_ui->_draw_pending;
	is [ $area->top_row, $rest_top->() ], [ 3, 3 ], 'down to its end';
	dispatch( $form_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_WHEEL_DOWN, x => 1, y => 1 );
	$form_ui->_draw_pending;
	is [ $area->top_row, $rest_top->() ], [ 3, 0 ], 'a notch past its end scrolls the box';
};

subtest 'a click within one frame toggles a check box' => sub {
	my $box     = Term::Fabulous::Widget::Checkbox->new( label => 'Fast' );
	my $tap_root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$tap_root->add_child($box);
	my $tap_ui = Term::Fabulous->new( width => 20, height => 5, root => $tap_root );
	$tap_ui->draw;
	dispatch( $tap_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT,    x => 1, y => 0 );
	dispatch( $tap_ui, type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 1, y => 0 );
	$tap_ui->_draw_pending;
	is $box->checked, 1, 'press and release reported before the same frame';
};

subtest 'root must be an event emitter' => sub {
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Text->new ) },
		qr/root must consume Clay::UI::Role::Events::Emitter/, 'a Text root is rejected';
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new, use_termbox => 1 ) },
		qr/Unrecognised parameters.*use_termbox/, 'unknown constructor parameters are rejected';
};

done_testing;
