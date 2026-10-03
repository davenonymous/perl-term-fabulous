use v5.24;
use warnings;
use utf8;

use Test2::V0;

use Clay::XS ();
use Term::Fabulous::Check;

# Called by their full names: Test2::V0 exports a number and a string.
my %check = map { $_ => \&{"Term::Fabulous::Check::$_"} } qw(positive_integer non_negative_integer integer number string boolean glyph color cell_color);

# [ check, value, what it returns ]
my @accepted = (
	[ positive_integer     => '12',                12 ],
	[ non_negative_integer => 0,                   0 ],
	[ integer              => '-3',                -3 ],
	[ number               => '2.5',               2.5 ],
	[ number               => -1e-3,               -0.001 ],
	[ string               => '',                  '' ],
	[ string               => 42,                  42 ],
	[ boolean              => 'yes',               1 ],
	[ boolean              => '',                  0 ],
	[ boolean              => undef,               0 ],
	[ glyph                => "\x{2501}",          "\x{2501}" ],
	[ glyph                => "e\x{301}",          "e\x{301}" ],
	[ color                => '#ff8800',           [ 255, 136, 0, 255 ] ],
	[ color                => [ 1, 2, 3, 4 ],      [ 1, 2, 3, 4 ] ],
	[ color                => { r => 1, g => 2, b => 3 }, [ 1, 2, 3, 255 ] ],
	[ cell_color           => 0x102030,            [ 16, 32, 48, 255 ] ],
	[ cell_color           => 'rgb(255, 0, 0)',    [ 255, 0, 0, 255 ] ],
);

# [ check, value, the expectation the message names ]
my @rejected = (
	[ positive_integer     => 0,         "a positive integer, got '0'" ],
	[ positive_integer     => '1.5',     "a positive integer, got '1.5'" ],
	[ non_negative_integer => -1,        "a non-negative integer, got '-1'" ],
	[ integer              => 'x',       "an integer, got 'x'" ],
	[ integer              => undef,     'an integer, got undef' ],
	[ number               => 'inf',     "a finite number, got 'inf'" ],
	[ number               => [],        'a finite number, got an ARRAY reference' ],
	[ string               => undef,     'a string, got undef' ],
	[ string               => {},        'a string, got a HASH reference' ],
	[ boolean              => [],        'a plain boolean value, got an ARRAY reference' ],
	[ glyph                => 'ab',      "a single character one column wide, got 'ab'" ],
	[ glyph                => "\x{65E5}", "a single character one column wide, got '\x{65E5}'" ],
	[ color                => 'nope',    "a color, got 'nope' (unrecognized color string 'nope')" ],
	[ color                => undef,     'a color, got undef' ],
	[ cell_color           => 0x1000000, "a color, got '16777216' (a packed color is at most 0xFFFFFF)" ],
);

foreach my $case (@accepted) {
	my ( $name, $value, $expected ) = @$case;
	is $check{$name}->( 'My::Widget', property => $value ), $expected, "$name accepts " . ( defined $value ? "'$value'" : 'undef' );
}

foreach my $case (@rejected) {
	my ( $name, $value, $expected ) = @$case;
	like dies { $check{$name}->( 'My::Widget', property => $value ) }, qr/\AMy::Widget: property must be \Q$expected\E at /, "$name rejects " . ( defined $value ? "'$value'" : 'undef' );
}

subtest 'sizing' => sub {
	my $sizing = \&Term::Fabulous::Check::sizing;
	is $sizing->( 'My::Widget', width => 'fit(4, 30)' ), Clay::XS::sizing_fit( 4, 30 ), 'a spec string';
	is $sizing->( 'My::Widget', width => 'percent(25)' ), Clay::XS::sizing_percent(0.25), 'a percentage';
	is $sizing->( 'My::Widget', width => Clay::XS::sizing_grow() ), Clay::XS::sizing_grow(), 'a hash from Clay::XS is copied';
	like dies { $sizing->( 'My::Widget', width => 'wide' ) },        qr/\AMy::Widget: invalid width 'wide' \(expected grow, fit/, 'an unknown spec dies';
	like dies { $sizing->( 'My::Widget', width => 'fit(5, 2)' ) },   qr/width minimum 5 is greater than maximum 2/,           'a minimum above the maximum dies';
	like dies { $sizing->( 'My::Widget', width => 'percent(101)' ) }, qr/width percentage must be in 0\.\.100/,               'a percentage above 100 dies';
	like dies { $sizing->( 'My::Widget', width => { kind => 1 } ) }, qr/\AMy::Widget: invalid width: /,                       'an invalid hash dies';
};

my $owner = bless {}, 'My::Widget';
like dies { $check{string}->( $owner, label => undef ) }, qr/\AMy::Widget: label must be a string/, 'an object owner is named by its class';

is [ map { Term::Fabulous::Check::describe($_) } undef, 'nope', 12, [], {}, \'x' ], [ 'undef', "'nope'", "'12'", 'an ARRAY reference', 'a HASH reference', 'a SCALAR reference' ], 'describe names values as the messages do';

done_testing;
