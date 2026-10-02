use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use InputTest;
use Term::Fabulous::Termbox qw(TB_MOD_MOTION TB_MOD_SHIFT TB_REVERSE);
use Term::Fabulous::Widget::TextField;

sub text_field {
	my $field = Term::Fabulous::Widget::TextField->new( preferred_columns => 8, @_ );
	my $ui    = layout_ui($field);
	return ( $field, $ui );
}

sub events {
	my ( $field, $name ) = @_;
	my @values;
	$field->on( $name => sub { push @values, $_[0]->value; return } );
	return \@values;
}

subtest 'size and value' => sub {
	my ( $field, $ui ) = text_field( value => 'hi' );
	is [ $field->columns, $field->rows ], [ 8, 1 ], 'preferred_columns and one row without a layout size';
	is row_text( $field, 0 ), 'hi      ', 'the value is painted';
	$field->value("a\nb");
	is $field->value, 'a b', 'line breaks become spaces';
	like dies { Term::Fabulous::Widget::TextField->new( mask => '**' ) },             qr/mask must be a single character/, 'an invalid mask dies';
	like dies { $field->max_length(1) }, qr/^Term::Fabulous::Widget::TextField: the text has 3 characters, more than max_length 1/, 'editor errors name the widget';
	is( Term::Fabulous::Widget::TextField->new( read_only => 'yes', disabled => 'no' )->read_only, 1, 'read_only is stored as 1 or 0' );
	like dies { Term::Fabulous::Widget::TextField->new( preferred_columns => 0 ) }, qr/positive integer/,                'an invalid width dies';
};

subtest 'typing fires Change, Enter fires Submit' => sub {
	my ( $field, $ui ) = text_field();
	my $changes = events( $field, 'Change' );
	my $submits = events( $field, 'Submit' );
	type_text( $field, 'abc' );
	press( $field, 'Backspace' );
	press( $field, 'Enter' );
	is $changes, [ 'a', 'ab', 'abc', 'ab' ], 'one Change per edit';
	is $submits, ['ab'], 'Submit with the text';

	$field->value('quiet');
	is scalar @$changes, 4, 'setting the value fires nothing';
};

subtest 'cursor, selection and focus painting' => sub {
	my ( $field, $ui ) = text_field( value => 'abc' );
	is $field->cell( 3, 0 ), undef, 'no cursor without focus';

	$ui->interaction->set_focused_widget($field);
	ok $field->cell( 3, 0 )->[1] & TB_REVERSE, 'the focused field shows the cursor after the text';
	press( $field, 'Shift+Left' );
	is $field->editor->selected_text, 'c', 'Shift extends the selection';
	is $field->cell( 2, 0 )->[2], $field->color_attr( $field->selection_color ), 'the selection is painted';
	is $field->cell( 0, 0 )->[2], $field->color_attr( $field->focus_background_color ), 'the rest has the focus background';
};

subtest 'horizontal scrolling' => sub {
	my ( $field, $ui ) = text_field();
	type_text( $field, 'abcdefghij' );
	is row_text( $field, 0 ), 'defghij ', 'the end of the text and the cursor cell are visible';
	press( $field, 'Home' );
	is row_text( $field, 0 ), 'abcdefgh', 'Home scrolls back';
	press( $field, 'End' );
	press( $field, 'Ctrl+W' );
	is row_text( $field, 0 ), '        ', 'deleting scrolls back so text fills the field';

	$field->value('日本語のテキスト');
	is row_text( $field, 0 ), 'キスト  ', 'the view starts at a whole wide character';
};

subtest 'keys that are not used bubble' => sub {
	my ( $field, $ui ) = text_field();
	my @bubbled;
	my $parent = $field->parent;
	$parent->on( KeyPress => sub { push @bubbled, $_[0]->key_name; return } );
	press( $field, $_ ) foreach qw(a Tab Up Escape Left);
	is \@bubbled, [qw(Tab Up Escape)], 'typing and editing keys stop, others bubble';

	$field->read_only(1);
	press( $field, $_ ) foreach qw(b Backspace Left);
	is [ $field->value, \@bubbled ], [ 'a', [qw(Tab Up Escape b Backspace)] ], 'a read-only field ignores edits and lets them bubble';
};

subtest 'placeholder and mask' => sub {
	my ( $field, $ui ) = text_field( placeholder => 'Name' );
	is row_text( $field, 0 ), 'Name    ', 'the placeholder shows while empty';
	is $field->cell( 0, 0 )->[1], $field->color_attr( $field->placeholder_color ), 'in its color';

	$field->mask('*');
	$field->value('secret');
	is row_text( $field, 0 ), '******  ', 'masked';
	is $field->value, 'secret', 'the value is not';
};

subtest 'mouse' => sub {
	my ( $field, $ui ) = text_field( value => 'one two' );
	click( $field, 1, 0 );
	is [ $field->editor->cursor ], [ 0, 1 ], 'a click places the cursor';
	click( $field, 3, 0, modifiers => TB_MOD_MOTION );
	is $field->editor->selected_text, 'ne', 'dragging selects';
	click( $field, 6, 0, modifiers => TB_MOD_SHIFT );
	is $field->editor->selected_text, 'ne tw', 'Shift-click extends the selection';
	click( $field, 5, 0 );
	click( $field, 5, 0 );
	is $field->editor->selected_text, 'two', 'a double click selects a word';
};

subtest 'disabled' => sub {
	my ( $field, $ui ) = text_field( value => 'x' );
	$ui->interaction->set_focused_widget($field);
	$field->disabled(1);
	ok !$field->is_focused, 'disabling removes the focus';
	ok !$field->can_focus, 'and keeps it away';
	press( $field, 'y' );
	is $field->value, 'x', 'keys are ignored';
	is $field->cell( 0, 0 )->[1], $field->color_attr( $field->disabled_color ), 'painted in the disabled color';
};

done_testing;
