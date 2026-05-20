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

class Term::Fabulous :isa(Clay::UI) :does(Term::Fabulous::Render) {
	field $loop :reader;
	field $termbox_poll_interval :reader = 1 / 10;
	field $termbox_draw_interval :reader = 1 / 10;

	method run() {
		$loop = IO::Async::Loop->new;

		$self->_init_signal_handlers();
		$self->_init_draw_timer();
		$self->_init_poll_timer();

		$loop->run;

		tb_shutdown();
	}

	method _init_poll_timer() {
		my $poll_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_poll_interval,
			on_tick => sub {
				my $ev = Termbox::Event->new();
				my $result = tb_peek_event( $ev, 0 );
				if($result == TB_ERR_NO_EVENT) {
					return;
				}
				if($result == TB_ERR_POLL) {
					tb_last_errno() == EINTR ? return : die "Error polling for events: $!";
					die "Error polling for events: $!";
				}

				$self->_handle_termbox_event($ev);
			},
		);
		$poll_timer->start;
		$loop->add($poll_timer);
	}

	method _init_draw_timer() {
		my $draw_timer = IO::Async::Timer::Periodic->new(
			interval => $termbox_draw_interval,
			on_tick => sub {
				$self->draw();
				return;
			},
		);
		$draw_timer->start;
		$loop->add($draw_timer);
	}

	method _init_signal_handlers() {
		my $term_signal = IO::Async::Signal->new(
			name => 'SIGTERM',
			on_receipt => sub {
				$loop->loop_stop;
			},
		);
		$loop->add($term_signal);
		my $int_signal = IO::Async::Signal->new(
			name => 'SIGINT',
			on_receipt => sub {
				$loop->loop_stop;
			},
		);
		$loop->add($int_signal);
	}

	method _handle_termbox_event($event) {
		return unless defined $event && defined $event->type;

		if($event->type == TB_EVENT_KEY) {
		 	$self->root->fire_event(Term::Fabulous::Event::KeyPress->of($event));
			if($event->key == 3 && $event->ch == 0) {
				$loop->loop_stop;
			}
		}

		elsif($event->type == TB_EVENT_RESIZE) {
			$self->root->fire_event(Term::Fabulous::Event::Resize->of($event));
			$self->width($event->w);
			$self->height($event->h);
			$self->root->fire_event(Term::Fabulous::Event::Resize->of($event, 1));
		}

		elsif($event->type == TB_EVENT_MOUSE) {
			$self->root->fire_event(Term::Fabulous::Event::Mouse->of($event));
		}
	}

}

1;
