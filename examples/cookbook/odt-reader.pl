#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Odt/*.pm live

use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use My::Odt::Parser;
use My::Odt::View;
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::StatusBar;

my $file     = shift // "$FindBin::Bin/documents/pancakes.odt";
my $document = My::Odt::Parser->parse_file($file);

my $view = My::Odt::View->new(
	id       => 'document',
	document => $document,
	layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $where  = '';
my $status = Term::Fabulous::Widget::StatusBar->new(
	message => 'l selects a link, Enter follows it',
	timeout => 4,
	parts   => sub { return ( [ $where, 'dim' ] ) },
);

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $view, $status );

$view->on(
	ViewChange => sub ($event) {
		$where = sprintf '%s  %d%%', $event->section_title // 'Top', $event->percent;
		return;
	}
);

# LibreOffice writes a link to a heading as "#Heading|outline", a link to
# a bookmark as "#Name"; anything else is an address for a browser.
$view->on(
	LinkActivate => sub ($event) {
		my $target = $event->link;
		my ($name) = $target =~ /\A#(.*?)(?:\|outline)?\z/;
		my $index  = defined $name ? $document->find_section($name) : undef;
		if ( defined $index ) {
			$view->show_block($index);
		}
		else {
			$status->message( "Open $target in your browser.", 'info' );
		}
		return;
	}
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
