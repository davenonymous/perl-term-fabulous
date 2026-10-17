package Term::Fabulous::Scrolling;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT_OK = qw(inner_rows page_rows reveal_rows scroll_by_rows scroll_by_pages scroll_to_end scroll_to_start scrolled_percent);

use List::Util qw(max min);
use Scalar::Util qw(blessed);
use Term::Fabulous::Check qw(describe);
use Term::Fabulous::Viewport qw(clamp_offset max_offset reveal_range);

sub _checked ( $function, $ui, $widget ) {
	die "Term::Fabulous::Scrolling: $function needs a UI, got " . describe($ui) unless blessed $ui && $ui->can('scroll_state');
	die "Term::Fabulous::Scrolling: $function needs a widget, got " . describe($widget) unless blessed $widget;
	return;
}

sub _checked_count ( $function, $name, $value ) {
	die "Term::Fabulous::Scrolling: $function needs a number of $name, got " . describe($value) unless defined $value && !ref $value && $value =~ /\A-?[0-9]+\z/;
	return $value;
}

# Clay reports the viewport as the whole box of the container; the
# content shows inside the padding of its declaration, which holds the
# border and the scrollbars too (see Term::Fabulous::Role::HasBorderStyle).
sub inner_rows ( $ui, $widget ) {
	_checked( inner_rows => $ui, $widget );
	my $frame   = $ui->bounding_box($widget)            // return ();
	my $padding = $widget->to_config->{layout}{padding} // {};
	return ( $frame->{y} + ( $padding->{top} // 0 ), $frame->{y} + $frame->{height} - ( $padding->{bottom} // 0 ) );
}

# A page is the rows the content shows less one, so that the last row
# stays in view as a landmark; at least one row.
sub page_rows ( $ui, $widget ) {
	my ( $top, $bottom ) = inner_rows( $ui, $widget ) or return undef;
	return max( 1, int( $bottom - $top + 0.5 ) - 1 );
}

# Scrolls to an offset, within the ends. Clay keeps the position in
# fractions of a row; a move of less than half a row is none.
sub _scroll_to ( $ui, $widget, $state, $offset ) {
	my $from = -$state->{position}{y};
	my $to   = clamp_offset( $state->{content}{height}, $state->{viewport}{height}, $offset );
	return 0 if int( $to + 0.5 ) == int( $from + 0.5 );
	$ui->scroll_to( $widget, { y => -$to } );
	return 1;
}

sub scroll_by_rows ( $ui, $widget, $rows ) {
	_checked( scroll_by_rows => $ui, $widget );
	_checked_count( scroll_by_rows => rows => $rows );
	my $state = $ui->scroll_state($widget) // return 0;
	return _scroll_to( $ui, $widget, $state, -$state->{position}{y} + $rows );
}

sub scroll_by_pages ( $ui, $widget, $pages ) {
	_checked( scroll_by_pages => $ui, $widget );
	_checked_count( scroll_by_pages => pages => $pages );
	my $page = page_rows( $ui, $widget ) // return 0;
	return scroll_by_rows( $ui, $widget, $pages * $page );
}

sub scroll_to_start ( $ui, $widget ) {
	_checked( scroll_to_start => $ui, $widget );
	my $state = $ui->scroll_state($widget) // return 0;
	return _scroll_to( $ui, $widget, $state, 0 );
}

sub scroll_to_end ( $ui, $widget ) {
	_checked( scroll_to_end => $ui, $widget );
	my $state = $ui->scroll_state($widget) // return 0;
	return _scroll_to( $ui, $widget, $state, max_offset( $state->{content}{height}, $state->{viewport}{height} ) );
}

# Screen rows from $from to before $to into view, with the smallest move.
# Viewport's reveal_range wants one coordinate system: the content's
# rows, counted from the first row inside the padding, which shows the
# inner rows from the offset on.
sub reveal_rows ( $ui, $widget, $from, $to ) {
	_checked( reveal_rows => $ui, $widget );
	my $state = $ui->scroll_state($widget) // return 0;
	my ( $top, $bottom ) = inner_rows( $ui, $widget ) or return 0;
	my $offset  = -$state->{position}{y};
	my $inner   = $bottom - $top;
	my $content = $state->{content}{height} - ( $state->{viewport}{height} - $inner );
	return _scroll_to( $ui, $widget, $state, reveal_range( $content, $inner, $offset, $from - $top + $offset, $to - $top + $offset ) );
}

# How far down the content is scrolled, from 0 to 100; content that fits
# is seen whole, 100. undef before the container was laid out.
sub scrolled_percent ( $ui, $widget ) {
	_checked( scrolled_percent => $ui, $widget );
	my $state = $ui->scroll_state($widget) // return undef;
	my $last  = max_offset( $state->{content}{height}, $state->{viewport}{height} );
	return 100 unless $last > 0;
	return min( 100, max( 0, int( 100 * -$state->{position}{y} / $last + 0.5 ) ) );
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Scrolling - Scroll a container by rows, by pages and to its ends, as a pager does

=head1 SYNOPSIS

	use Term::Fabulous::Scrolling qw(scroll_by_rows scroll_by_pages scroll_to_start scroll_to_end scrolled_percent);

	my $box = $ui->find_by_id('log');    # a ScrollBox, a VirtualList, a document view
	scroll_by_rows( $ui, $box, 1 );      # one row down
	scroll_by_pages( $ui, $box, -1 );    # one page up
	scroll_to_end( $ui, $box );
	say scrolled_percent( $ui, $box ), '%';

	scroll_by_rows( $ui, $box, 1 ) or say 'already at the end';

=head1 DESCRIPTION

A program that lets the user scroll a container with keys, as a pager
does, needs the same few moves for every container: by a row, by a
page, to either end, and far enough to bring a range of rows into view.
This module provides these moves for any scroll container, such as a
L<Term::Fabulous::Widget::ScrollBox>, a
L<Term::Fabulous::Widget::VirtualList> or a
L<Term::Fabulous::Widget::DocumentView>.
L<Term::Fabulous::Cookbook::Documents> has a recipe that scrolls a
ScrollBox with pager keys using these functions.

All scroll containers are scrolled the same way, with the UI's
L<scroll_state and scroll_to|Term::Fabulous/"bounding_box, scroll_state, scroll_to">
methods, and this module applies the same rules to all of them:

=over

=item *

A I<page> is the number of rows the container shows inside its border,
padding and scrollbars, less one. The row that is kept stays in view
after the move and helps the reader find their place. A page is at
least one row.

Clay reports the whole box of the container as its viewport, border
included. To find the rows that show content, the module therefore
takes the box from C<bounding_box> and subtracts the padding of the
container's layout (from its C<to_config>), which is where
Term::Fabulous reserves the room for the border and the scrollbars.

=item *

Scrolling stops at the ends of the content. Every function that
scrolls returns 1 when it moved the content and 0 when it did not, for
example because the content is already at that end. A key handler can
use the return value to tell whether the key had an effect.

=item *

Clay keeps the scroll position in fractions of a row. A function
compares the target position with the current one, both rounded to the
nearest whole row; when they round to the same row, it does not scroll
and returns 0.

=back

Before the first frame has laid the container out, Clay knows neither
its size nor its scroll position, so there is nothing to scroll. Until
then the functions that scroll return 0 without doing anything,
L</page_rows> and L</scrolled_percent> return C<undef>, and
L</inner_rows> returns an empty list.

The calculations come from L<Term::Fabulous::Viewport>. The functions
take the UI and the container as arguments rather than being methods of
a widget, so any container can use them and a test can exercise them
with a small ScrollBox on a memory terminal. The document view uses
them for its line and page keys, to scroll search matches and links
into view, and for the percentage it reports.

=head1 FUNCTIONS

Nothing is exported by default. Every function takes the UI (a
L<Term::Fabulous> object) and the scroll container as its first two
arguments and dies when the UI cannot report scroll states or the
container is not an object. Counts of rows and pages must be integers;
a negative count scrolls up. Anything else dies.

=head2 scroll_by_rows

	my $moved = scroll_by_rows( $ui, $widget, $rows );

Scrolls the content by C<$rows> rows: down for a positive number, up
for a negative one, and no further than either end. Returns 1 when the
content moved and 0 otherwise.

=head2 scroll_by_pages

	my $moved = scroll_by_pages( $ui, $widget, $pages );

Scrolls the content by C<$pages> pages of L</page_rows> rows each: down
for a positive number, up for a negative one. Returns 1 when the
content moved and 0 otherwise.

=head2 scroll_to_start, scroll_to_end

	my $moved = scroll_to_start( $ui, $widget );
	my $moved = scroll_to_end( $ui, $widget );

Scroll to the top of the content, or so far down that its last row is
at the bottom of the view. Return 1 when the content moved and 0
otherwise.

=head2 reveal_rows

	my $moved = reveal_rows( $ui, $widget, $from, $to );

Scrolls the rows from screen row C<$from> up to, but not including,
screen row C<$to> into the container's inner rows (see L</inner_rows>),
with the smallest possible move. The content does not move when the
rows are already in view. Rows above the view end up at its top, and
rows below it end up at its bottom. When the rows are more than the
view can show, their first row goes to the top (see
L<Term::Fabulous::Viewport/reveal_range>). Both rows are screen
coordinates, as L<Term::Fabulous/"bounding_box, scroll_state, scroll_to">
reports them. Returns 1 when the content moved and 0 otherwise.

=head2 inner_rows

	my ( $top, $bottom ) = inner_rows( $ui, $widget );

Returns the screen row of the first row of the container's content and
the screen row just below its last one, both inside the border, padding
and scrollbars. C<$bottom - $top> is the number of rows that show
content. Returns an empty list before the first frame has laid the
container out.

=head2 page_rows

	my $rows = page_rows( $ui, $widget );

Returns the number of rows in a page: the inner rows less one, at least
1. Returns C<undef> before the first frame has laid the container out.

=head2 scrolled_percent

	my $percent = scrolled_percent( $ui, $widget );

Returns how far the content is scrolled down, as an integer from 0 at
the top to 100 at the end, rounded to the nearest percent. When all of
the content fits into the view, it returns 100, because the reader
sees all of it. Returns C<undef> before the first frame has laid the
container out.

=head1 SEE ALSO

L<Term::Fabulous::Cookbook::Documents>, L<Term::Fabulous::Viewport>,
L<Term::Fabulous::Widget::ScrollBox>, L<Term::Fabulous::Widget::VirtualList>,
L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Manual::Events/SCROLLING>.

=cut
