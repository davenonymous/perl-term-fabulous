#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm and My/Markdown/*.pm live

use Clay::XS qw(sizing_grow);
use My::Markdown;
use My::Markdown::View;
use Term::Fabulous;

my $file     = shift // "$FindBin::Bin/documents/news.md";
my $document = My::Markdown->parse_file($file);

my $view = My::Markdown::View->new(
	id       => 'news',
	document => $document,
	layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
