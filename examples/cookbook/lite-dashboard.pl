#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use Time::HiRes ();

use Term::Fabulous::Lite;    # exports TF

# A dashboard that a timer feeds four times a second: a chart of the
# last minute of traffic, three gauges and a status bar. q or Escape
# quits.

my $traffic = TF->widget(
	'LineChart',
	title      => 'Traffic',
	x_axis     => { type => 'time', span => 60, format => '%H:%M:%S' },
	y_axis     => { min  => 0, title => 'Mbit/s' },
	max_points => 240,
	series     => [ { name => 'in', type => 'area', line => 1 }, { name => 'out' } ],
	width      => 'grow',
	height     => 'grow',
);
my %label  = ( cpu => 'CPU', memory => 'Memory', disk => 'Disk' );
my %gauge  = map { $_ => TF->progress_bar( value => 0, columns => 22 ) } qw(cpu memory disk);
my $status = TF->status_bar( 'Collecting the first measurements', parts => [ [ 'q quits', 'dim' ] ] );

my $root = TF->screen(
	TF->column(
		width   => 'grow',
		height  => 'grow',
		padding => [ 1, 2 ],
		gap     => 1,
		TF->text( 'Server dashboard', bold => 1 ),
		TF->row(
			gap    => 2,
			width  => 'grow',
			height => 'grow',
			$traffic,
			TF->column(
				border  => 'Round',
				padding => [ 0, 1 ],
				gap     => 1,
				width   => 'fixed(40)',
				TF->text( 'Resources', bold => 1 ),
				map { TF->row( gap => 1, TF->box( width => 'fixed(7)', TF->text( $label{$_} ) ), $gauge{$_} ) } qw(cpu memory disk),
			),
		),
	),
	$status,
);

# Made-up measurements: smooth curves with a little noise.
my $tick = 0;

sub measure () {
	$tick++;
	return (
		in     => 65 + 20 * sin( $tick / 23 ) + 8 * sin( $tick / 3.1 ) + 4 * sin( $tick * 1.7 ),
		out    => 18 + 6 * sin( $tick / 11 ) + 3 * sin( $tick * 2.3 ),
		cpu    => 45 + 35 * sin( $tick / 17 ) + 5 * sin( $tick * 1.3 ),
		memory => 62 + 4 * sin( $tick / 41 ),
		disk   => 71 + $tick / 400,
	);
}

my $timer = IO::Async::Timer::Periodic->new(
	interval => 0.25,
	on_tick  => sub {
		my %now = measure();
		$traffic->append( Time::HiRes::time(), { in => $now{in}, out => $now{out} } );
		$gauge{$_}->value( $now{$_} ) foreach qw(cpu memory disk);
		$gauge{cpu}->color( $now{cpu} > 75                                                                                    ? '#e06c75' : '#61afef' );
		$status->message( sprintf( 'In %.1f Mbit/s, out %.1f Mbit/s, CPU %d%%', @now{qw(in out)}, $now{cpu} ), $now{cpu} > 75 ? 'warning' : 'info' );
		return;
	},
);
$timer->start;
IO::Async::Loop->new->add($timer);

TF->run( $root, quit_keys => [qw(q Escape)] );
