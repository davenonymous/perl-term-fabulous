#!/usr/bin/env perl

use v5.22;
use warnings;
use strict;
use utf8;
use experimental 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/../lib/";

use Term::Fabulous;
use Term::Fabulous::Layout;

my $layout = Term::Fabulous::Layout->new(string => <<'END');
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text

Box "root" {
	layout direction=down gap=4
	sizing width=grow height="fixed(30)"
	padding left=1 right=1 top=1 bottom=1

	border style=Round style-bottom=Thick style-top=Thick color="rgba(20, 140, 56, 255)"
	background_color "rgba(20, 25, 55, 255)"
	border_width 1

	Text "message" {
		text "Hello, KDL layout!"
		text_color "rgba(220, 34, 220, 255)"
	}

	Text "message2" {
		text "Hello, KDL layout!"
		text_color "rgba(33, 34, 220, 255)"
	}
}
END

my $root = $layout->build;

my $ui = Term::Fabulous->new(
	width       => 100,
	height      => 32,
	root        => $root,
	use_termbox => 1,
);

use Data::Printer;
#p $root;

$ui->run();
