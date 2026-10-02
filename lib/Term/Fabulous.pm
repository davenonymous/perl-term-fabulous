package Term::Fabulous;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI;
use Term::Fabulous::Render;
use Term::Fabulous::Render::Target::Termbox;

class Term::Fabulous
	:isa(Clay::UI)
	:does(Term::Fabulous::Render)
	:does(Term::Fabulous::Render::Target::Termbox)
	:strict(params)
{
	use Clay::UI::Revision qw(current_revision);
	use Clay::XS qw(
		CLAY_RENDER_COMMAND_TYPE_BORDER
		CLAY_RENDER_COMMAND_TYPE_CUSTOM
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE
		CLAY_RENDER_COMMAND_TYPE_TEXT
	);
	use Feature::Compat::Try;
	use IO::Async::Handle;
	use IO::Async::Loop;
	use IO::Async::Signal;
	use IO::Async::Timer::Countdown;
	use IO::Async::Timer::Periodic;
	use List::Util qw(any);
	use POSIX qw(EINTR EIO);
	use Scalar::Util qw(refaddr);
	use Time::HiRes ();
	use Term::Fabulous::Termbox qw(
		tb_init tf_init_inline tb_shutdown tb_width tb_height tb_hide_cursor tb_clear
		tb_set_input_mode tb_set_output_mode tb_get_fds tb_peek_event tb_send
		tb_last_errno tb_strerror tf_install_input_parser tf_readable_bytes
		tf_cursor_position tf_reset_attrs tf_kitty_keyboard_query
		TB_OK TB_ERR TB_ERR_NEED_MORE TB_ERR_NO_EVENT TB_ERR_POLL
		TB_EVENT_KEY TB_EVENT_MOUSE TB_EVENT_RESIZE
		TB_INPUT_ESC TB_INPUT_MOUSE
		TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN
		TF_KEY_MOUSE_MOVE TF_KEY_MOUSE_WHEEL_LEFT TF_KEY_MOUSE_WHEEL_RIGHT
		TB_KEY_CTRL_C TB_KEY_TAB TB_KEY_BACK_TAB TB_MOD_MOTION
	);
	use Term::Fabulous::Termbox::Event;
	use Term::Fabulous::Event::KeyPress;
	use Term::Fabulous::Event::Mouse;
	use Term::Fabulous::Event::MouseMove;
	use Term::Fabulous::Event::Resize;
	use Term::Fabulous::Event::Start;
	use Term::Fabulous::Render::Geometry qw(cell_rect);
	use Term::Fabulous::Unicode qw(terminal_is_utf8);

	use constant WATCHED_SIGNALS     => qw(TERM INT HUP);
	use constant WHEEL_NOTCH_ROWS    => 3;
	use constant WHEEL_NOTCH_COLUMNS => 3;

	# Mouse mode 1003 (any-event tracking) reports the pointer moving with
	# no button held; termbox2 asks only for buttons, drags and the wheel.
	use constant REPORT_MOUSE_MOTION      => "\x1b[?1003h";
	use constant STOP_MOUSE_MOTION_REPORT => "\x1b[?1003l";

	# The kitty keyboard protocol with its flags 1 (disambiguate escape
	# codes) and 4 (report alternate keys), pushed onto the terminal's
	# stack of flags and popped off again.
	use constant PUSH_KITTY_KEYBOARD             => "\x1b[>5u";
	use constant POP_KITTY_KEYBOARD              => "\x1b[<u";
	use constant KITTY_KEYBOARD_QUERY_TIMEOUT_MS => 500;

	use constant CURSOR_REPORT_TIMEOUT_MS => 1000;
	use constant ERASE_BELOW              => "\x1b[J";

	field $inline :param :reader = undef;    # the rows of the inline region, or undef for the full screen
	field $mouse :param :reader  = undef;
	field $kitty_keyboard :param :reader = 1;
	field $kitty_keyboard_active :reader = 0;    # whether run asked the terminal for the protocol
	field $loop :reader;
	field $termbox_draw_interval :reader            = 1 / 30;
	field $termbox_resize_debounce_interval :reader = 1 / 10;

	field $_terminal_is_open = 0;
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
	field $_drawn_revision  = -1;   # the Clay::UI revision the last frame showed
	field $_shown_down      = 0;    # the button state the last frame showed Clay
	field $_frame_seconds   = 0;    # how long the last frame took to draw
	field $_frame_ended_at  = 0;    # when it was drawn (Time::HiRes::time)

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
	}

	method pointer_state () {
		return undef unless defined $_pointer;
		return {%$_pointer};
	}

	method invalidate () {
		$_frame_requested = 1;
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

		my ( $init, $rc ) = defined $inline ? ( 'tf_init_inline', tf_init_inline() ) : ( 'tb_init', tb_init() );
		die "Term::Fabulous: $init failed: " . tb_strerror($rc) . "\n" unless $rc == TB_OK;
		$_terminal_is_open = 1;
		$self->invalidate_canvases;    # the fresh back buffer holds no canvas cells

		try {
			$self->_prepare_terminal;
			$loop = IO::Async::Loop->new;
			$self->_attach_notifiers;
			$loop->later( sub { $self->_start } );
			$loop->run;

			# The frame that stays on the screen shows the final state; frames
			# start after Start, with the frame timer.
			$self->_draw_frame if defined $inline && $_draw_timer->is_running;
		}
		catch ($error) {
			# Perl reports an uncaught exception before unwinding into
			# finally; restore the terminal first so the message stays visible.
			$self->_close_terminal;
			die $error;
		}
		finally {
			$self->_close_terminal;    # also runs when an event handler calls exit()
		}
		return;
	}

	method _close_terminal () {
		return unless $_terminal_is_open;
		$_terminal_is_open = 0;
		$self->_detach_notifiers;
		tb_send(STOP_MOUSE_MOTION_REPORT) if $mouse;    # termbox2 switches off only the modes it switched on
		tb_send(POP_KITTY_KEYBOARD) if $kitty_keyboard_active;    # before termbox2 leaves the alternate screen, which has a stack of its own
		$kitty_keyboard_active = 0;
		$self->_leave_inline_region if defined $self->termbox_inline_top;
		tb_shutdown();
		return;
	}

	# The region starts on the cursor's row, or on the next one when text
	# precedes the cursor there. When it would reach below the screen,
	# the terminal scrolls up first. Its rows are erased, since termbox
	# takes the rows it has not drawn yet for blank.
	method _anchor_inline_region ($screen_height) {
		my $rc = tf_cursor_position( CURSOR_REPORT_TIMEOUT_MS, \my $column, \my $row );
		die "Term::Fabulous: the terminal did not report its cursor position; inline mode needs a terminal that answers ESC [ 6 n\n"
			if $rc == TB_ERR_NO_EVENT;
		_check_termbox( 'tf_cursor_position', $rc );

		my $rows     = $inline < $screen_height ? $inline : $screen_height;
		my $top      = $column == 0 ? $row : $row + 1;
		my $overflow = $top + $rows - $screen_height;
		_check_termbox( 'tf_reset_attrs', tf_reset_attrs() );    # scrolled-in and erased rows take the current background
		if ( $overflow > 0 ) {
			_check_termbox( 'tb_send', tb_send( _cursor_to_row( $screen_height - 1 ) . "\n" x $overflow ) );
			$top -= $overflow;
		}
		_check_termbox( 'tb_send', tb_send( _cursor_to_row($top) . ERASE_BELOW ) );
		_check_termbox( 'tb_clear', tb_clear() );    # cells of an earlier region must not come back at their old rows
		$self->set_termbox_inline_top($top);
		return $rows;
	}

	# The last frame stays where it is; the shell goes on below it.
	method _leave_inline_region () {
		my $last_row = $self->termbox_inline_top + $self->height - 1;
		tf_reset_attrs();
		tb_send( _cursor_to_row($last_row) . "\n" );
		$self->set_termbox_inline_top(undef);
		return;
	}

	sub _cursor_to_row ($row) {
		return "\x1b[" . ( $row + 1 ) . ";1H";
	}

	sub _check_termbox ( $function, $rc ) {
		die "Term::Fabulous: $function failed: " . tb_strerror($rc) . "\n" unless $rc == TB_OK;
		return;
	}

	# Watching a duplicate lets the watcher close its handle without closing
	# termbox's own descriptor before tb_shutdown().
	sub _duplicate_for_reading ($fd) {
		open my $handle, '<&', $fd or die "Term::Fabulous: cannot duplicate file descriptor $fd: $!\n";
		return $handle;
	}

	# Rectangles, text and canvases paint their whole box, a border only its
	# edges; nothing is painted outside the clip rect.
	sub _command_paints_cell ( $command, $clip, $x, $y ) {
		my ( $clip_x0, $clip_y0, $clip_x1, $clip_y1 ) = @$clip;
		return 0 unless $x >= $clip_x0 && $x < $clip_x1 && $y >= $clip_y0 && $y < $clip_y1;

		my ( $x0, $y0, $x1, $y1 ) = cell_rect( $command->{boundingBox} );
		return 0 unless $x >= $x0 && $x < $x1 && $y >= $y0 && $y < $y1;

		my $type = $command->{commandType};
		return 1 if $type == CLAY_RENDER_COMMAND_TYPE_RECTANGLE || $type == CLAY_RENDER_COMMAND_TYPE_TEXT || $type == CLAY_RENDER_COMMAND_TYPE_CUSTOM;
		return 0 unless $type == CLAY_RENDER_COMMAND_TYPE_BORDER;

		my $widths = $command->{renderData}{width} // {};
		return $x < $x0 + ( $widths->{left} // 0 )
			|| $x >= $x1 - ( $widths->{right} // 0 )
			|| $y < $y0 + ( $widths->{top} // 0 )
			|| $y >= $y1 - ( $widths->{bottom} // 0 );
	}

	method _prepare_terminal () {
		_check_termbox( 'tb_set_output_mode', tb_set_output_mode( $self->output_mode ) );
		_check_termbox( 'tb_set_input_mode',  tb_set_input_mode( TB_INPUT_ESC | ( $mouse ? TB_INPUT_MOUSE : 0 ) ) );
		_check_termbox( 'tf_install_input_parser', tf_install_input_parser() );
		_check_termbox( 'tb_send', tb_send(REPORT_MOUSE_MOTION) ) if $mouse;
		$self->_use_kitty_keyboard if $kitty_keyboard;
		_check_termbox( 'tb_hide_cursor', tb_hide_cursor() );

		my ( $width, $height ) = ( tb_width(), tb_height() );
		die "Term::Fabulous: the terminal reports an unusable size of ${width}x${height}\n"
			if $width < 1 || $height < 1;
		$self->width($width);
		$self->height( defined $inline ? $self->_anchor_inline_region($height) : $height );
		return;
	}

	# A terminal that does not answer the query does not speak the
	# protocol; the input parser reads the legacy encodings as before.
	method _use_kitty_keyboard () {
		my $rc = tf_kitty_keyboard_query( KITTY_KEYBOARD_QUERY_TIMEOUT_MS, \my $supported );
		return if $rc == TB_ERR_NO_EVENT;
		_check_termbox( 'tf_kitty_keyboard_query', $rc );
		return unless $supported;
		_check_termbox( 'tb_send', tb_send(PUSH_KITTY_KEYBOARD) );
		$kitty_keyboard_active = 1;
		return;
	}

	# Signals and timers; the terminal input is watched from _start on.
	method _attach_notifiers () {
		my $stop = sub { $loop->stop };

		$_resize_timer = IO::Async::Timer::Countdown->new(
			delay     => $termbox_resize_debounce_interval,
			on_expire => sub { $self->_fire_resize },
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
	# read only after it.
	method _start () {
		$self->root->fire_event( Term::Fabulous::Event::Start->new( width => $self->width, height => $self->height ) );
		$_draw_timer->start;
		$self->_watch_terminal_input;
		$self->_drain_termbox_events if defined $inline || $kitty_keyboard;    # keys the terminal queries read ahead
		return;
	}

	method _watch_terminal_input () {
		_check_termbox( 'tb_get_fds', tb_get_fds( \my $tty_fd, \my $resize_fd ) );
		my $tty_handle = _duplicate_for_reading($tty_fd);
		my @input_watchers = (
			IO::Async::Handle->new(
				read_handle   => $tty_handle,
				on_read_ready => sub {
					$self->_drain_termbox_events;
					die "Term::Fabulous: the terminal was closed (end of input)\n" if _input_is_at_eof($tty_handle);
				},
			),
			IO::Async::Handle->new(
				read_handle   => _duplicate_for_reading($resize_fd),
				on_read_ready => sub { $self->_drain_termbox_events },
			),
		);
		$self->_add_notifiers(@input_watchers);

		# IO::Async switches watched handles to non-blocking mode. A duplicate
		# shares that flag with termbox's own descriptor, and termbox gives up
		# on a partial write() of a frame, so switch them back. Readiness
		# notification does not depend on the flag, and nothing here reads
		# from these handles.
		foreach my $watcher (@input_watchers) {
			defined $watcher->read_handle->blocking(1)
				or die "Term::Fabulous: cannot restore blocking mode on a terminal descriptor: $!\n";
		}
		return;
	}

	# After termbox has read all it could, a descriptor that still reports
	# readable with no byte to read is at end of file: the terminal is gone.
	# termbox reports that only as "no event", again and again. A terminal
	# that hung up cannot even say how many bytes wait (EIO).
	sub _input_is_at_eof ($handle) {
		vec( my $readable = '', fileno $handle, 1 ) = 1;
		return 0 unless select( $readable, undef, undef, 0 ) > 0;
		my $waiting = tf_readable_bytes( fileno $handle );
		return 1 if $waiting == 0;
		return $waiting < 0 && $! == EIO ? 1 : 0;
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

	method _draw_frame () {
		return if $_resize_timer->is_running;
		return unless $self->_frame_is_due;
		$self->_draw_pending;
		return;
	}

	# A frame is due when something asked for one (invalidate, a key, a
	# click, a resize), when wheel input or a button press or release waits
	# to be shown to Clay, or when a widget changed since the last frame
	# (the Clay::UI revision). Pointer motion alone gets at most every
	# other slice of time: when frames are slow, moving the mouse must not
	# keep the loop busy with nothing but redrawing.
	method _frame_is_due ( $now = Time::HiRes::time() ) {
		return 1 if $_frame_requested || $_wheel_rows || $_wheel_columns;
		return 1 if current_revision() != $_drawn_revision;
		return 0 unless @_pointer_queue;
		return 1 if any { $_->{down} != $_shown_down } @_pointer_queue;
		return $now - $_frame_ended_at >= $_frame_seconds ? 1 : 0;
	}

	# Clay takes one button state per frame, so every queued pointer state
	# gets a frame of its own; the wheel movement goes with the first. The
	# revision is read before drawing: a frame that changes widgets (hover
	# and press events fire during it) leaves the next frame due.
	method _draw_pending () {
		my @pointers = splice @_pointer_queue;
		push @pointers, $_pointer unless @pointers;
		my ( $columns, $rows ) = ( $_wheel_columns, $_wheel_rows );
		( $_wheel_columns, $_wheel_rows ) = ( 0, 0 );
		$_drawn_revision  = current_revision();
		$_frame_requested = 0;

		my $started = Time::HiRes::time();
		foreach my $pointer (@pointers) {
			$_pointer    = $pointer;
			$_shown_down = defined $pointer ? $pointer->{down} : 0;
			$self->draw( scroll_cells => [ $columns, $rows ] );
			( $columns, $rows ) = ( 0, 0 );
		}
		$_frame_ended_at = Time::HiRes::time();
		$_frame_seconds  = $_frame_ended_at - $started;
		return;
	}

	method _drain_termbox_events () {
		while (1) {
			my $event = Term::Fabulous::Termbox::Event->new;
			my $rc    = tb_peek_event( $event, 0 );
			if ( $rc == TB_OK ) {
				$self->_dispatch_termbox_event($event);
				next;
			}

			# Nothing buffered, or only the start of a key sequence whose
			# remaining bytes make the descriptor readable again.
			return if $rc == TB_ERR_NO_EVENT || $rc == TB_ERR || $rc == TB_ERR_NEED_MORE;
			return if $rc == TB_ERR_POLL && tb_last_errno() == EINTR;
			die "Term::Fabulous: reading terminal input failed: " . tb_strerror($rc) . "\n";
		}
	}

	method _dispatch_termbox_event ($event) {
		my $type = $event->type;
		return $self->_on_key($event)    if $type == TB_EVENT_KEY;
		return $self->_on_mouse($event)  if $type == TB_EVENT_MOUSE;
		return $self->_on_resize($event) if $type == TB_EVENT_RESIZE;
		die "Term::Fabulous: unknown termbox event type '$type'";
	}

	method _on_key ($event) {
		$_frame_requested = 1;    # listeners may change anything
		my $target = $self->interaction->get_focused_widget // $self->root;
		$target->fire_event( Term::Fabulous::Event::KeyPress->of($event) );

		my ( $key, $is_special_key ) = ( $event->key, $event->ch == 0 );
		$loop->stop                        if $is_special_key && $key == TB_KEY_CTRL_C;
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
		$self->interaction->set_focused_widget( _focusable_at_or_above($target) )
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
	sub _focusable_at_or_above ($widget) {
		for ( my $node = $widget; defined $node; $node = $node->parent ) {
			return $node if $node->DOES('Clay::UI::Role::Interaction::Focusable') && $node->can_focus;
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
		$_resize_timer->is_running ? $_resize_timer->reset : $_resize_timer->start;
		return;
	}

	method _fire_resize () {
		return unless defined $_pending_resize;
		my ( $width, $height ) = @$_pending_resize;
		$_pending_resize = undef;
		$height = $self->_anchor_inline_region($height) if defined $inline;

		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 0 ) );
		$self->width($width);
		$self->height($height);
		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 1 ) );
		$_frame_requested = 1;
		$self->_drain_termbox_events if defined $inline;    # keys the cursor position query read ahead
		return;
	}

	# Topmost event emitter painted at the cell in the last frame that is
	# still part of this UI: a listener may have removed it since.
	method _emitter_at ( $x, $y ) {
		my ( $commands, $clip_rects ) = $self->last_frame;
		foreach my $index ( reverse 0 .. $#$clip_rects ) {
			my $command = $commands->[$index];
			next unless _command_paints_cell( $command, $clip_rects->[$index], $x, $y );
			my $widget = $self->widget_for( $command->{userData} );
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

=begin html

<p><img src="/screenshots/overview.svg" alt="A Term::Fabulous program: a sign-up form with text fields, radio buttons, a dropdown, a slider, a check box and buttons, a chart of requests per second with a translucent notification, an event log and text in several scripts"></p>

=end html

=head1 DESCRIPTION

Term::Fabulous builds full-screen terminal applications in Perl. You
describe the screen as a tree of widgets (boxes, text, buttons, input
fields, scrollable areas and canvases), in Perl code or in a layout file
written in KDL, a small configuration language (L<https://kdl.dev>).
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
boxes; radio buttons; dropdowns; sliders.

=item *

Keyboard focus with Tab and mouse clicks, readable key names for key
bindings (C<Ctrl+S>, C<Shift+Left>), mouse wheel scrolling.

=item *

Canvases for free drawing, including a half-block pixel canvas with
lines, rectangles and circles.

=item *

Correct handling of Unicode: wide CJK characters, emoji, combining
characters.

=item *

The same widget tree can be printed once as text (with or without
colors) for reports and tests, through L<Term::Fabulous::Static>.

=item *

Runs on L<IO::Async>, so timers, sockets and child processes work
alongside the user interface.

=back

This class is the application object: it owns the widget tree, opens the
terminal, runs the event loop, draws a frame whenever something changed
(checking 30 times per second) and dispatches input events. It is a
subclass of L<Clay::UI>.

=head1 DOCUMENTATION

=over

=item L<Term::Fabulous::Manual>

The user guide. Start here: it explains layout, text, colors, events,
the keyboard and the mouse, focus, forms, KDL layout files, the event
loop and writing your own widgets, with examples throughout. Its
L<FEATURE INDEX|Term::Fabulous::Manual/FEATURE INDEX> maps tasks to the
documentation.

=item L<Term::Fabulous::Cookbook>

Complete programs for common tasks.

=item This page

The reference for C<new>, C<run> and the other methods of the
application object.

=item The module pages

One page per class, listed under L</MODULES>.

=item L<Term::Fabulous::Examples>

The example programs of the distribution, with a picture of each: demo
programs, a gallery of the widgets and the complete programs of the
cookbook. The picture above is F<examples/showcase.pl>.

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
L</run>, so you can create the object, set the focus and add timers
first. Unknown parameters die
(C<Unrecognised parameters for Term::Fabulous constructor: 'colour'>).

=over

=item C<root>

Required. The root widget, the top of the widget tree, usually a
L<Term::Fabulous::Widget::Box>. It receives every event that no other
widget receives: key presses while nothing has the focus, mouse events
where no widget is drawn, and every C<Resize>. It must therefore be able
to fire events (compose L<Clay::UI::Role::Events::Emitter>, as all
Term::Fabulous widgets except Text do); otherwise C<new> dies. A widget
that was ever attached to another widget cannot be the root.

=item C<width>

Required. A positive number: the width of the layout in columns until
L</run> starts. C<run> replaces it with the terminal's width, and keeps
it up to date when the terminal is resized.

=item C<height>

Required. A positive number: the height of the layout in rows until
L</run> starts, then the terminal's height (in inline mode, the rows of
the inline region).

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
L<Term::Fabulous::Manual/MOUSE>). With 0, the terminal keeps the mouse
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
integer, default 8192. Every widget is one element and Term::Fabulous
uses two more, so the default allows 8190 widgets on the screen at
once; a larger tree dies with
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
restores the terminal. It returns nothing.

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
was resized or L</invalidate> was called. Nothing is drawn while
nothing happens. A pointer that only moved gets a frame of its own at
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

C<run> dies with a message starting with C<Term::Fabulous:> when the
terminal cannot be opened, for example when the process has no
controlling terminal (C<tb_init failed: No such device or address>,
or C<tf_init_inline failed: ...> in inline mode), or when the terminal
reports a size of 0 columns or rows. In inline mode it also dies when
the terminal does not report its cursor position within a second
(C<the terminal did not report its cursor position; ...>).

When the locale's character set is not UTF-8, C<run> warns (at every
call): C<Term::Fabulous: the locale's character set is not UTF-8; wide
characters will be misaligned>.

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
(C<get_focused_widget>). See L<Term::Fabulous::Manual/FOCUS>. Inherited
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

Returns 1 while L</run> uses the kitty keyboard protocol: from the
start of C<run>, before C<Start> fires, until C<run> returns, when the
terminal speaks the protocol and C<kitty_keyboard> is 1. Returns 0
otherwise, and always outside C<run>. Read only.

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
(see L<Term::Fabulous::Manual/WRITING YOUR OWN WIDGETS>).

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

Lays out and draws one frame immediately. C<run> calls it whenever a
frame is due, so programs do not need it; see L</invalidate> to ask for
a frame instead. It only has a visible effect while the terminal is
open. See L<Term::Fabulous::Render/draw>.

=head2 Other inherited methods

The class inherits further methods from L<Clay::UI> (C<render>,
C<widget_for>, C<measure_text>) and from L<Term::Fabulous::Render>
(C<get_last_commands>, C<get_last_clip_rects>, C<last_frame>).
Applications rarely need them; they are documented on those pages.

=head1 EVENTS

C<run> fires these events. Each one bubbles from the widget it is fired
on to the root, as described in
L<Term::Fabulous::Manual/Return values and bubbling>.

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

On the root widget, once per C<run>, after the terminal is open and
C<width> and C<height> hold its size, before the first frame.

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
L<Term::Fabulous::Widget::Dialog>, C<CanvasResize> from canvases, and
Clay::UI's C<OnPress>, C<OnRelease>, C<OnHoverStart>, C<OnHoverStopped>,
C<OnFocus>, C<OnBlur> and C<OnScroll>. The complete list is in
L<Term::Fabulous::Manual/Event reference>.

=head1 KEYBOARD AND FOCUS

Three keys have a fixed meaning. Their C<KeyPress> is fired first, like
for any other key, and then:

=over

=item C<Ctrl+C>

stops the loop, so L</run> returns.

=item C<Tab>

moves the focus to the next widget that can take it, in tree order,
wrapping around at the end.

=item C<Shift+Tab> (key name C<BackTab>)

moves the focus to the previous one.

=back

Listeners cannot prevent these actions.

When the left mouse button is pressed (not dragged), the widget under
the pointer gets the focus, or its nearest ancestor that can take it.
When there is none, the focus is cleared; so clicking an empty area
leaves a text field and closes an open dropdown. This happens before the
C<Mouse> event is fired.

See L<Term::Fabulous::Manual/KEYBOARD> and
L<Term::Fabulous::Manual/FOCUS>.

=head1 INLINE MODE

	my $ui = Term::Fabulous->new( root => $root, width => 80, height => 3, inline => 3 );
	$ui->run;
	say 'Done.';    # printed below the region

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

Every module has its own page. They are grouped here by purpose.

=head2 Application

=over

=item L<Term::Fabulous>

The interactive application object, described on this page.

=item L<Term::Fabulous::Static>

Renders a widget tree once, as text, without opening the terminal; for
reports, command-line output and tests.

=item L<Term::Fabulous::Layout>

Builds a widget tree from a KDL layout file and documents the layout
file format.

=back

=head2 Widgets

=over

=item L<Term::Fabulous::Widget::Box>

The general container, with layout options, a background and a border.

=item L<Term::Fabulous::Widget::Text>

Shows text in one color; wraps and aligns it.

=item L<Term::Fabulous::Widget::Button>

A box that can take the keyboard focus, shows when it is focused or
pressed, and fires C<Activate> for a click or Enter.

=item L<Term::Fabulous::Widget::Dialog>

A box that opens over the whole screen, keeps the keyboard focus inside
itself and closes on Escape.

=item L<Term::Fabulous::Widget::ScrollBox>

A box whose content can be larger than the box and scrolls with the
mouse wheel.

=item L<Term::Fabulous::Widget::Canvas>

A box with a grid of character cells that you draw into.

=item L<Term::Fabulous::Widget::PixelCanvas>

A canvas that draws pixels, two per cell, with lines, rectangles and
circles.

=item L<Term::Fabulous::Widget>

The abstract base class of all widgets except Text. Its page describes
the constructor parameters and methods they all share.

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

=item L<Term::Fabulous::Widget::Input>

The base class of the input widgets; derive from it to write your own.

=item L<Term::Fabulous::Widget::TextInput>

The base class of TextField and TextArea, with the editing keys and mouse
selection.

=item L<Term::Fabulous::Editor>

The text, cursor, selection, undo history and clipboard behind the text
inputs, without any drawing.

=item L<Term::Fabulous::Widget::Dropdown::List>

The list an open dropdown shows. Used internally by the dropdown.

=item L<Term::Fabulous::Widget::Dialog::Backdrop>

The layer behind an open dialog. Used internally by the dialog.

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

A dialog was closed.

=back

=head2 Colors, borders and text

=over

=item L<Term::Fabulous::Color>

Color values: parsing color strings, converting between RGB and HSL,
making colors lighter, darker or mixed.

=item L<Term::Fabulous::Enum::BorderStyle>

The 20 border styles and their characters.

=item L<Term::Fabulous::Role::HasBorderStyle>

The per-side border styles of a widget and how borders take space.

=item L<Term::Fabulous::Unicode>

How many terminal columns a piece of text takes, and how text is made
safe for the terminal.

=item L<Term::Fabulous::Enum::WebColor>

The 148 CSS named colors (C<Tomato>, C<SteelBlue>, ...) as
Term::Fabulous::Color objects.

=back

=head2 Extending Term::Fabulous

These modules matter only if you write widget classes that can be built
from layout files, or your own application or output class.

=over

=item L<Term::Fabulous::Role::CanParseLayout>

Makes a widget class usable in KDL layout files.

=item L<Term::Fabulous::Render>

The role that draws a laid-out widget tree; composed by Term::Fabulous
and Term::Fabulous::Static.

=item L<Term::Fabulous::Render::Target::Termbox>

Sends the drawn cells to the terminal.

=item L<Term::Fabulous::Termbox>

The termbox2 library itself, compiled into the distribution: the
C<tb_*> functions and C<TB_*> constants, and the width functions
L<Term::Fabulous::Unicode> measures with.

=item L<Term::Fabulous::Termbox::Event>

One termbox2 input event, as C<tb_peek_event> fills it.

=item L<Term::Fabulous::Render::Target::Grid>

Collects the drawn cells in memory.

=item L<Term::Fabulous::Render::Target::Mask>

Lets a frame keep cells of the previous frame, so unchanged canvases are
not drawn again.

=item L<Term::Fabulous::Render::Rectangle>

Draws backgrounds.

=item L<Term::Fabulous::Render::Border>

Draws borders.

=item L<Term::Fabulous::Render::Text>

Draws text.

=item L<Term::Fabulous::Render::Canvas>

Draws canvases, only their changed cells when possible.

=item L<Term::Fabulous::Render::Clip>

Restricts drawing to the visible part of scroll containers.

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

C<Alt> plus a key is recognized when the terminal sends the Escape and
the key in one write, which terminals do. C<Escape> followed quickly
by a key that arrives in the same read looks like C<Alt> plus that key.
C<Alt+[> and C<Alt+O> cannot be bound: they begin the escape sequences
of other keys.

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
default); every widget is one element and Term::Fabulous uses two
more. A larger tree makes drawing die with a message that names the
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
