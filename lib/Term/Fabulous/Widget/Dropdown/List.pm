package Term::Fabulous::Widget::Dropdown::List;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Canvas;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Dropdown::List
	:isa(Term::Fabulous::Widget::Canvas)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use List::Util qw(max min);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	use constant SCROLLBAR_TRACK => "\x{2502}";
	use constant SCROLLBAR_THUMB => "\x{2503}";

	field $dropdown     :param :weak;
	field $visible_rows :param :reader;

	# The first option shown.
	field $top = 0;

	ADJUST {
		weaken( my $weak_self = $self );
		$self->on( CanvasResize => sub ($event) { $weak_self->repaint; return Clay::UI::Enum::Result->CONTINUE } );
		$self->on(
			Mouse => sub ($event) {
				return $weak_self->_handle_mouse($event) ? Clay::UI::Enum::Result->HANDLED : Clay::UI::Enum::Result->CONTINUE;
			}
		);
	}

	method top_option () {
		return $top;
	}

	method _scrolls () {
		return $dropdown->option_count > $visible_rows;
	}

	method _max_top () {
		return max( 0, $dropdown->option_count - $visible_rows );
	}

	# Scrolls the highlighted option into view and repaints.
	method show_highlight () {
		my $highlighted = $dropdown->highlighted_index // 0;
		$top = $highlighted                     if $highlighted < $top;
		$top = $highlighted - $visible_rows + 1 if $highlighted >= $top + $visible_rows;
		$top = min( max( $top, 0 ), $self->_max_top );
		return $self->repaint;
	}

	method scroll ($rows) {
		$top = min( max( $top + $rows, 0 ), $self->_max_top );
		return $self->repaint;
	}

	# The option shown at a buffer row, or undef.
	method option_at_row ($row) {
		my $index = $top + $row;
		return $row >= 0 && $index < $dropdown->option_count ? $index : undef;
	}

	method _handle_mouse ($event) {
		my $key = $event->key;
		if ( $key == TB_KEY_MOUSE_WHEEL_UP || $key == TB_KEY_MOUSE_WHEEL_DOWN ) {
			my $before = $top;
			$self->scroll( $key == TB_KEY_MOUSE_WHEEL_UP ? -1 : 1 );
			return 0 if $top == $before;    # every option shown, or at an end
			$event->use_wheel;
			return 1;
		}
		return 0 unless $key == TB_KEY_MOUSE_LEFT || $key == TB_KEY_MOUSE_RELEASE;

		my ( $column, $row ) = $self->cell_at($event);
		my $index = defined $row && $column < $self->_text_columns ? $self->option_at_row($row) : undef;
		return 1 unless defined $index;
		if ( $key == TB_KEY_MOUSE_LEFT ) {
			$dropdown->highlight($index);
			return 1;
		}
		$dropdown->choose($index);
		return 1;
	}

	method _text_columns () {
		return $self->columns - ( $self->_scrolls ? 1 : 0 );
	}

	method repaint () {
		$self->mark_changed;
		return $self unless $self->columns > 0 && $self->rows > 0 && defined $dropdown;
		$self->clear;

		my $width = $self->_text_columns;
		foreach my $row ( 0 .. $self->rows - 1 ) {
			my $index = $self->option_at_row($row) // last;
			my ( $fg, $bg ) = $dropdown->option_attrs($index);
			$self->put_attrs( $_, $row, ' ', undef, $bg ) foreach 0 .. $width - 1;
			$self->_paint_label( $row, $dropdown->option_label($index), $fg, $bg, $width - 1 );
		}
		$self->_paint_scrollbar if $self->_scrolls;
		return $self;
	}

	# One space of margin on either side of the label.
	method _paint_label ( $row, $label, $fg, $bg, $limit ) {
		my $x = 1;
		foreach my $cluster ( grapheme_clusters($label) ) {
			my $columns = cluster_columns($cluster);
			last if $x + $columns > $limit;
			$self->put_attrs( $x, $row, $cluster, $fg, $bg );
			$x += $columns;
		}
		return;
	}

	method _paint_scrollbar () {
		my ( $height, $x ) = ( $self->rows, $self->columns - 1 );
		my $total     = $dropdown->option_count;
		my $thumb     = max( 1, int( $height * $height / $total + 0.5 ) );
		my $max_top   = $self->_max_top;
		my $thumb_top = $max_top ? int( ( $height - $thumb ) * $top / $max_top + 0.5 ) : 0;
		my $track_fg  = $dropdown->color_attr( $dropdown->disabled_color );
		my $thumb_fg  = $dropdown->accent_attr;

		foreach my $y ( 0 .. $height - 1 ) {
			my $is_thumb = $y >= $thumb_top && $y < $thumb_top + $thumb;
			$self->put_attrs( $x, $y, $is_thumb ? SCROLLBAR_THUMB : SCROLLBAR_TRACK, $is_thumb ? $thumb_fg : $track_fg, undef );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Dropdown::List - The option list of an open dropdown

=head1 DESCRIPTION

This class is internal to L<Term::Fabulous::Widget::Dropdown>.
Applications never create a list themselves: the dropdown creates one
each time it opens, adds it as a floating child of itself (so it is
drawn over the other widgets, attached below or above the dropdown), and
removes it when it closes.

The list is a L<Term::Fabulous::Widget::Canvas> that paints the
dropdown's options with a one-column margin on both sides, highlights
one of them, scrolls through them when there are more options than
rows, and then shows a scrollbar in its rightmost column. It turns mouse
presses into highlights and mouse releases into choices, and scrolls on
the mouse wheel. It never takes the keyboard focus; the dropdown keeps
the focus and handles the keys.

The methods below are documented for authors of dropdown subclasses and
for tests.

=head1 CONSTRUCTOR

=head2 new

	my $list = Term::Fabulous::Widget::Dropdown::List->new(
		dropdown     => $dropdown,
		visible_rows => 8,
		...
	);

Called by the dropdown with these parameters, plus C<background_color>,
C<border_color>, C<border_width>, C<border_style>, C<layout> and
C<floating> (see L<Term::Fabulous::Widget/floating>). Unknown
parameters die.

=over

=item C<dropdown>

Required. The L<Term::Fabulous::Widget::Dropdown> the list belongs to.
Held as a weak reference.

=item C<visible_rows>

Required. A positive integer: how many options the list shows at once.

=back

=head1 METHODS

=head2 visible_rows

	my $rows = $list->visible_rows;

How many options the list shows at once.

=head2 top_option

	my $index = $list->top_option;

The index of the first option shown (from 0).

=head2 show_highlight

	$list->show_highlight;

Scrolls the dropdown's highlighted option into view and repaints.
Returns the list.

=head2 scroll

	$list->scroll(-1);

Scrolls by a number of options (negative: towards the first), staying
within the options. Returns the list.

=head2 option_at_row

	my $index = $list->option_at_row($row);

The index of the option shown at a row of the list's content (from 0),
or C<undef> for a row without an option.

=head2 repaint

	$list->repaint;

Paints the visible options and, when the list scrolls, the scrollbar,
and marks the list changed (see
L<Clay::UI::Role::Core::Element/mark_changed>). Returns the list.

=head1 MOUSE

A left press on an option highlights it; releasing the left button over
an option chooses it (see L<Term::Fabulous::Widget::Dropdown/choose>).
Presses on the scrollbar column are ignored. Each notch of the mouse
wheel scrolls by one option.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Dropdown>.

=cut
