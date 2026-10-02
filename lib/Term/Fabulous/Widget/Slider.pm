package Term::Fabulous::Widget::Slider;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Slider
	:isa(Term::Fabulous::Widget::Input)
	:strict(params)
{
	use List::Util ();    # min and max are methods here
	use POSIX qw(floor);
	use Scalar::Util qw(looks_like_number);
	use Termbox 2 qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns string_columns);

	# Key name => steps (or pages, or the end) the value moves.
	my %MOVE_BY_KEY = (
		Left     => [ step => -1 ],
		Down     => [ step => -1 ],
		Right    => [ step => 1 ],
		Up       => [ step => 1 ],
		PageDown => [ page => -1 ],
		PageUp   => [ page => 1 ],
		Home     => [ end  => -1 ],
		End      => [ end  => 1 ],
	);

	field $min               :param = 0;
	field $max               :param = 100;
	field $step              :param = 1;
	field $page_step         :param = undef;
	field $show_value        :param = 1;
	field $value_format      :param = undef;
	field $preferred_columns :param = 20;
	field $fill_glyph        :param = "\x{2501}";
	field $track_glyph       :param = "\x{2500}";
	field $thumb_glyph       :param = "\x{25CF}";
	field $track_color       :param = [ 90, 96, 110, 255 ];

	# The current value; undef only until construction or a layout sets it.
	field $current;

	ADJUST :params ( :$value = undef ) {
		$self->_check_range( $min, $max, $step );
		$self->_checked_page_step($page_step);
		$self->_checked_format($value_format);
		$self->_checked_columns($preferred_columns);
		$self->_checked_glyph( $_->[0] => $_->[1] ) foreach [ fill_glyph => $fill_glyph ], [ track_glyph => $track_glyph ], [ thumb_glyph => $thumb_glyph ];
		$self->_checked_color( track_color => $track_color );
		$self->value( $value // $current // $min );
	}

	sub _number ( $name, $value ) {
		die "Term::Fabulous::Widget::Slider: $name must be a finite number, got " . ( defined $value ? "'$value'" : 'undef' )
			unless defined $value && !ref $value && looks_like_number($value) && $value == $value && $value - $value == 0;
		return $value + 0;
	}

	method _check_range ( $low, $high, $increment ) {
		( $low, $high, $increment ) = ( _number( min => $low ), _number( max => $high ), _number( step => $increment ) );
		die "Term::Fabulous::Widget::Slider: min ($low) must be less than max ($high)" unless $low < $high;
		die "Term::Fabulous::Widget::Slider: step must be positive, got $increment"    unless $increment > 0;
		( $min, $max, $step ) = ( $low, $high, $increment );
		return;
	}

	method _checked_page_step ($size) {
		return undef unless defined $size;
		$size = _number( page_step => $size );
		die "Term::Fabulous::Widget::Slider: page_step must be positive, got $size" unless $size > 0;
		return $size;
	}

	method _checked_format ($format) {
		return undef unless defined $format;
		die "Term::Fabulous::Widget::Slider: value_format must be a sprintf format string or a code reference"
			unless ref $format eq 'CODE' || !ref $format;
		return $format;
	}

	method _checked_columns ($columns) {
		die "Term::Fabulous::Widget::Slider: preferred_columns must be a positive integer, got " . ( defined $columns ? "'$columns'" : 'undef' )
			unless defined $columns && !ref $columns && $columns =~ /\A[0-9]+\z/ && $columns > 0;
		return $columns + 0;
	}

	method _checked_glyph ( $name, $glyph ) {
		my @clusters = defined $glyph && !ref $glyph ? grapheme_clusters($glyph) : ();
		die "Term::Fabulous::Widget::Slider: $name must be a single character one column wide, got " . ( defined $glyph ? ( ref $glyph || "'$glyph'" ) : 'undef' )
			unless @clusters == 1 && cluster_columns( $clusters[0] ) == 1;
		return $glyph;
	}

	# ---------------------------------------------------------------------
	# Value
	# ---------------------------------------------------------------------

	# Digits after the decimal point of the step, so values print without
	# floating-point noise.
	method _decimals () {
		my $text = sprintf '%.10f', $step;
		$text =~ s/0+\z//;
		return $text =~ /\.(\d+)\z/ ? length $1 : 0;
	}

	# The nearest value on the grid min, min + step, ... inside the range.
	method _snapped ($number) {
		my $steps   = floor( ( $number - $min ) / $step + 0.5 );
		my $snapped = $min + $steps * $step;
		$snapped -= $step while $snapped > $max + $step / 1e6;
		$snapped = $min if $snapped < $min;
		return 0 + sprintf '%.*f', $self->_decimals, $snapped;
	}

	method value (@new) {
		return $current unless @new;
		my $number = _number( value => $new[0] );
		die "Term::Fabulous::Widget::Slider: value must be in $min..$max, got $number" if $number < $min || $number > $max;
		$current = $self->_snapped($number);
		$self->repaint;
		return $current;
	}

	# The highest value on the grid; max itself when the range is a whole
	# number of steps.
	method _top_value () {
		return $self->_snapped($max);
	}

	method _set_range ( $low, $high, $increment ) {
		$self->_check_range( $low, $high, $increment );
		$current = $self->_snapped( List::Util::min( List::Util::max( $current // $min, $min ), $max ) );
		$self->repaint;
		return;
	}

	method min (@new) {
		$self->_set_range( $new[0], $max, $step ) if @new;
		return $min;
	}

	method max (@new) {
		$self->_set_range( $min, $new[0], $step ) if @new;
		return $max;
	}

	method step (@new) {
		$self->_set_range( $min, $max, $new[0] ) if @new;
		return $step;
	}

	method page_step (@new) {
		return $page_step // List::Util::max( $step, $step * floor( ( $max - $min ) / $step / 10 + 0.5 ) ) unless @new;
		$page_step = $self->_checked_page_step( $new[0] );
		return $self->page_step;
	}

	method show_value (@new) {
		return $show_value unless @new;
		$show_value = $new[0] ? 1 : 0;
		$self->repaint;
		return $show_value;
	}

	method value_format (@new) {
		return $value_format unless @new;
		$value_format = $self->_checked_format( $new[0] );
		$self->repaint;
		return $value_format;
	}

	method preferred_columns (@new) {
		return $preferred_columns unless @new;
		return $preferred_columns = $self->_checked_columns( $new[0] );
	}

	method fill_glyph (@new)  { return @new ? $self->_set_glyph( fill_glyph  => \$fill_glyph,  @new ) : $fill_glyph }
	method track_glyph (@new) { return @new ? $self->_set_glyph( track_glyph => \$track_glyph, @new ) : $track_glyph }
	method thumb_glyph (@new) { return @new ? $self->_set_glyph( thumb_glyph => \$thumb_glyph, @new ) : $thumb_glyph }

	method _set_glyph ( $name, $field_ref, $glyph ) {
		$$field_ref = $self->_checked_glyph( $name => $glyph );
		$self->repaint;
		return $$field_ref;
	}

	method track_color (@new) {
		return @new ? $self->_set_color( track_color => \$track_color, @new ) : $track_color;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties,
			qw(min max step page_step value show_value value_format preferred_columns fill_glyph track_glyph thumb_glyph track_color) );
	}

	method format_value ($number) {
		return $value_format->($number) if ref $value_format eq 'CODE';
		return sprintf $value_format, $number if defined $value_format;
		return sprintf '%.*f', $self->_decimals, $number;
	}

	# The user moved the value: snap, repaint, and fire Change if it moved.
	method _move_to ($number) {
		my $snapped = $self->_snapped( List::Util::min( List::Util::max( $number, $min ), $max ) );
		return if $snapped == $current;
		$current = $snapped;
		$self->repaint;
		$self->fire_change($current);
		return;
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method handle_key ($event) {
		my $name = $event->key_name // return 0;
		my $move = $MOVE_BY_KEY{$name} // return 0;
		my ( $unit, $direction ) = @$move;
		$self->_move_to(
			  $unit eq 'step' ? $current + $direction * $step
			: $unit eq 'page' ? $current + $direction * $self->page_step
			: $direction < 0  ? $min
			:                   $self->_top_value
		);
		return 1;
	}

	method handle_mouse ($event) {
		my $key = $event->key;
		if ( $key == TB_KEY_MOUSE_WHEEL_UP || $key == TB_KEY_MOUSE_WHEEL_DOWN ) {
			$self->_move_to( $current + ( $key == TB_KEY_MOUSE_WHEEL_UP ? $step : -$step ) );
			return 1;
		}
		return 0 unless $key == TB_KEY_MOUSE_LEFT;

		my ($column) = $self->cell_at($event);
		my $track = $self->_track_columns;
		return 1 unless defined $column && $column < $track;
		$self->_move_to( $track > 1 ? $min + ( $max - $min ) * $column / ( $track - 1 ) : $min );
		return 1;
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	# The columns of the value label: wide enough for any value, so the
	# track keeps its length while the value changes.
	method _label_columns () {
		return 0 unless $show_value;
		return List::Util::max map { string_columns( $self->format_value($_) ) } $min, $self->_top_value, $current // $min;
	}

	method _track_columns () {
		my $label = $self->_label_columns;
		return List::Util::max( 1, $self->columns - ( $label ? $label + 1 : 0 ) );
	}

	method natural_size () {
		my $label = $self->_label_columns;
		return ( $preferred_columns + ( $label ? $label + 1 : 0 ), 1 );
	}

	method paint () {
		my $bg    = $self->paint_focus_background;
		my $track = $self->_track_columns;
		my $thumb = int( ( $track - 1 ) * ( $current - $min ) / ( $max - $min ) + 0.5 );

		$self->fill_attrs( 0, 0, $thumb, $fill_glyph, $self->accent_attr, $bg );
		$self->fill_attrs( $thumb + 1, 0, $track - $thumb - 1, $track_glyph, $self->color_attr( $self->is_enabled ? $track_color : $self->disabled_color ), $bg );
		$self->put_attrs( $thumb, 0, $thumb_glyph, $self->is_focused ? $self->foreground_attr : $self->accent_attr, $bg );
		return unless $show_value;

		my $label = $self->format_value($current);
		my $x     = $self->columns - string_columns($label);
		$self->paint_text( List::Util::max( $x, $track + 1 ), 0, $label, $self->foreground_attr, $bg );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Slider - Choose a number from a range by moving a thumb

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Slider;

	my $volume = Term::Fabulous::Widget::Slider->new( min => 0, max => 100, step => 5, value => 50 );
	$volume->on( Change => sub ($event) { set_volume( $event->value ); return } );

=head1 DESCRIPTION

An L<Term::Fabulous::Widget::Input> showing a horizontal track with a
thumb at the current value and, by default, the value itself on the
right of it. The part of the track left of the thumb is painted in the
accent color. Unknown constructor parameters die.

The value is always one of C<min>, C<min + step>, C<min + 2 * step>,
... and lies within C<min> and C<max>. Values are rounded to as many
decimals as the step has, so a step of C<0.1> gives C<0.3>, not
C<0.30000000000000004>.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::Input>:

=over

=item C<min>, C<max>, C<step>

The range and the step between values; finite numbers with C<min>
below C<max> and a positive C<step>. Defaults 0, 100 and 1.

=item C<value>

The initial value, default C<min>. It is rounded to the nearest step;
a value outside the range dies.

=item C<page_step>

How far Page Up and Page Down move. Defaults to a tenth of the range,
rounded to whole steps (at least one step).

=item C<show_value>

Boolean, default 1: show the value right of the track.

=item C<value_format>

How the value is shown: a C<sprintf> format such as C<'%d%%'>, or a
code reference that gets the value and returns the text. By default,
with as many decimals as the step.

=item C<preferred_columns>

The length of the track when the C<layout> gives no width, a positive
integer; default 20. The value label adds to it.

=item C<fill_glyph>, C<track_glyph>, C<thumb_glyph>

The characters of the track left of the thumb, right of it, and of the
thumb; each a single character one column wide. Defaults: a heavy and a
light horizontal line and a black circle.

=item C<track_color>

The color of the track right of the thumb.

=back

All have readers and writers of the same name. Changing C<min>, C<max>
or C<step> moves the value into the new range. Writing C<value> fires no
event.

=head1 METHODS

=head2 format_value

	my $text = $slider->format_value(42);

A value as the slider shows it.

=head1 KEYS

Left and Down decrease the value by one step, Right and Up increase it.
Page Down and Page Up move by C<page_step>, Home and End to the lowest
and highest value.

=head1 MOUSE

Pressing on the track moves the thumb there, and dragging moves it
along; the value follows the pointer while it stays over the slider.
The mouse wheel moves the value by one step per notch.

=head1 EVENTS

L<Term::Fabulous::Event::Change> when the user moves the value, with
the new value.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Input/KDL PROPERTIES> plus the
constructor parameters above, except that C<value_format> takes only a
format string:

	Slider "volume" {
		max 11
		value 5
		value_format "%d dB"
	}

=cut
