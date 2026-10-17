use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use DocumentTest;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Item;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Document::Mark;

subtest 'marks' => sub {
	like dies { Term::Fabulous::Document::Mark->new( start => 3, end => 2, kind => 'bold' ) },   qr/end 2 lies before start 3/, 'a mark does not end before it starts';
	like dies { Term::Fabulous::Document::Mark->new( start => 0, end => 2, kind => 'no way' ) }, qr/kind must be a word/,       'the kind is a word';
	like dies { Term::Fabulous::Document::Mark->new( start => 0, end => 2, kind => 'link' ) },   qr/a link mark needs a link/,  'a link mark needs its link';
	like dies { Term::Fabulous::Document::Mark->new( start => 0, end => 2, kind => 'bold', link => 'x' ) }, qr/only a link mark has a link/, 'and only a link mark has one';
	my $code = Term::Fabulous::Document::Mark->new( start => 2, end => 7, kind => 'code' );
	is [ $code->span_length, $code->is_link, $code->link ], [ 5, 0, undef ], 'span_length is end minus start; a code mark is no link';
	my $link = Term::Fabulous::Document::Mark->new( start => 0, end => 1, kind => 'link', link => { page => 'Other' } );
	is [ $link->is_link, $link->link ], [ 1, { page => 'Other' } ], 'a link mark keeps any defined value as its link';
};

subtest 'blocks' => sub {
	my $bold = Term::Fabulous::Document::Mark->new( start => 0, end => 9, kind => 'bold' );
	like dies { Term::Fabulous::Document::Block::Paragraph->new( text => 'short', marks => [$bold] ) },          qr/a mark ends at 9, past the text \(5 characters\)/, 'marks lie within the text';
	like dies { Term::Fabulous::Document::Block::Paragraph->new( text => 'x', quote => -1 ) },                   qr/quote must be a non-negative integer/,             'the quote depth is checked';
	like dies { Term::Fabulous::Document::Block::Heading->new( text => 'X', level => 7 ) },                      qr/level must be an integer from 1 to 6/,             'heading levels are 1 to 6';
	like dies { Term::Fabulous::Document::Block::Heading->new( text => 'X', level => 1, indent => 2 ) },         qr/a heading is not indented/,                        'headings are not indented';
	like dies { Term::Fabulous::Document::Block::Item->new( text => 'x', marker => '10.', marker_width => 3 ) }, qr/leaves no space after the marker/, 'the marker width leaves a space';
	like dies { Term::Fabulous::Document::Block::Verbatim->new( text => 'x', marks => [ Term::Fabulous::Document::Mark->new( start => 0, end => 1, kind => 'bold' ) ] ) },
		qr/a verbatim block has no marks/, 'verbatim blocks have no marks';

	my $code = Term::Fabulous::Document::Block::Verbatim->new( text => "a\n\nlonger line", language => 'perl' );
	is [ $code->kind, [ $code->lines ], $code->language ], [ 'verbatim', [ 'a', '', 'longer line' ], 'perl' ], 'a verbatim block has lines and a language';
	is [ $code->body_rows(3), $code->row_of_character( 3, 3 ) ], [ 3, 2 ], 'code takes a row per line, whatever the columns';
	my $empty = Term::Fabulous::Document::Block::Verbatim->new( text => '' );
	is [ [ $empty->lines ], $empty->body_rows(10) ], [ [''], 1 ], 'an empty verbatim block is one empty line, the row its code block shows';

	my $first  = Term::Fabulous::Document::Mark->new( start => 0, end => 4, kind => 'link', link => 'a' );
	my $second = Term::Fabulous::Document::Mark->new( start => 5, end => 9, kind => 'link', link => 'b' );
	like dies { Term::Fabulous::Document::Block::Paragraph->new( text => 'some text', marks => [ Term::Fabulous::Document::Mark->new( start => 2, end => 2, kind => 'link', link => 'x' ) ] ) },
		qr/the link mark at 2 covers no text/, 'a link mark covers text';
	like dies { Term::Fabulous::Document::Block::Paragraph->new( text => 'some text', marks => [ $first, Term::Fabulous::Document::Mark->new( start => 3, end => 6, kind => 'link', link => 'x' ) ] ) },
		qr/the link marks 0 to 4 and 3 to 6 overlap/, 'and link marks do not overlap';
	my $linked = Term::Fabulous::Document::Block::Paragraph->new( text => 'some text', marks => [ $second, $bold, $first ] );
	is [ map { $_->link } $linked->links ], [ 'a', 'b' ], 'links come in the order of the text, however they were given';
	is [ map { $_->kind } $linked->marks ], [ 'link', 'bold', 'link' ], 'while the marks keep their order';

	my $marks     = [$bold];
	my $paragraph = Term::Fabulous::Document::Block::Paragraph->new( text => 'bold text', marks => $marks, quote => 1 );
	push @$marks, $bold;
	is scalar( () = $paragraph->marks ),                                   1,        'a block keeps a copy of its marks';
	is [ $paragraph->body_rows(5), $paragraph->row_of_character( 5, 5 ) ], [ 2, 1 ], 'a paragraph wraps its text';
	is $paragraph->quote,                                                  1,        'and knows how deep in quotes it is';

	my %marked = marked('Some <bold>bold <link=x>link</link></bold>.');
	is $marked{text},                                                              'Some bold link.',                                     'the test helper strips the tags';
	is [ map { [ $_->kind, $_->start, $_->end, $_->link ] } @{ $marked{marks} } ], [ [ 'bold', 5, 14, undef ], [ 'link', 10, 14, 'x' ] ], 'and keeps the marks';
};

my $SAMPLE = sample_document();

subtest 'parameters' => sub {
	like dies { Term::Fabulous::Document->new( blocks => {} ) },    qr/blocks must be an array reference/,                      'blocks are a list';
	like dies { Term::Fabulous::Document->new( blocks => ['x'] ) }, qr/blocks must be Term::Fabulous::Document::Block objects/, 'of blocks';
	like dies { Term::Fabulous::Document->new( source => [] ) },    qr/source must be a string/,                                'the source is a path';
	is( Term::Fabulous::Document->new->count,                      0,      'a document may be empty' );
	is( Term::Fabulous::Document->new( source => 'a.md' )->source, 'a.md', 'and remembers its source' );
};

subtest 'headings and sections' => sub {
	is [ map { $SAMPLE->block($_)->text } $SAMPLE->heading_indexes ], [ 'NAME', 'SYNOPSIS', 'DESCRIPTION', 'Methods', 'Lists', 'SEE ALSO' ], 'the headings, in order';
	my @headings = $SAMPLE->heading_indexes;
	is $SAMPLE->section_at( $headings[3] ),                                3,     'a heading is in its own section';
	is $SAMPLE->section_at( $headings[3] + 1 ),                            3,     'a block after it too';
	is document( paragraph('Before.'), heading( 1, 'A' ) )->section_at(0), undef, 'a block before the first heading is in none';
	like dies { $SAMPLE->block( $SAMPLE->count ) },      qr/does not exist/,            'block checks the index';
	like dies { $SAMPLE->section_at( $SAMPLE->count ) }, qr/block \d+ does not exist/,  'and so does section_at';
	like dies { $SAMPLE->section_at('abc') },            qr/section_at needs an index/, 'which needs an index';

	is [ map { $_->text } $SAMPLE->headings ], [ 'NAME', 'SYNOPSIS', 'DESCRIPTION', 'Methods', 'Lists', 'SEE ALSO' ], 'headings are the heading blocks, in section order';
	is $SAMPLE->block_of_section(3),           $headings[3],                                                          'block_of_section is where a section starts';
	is $SAMPLE->heading_of_section(3)->text,   'Methods',                                                             'and heading_of_section its heading';
	like dies { $SAMPLE->heading_of_section(6) },     qr/section 6 does not exist, the document has 6 sections/, 'a section number beyond the last dies';
	like dies { $SAMPLE->block_of_section('Lists') }, qr/block_of_section needs a section number, got 'Lists'/,  'and so does a section number that is none';
};

subtest 'find_section' => sub {
	my $text_at = sub ($name) { my $index = $SAMPLE->find_section($name); defined $index ? $SAMPLE->block($index)->text : undef };
	is $text_at->('Methods'),    'Methods',          'a heading by its text';
	is $text_at->('methods'),    'Methods',          'ignoring case when nothing matches exactly';
	is $text_at->('new'),        'new',              'a term by its text';
	is $text_at->('frobnicate'), 'frobnicate VALUE', 'a term that starts with the name as a word';
	is $text_at->('frob'),       undef,              'but not with part of a word';
	is $text_at->("SEE\n ALSO"), 'SEE ALSO',         'whitespace is squeezed';
	is $text_at->(''),           undef,              'an empty name finds nothing';
	like dies { $SAMPLE->find_section(undef) }, qr/find_section needs a section name/, 'a name is needed';
};

subtest 'links' => sub {
	is [ map { $_->[1]->link } $SAMPLE->links ], [ 'Other', '/Methods', 'Other/Details', 'Other', 'https://example.com/sample', 'crontab(5)' ], 'every link, in order';
	my ( $index, $mark ) = @{ ( $SAMPLE->links )[0] };
	is [ $index, $SAMPLE->block($index)->kind ], [ 5, 'paragraph' ], 'with the block it is in';
};

subtest 'find_text' => sub {
	my $long = long_document();
	is scalar( my @all = $long->find_text('needle') ),                                 120,                    'one match per paragraph';
	is [ ( $long->find_text('Needle') )[0] ],                                          [],                     'a capital letter matches case';
	is [ $SAMPLE->find_text('BOLD') ],                                                 [],                     'so nothing is found when the case differs';
	is [ $SAMPLE->find_text('bold') ],                                                 [ [ 5, 5, 9 ] ],        'a match points at the text';
	is [ $SAMPLE->find_text('') ],                                                     [],                     'an empty query finds nothing';
	is [ map { [ @$_[ 1, 2 ] ] } document( paragraph('aaaa') )->find_text('aa') ],     [ [ 0, 2 ], [ 2, 4 ] ], 'matches do not overlap';
	is [ map { [ @$_[ 1, 2 ] ] } document( paragraph('a.b axb') )->find_text('a.b') ], [ [ 0, 3 ] ],           'the query is text, not a pattern';
	like dies { $SAMPLE->find_text( [] ) }, qr/find_text needs a string/, 'a query is a string';
};

done_testing;
