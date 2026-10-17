#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_NONE);
use List::Util qw(first);
use Text::Tabs qw(expand);
use Term::Fabulous;
use Term::Fabulous::Scrolling qw(inner_rows reveal_rows scroll_by_pages scroll_by_rows scroll_to_end scroll_to_start scrolled_percent);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

use constant {
	PLAIN  => [ 200, 210, 230, 255 ],
	MARKED => [ 229, 192, 123, 255 ],
};

my $file = shift // "$FindBin::Bin/lib/My/MiniMark.pm";
open my $handle, '<:encoding(UTF-8)', $file or die "Cannot read $file: $!\n";
chomp( my @lines = <$handle> );
close $handle;
$Text::Tabs::tabstop = 4;
@lines               = expand(@lines);

my $text = Term::Fabulous::Widget::ScrollBox->new(
	id     => 'text',
	layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);
my @rows = map { Term::Fabulous::Widget::Text->new( text => length $_ ? $_ : "\x{A0}", wrap_mode => CLAY_TEXT_WRAP_NONE, text_color => PLAIN ) } @lines;
$text->add_child(@rows);

my $status = Term::Fabulous::Widget::Text->new( text => '', wrap_mode => CLAY_TEXT_WRAP_NONE, text_color => [ 150, 160, 180, 255 ] );
my $root   = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $text, $status );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

# n marks the next line that starts a sub or a method and scrolls it
# into view. reveal_rows takes screen rows: line $index of the text is
# on the row where the content starts, plus $index, less how far the
# text is scrolled.
my $marked = -1;

sub mark_next_definition () {
	my $next = first { $lines[$_] =~ /\A\s*(?:sub|method)\b/ } $marked + 1 .. $#lines;
	return 0 unless defined $next;
	$rows[$marked]->text_color(PLAIN) if $marked >= 0;
	$rows[$next]->text_color(MARKED);
	$marked = $next;
	my ($top) = inner_rows( $ui, $text ) or return 1;    # nothing is laid out before the first frame
	my $row = $top + $next + sprintf( '%.0f', $ui->scroll_state($text)->{position}{y} );
	reveal_rows( $ui, $text, $row, $row + 1 );
	return 1;
}

# Each function returns 1 when it moved the text and 0 when it could
# not, at the start or the end.
my %action_of_key = (
	j        => sub { scroll_by_rows( $ui, $text,  1 ) },
	Down     => sub { scroll_by_rows( $ui, $text,  1 ) },
	k        => sub { scroll_by_rows( $ui, $text, -1 ) },
	Up       => sub { scroll_by_rows( $ui, $text, -1 ) },
	Space    => sub { scroll_by_pages( $ui, $text,  1 ) },
	PageDown => sub { scroll_by_pages( $ui, $text,  1 ) },
	b        => sub { scroll_by_pages( $ui, $text, -1 ) },
	PageUp   => sub { scroll_by_pages( $ui, $text, -1 ) },
	g        => sub { scroll_to_start( $ui, $text ) },
	G        => sub { scroll_to_end( $ui, $text ) },
	n        => \&mark_next_definition,
);

my $note = 'j k Space b g G scroll, n marks the next definition';

sub show_status () {
	my $percent = scrolled_percent( $ui, $text ) // 0;
	$status->text( sprintf ' %s  %d%%  %s', $file =~ s{.*/}{}r, $percent, $note );
	return;
}
show_status();

$root->on(
	KeyPress => sub ($event) {
		my $action = $action_of_key{ $event->key_name // '' } or return Clay::UI::Enum::Result->CONTINUE;
		$note = $action->() ? '' : 'Nothing more in that direction.';
		show_status();
		return;
	}
);

# A frame that moved the text reports it; the percentage is that of
# the frame just laid out.
$text->on(
	OnScroll => sub ($event) {
		show_status();
		return;
	}
);

$ui->run;
