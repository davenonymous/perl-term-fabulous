#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Odt/Parser.pm lives

use My::Odt::Parser;

binmode STDOUT, ':encoding(UTF-8)';

my $document = My::Odt::Parser->parse_file( shift // "$FindBin::Bin/documents/pancakes.odt" );

# A line per block: its kind, then its text, indented as the view
# indents it and with the marker of an item. Under it a line per mark:
# its kind and the text it covers.
foreach my $block ( $document->blocks ) {
	my $kind   = $block->kind eq 'heading' ? 'heading ' . $block->level : $block->kind;
	my $marker = $block->kind eq 'item'    ? $block->marker . ' '       : '';
	printf "%-10s %s%s%s\n", $kind, ' ' x $block->indent, $marker, $block->text;
	foreach my $mark ( $block->marks ) {
		my $covered = substr( $block->text, $mark->start, $mark->span_length );
		printf "%-10s %s%s \"%s\"%s\n", '', ' ' x $block->indent, $mark->kind, $covered, $mark->is_link ? ' -> ' . $mark->link : '';
	}
}
