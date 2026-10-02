use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use Clay::XS qw(sizing_fixed CLAY_TOP_TO_BOTTOM);
use InputTest;
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_DOWN);
use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Dropdown;

my @COLORS = qw(Red Green Blue Cyan Magenta Yellow);

sub dropdown {
	my $dropdown = Term::Fabulous::Widget::Dropdown->new( options => [@COLORS], @_ );
	my $ui       = layout_ui($dropdown);
	my @changes;
	$dropdown->on( Change => sub { push @changes, $_[0]->value; return } );
	return ( $dropdown, $ui, \@changes );
}

sub list_rows {
	my ($dropdown) = @_;
	my ($list) = @{ $dropdown->children };
	return [ map { row_text( $list, $_ ) } 0 .. $list->rows - 1 ];
}

subtest 'options and value' => sub {
	my $dropdown = Term::Fabulous::Widget::Dropdown->new( options => [ 'Red', [ 'Dark green' => 'green' ], { label => 'Blue', value => 'b' } ], value => 'green' );
	is [ $dropdown->options ], [ { label => 'Red', value => 'Red' }, { label => 'Dark green', value => 'green' }, { label => 'Blue', value => 'b' } ], 'three ways to give options';
	is [ $dropdown->selected_index, $dropdown->selected_label ], [ 1, 'Dark green' ], 'selected by value';

	$dropdown->options( [ 'Red', [ Green => 'green' ] ] );
	is $dropdown->selected_label, 'Green', 'new options keep the selected value';
	$dropdown->options( ['Red'] );
	is $dropdown->value, undef, 'and drop it when it is gone';

	like dies { $dropdown->value('nope') },                                                            qr/no option has the value 'nope'/, 'an unknown value dies';
	like dies { $dropdown->choose(1) },                                                                qr/choose needs an option index in 0\.\.0/, 'choosing an index out of range dies';
	like dies { $dropdown->selected_index(5) },                                                        qr/selected_index must be/,         'an index out of range dies';
	like dies { Term::Fabulous::Widget::Dropdown->new( options => [ [ 1, 2, 3 ] ] ) },                 qr/an option must be/,              'an invalid option dies';
	like dies { Term::Fabulous::Widget::Dropdown->new( options => ['a'], value => 'a', selected_index => 0 ) }, qr/not both/,                 'value and selected_index together die';
};

subtest 'painting' => sub {
	my ( $dropdown, $ui ) = dropdown( placeholder => 'Color' );
	is [ $dropdown->columns, row_text( $dropdown, 0 ) ], [ 9, "Color   \x{25BE}" ], 'sized for the widest label; the placeholder shows';
	$dropdown->value('Blue');
	is row_text( $dropdown, 0 ), "Blue    \x{25BE}", 'the selected label';
};

subtest 'keys while closed' => sub {
	my ( $dropdown, $ui, $changes ) = dropdown();
	press( $dropdown, $_ ) foreach qw(Down Down Up End Home Up);
	is $changes, [qw(Red Green Red Yellow Red)], 'Up, Down, Home and End select directly; moving past the ends changes nothing';
	press( $dropdown, 'c' );
	is $dropdown->value, 'Cyan', 'typing selects by the start of the label';
	press( $dropdown, 'Escape' );
	ok !$dropdown->is_open, 'Escape does not open';
};

subtest 'the open list' => sub {
	my ( $dropdown, $ui, $changes ) = dropdown( max_visible_options => 4, value => 'Green' );
	press( $dropdown, 'Enter' );
	$ui->draw;
	ok $dropdown->is_open, 'Enter opens the list';
	is $dropdown->highlighted_index, 1, 'the selected option is highlighted';
	is list_rows($dropdown), [ " Red     \x{2503}", " Green   \x{2503}", " Blue    \x{2503}", " Cyan    \x{2502}" ], 'four options and a scrollbar';

	press( $dropdown, $_ ) foreach qw(Down Down Down);
	is list_rows($dropdown)->[3], " Magenta \x{2503}", 'moving the highlight scrolls the list';
	press( $dropdown, 'Escape' );
	is [ $dropdown->is_open, $dropdown->value, scalar @$changes ], [ 0, 'Green', 0 ], 'Escape closes without a change';

	press( $dropdown, 'Space' );
	press( $dropdown, 'End' );
	press( $dropdown, 'Enter' );
	is [ $dropdown->is_open, $changes ], [ 0, ['Yellow'] ], 'Enter chooses the highlighted option';
};

subtest 'mouse' => sub {
	my ( $dropdown, $ui, $changes ) = dropdown();
	click( $dropdown, 0, 0 );
	$ui->draw;
	ok $dropdown->is_open, 'a click opens the list';
	my ($list) = @{ $dropdown->children };

	click( $list, 2, 2 );
	is $dropdown->highlighted_index, 2, 'pressing highlights';
	click( $list, 0, 0, key => TB_KEY_MOUSE_WHEEL_DOWN );
	is $list->top_option, 0, 'the wheel scrolls only a list that does not show everything';
	click( $list, 2, 3, key => TB_KEY_MOUSE_RELEASE );
	is [ $dropdown->is_open, $changes ], [ 0, ['Cyan'] ], 'releasing over an option chooses it';
};

subtest 'losing the focus closes the list' => sub {
	my ( $dropdown, $ui ) = dropdown();
	$ui->interaction->set_focused_widget($dropdown);
	$dropdown->open;
	$ui->interaction->set_focused_widget(undef);
	ok !$dropdown->is_open, 'closed';
};

subtest 'the list opens upwards without room below' => sub {
	my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, padding => { top => 8 } } );
	my $dropdown = Term::Fabulous::Widget::Dropdown->new( options => [@COLORS] );
	$root->add_child($dropdown);
	my $ui = Term::Fabulous::Static->new( root => $root, width => 20, height => 10, trim_trailing_whitespace => 1 );
	$ui->draw;
	$dropdown->open;
	my @lines = $ui->render_lines( colors => 0 );
	is $lines[0], "\x{256D}" . ( "\x{2500}" x 9 ) . "\x{256E}", 'the list ends above the dropdown';
	is $lines[8], ( ' ' x 8 ) . "\x{25B4}", 'the arrow points up';
};

done_testing;
