package Term::Fabulous;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI;
use Term::Fabulous::Render;
use Term::Fabulous::Terminal::Termbox;

class Term::Fabulous
	:isa(Clay::UI)
	:does(Term::Fabulous::Render)
	:strict(params)
{
	use Clay::UI::Revision qw(current_revision);
	use Feature::Compat::Try;
	use IO::Async::Handle;
	use IO::Async::Loop;
	use IO::Async::Signal;
	use IO::Async::Timer::Countdown;
	use IO::Async::Timer::Periodic;
	use List::Util qw(any);
	use Scalar::Util qw(blessed looks_like_number refaddr);
	use Time::HiRes ();
	use Term::Fabulous::Termbox qw(
		TB_EVENT_KEY TB_EVENT_MOUSE TB_EVENT_RESIZE
		TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN
		TF_KEY_MOUSE_MOVE TF_KEY_MOUSE_WHEEL_LEFT TF_KEY_MOUSE_WHEEL_RIGHT
		TB_KEY_CTRL_C TB_KEY_TAB TB_KEY_BACK_TAB TB_MOD_MOTION
	);
	use Term::Fabulous::Event::KeyPress;
	use Term::Fabulous::Event::Mouse;
	use Term::Fabulous::Event::MouseMove;
	use Term::Fabulous::Event::Resize;
	use Term::Fabulous::Event::Start;
	use Term::Fabulous::Unicode qw(terminal_is_utf8);

	use constant WATCHED_SIGNALS     => qw(TERM INT HUP);
	use constant WHEEL_NOTCH_ROWS    => 3;
	use constant WHEEL_NOTCH_COLUMNS => 3;

	# step draws until no frame is due; a tree that changes again in every
	# frame would never settle.
	use constant MAX_FRAME_BATCHES_PER_STEP => 100;

	field $inline :param :reader = undef;    # the rows of the inline region, or undef for the full screen
	field $mouse :param :reader  = undef;
	field $kitty_keyboard :param :reader = 1;
	field $terminal :param :reader //= Term::Fabulous::Terminal::Termbox->new;
	field $clock :param = sub { Time::HiRes::time() };
	field $loop :reader;
	field $termbox_draw_interval :reader            = 1 / 30;
	field $termbox_resize_debounce_interval :reader = 1 / 10;

	field $_running = 0;    # whether run's loop is active
	field @_notifiers;
	field $_resize_timer;
	field $_draw_timer;
	field %_signals_before;    # the caller's %SIG entries for the signals run watches
	field $_pending_resize;
	field $_pointer;             # the pointer state as last reported
	field @_pointer_queue;       # pointer states no frame has shown to Clay yet
	field $_wheel_rows    = 0;   # wheel scrolling since the last frame
	field $_wheel_columns = 0;
	field $_frame_requested = 1;    # invalidate() or input since the last frame
	field $_frame_due_at;           # the earliest time a widget asked for a frame at, on the clock
	field $_drawn_revision  = -1;   # the Clay::UI revision the last frame showed
	field $_shown_down      = 0;    # the button state the last frame showed Clay
	field $_frame_seconds   = 0;    # how long the last frame took to draw
	field $_frame_ended_at  = 0;    # when it was drawn, on the clock

	sub BUILDARGS ( $class, %params ) {
		die "Term::Fabulous: measure_text cannot be replaced; text is always measured in terminal columns" if exists $params{measure_text};
		return %params;
	}

	ADJUST {
		die "Term::Fabulous: root must consume Clay::UI::Role::Events::Emitter to receive input events, got " . ref( $self->root )
			unless $self->root->DOES('Clay::UI::Role::Events::Emitter');
	}

	ADJUST {
		die "Term::Fabulous: inline must be a whole number of rows of at least 1, got '$inline'"
			if defined $inline && $inline !~ /\A[1-9][0-9]*\z/;
		die "Term::Fabulous: inline mode has no mouse support; leave out mouse or pass mouse => 0"
			if defined $inline && $mouse;
		$mouse //= defined $inline ? 0 : 1;
		die "Term::Fabulous: terminal must consume Term::Fabulous::Role::Terminal, got " . ( ref $terminal || "'$terminal'" )
			unless blessed $terminal && $terminal->DOES('Term::Fabulous::Role::Terminal');
		die "Term::Fabulous: clock must be a code reference, got " . ( defined $clock ? "'$clock'" : 'undef' )
			unless ref $clock eq 'CODE';
	}

	method cell_target () {
		return $terminal->cell_target;
	}

	method kitty_keyboard_active () {
		return $terminal->kitty_keyboard_active;
	}

	method pointer_state () {
		return undef unless defined $_pointer;
		return {%$_pointer};
	}

	method invalidate () {
		$_frame_requested = 1;
		return $self;
	}

	method now () {
		return $clock->();
	}

	# A frame is due at the earliest of the times asked for; the request is
	# forgotten when a frame is drawn, so an animation asks again from it.
	method request_frame_at ($time) {
		die "Term::Fabulous: request_frame_at needs a time in seconds, got " . ( defined $time ? "'$time'" : 'undef' )
			unless defined $time && !ref $time && looks_like_number($time);
		$_frame_due_at = $time if !defined $_frame_due_at || $time < $_frame_due_at;
		return $self;
	}

	method find_by_id ($id) {
		my $root = $self->root;
		die "Term::Fabulous: the root widget " . ref($root) . " cannot search by id (no find_by_id method)" unless $root->can('find_by_id');
		return $root->find_by_id($id);
	}

	method run () {
		warn "Term::Fabulous: the locale's character set is not UTF-8; wide characters will be misaligned\n"
			unless terminal_is_utf8();

		my $opened = $self->_open_terminal;
		try {
			$loop = IO::Async::Loop->new;
			$self->_attach_notifiers;
			$_running = 1;
			$loop->later( sub { $self->_start($opened) } );
			$loop->run;

			# The frame that stays on the screen shows the final state; frames
			# start after Start, with the frame timer.
			$self->_draw_frame if defined $inline && $_draw_timer->is_running;
		}
		catch ($error) {
			# Perl reports an uncaught exception before unwinding into
			# finally; restore the terminal first so the message stays visible.
			$self->_end_run;
			die $error;
		}
		finally {
			$self->_end_run;    # also runs when an event handler calls exit()
		}
		return;
	}

	method step (%options) {
		my @unknown = grep { $_ ne 'paced' } sort keys %options;
		die "Term::Fabulous: step does not accept @unknown (known options: paced)" if @unknown;
		die "Term::Fabulous: step cannot be called while run is active; run reads the input and draws by itself" if $_running;

		$self->_fire_start if $self->_open_terminal;
		$self->_read_input;
		$self->_apply_resize;

		my $frames = 0;
		foreach my $batch ( 1 .. MAX_FRAME_BATCHES_PER_STEP ) {
			return $frames unless $self->_frame_is_due( $options{paced} );
			$frames += $self->_draw_pending;
		}
		die "Term::Fabulous: step drew " . MAX_FRAME_BATCHES_PER_STEP . " rounds of frames and another frame is still due; a widget changes in every frame\n";
	}

	# Returns 1 when it opened the terminal, 0 when it was open already.
	method _open_terminal () {
		return 0 if $terminal->is_open;
		$terminal->open( inline => $inline, mouse => $mouse, kitty_keyboard => $kitty_keyboard );
		$self->invalidate_canvases;    # a fresh screen holds no canvas cells
		my ( $width, $height ) = $terminal->size;
		$self->width($width);
		$self->height($height);
		return 1;
	}

	method _end_run () {
		$_running = 0;
		$self->_detach_notifiers;
		$terminal->close;
		return;
	}

	method _stop_run () {
		$loop->stop if $_running;
		return;
	}

	# Signals and timers; the terminal input is watched from _start on.
	method _attach_notifiers () {
		my $stop = sub { $loop->stop };

		$_resize_timer = IO::Async::Timer::Countdown->new(
			delay     => $termbox_resize_debounce_interval,
			on_expire => sub { $self->_apply_resize },
		);
		$_draw_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_draw_interval,
			on_tick  => sub { $self->_draw_frame },
		);

		%_signals_before = map { $_ => $SIG{$_} } WATCHED_SIGNALS;
		$self->_add_notifiers(
			( map { IO::Async::Signal->new( name => $_, on_receipt => $stop ) } WATCHED_SIGNALS ),
			$_resize_timer,
			$_draw_timer,
		);
		return;
	}

	method _add_notifiers (@notifiers) {
		push @_notifiers, @notifiers;
		$loop->add($_) foreach @notifiers;
		return;
	}

	# Start fires from inside the running loop, so its listeners can use
	# $ui->loop (add notifiers, stop it); frames are drawn and input is
	# read only after it. A terminal step opened has had its Start.
	method _start ($opened) {
		$self->_fire_start if $opened;
		$_draw_timer->start;
		$self->_watch_terminal_input;
		$self->_read_input if defined $inline || $kitty_keyboard;    # keys the terminal queries read ahead
		return;
	}

	method _fire_start () {
		$self->root->fire_event( Term::Fabulous::Event::Start->new( width => $self->width, height => $self->height ) );
		return;
	}

	method _watch_terminal_input () {
		my @input_watchers = map { IO::Async::Handle->new( read_handle => $_, on_read_ready => sub { $self->_read_input } ) } $terminal->read_handles;
		$self->_add_notifiers(@input_watchers);

		# IO::Async switches watched handles to non-blocking mode. A handle
		# may share that flag with the terminal's own descriptor (termbox
		# gives up on a partial write() of a frame), so switch them back.
		# Readiness notification does not depend on the flag, and nothing
		# here reads from these handles.
		foreach my $watcher (@input_watchers) {
			defined $watcher->read_handle->blocking(1)
				or die "Term::Fabulous: cannot restore blocking mode on a terminal descriptor: $!\n";
		}
		return;
	}

	method _detach_notifiers () {
		foreach my $notifier (@_notifiers) {
			my $owner = $notifier->loop;
			$owner->remove($notifier) if defined $owner;
		}
		$self->_restore_signal_handlers;
		@_notifiers       = ();
		$_resize_timer    = undef;
		$_draw_timer      = undef;
		$_pending_resize  = undef;
		$_wheel_rows      = 0;
		$_wheel_columns   = 0;
		@_pointer_queue   = ();
		$_frame_requested = 1;    # the next run starts with a frame
		return;
	}

	# IO::Async resets a signal it stops watching to the default action;
	# the caller's handler comes back, unless another watcher (one the
	# program added to the loop) keeps IO::Async's handler in place.
	method _restore_signal_handlers () {
		foreach my $name ( keys %_signals_before ) {
			$SIG{$name} = $_signals_before{$name} unless defined $SIG{$name};
		}
		%_signals_before = ();
		return;
	}

	# One tick of the frame timer.
	method _draw_frame () {
		return if $_resize_timer->is_running;
		$self->_draw_pending if $self->_frame_is_due(1);
		return;
	}

	# A frame is due when something asked for one (invalidate, a key, a
	# click, a resize), when wheel input or a button press or release waits
	# to be shown to Clay, or when a widget changed since the last frame
	# (the Clay::UI revision). Paced, pointer motion alone gets at most
	# every other slice of time: when frames are slow, moving the mouse
	# must not keep the loop busy with nothing but redrawing.
	method _frame_is_due ($paced) {
		return 1 if $_frame_requested || $_wheel_rows || $_wheel_columns;
		return 1 if current_revision() != $_drawn_revision;
		return 1 if defined $_frame_due_at && $clock->() >= $_frame_due_at;
		return 0 unless @_pointer_queue;
		return 1 if !$paced || any { $_->{down} != $_shown_down } @_pointer_queue;
		return $clock->() - $_frame_ended_at >= $_frame_seconds ? 1 : 0;
	}

	# Clay takes one button state per frame, so every queued pointer state
	# gets a frame of its own; the wheel movement goes with the first. A
	# frame shows the revision its layout pass started at (changes the
	# frame's own events and preparations made included); a change after
	# it (an after_draw callback, say) leaves the next frame due. Returns
	# the number of frames drawn.
	method _draw_pending () {
		my @pointers = splice @_pointer_queue;
		push @pointers, $_pointer unless @pointers;
		my ( $columns, $rows ) = ( $_wheel_columns, $_wheel_rows );
		( $_wheel_columns, $_wheel_rows ) = ( 0, 0 );
		$_frame_requested = 0;
		$_frame_due_at    = undef;

		my $started = $clock->();
		foreach my $pointer (@pointers) {
			$_pointer    = $pointer;
			$_shown_down = defined $pointer ? $pointer->{down} : 0;
			$self->draw( scroll_cells => [ $columns, $rows ] );
			$_drawn_revision = $self->laid_out_revision;
			( $columns, $rows ) = ( 0, 0 );
		}
		$_frame_ended_at = $clock->();
		$_frame_seconds  = $_frame_ended_at - $started;
		return scalar @pointers;
	}

	method _read_input () {
		while ( defined( my $event = $terminal->next_event ) ) {
			$self->_dispatch_event($event);
		}
		die "Term::Fabulous: the terminal was closed (end of input)\n" if $terminal->input_ended;
		return;
	}

	method _dispatch_event ($event) {
		my $type = $event->type;
		return $self->_on_key($event)    if $type == TB_EVENT_KEY;
		return $self->_on_mouse($event)  if $type == TB_EVENT_MOUSE;
		return $self->_on_resize($event) if $type == TB_EVENT_RESIZE;
		die "Term::Fabulous: unknown terminal event type '$type'";
	}

	method _on_key ($event) {
		$_frame_requested = 1;    # listeners may change anything
		my $target = $self->interaction->get_focused_widget // $self->root;
		$target->fire_event( Term::Fabulous::Event::KeyPress->of($event) );

		my ( $key, $is_special_key ) = ( $event->key, $event->ch == 0 );
		$self->_stop_run                   if $is_special_key && $key == TB_KEY_CTRL_C;
		$self->interaction->focus_next     if $is_special_key && $key == TB_KEY_TAB;
		$self->interaction->focus_previous if $is_special_key && $key == TB_KEY_BACK_TAB;
		return;
	}


	# The pointer motion a MouseMove reports makes no frame due by itself
	# (see _frame_is_due); listeners that change a widget make one due.
	method _on_mouse ($event) {
		my ( $x, $y, $key ) = ( $event->x, $event->y, $event->key );
		my $newest = @_pointer_queue ? $_pointer_queue[-1] : $_pointer;
		my $down
			= $key == TB_KEY_MOUSE_LEFT ? 1
			: _releases_left_button($event) ? 0
			:                                 ( defined $newest ? $newest->{down} : 0 );
		$_pointer = { x => $x, y => $y, down => $down };
		$self->_queue_pointer($_pointer);

		my $target = $self->_emitter_at( $x, $y ) // $self->root;
		if ( $key == TF_KEY_MOUSE_MOVE ) {
			$target->fire_event( Term::Fabulous::Event::MouseMove->of($event) );
			return;
		}

		$_frame_requested = 1;    # listeners may change anything
		$self->interaction->set_focused_widget( $self->_focusable_at_or_above($target) )
			if $key == TB_KEY_MOUSE_LEFT && !( $event->mod & TB_MOD_MOTION );
		my $mouse_event = Term::Fabulous::Event::Mouse->of($event);
		$target->fire_event($mouse_event);

		# A widget that scrolled itself has used the wheel notch.
		return if $mouse_event->wheel_used;
		$_wheel_rows    += WHEEL_NOTCH_ROWS    if $key == TB_KEY_MOUSE_WHEEL_UP;
		$_wheel_rows    -= WHEEL_NOTCH_ROWS    if $key == TB_KEY_MOUSE_WHEEL_DOWN;
		$_wheel_columns += WHEEL_NOTCH_COLUMNS if $key == TF_KEY_MOUSE_WHEEL_LEFT;
		$_wheel_columns -= WHEEL_NOTCH_COLUMNS if $key == TF_KEY_MOUSE_WHEEL_RIGHT;
		return;
	}

	# Motion replaces the newest queued state; a press or a release adds
	# one, so a press and a release within the same frame are both shown
	# to Clay.
	method _queue_pointer ($pointer) {
		if ( @_pointer_queue && $_pointer_queue[-1]{down} == $pointer->{down} ) {
			$_pointer_queue[-1] = $pointer;
			return;
		}
		push @_pointer_queue, $pointer;
		return;
	}

	# A release whose button the terminal did not name counts as the left.
	sub _releases_left_button ($event) {
		return 0 unless $event->key == TB_KEY_MOUSE_RELEASE;
		my $button = $event->ch;
		return $button == 0 || $button == TB_KEY_MOUSE_LEFT ? 1 : 0;
	}

	# The widget a click focuses: the nearest one that can take focus now.
	method _focusable_at_or_above ($widget) {
		my $interaction = $self->interaction;
		for ( my $node = $widget; defined $node; $node = $node->parent ) {
			return $node if $interaction->can_take_focus($node);
		}
		return undef;
	}

	method _on_resize ($event) {
		my ( $width, $height ) = ( $event->w, $event->h );
		return if $width < 1 || $height < 1;

		# termbox has already rebuilt its buffers for the new size, keeping
		# only the cells inside both sizes: no canvas is intact any more,
		# even when the size ends up where it was.
		$self->invalidate_canvases;
		$_pending_resize = [ $width, $height ];
		return unless defined $_resize_timer;    # step applies it at once
		$_resize_timer->is_running ? $_resize_timer->reset : $_resize_timer->start;
		return;
	}

	method _apply_resize () {
		return unless defined $_pending_resize;
		my ( $width, $height ) = $terminal->apply_resize(@$_pending_resize);
		$_pending_resize = undef;

		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 0 ) );
		$self->width($width);
		$self->height($height);
		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 1 ) );
		$_frame_requested = 1;
		$self->_read_input if defined $inline;    # keys the cursor position query read ahead
		return;
	}

	# Topmost event emitter painted at the cell in the last frame that is
	# still part of this UI: a listener may have removed it since.
	method _emitter_at ( $x, $y ) {
		my $frame = $self->last_frame;
		foreach my $index ( $frame->topmost_at( $x, $y ) ) {
			my $widget = $self->widget_for( $frame->command($index)->{userData} );
			return $widget if defined $widget && $widget->DOES('Clay::UI::Role::Events::Emitter') && $self->_owns($widget);
		}
		return undef;
	}

	method _owns ($widget) {
		my $ui = $widget->can('ui') ? $widget->ui : undef;
		return defined $ui && refaddr($ui) == refaddr($self) ? 1 : 0;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous - Full-screen terminal user interfaces with layouts,
widgets, keyboard and mouse

=head1 SYNOPSIS

	use v5.24;
	use warnings;
	use feature 'signatures';
	no warnings 'experimental::signatures';

	use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
	use Term::Fabulous;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Widget::TextField;

	my $root = Term::Fabulous::Widget::Box->new(
		background_color => [ 20, 25, 35, 255 ],
		layout           => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_grow() },
			padding          => { left => 2, right => 2, top => 1, bottom => 1 },
			child_gap        => 1,
		},
	);

	my $greeting = Term::Fabulous::Widget::Text->new(
		text       => 'What is your name? (Enter to greet, Ctrl+C to quit)',
		text_color => [ 230, 230, 230, 255 ],
	);
	my $name = Term::Fabulous::Widget::TextField->new( placeholder => 'Your name' );
	$root->add_child( $greeting, $name );

	$name->on(
		Submit => sub ($event) {
			$greeting->text( 'Hello, ' . $event->value . '!' );
			return;
		}
	);

	my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
	$ui->interaction->set_focused_widget($name);
	$ui->run;    # returns after Ctrl+C, SIGINT, SIGTERM or SIGHUP

The picture shows F<examples/showcase.pl>, a demo program of the
distribution (see L<Term::Fabulous::Examples>):

=begin html

<p><img src="/screenshots/overview.svg" alt="A Term::Fabulous program: a sign-up form with text fields, radio buttons, a dropdown, a slider, a check box and buttons, a chart of requests per second with a translucent notification, an event log and text in several scripts"></p>

=end html

=head1 DESCRIPTION

Term::Fabulous builds full-screen terminal applications in Perl. You
describe the screen as a tree of widgets (boxes, text, buttons, input
fields, tables, charts, scrollable areas and canvases), in Perl code or
in a layout file written in KDL, a small configuration language
(L<https://kdl.dev>).
Term::Fabulous sizes and positions the widgets with the Clay layout
engine, draws them with 24-bit colors through the termbox2 library, and
turns key presses, mouse clicks and terminal resizes into events your
code reacts to.

Highlights:

=over

=item *

Flexible layout: rows and columns, growing, fitting, fixed and
percentage sizes, padding, gaps, alignment, borders in 20 styles.

=item *

Input widgets for forms: single- and multi-line text with selection,
undo and a clipboard shared by all text fields of the program; check
boxes; radio buttons; dropdowns; sliders; star ratings; segmented
controls.

=item *

A table widget for rows of data: sorting by one or several columns,
filtering (also by the user, in a filter row), groups and trees that
open and close, pages, single and multiple selection, any widget as a
cell, and lines and colors per column, row and cell.

=item *

Chart widgets that draw themselves from data: line, area, bar and
scatter charts with category, numeric, logarithmic and time axes,
stacking, curves, transforms and live data; histograms; sparklines;
pie, donut, polar area and radar charts; a legend, hover with a
C<SeriesHover> event, and palettes for dark and light backgrounds.

=item *

Keyboard focus with Tab and mouse clicks, readable key names for key
bindings (C<Ctrl+S>, C<Shift+Left>), the kitty keyboard protocol for
keys older terminals cannot tell apart, mouse wheel scrolling.

=item *

Dialogs that open over the screen and keep the keyboard focus inside.

=item *

Dividers between widgets, horizontal or vertical, with a text on the
line; accordions whose sections open and close under their headers.

=item *

Progress bars in several styles, with labels, stripes, stacked
segments and an indeterminate runner, and spinners in twelve styles,
animated on the application's clock without timers; toasts that
appear in a corner and go away by themselves.

=item *

Canvases for free drawing, including a half-block pixel canvas with
lines, rectangles and circles.

=item *

Correct handling of Unicode: wide CJK characters, emoji, combining
characters.

=item *

A prompt of a few rows below the shell's output instead of the whole
screen (L</INLINE MODE>).

=item *

The same widget tree can be printed once as text (with or without
colors) for reports and tests, through L<Term::Fabulous::Static>.

=item *

Whole programs can be tested without a terminal: a terminal in memory
(L<Term::Fabulous::Terminal::Memory>) takes keys, clicks and resizes,
and L</step> handles them as L</run> would.

=item *

Runs on L<IO::Async>, so timers, sockets and child processes work
alongside the user interface.

=back

This class is the application object: it owns the widget tree, opens the
terminal, runs the event loop, draws a frame whenever something changed
(checking 30 times per second) and dispatches input events. It is a
subclass of L<Clay::UI>. It reaches the terminal through a I<terminal>
object (L<Term::Fabulous::Role::Terminal>): the real one by default, or
L<Term::Fabulous::Terminal::Memory> in tests, which L</step> drives
without an event loop.

=head1 DOCUMENTATION

The documentation has four parts. If you are new to Term::Fabulous,
start with the manual's first page and its first program.

=over

=item The manual: L<Term::Fabulous::Manual>

The user guide. Its first page introduces the library, shows a first
program, lists the topic pages and ends with a
L<FEATURE INDEX|Term::Fabulous::Manual/FEATURE INDEX> that maps tasks
to the sections, recipes and class pages that describe them. The topic
pages explain the concepts, with examples throughout:
L<Term::Fabulous::Manual::Layout> (widgets, the widget tree and
layout), L<Term::Fabulous::Manual::Looks> (text, colors, borders),
L<Term::Fabulous::Manual::Events> (events, keyboard, focus, mouse,
scrolling), L<Term::Fabulous::Manual::Forms> (input widgets),
L<Term::Fabulous::Manual::Feedback> (progress bars, spinners and
toasts), L<Term::Fabulous::Manual::Charts> (canvases and charts),
L<Term::Fabulous::Manual::Tables>, L<Term::Fabulous::Manual::TableRows>
and L<Term::Fabulous::Manual::TableStyles> (the table widget),
L<Term::Fabulous::Manual::KDL> (layout files),
L<Term::Fabulous::Manual::Programs> (event loop, output without a
terminal, testing), L<Term::Fabulous::Manual::CustomWidgets>,
L<Term::Fabulous::Manual::Troubleshooting> and
L<Term::Fabulous::Manual::Glossary>.

=item The cookbook: L<Term::Fabulous::Cookbook>

Recipes: complete, runnable programs for common tasks, each with a
picture and notes on the lines that matter. Its first page lists every
recipe; the recipes are on topic pages such as
L<Term::Fabulous::Cookbook::GettingStarted>,
L<Term::Fabulous::Cookbook::Forms>, L<Term::Fabulous::Cookbook::Tables>
and L<Term::Fabulous::Cookbook::Charts>.

=item The examples: L<Term::Fabulous::Examples>

The example programs of the distribution, with a picture of each: demo
programs, a gallery with one program per widget, and the complete
programs of the cookbook.

=item The class pages

One reference page per class, listed by purpose under L</MODULES>.
This page is the reference of the application object: L</new>,
L</run>, L</step> and the other methods, the events it fires, the keys
it handles itself, inline mode and wheel scrolling.

=back

=head1 REQUIREMENTS

Perl 5.24 or later, a C compiler to build L<Term::Fabulous::Termbox>
(termbox2 is compiled into the distribution), a terminal with 24-bit
colors and a UTF-8 locale. See L<Term::Fabulous::Manual/REQUIREMENTS>.

=head1 CONSTRUCTOR

=head2 new

	my $ui = Term::Fabulous->new(
		root   => $root_widget,
		width  => 80,
		height => 24,
		mouse  => 1,
	);

Creates the application object. The terminal is not touched until
L</run> (or L</step>), so you can create the object, set the focus and
add timers first. Unknown parameters die
(C<Unrecognised parameters for Term::Fabulous constructor: 'colour'>).

=over

=item C<root>

Required. The root widget, the top of the widget tree, usually a
L<Term::Fabulous::Widget::Box>. It receives every event that no other
widget receives: key presses while nothing has the focus, mouse events
where no widget is drawn, and every C<Start> and C<Resize>. It must
therefore be able to fire events (compose
L<Clay::UI::Role::Events::Emitter>, as all Term::Fabulous widgets
except Text do); otherwise C<new> dies
(C<Term::Fabulous: root must consume Clay::UI::Role::Events::Emitter to receive input events, got ...>).
The root must not have a parent (C<new> dies with
C<Clay::UI: 'root' must not have a parent; ...>); a widget that was
removed from its parent can be a root. A widget tree belongs to one
application object (or L<Term::Fabulous::Static>) at a time: a second
object with the same root dies with
C<Clay::UI: 'root' is already the root of another Clay::UI>, as long as
the first one exists.

=item C<width>

Required. A positive number: the width of the layout in columns until
the terminal is opened (L</run> or L</step>). It is then replaced with
the terminal's width, and kept up to date when the terminal is resized.

=item C<height>

Required. A positive number: the height of the layout in rows until
the terminal is opened, then the terminal's height (in inline mode, the
rows of the inline region).

=item C<inline>

Optional. A whole number of rows, at least 1, or C<undef>, the default.
With a number, L</run> does not take over the screen: the user
interface is drawn into that many rows below the shell's output and
stays there when C<run> returns, like a prompt. See L</INLINE MODE>.
Anything else dies
(C<Term::Fabulous: inline must be a whole number of rows of at least 1, got '0'>).

=item C<mouse>

A boolean. Default: 1, or 0 in inline mode. With 1, the terminal
reports mouse clicks, drags, movement and the wheel to the program (see
L<Term::Fabulous::Manual::Events/MOUSE>). With 0, the terminal keeps the mouse
for itself, so the user can select and copy text as usual, and no
C<Mouse> or C<MouseMove> events are fired. Inline mode has no mouse
support: C<mouse> with a true value and C<inline> together die.

=item C<kitty_keyboard>

A boolean. Default: 1. With 1, L</run> asks the terminal whether it
speaks the
L<kitty keyboard protocol|https://sw.kovidgoyal.net/kitty/keyboard-protocol/>
and, if it does, switches the protocol on until C<run> returns. The
terminal then reports keys the legacy encodings cannot tell apart
(Ctrl+I and Tab, Ctrl+Shift+W and Ctrl+W, Escape and the start of Alt
plus a key), the Super, Hyper and Meta modifiers, and keys such as F13
to F35, the keypad and media keys; see
L<Term::Fabulous::Event::KeyPress/THE KITTY KEYBOARD PROTOCOL>. A
terminal without the protocol answers that it has none, and the keys
are read as before. The question costs one exchange with the terminal
when C<run> starts, at most half a second for a terminal that does not
answer at all. With 0, the terminal is not asked and the protocol stays
off. L</kitty_keyboard_active> tells whether C<run> uses it.

=item C<terminal>

Optional. The terminal to run on: an object composing
L<Term::Fabulous::Role::Terminal>. Default: a new
L<Term::Fabulous::Terminal::Termbox>, the real terminal. Pass a
L<Term::Fabulous::Terminal::Memory> to test a program without a
terminal (see L</step> and L<Term::Fabulous::Manual::Programs/TESTING>). Anything
else dies (C<Term::Fabulous: terminal must consume Term::Fabulous::Role::Terminal>).

=item C<clock>

Optional, for tests. A code reference that returns the current time in
seconds, default C<Time::HiRes::time>. Frame pacing reads it: how long
a frame took and when it ended (see L</run>), and so do L</now> and
the widgets that animate (see L</request_frame_at>). A test gives it a
clock it controls to check the pacing with C<< step( paced => 1 ) >>
or to move an animation on. Anything but a code reference dies.

=item C<output_mode>

Optional, and only one value is allowed: C<TB_OUTPUT_TRUECOLOR> from
L<Term::Fabulous::Termbox>, the default. Any other value dies. Term::Fabulous always draws
with 24-bit colors.

=item C<memory_size>

Optional, rarely needed. The number of bytes Clay reserves for laying out
a frame: an integer of at least what C<Clay::XS::Clay_MinMemorySize()>
reports for the UI's C<max_element_count> (about 6 MB for the default
count), which is also the default. It does not raise the limit on the
number of widgets; C<max_element_count> does.

=item C<max_element_count>

Optional. The number of Clay elements a frame may hold: a positive
integer, default 8192. Every widget is one element and Clay keeps two
elements for itself, so the default allows 8190 widgets on the screen
at once; a larger tree dies with
C<Clay::UI: the widget tree has more elements than max_element_count (8192) allows ...>.
Raise it for very large trees; the memory Clay reserves grows with it.
See L<Clay::UI/new>.

=item C<error_handler>

Optional. A code reference Clay calls when it reports an error during
layout (for example two widgets with the same id). The default dies with
C<Clay error: ...>. See L<Clay::UI/new>.

=item C<measure_text>

Not accepted, although L<Clay::UI> has it: Term::Fabulous always
measures text in terminal columns itself, so passing C<measure_text>
dies.

=back

=head1 METHODS

=head2 run

	$ui->run;

Opens the terminal in full-screen mode (or inline, see
L</INLINE MODE>), runs the event loop until it is stopped, and
restores the terminal. It returns nothing. A terminal that L</step>
opened is used as it is, without a second C<Start>, and closed when
C<run> returns.

While it runs:

=over

=item *

a C<Start> event is fired on the root widget as soon as the terminal is
open, with its size: from inside the running loop, before the first
frame and before any input is read, so a C<Start> listener can use
L</loop>. Timers and other work the program queued on the loop before
C<run> may run before it;

=item *

every 1/30 second (see L</termbox_draw_interval>) the screen is laid
out and drawn again, using the real terminal size, if anything changed
since the last frame: a widget was changed, input arrived, the terminal
was resized, L</invalidate> was called, or the time a widget asked for
a frame at has come (L</request_frame_at>, how spinners and progress
bars animate). Nothing is drawn while nothing happens. A pointer that only moved gets a frame of its own at
most every other check when frames take long to draw (longer than the
time since the last one ended), so moving the mouse cannot keep the
loop busy with nothing but redrawing; clicks, keys and changed widgets
are always drawn at the next check;

=item *

terminal input is read as soon as it arrives and dispatched as
C<KeyPress>, C<Mouse> and C<MouseMove> events (see L</EVENTS>);

=item *

terminal resizes fire C<Resize> on the root widget;

=item *

everything else you added to the L<IO::Async::Loop> (IO::Async calls
these objects I<notifiers>: timers, sockets, child processes, ...) runs
as usual.

=back

The loop stops, and C<run> returns, when:

=over

=item *

your code calls C<< $ui->loop->stop >>;

=item *

the user presses C<Ctrl+C> (after its C<KeyPress> was fired);

=item *

the process receives C<SIGINT>, C<SIGTERM> or C<SIGHUP>.

=back

While C<run> is active it handles these three signals itself; when it
returns or dies, C<%SIG> holds again what the program had set for them
before, except for a signal that an L<IO::Async::Signal> the program
added to the loop still watches.

If code running inside the loop dies (a listener, a timer), C<run>
restores the terminal first and then dies with the same error, so the
message is readable on the normal screen. The terminal is also restored
when code inside the loop calls C<exit>. When the terminal input ends
without a C<SIGHUP> reaching the process (a terminal that went away
while the process is not in its session, or input from a pipe), C<run>
dies with C<Term::Fabulous: the terminal was closed>.
After C<run> has returned or died, the object can be used again and
C<run> can be called again.

C<run> dies with the terminal's error when the terminal cannot be
opened. For the real terminal, these start with
C<Term::Fabulous::Terminal::Termbox:>, for example when the process has
no controlling terminal (C<tb_init failed: No such device or address>,
or C<tf_init_inline failed: ...> in inline mode), when the terminal
reports a size of 0 columns or rows, and in inline mode when the
terminal does not report its cursor position within a second
(C<the terminal did not report its cursor position; ...>); see
L<Term::Fabulous::Terminal::Termbox/open>.

When the locale's character set is not UTF-8, C<run> warns (at every
call): C<Term::Fabulous: the locale's character set is not UTF-8; wide
characters will be misaligned>.

=head2 step

	my $frames = $ui->step;
	my $frames = $ui->step( paced => 1 );

One turn of L</run> without an event loop, for tests: usually with a
L<Term::Fabulous::Terminal::Memory> as the L</terminal>, whose input
methods queue keys, clicks and resizes. C<step>

=over

=item 1.

opens the terminal if it is not open yet, sets L</width> and L</height>
to its size and fires C<Start>, as C<run> does (but there is no loop:
L</loop> is the one of the last C<run>, or C<undef>);

=item 2.

reads every event that waits and dispatches it exactly as C<run> does:
a key to the focused widget (after which Tab and Shift+Tab also move
the focus), a mouse event to the widget under the pointer (a press
focuses it first), a wheel notch to the scroll box under the pointer;
see L</EVENTS> and L</KEYBOARD AND FOCUS>. C<Ctrl+C> fires its
C<KeyPress> but has no loop to stop;

=item 3.

applies a resize at once, firing the C<Resize> pair, instead of waiting
for the size to settle;

=item 4.

draws frames as long as one is due: for a click, one frame for the
press and one for the release, and another one when a frame changed
widgets (hover and press events fire while a frame is drawn). Without
C<paced>, a frame that only shows pointer motion is drawn at once; with
C<< paced => 1 >>, it waits like in C<run> (see there), measured with
the C<clock> of L</new>.

=back

Returns the number of frames it drew, 0 when nothing was due. The
terminal stays open; C<run> closes it, or close it with
C<< $ui->terminal->close >>. Unknown options die, and so does a call
from inside C<run>. When frames keep being due after 100 rounds,
because a widget changes in every frame, C<step> dies. When the
terminal input has ended (L<Term::Fabulous::Terminal::Memory/end_input>),
C<step> dies like C<run>.

=head2 terminal

	my $terminal = $ui->terminal;
	$ui->terminal->press_key('Enter');

Returns the terminal object given to L</new>, or the
L<Term::Fabulous::Terminal::Termbox> created by default. Read only.

=head2 loop

	my $loop = $ui->loop;
	$ui->loop->stop;

Returns the L<IO::Async::Loop> of the most recent L</run>, or C<undef>
before the first C<run>; it is set before the C<Start> event fires.
Call C<< $ui->loop->stop >> from a listener or timer to end C<run>. The loop is IO::Async's process-wide loop: the same
object that C<< IO::Async::Loop->new >> returns, which is why notifiers
added to C<< IO::Async::Loop->new >> before C<run> run inside it.

=head2 interaction

	my $tracker = $ui->interaction;
	$ui->interaction->set_focused_widget($widget);
	my $focused = $ui->interaction->get_focused_widget;

Returns the L<Clay::UI::Interaction> object of this UI. It holds the
keyboard focus and the hover and press state of the widgets. Use it to
move the focus from code (C<set_focused_widget>, C<focus_next>,
C<focus_previous>) and to ask which widget has it
(C<get_focused_widget>). See L<Term::Fabulous::Manual::Events/FOCUS>. Inherited
from L<Clay::UI>.

=head2 root

	my $root = $ui->root;

Returns the root widget given to L</new>. Read only.

=head2 width

	my $columns = $ui->width;
	$ui->width(100);

Accessor. Returns the current layout width in columns: the terminal width
while L</run> is active. Writing sets the layout width from the next frame
on and returns the new value; a value that is not a positive number dies.
C<run> sets the width to the terminal width when it starts and after every
terminal resize, so a written value lasts only until then. Inherited from
L<Clay::UI>.

=head2 height

	my $rows = $ui->height;
	$ui->height(40);

Accessor. Returns the current layout height in rows: the terminal height
while L</run> is active, or the rows of the inline region in inline mode.
Writing works like for L</width>. Inherited from L<Clay::UI>.

=head2 inline

	my $rows = $ui->inline;    # undef for the full screen

Returns the C<inline> constructor parameter. Read only.

=head2 mouse

	my $enabled = $ui->mouse;

Returns whether the mouse is reported: the C<mouse> constructor
parameter, or its default (1, or 0 in inline mode). Read only.

=head2 kitty_keyboard

	my $wanted = $ui->kitty_keyboard;

Returns the C<kitty_keyboard> constructor parameter, or its default
(1). Read only.

=head2 kitty_keyboard_active

	my $in_use = $ui->kitty_keyboard_active;

Returns 1 while the open terminal uses the kitty keyboard protocol:
from the start of L</run> (or the first L</step>), before C<Start>
fires, until the terminal is closed, when the terminal speaks the
protocol and C<kitty_keyboard> is 1. Returns 0 otherwise, and always
while the terminal is closed. Read only.

=head2 output_mode

	my $mode = $ui->output_mode;    # TB_OUTPUT_TRUECOLOR

Returns the C<output_mode> constructor parameter, always
C<TB_OUTPUT_TRUECOLOR>. Read only.

=head2 pointer_state

	my $pointer = $ui->pointer_state;    # { x => 12, y => 3, down => 0 } or undef

Returns where the mouse pointer was last reported: a new hash reference
with the cell coordinates C<x> and C<y> and C<down>, which is 1 while the
left button is held and 0 otherwise. Returns C<undef> until the first
mouse report. The terminal reports every move, so this is the live
mouse position as of the last report. Term::Fabulous passes it to Clay
with every frame, which derives the hover and press state of the
widgets from it. When the button went down and up again between two
frames, each state gets a frame of its own, so a click is never too
fast to press a widget. C<down> follows the left button only: the
release of another button does not end a press.

=head2 invalidate

	$ui->invalidate;

Asks for a frame: the screen is laid out and drawn again at the next
tick of the frame timer, even if Term::Fabulous saw no change. Returns
the object. Frames are drawn by themselves whenever a widget was
changed through its methods, input arrived or the terminal was resized,
so most programs never need this; call it when something the frame
depends on changed behind Term::Fabulous's back, for example state a
custom widget reads while it draws without calling C<mark_changed>
(see L<telling Term::Fabulous that something changed|Term::Fabulous::Manual::CustomWidgets/Telling Term::Fabulous that something changed>).

=head2 now

	my $seconds = $ui->now;

The current time in seconds on the application's clock: the C<clock>
of L</new>, by default C<Time::HiRes::time>. Widgets that animate read
it instead of the system clock, so a test or the screenshot harness
can move it; see L</request_frame_at>.

=head2 request_frame_at

	$ui->request_frame_at( $ui->now + 0.1 );

Asks for a frame at a time on the clock (see L</now>): at the first
tick of the frame timer at or after it, a frame is drawn as if
L</invalidate> had been called, and C<step> draws one when the time
has come. Several requests keep the earliest time. Every frame forgets
the request, so something that animates asks again from the frame it
is drawn in. Returns the object. Dies unless the argument is a number.

This is how the widgets that move by themselves (a
L<Term::Fabulous::Widget::Spinner>, an indeterminate
L<Term::Fabulous::Widget::ProgressBar>) are drawn without timers of
their own; see L<Term::Fabulous::Widget::Display/ANIMATION> to write
one.

=head2 find_by_id

	my $field = $ui->find_by_id('name');

Returns the widget with the given id, searching the whole tree from the
root, or C<undef> when there is none; see
L<Term::Fabulous::Widget/find_by_id>. Dies when the root widget has no
C<find_by_id> method (every Term::Fabulous widget has one).

=head2 termbox_draw_interval

	my $seconds = $ui->termbox_draw_interval;    # 1/30

Returns the time between two checks for a due frame in seconds: 1/30.
A frame is drawn at a tick only when something changed since the last
one. Read only.

=head2 termbox_resize_debounce_interval

	my $seconds = $ui->termbox_resize_debounce_interval;    # 1/10

Returns how long, in seconds, the terminal size must stay unchanged
before a resize is applied and the C<Resize> events are fired: 1/10.
While a resize is pending, no frames are drawn. Read only.

=head2 draw

	$ui->draw;

Lays out and draws one frame immediately, into the cell target of the
L</terminal>. C<run> calls it whenever a frame is due, so programs do
not need it; see L</invalidate> to ask for a frame instead. With the
real terminal, it only has a visible effect while the terminal is open.
See L<Term::Fabulous::Render/draw>.

=head2 bounding_box, scroll_state, scroll_to

	my $box   = $ui->bounding_box($widget);       # { x, y, width, height } in cells, or undef
	my $state = $ui->scroll_state($scroll_box);   # { position, viewport, content }
	$ui->scroll_to( $scroll_box, { y => -10 } );  # ten rows down from the top

C<bounding_box> returns where the last frame placed a widget.
C<scroll_state> and C<scroll_to> read and set the scroll position of a
scroll container such as a L<Term::Fabulous::Widget::ScrollBox>, in
cells: 0 at the top and left, negative when scrolled down or right.
Inherited from L<Clay::UI>; see L<Clay::UI/bounding_box>,
L<Clay::UI/scroll_state> and L<Clay::UI/scroll_to>, and the recipe
L<Scroll a ScrollBox from code|Term::Fabulous::Cookbook::LiveData/Scroll a ScrollBox from code (keep a log at the newest line)>.

=head2 after_draw

	$ui->after_draw( sub { ... } );

Queues a code reference to call once after the next frame has been
drawn, for work that needs the layout of that frame. See
L<Term::Fabulous::Render/after_draw>.

=head2 Other inherited methods

The class inherits further methods from L<Clay::UI> (C<render>,
C<widget_for>, C<measure_text>, C<max_element_count>,
C<laid_out_revision>), from L<Term::Fabulous::Render> (C<last_frame>,
the L<Term::Fabulous::Render::Frame> of the last frame, and
C<clip_rect>) and from L<Term::Fabulous::Render::Canvas>
(C<invalidate_canvases>). C<cell_target> returns the cell target of the
L</terminal>. Applications rarely need them; they are documented on
those pages.

=head1 EVENTS

L</run> and L</step> fire these events. Each one bubbles from the
widget it is fired on to the root, as described in
L<Term::Fabulous::Manual::Events/Return values and bubbling>.

=over

=item C<KeyPress> (L<Term::Fabulous::Event::KeyPress>)

For every key press, on the focused widget, or on the root widget when
nothing has the focus.

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

For every mouse report with a button or the wheel (button press,
release, drag, wheel), on the topmost widget that drew something in the
cell under the pointer in the last frame: its background, its border or
its canvas. Text widgets are skipped, and so are widgets that draw
nothing there. When no widget qualifies, the event is fired on the root
widget. Content that is scrolled out of view in a
L<Term::Fabulous::Widget::ScrollBox> is not drawn and never receives
the event.

=item C<MouseMove> (L<Term::Fabulous::Event::MouseMove>)

For every report of the pointer moving with no button held, on the same
widget a C<Mouse> event would go to. The hover state of the widgets
follows these moves.

=item C<Start> (L<Term::Fabulous::Event::Start>)

On the root widget, once each time the terminal is opened (by L</run>,
or by the first L</step>), after C<width> and C<height> hold its size and
before the first frame.

=item C<Resize> (L<Term::Fabulous::Event::Resize>)

On the root widget, twice per resize: first with C<is_pre_event> true,
before the new size is applied, then with C<is_post_event> true, after
it. Resizes are debounced (see L</termbox_resize_debounce_interval>),
and a size with zero columns or rows is ignored. The starting size
fires C<Start> instead; see L<Term::Fabulous::Event::Resize>.

=back

Widgets fire further events themselves: C<Change> from the input
widgets, C<Submit> from L<Term::Fabulous::Widget::TextField>,
C<Activate> from L<Term::Fabulous::Widget::Button>, C<Close> from
L<Term::Fabulous::Widget::Dialog>, C<CanvasResize> from canvases,
C<SeriesHover> from charts, the table events (C<CursorMove>,
C<SelectionChange>, C<RowActivate>, C<SortChange>, C<FilterChange>,
C<PageChange>, C<Expand>, C<Collapse>, C<ColumnsChange>) from
L<Term::Fabulous::Widget::Table>, and Clay::UI's C<OnPress>,
C<OnRelease>, C<OnHoverStart>, C<OnHoverStopped>, C<OnFocus>, C<OnBlur>
and C<OnScroll>. The complete list is in
L<Term::Fabulous::Manual::Events/Event reference>.

=head1 KEYBOARD AND FOCUS

Three keys have a fixed meaning. Their C<KeyPress> is fired first, like
for any other key, and then:

=over

=item C<Ctrl+C>

stops the loop, so L</run> returns.

=item C<Tab>

moves the focus to the next widget that can take it, in tree order,
wrapping around at the end. An open L<Term::Fabulous::Widget::Dialog>
keeps the focus among its own widgets, and a container can set an order
of its own (see L<Term::Fabulous::Manual::Events/Custom focus order>).

=item C<Shift+Tab> (key name C<BackTab>)

moves the focus to the previous one, in the same order.

=back

Listeners cannot prevent these actions.

When the left mouse button is pressed (not dragged), the widget under
the pointer gets the focus, or its nearest ancestor that can take it.
When there is none, the focus is cleared; so clicking an empty area
leaves a text field and closes an open dropdown. This happens before the
C<Mouse> event is fired.

See L<Term::Fabulous::Manual::Events/KEYBOARD> and
L<Term::Fabulous::Manual::Events/FOCUS>.

=head1 INLINE MODE

	my $ui = Term::Fabulous->new( root => $root, width => 80, height => 3, inline => 3 );
	$ui->run;
	say 'Done.';    # printed below the region

=begin html

<p><img src="/screenshots/cookbook-inline-prompt.svg" alt="An inline prompt in the three rows below a shell's earlier output: a question, a text field holding Ada Lovelace and a help line"></p>

=end html

The picture shows the recipe
L<Ask for input below the shell's output|Term::Fabulous::Cookbook::Forms/Ask for input below the shell's output (inline mode)>,
a complete program that asks for a name in three rows below the
shell's output.

With C<inline> set to a number of rows, L</run> leaves the screen as it
is and draws the user interface into that many rows, starting at the
line of the cursor (the line below it when text precedes the cursor
on its line). The layout is as wide as the terminal and as high as
the region; L</height> and the C<Start> and C<Resize> events report the
region's rows. A region taller than the terminal gets the terminal's
height.

=over

=item *

When the region does not fit below the cursor, the terminal scrolls up
first, as if lines had been printed. The rows of the region are erased
before the first frame.

=item *

When C<run> returns, it first draws a frame if one is due, so a change
made by the listener that stopped the loop is shown. That frame stays
on the screen (when C<run> dies, the last frame drawn before), and the
cursor goes to the line below it, where the shell or the program's own
output continues.

=item *

When the terminal is resized, Term::Fabulous asks the terminal where
the region is now (between frames the hidden cursor waits at the start
of its first row), erases from there down and draws the region again.

=item *

The mouse is not available (see L</new>).

=item *

The terminal must answer the cursor position query C<ESC [ 6 n>, as
xterm-compatible terminals do; Term::Fabulous asks when C<run> starts
and after every resize.

=back

Like in full-screen mode, printing to STDOUT while C<run> is active
writes over the user interface.

=head1 MOUSE WHEEL SCROLLING

Each notch of the mouse wheel scrolls the scroll box under the
pointer (for example a L<Term::Fabulous::Widget::ScrollBox>) by three
rows, and each notch of a horizontal wheel (or a sideways tilt of the
wheel) by three columns. Notches that arrive between two frames are
added up and applied when the next frame is drawn. A C<Mouse> event is
fired for every notch, before the notch is counted: when a listener
calls C<use_wheel> on it (L<Term::Fabulous::Event::Mouse/use_wheel>),
the notch scrolls no scroll box; what the listener returns does not
matter for this. Widgets that scroll themselves, like
L<Term::Fabulous::Widget::TextArea>, use the notches they scroll by, so
the scroll box around them stays put while they can still scroll.

=head1 MODULES

Every module has its own page. They are grouped here by purpose; the
modules marked "used internally" are documented for people who extend
Term::Fabulous, and programs do not use them directly.

=head2 Application

=over

=item L<Term::Fabulous>

The interactive application object, described on this page.

=item L<Term::Fabulous::Static>

Renders a widget tree once, as text, without opening the terminal; for
reports, command-line output and tests.

=item L<Term::Fabulous::Layout>

Builds a widget tree from a KDL layout file, and documents the layout
file format.

=item L<Term::Fabulous::Terminal::Memory>

A terminal in memory: test a whole program, keys, clicks and what the
screen shows, with L</step>.

=back

=head2 Widgets

=over

=item L<Term::Fabulous::Widget::Box>

The general container, with layout options, a background and a border.

=item L<Term::Fabulous::Widget::Text>

Shows text in one color; wraps and aligns it.

=item L<Term::Fabulous::Widget::Button>

A box that can take the keyboard focus, shows when it is focused or
pressed, and fires C<Activate> for a click, Enter or Space.

=item L<Term::Fabulous::Widget::Dialog>

A box that opens over the whole screen, keeps the keyboard focus inside
itself and closes on Escape.

=item L<Term::Fabulous::Widget::ScrollBox>

A box whose content can be larger than the box and scrolls with the
mouse wheel.

=item L<Term::Fabulous::Widget::Divider>

A horizontal or vertical line between widgets, with an optional text at
its start, center or end.

=item L<Term::Fabulous::Widget::Accordion>, L<Term::Fabulous::Widget::Accordion::Item>

Sections with headers that open and close, one at a time or several,
with the keyboard and the mouse.

=item L<Term::Fabulous::Widget::Canvas>

A box with a grid of character cells that you draw into.

=item L<Term::Fabulous::Widget::PixelCanvas>

A canvas that draws pixels, two per cell, with lines, rectangles and
circles.

=item L<Term::Fabulous::Widget>

The abstract base class of all widgets except Text. Its page describes
the constructor parameters and methods they all share.

=item L<Term::Fabulous::Widget::Display>

The abstract base class of the widgets that paint themselves from their
own state (the divider, the progress bar, the input widgets), with the
animation helpers; derive from it to write your own.

=item L<Term::Fabulous::Widget::Element>, L<Term::Fabulous::Widget::TextNode>

The L<Clay::UI> roles behind Term::Fabulous::Widget and
Term::Fabulous::Widget::Text. Used internally.

=item L<Term::Fabulous::Widget::Dialog::Backdrop>

The layer behind an open dialog. Used internally by the dialog.

=back

=head2 Input widgets

=over

=item L<Term::Fabulous::Widget::TextField>

A single line of text input, optionally masked for passwords.

=item L<Term::Fabulous::Widget::TextArea>

Text input of several lines, wrapped or scrolled sideways.

=item L<Term::Fabulous::Widget::Checkbox>

A box the user checks and unchecks.

=item L<Term::Fabulous::Widget::RadioGroup>

A group of radio buttons of which one is selected; it takes the focus
for its buttons.

=item L<Term::Fabulous::Widget::RadioButton>

One choice inside a radio group.

=item L<Term::Fabulous::Widget::Dropdown>

One choice from a list that opens over the other widgets.

=item L<Term::Fabulous::Widget::Slider>

A number from a range, chosen by moving a thumb.

=item L<Term::Fabulous::Widget::StarRating>

A number of stars, whole or half, chosen with the keys or a click, or
read-only.

=item L<Term::Fabulous::Widget::SegmentedControl>

One choice of a few options shown side by side as one bar.

=item L<Term::Fabulous::Widget::Input>

The base class of the input widgets; derive from it to write your own.

=item L<Term::Fabulous::Widget::TextInput>

The base class of TextField and TextArea, with the editing keys and mouse
selection.

=item L<Term::Fabulous::Editor>

The text, cursor, selection, undo history and clipboard behind the text
inputs, without any drawing.

=item L<Term::Fabulous::TextView>

How the text inputs lay an editor's text out in rows: wrapping,
scrolling, the cell of the cursor and the text under a click.

=item L<Term::Fabulous::Widget::Dropdown::List>

The list an open dropdown shows. Used internally by the dropdown.

=back

=head2 Feedback widgets

=over

=item L<Term::Fabulous::Widget::ProgressBar>

How much of a task is done: a bar in several styles, with a label,
stripes, segments, or a runner for a task of unknown extent.

=item L<Term::Fabulous::Widget::Spinner>

That something is going on: frames cycling next to a label, in twelve
styles of one cell to three rows, or frames of your own.

=item L<Term::Fabulous::Widget::Toast>

A notification of a kind (info, success, warning, danger) that appears
in a corner, stacks with the others there and goes away by itself; in
the layout, an alert box.

=item L<Term::Fabulous::Widget::Toast::Stack>

The column of toasts in one corner. Used internally by the toast.

=back

=head2 Tables

=over

=item L<Term::Fabulous::Widget::Table>

Rows and columns of data, with sorting, filtering, grouping, trees,
pages, selection and widgets as cells. The guide to tables starts at
L<Term::Fabulous::Manual::Tables>, which has a feature index of its
own.

=item L<Term::Fabulous::Widget::Table::Column>

What a table column shows and how: its parameters in full.

=item L<Term::Fabulous::Widget::Table::Mutator>

Ready-made mutators that format cell values: dates, numbers, sizes,
durations, flags, lookups.

=item L<Term::Fabulous::Widget::Table::Filter>

Filter conditions on numbers, dates and text, their combinations, and
the notation of the filter row.

=item L<Term::Fabulous::Widget::Table::Value>

How tables read numbers and dates; natural sorting.

=item L<Term::Fabulous::Widget::Table::Model>

The rows of a table and the lines it shows, without widgets.

=item L<Term::Fabulous::Widget::Table::Style>, L<Term::Fabulous::Widget::Table::Borders>

How a table checks its style hashes and works out its grid lines. Used
internally by the table.

=item L<Term::Fabulous::Widget::Table::Cell>, L<Term::Fabulous::Widget::Table::Toggle>, L<Term::Fabulous::Widget::Table::Grid>, L<Term::Fabulous::Widget::Table::HeaderView>, L<Term::Fabulous::Widget::Table::Scrollbar>, L<Term::Fabulous::Widget::Table::Pager>, L<Term::Fabulous::Widget::Table::ColumnChooser>

The widgets a table is built of: cells, the open and close markers,
the grids, the header, the scrollbar, the page controls and the column
chooser. Used internally by the table.

=back

=head2 Charts

=over

=item L<Term::Fabulous::Widget::Chart>

What all charts share: title, legend, palettes and themes, colors,
hover and the C<SeriesHover> event.

=item L<Term::Fabulous::Widget::XYChart>

The reference for charts with an x and a y axis: series and their data
forms, axes, stacking, curves, rendering styles, transforms, live data.

=item L<Term::Fabulous::Widget::LineChart>, L<Term::Fabulous::Widget::AreaChart>, L<Term::Fabulous::Widget::BarChart>, L<Term::Fabulous::Widget::ScatterPlot>

The XY charts, each with its default series type: lines, filled areas,
bars, and points with trend lines.

=item L<Term::Fabulous::Widget::Histogram>

How values are distributed: counts in bins.

=item L<Term::Fabulous::Widget::Sparkline>

A chart without axes, one row high.

=item L<Term::Fabulous::Widget::PieChart>, L<Term::Fabulous::Widget::DonutChart>, L<Term::Fabulous::Widget::PolarAreaChart>

Parts of a whole as slices.

=item L<Term::Fabulous::Widget::RadarChart>

Several values per series on axes around a center.

=item L<Term::Fabulous::Role::HasSeries>

Adding, changing and removing the series of a chart and their data.

=item L<Term::Fabulous::Chart::Transform>, L<Term::Fabulous::Chart::Curve>, L<Term::Fabulous::Chart::Easing>

Steps that prepare the data of a series; the curves between points and
their easing functions.

=item L<Term::Fabulous::Chart::Palette>, L<Term::Fabulous::Chart::Format>, L<Term::Fabulous::Chart::Marker>

Palettes and ink colors; number and date labels; the character sets
charts draw with.

=item L<Term::Fabulous::Chart::Scale>, L<Term::Fabulous::Chart::Scale::Linear>, L<Term::Fabulous::Chart::Scale::Log>, L<Term::Fabulous::Chart::Scale::Time>, L<Term::Fabulous::Chart::Scale::Category>

The scales of chart axes: what they have in common, and numeric,
logarithmic, date and time, and category axes.

=item L<Term::Fabulous::Chart::Raster>, L<Term::Fabulous::Chart::Surface>, L<Term::Fabulous::Chart::Radial>, L<Term::Fabulous::Chart::Series>

The machinery behind the charts: subpixel drawing, the cells of a chart
while it is drawn, the geometry of round charts and the series object;
for charts of your own.

=back

=head2 Events

=over

=item L<Term::Fabulous::Event::KeyPress>

A key was pressed. Provides readable key names for key bindings.

=item L<Term::Fabulous::Event::Mouse>

A mouse button was pressed or released, the mouse was dragged, or the
wheel was turned.

=item L<Term::Fabulous::Event::MouseMove>

The mouse pointer moved with no button held.

=item L<Term::Fabulous::Event::Start>

The terminal is open and its size is known.

=item L<Term::Fabulous::Event::Resize>

The terminal changed size.

=item L<Term::Fabulous::Event::CanvasResize>

A canvas got a new size from the layout.

=item L<Term::Fabulous::Event::Change>

The user changed the value of an input widget.

=item L<Term::Fabulous::Event::Submit>

The user pressed Enter in a text field.

=item L<Term::Fabulous::Event::Activate>

The user activated a button, by click or key.

=item L<Term::Fabulous::Event::Close>

A dialog was closed, or a toast went away.

=item L<Term::Fabulous::Event::Select>

The user opened or closed an item of an accordion.

=item L<Term::Fabulous::Event::SeriesHover>

The pointer moved onto another series, point or slice of a chart.

=item L<Term::Fabulous::Event::CursorMove>

The cursor of a table moved to another line.

=item L<Term::Fabulous::Event::SelectionChange>

The user changed which rows of a table are selected.

=item L<Term::Fabulous::Event::RowActivate>

The user pressed Enter on a table row or double-clicked it.

=item L<Term::Fabulous::Event::SortChange>

The user changed how a table is sorted.

=item L<Term::Fabulous::Event::FilterChange>

The user typed into a filter field of a table.

=item L<Term::Fabulous::Event::PageChange>

The user turned the page of a table or chose another page size.

=item L<Term::Fabulous::Event::Expand>, L<Term::Fabulous::Event::Collapse>

The user opened or closed a tree row or a group of a table.

=item L<Term::Fabulous::Event::ColumnsChange>

The user showed or hid a table column in the column chooser.

=back

=head2 Colors, borders and text

=over

=item L<Term::Fabulous::Color>

Color values: parsing color strings, converting between RGB and HSL,
making colors lighter, darker or mixed.

=item L<Term::Fabulous::Enum::WebColor>

The 148 CSS named colors (C<Tomato>, C<SteelBlue>, ...) as
Term::Fabulous::Color objects.

=item L<Term::Fabulous::Enum::BorderStyle>

The 20 border styles and their characters.

=item L<Term::Fabulous::Role::HasBorderStyle>

The per-side border styles of a widget and how borders take space.

=item L<Term::Fabulous::Unicode>

How many terminal columns a piece of text takes, and how text is made
safe for the terminal.

=back

=head2 Extending Term::Fabulous

These modules matter only if you write widget classes that can be built
from layout files, or your own terminal or output class.

=over

=item L<Term::Fabulous::Role::CanParseLayout>

Makes a widget class usable in KDL layout files.

=item L<Term::Fabulous::Check>

Checks the values of widget properties, with one wording for each kind
of value.

=item L<Term::Fabulous::Role::Terminal>

What the application object needs from a terminal; write your own
terminal with it.

=item L<Term::Fabulous::Terminal::Termbox>

The real terminal, through termbox2: the default terminal.

=item L<Term::Fabulous::Terminal::Termbox::Cells>

Sends the drawn cells to the terminal. Used internally by the real
terminal.

=item L<Term::Fabulous::Termbox>

The termbox2 library itself, compiled into the distribution: the
C<tb_*> functions and C<TB_*> constants, and the width functions
L<Term::Fabulous::Unicode> measures with.

=item L<Term::Fabulous::Termbox::Event>

One termbox2 input event, as C<tb_peek_event> fills it.

=item L<Term::Fabulous::Render>

The role that draws a laid-out widget tree; composed by Term::Fabulous
and Term::Fabulous::Static.

=item L<Term::Fabulous::Render::Frame>

What one frame paints: the paint order, the clip rect of every command
(the visible part of scroll containers) and the cells every command
paints, for drawing and for finding the widget under the mouse.

=item L<Term::Fabulous::Render::Target::Grid>

Collects the drawn cells in memory.

=item L<Term::Fabulous::Render::Target::Mask>

The base role of the cell targets: lets a frame keep cells of the
previous frame, so unchanged canvases are not drawn again.

=item L<Term::Fabulous::Render::Rectangle>, L<Term::Fabulous::Render::Border>, L<Term::Fabulous::Render::Text>, L<Term::Fabulous::Render::Canvas>

Draw backgrounds, borders, text and canvases; the canvas painter sends
only the changed cells when possible.

=item L<Term::Fabulous::Render::Attr>

Converts colors into termbox2 color values.

=item L<Term::Fabulous::Render::Geometry>

Converts Clay's layout boxes into terminal cells.

=back

=head1 LIMITATIONS

=over

=item *

A frame lays out and draws the whole screen, whatever changed. Only the
cells that changed are sent to the terminal, but a very large widget
tree costs CPU time on every frame it needs.

=item *

Without the kitty keyboard protocol (see L</new>), C<Alt> plus a key is
recognized when the terminal sends the Escape and the key in one write,
which terminals do. C<Escape> followed quickly by a key that arrives in
the same read looks like C<Alt> plus that key. C<Alt+[> and C<Alt+O>
cannot be bound: they begin the escape sequences of other keys. A
terminal that speaks the protocol reports all of these keys without
ambiguity.

=item *

Mouse reports with the buttons 8 to 11 (extra buttons of some mice)
are decoded by termbox2 as the left, middle or right button.

=item *

In inline mode, a terminal that rewraps its lines when it gets narrower
rewraps the region too. Term::Fabulous erases the rewrapped rows it
still finds on the screen, but when they are more than the screen
holds, the terminal pushes the first of them into the scrollback (tmux
does), and the scrollback cannot be erased without erasing the user's
history too: copies of the old region stay there. Output that other
programs write to the terminal while C<run> is active also moves the
region away from where Term::Fabulous draws it.

=item *

Clay lays out at most C<max_element_count> elements per frame (8192 by
default); every widget is one element and Clay keeps two for
itself. A larger tree makes drawing die with a message that names the
limit; raise C<max_element_count> in L</new>.

=back

=head1 SEE ALSO

L<Term::Fabulous::Manual>, L<Term::Fabulous::Cookbook>,
L<Term::Fabulous::Examples>, L<Clay::UI>, L<Clay::XS>,
L<Term::Fabulous::Termbox>, L<IO::Async>, L<Object::Pad>.

=head1 BUGS

Please report bugs at
L<https://github.com/davenonymous/perl-term-fabulous/issues>.

=head1 AUTHOR

davenonymous E<lt>perl@davenonymous.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
