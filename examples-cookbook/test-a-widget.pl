#!/usr/bin/env perl

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;
use Term::Fabulous::Termbox qw(TB_KEY_ARROW_LEFT);
use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::TextField;

# A key press as termbox2 would report it: a typed character, or a
# special key code.
sub type_text ( $widget, $text ) {
	$widget->fire_event( Term::Fabulous::Event::KeyPress->new( key => 0, char => ord $_, modifiers => 0 ) ) foreach split //, $text;
	return;
}

sub press_key ( $widget, $key ) {
	$widget->fire_event( Term::Fabulous::Event::KeyPress->new( key => $key, char => 0, modifiers => 0 ) );
	return;
}

my $field = Term::Fabulous::Widget::TextField->new( preferred_columns => 10, max_length => 8 );
my @changes;
$field->on( Change => sub ($event) { push @changes, $event->value; return } );

my $root = Term::Fabulous::Widget::Box->new;
$root->add_child($field);
my $page = Term::Fabulous::Static->new( root => $root, width => 20 );
$page->render_lines;    # lays the widgets out once, so the field has a size

type_text( $field, 'hello' );
press_key( $field, TB_KEY_ARROW_LEFT );
type_text( $field, 'X' );

is $field->value, 'hellXo', 'typing and cursor movement';
is $changes[-1], 'hellXo', 'Change carries the new text';

type_text( $field, 'abcdef' );
is $field->value, 'hellXabo', 'max_length stops the input at 8 characters';

# The field is 10 columns wide and has a background color, so its
# empty cells are kept as spaces.
is [ $page->render_lines( colors => 0 ) ], ['hellXabo  '], 'what the screen shows';

done_testing;
