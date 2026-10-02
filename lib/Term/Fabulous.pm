package Term::Fabulous;

use v5.22;
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
	use Clay::UI::Enum::Result;
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
	use POSIX qw(EINTR);
	use Term::Fabulous::Termbox qw(
		tb_init tb_shutdown tb_width tb_height tb_hide_cursor
		tb_set_input_mode tb_set_output_mode tb_get_fds tb_peek_event
		tb_last_errno tb_strerror
		TB_OK TB_ERR TB_ERR_NEED_MORE TB_ERR_NO_EVENT TB_ERR_POLL
		TB_EVENT_KEY TB_EVENT_MOUSE TB_EVENT_RESIZE
		TB_INPUT_ESC TB_INPUT_MOUSE
		TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN
		TB_KEY_CTRL_C TB_KEY_TAB TB_KEY_BACK_TAB TB_MOD_MOTION
	);
	use Term::Fabulous::Termbox::Event;
	use Term::Fabulous::Event::KeyPress;
	use Term::Fabulous::Event::Mouse;
	use Term::Fabulous::Event::Resize;
	use Term::Fabulous::Render::Geometry qw(cell_rect);
	use Term::Fabulous::Unicode qw(terminal_is_utf8);

	use constant WHEEL_NOTCH_ROWS => 3;

	field $mouse :param :reader = 1;
	field $loop :reader;
	field $termbox_draw_interval :reader            = 1 / 30;
	field $termbox_resize_debounce_interval :reader = 1 / 10;

	field $_terminal_is_open = 0;
	field @_notifiers;
	field $_resize_timer;
	field $_pending_resize;
	field $_pointer;             # the pointer state as last reported
	field @_pointer_queue;       # pointer states no frame has shown to Clay yet
	field $_wheel_rows = 0;      # wheel scrolling since the last frame

	sub BUILDARGS ( $class, %params ) {
		die "Term::Fabulous: measure_text cannot be replaced; text is always measured in terminal columns" if exists $params{measure_text};
		return %params;
	}

	ADJUST {
		die "Term::Fabulous: root must consume Clay::UI::Role::Events::Emitter to receive input events, got " . ref( $self->root )
			unless $self->root->DOES('Clay::UI::Role::Events::Emitter');
	}

	method pointer_state () {
		return undef unless defined $_pointer;
		return {%$_pointer};
	}

	method run () {
		warn "Term::Fabulous: the locale's character set is not UTF-8; wide characters will be misaligned\n"
			unless terminal_is_utf8();

		my $rc = tb_init();
		die "Term::Fabulous: tb_init failed: " . tb_strerror($rc) . "\n" unless $rc == TB_OK;
		$_terminal_is_open = 1;
		$self->invalidate_canvases;    # the fresh back buffer holds no canvas cells

		try {
			$self->_prepare_terminal;
			$loop = IO::Async::Loop->new;
			$self->_attach_notifiers;
			$loop->run;
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
		tb_shutdown();
		return;
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
		_check_termbox( 'tb_hide_cursor',     tb_hide_cursor() );

		my ( $width, $height ) = ( tb_width(), tb_height() );
		die "Term::Fabulous: the terminal reports an unusable size of ${width}x${height}\n"
			if $width < 1 || $height < 1;
		$self->width($width);
		$self->height($height);
		return;
	}

	method _attach_notifiers () {
		my $stop = sub { $loop->stop };

		$_resize_timer = IO::Async::Timer::Countdown->new(
			delay     => $termbox_resize_debounce_interval,
			on_expire => sub { $self->_fire_resize },
		);
		my $draw_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_draw_interval,
			on_tick  => sub { $self->_draw_frame },
		);
		$draw_timer->start;

		_check_termbox( 'tb_get_fds', tb_get_fds( \my $tty_fd, \my $resize_fd ) );
		my @input_watchers = map {
			IO::Async::Handle->new(
				read_handle   => _duplicate_for_reading($_),
				on_read_ready => sub { $self->_drain_termbox_events },
			)
		} ( $tty_fd, $resize_fd );

		@_notifiers = (
			IO::Async::Signal->new( name => 'TERM', on_receipt => $stop ),
			IO::Async::Signal->new( name => 'INT',  on_receipt => $stop ),
			$_resize_timer,
			$draw_timer,
			@input_watchers,
		);
		$loop->add($_) foreach @_notifiers;

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

	method _detach_notifiers () {
		foreach my $notifier (@_notifiers) {
			my $owner = $notifier->loop;
			$owner->remove($notifier) if defined $owner;
		}
		@_notifiers      = ();
		$_resize_timer   = undef;
		$_pending_resize = undef;
		$_wheel_rows     = 0;
		@_pointer_queue  = ();
		return;
	}

	method _draw_frame () {
		return if $_resize_timer->is_running;
		$self->_draw_pending;
		return;
	}

	# Clay takes one button state per frame, so every queued pointer state
	# gets a frame of its own; the wheel rows go with the first.
	method _draw_pending () {
		my @pointers = splice @_pointer_queue;
		push @pointers, $_pointer unless @pointers;
		my $rows = $_wheel_rows;
		$_wheel_rows = 0;

		foreach my $pointer (@pointers) {
			$_pointer = $pointer;
			$self->draw( scroll_cells => [ 0, $rows ] );
			$rows = 0;
		}
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
		my $target = $self->interaction->get_focused_widget // $self->root;
		$target->fire_event( Term::Fabulous::Event::KeyPress->of($event) );

		my ( $key, $is_special_key ) = ( $event->key, $event->ch == 0 );
		$loop->stop                        if $is_special_key && $key == TB_KEY_CTRL_C;
		$self->interaction->focus_next     if $is_special_key && $key == TB_KEY_TAB;
		$self->interaction->focus_previous if $is_special_key && $key == TB_KEY_BACK_TAB;
		return;
	}

	method _on_mouse ($event) {
		my ( $x, $y, $key ) = ( $event->x, $event->y, $event->key );
		my $newest = @_pointer_queue ? $_pointer_queue[-1] : $_pointer;
		my $down
			= $key == TB_KEY_MOUSE_LEFT    ? 1
			: $key == TB_KEY_MOUSE_RELEASE ? 0
			:                                ( defined $newest ? $newest->{down} : 0 );
		$_pointer = { x => $x, y => $y, down => $down };
		$self->_queue_pointer($_pointer);

		my $target = $self->_emitter_at( $x, $y ) // $self->root;
		$self->interaction->set_focused_widget( _focusable_at_or_above($target) )
			if $key == TB_KEY_MOUSE_LEFT && !( $event->mod & TB_MOD_MOTION );
		my $result = $target->fire_event( Term::Fabulous::Event::Mouse->of($event) );

		# A widget that scrolls itself has used the wheel notch.
		return if $result == Clay::UI::Enum::Result->HANDLED;
		$_wheel_rows += WHEEL_NOTCH_ROWS if $key == TB_KEY_MOUSE_WHEEL_UP;
		$_wheel_rows -= WHEEL_NOTCH_ROWS if $key == TB_KEY_MOUSE_WHEEL_DOWN;
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

		$_pending_resize = [ $width, $height ];
		$_resize_timer->is_running ? $_resize_timer->reset : $_resize_timer->start;
		return;
	}

	method _fire_resize () {
		return unless defined $_pending_resize;
		my ( $width, $height ) = @$_pending_resize;
		$_pending_resize = undef;

		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 0 ) );
		$self->width($width);
		$self->height($height);
		$self->root->fire_event( Term::Fabulous::Event::Resize->new( width => $width, height => $height, is_post_event => 1 ) );
		return;
	}

	# Topmost event emitter painted at the cell in the last frame.
	method _emitter_at ( $x, $y ) {
		my @commands   = $self->get_last_commands;
		my @clip_rects = $self->get_last_clip_rects;
		foreach my $index ( reverse 0 .. $#clip_rects ) {
			my $command = $commands[$index];
			next unless _command_paints_cell( $command, $clip_rects[$index], $x, $y );
			my $widget = $self->widget_for( $command->{userData} );
			return $widget if defined $widget && $widget->DOES('Clay::UI::Role::Events::Emitter');
		}
		return undef;
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
	$ui->run;    # returns after Ctrl+C, SIGINT or SIGTERM

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
percentage sizes, padding, gaps, alignment, borders in 21 styles.

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
terminal, runs the event loop, draws the screen 30 times per second and
dispatches input events. It is a subclass of L<Clay::UI>.

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

=item The F<examples> directory of the distribution

Runnable demo programs.

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
L</run> starts, then the terminal's height.

=item C<mouse>

A boolean. Default: 1. With 1, the terminal reports mouse clicks, drags
and the wheel to the program (see L<Term::Fabulous::Manual/MOUSE>). With
0, the terminal keeps the mouse for itself, so the user can select and
copy text as usual, and no C<Mouse> events are fired.

=item C<output_mode>

Optional, and only one value is allowed: C<TB_OUTPUT_TRUECOLOR> from
L<Term::Fabulous::Termbox>, the default. Any other value dies. Term::Fabulous always draws
with 24-bit colors.

=item C<memory_size>

Optional, rarely needed. The number of bytes Clay reserves for laying out
a frame: an integer of at least C<Clay::XS::Clay_MinMemorySize()> (about
6 MB), which is also the default. It does not raise the limit on the
number of widgets; see L</LIMITATIONS>.

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

Opens the terminal in full-screen mode, runs the event loop until it is
stopped, and restores the terminal. It returns nothing.

While it runs:

=over

=item *

the screen is laid out and drawn every 1/30 second (see
L</termbox_draw_interval>), using the real terminal size;

=item *

terminal input is read as soon as it arrives and dispatched as
C<KeyPress> and C<Mouse> events (see L</EVENTS>);

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

the process receives C<SIGINT> or C<SIGTERM>.

=back

If code running inside the loop dies (a listener, a timer), C<run>
restores the terminal first and then dies with the same error, so the
message is readable on the normal screen. The terminal is also restored
when code inside the loop calls C<exit>. After C<run> has returned or
died, the object can be used again and C<run> can be called again.

C<run> dies with a message starting with C<Term::Fabulous:> when the
terminal cannot be opened, for example when the process has no
controlling terminal (C<tb_init failed: No such device or address>), or
when the terminal reports a size of 0 columns or rows.

When the locale's character set is not UTF-8, C<run> warns (at every
call): C<Term::Fabulous: the locale's character set is not UTF-8; wide
characters will be misaligned>.

=head2 loop

	my $loop = $ui->loop;
	$ui->loop->stop;

Returns the L<IO::Async::Loop> of the most recent L</run>, or C<undef>
before the first C<run>. Call C<< $ui->loop->stop >> from a listener or
timer to end C<run>. The loop is IO::Async's process-wide loop: the same
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
while L</run> is active. Writing works like for L</width>. Inherited from
L<Clay::UI>.

=head2 mouse

	my $enabled = $ui->mouse;

Returns the C<mouse> constructor parameter. Read only.

=head2 output_mode

	my $mode = $ui->output_mode;    # TB_OUTPUT_TRUECOLOR

Returns the C<output_mode> constructor parameter, always
C<TB_OUTPUT_TRUECOLOR>. Read only.

=head2 pointer_state

	my $pointer = $ui->pointer_state;    # { x => 12, y => 3, down => 0 } or undef

Returns where the mouse pointer was last reported: a new hash reference
with the cell coordinates C<x> and C<y> and C<down>, which is 1 while the
left button is held and 0 otherwise. Returns C<undef> until the first
mouse event. The pointer is reported only on button presses, releases,
drags and wheel turns (see L<Term::Fabulous::Manual/What the terminal reports>),
so this is not the live mouse position. Term::Fabulous
passes it to Clay with every frame, which derives the hover and press
state of the widgets from it. When the button went down and up again
between two frames, each state gets a frame of its own, so a click is
never too fast to press a widget.

=head2 termbox_draw_interval

	my $seconds = $ui->termbox_draw_interval;    # 1/30

Returns the time between two frames in seconds: 1/30. Read only.

=head2 termbox_resize_debounce_interval

	my $seconds = $ui->termbox_resize_debounce_interval;    # 1/10

Returns how long, in seconds, the terminal size must stay unchanged
before a resize is applied and the C<Resize> events are fired: 1/10.
While a resize is pending, no frames are drawn. Read only.

=head2 draw

	$ui->draw;

Lays out and draws one frame immediately. C<run> calls it 30 times per
second, so programs do not need it. It only has a visible effect while
the terminal is open. See L<Term::Fabulous::Render/draw>.

=head2 Other inherited methods

The class inherits further methods from L<Clay::UI> (C<render>,
C<widget_for>, C<measure_text>) and from L<Term::Fabulous::Render>
(C<get_last_commands>, C<get_last_clip_rects>). Applications rarely need
them; they are documented on those pages.

=head1 EVENTS

C<run> fires these events. Each one bubbles from the widget it is fired
on to the root, as described in
L<Term::Fabulous::Manual/Return values and bubbling>.

=over

=item C<KeyPress> (L<Term::Fabulous::Event::KeyPress>)

For every key press, on the focused widget, or on the root widget when
nothing has the focus.

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

For every mouse report (button press, release, drag, wheel), on the
topmost widget that drew something in the cell under the pointer in the
last frame: its background, its border or its canvas. Text widgets are
skipped, and so are widgets that draw nothing there. When no widget
qualifies, the event is fired on the root widget. Content that is
scrolled out of view in a L<Term::Fabulous::Widget::ScrollBox> is not
drawn and never receives the event.

=item C<Resize> (L<Term::Fabulous::Event::Resize>)

On the root widget, twice per resize: first with C<is_pre_event> true,
before the new size is applied, then with C<is_post_event> true, after
it. Resizes are debounced (see L</termbox_resize_debounce_interval>),
and a size with zero columns or rows is ignored. No C<Resize> is fired
when C<run> starts and adopts the terminal's size; see
L<Term::Fabulous::Event::Resize>.

=back

Widgets fire further events themselves: C<Change> from the input
widgets, C<Submit> from L<Term::Fabulous::Widget::TextField>,
C<CanvasResize> from canvases, and Clay::UI's C<OnPress>, C<OnRelease>,
C<OnHoverStart>, C<OnHoverStopped>, C<OnFocus>, C<OnBlur> and
C<OnScroll>. The complete list is in
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

=head1 MOUSE WHEEL SCROLLING

Each notch of the mouse wheel scrolls the scroll box under the
pointer (for example a L<Term::Fabulous::Widget::ScrollBox>) by three
rows. Notches that arrive between two frames are added up and applied
when the next frame is drawn. A C<Mouse> event is fired for every notch
termbox2 reports (see L</LIMITATIONS> for reports it loses), before the
notch is counted: when a listener returns C<HANDLED> for it, the notch
scrolls no scroll box. Widgets that scroll themselves, like
L<Term::Fabulous::Widget::TextArea>, handle the wheel this way, so the
scroll box around them stays put while the pointer is over them. Only
vertical scrolling is driven by the wheel; there is no horizontal wheel
input.

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

A box that can take the keyboard focus and reports mouse clicks.

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

=back

=head2 Events

=over

=item L<Term::Fabulous::Event::KeyPress>

A key was pressed. Provides readable key names for key bindings.

=item L<Term::Fabulous::Event::Mouse>

A mouse button was pressed or released, the mouse was dragged, or the
wheel was turned.

=item L<Term::Fabulous::Event::Resize>

The terminal changed size.

=item L<Term::Fabulous::Event::CanvasResize>

A canvas got a new size from the layout.

=item L<Term::Fabulous::Event::Change>

The user changed the value of an input widget.

=item L<Term::Fabulous::Event::Submit>

The user pressed Enter in a text field.

=back

=head2 Colors, borders and text

=over

=item L<Term::Fabulous::Color>

Color values: parsing color strings, converting between RGB and HSL,
making colors lighter, darker or mixed.

=item L<Term::Fabulous::Enum::BorderStyle>

The 21 border styles and their characters.

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

The whole screen is laid out and drawn 30 times per second, also when
nothing changed. Only the cells that changed are sent to the terminal,
but very large widget trees cost CPU time.

=item *

termbox2 asks the terminal to report mouse buttons, drags and the wheel,
but not movement without a pressed button, so hover effects follow
clicks, drags and the wheel only.

=item *

When the terminal sends several mouse reports at once (for example
during fast wheel scrolling), termbox2 delivers only the first, so some
wheel notches and fast releases are lost.

=item *

C<Alt> plus a printable key cannot be told apart from C<Escape> followed
by that key.

=item *

There are no floating windows or dialogs for application use yet; only
the dropdown list floats over other widgets.

=item *

Clay lays out at most 8192 elements per frame; every widget is one
element and Term::Fabulous uses two more, so at most 8190 widgets can
be shown. A larger tree makes drawing die with a misleading Clay error
(C<There were still open layout elements when EndLayout was called>).
C<memory_size> does not change this limit.

=back

=head1 SEE ALSO

L<Term::Fabulous::Manual>, L<Term::Fabulous::Cookbook>, L<Clay::UI>,
L<Clay::XS>, L<Term::Fabulous::Termbox>, L<IO::Async>, L<Object::Pad>.

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
