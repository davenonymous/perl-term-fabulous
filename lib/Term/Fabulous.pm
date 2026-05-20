package Term::Fabulous;

use v5.22;

use Object::Pad 0.825;
use Termbox qw(:all);
use POSIX qw(:errno_h :signal_h);

use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Event::Resize;
use Term::Fabulous::Event::Mouse;
use IO::Async::Loop;
use IO::Async::Signal;
use IO::Async::Timer::Periodic;
use IO::Async::Timer::Countdown;

class Term::Fabulous :isa(Clay::UI) :does(Term::Fabulous::Render) {
	field $loop :reader;
	field $termbox_poll_interval :reader = 1 / 30;
	field $termbox_draw_interval :reader = 1 / 30;
	field $termbox_resize_debounce_interval :reader = 1 / 10;

	field $_resize_timer;
	field $_pending_resize_w;
	field $_pending_resize_h;

	method run() {
		$loop = IO::Async::Loop->new;

		$self->_init_signal_handlers();
		$self->_init_draw_timer();
		$self->_init_resize_debounce_timer();
		$self->_init_poll_timer();

		$loop->run;

		tb_shutdown();
	}

	method _init_poll_timer() {
		my $poll_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_poll_interval,
			on_tick => sub {
				while (1) {
					my $ev = Termbox::Event->new();
					my $result = tb_peek_event($ev, 0);
					if ($result == 0) {
						$self->_handle_termbox_event($ev);
						next;
					}
					last if $result == TB_ERR_NO_EVENT;
					if ($result == TB_ERR_POLL) {
						last if tb_last_errno() == EINTR;
						die "Error polling for events: $!";
					}
					die "Unexpected tb_peek_event result: $result";
				}
			},
		);
		$poll_timer->start;
		$loop->add($poll_timer);
	}

	method _init_draw_timer() {
		my $draw_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_draw_interval,
			on_tick => sub {
				return if $_resize_timer && $_resize_timer->is_running;
				$self->draw();
			},
		);
		$draw_timer->start;
		$loop->add($draw_timer);
	}

	method _init_resize_debounce_timer() {
		$_resize_timer = IO::Async::Timer::Countdown->new(
			delay => $termbox_resize_debounce_interval,
			on_expire => sub { $self->_fire_resize },
		);
		$loop->add($_resize_timer);
	}

	method _fire_resize() {
		return unless defined $_pending_resize_w && defined $_pending_resize_h;

		my $w = $_pending_resize_w;
		my $h = $_pending_resize_h;
		$_pending_resize_w = undef;
		$_pending_resize_h = undef;

		$self->root->fire_event(
			Term::Fabulous::Event::Resize->new(
				width => $w, height => $h, is_post_event => 0,
			)
		);
		$self->width($w);
		$self->height($h);
		$self->root->fire_event(
			Term::Fabulous::Event::Resize->new(
				width => $w, height => $h, is_post_event => 1,
			)
		);
	}

	method _init_signal_handlers() {
		my $term_signal = IO::Async::Signal->new(
			name => 'SIGTERM',
			on_receipt => sub { $loop->loop_stop },
		);
		$loop->add($term_signal);
		my $int_signal = IO::Async::Signal->new(
			name => 'SIGINT',
			on_receipt => sub { $loop->loop_stop },
		);
		$loop->add($int_signal);
	}

	method _handle_termbox_event($event) {
		return unless defined $event && defined $event->type;

		if ($event->type == TB_EVENT_KEY) {
			$self->root->fire_event(Term::Fabulous::Event::KeyPress->of($event));
			if ($event->key == 3 && $event->ch == 0) {
				$loop->loop_stop;
			}
		}
		elsif ($event->type == TB_EVENT_RESIZE) {
			my $w = $event->w;
			my $h = $event->h;
			my $dims_changed =
				!defined $_pending_resize_w
				|| $_pending_resize_w != $w
				|| $_pending_resize_h != $h;

			$_pending_resize_w = $w;
			$_pending_resize_h = $h;

			if ($dims_changed) {
				$_resize_timer->is_running ? $_resize_timer->reset : $_resize_timer->start;
			}
			elsif (!$_resize_timer->is_running) {
				$_resize_timer->start;
			}
		}
		elsif ($event->type == TB_EVENT_MOUSE) {
			$self->root->fire_event(Term::Fabulous::Event::Mouse->of($event));
		}
	}

}

1;
