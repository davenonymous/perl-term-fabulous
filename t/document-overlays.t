use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use DocumentTest;
use Term::Fabulous::Document::Overlays;

# Blocks: 0 NAME, 1 the links A and B, 2 MIDDLE, 3 two needles,
# 4 no needle, 5 END, 6 the link C and a needle.
my $DOCUMENT = document(
	heading( 1, 'NAME' ),
	paragraph('Links - one <link=A>A</link> and <link=B>B</link>'),
	heading( 1, 'MIDDLE' ),
	paragraph('needle one, needle two'),
	paragraph('Plain text.'),
	heading( 1, 'END' ),
	paragraph('<link=C>C</link> and a needle.'),
);

sub overlays () {
	return Term::Fabulous::Document::Overlays->new( document => $DOCUMENT );
}

my $ALL = { first => 0, last => 6 };

subtest 'a search starts at the top block' => sub {
	my $overlays = overlays();
	is [ $overlays->search( 'needle', 0 ) ],                                   [ 3, 6 ],           'it marks the blocks with matches';
	is [ $overlays->query, $overlays->match_count, $overlays->current_match ], [ 'needle', 3, 1 ], 'the first match is current';
	is [ $overlays->current_match_start ],                                     [ 3, 0 ],           'it starts its block';
	is [ $overlays->search( 'needle', 6 ), $overlays->current_match ],         [ 3, 6, 3 ],        'from a lower top, the first match in that block or after it';
	is [ $overlays->current_match_start ],                                     [ 6, 8 ],           'which is in block 6';
	is [ $overlays->search( 'needle', 7 ), $overlays->current_match ],         [ 3, 6, 1 ],        'below the last match, the first one';
	is [ $overlays->search( 'Plain', 0 ) ],                                    [ 3, 4, 6 ],        'a new search touches the blocks of the old one and of the new one';
	like dies { $overlays->search( undef,  0 ) }, qr/search needs a string, got undef/,   'a search needs a text';
	like dies { $overlays->search( 'x',   -1 ) }, qr/top must be a non-negative integer/, 'and a top block';
};

subtest 'an empty search ends the search' => sub {
	my $overlays = overlays();
	$overlays->search( 'needle', 0 );
	is [ $overlays->search( '', 0 ) ], [ 3, 6 ], 'it touches the blocks that had matches';
	is [ $overlays->query, $overlays->match_count, $overlays->current_match ], [ undef, 0, undef ], 'and leaves no search';
};

subtest 'stepping goes around' => sub {
	my $overlays = overlays();
	$overlays->search( 'needle', 0 );
	is [ $overlays->step_match(-1) ], [ 3, 6 ], 'back from the first match touches its block and the last one';
	is $overlays->current_match,      3,        'which is current';
	is [ $overlays->step_match(1) ],  [ 3, 6 ], 'on from the last match goes around to the first';
	is $overlays->current_match,      1,        'which is current again';
	is [ $overlays->step_match(1) ],  [3],      'a step within a block touches it once';
	like dies { $overlays->step_match(2) }, qr/step_match needs a direction of 1 or -1, got '2'/, 'a step is one match';
};

subtest 'link selection' => sub {
	my $overlays = overlays();
	is [ $overlays->select_link( 1, { first => 2, last => 6 } ) ],  [6],      'the first link in view, when none is selected';
	is $overlays->selected_link,                                    'C',      'is selected';
	is [ $overlays->select_link( 1, $ALL ) ],                       [],       'the selection stops at the last link';
	is $overlays->selected_link,                                    'C',      'and stays';
	is [ $overlays->select_link( -1, $ALL ) ],                      [ 1, 6 ], 'going back touches the block left and the block entered';
	is [ $overlays->select_link( -1, $ALL ) ],                      [1],      'a step within a block touches it once';
	is $overlays->selected_link,                                    'A',      'the first link';
	is [ $overlays->select_link( -1, $ALL ) ],                      [],       'where the selection stops going back';
	is [ $overlays->select_link( 1, { first => 5, last => 6 } ) ],  [ 1, 6 ], 'a selection out of view starts again from the view';
	is [ $overlays->select_link( -1, { first => 0, last => 0 } ) ], [],       'with no link in view, nothing is selected';

	my $unknown = overlays();
	is [ $unknown->select_link( -1, undef ) ], [6],      'without a view, the last link going back';
	is [ $unknown->select_link( -1, undef ) ], [ 1, 6 ], 'and from the selection on';
	is $unknown->selected_link, 'B', 'which moves on';
};

subtest 'a click selects the link it hit' => sub {
	my $overlays = overlays();
	my ( undef, $second ) = $DOCUMENT->block(1)->links;
	is [ $overlays->select_link_at( 1, $second->start, $second->end ) ], [1],                       'the block of the link is touched';
	is $overlays->selected_link,                                         'B',                       'and the link is selected';
	is [ $overlays->selected_mark ],                                     [ 1, exact_ref($second) ], 'with its block and mark';
	like dies { $overlays->select_link_at( 3, 0, 6 ) }, qr/block 3 has no link from 0 to 6/, 'a click on no link is a bug';
};

subtest 'the selected link among the links of its block' => sub {
	my $overlays = overlays();
	$overlays->select_link( 1, undef ) foreach 1 .. 2;
	is [ map { $overlays->selected_in_block($_) } 1, 6 ], [ 1, undef ], 'B is the second link of block 1, and in no other block';
};

subtest 'the spans of a block' => sub {
	my $overlays = overlays();
	$overlays->search( 'needle', 0 );
	is [ $overlays->spans_of(3) ], [ [ 0, 6, 'match_current' ], [ 12, 18, 'match' ] ], 'the current match in its own kind';
	is [ $overlays->spans_of(4) ], [],                                                 'a block without matches has none';
};

subtest 'clearing' => sub {
	my $overlays = overlays();
	$overlays->search( 'needle', 0 );
	$overlays->select_link( 1, undef );
	is [ $overlays->clear ],                                                   [ 1, 3, 6 ],         'touches the blocks of the matches and of the selection';
	is [ $overlays->query, $overlays->match_count, $overlays->selected_link ], [ undef, 0, undef ], 'and drops them';
	is [ $overlays->clear, $overlays->is_empty ],                              [1],                 'a second time there is nothing to clear';
	$overlays->search( 'nothing like this', 0 );
	is [ $overlays->is_empty, $overlays->clear, $overlays->is_empty ], [ 0, 1 ], 'a search without matches touches no block, but it ends';
};

subtest 'a document without links or matches' => sub {
	my $overlays = Term::Fabulous::Document::Overlays->new( document => document( heading( 1, 'Plain' ), paragraph('Nothing.') ) );
	is [ $overlays->select_link( 1, undef ) ], [], 'has no link to select';
	is [ $overlays->search( 'zzz', 0 ), $overlays->step_match(1) ], [], 'and no match to step to';
	is [ $overlays->query, $overlays->current_match ], [ 'zzz', undef ], 'but a search';
};

subtest 'no document' => sub {
	my $overlays = Term::Fabulous::Document::Overlays->new;
	is [ $overlays->select_link( 1, undef ), $overlays->search( 'x', 0 ) ], [], 'selects and finds nothing';
	is [ $overlays->spans_of(0), $overlays->selected_in_block(0) ], [undef], 'and draws nothing';
	like dies { Term::Fabulous::Document::Overlays->new( document => {} ) }, qr/document must be a Term::Fabulous::Document or undef, got a HASH reference/, 'a document is a document';
};

done_testing;
