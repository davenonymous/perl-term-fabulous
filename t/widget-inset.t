use v5.22;
use warnings;

use Test2::V0;

use Clay::UI;
use Clay::XS qw(CLAY_RENDER_COMMAND_TYPE_TEXT);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;

subtest 'border width is added to the padding' => sub {
	my $box = Term::Fabulous::Widget::Box->new( border_width => 1, layout => { padding => { left => 2 }, child_gap => 1 } );
	my $config = $box->to_config;
	is $config->{layout}{padding}, { left => 3, right => 1, top => 1, bottom => 1 }, 'scalar width on every side';
	is $config->{layout}{child_gap}, 1, 'other layout keys are kept';

	my $sides = Term::Fabulous::Widget::Box->new( border_width => { left => 2, top => 1, between_children => 5 } );
	is $sides->to_config->{layout}{padding}, { left => 2, right => 0, top => 1, bottom => 0 }, 'per-side widths, between_children ignored';

	my $button = Term::Fabulous::Widget::Button->new( border_width => 1 );
	is $button->to_config->{layout}{padding}, { left => 1, right => 1, top => 1, bottom => 1 }, 'subclasses get the inset too';

	my $plain = Term::Fabulous::Widget::Box->new( layout => { padding => { left => 2 } } );
	is $plain->to_config->{layout}, $plain->layout, 'without a border the layout is passed through';

	like dies { Term::Fabulous::Widget::Box->new( border_width => -1 ) }, qr/'border_width'.*'-1'/, 'Clay::UI rejects a negative width when it is set';
};

subtest 'the stored layout is never modified' => sub {
	my $box    = Term::Fabulous::Widget::Box->new( border_width => 1, layout => { padding => { left => 2 } } );
	my $first  = $box->to_config;
	my $second = $box->to_config;
	is $second->{layout}{padding}, $first->{layout}{padding}, 'repeated to_config gives the same padding';
	is $box->layout, { padding => { left => 2 } }, 'widget layout unchanged';
};

subtest 'Clay places content inside the border' => sub {
	my $root = Term::Fabulous::Widget::Box->new( border_width => 1, layout => { padding => { left => 1 } } );
	$root->add_child( Term::Fabulous::Widget::Text->new( text => 'hi' ) );
	my $ui = Clay::UI->new(
		width        => 20,
		height       => 5,
		root         => $root,
		measure_text => sub { return { width => length $_[0], height => 1 } },
	);
	my ($text) = grep { $_->{commandType} == CLAY_RENDER_COMMAND_TYPE_TEXT } @{ $ui->render };
	is [ @{ $text->{boundingBox} }{qw(x y)} ], [ 2, 1 ], 'text starts after border and padding';
};

done_testing;
