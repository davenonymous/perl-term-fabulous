use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use InputTest;
use Termbox 2 qw(TB_KEY_MOUSE_WHEEL_DOWN);
use Term::Fabulous::Widget::TextArea;

sub text_area {
	my $area = Term::Fabulous::Widget::TextArea->new( preferred_columns => 12, preferred_rows => 3, @_ );
	my $ui   = layout_ui($area);
	return ( $area, $ui );
}

sub rows {
	my ($area) = @_;
	return [ map { row_text( $area, $_ ) } 0 .. $area->rows - 1 ];
}

subtest 'size, wrapping and the scrollbar' => sub {
	my ( $area, $ui ) = text_area( value => "The quick brown fox jumps\nend" );
	is [ $area->columns, $area->rows ], [ 12, 3 ], 'preferred size without a layout size';
	is rows($area), [ "brown fox  \x{2502}", "jumps      \x{2503}", "end        \x{2503}" ],
		'lines wrap at spaces; the scrollbar shows when the text is taller';

	$area->wrap(0);
	is rows($area), [ 'The quick br', 'end         ', '            ' ], 'without wrapping every line takes one row';

	$area->wrap(1);
	$area->value('abcdefghijklmnopqrstuvwxyz');
	is rows($area), [ 'abcdefghijkl', 'mnopqrstuvwx', 'yz          ' ], 'a word wider than the area breaks anywhere';
};

subtest 'Enter, vertical movement and the goal column' => sub {
	my ( $area, $ui ) = text_area();
	my @changes;
	$area->on( Change => sub { push @changes, $_[0]->value; return } );
	type_text( $area, 'abcdef' );
	press( $area, 'Enter' );
	type_text( $area, 'ab' );
	is $area->value, "abcdef\nab", 'Enter starts a new line';
	is scalar @changes, 9, 'every edit fires Change';

	press( $area, 'Up' );
	is [ $area->editor->cursor ], [ 0, 2 ], 'Up keeps the column';
	press( $area, 'End' );
	press( $area, 'Down' );
	is [ $area->editor->cursor ], [ 1, 2 ], 'Down stops at the end of a shorter line';
	press( $area, 'Up' );
	is [ $area->editor->cursor ], [ 0, 6 ], 'and returns to the column it aimed for';
	press( $area, 'Up' );
	is [ $area->editor->cursor ], [ 0, 0 ], 'Up on the first row goes to the start';
	press( $area, 'Shift+Down' );
	is $area->editor->selected_text, "abcdef\n", 'Shift+Down selects';
};

subtest 'scrolling follows the cursor' => sub {
	my ( $area, $ui ) = text_area( value => join "\n", 1 .. 10 );
	is $area->top_row, 7, 'the end of a long text is in view';
	press( $area, 'Ctrl+Home' );
	is $area->top_row, 0, 'moving to the start scrolls up';
	press( $area, 'PageDown' );
	is [ $area->editor->cursor ], [ 2, 0 ], 'Page Down moves by the height less one row';

	click( $area, 0, 0, key => TB_KEY_MOUSE_WHEEL_DOWN );
	is [ $area->top_row, $area->editor->cursor ], [ 3, 2, 0 ], 'the wheel scrolls without moving the cursor';
	click( $area, 0, 1 );
	is [ $area->editor->cursor ], [ 4, 0 ], 'a click maps through the scrolled view';
};

subtest 'selection across lines' => sub {
	my ( $area, $ui ) = text_area( value => "ab\ncd" );
	$ui->interaction->set_focused_widget($area);
	press( $area, 'Ctrl+A' );
	my $selected = $area->color_attr( $area->selection_color );
	is [ map { $area->cell( $_, 0 )->[2] } 0 .. 2 ], [ ($selected) x 3 ], 'a selected line break shows as a selected cell';
	press( $area, 'Delete' );
	is $area->value, '', 'the selection is deleted';
};

done_testing;
