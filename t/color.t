use v5.22;
use warnings;

use Test2::V0;

use Term::Fabulous::Color;

my $Color = 'Term::Fabulous::Color';

sub rgba_of {
	my ($spec) = @_;
	return [ $Color->new( color => $spec )->to_rgba ];
}

subtest 'string grammar' => sub {
	is rgba_of('#ff00ff'),              [ 255, 0,   255, 255 ], '#rrggbb';
	is rgba_of('7c3aed80'),             [ 124, 58,  237, 128 ], 'rrggbbaa without #';
	is rgba_of('rgb(255, 255, 255)'),   [ 255, 255, 255, 255 ], 'rgb() accepts 255';
	is rgba_of('hsl(0, 100%, 50%)'),    [ 255, 0,   0,   255 ], 'hsl()';
	is rgba_of('hsl(720, 100%, 50%)'),  [ 255, 0,   0,   255 ], 'hue is taken modulo 360';
	is rgba_of('hsla(120, 100%, 50%, 0.5)'), [ 0, 255, 0, 128 ], 'hsla()';
	like dies { $Color->new( color => 'white' ) }, qr/unrecognized color string 'white'/, 'named colors are not supported';
};

subtest 'alpha grammar' => sub {
	is rgba_of('rgba(1, 2, 3, 1)')->[3],    1,   'bare integer is the 0..255 channel';
	is rgba_of('rgba(1, 2, 3, 255)')->[3],  255, 'bare 255';
	is rgba_of('rgba(1, 2, 3, 1.0)')->[3],  255, 'decimal is a fraction of 1';
	is rgba_of('rgba(1, 2, 3, .25)')->[3],  64,  'leading-dot decimal, rounded';
	is rgba_of('rgba(1, 2, 3, 50%)')->[3],  128, 'percentage';
	like dies { rgba_of('rgba(1, 2, 3, 1.5)') },  qr/alpha fraction must be a number in 0\.\.1/,     'fraction above 1 dies';
	like dies { rgba_of('rgba(1, 2, 3, 101%)') }, qr/alpha percentage must be a number in 0\.\.100/, 'percentage above 100 dies';
	like dies { rgba_of('rgba(1, 2, 3, 256)') },  qr/alpha must be a number in 0\.\.255/,            'channel above 255 dies';
};

subtest 'hash, array and clone inputs' => sub {
	is rgba_of( { r => 1, g => 2, b => 3 } ),                           [ 1, 2, 3, 255 ], 'r/g/b hash';
	is rgba_of( { red => 1, green => 2, blue => 3, alpha => 4 } ),      [ 1, 2, 3, 4 ],   'red/green/blue/alpha hash';
	is rgba_of( [ 1, 2, 3 ] ),                                          [ 1, 2, 3, 255 ], 'three-element array';
	is rgba_of( $Color->new( color => [ 9, 8, 7, 6 ] ) ),               [ 9, 8, 7, 6 ],   'clone of another Color';
	like dies { rgba_of( { r => 1, g => 2 } ) },                qr/color hash needs exactly the keys/, 'incomplete hash dies';
	like dies { rgba_of( { r => 1, g => 2, b => 3, x => 4 } ) }, qr/color hash needs exactly the keys/, 'extra hash key dies';
	like dies { rgba_of( [ 1, 2 ] ) },                           qr/needs 3 or 4 elements, got 2/,      'short array dies';
	like dies { rgba_of(undef) },                                qr/invalid color input undef/,         'undef dies';
};

subtest 'channel validation and rounding' => sub {
	is rgba_of( [ 254.6, 0.4, 255, 0 ] ), [ 255, 0, 255, 0 ], 'channels are rounded to the nearest integer';
	like dies { rgba_of( [ 256, 0, 0 ] ) },   qr/red must be a number in 0\.\.255, got '256'/,  'above 255 dies';
	like dies { rgba_of( [ 0, -1, 0 ] ) },    qr/green must be a number in 0\.\.255, got '-1'/, 'negative dies';
	like dies { rgba_of( [ 0, 0, 'x' ] ) },   qr/blue must be a number in 0\.\.255, got 'x'/,   'non-numeric dies';
	like dies { rgba_of( [ 'nan', 0, 0 ] ) }, qr/red must be a number/,                         'NaN dies';
	like dies { $Color->new( color => [ 1, 2, 3 ], red => 1 ) }, qr/Unrecognised parameters/,    'channel params are not constructor params';
};

subtest 'HSL conversions round once' => sub {
	my $color = $Color->rgb( 10, 200, 30 );
	is [ $color->lighten(0)->to_rgba ], [ 10, 200, 30, 255 ], 'lighten(0) is an identity';
	is [ $color->to_hsl ], [ 126, 90, 41 ], 'to_hsl rounds';
	is [ $Color->hsl_to_rgb( 0, 100, 50 ) ], [ 255, 0, 0 ], 'hsl_to_rgb';
	is [ $Color->rgb_to_hsl( 255, 0, 0 ) ], [ 0, 100, 50 ], 'rgb_to_hsl';
	is [ $Color->hsl( 174, 72, 56 )->to_rgba ], [ $Color->new( color => 'hsl(174, 72%, 56%)' )->to_rgba ], 'hsl factory matches the string form';
	is [ $Color->hsla( 174, 72, 56, 0.5 )->to_rgba ]->[3], 128, 'hsla alpha is a 0..1 fraction';
	like dies { $Color->hsla( 0, 0, 0, 2 ) }, qr/alpha fraction must be a number in 0\.\.1/, 'hsla alpha above 1 dies';
	is [ $color->darken(0.1)->to_rgba ], [ $color->lighten(-0.1)->to_rgba ], 'darken is negative lighten';
};

done_testing;
