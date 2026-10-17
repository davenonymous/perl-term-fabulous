use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use Clay::XS qw(sizing_grow);
use DocumentTest;
use List::Util qw(first);
use Object::Pad 0.825;
use Term::Fabulous;
use Term::Fabulous::Color;
use Term::Fabulous::Document::Block;
use Term::Fabulous::Document::Look;
use Term::Fabulous::Event::ViewChange;
use Term::Fabulous::Render::Attr qw(color_attr);
use Term::Fabulous::Terminal::Memory;
use Term::Fabulous::Termbox qw(TF_KEY_MOUSE_WHEEL_RIGHT);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Divider;
use Term::Fabulous::Widget::DocumentView;

my $SAMPLE = sample_document();
my $LONG   = long_document();

# The view of a document, focused, filling a memory terminal of the
# given size; every LinkActivate and ViewChange is collected.
sub document_ui ( $document, $width = 60, $height = 12, $class = 'Term::Fabulous::Widget::DocumentView' ) {
	my $view = $class->new(
		id       => 'document',
		document => $document,
		bordered => 1,
		layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
	);
	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$root->add_child($view);
	my $terminal = Term::Fabulous::Terminal::Memory->new( width => $width, height => $height );
	my $ui       = Term::Fabulous->new( root => $root, width => $width, height => $height, terminal => $terminal );
	my %h        = ( terminal => $terminal, ui => $ui, activated => [], views => [] );
	$view->on( LinkActivate => sub ($event) { push @{ $h{activated} }, $event; return } );
	$view->on( ViewChange   => sub ($event) { push @{ $h{views} },     $event; return } );
	$ui->interaction->set_focused_widget($view);
	$ui->step;
	return ( $view, \%h );
}

# The rows inside the border, without the scrollbar column: row 0 is
# the terminal's row 1, and column 0 its column 1.
sub screen ($h) {
	my @lines = $h->{terminal}->lines;
	return [ map { substr( $_, 1, length($_) - 3 ) =~ s/\s+\z//r } @lines[ 1 .. $#lines - 1 ] ];
}

sub press ( $h, @keys ) {
	$h->{terminal}->press_key($_) foreach @keys;
	$h->{ui}->step;
	return;
}

sub row_of ( $h, $text ) {
	my $rows = screen($h);
	return ( grep { index( $rows->[$_], $text ) >= 0 } 0 .. $#$rows )[0];
}

# The terminal column and row of the first occurrence of a text on the
# screen, and its cell.
sub position_of ( $h, $text ) {
	my $row = row_of( $h, $text ) // return ();
	return ( 1 + index( screen($h)->[$row], $text ), 1 + $row );
}

sub cell_of ( $h, $text ) {
	my @position = position_of( $h, $text ) or return undef;
	return $h->{terminal}->cell(@position);
}

# The Text the view built for the block whose text starts so.
sub rich_text_of ( $view, $start ) {
	return first { $_->isa('Term::Fabulous::Widget::Text') && index( $_->text, $start ) == 0 } $view->descendants;
}

sub attr_of ($color) {
	return color_attr( Term::Fabulous::Color->new( color => $color ) );
}

subtest 'parameters' => sub {
	like dies {
		Term::Fabulous::Widget::DocumentView->new( id => 'd', build => sub { } )
	}, qr/build cannot be given/, 'the items come from the document';
	like dies { Term::Fabulous::Widget::DocumentView->new( id => 'd', document => {} ) }, qr/document must be a Term::Fabulous::Document/, 'a document is a document';
	like dies { Term::Fabulous::Widget::DocumentView->new( id => 'd', document => document( paragraph('<shiny>x</shiny>') ) ) },
		qr/mark of kind 'shiny', which Term::Fabulous::Document::Look does not know/,
		'a mark of a kind the look has no style for';
	my $view = Term::Fabulous::Widget::DocumentView->new( id => 'd', document => $SAMPLE );
	is $view->count, $SAMPLE->count, 'there is an item per block';
	like dies { $view->count(3) }, qr/count cannot be set/, 'and nobody else decides that';
	is( Term::Fabulous::Widget::DocumentView->new( id => 'e' )->count, 0, 'a view without a document is empty' );
};

subtest 'blocks' => sub {
	my ( $view, $h ) = document_ui( $SAMPLE, 60, 40 );
	my $rows = screen($h);
	is [ @$rows[ 0 .. 4 ] ], [ ' NAME', ' ' . ( "\x{2500}" x 55 ), '', '   Sample - a page to test the document view with', '' ], 'a first-level heading has a rule, paragraphs are indented';
	my $item = row_of( $h, 'First point.' );
	is [ @$rows[ $item .. $item + 4 ] ], [ "   \x{2022} First point.", "   \x{2022} Second point with Details.", '', '   1. One.', '   2. Two.' ],
		'the items of a list follow each other, lists are apart';
	my $term = row_of( $h, 'frobnicate VALUE' );
	is $rows->[ $term + 1 ],                   '       Frobnicates the VALUE.', 'a term is followed by its definition';
	is $rows->[ row_of( $h, 'use Sample;' ) ], '    use Sample;',               'code is shown as it is';

	my $look = $view->document_look;
	my $bold = cell_of( $h, 'bold,' );
	is $bold->[0], 'b', 'the bold word';
	ok $bold->[1] & $look->style('bold')->{set}, 'is drawn bold';
};

subtest 'block quotes' => sub {
	my ( $view, $h ) = document_ui( document( paragraph( 'Quoted.', quote => 1 ), paragraph( 'Deeper.', quote => 2 ) ), 40, 8 );
	is [ @{ screen($h) }[ 0 .. 2 ] ], [ " \x{2502}   Quoted.", " \x{2502} \x{2502}", " \x{2502} \x{2502}   Deeper." ],    'a bar per quote level, and the blank row between the blocks inside the bars';
	is $h->{terminal}->cell( 2, 1 )->[1] & 0xFFFFFF, attr_of( $view->document_look->style('quote')->{color} ) & 0xFFFFFF, 'in the quote color';
	$h->{ui}->theme('light');
	$h->{ui}->step;
	is $h->{terminal}->cell( 2, 1 )->[1] & 0xFFFFFF, attr_of( $view->document_look->style('quote')->{color} ) & 0xFFFFFF, 'which follows the theme';
};

subtest 'scrolling keys' => sub {
	my ( $view, $h ) = document_ui($LONG);
	press( $h, 'Down', 'j' );
	is screen($h)->[0], '', 'Down and j scroll a row each';
	press( $h, 'End' );
	is screen($h)->[-1],         '   The last paragraph.', 'End shows the end';
	is $h->{views}[-1]->percent, 100,                      'which is 100 percent';
	press( $h, 'Home' );
	is screen($h)->[0], ' NAME', 'Home shows the top';
	press( $h, 'PageDown' );
	is $view->top_block, 4, 'PageDown scrolls by the rows shown less one';
	press( $h, 'b' );
	is $view->top_block, 0, 'b scrolls back';
};

subtest 'links' => sub {
	my ( $view, $h ) = document_ui($SAMPLE);
	press( $h, 'Enter' );
	is $h->{activated}, [], 'Enter does nothing while no link is selected';
	press( $h, 'l' );
	is $view->selected_link,                              'Other',                                                                   'l selects the first link in view';
	is rich_text_of( $view, 'Some bold' )->selected_link, 0,                                                                         'the text of its block shows it selected';
	is cell_of( $h, 'Other and one' )->[2],               attr_of( $h->{ui}->theme->look( 'text', 'link.background', 'selected' ) ), 'in the look of a selected link';
	press( $h, 'l', 'Enter' );
	my ( undef, $section ) = $SAMPLE->block(5)->links;
	is [ map { [ $_->link, $_->index, $_->start, $_->end ] } @{ $h->{activated} } ], [ [ '/Methods', 1, $section->start, $section->end ] ], 'Enter fires LinkActivate for the selected link';
	ref_is $h->{activated}[0]->target, $view, 'on the view';
	press( $h, 'L', 'L', 'L' );
	is $view->selected_link,  'Other', 'L goes back and stops at the first link';
	is $h->{views}[-1]->link, 'Other', 'ViewChange reports the selected link';
	$view->rebuild;
	$h->{ui}->step;
	is rich_text_of( $view, 'Some bold' )->selected_link, 0, 'a text built again shows it too';
	press( $h, 'Escape' );
	is $view->selected_link, undef, 'Escape drops the selection';
};

subtest 'clicking a link' => sub {
	my ( $view, $h ) = document_ui( $SAMPLE, 60, 40 );
	press( $h, 'l' );
	$h->{terminal}->click( position_of( $h, 'Details' ) );
	$h->{ui}->step;
	my ($event) = @{ $h->{activated} };
	is [ $event->link, $view->selected_link ], [ 'Other/Details', 'Other/Details' ], 'a click on a link fires LinkActivate with its link and selects the link in the view';
	is [ rich_text_of( $view, 'Some bold' )->selected_link, rich_text_of( $view, 'Second point' )->selected_link ], [ undef, 0 ], 'the selection moved from one block to the other';
	press( $h, 'l' );
	is $view->selected_link, 'Other', 'l goes on from the clicked link';
};

subtest 'search' => sub {
	my ( $view, $h ) = document_ui($LONG);
	is $view->search('needle'), 120, 'search counts the matches';
	$h->{ui}->step;
	is [ $view->current_match, $h->{views}[-1]->matches, $h->{views}[-1]->query ], [ 1, 120, 'needle' ], 'the first one is current, and the ViewChange names the query';
	press( $h, 'N' );
	is $view->current_match, 120, 'N goes around to the last';
	ok defined row_of( $h, 'Paragraph 120 ' ), 'and scrolls it into view';
	my $look = $view->document_look;
	my $row  = row_of( $h, 'Paragraph 120 ' );
	is $h->{terminal}->cell( 1 + index( screen($h)->[$row], 'needle' ), 1 + $row )->[2], attr_of( $look->style('match_current')->{background} ), 'in the style of the current match';
	press( $h, 'n' );
	is $view->current_match, 1, 'n goes around to the first';
	press( $h, 'Escape' );
	is [ $view->query, $view->match_count ], [ undef, 0 ], 'Escape ends the search';
};

subtest 'ViewChange' => sub {
	my ( $view, $h ) = document_ui($SAMPLE);
	my $first = $h->{views}[0];
	is [ $first->top, $first->section, $first->percent ], [ 0, 0, 0 ], 'the first frame is reported';
	my $count = @{ $h->{views} };
	$h->{ui}->invalidate;
	$h->{ui}->step;
	is scalar @{ $h->{views} }, $count, 'a frame that shows the same is not';
	$view->show_block( $SAMPLE->find_section('Lists') );
	$h->{ui}->step;
	is [ $h->{views}[-1]->section, $h->{views}[-1]->section_title ], [ 4, 'Lists' ], 'the section follows the top block, with its title';
	like dies { Term::Fabulous::Event::ViewChange->new( section => 1 ) }, qr/section and section_title go together/, 'a section never comes without its title';
	like dies { Term::Fabulous::Event::ViewChange->new( matches => 2 ) }, qr/2 matches without a query/,             'matches never come without their query';
};

subtest 'code scrolls sideways' => sub {
	my ( $view, $h ) = document_ui( document( verbatim( join ' ', ('word') x 30 ), paragraph('Text.') ), 40, 8 );
	press( $h, 'Right' );
	is $view->code_offset, 8, 'Right scrolls the code';
	like screen($h)->[0], qr/\A   \x{2039}/, 'and the code shows it is scrolled';
	press( $h, 'Left', 'Left' );
	is $view->code_offset, 0, 'Left scrolls back, as far as the start';
	$h->{terminal}->mouse( key => TF_KEY_MOUSE_WHEEL_RIGHT, x => 10, y => 1 );
	$h->{ui}->step;
	is $view->code_offset, 3, 'so does the horizontal wheel, three columns a notch';
};

subtest 'theme switch' => sub {
	my ( $view, $h ) = document_ui($SAMPLE);
	$h->{ui}->theme('light');
	$h->{ui}->step;
	my $light = Term::Fabulous::Document::Look->new( theme => $h->{ui}->theme );
	is cell_of( $h, 'NAME' )->[1] & 0xFFFFFF, attr_of( $light->style('heading1')->{color} ) & 0xFFFFFF, 'headings are restyled in the new theme';
};

subtest 'the border is dropped at runtime' => sub {
	my ( $view, $h ) = document_ui($LONG);
	$view->bordered(0);
	$h->{ui}->step;
	my @lines = $h->{terminal}->lines;
	like $lines[0], qr/\A NAME/, 'the content moves into the rows of the border';
	is scalar( grep { substr( $_, -1 ) ne ' ' } @lines ), scalar @lines, 'and the scrollbar into the last column, on every row';
};

subtest 'a match deep inside a tall block' => sub {
	my $code = join "\n", map { $_ == 38 ? "line $_ needle" : "line $_" } 1 .. 45;
	my ( $view, $h ) = document_ui( document( paragraph('Intro.'), verbatim($code) ) );
	$view->search('needle');
	$h->{ui}->step;
	ok defined row_of( $h, 'line 38 needle' ), 'search shows the line of the match, not the top of its block';

	my $long = join ' ', map { "word$_" } 1 .. 400;
	my ( $prose_view, $h2 ) = document_ui( document( paragraph("$long target") ) );
	$prose_view->search('target');
	$h2->{ui}->step;
	ok defined row_of( $h2, 'target' ), 'and the line of a match in a long paragraph';
};

subtest 'a match deep inside a tall block far below' => sub {
	my $code = join "\n", map { $_ == 38 ? "line $_ needle" : "line $_" } 1 .. 45;
	my ( $view, $h ) = document_ui( document( ( map { paragraph("Paragraph $_.") } 1 .. 80 ), verbatim($code) ) );
	$view->search('needle');
	$h->{ui}->step;
	ok defined row_of( $h, 'line 38 needle' ), 'the line shows once the block was built and measured';
};

subtest 'the horizontal wheel goes on when no code can move' => sub {
	my ( $view, $h ) = document_ui($SAMPLE);
	my @notches;
	$h->{ui}->root->on( Mouse => sub ($event) { push @notches, $event->key; return } );
	$h->{terminal}->mouse( key => TF_KEY_MOUSE_WHEEL_RIGHT, x => 10, y => 3 );
	$h->{ui}->step;
	is [ $view->code_offset, scalar @notches ], [ 0, 1 ], 'the notch reaches the widgets around';
};

subtest 'a theme switch restyles blocks out of view' => sub {
	my ( $view, $h ) = document_ui($SAMPLE);
	press( $h, 'End' );
	$h->{ui}->theme('light');
	$h->{ui}->step;
	press( $h, 'Home' );
	my $light = Term::Fabulous::Document::Look->new( theme => $h->{ui}->theme );
	is cell_of( $h, 'NAME' )->[1] & 0xFFFFFF, attr_of( $light->style('heading1')->{color} ) & 0xFFFFFF, 'in the colors of the new theme when they come back';
};

subtest 'another document' => sub {
	my ( $view, $h ) = document_ui($LONG);
	$view->search('needle');
	press( $h, 'End' );
	$view->document($SAMPLE);
	$h->{ui}->step;
	is [ screen($h)->[0], $view->match_count ], [ ' NAME', 0 ], 'starts at its top, without the search of the last one';

	$view->document( document( heading( 1, 'A' ), verbatim( 'x' x 120 ) ) );
	$h->{ui}->step;
	press( $h, 'Right' );
	my $count = @{ $h->{views} };
	$view->document( document( heading( 1, 'A' ), verbatim( 'y' x 120 ) ) );
	$h->{ui}->step;
	is $view->code_offset,      0,          'with its code not scrolled sideways';
	is scalar @{ $h->{views} }, $count + 1, 'and a ViewChange, even when the view looks the same as before';
};

# A block kind of another format: a horizontal rule, one row high, and a
# view that knows how to show it.
class My::Rule :isa(Term::Fabulous::Document::Block) {
	method kind ()                 { return 'rule' }
	method body_rows :override ($) { return 1 }
}

class My::Look :isa(Term::Fabulous::Document::Look) {

	method recipes :common () {
		return ( $class->SUPER::recipes, code_block => { color => 'text', background => 'accent' } );
	}
}

class My::View :isa(Term::Fabulous::Widget::DocumentView) {

	method look_class :common () { return 'My::Look' }

	method view_of_rule ( $block, $padding ) {
		return { widget => $self->boxed( $padding, Term::Fabulous::Widget::Divider->new ), text => undef };
	}
}

class My::WrongText :isa(Term::Fabulous::Widget::DocumentView) {

	method view_of_rule ( $block, $padding ) {
		my $divider = Term::Fabulous::Widget::Divider->new;
		return { widget => $self->boxed( $padding, $divider ), text => $divider };
	}
}

subtest 'a block kind of a subclass' => sub {
	my $document = document( paragraph('Above.'), My::Rule->new( text => '' ), paragraph('Below.') );
	my ( $view, $h ) = document_ui( $document, 40, 8, 'My::View' );
	is [ @{ screen($h) }[ 0 .. 4 ] ],            [ '   Above.', '', '   ' . ( "\x{2500}" x 33 ), '', '   Below.' ], 'the subclass shows the rule with its view_of_rule';
	is $view->geometry->estimated_rows( 1, 40 ), 2,                                                                 'and the block tells its rows';
	like dies { document_ui( $document, 40, 8 ) }, qr/no view_of_rule method for a block of kind 'rule'/, 'the base view dies for a kind it has no builder for';
	like dies { document_ui( $document, 40, 8, 'My::WrongText' ) }, qr/view_of_rule must return a Term::Fabulous::Widget::Text, .* as text, got a Term::Fabulous::Widget::Divider/,
		'and a text that is no Text or CodeBlock dies when the block is built';
};

subtest 'the code blocks of a subclass paint with its look' => sub {
	my ( $view, $h ) = document_ui( document( verbatim('code') ), 40, 8, 'My::View' );
	is cell_of( $h, 'code' )->[2], attr_of( My::Look->of($view)->style('code_block')->{background} ), 'a verbatim block takes the code_block style of the view\'s look class';
};

done_testing;
