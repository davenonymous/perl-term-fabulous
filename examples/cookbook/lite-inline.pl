#!/usr/bin/env perl

use v5.32;
use warnings;

use Term::Fabulous::Lite;    # exports TF

# One form below the shell's output: every field at once, Tab moves
# between them, Enter or the Order button answers, Escape cancels.
my $order = TF->inline->form(
	'Your order',
	fields => [
		{ name => 'name', label => 'Name', input => TF->text_field( placeholder => 'Your name', required => 1, columns => 30 ) },
		{ name => 'size', label => 'Size', input => TF->radio_group( value => 'Medium', direction => 'ltr', gap => 2, map { TF->radio_button($_) } qw(Small Medium Large) ) },
		{ name => 'news', label => '',     input => TF->checkbox('Send me the newsletter') },
	],
	ok => 'Order',
);

say defined $order
	? sprintf( 'Ordered a %s one for %s%s.', $order->{size}, $order->{name}, $order->{news} ? ', with the newsletter' : '' )
	: 'Cancelled.';
