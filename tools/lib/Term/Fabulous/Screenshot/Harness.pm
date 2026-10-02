package Term::Fabulous::Screenshot::Harness;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use JSON::PP ();
use Term::Fabulous::Screenshot::Clock;

# The configuration, written by Term::Fabulous::Screenshot::Runner.
use constant CONFIG_VARIABLE => 'TF_SCREENSHOT_HARNESS';

my $config;

BEGIN {
	my $json = $ENV{ CONFIG_VARIABLE() } // die "Term::Fabulous::Screenshot::Harness: " . CONFIG_VARIABLE() . " is not set; the harness runs only under Term::Fabulous::Screenshot::Runner\n";
	$config = JSON::PP->new->utf8->decode($json);
	Term::Fabulous::Screenshot::Clock::install( $config->{epoch} );
}

use IO::Async::Loop;
use Term::Fabulous::Screenshot::VirtualLoop;
use Term::Fabulous::Termbox qw(tb_width tb_height tb_get_cell tb_cluster_width TB_OK);

# Virtual seconds the program gets after each input before the next step,
# enough for several frames at Term::Fabulous's 30 frames per second.
use constant INPUT_PAUSE_SECONDS => 0.1;

# Real seconds the terminal may take to deliver input before the harness
# gives up.
use constant INPUT_DELIVERY_TIMEOUT => 5;

# A terminal holds at most 4095 unread input bytes; a step must fit.
use constant MAX_SEND_BYTES => 4095;

# Created before the program runs, so IO::Async::Loop->new returns it to
# the program and to Term::Fabulous.
my $loop = Term::Fabulous::Screenshot::VirtualLoop->new;
die "Term::Fabulous::Screenshot::Harness: IO::Async::Loop->new does not return the virtual loop\n"
	unless IO::Async::Loop->new == $loop;

my $input = _open_input( $config->{input_fd} );

# The steps start when the program's event loop does, which for a
# Term::Fabulous program is after the terminal has been opened.
$loop->watch_time(
	after => 0,
	code  => sub {
		_mark_started();
		_run_steps( @{ $config->{steps} } );
	}
);

# Tells the runner the event loop ran, so a program that ends before the
# screenshot is reported as such.
sub _mark_started () {
	open my $marker, '>', "$config->{capture_file}.started" or die "Term::Fabulous::Screenshot::Harness: cannot write $config->{capture_file}.started: $!\n";
	close $marker;
	return;
}

sub _open_input ($fd) {
	open my $handle, '>&=', $fd or die "Term::Fabulous::Screenshot::Harness: cannot open the terminal input (file descriptor $fd): $!\n";
	binmode $handle;
	return $handle;
}

sub _run_steps (@steps) {
	my $step = shift @steps;
	return _capture_screen() unless defined $step;

	my $continue = sub { _run_steps(@steps) };
	if ( $step->{action} eq 'wait' ) {
		$loop->watch_time( after => $step->{seconds}, code => $continue );
		return;
	}
	if ( $step->{action} eq 'send' ) {
		_send_to_terminal( pack 'H*', $step->{bytes} );
		$loop->watch_time( after => INPUT_PAUSE_SECONDS, code => $continue );
		return;
	}
	die "Term::Fabulous::Screenshot::Harness: unknown step action '$step->{action}'\n";
}

# Writes the bytes as the terminal would, then waits in real time until
# they can be read, so the program sees them before the clock moves on.
sub _send_to_terminal ($bytes) {
	die "Term::Fabulous::Screenshot::Harness: a step sends " . length($bytes) . " bytes, more than the terminal can hold (" . MAX_SEND_BYTES . ")\n"
		if length($bytes) > MAX_SEND_BYTES;
	my $offset = 0;
	while ( $offset < length $bytes ) {
		my $written = syswrite( $input, $bytes, length($bytes) - $offset, $offset );
		die "Term::Fabulous::Screenshot::Harness: writing to the terminal failed: $!\n" unless defined $written;
		$offset += $written;
	}

	my $started = CORE::time();    # the real clock: CORE:: bypasses the virtual one
	until ( _pending_input_bytes() >= length $bytes ) {
		die "Term::Fabulous::Screenshot::Harness: the terminal did not deliver the input within " . INPUT_DELIVERY_TIMEOUT . " seconds\n"
			if CORE::time() - $started > INPUT_DELIVERY_TIMEOUT;
		select( undef, undef, undef, 0.001 );
	}
	return;
}

# Bytes waiting to be read on the terminal, which is the program's STDIN.
sub _pending_input_bytes () {
	require 'sys/ioctl.ph';
	my $count = pack 'L', 0;
	ioctl( STDIN, FIONREAD(), $count ) or die "Term::Fabulous::Screenshot::Harness: FIONREAD on the terminal failed: $!\n";
	return unpack 'L', $count;
}

# Reads what the terminal shows from termbox2's front buffer: the cells
# of the last frame Term::Fabulous presented.
sub _capture_screen () {
	my ( $columns, $rows ) = ( tb_width(), tb_height() );
	die "Term::Fabulous::Screenshot::Harness: the program has not opened the terminal; only Term::Fabulous programs can be captured while they run\n"
		unless $columns > 0 && $rows > 0;

	my @screen = map { _capture_row( $_, $columns ) } 0 .. $rows - 1;
	my $capture = { columns => $columns, rows => $rows, cells => \@screen };

	open my $file, '>', $config->{capture_file} or die "Term::Fabulous::Screenshot::Harness: cannot write $config->{capture_file}: $!\n";
	print {$file} JSON::PP->new->utf8->canonical->encode($capture);
	close $file or die "Term::Fabulous::Screenshot::Harness: cannot write $config->{capture_file}: $!\n";

	$loop->stop;
	return;
}

# One row as [ glyph, columns, fg, bg ] per visible character. termbox2
# draws a wide character that does not fit at the end of a row as spaces.
sub _capture_row ( $y, $columns ) {
	my @cells;
	my $x = 0;
	while ( $x < $columns ) {
		my ( $status, $glyph, $fg, $bg ) = tb_get_cell( $x, $y, 0 );
		die "Term::Fabulous::Screenshot::Harness: tb_get_cell($x, $y) failed with status $status\n" unless $status == TB_OK;
		$glyph = ' ' unless length $glyph;

		my $width = tb_cluster_width($glyph);
		$width = 1 if $width < 1;
		if ( $x + $width > $columns ) {
			push @cells, [ ' ', 1, $fg, $bg ] foreach $x .. $columns - 1;
			last;
		}
		push @cells, [ $glyph, $width, $fg, $bg ];
		$x += $width;
	}
	return \@cells;
}

1;

__END__

=head1 NAME

Term::Fabulous::Screenshot::Harness - Runs inside an example program to
replay input and capture the screen

=head1 SYNOPSIS

	# Started by Term::Fabulous::Screenshot::Runner, never by hand:
	TF_SCREENSHOT_HARNESS='{...}' perl -MTerm::Fabulous::Screenshot::Harness examples/form.pl

=head1 DESCRIPTION

Maintainer tool, not installed. L<Term::Fabulous::Screenshot::Runner>
starts every example program with this module loaded first, in a
pseudo terminal. Loading it:

=over

=item *

installs the virtual clock (L<Term::Fabulous::Screenshot::Clock>) at the
configured start time, before any other module is compiled;

=item *

creates a L<Term::Fabulous::Screenshot::VirtualLoop>, which becomes the
loop C<< IO::Async::Loop->new >> returns, so the program's timers and
Term::Fabulous's frames run in virtual time;

=item *

schedules the steps: once the program runs its event loop, they wait
or write input into the terminal, in order. After writing, the harness
waits in real time until the terminal has delivered the bytes and then
gives the program 0.1 virtual seconds before the next step.

=back

After the last step it reads every cell of termbox2's front buffer
(what the terminal shows), writes them as JSON to the capture file and
stops the event loop, so the program ends as if the user had quit.

A program that never runs an event loop (one that prints a report with
L<Term::Fabulous::Static>, for example) is not affected: it prints and
ends, and the runner takes the screenshot from its output.

=head1 CONFIGURATION

The environment variable C<TF_SCREENSHOT_HARNESS> holds a JSON object:

=over

=item C<epoch>

The start time of the virtual clock, in epoch seconds.

=item C<steps>

An array of C<{ "action": "wait", "seconds": N }> and
C<{ "action": "send", "bytes": HEX }> objects.

=item C<input_fd>

The file descriptor of the pseudo terminal's master side, to write
input to.

=item C<capture_file>

Where to write the captured screen (and, next to it with C<.started>
appended, an empty file once the event loop runs): C<{ columns, rows, cells }>, with
one array per row of C<[ glyph, columns, fg, bg ]> arrays, the
attributes as termbox2 stores them.

=back

=cut
