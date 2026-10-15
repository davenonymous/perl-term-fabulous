#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Lite;    # exports TF
use Term::Fabulous::Widget::Table::Mutator qw(bytes datetime);

# The files of a directory in a table: a click on a title or s sorts,
# Tab reaches the filter row, Enter shows a file, q or Escape quits.
#
#     perl examples/cookbook/lite-table.pl            # the current directory
#     perl examples/cookbook/lite-table.pl ~/Pictures

my $directory = $ARGV[0] // '.';
opendir my $handle, $directory or die "Cannot read $directory: $!\n";
my @entries;
foreach my $name ( sort grep { !/\A\./ } readdir $handle ) {
	my $path = "$directory/$name";
	my @stat = stat $path or next;
	push @entries, {
		name     => $name,
		size     => -d $path ? undef : $stat[7],
		modified => $stat[9],
		kind     => -d $path ? 'folder' : $name =~ /\.(\w+)\z/ ? $1 : 'file',
	};
}
closedir $handle;

my $table = TF->table(
	id           => 'files',
	row_id       => 'name',
	rows         => \@entries,
	sort         => ['name'],
	filter_row   => 1,
	width        => 'grow',
	height       => 'grow',
	border       => 'Outer',
	column_lines => 'none',
	header_line  => 'none',
	stripe_color => '#1c2029',
	columns      => [
		{ key => 'name',     title => 'Name',     width => 'fit(24)', compare => 'natural' },
		{ key => 'size',     title => 'Size',     type  => 'number',  mutator => bytes() },
		{ key => 'modified', title => 'Modified', type  => 'date',    mutator => datetime('%Y-%m-%d %H:%M') },
		{ key => 'kind',     title => 'Kind' },
	],
	row_style => sub ( $row, $id ) { $row->{kind} eq 'folder' ? { text_color => '#61afef', bold => 1 } : undef },
);
my $status = TF->status_bar( scalar(@entries) . " entries in $directory", parts => [ [ 'Enter shows a file, Tab filters, q quits', 'dim' ] ] );

my $ui = TF->app( TF->screen( TF->column( width => 'grow', height => 'grow', padding => [ 1, 2 ], $table ), $status ), focus => $table, quit_keys => [qw(q Escape)] );

# Enter on a row opens a prompt with the details of the file.
$table->on(
	RowActivate => sub ($event) {
		my $row = $event->row;
		TF->alert(
			$ui,
			title   => $row->{name},
			message => sprintf(
				"[bold]%s[/]\n%s, modified %s", "$directory/$row->{name}", $row->{kind} eq 'folder' ? 'a folder' : $table->display_value( $row->{name}, 'size' ),
				$table->display_value( $row->{name}, 'modified' )
			),
		);
		return;
	}
);

$ui->run;
