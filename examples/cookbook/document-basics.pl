#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_grow);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Item;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Term;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Document::Mark;
use Term::Fabulous::Widget::DocumentView;

# Joins pieces of text into the text of a block and the marks over it.
# A piece is a plain string, [ KIND => 'text' ] for a styled piece, or
# [ link => 'text', TARGET ] for a link.
sub inline (@pieces) {
	my ( $text, @marks ) = ('');
	foreach my $piece (@pieces) {
		if ( !ref $piece ) {
			$text .= $piece;
			next;
		}
		my ( $kind, $words, $target ) = @$piece;
		my $start = length $text;
		$text .= $words;
		push @marks, Term::Fabulous::Document::Mark->new( start => $start, end => length $text, kind => $kind, $kind eq 'link' ? ( link => $target ) : () );
	}
	return ( text => $text, marks => \@marks );
}

sub heading ( $level, $text ) {
	return Term::Fabulous::Document::Block::Heading->new( level => $level, text => $text );
}

sub paragraph ( $options, @pieces ) {
	return Term::Fabulous::Document::Block::Paragraph->new( %$options, inline(@pieces) );
}

my $document = Term::Fabulous::Document->new(
	blocks => [
		heading( 1, 'snapback' ),
		paragraph(
			{},
			[ bold   => 'snapback' ],    ' copies the files of a directory to a backup disk, but ',
			[ italic => 'only' ],        ' those that changed since the last run. It reads its settings from ',
			[ file   => '~/.snapback' ], '. The old option ', [ strike => '--all' ], ' is gone.',
		),

		heading( 2, 'Usage' ),
		Term::Fabulous::Document::Block::Verbatim->new(
			language => 'shell',
			text     => "snapback ~/Documents /mnt/backup\nsnapback --dry-run ~/Photos /mnt/backup",
		),

		heading( 2, 'Options' ),
		Term::Fabulous::Document::Block::Term->new( text => '--dry-run' ),
		paragraph( { indent => 4 }, 'Lists the files it would copy, and copies nothing.' ),
		Term::Fabulous::Document::Block::Term->new( text => '--keep N' ),
		paragraph( { indent => 4 }, 'Keeps the last ', [ code => 'N' ], ' backups and deletes older ones.' ),

		heading( 2, 'Before the first run' ),
		Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 1, inline('Connect the backup disk.') ),
		Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 2, inline('Check that it has enough free space:') ),
		Term::Fabulous::Document::Block::Item->new( marker => '1.', marker_width => 3, position => 1, indent => 2, inline( 'Run ', [ code => 'df -h /mnt/backup' ], '.' ) ),
		Term::Fabulous::Document::Block::Item->new( marker => '2.', marker_width => 3, position => 2, indent => 2, inline('Compare it with the size of the directory.') ),
		Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 3, inline( 'Try a dry run first (see ', [ link => 'Options', 'Options' ], ').' ) ),

		heading( 3, 'From the mailing list' ),
		paragraph( { quote => 1 }, 'Ada wrote:' ),
		paragraph( { quote => 2 }, 'Restore a file now and then. A backup that was never restored is a hope, not a backup.' ),
		paragraph( {}, 'More at ', [ link => 'snapback.example.org', 'https://snapback.example.org' ], '.' ),
	],
);

my $view = Term::Fabulous::Widget::DocumentView->new(
	id       => 'manual',
	document => $document,
	layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1, top => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
