#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Lite;    # exports TF

# Each question takes a few rows below the shell's output, waits for
# the answer and returns it; Escape returns undef.
sub cancelled () {
	say 'Cancelled.';
	exit;
}

my $name = TF->inline->prompt( 'What is your name?', placeholder => 'Your name' );
cancelled() unless defined $name;

my $size = TF->inline->choose( 'Which size?', options => [qw(Small Medium Large)], value => 'Medium' );
cancelled() unless defined $size;

my $sure = TF->inline->confirm( "Order a $size one for $name?", ok => 'Order', default => 'cancel' );
say $sure ? "Ordered a $size one for $name." : 'Nothing ordered.';
