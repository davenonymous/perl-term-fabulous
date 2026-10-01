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
	use Clay::XS qw(
		CLAY_RENDER_COMMAND_TYPE_BORDER
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
	use Termbox 2 qw(
		tb_init tb_shutdown tb_width tb_height tb_hide_cursor
		tb_set_input_mode tb_set_output_mode tb_get_fds tb_peek_event
		tb_last_errno tb_strerror
		TB_OK TB_ERR TB_ERR_NEED_MORE TB_ERR_NO_EVENT TB_ERR_POLL
		TB_EVENT_KEY TB_EVENT_MOUSE TB_EVENT_RESIZE
		TB_INPUT_ESC TB_INPUT_MOUSE
		TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE
	);
	use Term::Fabulous::Event::KeyPress;
	use Term::Fabulous::Event::Mouse;
	use Term::Fabulous::Event::Resize;
	use Term::Fabulous::Render::Geometry qw(cell_rect);
	use Term::Fabulous::Unicode qw(terminal_is_utf8);

	# Termbox.pm exports no TB_KEY_CTRL_* constants.
	use constant KEY_CTRL_C => 0x03;

	field $mouse :param :reader = 1;
	field $loop :reader;
	field $termbox_draw_interval :reader            = 1 / 30;
	field $termbox_resize_debounce_interval :reader = 1 / 10;

	field $_terminal_is_open = 0;
	field @_notifiers;
	field $_resize_timer;
	field $_pending_resize;
	field $_pointer;

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

	# Rectangles and text paint their whole box, a border only its edges.
	sub _command_paints_cell ( $command, $x, $y ) {
		my ( $x0, $y0, $x1, $y1 ) = cell_rect( $command->{boundingBox} );
		return 0 unless $x >= $x0 && $x < $x1 && $y >= $y0 && $y < $y1;

		my $type = $command->{commandType};
		return 1 if $type == CLAY_RENDER_COMMAND_TYPE_RECTANGLE || $type == CLAY_RENDER_COMMAND_TYPE_TEXT;
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
		tb_hide_cursor();    # the Termbox binding returns no status for this call

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
		return;
	}

	method _draw_frame () {
		return if $_resize_timer->is_running;
		$self->draw;
		return;
	}

	method _drain_termbox_events () {
		while (1) {
			my $event = Termbox::Event->new;
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
		$loop->stop if $event->key == KEY_CTRL_C && $event->ch == 0;
		return;
	}

	method _on_mouse ($event) {
		my ( $x, $y, $key ) = ( $event->x, $event->y, $event->key );
		my $down
			= $key == TB_KEY_MOUSE_LEFT    ? 1
			: $key == TB_KEY_MOUSE_RELEASE ? 0
			:                                ( defined $_pointer ? $_pointer->{down} : 0 );
		$_pointer = { x => $x, y => $y, down => $down };

		my $target = $self->_emitter_at( $x, $y ) // $self->root;
		$target->fire_event( Term::Fabulous::Event::Mouse->of($event) );
		return;
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
		foreach my $command ( reverse $self->get_last_commands ) {
			next unless _command_paints_cell( $command, $x, $y );
			my $widget = $self->widget_for( $command->{userData} );
			return $widget if defined $widget && $widget->DOES('Clay::UI::Role::Events::Emitter');
		}
		return undef;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous - Terminal UIs from Clay layouts, drawn with termbox2

=head1 SYNOPSIS

	use Term::Fabulous;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Text;
	use Clay::XS qw(sizing_grow);

	my $root = Term::Fabulous::Widget::Box->new(
		background_color => [20, 25, 35, 255],
		layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);
	$root->add_child( Term::Fabulous::Widget::Text->new(text => 'Hello', text_color => [255, 255, 255, 255]) );
	$root->on( KeyPress => sub ($event) { ... } );

	my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
	$ui->run;   # returns after Ctrl+C, SIGINT or SIGTERM

=head1 DESCRIPTION

A L<Clay::UI> subclass that composes L<Term::Fabulous::Render>: it lays
out a widget tree with Clay and draws it into the terminal through
termbox2, redrawing continuously at 30 frames per second while
L</run> is active.

To render the same widget tree once, as text for a pipe or a report,
use L<Term::Fabulous::Static> instead; it paints with the same render
roles but never opens the terminal.

=head1 CONSTRUCTOR

=head2 new

	my $ui = Term::Fabulous->new(%params);

Unknown parameters die.

=over

=item C<root> (required)

The root widget. It must consume L<Clay::UI::Role::Events::Emitter>
(for example L<Term::Fabulous::Widget::Box>), otherwise the constructor
dies, because unhandled input events are delivered to it.

=item C<width>, C<height> (required)

Initial layout size in cells. L</run> replaces them with the terminal
size, and resizes keep them in sync.

=item C<output_mode>

Must be C<TB_OUTPUT_TRUECOLOR> (the default); see
L<Term::Fabulous::Render>.

=item C<mouse>

Boolean, default 1. Enables termbox2 mouse input (clicks, releases,
wheel and drag motion).

=item C<memory_size>, C<error_handler>

Passed to L<Clay::UI>. The measure-text callback is always the
terminal-cell measurement installed by L<Term::Fabulous::Render>.

=back

=head1 METHODS

=head2 run

Opens the terminal, runs the event loop until it is stopped, and closes
the terminal again. The terminal is initialized here, not in the
constructor: C<tb_init> and every terminal setup call are checked and
die with termbox2's error message. Once the terminal is open, it is
always restored (C<tb_shutdown>) and every watcher this object added to
the L<IO::Async::Loop> singleton is removed, whether the loop stops
normally, an exception escapes from a timer or an event handler, or an
event handler calls C<exit>. An exception is rethrown after the terminal
has been restored, so its message appears on the normal screen. C<run>
can therefore be called again later, and other code can keep using the
loop.

When the locale's character set is not UTF-8, C<run> warns once before
opening the terminal: termbox2 then cannot place wide characters.

Input is read when the terminal (or termbox2's resize pipe) becomes
readable; there is no polling timer.

=head2 pointer_state

C<undef> until the first mouse event, then C<< { x => ..., y => ..., down => 0|1 } >>.
A left-button press sets C<down>, a release clears it, wheel and other
buttons keep it. C<draw> passes it to Clay, which drives hover and
press state of L<Clay::UI::Role::Interaction::Hoverable> and
L<Clay::UI::Role::Interaction::Pressable> widgets.

=head2 loop

The L<IO::Async::Loop> used by the last L</run>.

=head2 mouse, termbox_draw_interval, termbox_resize_debounce_interval

Readers. The intervals are 1/30 s (redraw) and 1/10 s (resize debounce).

=head1 EVENTS

Every dispatch fires a freshly built event, which then bubbles up the
parent chain as described in L<Clay::UI::Role::Events::Emitter>.

=over

=item L<Term::Fabulous::Event::KeyPress>

Fired on the focused widget (C<< $ui->interaction->get_focused_widget >>),
or on the root when nothing has focus.

=item L<Term::Fabulous::Event::Mouse>

Fired on the topmost event emitter painted at the pointer's cell in the
last frame (a widget's background or text, or the edge cells of its
border), or on the root when there is none.

=item L<Term::Fabulous::Event::Resize>

Always fired on the root, twice per debounced terminal resize: once
before the new size is applied (C<is_pre_event>) and once after it.
Resizes to a zero width or height are ignored.

=back

Ctrl+C fires a KeyPress (key 3) and then stops the loop, so L</run>
returns.

=head1 SEE ALSO

L<Term::Fabulous::Static>, L<Term::Fabulous::Render>, L<Term::Fabulous::Layout>, L<Clay::UI>, L<Termbox>.

=head1 AUTHOR

davenonymous E<lt>perl@davenonymous.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2026 davenonymous

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
