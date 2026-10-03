use v5.24;
use warnings;

use Test2::V0;

use Term::Fabulous::Color;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Layout;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

my $Style = 'Term::Fabulous::Enum::BorderStyle';

subtest 'mixed joints' => sub {
	is $Style->Solid->get_mixed_joint( $Style->Heavy )->[0],   "\x{2542}", 'Solid crossing Heavy';
	is $Style->Solid->get_mixed_joint( $Style->Double )->[0],  "\x{256B}", 'Solid crossing Double';
	is $Style->Double->get_mixed_joint( $Style->Solid )->[1],  "\x{2564}", 'Double crossing Solid';
	is $Style->get_mixed_joints( $Style->Heavy, $Style->Solid )->[0], "\x{253F}", 'class-method form';
	is scalar( @{ $Style->Heavy->get_mixed_joint( $Style->Solid ) } ), 5, 'five glyphs';
	is $Style->Round->get_mixed_joint( $Style->Solid ), undef, 'no table';
	is $Style->Solid->get_mixed_joint( $Style->Round ), undef, 'no table for that vertical style';
	like dies { $Style->Solid->get_mixed_joint('Heavy') }, qr/vertical style must be a Term::Fabulous::Enum::BorderStyle/, 'a name is rejected';
	ref_is $Style->Dashed->joints, $Style->Heavy->joints, 'Dashed uses the heavy joints';
};

subtest 'junction' => sub {
	my ( $S, $H, $D, $R, $A ) = map { $Style->$_ } qw(Solid Heavy Double Round Ascii);
	is $Style->junction( left => $S, right => $S ),                            "\x{2500}", 'two opposite arms: the edge glyph';
	is $Style->junction( right => $Style->Dashed ),                            "\x{254D}", 'one arm: the edge glyph, a dashed line stays dashed';
	is $Style->junction( up => $S, down => $S ),                               "\x{2502}", 'vertical arms: the left edge glyph';
	is $Style->junction( right => $R, down => $R ),                            "\x{256D}", 'a corner of a round style is round';
	is $Style->junction( up => $S, left => $H ),                               "\x{251B}", 'a corner of mixed styles takes the horizontal one';
	is $Style->junction( up => $S, right => $S, down => $S, left => $S ),      "\x{253C}", 'four arms: the cross';
	is $Style->junction( left => $D, right => $D, down => $S ),                "\x{2564}", 'mixed families use the mixed joints';
	is $Style->junction( up => $S, down => $S, right => $H ),                  "\x{251D}", 'heavy to the right of a light line';
	is $Style->junction( up => $R, down => $R, left => $S, right => $S ),      "\x{253C}", 'Round counts as Solid';
	is $Style->junction( up => $H, down => $H, left => $D, right => $D ),      "\x{256C}", 'without a mixed table, the horizontal joints';
	is $Style->junction( right => $A, down => $A, left => $A ),                '+',         'Ascii joints';
	is $Style->junction( right => $Style->Blank, down => $Style->Thick ),      undef,       'styles without joints are no arms';
	is $Style->junction(),                                                     undef,       'no arms';
	like dies { $Style->junction( middle => $S ) }, qr/junction takes the arms up, right, down and left, got middle/, 'an unknown arm dies';
	like dies { $Style->junction( up => 'Solid' ) }, qr/the up arm style must be a Term::Fabulous::Enum::BorderStyle/, 'a style name dies';
};

subtest 'style list' => sub {
	is $Style->from_name('Tab'), undef, 'Tab is gone';
	isa_ok $Style->from_name('Hidden'), [$Style], 'Hidden exists';
	like dies { Term::Fabulous::Layout->new( string => "use Term::Fabulous::Widget::Box as Box\nBox {\n\tborder style=Tab\n}" )->build },
		qr/invalid border style 'Tab' \(known: Ascii, .*Wide\)/, 'a layout with style=Tab dies';
};

subtest 'widget border styles are validated' => sub {
	like dies { Term::Fabulous::Widget::Box->new( border_style => 'Round' ) },     qr/border_style must be a Term::Fabulous::Enum::BorderStyle/, 'border_style string';
	like dies { Term::Fabulous::Widget::Box->new( border_style_top => 'Round' ) }, qr/border_style_top/,                                          'side parameter string';

	my $box = Term::Fabulous::Widget::Box->new( border_style => $Style->Round );
	ref_is $box->border_style_left, $Style->Round, 'border_style sets every side';
	my $mixed = Term::Fabulous::Widget::Box->new( border_style => $Style->Round, border_style_left => $Style->Thick );
	is [ map { $mixed->$_ } qw(border_style_left border_style_top) ], [ $Style->Thick, $Style->Round ], 'a side parameter wins over border_style';
	like dies { $box->border_style_left('Round') }, qr/border_style_left/, 'accessor write is checked';
	ok lives { $box->border_style_left(undef) }, 'undef clears a side';
};

subtest 'widget colors take every Term::Fabulous::Color format' => sub {
	my $box = Term::Fabulous::Widget::Box->new( background_color => '#ff8800', border_color => Term::Fabulous::Color->rgb( 1, 2, 3 ) );
	is [ $box->background_color, $box->border_color ], [ [ 255, 136, 0, 255 ], [ 1, 2, 3, 255 ] ], 'constructor strings and objects become [r, g, b, a]';
	is $box->background_color('rgb(4, 5, 6)'), [ 4, 5, 6, 255 ], 'the writer converts too';
	is $box->background_color(undef), undef, 'undef still clears the color';
	like dies { Term::Fabulous::Widget::Box->new( border_color => 'nope' ) }, qr/\ATerm::Fabulous::Widget::Box: border_color must be a color, got 'nope' \(unrecognized color string 'nope'\)/, 'an invalid color names the parameter';
	is( Term::Fabulous::Widget::Text->new( text => 'x', text_color => '#ffffff' )->text_color, [ 255, 255, 255, 255 ], 'Text text_color' );
	is( Term::Fabulous::Widget::ScrollBox->new( id => 's', vertical => '' )->vertical, 0, 'ScrollBox booleans are stored as 1 or 0' );
};

done_testing;
