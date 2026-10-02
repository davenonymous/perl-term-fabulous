use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use InputTest;
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_WHEEL_UP TB_MOD_MOTION);
use Term::Fabulous::Widget::Slider;

sub slider {
	my $slider = Term::Fabulous::Widget::Slider->new( preferred_columns => 11, @_ );
	my $ui     = layout_ui($slider);
	my @changes;
	$slider->on( Change => sub { push @changes, $_[0]->value; return } );
	return ( $slider, $ui, \@changes );
}

subtest 'painting' => sub {
	my ( $slider, $ui ) = slider( value => 50 );
	is [ $slider->columns, row_text( $slider, 0 ) ], [ 15, ( "\x{2501}" x 5 ) . "\x{25CF}" . ( "\x{2500}" x 5 ) . '  50' ], 'track, thumb and value';
	$slider->show_value(0);
	is row_text( $slider, 0 ), ( "\x{2501}" x 7 ) . "\x{25CF}" . ( "\x{2500}" x 7 ), 'without the value the track takes the width';
	$slider->value_format('%d%%');
	$slider->show_value(1);
	like row_text( $slider, 0 ), qr/ 50%\z/, 'a sprintf format';
};

subtest 'values snap to the step' => sub {
	my ($slider) = slider( min => 0, max => 1, step => 0.1, value => 0.33 );
	is $slider->value, 0.3, 'rounded to the step, without floating-point noise';
	is $slider->format_value( $slider->value ), '0.3', 'shown with the step decimals';
	is( ( slider( min => 0, max => 10, step => 3, value => 10 ) )[0]->value, 9, 'the highest value on the grid' );
	my ($offset) = slider( min => 0.5, max => 10.5, step => 1 );
	is [ $offset->value, $offset->value(2.5), $offset->format_value(2.5) ], [ 0.5, 2.5, '2.5' ], 'the decimals of min count too';
	is( ( slider( min => 0, max => 1e-9, step => 1e-12, value => 3e-12 ) )[0]->value, 3e-12, 'a tiny step keeps its decimals' );

	$slider->max(0.2);
	is $slider->value, 0.2, 'a new range moves the value into it';
	like dies { $slider->value(2) },                                   qr/value must be in 0\.\.0\.2/,      'a value outside the range dies';
	like dies { Term::Fabulous::Widget::Slider->new( min => 5, max => 5 ) }, qr/min \(5\) must be less than max/, 'an empty range dies';
	like dies { Term::Fabulous::Widget::Slider->new( step => 0 ) },          qr/step must be positive/,           'a zero step dies';
};

subtest 'keys' => sub {
	my ( $slider, $ui, $changes ) = slider( value => 50, step => 5 );
	press( $slider, $_ ) foreach qw(Right Up Left Down PageUp PageDown End Right Home Left);
	is $changes, [ 55, 60, 55, 50, 60, 50, 100, 0 ], 'steps, pages (a tenth of the range) and the ends; no event without a move';
	is $slider->page_step, 10, 'the default page step';
};

subtest 'mouse' => sub {
	my ( $slider, $ui, $changes ) = slider( show_value => 0 );
	click( $slider, 10, 0 );
	click( $slider, 4, 0, modifiers => TB_MOD_MOTION );
	click( $slider, 4, 0, key => TB_KEY_MOUSE_WHEEL_UP );
	is $changes, [ 100, 40, 41 ], 'pressing and dragging set the value at the pointer, the wheel steps';
};

done_testing;
