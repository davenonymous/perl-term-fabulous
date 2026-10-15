#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Lite;    # exports TF

# A small form: the options of a widget come first, its children after
# them. Escape or Ctrl+C quits.
my $status = TF->text('Change something.');
my $name;
my $root = TF->screen(
	gap     => 1,
	padding => [ 1, 2 ],
	TF->text('Hello from Term::Fabulous::Lite! Tab moves between inputs; Escape quits.'),
	TF->column(
		border       => 'Round',
		border_color => '#61afef',
		width        => 'grow',
		padding      => [ 0, 1 ],
		TF->row( gap => 1, TF->box( width => 'fixed(6)', TF->text('Name') ), $name = TF->text_field( id => 'name', placeholder => 'Your name', columns => 30 ) ),
		TF->row(
			gap => 1,
			TF->box( width => 'fixed(6)', TF->text('Size') ),
			TF->radio_group( id => 'size', value => 'm', direction => 'ltr', gap => 2, map { TF->radio_button( $_->[0], value => $_->[1] ) } [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ] ),
		),
		TF->row( gap => 1, TF->box( width => 'fixed(6)', TF->text('News') ), TF->checkbox( 'Send me the newsletter', id => 'newsletter' ) ),
	),
	$status,
);

# Every Change bubbles up to the root; show the latest one.
$root->on( Change => sub ($event) { $status->text( sprintf '%s changed to: %s', $event->target->id, $event->value // 'nothing' ); return } );

TF->run( $root, focus => $name, quit_keys => ['Escape'] );
