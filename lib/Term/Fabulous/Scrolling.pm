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

Term::Fabulous::Scrolling - Scroll a container by rows, by pages and to its ends

=head1 SYNOPSIS

	use Term::Fabulous::Scrolling qw(scroll_by_rows scroll_by_pages scroll_to_start scroll_to_end scrolled_percent);

	my $box = $ui->find_by_id('log');    # a ScrollBox, a VirtualList, a document view
	scroll_by_rows( $ui, $box, 1 );          # a row down
	scroll_by_pages( $ui, $box, -1 );        # a page up
	scroll_to_end( $ui, $box );
	say scrolled_percent( $ui, $box ), '%';

	scroll_by_rows( $ui, $box, 1 ) or say 'already at the end';

=head1 DESCRIPTION

A program that scrolls a container with its keys, as a pager does, needs
the same few moves for every container: a row, a page, the ends, and a
range of rows into view. Every scroll container of Clay is scrolled the
same way, with the
L<scroll_to and scroll_state|Term::Fabulous/"bounding_box, scroll_state, scroll_to">
of the UI, and by the same rules, which this module holds:

=over

=item *

A I<page> is the rows the container shows inside its border, padding
and scrollbars, less one, which stays in view as a landmark; at least
one row. Clay's viewport is the whole box of the container, border
included, so the module measures the box with C<bounding_box> and takes
off the padding of the container's declaration (C<to_config>), where
Term::Fabulous puts the border and the scrollbars too.

=item *

Scrolling stops at the ends, and a function that scrolls returns 1 when
it moved the content and 0 when it could not, so a key binding can
tell. Clay keeps the position in fractions of a row; a move of less
than half a row is none.

=back

The arithmetic is L<Term::Fabulous::Viewport>'s. The functions take
the UI and the container, so that a test gives them a small
L<Term::Fabulous::Widget::ScrollBox> on a memory terminal. Before the
first frame laid the container out, there is nothing to scroll: the
functions that scroll return 0, and the others C<undef> or an empty
list. L<Term::Fabulous::Widget::DocumentView> scrolls with these
functions.

=head1 FUNCTIONS

Nothing is exported by default. Every function dies when the UI is
not a UI or the widget not a widget; the number of rows or pages must
be an integer, negative to scroll up.

=head2 scroll_by_rows

	scroll_by_rows( $ui, $widget, $rows );

Scrolls by rows: down for a positive number, up for a negative one.

=head2 scroll_by_pages

	scroll_by_pages( $ui, $widget, $pages );

Scrolls by pages of L</page_rows>.

=head2 scroll_to_start, scroll_to_end

	scroll_to_end( $ui, $widget );

Scrolls to the top or to the end of the content.

=head2 reveal_rows

	reveal_rows( $ui, $widget, $from, $to );

Scrolls the screen rows from C<$from> to before C<$to> into the inner
rows, with the smallest move: not at all when they are in view, and so
that the first of them is at the top or the last at the bottom
otherwise; rows taller than the view show their start (see
L<Term::Fabulous::Viewport/reveal_range>).

=head2 inner_rows

	my ( $top, $bottom ) = inner_rows( $ui, $widget );

The first screen row of the container's content and the row after its
last, inside the border, padding and scrollbars; an empty list before
the first frame.

=head2 page_rows

	my $rows = page_rows( $ui, $widget );

The rows of a page: the inner rows less one, at least one.

=head2 scrolled_percent

	my $percent = scrolled_percent( $ui, $widget );

How far the content is scrolled, from 0 at the top to 100 at the end,
rounded; 100 when the content fits, so that it is seen whole.

=head1 SEE ALSO

L<Term::Fabulous::Viewport>, L<Term::Fabulous::Widget::ScrollBox>,
L<Term::Fabulous::Widget::DocumentView>, L<Term::Fabulous::Manual::Events/SCROLLING>.

=cut
