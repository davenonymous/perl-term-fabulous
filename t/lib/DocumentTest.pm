package DocumentTest;

# Helpers for the tests of the document model and the document view:
# build blocks and documents without a parser. A text may hold marks
# written as <kind>...</kind> for any kind, and <link=TARGET>...</link>
# for a link; the tags nest. sample_document and long_document are the
# two documents several tests share.

use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Exporter 'import';
our @EXPORT = qw(document marked heading paragraph list_item term verbatim sample_document long_document);    ## no critic (Modules::ProhibitAutomaticExportation) every test uses most helpers

use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Item;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Term;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Document::Mark;

# The text without its tags, and the marks the tags stood for, as the
# constructor parameters of a block.
sub marked ($tagged) {
	my ( $text, @marks, @open ) = ('');
	foreach my $piece ( split /(<\/?\w+(?:=[^>]*)?>)/, $tagged ) {
		if ( $piece =~ /\A<(\w+)(?:=([^>]*))?>\z/ ) {
			push @open, { start => length $text, kind => $1, defined $2 ? ( link => $2 ) : () };
		}
		elsif ( $piece =~ /\A<\/(\w+)>\z/ ) {
			my $mark = pop @open // die "DocumentTest: a </$1> without a <$1>";
			die "DocumentTest: a </$1> closes a <$mark->{kind}>" unless $mark->{kind} eq $1;
			push @marks, Term::Fabulous::Document::Mark->new( %$mark, end => length $text );
		}
		else {
			$text .= $piece;
		}
	}
	die "DocumentTest: a <$open[-1]{kind}> is never closed" if @open;
	return ( text => $text, marks => [ sort { $a->start <=> $b->start } @marks ] );
}

sub heading ( $level, $text, %options ) {
	return Term::Fabulous::Document::Block::Heading->new( marked($text), level => $level, %options );
}

sub paragraph ( $text, %options ) {
	return Term::Fabulous::Document::Block::Paragraph->new( marked($text), %options );
}

# The marker takes its own columns and a space unless marker_width says
# otherwise.
sub list_item ( $marker, $position, $text, %options ) {
	my $width = delete $options{marker_width} // length($marker) + 1;
	return Term::Fabulous::Document::Block::Item->new( marked($text), marker => $marker, marker_width => $width, position => $position, %options );
}

sub term ( $text, %options ) {
	return Term::Fabulous::Document::Block::Term->new( marked($text), %options );
}

sub verbatim ( $text, %options ) {
	return Term::Fabulous::Document::Block::Verbatim->new( text => $text, %options );
}

sub document (@blocks) {
	return Term::Fabulous::Document->new( blocks => \@blocks );
}

# Blocks: 0 NAME, 1 the name line, 2 SYNOPSIS, 3 code, 4 DESCRIPTION,
# 5 marks and links, 6 Methods, 7 and 9 terms with their definitions 8
# and 10, 11 Lists, 12 and 13 a bulleted list, 14 and 15 a numbered one,
# 16 SEE ALSO, 17 more links.
sub sample_document () {
	return document(
		heading( 1, 'NAME' ),
		paragraph('Sample - a page to test the document view with'),
		heading( 1, 'SYNOPSIS' ),
		verbatim( "use Sample;\nmy \$sample = Sample->new;", language => 'perl' ),
		heading( 1, 'DESCRIPTION' ),
		paragraph(
			'Some <bold>bold</bold>, <italic>italic</italic>, <code>code</code> and <file>file.txt</file>, a link to <link=Other>Other</link> and one to <link=/Methods>a section</link>, Grüße and é.'
		),
		heading( 2, 'Methods' ),
		term('new'),
		paragraph( 'Creates a sample.', indent => 4 ),
		term('frobnicate VALUE'),
		paragraph( 'Frobnicates the <italic>VALUE</italic>.', indent => 4 ),
		heading( 2, 'Lists' ),
		list_item( "\x{2022}", 1, 'First point.' ),
		list_item( "\x{2022}", 2, 'Second point with <link=Other/Details>Details</link>.' ),
		list_item( '1.',       1, 'One.' ),
		list_item( '2.',       2, 'Two.' ),
		heading( 1, 'SEE ALSO' ),
		paragraph('<link=Other>Other</link>, <link=https://example.com/sample>https://example.com/sample</link>, <link=crontab(5)>crontab(5)</link>.'),
	);
}

# A heading, 120 one-line paragraphs with a needle each, and a last one.
sub long_document () {
	return document( heading( 1, 'NAME' ), ( map { paragraph("Paragraph $_ with a needle in it.") } 1 .. 120 ), paragraph('The last paragraph.') );
}

1;
