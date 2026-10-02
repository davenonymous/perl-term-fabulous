use v5.24;
use warnings;

use Test2::V0;

use Term::Fabulous::Layout;
use Term::Fabulous::Widget::ScrollBox;

subtest 'directions' => sub {
	my $box = Term::Fabulous::Widget::ScrollBox->new( id => 'log' );
	is [ $box->horizontal, $box->vertical ], [ 0, 1 ], 'vertical by default';
	my $both = Term::Fabulous::Widget::ScrollBox->new( id => 'both', horizontal => 'yes', vertical => '' );
	is [ $both->horizontal, $both->vertical ], [ 1, 0 ], 'the constructor takes any truth value';
	is $both->to_config->{clip}, { horizontal => 1, vertical => 0 }, 'and hands Clay the directions';
	like dies { Term::Fabulous::Widget::ScrollBox->new }, qr/requires an explicit 'id'/, 'an id is required: Clay keeps the scroll position by it';
};

subtest 'KDL properties' => sub {
	my $built = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::ScrollBox as ScrollBox
ScrollBox "table" {
	horizontal #true
	vertical #false
}
KDL
	is [ $built->id, $built->horizontal, $built->vertical ], [ 'table', 1, 0 ], 'horizontal and vertical';
};

done_testing;
