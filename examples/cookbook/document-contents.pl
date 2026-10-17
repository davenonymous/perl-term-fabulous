#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use My::MiniMark;
use Term::Fabulous;
use Term::Fabulous::Layout;

my $root = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::RichText as RichText
use Term::Fabulous::Widget::DocumentView as DocumentView

Box "root" {
	sizing width=grow height=grow

	Box "contents-pane" {
		sizing width="fixed(34)" height=grow
		padding left=1 right=1
		border style=Round
		bordered #true
		RichText "contents" { text ""; }
	}

	// The view is framed by a box around it rather than by a border of its
	// own, as its documentation advises.
	Box "page-pane" {
		sizing width=grow height=grow
		border style=Round
		bordered #true
		DocumentView "manual" {
			sizing width=grow height=grow
			padding left=1 right=1
			indent 2
		}
	}
}
KDL

my $view     = $root->find_by_id('manual');
my $contents = $root->find_by_id('contents');
my $document = My::MiniMark->parse_file("$FindBin::Bin/documents/snapback.md");
$view->document($document);

# One line per heading, indented by its level, each a link to its
# section number; a mark in front of the section the reader is in.
sub show_contents ($current) {
	my @lines = map {
		my $heading = $document->heading_of_section($_);
		my $title   = $heading->text =~ s/\[/\\[/gr;
		my $mark    = defined $current && $current == $_ ? '[bold]>[/] ' : '  ';
		$mark . '  ' x ( $heading->level - 1 ) . "[link=$_]$title\[/link]";
	} 0 .. $document->heading_indexes - 1;
	$contents->markup( join "\n", @lines );
	return;
}
show_contents(undef);

# The view reports the section at its top after every frame that shows
# something new; the contents follow it.
my $shown_section = -1;
$view->on(
	ViewChange => sub ($event) {
		my $section = $event->section // -1;
		return if $section == $shown_section;
		$shown_section = $section;
		show_contents( $event->section );
		return;
	}
);

# A click on a heading, or Enter on the selected one, shows its section.
$contents->on(
	LinkActivate => sub ($event) {
		$view->show_block( $document->block_of_section( $event->link ) );
		return;
	}
);

my $ui = Term::Fabulous->new( root => $root, width => 100, height => 26 );
$ui->interaction->set_focused_widget($view);
$ui->run;
