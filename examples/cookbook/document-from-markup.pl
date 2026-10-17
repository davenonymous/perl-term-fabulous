#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use Clay::XS qw(sizing_grow);
use My::MiniMark;
use Term::Fabulous;
use Term::Fabulous::Widget::DocumentView;

my $file     = shift // "$FindBin::Bin/documents/snapback.md";
my $document = My::MiniMark->parse_file($file);

my $view = Term::Fabulous::Widget::DocumentView->new(
	id       => 'manual',
	document => $document,
	layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
