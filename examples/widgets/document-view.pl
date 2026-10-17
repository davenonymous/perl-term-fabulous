#!/usr/bin/env perl

# Term::Fabulous::Widget::DocumentView: a document built from blocks,
# shown with headings, lists, a quote, code and links. Scroll with the
# keys (Down, Up, PageDown, PageUp, Home, End, or j k Space b g G) and
# the wheel; l and L select a link, Enter follows it; / is not a key
# here, but the program searches for "block" at the start: n and N step
# through the matches, Escape drops them. Ctrl+C quits.
#
#     perl examples/widgets/document-view.pl

use v5.32;
use warnings;
use strict;
use utf8;
use experimental 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/../../lib/";

use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_NONE);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Item;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Document::Mark;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::DocumentView;
use Term::Fabulous::Widget::Text;

# A paragraph whose text holds marks as <kind>...</kind> and links as
# <link=TARGET>...</link>, the way a parser would produce them.
sub marked ( $tagged, %options ) {
	my ( $text, @marks, @open ) = ('');
	foreach my $piece ( split /(<\/?\w+(?:=[^>]*)?>)/, $tagged ) {
		if    ( $piece =~ /\A<(\w+)(?:=([^>]*))?>\z/ ) { push @open, { start => length $text, kind => $1, defined $2 ? ( link => $2 ) : () } }
		elsif ( $piece =~ /\A<\/\w+>\z/ )              { push @marks, Term::Fabulous::Document::Mark->new( %{ pop @open }, end => length $text ) }
		else                                           { $text .= $piece }
	}
	return Term::Fabulous::Document::Block::Paragraph->new( text => $text, marks => \@marks, %options );
}

sub heading ( $level, $text ) {
	return Term::Fabulous::Document::Block::Heading->new( text => $text, level => $level );
}

sub item ( $position, $text ) {
	return Term::Fabulous::Document::Block::Item->new( text => $text, marker => "\x{2022}", marker_width => 2, position => $position );
}

my $document = Term::Fabulous::Document->new(
	blocks => [
		heading( 1, 'DOCUMENT VIEW' ),
		marked('A <bold>DocumentView</bold> shows a <code>Term::Fabulous::Document</code>: a list of blocks that a parser made of some source, POD or Markdown or anything else.'),
		heading( 2, 'Blocks' ),
		marked('Every block has a kind, and the view shows each kind in the style of the theme:'),
		item( 1, 'headings, in six levels, the first with a rule under it;' ),
		item( 2, 'paragraphs, wrapped to the width of the view, with bold, italic and code marks;' ),
		item( 3, 'items of bulleted and numbered lists, with a hanging indent;' ),
		item( 4, 'verbatim blocks, shown as code that never wraps;' ),
		item( 5, 'and quotes, with a bar beside them.' ),
		marked( 'A quoted block looks like this, and may <italic>itself</italic> hold marks.', quote => 1 ),
		heading( 2, 'Code' ),
		marked('The code blocks scroll sideways together with Left and Right, or with a horizontal wheel:'),
		Term::Fabulous::Document::Block::Verbatim->new(
			text     => join( "\n", 'my $view = Term::Fabulous::Widget::DocumentView->new(', '    id       => "document",', '    document => $document,    # from a parser of your format', ');' ),
			language => 'perl',
		),
		heading( 2, 'Links' ),
		marked(
'A link such as <link=https://metacpan.org/pod/Term::Fabulous>Term::Fabulous on MetaCPAN</link> is selected with l and L and followed with Enter or a click; the view fires <code>LinkActivate</code> and leaves the rest to the program. The <link=/Blocks>Blocks</link> section above is a link too.'
		),
		heading( 1, 'MORE' ),
		( map { marked("Paragraph $_ of a longer document, so that there is something to scroll through and to search for: the word block appears in every one of them.") } 1 .. 40 ),
	],
);

my $view = Term::Fabulous::Widget::DocumentView->new(
	id           => 'document',
	document     => $document,
	bordered     => 1,
	border_style => Term::Fabulous::Enum::BorderStyle->Round,
	layout       => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $status = Term::Fabulous::Widget::Text->new( text => '', text_color => [ 150, 160, 180, 255 ], wrap_mode => CLAY_TEXT_WRAP_NONE );
my $root   = Term::Fabulous::Widget::Box->new(
	layout => {
		layout_direction => CLAY_TOP_TO_BOTTOM,
		sizing           => { width => sizing_grow(), height => sizing_grow() },
		padding          => { left  => 1,             right  => 1 },
	},
);
$root->add_child( $view, $status );

# The view tells after every frame what it shows; the program follows
# links by naming them in the status line.
$view->on(
	ViewChange => sub ($event) {
		my $where = defined $event->section_title ? $event->section_title : 'top';
		my $marks
			= defined $event->link ? 'Enter follows ' . $event->link
			: $event->matches      ? sprintf( 'match %d of %d for "%s"', $event->match, $event->matches, $event->query )
			:                        'l selects a link, n the next match';
		$status->text( sprintf '%s  %3d%%  |  %s', $where, $event->percent, $marks );
		return;
	}
);
$view->on( LinkActivate => sub ($event) { $status->text( 'Followed the link to ' . $event->link ); return } );

my $ui = Term::Fabulous->new( width => 80, height => 24, root => $root );
$ui->interaction->set_focused_widget($view);
$view->search('block');
$ui->run;
