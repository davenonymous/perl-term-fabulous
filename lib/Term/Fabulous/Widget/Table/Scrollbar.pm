package Term::Fabulous::Widget::Table::Scrollbar;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Canvas;

class Term::Fabulous::Widget::Table::Scrollbar :isa(Term::Fabulous::Widget::Canvas) :strict(params) {
	use List::Util qw(max min);
	use POSIX qw(floor);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Check qw(cell_color);
	use Term::Fabulous::Render::Attr qw(cell_color_attr);

	use constant { TRACK => "\x{2502}", THUMB => "\x{2503}" };

	field $follows     :param;
	field $track_color :param = [ 70, 76, 90, 255 ];
	field $thumb_color :param = [ 97, 175, 239, 255 ];
	field $_painted_key;

	ADJUST {
		die "Term::Fabulous::Widget::Table::Scrollbar: follows must be a scroll container"
			unless defined $follows && $follows->DOES('Clay::UI::Role::Layout::HasScroll');
		weaken $follows;
		$track_color = cell_color( $self, track_color => $track_color );
		$thumb_color = cell_color( $self, thumb_color => $thumb_color );
	}

	method _set_color ( $name, $field_ref, @new ) {
		return $$field_ref unless @new;
		$$field_ref = cell_color( $self, $name => $new[0] );
		$self->mark_changed;
		return $$field_ref;
	}

	method track_color (@new) { return $self->_set_color( track_color => \$track_color, @new ) }
	method thumb_color (@new) { return $self->_set_color( thumb_color => \$thumb_color, @new ) }

	# The scroll state of the container in the frame being drawn, or undef
	# when it was not laid out or there is nothing to scroll.
	method _scrolling () {
		my $ui = $self->ui // return undef;
		return undef unless defined $follows;
		my $state = $ui->scroll_state($follows) // return undef;
		return $state->{content}{height} > $state->{viewport}{height} ? $state : undef;
	}

	# [ first row, rows ] of the thumb in a track of $rows rows.
	sub _thumb ( $state, $rows ) {
		my ( $viewport, $content ) = ( $state->{viewport}{height}, $state->{content}{height} );
		my $size   = max( 1, min( $rows, int( $rows * $viewport / $content + 0.5 ) ) );
		my $travel = $content - $viewport;
		my $first  = int( ( $rows - $size ) * -$state->{position}{y} / $travel + 0.5 );
		return [ max( 0, min( $rows - $size, $first ) ), $size ];
	}

	method refresh :override () {
		my $rows  = $self->rows;
		my $state = $self->_scrolling;
		my $thumb = defined $state && $rows > 0 ? _thumb( $state, $rows ) : undef;
		my $key   = join ':', $self->columns, $rows, ( defined $thumb ? @$thumb : 'none' ), @$track_color, @$thumb_color;
		return if defined $_painted_key && $key eq $_painted_key;
		$_painted_key = $key;
		$self->clear;
		return unless defined $thumb;
		my ( $track, $bar ) = ( cell_color_attr( fg => $track_color ), cell_color_attr( fg => $thumb_color ) );
		foreach my $row ( 0 .. $rows - 1 ) {
			my $on_thumb = $row >= $thumb->[0] && $row < $thumb->[0] + $thumb->[1];
			$self->put_attrs( 0, $row, $on_thumb ? THUMB : TRACK, $on_thumb ? $bar : $track, undef );
		}
		return;
	}

	# The scroll position that puts the thumb's middle at a row of the
	# track, for a click or a drag; undef when there is nothing to scroll.
	method position_at_row ($row) {
		my $state = $self->_scrolling // return undef;
		my $rows  = $self->rows;
		return undef unless $rows > 0;
		my $size     = _thumb( $state, $rows )->[1];
		my $free     = max( 1, $rows - $size );
		my $fraction = max( 0, min( 1, ( $row - floor( $size / 2 ) ) / $free ) );
		return -$fraction * ( $state->{content}{height} - $state->{viewport}{height} );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Table::Scrollbar - The vertical scrollbar of a table

=head1 DESCRIPTION

A one column wide L<Term::Fabulous::Widget::Canvas> that
L<Term::Fabulous::Widget::Table> shows right of its body. When the body
has more lines than fit, it draws a track (a thin vertical line,
U+2502) with a thumb (a heavy vertical line, U+2503) whose length and
place show which part of the body is visible; otherwise it is empty. It
paints from the scroll state of the frame being drawn, so it is always
up to date, and it paints again only when the thumb moved. The table
scrolls the body when the scrollbar is clicked or dragged (see
L</position_at_row>).

=begin html

<p><img src="/screenshots/example-table-files-scrolling.svg" alt="A file tree table with all folders open, scrolled down: the column titles and the filter row stay at the top, and the scrollbar right of the frame shows a thumb in its middle"></p>

=end html

The table makes its scrollbar itself, with its C<line_color> as the
track color and its C<text_color> as the thumb color, and shows it
while its C<scrollbar> parameter is true. See
L<Term::Fabulous::Manual::TableStyles/SIZE AND SCROLLING>.

=head1 CONSTRUCTOR

	my $bar = Term::Fabulous::Widget::Table::Scrollbar->new(
		follows     => $scroll_box,
		track_color => [ 70, 76, 90, 255 ],
		thumb_color => [ 97, 175, 239, 255 ],
	);

C<follows> (required) is the scroll container whose vertical position
the scrollbar shows (held weakly); the colors take anything a canvas
cell takes.

=head1 METHODS

=head2 track_color

	$bar->track_color('#464c5a');

Accessor for the C<track_color> parameter. Writing marks the scrollbar
changed and returns the new color as C<[r, g, b, a]>. An invalid color
dies and leaves the old one.

=head2 thumb_color

	$bar->thumb_color('#61afef');

Accessor for the C<thumb_color> parameter, as C<track_color>.

=head2 position_at_row

	my $y = $bar->position_at_row($row);

The vertical scroll position (Clay's, 0 or negative; see
L<Clay::UI/scroll_state>) that centers the thumb on a row of the
scrollbar, or C<undef> when there is nothing to scroll.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Table>, L<Term::Fabulous::Manual::TableStyles/SIZE AND SCROLLING>.

=cut
