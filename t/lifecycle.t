use v5.22;
use warnings;

use Test2::V0;

use IO::Async::Loop;
use IO::Async::Signal;
use Fcntl qw(F_GETFL O_NONBLOCK);
use Scalar::Util qw(weaken);
use Termbox 2 qw(TB_OK TB_ERR_INIT_OPEN TB_ERR_NO_EVENT TB_EVENT_KEY);
use Term::Fabulous;
use Term::Fabulous::Widget::Box;

# termbox is replaced by stubs; the "terminal" input is a pipe we control.
pipe my $tty_read,    my $tty_write    or die "pipe: $!";
pipe my $resize_read, my $resize_write or die "pipe: $!";

my %calls;
my $init_result = TB_OK;
my $draw_dies   = 0;
my @queued_events;
my $tty_was_nonblocking;

{
	no strict 'refs';
	no warnings 'redefine';
	my %termbox_stubs = (
		tb_init            => sub { $calls{tb_init}++;     $init_result },
		tb_shutdown        => sub { $calls{tb_shutdown}++; return },
		tb_strerror        => sub { "stub error $_[0]" },
		tb_width           => sub {20},
		tb_height          => sub {5},
		tb_hide_cursor     => sub {return},
		tb_set_input_mode  => sub {TB_OK},
		tb_set_output_mode => sub {TB_OK},
		tb_get_fds         => sub { ${ $_[0] } = fileno $tty_read; ${ $_[1] } = fileno $resize_read; TB_OK },
		tb_peek_event      => sub {
			my ($event) = @_;
			$tty_was_nonblocking = fcntl( $tty_read, F_GETFL, 0 ) & O_NONBLOCK ? 1 : 0;
			my $queued = shift @queued_events // return TB_ERR_NO_EVENT;
			$event->$_( $queued->{$_} ) foreach keys %$queued;
			return TB_OK;
		},
	);
	*{"Term::Fabulous::$_"} = $termbox_stubs{$_} foreach keys %termbox_stubs;

	*Term::Fabulous::Render::tb_clear   = sub { die "draw failed\n" if $draw_dies; return };
	*Term::Fabulous::Render::tb_present = sub {return};
	*Term::Fabulous::Render::Rectangle::tb_print = sub {0};
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
	@queued_events = ( { type => TB_EVENT_KEY, key => 3, ch => 0 } );    # Ctrl+C
	syswrite $tty_write, 'x';                                              # makes the terminal readable

	ok lives { $ui->run }, 'run returns after Ctrl+C';
	is $tty_was_nonblocking, 0, "termbox's descriptor stays blocking while it is watched";
	is $calls{tb_shutdown}, 2, 'the terminal is restored again';
	is scalar( $loop->notifiers ), $notifiers_before, 'no notifier is left on the loop';
};

subtest 'nothing pins the object after run' => sub {
	weaken( my $weak = $ui );
	undef $ui;
	ok !defined $weak, 'Term::Fabulous is freed';
};

subtest 'tb_init failure' => sub {
	$init_result = TB_ERR_INIT_OPEN;
	my $failing = Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new );
	like dies { $failing->run }, qr/^Term::Fabulous: tb_init failed: stub error -4/, 'dies with the termbox error';
	is $calls{tb_shutdown}, 2, 'no shutdown without a successful init';
};

done_testing;
