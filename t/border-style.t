use v5.22;
use warnings;

use Test2::V0;

use Term::Fabulous::Color;
use Term::Fabulous::Enum::BorderStyle;
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

subtest 'widget border styles are validated' => sub {
	like dies { Term::Fabulous::Widget::Box->new( border_style => 'Round' ) },     qr/border_style must be a Term::Fabulous::Enum::BorderStyle/, 'border_style string';
	like dies { Term::Fabulous::Widget::Box->new( border_style_top => 'Round' ) }, qr/border_style_top/,                                          'side parameter string';

	my $box = Term::Fabulous::Widget::Box->new( border_style => $Style->Round );
	ref_is $box->border_style_left, $Style->Round, 'border_style sets every side';
	like dies { $box->border_style_left('Round') }, qr/border_style_left/, 'accessor write is checked';
	ok lives { $box->border_style_left(undef) }, 'undef clears a side';
};

subtest 'widget colors take every Term::Fabulous::Color format' => sub {
	my $box = Term::Fabulous::Widget::Box->new( background_color => '#ff8800', border_color => Term::Fabulous::Color->rgb( 1, 2, 3 ) );
	is [ $box->background_color, $box->border_color ], [ [ 255, 136, 0, 255 ], [ 1, 2, 3, 255 ] ], 'constructor strings and objects become [r, g, b, a]';
	is $box->background_color('rgb(4, 5, 6)'), [ 4, 5, 6, 255 ], 'the writer converts too';
	is $box->background_color(undef), undef, 'undef still clears the color';
	like dies { Term::Fabulous::Widget::Box->new( border_color => 'nope' ) }, qr/border_color is not a color: Term::Fabulous::Color: unrecognized color string 'nope'/, 'an invalid color names the parameter';
	is( Term::Fabulous::Widget::Text->new( text => 'x', text_color => '#ffffff' )->text_color, [ 255, 255, 255, 255 ], 'Text text_color' );
	is( Term::Fabulous::Widget::ScrollBox->new( id => 's', vertical => '' )->vertical, 0, 'ScrollBox booleans are stored as 1 or 0' );
};

done_testing;
