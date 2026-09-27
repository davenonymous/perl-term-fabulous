use v5.22;
use warnings;

use Test2::V0;

use Termbox 2 qw(TB_DEFAULT TB_TRUECOLOR_BLACK);
use Term::Fabulous::Color;
use Term::Fabulous::Render::Attr qw(color_attr clay_color);

subtest 'color_attr' => sub {
	is color_attr( Term::Fabulous::Color->rgba( 0, 0, 0, 255 ) ), TB_TRUECOLOR_BLACK, 'opaque black';
	is color_attr( Term::Fabulous::Color->rgba( 0, 0, 0, 0 ) ),   TB_DEFAULT,         'alpha 0 is the terminal default';
	is color_attr( Term::Fabulous::Color->rgba( 9, 9, 9, 0 ) ),   TB_DEFAULT,         'alpha 0 ignores the channels';
	is color_attr( Term::Fabulous::Color->rgb( 18, 52, 86 ) ),    0x123456,           'packed rgb';
	is color_attr( Term::Fabulous::Color->rgba( 18, 52, 86, 1 ) ), 0x123456,          'partial alpha is opaque';
	is color_attr( Term::Fabulous::Color->rgb( 255, 255, 255 ) ), 0xFFFFFF,           'white stays inside the color bits';
};

subtest 'clay_color' => sub {
	my $color = clay_color( { r => '20', g => '25', b => '35', a => '255' } );
	isa_ok $color, 'Term::Fabulous::Color';
	is [ $color->to_rgba ], [ 20, 25, 35, 255 ], 'channels';
	ref_is clay_color( { r => 20, g => 25, b => 35, a => 255 } ), $color, 'memoized by channel values';
	like dies { clay_color(undef) }, qr/must be a hash reference/, 'undef dies';
	like dies { clay_color( { r => 300, g => 0, b => 0, a => 255 } ) }, qr/red must be a number in 0\.\.255/, 'invalid channel dies';
};

done_testing;
