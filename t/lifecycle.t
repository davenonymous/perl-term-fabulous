use v5.24;
use warnings;

use Test2::V0;
use Feature::Compat::Try;

use IO::Async::Loop;
use IO::Async::Signal;
use Fcntl qw(F_GETFL O_NONBLOCK);
use POSIX qw(EINTR EIO);
use Scalar::Util qw(weaken);
use Term::Fabulous::Termbox qw(TB_OK TB_ERR_INIT_OPEN TB_ERR_NO_EVENT TB_ERR_POLL TB_ERR_READ TB_EVENT_KEY TB_EVENT_RESIZE);
use Term::Fabulous;
use Term::Fabulous::Widget::Box;

# termbox is replaced by stubs; the "terminal" input is a pipe we control.
pipe my $tty_read,    my $tty_write    or die "pipe: $!";
pipe my $resize_read, my $resize_write or die "pipe: $!";

my %calls;
my $init_result = TB_OK;
my $draw_dies   = 0;
my @queued_events;    # termbox event fields, or [ status, errno ] for a failure
my $last_errno = 0;
my $tty_was_nonblocking;

# Empties the pipe that stands for the terminal, as termbox reads it.
sub drain_tty {
	vec( my $readable = '', fileno $tty_read, 1 ) = 1;
	sysread $tty_read, my $bytes, 4096 while select( my $ready = $readable, undef, undef, 0 ) > 0 && !eof_reached();
	return;
}

sub eof_reached { return Term::Fabulous::Termbox::tf_readable_bytes( fileno $tty_read ) == 0 }

{
	no strict 'refs';
	no warnings 'redefine';
	my %termbox_stubs = (
		tb_init            => sub { $calls{tb_init}++;     $init_result },
		tb_shutdown        => sub { $calls{tb_shutdown}++; return },
		tb_strerror        => sub { "stub error $_[0]" },
		tb_width           => sub {20},
		tb_height          => sub {5},
		tb_hide_cursor     => sub {TB_OK},
		tb_set_input_mode  => sub {TB_OK},
		tb_set_output_mode => sub {TB_OK},
		tb_send            => sub {TB_OK},
		tf_install_input_parser => sub {TB_OK},
		tb_get_fds         => sub { ${ $_[0] } = fileno $tty_read; ${ $_[1] } = fileno $resize_read; TB_OK },
		tb_last_errno      => sub {$last_errno},
		tb_peek_event      => sub {
			my ($event) = @_;
			$tty_was_nonblocking = fcntl( $tty_read, F_GETFL, 0 ) & O_NONBLOCK ? 1 : 0;
			my $queued = shift @queued_events;
			if ( !defined $queued ) {
				drain_tty();
				return TB_ERR_NO_EVENT;
			}
			if ( ref $queued eq 'ARRAY' ) {
				( my $status, $last_errno ) = @$queued;
				return $status;
			}
			$event->$_( $queued->{$_} ) foreach keys %$queued;
			return TB_OK;
		},
	);
	*{"Term::Fabulous::$_"} = $termbox_stubs{$_} foreach keys %termbox_stubs;

	*Term::Fabulous::Render::Target::Termbox::tb_clear   = sub { die "draw failed\n" if $draw_dies; return };
	*Term::Fabulous::Render::Target::Termbox::tb_present = sub { $calls{tb_present}++; return };
	*Term::Fabulous::Render::Target::Termbox::tb_print = sub {0};
}

my $loop = IO::Async::Loop->new;

# IO::Async adds its own signal-pipe handle on the first signal watch and
# keeps it for the loop's lifetime; create it before taking the snapshot.
my $warmup_signal = IO::Async::Signal->new( name => 'HUP', on_receipt => sub { } );
$loop->add($warmup_signal);
$loop->remove($warmup_signal);
my $notifiers_before = scalar $loop->notifiers;
my $ui               = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );

subtest 'a draw that dies' => sub {
	$draw_dies = 1;
	like dies { $ui->run }, qr/^draw failed/, 'the exception propagates out of run';
	is $calls{tb_shutdown}, 1, 'the terminal is restored exactly once';
	is scalar( $loop->notifiers ), $notifiers_before, 'no notifier is left on the loop';
};

subtest 'a second run works' => sub {
	$draw_dies     = 0;
	my @starts;
	$ui->root->on( Start => sub { push @starts, [ $_[0]->width, $_[0]->height, $ui->width ]; return } );
	@queued_events = ( { type => TB_EVENT_KEY, key => 3, ch => 0 } );    # Ctrl+C
	syswrite $tty_write, 'x';                                              # makes the terminal readable

	ok lives { $ui->run }, 'run returns after Ctrl+C';
	is $tty_was_nonblocking, 0, "termbox's descriptor stays blocking while it is watched";
	is \@starts, [ [ 20, 5, 20 ] ], 'Start fires once, with the terminal size already applied';
	is $calls{tb_shutdown}, 2, 'the terminal is restored again';
	is scalar( $loop->notifiers ), $notifiers_before, 'no notifier is left on the loop';
};

subtest 'Start fires inside the running loop' => sub {
	my $handler = sub { };
	local $SIG{INT}  = $handler;
	local $SIG{HUP}  = 'IGNORE';
	my $loop_in_start;
	my $start = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	$start->root->on( Start => sub { $loop_in_start = $start->loop; $start->loop->stop; return } );

	my $presents_before = $calls{tb_present} // 0;
	my $presents_at_start;
	$start->root->on( Start => sub { $presents_at_start = $calls{tb_present} // 0; return } );
	ok lives { $start->run }, 'a Start listener can stop the loop';
	ref_is $loop_in_start, $loop, 'and sees it';
	is $presents_at_start, $presents_before, 'no frame is drawn before Start';
	ref_is $SIG{INT}, $handler, 'run gives back the INT handler it found';
	is $SIG{HUP}, 'IGNORE', 'and the HUP setting';
	is scalar( $loop->notifiers ), $notifiers_before, 'no notifier is left on the loop';
};

subtest 'a signal watcher of the program outlives run' => sub {
	my $received = 0;
	my $watcher  = IO::Async::Signal->new( name => 'TERM', on_receipt => sub { $received++ } );
	my $watching = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	$watching->root->on( Start => sub { $watching->loop->add($watcher); $watching->loop->stop; return } );
	$watching->run;
	kill TERM => $$;
	$loop->loop_once(0.1);
	is $received, 1, 'IO::Async still handles the signal it watches';
	$loop->remove($watcher);
};

subtest 'INT, TERM and HUP end run' => sub {
	foreach my $signal (qw(INT TERM HUP)) {
		my $signalled = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
		$signalled->root->on( Start => sub { kill $signal => $$; return } );
		ok lives { $signalled->run }, "run returns after SIG$signal";
	}
};

subtest 'a resize' => sub {
	my $resizing = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	my ( @resizes, $presents_at_input, $invalidated );
	$resizing->root->on(
		Resize => sub {
			my ($event) = @_;
			push @resizes, [ $event->width, $event->height, $event->is_post_event, $resizing->width ];
			$resizing->loop->stop if $event->is_post_event;
			return;
		}
	);
	@queued_events = (
		{ type => TB_EVENT_RESIZE, w => 10, h => 3 },
		{ type => TB_EVENT_RESIZE, w => 0,  h => 0 },
		{ type => TB_EVENT_RESIZE, w => 30, h => 8 },
	);
	$resizing->root->on( Start => sub { $presents_at_input = $calls{tb_present} // 0; syswrite $tty_write, 'x'; return } );
	{
		my $original = \&Term::Fabulous::invalidate_canvases;
		no warnings 'redefine';
		local *Term::Fabulous::invalidate_canvases = sub { $invalidated++; return $original->(@_) };
		ok lives { $resizing->run }, 'run returns';
	}

	is \@resizes, [ [ 30, 8, 0, 20 ], [ 30, 8, 1, 30 ] ], 'one Resize pair for the last usable size, the size applied in between';
	is $calls{tb_present} // 0, $presents_at_input, 'no frame is drawn while the size settles';
	ok $invalidated >= 2, 'every reported size makes termbox rebuild its cells, so no canvas is kept';
};

subtest 'inline mode' => sub {
	my $box = sub { Term::Fabulous::Widget::Box->new };
	like dies { Term::Fabulous->new( width => 20, height => 5, root => $box->(), inline => 0 ) }, qr/inline must be a whole number of rows of at least 1, got '0'/, 'inline needs rows';
	like dies { Term::Fabulous->new( width => 20, height => 5, root => $box->(), inline => 3, mouse => 1 ) }, qr/inline mode has no mouse support/, 'and has no mouse';
	my $inline = Term::Fabulous->new( width => 20, height => 5, root => $box->(), inline => 3 );
	is $inline->mouse, 0, 'the mouse is off by default';

	# The stubbed terminal has 5 rows; the cursor is reported as [column, row].
	my ( $sent, $cursor, @seen ) = ( '', [ 4, 4 ] );
	no warnings 'redefine';
	local *Term::Fabulous::tf_init_inline     = sub { $calls{tf_init_inline}++; TB_OK };
	local *Term::Fabulous::tf_cursor_position = sub {
		return TB_ERR_NO_EVENT unless defined $cursor;
		( ${ $_[1] }, ${ $_[2] } ) = @$cursor;
		return TB_OK;
	};
	local *Term::Fabulous::tf_reset_attrs     = sub {TB_OK};
	local *Term::Fabulous::tb_clear           = sub {TB_OK};
	local *Term::Fabulous::tb_send            = sub { $sent .= $_[0]; TB_OK };

	$inline->root->on( Start => sub { push @seen, [ $_[0]->height, $inline->termbox_inline_top ]; $inline->loop->stop; return } );
	my $presents = $calls{tb_present} // 0;
	ok lives { $inline->run }, 'run returns';
	is $calls{tf_init_inline}, 1, 'the terminal is opened inline';
	is $calls{tb_present}, $presents + 1, 'the state the loop stopped in is drawn before run returns';
	is \@seen, [ [ 3, 2 ] ], 'Start reports the rows of the region, moved up to fit the screen';
	is $sent, "\e[5;1H\n\n\n" . "\e[3;1H\e[J" . "\e[5;1H\n", 'the terminal scrolls, the region is erased, and the shell goes on below its last row';
	is $inline->termbox_inline_top, undef, 'the region is forgotten after run';

	my $resizing = Term::Fabulous->new( width => 20, height => 5, root => $box->(), inline => 3 );
	( $sent, $cursor, @seen ) = ( '', [ 0, 0 ] );
	@queued_events = ( { type => TB_EVENT_RESIZE, w => 30, h => 8 } );
	$resizing->root->on( Start => sub { $cursor = [ 0, 1 ]; syswrite $tty_write, 'x'; return } );
	$resizing->root->on(
		Resize => sub {
			return unless $_[0]->is_post_event;
			push @seen, [ $_[0]->width, $_[0]->height, $resizing->termbox_inline_top ];
			$resizing->loop->stop;
			return;
		}
	);
	ok lives { $resizing->run }, 'run returns after a resize';
	is \@seen, [ [ 30, 3, 1 ] ], 'the region is found again where the terminal moved the cursor';

	$cursor = undef;
	like dies { $inline->run }, qr/^Term::Fabulous: the terminal did not report its cursor position/, 'a terminal that does not answer ends run';
};

subtest 'terminal input errors' => sub {
	my $reading = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	$reading->root->on( Start => sub { syswrite $tty_write, 'x'; return } );
	@queued_events = ( [ TB_ERR_POLL, EINTR ], { type => TB_EVENT_KEY, key => 3, ch => 0 } );
	ok lives { $reading->run }, 'an interrupted poll is retried';

	@queued_events = ( [ TB_ERR_READ, EIO ] );
	like dies { $reading->run }, qr/^Term::Fabulous: reading terminal input failed: stub error -\d+/, 'any other error ends run';
	@queued_events = ();
	drain_tty();

	pipe my $closed_read, my $closed_write or die "pipe: $!";
	close $closed_write;
	my $open_read = $tty_read;
	$tty_read = $closed_read;
	like dies { $reading->run }, qr/^Term::Fabulous: the terminal was closed/, 'the end of the terminal input ends run';
	$tty_read = $open_read;
	is scalar( $loop->notifiers ), $notifiers_before, 'no notifier is left on the loop';
};

subtest 'end of input' => sub {
	pipe my $read, my $write or die "pipe: $!";
	ok !Term::Fabulous::_input_is_at_eof($read), 'nothing to read yet';
	syswrite $write, 'a';
	ok !Term::Fabulous::_input_is_at_eof($read), 'a byte to read';
	sysread $read, my $byte, 1;
	close $write;
	ok Term::Fabulous::_input_is_at_eof($read), 'readable with nothing to read: end of file';

	try { require IO::Pty }
	catch ($error) { skip_all 'IO::Pty is not installed' }
	my $pty      = IO::Pty->new;
	my $terminal = $pty->slave;
	ok !Term::Fabulous::_input_is_at_eof($terminal), 'a live terminal';
	close $pty;
	ok Term::Fabulous::_input_is_at_eof($terminal), 'a terminal that hung up';
};

subtest 'nothing pins the object after run' => sub {
	weaken( my $weak = $ui );
	undef $ui;
	ok !defined $weak, 'Term::Fabulous is freed';
};

subtest 'tb_init failure' => sub {
	$init_result = TB_ERR_INIT_OPEN;
	my $shutdowns = $calls{tb_shutdown};
	my $failing   = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	like dies { $failing->run }, qr/^Term::Fabulous: tb_init failed: stub error -4/, 'dies with the termbox error';
	is $calls{tb_shutdown}, $shutdowns, 'no shutdown without a successful init';
};

done_testing;
