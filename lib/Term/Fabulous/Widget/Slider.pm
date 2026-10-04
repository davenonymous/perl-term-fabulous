package Term::Fabulous::Widget::Slider;

use v5.32;
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
	use Term::Fabulous::Check qw(boolean glyph number positive_integer);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN);
	use Term::Fabulous::Unicode qw(string_columns);

	# Key name => steps (or pages, or the end) the value moves.
	my %MOVE_BY_KEY = (
		Left     => [ step => -1 ],
		Down     => [ step => -1 ],
		Right    => [ step =>  1 ],
		Up       => [ step =>  1 ],
		PageDown => [ page => -1 ],
		PageUp   => [ page =>  1 ],
		Home     => [ end  => -1 ],
		End      => [ end  =>  1 ],
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

	field $current;

	ADJUST :params ( :$value = undef ) {
		$show_value        = boolean( $self, show_value => $show_value );
		$page_step         = $self->_checked_page_step($page_step);
		$value_format      = $self->_checked_format($value_format);
		$preferred_columns = positive_integer( $self, preferred_columns => $preferred_columns );
		$fill_glyph        = glyph( $self, fill_glyph  => $fill_glyph );
		$track_glyph       = glyph( $self, track_glyph => $track_glyph );
		$thumb_glyph       = glyph( $self, thumb_glyph => $thumb_glyph );
		( $min, $max, $step ) = $self->_checked_range( min => $min, max => $max, step => $step );
		$current = $min;
		$self->value( $value // $min );
	}

	# The range with the given parts changed, checked as a whole.
	method _checked_range (%range) {
		my ( $low, $high, $increment ) = map { number( $self, $_ => $range{$_} ) } qw(min max step);
		die "Term::Fabulous::Widget::Slider: min ($low) must be less than max ($high)" unless $low < $high;
		die "Term::Fabulous::Widget::Slider: step must be positive, got $increment" unless $increment > 0;
		return ( $low, $high, $increment );
	}

	method _checked_page_step ($size) {
		return undef unless defined $size;
		$size = number( $self, page_step => $size );
		die "Term::Fabulous::Widget::Slider: page_step must be positive, got $size" unless $size > 0;
		return $size;
	}

	method _checked_format ($format) {
		return undef unless defined $format;
		die "Term::Fabulous::Widget::Slider: value_format must be a sprintf format string or a code reference"
			unless ref $format eq 'CODE' || !ref $format;
		return $format;
	}

	# ---------------------------------------------------------------------
	# Value
	# ---------------------------------------------------------------------

	# Digits after the decimal point in the shortest form of a number:
	# 0.25 has 2, 1e-12 has 12, 1500 has 0.
	sub _decimal_places ($number) {
		my ( $mantissa, $exponent ) = sprintf( '%.15g', $number ) =~ /\A-?(\d+(?:\.\d+)?)(?:e([-+]\d+))?\z/
			or die "Term::Fabulous::Widget::Slider: cannot read the decimal places of $number";
		my $places = $mantissa =~ /\.(\d+)\z/ ? length $1 : 0;
		return List::Util::max( 0, $places - ( $exponent // 0 ) );
	}

	# Digits after the decimal point that values need: enough for the
	# step and for min, so values stay on the grid and print without
	# floating-point noise.
	method _decimals () {
		return List::Util::max( _decimal_places($step), _decimal_places($min) );
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
		my $number = number( $self, value => $new[0] );
		die "Term::Fabulous::Widget::Slider: value must be in $min..$max, got $number" if $number < $min || $number > $max;
		$current = $self->_snapped($number);
		$self->mark_changed;
		return $current;
	}

	# The highest value on the grid; max itself when the range is a whole
	# number of steps.
	method _top_value () {
		return $self->_snapped($max);
	}

	# Changes min, max and step together, so a new range can be set in one
	# go whatever the old one was; the value moves into it.
	method set_range (%range) {
		my @unknown = grep { !/\A(?:min|max|step)\z/ } sort keys %range;
		die "Term::Fabulous::Widget::Slider: set_range takes min, max and step, got @unknown" if @unknown;
		( $min, $max, $step ) = $self->_checked_range( min => $min, max => $max, step => $step, %range );
		$current = $self->_snapped( List::Util::min( List::Util::max( $current, $min ), $max ) );
		$self->mark_changed;
		return $self;
	}

	method min (@new) {
		$self->set_range( min => $new[0] ) if @new;
		return $min;
	}

	method max (@new) {
		$self->set_range( max => $new[0] ) if @new;
		return $max;
	}

	method step (@new) {
		$self->set_range( step => $new[0] ) if @new;
		return $step;
	}

	method page_step (@new) {
		return $page_step // List::Util::max( $step, $step * floor( ( $max - $min ) / $step / 10 + 0.5 ) ) unless @new;
		$page_step = $self->_checked_page_step( $new[0] );
		return $self->page_step;
	}

	method show_value (@new) {
		return $show_value unless @new;
		$show_value = boolean( $self, show_value => $new[0] );
		$self->mark_changed;
		return $show_value;
	}

	method value_format (@new) {
		return $value_format unless @new;
		$value_format = $self->_checked_format( $new[0] );
		$self->mark_changed;
		return $value_format;
	}

	method preferred_columns (@new) {
		return $preferred_columns unless @new;
		$preferred_columns = positive_integer( $self, preferred_columns => $new[0] );
		$self->mark_changed;
		return $preferred_columns;
	}

	method fill_glyph  (@new) { return @new ? $self->_set_glyph( fill_glyph  => \$fill_glyph,  @new ) : $fill_glyph }
	method track_glyph (@new) { return @new ? $self->_set_glyph( track_glyph => \$track_glyph, @new ) : $track_glyph }
	method thumb_glyph (@new) { return @new ? $self->_set_glyph( thumb_glyph => \$thumb_glyph, @new ) : $thumb_glyph }

	method _set_glyph ( $name, $field_ref, $glyph ) {
		$$field_ref = glyph( $self, $name => $glyph );
		$self->mark_changed;
		return $$field_ref;
	}

	# The track color comes from the theme's input.track unless given.
	ADJUSTPARAMS($params) {
		$self->adopt_look_params( $params, 'track_color' );
	}

	method themed_params :common () {
		return ( $class->SUPER::themed_params, track_color => [ 'track', 'normal' ] );
	}

	method track_color (@new) {
		return @new ? $self->_set_color( track_color => @new ) : $self->look_value('track_color');
	}

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			( map { $_ => 'scalar' } qw(min max step page_step value value_format preferred_columns fill_glyph track_glyph thumb_glyph) ),
			show_value  => 'boolean',
			track_color => 'color',
		);
	}

	# min, max and step of a layout are one range, so they apply in any
	# order; the value comes after it.
	method apply_layout_settings :override (@settings) {
		my %is_range = map { $_ => 1 } qw(min max step);
		my %range    = map { @$_ } grep { $is_range{ $_->[0] } } @settings;
		$self->set_range(%range) if %range;
		return $self->SUPER::apply_layout_settings( grep { !$is_range{ $_->[0] } } @settings );
	}

	method format_value ($number) {
		return $value_format->($number) if ref $value_format eq 'CODE';
		return sprintf $value_format, $number if defined $value_format;
		return sprintf '%.*f', $self->_decimals, $number;
	}

	# The user moved the value: snap, and fire Change if it moved.
	# Returns 1 when the value changed.
	method _move_to ($number) {
		my $snapped = $self->_snapped( List::Util::min( List::Util::max( $number, $min ), $max ) );
		return 0 if $snapped == $current;
		$current = $snapped;
		$self->mark_changed;
		$self->fire_change($current);
		return 1;
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method handle_key ($event) {
		my $name = $event->main_key_name // return 0;
		my $move = $MOVE_BY_KEY{$name}   // return 0;
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

			# At min or max the notch is left to a scroll box.
			return 0 unless $self->_move_to( $current + ( $key == TB_KEY_MOUSE_WHEEL_UP ? $step : -$step ) );
			$event->use_wheel;
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
		return List::Util::max map { string_columns( $self->format_value($_) ) } $min, $self->_top_value, $current;
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

		$self->fill_attrs( 0,          0, $thumb,              $fill_glyph,  $self->accent_attr,                                                                  $bg );
		$self->fill_attrs( $thumb + 1, 0, $track - $thumb - 1, $track_glyph, $self->color_attr( $self->is_enabled ? $self->track_color : $self->disabled_color ), $bg );
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

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::Slider;

	my $volume = Term::Fabulous::Widget::Slider->new(
		id           => 'volume',
		min          => 0,
		max          => 100,
		step         => 5,
		value        => 50,
		value_format => '%d%%',
	);
	$volume->on( Change => sub ($event) {
		set_volume( $event->value );
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	say $volume->value;    # 50
	$volume->value(75);    # programmatic: fires no Change

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.01/screenshots/widget-slider.svg" alt="Three sliders: focused at 65 percent, a temperature of 21.5 degrees, and a disabled one"></p>

=end html

=head1 DESCRIPTION

The picture shows three sliders: a focused one at 65 percent (the thumb
is in the C<text_color> while the slider has the focus), one that
formats its value with a code reference, and a disabled one. The
program is F<examples/widgets/slider.pl>.

A slider lets the user choose a number from a range. It shows a
horizontal track with a thumb at the current value and, by default, the
value itself right of the track:

=for highlighter language=text

	==========o---------  50

(with line-drawing characters and a dot instead of the ASCII shown
here). The part of the track left of the thumb is painted in the
C<accent_color>, the rest in C<track_color>.

The value is always on the grid C<min>, C<min + step>,
C<min + 2 * step>, ... and never outside C<min>..C<max>. Values are
rounded to as many decimal places as the C<step> or C<min> has
(whichever has more), so with a step of C<0.1> you get C<0.3>, not
C<0.30000000000000004>, and C<< min => 0.5, step => 1 >> gives C<0.5>,
C<1.5>, C<2.5>, ... If the range is not a
whole number of steps (C<min> 0, C<max> 10, C<step> 3), the highest
reachable value is the last grid value below C<max> (9).

The user moves the value with the arrow keys, Page Up and Page Down,
Home and End, by clicking or dragging on the track, or with the mouse
wheel.

Disabling, colors, focus and sizing are described in
L<Term::Fabulous::Widget::Input>. Unless the C<layout> sizes it, the
slider is one row high and C<preferred_columns> plus the width of the
value label plus one column wide.

=head1 CONSTRUCTOR

=head2 new

=for highlighter language=perl

	my $slider = Term::Fabulous::Widget::Slider->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::Input/CONSTRUCTOR>
(C<id>, C<layout>, C<background_color>, the border parameters,
C<disabled>, C<can_focus>, C<text_color>, C<disabled_color>,
C<accent_color>, C<focus_background_color>, the other Box parameters)
and the ones below. Unknown parameters die.

=over

=item C<min>

A finite number. Default: 0. The lowest value. Must be less than C<max>,
or the constructor dies.

=item C<max>

A finite number. Default: 100. The highest value.

=item C<step>

A positive finite number. Default: 1. The distance between two values
of the grid, and how far one arrow key press or wheel notch moves the
value.

=item C<value>

A finite number in C<min>..C<max>. Default: C<min>. The initial value;
it is rounded to the nearest grid value. Dies if outside the range.

=item C<page_step>

A positive finite number, or C<undef>. Default: C<undef>, which means a
tenth of the range rounded to whole steps, but at least one step (10 for
the default range 0..100). How far C<PageUp> and C<PageDown> move the
value.

=item C<show_value>

A boolean, stored as 1 or 0. Default: 1. Whether the value is shown
right of the track. A reference dies.

=item C<value_format>

How the value is shown: a C<sprintf> format string such as C<'%d%%'> or
C<'%.1f C'>, or a code reference that gets the value and returns the
text. Default: C<undef>, which shows the value with as many decimal
places as the C<step> or C<min> has, whichever has more. Anything other
than a string, a code reference or C<undef> dies. The label is as wide as the widest of the
lowest value, the highest reachable value and the current value, so the
track keeps its length while the value changes.

	value_format => sub ($value) { $value == 0 ? 'off' : "$value dB" },

=item C<preferred_columns>

A positive integer. Default: 20. The length of the track in columns when
the C<layout> gives the slider no width. The value label and one space
are added to it.

=item C<fill_glyph>

A single character one column wide. Default: C<"\x{2501}"> (heavy
horizontal line). The track left of the thumb.

=item C<track_glyph>

A single character one column wide. Default: C<"\x{2500}"> (light
horizontal line). The track right of the thumb.

=item C<thumb_glyph>

A single character one column wide. Default: C<"\x{25CF}"> (black
circle). The thumb. It is painted in C<accent_color>, or in
C<text_color> while the slider has the focus.

=item C<track_color>

A color, in any format L<Term::Fabulous::Widget::Input> accepts. The
track right of the thumb. Default: the theme's C<input.track>,
C<[90, 96, 110, 255]> in the dark theme, a gray.

=back

The glyph parameters die unless they are exactly one grapheme cluster
one column wide; the numeric parameters die unless they are finite
numbers in their range.

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Input/METHODS> (C<disabled>,
C<is_enabled>, the color accessors, C<mark_changed>), plus:

=head2 value

	my $number = $slider->value;
	$slider->value(42);

Accessor. Returns the current value, a number. Writing rounds the new
value to the nearest grid value, marks the input changed, and returns the stored value.
Dies if the new value is not a finite number or lies outside
C<min>..C<max>. Writing fires no C<Change> event.

=head2 min

	my $min = $slider->min;
	$slider->min(10);

Accessor for the lower end of the range. Writing moves the value into
the new range if needed (without a C<Change> event), marks the input
changed and returns the new C<min>. Dies if the new C<min> is not a finite number
less than C<max>; the range then stays as it was. To move a range past
its other end, use L</set_range>.

=head2 max

	my $max = $slider->max;
	$slider->max(200);

Accessor for the upper end of the range; works like L</min>. Dies if the
new C<max> is not a finite number greater than C<min>.

=head2 set_range

	$slider->set_range( min => 200, max => 300 );
	$slider->set_range( step => 0.5 );

Changes C<min>, C<max> and C<step> together: the parts not given keep
their values, and the new range is checked as a whole, so a range can
move anywhere in one call (with L</min> and L</max> one at a time,
C<min 200> while C<max> is still 100 dies). Moves the value into the
new range and onto its grid if needed (without a C<Change> event),
marks the input changed and returns the slider. Dies, leaving the range as it was,
when C<min> is not less than C<max>, the step is not positive, a part
is not a finite number, or another name is given.

=head2 step

	my $step = $slider->step;
	$slider->step(0.5);

Accessor for the step. Writing moves the value onto the new grid,
marks the input changed and returns the new step. Dies unless the step is a positive
finite number; the step then stays as it was.

=head2 page_step

	my $page = $slider->page_step;
	$slider->page_step(25);
	$slider->page_step(undef);    # back to a tenth of the range

Accessor. Reading returns the effective page step (the computed default
when none was set); writing returns the new effective page step. A value
that is not C<undef> or a positive finite number dies and leaves the old
one.

=head2 show_value

	my $shown = $slider->show_value;
	$slider->show_value(0);

Accessor for the C<show_value> parameter. Returns 1 or 0, also for a
value passed to C<new>. Writing marks the input changed and returns the
new value. Any plain value is accepted as a boolean; a reference dies
and leaves the setting unchanged.

=head2 value_format

	$slider->value_format('%.2f');

Accessor for the C<value_format> parameter. Writing marks the input changed and returns
the new format. Anything other than a string, a code reference or
C<undef> dies and leaves the old format.

=head2 format_value

	my $text = $slider->format_value(42);

A number formatted as the slider shows it (see C<value_format>).

=head2 preferred_columns

	my $columns = $slider->preferred_columns;
	$slider->preferred_columns(40);

Accessor for the C<preferred_columns> parameter. Writing returns the new
value, which takes effect at the next frame. A value that is not a
positive integer dies and leaves the old value.

=head2 fill_glyph

	$slider->fill_glyph('=');

Accessor for the C<fill_glyph> parameter. Writing marks the input changed and returns
the new glyph. A value that is not a single one-column character dies
and leaves the old glyph.

=head2 track_glyph

	$slider->track_glyph('-');

Accessor for the C<track_glyph> parameter; works like L</fill_glyph>.

=head2 thumb_glyph

	$slider->thumb_glyph('o');

Accessor for the C<thumb_glyph> parameter; works like L</fill_glyph>.

=head2 track_color

	$slider->track_color('#444444');

Accessor for the C<track_color> parameter. Writing marks the input changed and returns
the new color as C<[r, g, b, a]>. An invalid color dies and leaves the old one.

=head1 KEYS

While the slider has the focus and is enabled:

=over

=item C<Left>, C<Down>

Decrease the value by one C<step>.

=item C<Right>, C<Up>

Increase the value by one C<step>.

=item C<PageDown>, C<PageUp>

Decrease or increase the value by C<page_step>.

=item C<Home>, C<End>

Go to the lowest or the highest reachable value.

=back

The value never leaves the range; at either end these keys do nothing
(but are still used). All other keys bubble to the ancestors.

=head1 MOUSE

=over

=item Click and drag

Pressing the left button on the track moves the thumb there, and
dragging with the button held moves it along while the pointer stays
over the slider. The track's first column is C<min>, its last column
C<max>, and the value is rounded to the grid. Clicks on the value label
do nothing.

=item Wheel

Each notch moves the value by one C<step>: up increases, down
decreases. A notch that cannot move the value (down at C<min>, up at
the highest reachable value) is not used: inside a
L<Term::Fabulous::Widget::ScrollBox> it scrolls the scroll box instead.

=back

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> whenever the user moves the value to a
different grid value; C<< $event->value >> is the new number. While
dragging, it is fired for every new value. Programmatic writes to
C<value>, C<min>, C<max> and C<step> fire nothing.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Input/KDL PROPERTIES>, plus
C<min>, C<max>, C<step>, C<page_step>, C<value>, C<show_value>
(C<#true> / C<#false>), C<value_format> (a format string only; code
references cannot be written in KDL), C<preferred_columns>,
C<fill_glyph>, C<track_glyph>, C<thumb_glyph> and C<track_color>:

=for highlighter language=kdl

	use Term::Fabulous::Widget::Slider as Slider

	Slider "temperature" {
		min -10
		max 40
		step 0.5
		value 21.5
		value_format "%.1f C"
	}

C<min>, C<max> and C<step> are applied together, through L</set_range>,
and before C<value>, so they may come in any order: C<min 200; max 300>
works although the default C<max> is 100.

=head1 EXAMPLES

=head2 A percentage with a custom label

=for highlighter language=perl

	my $opacity = Term::Fabulous::Widget::Slider->new(
		min          => 0,
		max          => 1,
		step         => 0.05,
		value        => 1,
		value_format => sub ($value) { sprintf '%3d%%', $value * 100 },
	);

=head2 Keep two sliders in order

	my $low  = Term::Fabulous::Widget::Slider->new( value => 20 );
	my $high = Term::Fabulous::Widget::Slider->new( value => 80 );

	$low->on( Change => sub ($event) {
		$high->value( $event->value ) if $high->value < $event->value;
		return;
	} );

=head1 SEE ALSO

L<Term::Fabulous::Widget::Input>, L<Term::Fabulous::Event::Change>,
L<the slider section of the forms guide|Term::Fabulous::Manual::Forms/Sliders>,
L<Term::Fabulous::Cookbook::Forms/Choose from options in Perl (Dropdown, RadioGroup, Slider)>.

=cut
