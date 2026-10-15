#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Lite;    # exports TF
use Term::Fabulous::Widget::Table::Mutator qw(number);

# A deployment report printed to STDOUT: colored on a terminal, plain
# text in a pipe or a file.
#
#     perl examples/cookbook/lite-report.pl
#     perl examples/cookbook/lite-report.pl > report.txt

my @services = (
	{ name => 'web',    version => '2.14.0', status => 'running',  uptime => '14 days', requests => 2_310_442 },
	{ name => 'api',    version => '2.14.0', status => 'running',  uptime => '14 days', requests => 8_904_117 },
	{ name => 'worker', version => '2.13.2', status => 'degraded', uptime => '3 hours', requests => 410_280 },
	{ name => 'db',     version => '16.3',   status => 'running',  uptime => '41 days', requests => 0 },
);
my %disk = ( '/' => 71, '/home' => 88, '/var' => 46, '/srv' => 23 );
my @load = ( 0.4, 0.6, 0.5, 0.9, 1.4, 2.1, 1.8, 1.2, 0.9, 1.1, 1.6, 1.3, 0.8, 0.7, 0.6, 0.9, 1.0, 0.8 );

# A bar per file system; a nearly full one is red.
sub disk_row ($mount) {
	my $used = $disk{$mount};
	return TF->row( gap => 1, TF->box( width => 'fixed(6)', TF->text($mount) ), TF->progress_bar( value => $used, columns => 30, $used > 85 ? ( color => '#e06c75' ) : () ) );
}

my $report = TF->column(
	width => 'grow',
	gap   => 1,
	TF->text( 'Deployment report, 2026-06-01 09:41', bold => 1 ),
	TF->table(
		id           => 'services',
		row_id       => 'name',
		rows         => \@services,
		scrollbar    => 0,    # nothing scrolls on paper
		hover        => 0,
		border       => 'Round',
		column_lines => 'none',
		header_line  => 'none',
		header_style => { text_color => '#e5c07b' },
		columns      => [
			{ key => 'name',     title => 'Service' },
			{ key => 'version',  title => 'Version' },
			{ key => 'status',   title => 'Status' },
			{ key => 'uptime',   title => 'Uptime' },
			{ key => 'requests', title => 'Requests', type => 'number', mutator => number() },
		],
		row_style => sub ( $row, $id ) { $row->{status} eq 'degraded' ? { text_color => '#e5c07b', bold => 1 } : undef },
	),
	TF->column( TF->text( 'Disk usage', bold => 1 ), map { disk_row($_) } sort keys %disk ),
	TF->row(
		gap => 1,
		TF->text('Load, last 18 hours:'),
		TF->widget( 'Sparkline', type => 'bar', values => \@load, width => 'fixed(18)' ),
		TF->text( sprintf 'now %.1f', $load[-1] ),
	),
);

TF->print( $report, width => 64 );
