use v5.32;
use warnings;

use Test2::V0;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_fixed sizing_grow CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Divider;
use Term::Fabulous::Widget::Table;
use Term::Fabulous::Widget::Text;

sub text ($string) { return Term::Fabulous::Widget::Text->new( text => $string ) }

subtest 'a box stacks the estimates of its children' => sub {
	my $box = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, child_gap => 1, padding => { top => 1, bottom => 2, left => 1 } } );
	$box->add_child( text('aaaa bbbb cccc'), text('one'), Term::Fabulous::Widget::Divider->new );
	is $box->estimated_rows(10), 1 + 2 + ( 2 + 1 + 1 ) + 2, 'padding, the children in nine columns, and the gaps between them';
	is( Term::Fabulous::Widget::Box->new->estimated_rows(10), 0, 'an empty box takes no rows' );
};

subtest 'side by side the tallest child decides, fixed widths first' => sub {
	my $marker = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(4) } } );
	$marker->add_child( text('1.') );
	my $row = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_LEFT_TO_RIGHT } );
	$row->add_child( $marker, text('aaaa bbbb cccc') );
	is $row->estimated_rows(12), 3, 'the text wraps in the eight columns after the marker';
	is $row->estimated_rows(20), 1, 'and not when they are enough';
	my $pair = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_LEFT_TO_RIGHT } );
	$pair->add_child( text('aaaa bbbb'), text('x') );
	is $pair->estimated_rows(10), 2, 'two flexible children share the columns';
};

subtest 'a border, a fixed height and a display' => sub {
	my $framed = Term::Fabulous::Widget::Box->new( bordered => 1 );
	$framed->add_child( text('x') );
	is $framed->estimated_rows(10), 3, 'a border takes a row above and below';
	is( Term::Fabulous::Widget::Box->new( layout => { sizing => { height => sizing_fixed(7) } } )->estimated_rows(10), 7, 'a fixed height is the answer' );
	is( Term::Fabulous::Widget::Divider->new->estimated_rows(10),                                                      1, 'a display answers from its natural size' );
	my $table = Term::Fabulous::Widget::Table->new( id => 'table', columns => [ { key => 'n', title => 'N' } ], rows => [ map { { id => $_, n => $_ } } 1 .. 5 ], page_size => 2 );
	is $table->estimated_rows(20), 1 + 2 + 1, 'a table counts its header, the rows of its page and the pager';
};

done_testing;
