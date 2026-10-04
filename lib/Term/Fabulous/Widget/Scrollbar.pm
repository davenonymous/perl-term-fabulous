package Term::Fabulous::Widget::Scrollbar;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Canvas;

class Term::Fabulous::Widget::Scrollbar :isa(Term::Fabulous::Widget::Canvas) :strict(params) {
	use List::Util qw(max min);
	use POSIX qw(floor);
	use Scalar::Util qw(weaken);
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed);
	use Term::Fabulous::Check qw(cell_color describe);
	use Term::Fabulous::Render::Attr qw(cell_color_attr);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT);

	my $CONTINUE = Clay::UI::Enum::Result->CONTINUE;
	my $HANDLED  = Clay::UI::Enum::Result->HANDLED;

	# Per axis: the glyphs of the track and the thumb, and the keys of the
	# scroll position and of the viewport and content size.
	my %AXIS = (
		vertical   => { track => "\x{2502}", thumb => "\x{2503}", position => 'y', size => 'height', thickness => 'width' },
		horizontal => { track => "\x{2500}", thumb => "\x{2501}", position => 'x', size => 'width',  thickness => 'height' },
	);

	field $follows :param;
	field $axis :param = 'vertical';
	field $_painted_key;

	# The colors come from the theme's scrollbar family unless given.
	ADJUSTPARAMS($params) {
		$self->adopt_look_params( $params, qw(track_color thumb_color) );
	}

	method theme_family :common () {
		return 'scrollbar';
	}

	method themed_params :common () {
		return ( $class->SUPER::themed_params, track_color => [ 'track', 'normal' ], thumb_color => [ 'thumb', 'normal' ] );
	}

	ADJUST {
		die "Term::Fabulous::Widget::Scrollbar: follows must be a scroll container"
			unless defined $follows && $follows->DOES('Clay::UI::Role::Layout::HasScroll');
		weaken $follows;
		die "Term::Fabulous::Widget::Scrollbar: axis must be 'vertical' or 'horizontal', got " . describe($axis)
			unless defined $axis && !ref $axis && exists $AXIS{$axis};
		weaken( my $weak = $self );
		$self->on( Mouse => sub ($event) { return $weak ? $weak->_on_mouse($event) : $CONTINUE } );
	}

	method axis () { return $axis }

	method _set_color ( $name, @new ) {
		return $self->look_value($name) unless @new;
		return $self->set_look( $name => cell_color( $self, $name => $new[0] ) );
	}

	method track_color (@new) { return $self->_set_color( track_color => @new ) }
	method thumb_color (@new) { return $self->_set_color( thumb_color => @new ) }

	# The cells of the track along the scrollbar's axis.
	method _length () {
		return $axis eq 'vertical' ? $self->rows : $self->columns;
	}

	# Whether the container scrolls along the scrollbar's axis at all.
	method _axis_scrolls () {
		return 0 unless defined $follows;
		return ( $axis eq 'vertical' ? $follows->vertical : $follows->horizontal ) ? 1 : 0;
	}

	# A scrollbar for an axis the container does not scroll along takes
	# no cells, so a box that stops scrolling sideways loses the row.
	method contribute_layout :override ($config) {
		$self->SUPER::contribute_layout($config);
		return if $self->_axis_scrolls;
		my %sizing = %{ $config->{layout}{sizing} // {} };
		$sizing{ $AXIS{$axis}{thickness} } = sizing_fixed(0);
		$config->{layout} = { %{ $config->{layout} // {} }, sizing => \%sizing };
		return;
	}

	# The scroll state of the container in the frame being drawn, or undef
	# when it was not laid out or there is nothing to scroll along the axis.
	method _scrolling () {
		my $ui = $self->ui // return undef;
		return undef unless $self->_axis_scrolls;
		my $state = $ui->scroll_state($follows) // return undef;
		my $size  = $AXIS{$axis}{size};
		return $state->{content}{$size} > $state->{viewport}{$size} ? $state : undef;
	}

	# [ first cell, cells ] of the thumb in a track of $length cells.
	method _thumb ( $state, $length ) {
		my $spec = $AXIS{$axis};
		my ( $viewport, $content ) = ( $state->{viewport}{ $spec->{size} }, $state->{content}{ $spec->{size} } );
		my $size   = max( 1, min( $length, int( $length * $viewport / $content + 0.5 ) ) );
		my $travel = $content - $viewport;
		my $first  = int( ( $length - $size ) * -$state->{position}{ $spec->{position} } / $travel + 0.5 );
		return [ max( 0, min( $length - $size, $first ) ), $size ];
	}

	method refresh :override () {
		my $length = $self->_length;
		my $state  = $self->_scrolling;
		my $thumb  = defined $state && $length > 0 ? $self->_thumb( $state, $length ) : undef;
		my ( $track_color, $thumb_color ) = ( $self->track_color, $self->thumb_color );
		my $key = join ':', $self->columns, $self->rows, ( defined $thumb ? @$thumb : 'none' ), @$track_color, @$thumb_color;
		return if defined $_painted_key && $key eq $_painted_key;
		$_painted_key = $key;
		$self->clear;
		return unless defined $thumb;
		my $spec = $AXIS{$axis};
		my ( $track, $bar ) = ( cell_color_attr( fg => $track_color ), cell_color_attr( fg => $thumb_color ) );

		foreach my $cell ( 0 .. $length - 1 ) {
			my $on_thumb = $cell >= $thumb->[0] && $cell < $thumb->[0] + $thumb->[1];
			my ( $x, $y ) = $axis eq 'vertical' ? ( 0, $cell ) : ( $cell, 0 );
			$self->put_attrs( $x, $y, $on_thumb ? $spec->{thumb} : $spec->{track}, $on_thumb ? $bar : $track, undef );
		}
		return;
	}

	# The scroll position that puts the thumb's middle at a cell of the
	# track, for a click or a drag; undef when there is nothing to scroll.
	method position_at ($cell) {
		my $state  = $self->_scrolling // return undef;
		my $length = $self->_length;
		return undef unless $length > 0;
		my $size     = $self->_thumb( $state, $length )->[1];
		my $free     = max( 1, $length - $size );
		my $fraction = max( 0, min( 1, ( $cell - floor( $size / 2 ) ) / $free ) );
		my $spec     = $AXIS{$axis};
		return -$fraction * ( $state->{content}{ $spec->{size} } - $state->{viewport}{ $spec->{size} } );
	}

	# A left click, or a drag with the left button, scrolls the container
	# so that the thumb is centered under the pointer.
	method _on_mouse ($event) {
		return $CONTINUE unless $event->key == TB_KEY_MOUSE_LEFT;
		my $ui = $self->ui;
		my ( $column, $row ) = $self->cell_at($event);
		return $HANDLED unless defined $ui && defined $follows && defined $row;
		my $position = $self->position_at( $axis eq 'vertical' ? $row : $column );
		$ui->scroll_to( $follows, { $AXIS{$axis}{position} => $position } ) if defined $position;
		return $HANDLED;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Scrollbar - A scrollbar for a scroll container

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Scrollbar;

	my $bar = Term::Fabulous::Widget::Scrollbar->new(
		follows     => $scroll_box,
		axis        => 'vertical',
		track_color => [ 70, 76, 90, 255 ],
		thumb_color => [ 97, 175, 239, 255 ],
		layout      => { sizing => { width => sizing_fixed(1), height => sizing_grow() } },
	);

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Canvas> one cell thick that shows how far a
scroll container (a widget with L<Clay::UI::Role::Layout::HasScroll>,
such as a L<Term::Fabulous::Widget::ScrollBox>) is scrolled along one
axis. While the content is larger than the container along that axis,
it draws a track (a thin line) with a thumb (a heavy line) whose length
and place show which part of the content is visible; otherwise it is
empty. A vertical scrollbar paints its first column with U+2502 and
U+2503, a horizontal one its first row with U+2500 and U+2501. It
paints from the scroll state of the frame being drawn, so it is always
up to date, and it paints again only when the thumb moved. A scrollbar
for an axis its container does not scroll along (C<vertical> or
C<horizontal> of the container is false) is laid out zero cells thick
and takes no space.

A left click on the scrollbar scrolls the container so that the thumb
is centered under the pointer, and dragging with the left button keeps
doing so (see L</position_at>). The container must have been laid out
with the scrollbar in the same L<Term::Fabulous>; the scrollbar is
empty before the first frame.

L<Term::Fabulous::Widget::ScrollBox> makes its own scrollbars, inside
its border, and L<Term::Fabulous::Widget::Table> shows one right of its
body. Make one yourself to put a scrollbar somewhere else: give it a
C<fixed(1)> width and a C<grow> height (or the other way round for a
horizontal one) and place it next to the container.

=head1 CONSTRUCTOR

=head2 new

	my $bar = Term::Fabulous::Widget::Scrollbar->new( follows => $box, %parameters );

Unknown parameters die. A Scrollbar takes every parameter of
L<Term::Fabulous::Widget::Canvas> plus:

=over

=item C<follows>

B<Required>. The scroll container whose position the scrollbar shows,
held weakly. Dies unless it does L<Clay::UI::Role::Layout::HasScroll>.

=item C<axis>

C<'vertical'> (the default) or C<'horizontal'>; anything else dies.

=item C<track_color>

The color of the track. Default: the theme's C<scrollbar.track>, a
dark grey, C<[ 70, 76, 90, 255 ]>, in the dark theme.
Takes anything a canvas cell takes (see
L<Term::Fabulous::Widget::Canvas/put>).

=item C<thumb_color>

The color of the thumb. Default: the theme's C<scrollbar.thumb>, a
light blue, C<[ 97, 175, 239, 255 ]>, in the dark theme.

=back

=head1 METHODS

A Scrollbar has all methods of L<Term::Fabulous::Widget::Canvas> plus:

=head2 axis

	my $axis = $bar->axis;

Returns C<'vertical'> or C<'horizontal'>. Read-only.

=head2 track_color

	$bar->track_color('#464c5a');

Accessor for the C<track_color> parameter. Writing marks the scrollbar
changed and returns the new color as C<[r, g, b, a]>. An invalid color
dies and leaves the old one.

=head2 thumb_color

	$bar->thumb_color('#61afef');

Accessor for the C<thumb_color> parameter, as L</track_color>.

=head2 position_at

	my $position = $bar->position_at($cell);

The scroll position along the axis (Clay's, 0 or negative; see
L<Term::Fabulous/"bounding_box, scroll_state, scroll_to">) that centers
the thumb on a cell of the track, counted from the top or the left, or
C<undef> when there is nothing to scroll. A click on the scrollbar
scrolls to this position.

=head1 EVENTS

=over

=item C<Mouse> (L<Term::Fabulous::Event::Mouse>)

A left press or a drag with the left button scrolls the container and
stops the event; other mouse events bubble on. Your own listeners run
after the scrollbar's.

=back

=head1 SEE ALSO

L<Term::Fabulous::Widget::ScrollBox>, L<Term::Fabulous::Widget::Table>,
L<Term::Fabulous::Manual::Events/SCROLLING>.

=cut
