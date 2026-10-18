use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM);
use Term::Fabulous;
use Term::Fabulous::Scrolling qw(inner_rows page_rows reveal_rows scroll_by_pages scroll_by_rows scroll_to_end scroll_to_start scrolled_percent);
use Term::Fabulous::Terminal::Memory;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

# A ScrollBox of $lines lines, 10 rows tall from row 2 of the screen,
# with a border and a padding of a row above and below: its content
# shows in the 6 rows from row 4 to row 9. 30 lines and the 4 rows of
# border and padding scroll by up to 24 rows.
sub scroll_box_ui ( $lines = 30 ) {
	my $box = Term::Fabulous::Widget::ScrollBox->new(
		id       => 'box',
		vertical => 1,
		bordered => 1,
		layout   => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_fixed(10) }, padding => { top => 1, bottom => 1 } },
	);
	$box->add_child( Term::Fabulous::Widget::Text->new( text => "line $_" ) ) foreach 0 .. $lines - 1;
	my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { top => 2 } } );
	$root->add_child($box);
	my $terminal = Term::Fabulous::Terminal::Memory->new( width => 20, height => 14 );
	my $ui       = Term::Fabulous->new( root => $root, width => 20, height => 14, terminal => $terminal );
	return ( $ui, $box );
}

sub offset ( $ui, $box ) {
	return -$ui->scroll_state($box)->{position}{y};
}

# Each move, then the offset after it.
sub moves ( $ui, $box, @moves ) {
	return [ map { ( $_->(), offset( $ui, $box ) ) } @moves ];
}

subtest 'before the first frame' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	is [ scroll_by_rows( $ui, $box, 1 ), scroll_by_pages( $ui, $box, 1 ), scroll_to_end( $ui, $box ) ], [ 0, 0, 0 ], 'nothing scrolls';
	is [ inner_rows( $ui, $box ), page_rows( $ui, $box ), scrolled_percent( $ui, $box ) ], [ undef, undef ], 'and nothing is measured';
};

subtest 'rows' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	is moves( $ui, $box, sub { scroll_by_rows( $ui, $box, 3 ) }, sub { scroll_by_rows( $ui, $box, -1 ) }, sub { scroll_by_rows( $ui, $box, -5 ) } ), [ 1, 3, 1, 2, 1, 0 ],
		'scroll down and up, as far as the top';
	is scroll_by_rows( $ui, $box, -1 ), 0, 'and return 0 at the top';
	like dies { scroll_by_rows( $ui,   $box, 1.5 ) }, qr/scroll_by_rows needs a number of rows, got '1\.5'/, 'a row is whole';
	like dies { scroll_by_rows( undef, $box, 1 ) },   qr/scroll_by_rows needs a UI, got undef/,              'and needs a UI';
};

subtest 'pages' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	is [ inner_rows( $ui, $box ) ], [ 4, 10 ], 'the content shows inside the border and the padding';
	is page_rows( $ui, $box ),      5,         'a page is those rows less one';
	is moves( $ui, $box, sub { scroll_by_pages( $ui, $box, 2 ) }, sub { scroll_by_pages( $ui, $box, -1 ) }, sub { scroll_by_pages( $ui, $box, 9 ) } ), [ 1, 10, 1, 5, 1, 24 ],
		'pages go down and up, as far as the end';
	is scroll_by_pages( $ui, $box, 1 ), 0, 'and return 0 at the end';
};

subtest 'the ends' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	is moves( $ui, $box, sub { scroll_to_end( $ui, $box ) }, sub { scroll_to_end( $ui, $box ) }, sub { scroll_to_start( $ui, $box ) }, sub { scroll_to_start( $ui, $box ) } ),
		[ 1, 24, 0, 24, 1, 0, 0, 0 ],
		'to the end and to the start, once';
};

subtest 'revealing rows' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	is moves( $ui, $box, sub { reveal_rows( $ui, $box, 9, 10 ) }, sub { reveal_rows( $ui, $box, 12, 13 ) } ), [ 0, 0, 1, 3 ], 'a row in view stays, one below comes up to the last row';
	$ui->step;
	is moves( $ui, $box, sub { reveal_rows( $ui, $box, 2, 3 ) } ), [ 1, 1 ], 'one above comes down to the first row';
};

subtest 'revealing rows at the top' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	is moves( $ui, $box, sub { reveal_rows( $ui, $box, 6, 7, align => 'top' ) } ), [ 1, 2 ], 'a row in view moves up to the first inner row';
	$ui->step;
	is moves( $ui, $box, sub { reveal_rows( $ui, $box, 4,   5,   align => 'top' ) } ), [ 0, 2 ],  'the first inner row stays';
	is moves( $ui, $box, sub { reveal_rows( $ui, $box, 100, 101, align => 'top' ) } ), [ 1, 24 ], 'near the end the content stops at its end';
	like dies { reveal_rows( $ui, $box, 4, 5, align  => 'middle' ) }, qr/reveal_rows: align must be one of nearest, top, got 'middle'/, 'another align dies';
	like dies { reveal_rows( $ui, $box, 4, 5, center => 1 ) },        qr/reveal_rows does not take center \(known: align\)/,            'and another option';
};

subtest 'the percentage' => sub {
	my ( $ui, $box ) = scroll_box_ui();
	$ui->step;
	my @percents;
	foreach my $rows ( 0, 5, 13, 6 ) {
		scroll_by_rows( $ui, $box, $rows );
		push @percents, scrolled_percent( $ui, $box );
	}
	is \@percents, [ 0, 21, 75, 100 ], 'the share of the way down, rounded';

	my ( $short_ui, $short ) = scroll_box_ui(3);
	$short_ui->step;
	is scrolled_percent( $short_ui, $short ), 100, 'content that fits is seen whole';
};

done_testing;
