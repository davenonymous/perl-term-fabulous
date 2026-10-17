use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM);
use Term::Fabulous;
use Term::Fabulous::Terminal::Memory;
use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::RichText;

my $NBSP = "\x{a0}";

subtest 'wrapped_rows' => sub {
	my @rows = (
		[ 'aaaa bbbb cccc',     10, 2, 'a word that does not fit starts the next line' ],
		[ 'aaaa bbbb cccc',     9,  2, 'the last word is measured without a space' ],
		[ 'aaaa bbbb cccc',     8,  3, 'the others with the space after them' ],
		[ 'xx aaaaaaaaaaaa bb', 10, 3, 'a word wider than the line has a line of its own' ],
		[ "aa bb${NBSP}cc",     6,  2, 'a no-break space is part of its word' ],
		[ 'Grüße 日本語 x',        6,  3, 'words are measured in columns, not characters' ],
		[ '',                   5,  1, 'an empty text takes a row' ],
	);
	is( wrapped_rows( $_->[0], $_->[1] ), $_->[2], $_->[3] ) foreach @rows;
	like dies { wrapped_rows( 'x', 0 ) }, qr/columns must be a positive integer, got '0'/, 'a text wraps to a column at least';
};

subtest 'wrapped_row' => sub {
	my @row_of = (
		[ 'aaaa bbbb cccc',     0,  8,  0, 'the first character' ],
		[ 'aaaa bbbb cccc',     4,  8,  0, 'a space belongs to the word before it' ],
		[ 'aaaa bbbb cccc',     5,  8,  1, 'the next word is on the next line' ],
		[ 'aaaa bbbb cccc',     99, 8,  2, 'past the end is the last line' ],
		[ 'xx aaaaaaaaaaaa bb', 16, 10, 2, 'after a word wider than the line' ],
	);
	is( wrapped_row( @$_[ 0 .. 2 ] ), $_->[3], $_->[4] ) foreach @row_of;
	like dies { wrapped_row( undef,  0, 3 ) }, qr/wrapped_row needs a text, got undef/,   'a text is needed';
	like dies { wrapped_row( 'x',   -1, 3 ) }, qr/offset must be a non-negative integer/, 'with an offset in it';
};

# The contract with Clay: a RichText laid out in a box of a known width
# takes the rows the functions say.
sub laid_out_rows ( $text, $columns ) {
	my $box = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed($columns) } } );
	$box->add_child( Term::Fabulous::Widget::RichText->new( text => $text, can_focus => 0 ) );
	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$root->add_child($box);
	my $terminal = Term::Fabulous::Terminal::Memory->new( width => 40, height => 20 );
	my $ui       = Term::Fabulous->new( root => $root, width => 40, height => 20, terminal => $terminal );
	$ui->step;
	return $ui->bounding_box($box)->{height};
}

subtest 'Clay wraps as the functions do' => sub {
	my @texts = (
		[ 'aaaa bbbb cccc',                                          9 ],
		[ 'xx aaaaaaaaaaaa bb',                                      10 ],
		[ "aa bb${NBSP}cc dd",                                       6 ],
		[ 'Grüße wörld 日本語 text',                                    8 ],
		[ 'one two three four five six seven eight nine ten eleven', 12 ],
	);
	is [ map { laid_out_rows(@$_) } @texts ], [ map { wrapped_rows(@$_) } @texts ], 'the rows of every text';
};

done_testing;
