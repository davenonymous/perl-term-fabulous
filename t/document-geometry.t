use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use DocumentTest;
use Term::Fabulous::Document::Geometry;

# Blocks: 0 a first-level heading, 1 a paragraph, 2 and 3 the items of
# a list, 4 the item of the next list, 5 the first item of a list
# nested in it, 6 a term, 7 its definition, 8 a second-level heading,
# 9 code, 10 a quoted paragraph, 11 a quoted heading.
my $DOCUMENT = document(
	heading( 1, 'NAME' ),
	paragraph('Short paragraph.'),
	list_item( "\x{2022}", 1, 'First.',                  marker_width => 4 ),
	list_item( "\x{2022}", 2, 'Second item with words.', marker_width => 4 ),
	list_item( '1.',       1, 'Next list.',              marker_width => 5 ),
	list_item( 'a.',       1, 'Nested.',                 marker_width => 3, indent => 5 ),
	term('frobnicate'),
	paragraph( 'Defined here.', indent => 4 ),
	heading( 2, 'Code' ),
	verbatim("one\ntwo\nthree"),
	paragraph( 'Quoted words here.', quote => 2 ),
	heading( 2, 'Quoted', quote => 1 ),
);

my $GEOMETRY = Term::Fabulous::Document::Geometry->new( document => $DOCUMENT, indent => 2 );

subtest 'blocks' => sub {
	my @blocks = (

		# index, left, space before, text columns of 20, rows at 20 and at 12, what
		[ 0,  0, 0, 20, 2, 2, 'a first-level heading is not indented and has a rule' ],
		[ 1,  2, 1, 18, 2, 3, 'a paragraph has the indent and a blank row above' ],
		[ 2,  2, 1, 14, 2, 2, 'an item gives the columns of its marker away' ],
		[ 3,  2, 0, 14, 2, 4, 'a second item follows the first without a blank row' ],
		[ 4,  2, 1, 13, 2, 3, 'the first item of the next list does not' ],
		[ 5,  7, 0, 10, 1, 1, 'nor the first item of a list nested in an item' ],
		[ 6,  2, 1, 18, 2, 2, 'a term is a paragraph' ],
		[ 7,  6, 0, 14, 1, 2, 'its definition follows it, indented' ],
		[ 8,  0, 1, 20, 2, 2, 'a second-level heading has no rule' ],
		[ 9,  2, 1, 18, 4, 4, 'code takes a row per line, at any width' ],
		[ 10, 6, 1, 14, 3, 4, 'a quote takes two columns per level' ],
		[ 11, 2, 1, 18, 2, 2, 'also for a heading' ],
	);
	foreach my $row (@blocks) {
		my ( $index, @expected ) = @$row;
		my $what = pop @expected;
		my @got
			= ( $GEOMETRY->left_of($index), $GEOMETRY->space_before($index), $GEOMETRY->text_columns( $index, 20 ), $GEOMETRY->estimated_rows( $index, 20 ), $GEOMETRY->estimated_rows( $index, 12 ) );
		is \@got, \@expected, "block $index: $what";
	}
	is( Term::Fabulous::Document::Geometry->new( document => $DOCUMENT, indent => 0 )->left_of(1), 0, 'the indent is a parameter' );
	is $GEOMETRY->text_columns( 7, 3 ), 1, 'a box narrower than the indent leaves a column';
	like dies { $GEOMETRY->left_of(12) }, qr/block 12 does not exist/, 'a block the document does not have dies';
	like dies { Term::Fabulous::Document::Geometry->new( document => $DOCUMENT, indent => -1 ) }, qr/indent must be a non-negative integer/,                  'the indent is checked';
	like dies { Term::Fabulous::Document::Geometry->new( document => undef,     indent =>  2 ) }, qr/document must be a Term::Fabulous::Document, got undef/, 'and the document';
};

subtest 'the row of a character in its box' => sub {
	my @rows = (
		[ 1, 0,  20, 1, 'below the blank row' ],
		[ 3, 17, 12, 3, 'wrapped in the columns beside the marker' ],
		[ 9, 4,  12, 2, 'code is cut at its line breaks' ],
	);
	is( $GEOMETRY->row_of_character( @$_[ 0 .. 2 ] ), $_->[3], $_->[4] ) foreach @rows;
	like dies { $GEOMETRY->row_of_character( 1, -1, 20 ) }, qr/offset must be a non-negative integer/, 'the offset is checked';
};

done_testing;
