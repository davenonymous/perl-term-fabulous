use v5.22;
use warnings;

use Test2::V0;

use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;

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

done_testing;
