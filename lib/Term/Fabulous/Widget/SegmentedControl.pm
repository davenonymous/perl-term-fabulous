package Term::Fabulous::Widget::SegmentedControl;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::SegmentedControl
	:isa(Term::Fabulous::Widget::Input)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use List::Util qw(first sum0);
	use Scalar::Util qw(refaddr weaken);
	use Term::Fabulous::Check qw(boolean cell_color describe non_negative_integer);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT);
	use Term::Fabulous::Unicode qw(string_columns);

	# Key name => step through the enabled segments.
	my %STEP_BY_KEY = ( Left => -1, Up => -1, Right => 1, Down => 1 );

	field @options;    # { label, value, disabled }
	field $selected;    # index into @options, or undef

	field $vertical        :param = 0;
	field $segment_padding :param = 1;
	field $separator       :param = "\x{2502}";

	# The colors of the selected label, the separators and the hovered
	# segment come from the theme's input family unless given.
	my @COLOR_NAMES = qw(selected_text_color separator_color hover_background_color);

	# The segment the pointer is over while it hovers.
	field $_hover_index;

	ADJUST :params ( :$options = undef, :$value = undef, :$selected_index = undef ) {
		die ref($self) . ": give 'value' or 'selected_index', not both"
			if defined $value && defined $selected_index;
		$vertical        = boolean( $self, vertical => $vertical );
		$segment_padding = non_negative_integer( $self, segment_padding => $segment_padding );
		$separator       = $self->_checked_separator($separator);

		$self->options($options) if defined $options;
		$self->value($value) if defined $value;
		$self->selected_index($selected_index) if defined $selected_index;

		weaken( my $weak_self = $self );
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		$self->on( MouseMove      => sub ($event) { $weak_self->_hover_at( $weak_self->_index_at($event) ) if $weak_self;                           return $continue } );
		$self->on( OnHoverStopped => sub ($event) { $weak_self->_hover_at(undef) if $weak_self && refaddr( $event->target ) == refaddr($weak_self); return $continue } );
	}

	method _checked_separator ($glyph) {
		return undef unless defined $glyph;
		return Term::Fabulous::Check::glyph( $self, separator => $glyph );
	}

	# An option is a label (its own value), [ label, value ] or
	# { label => ..., value => ..., disabled => ... }.
	method _parse_option ($option) {
		my ( $label, $value, $disabled )
			= ref $option eq 'ARRAY' && @$option == 2 ? @$option
			: ref $option eq 'HASH'                   ? @{$option}{qw(label value disabled)}
			: !ref $option                            ? ( $option, $option )
			:                                           ();
		die ref($self) . ": an option must be a label, [ label, value ] or { label => ..., value => ..., disabled => ... }, got " . describe($option)
			unless defined $label && !ref $label && !ref $value;
		die ref($self) . ": a hash option takes only the keys 'label', 'value' and 'disabled'"
			if ref $option eq 'HASH' && grep { !/\A(?:label|value|disabled)\z/ } keys %$option;
		return { label => "$label", value => $value // $label, disabled => boolean( $self, 'option disabled' => $disabled ) };
	}

	# ---------------------------------------------------------------------
	# Options and value
	# ---------------------------------------------------------------------

	method options (@new) {
		return map { +{%$_} } @options unless @new;
		my ($list_of_options) = @new;
		die ref($self) . ": options must be an array reference" unless ref $list_of_options eq 'ARRAY';
		my @parsed = map { $self->_parse_option($_) } @$list_of_options;

		my $kept_value = defined $selected ? $options[$selected]{value} : undef;
		@options  = @parsed;
		$selected = defined $kept_value ? $self->_index_of_value($kept_value) : undef;
		$self->mark_changed;
		return map { +{%$_} } @options;
	}

	method _index_of_value ($wanted) {
		return first { defined $options[$_]{value} && $options[$_]{value} eq $wanted } 0 .. $#options;
	}

	method value (@new) {
		return defined $selected ? $options[$selected]{value} : undef unless @new;
		my ($wanted) = @new;
		my $index = defined $wanted ? $self->_index_of_value($wanted) : undef;
		die ref($self) . ": no option has the value '$wanted'" if defined $wanted && !defined $index;
		$self->_select($index);
		return $self->value;
	}

	method selected_index (@new) {
		return $selected unless @new;
		my ($index) = @new;
		die ref($self) . ": selected_index must be undef or an index in 0.." . $#options . ", got " . describe($index)
			if defined $index && !( !ref $index && $index =~ /\A[0-9]+\z/ && $index < @options );
		$self->_select($index);
		return $selected;
	}

	method _select ($index) {
		$selected = defined $index ? $index + 0 : undef;
		$self->mark_changed;
		return;
	}

	# Selects a segment as the user does: fires Change when the selection
	# changes. A disabled segment cannot be chosen.
	method choose ($index) {
		die ref($self) . ": choose needs an option index in 0.." . $#options . ", got " . describe($index)
			unless defined $index && !ref $index && $index =~ /\A[0-9]+\z/ && $index < @options;
		return $self if $options[$index]{disabled};
		return $self if defined $selected && $selected == $index;
		$self->_select($index);
		$self->fire_change( $self->value );
		return $self;
	}

	method option_disabled ( $index, @new ) {
		die ref($self) . ": option_disabled needs an option index in 0.." . $#options . ", got " . describe($index)
			unless defined $index && !ref $index && $index =~ /\A[0-9]+\z/ && $index < @options;
		return $options[$index]{disabled} unless @new;
		$options[$index]{disabled} = boolean( $self, 'option disabled' => $new[0] );
		$self->mark_changed;
		return $options[$index]{disabled};
	}

	# ---------------------------------------------------------------------
	# Accessors
	# ---------------------------------------------------------------------

	method _set ( $field_ref, $value ) {
		$$field_ref = $value;
		$self->mark_changed;
		return $$field_ref;
	}

	method vertical            (@new) { return @new ? $self->_set( \$vertical, boolean( $self, vertical => $new[0] ) )                              : $vertical }
	method segment_padding     (@new) { return @new ? $self->_set( \$segment_padding, non_negative_integer( $self, segment_padding => $new[0] ) )   : $segment_padding }
	method separator           (@new) { return @new ? $self->_set( \$separator, $self->_checked_separator( $new[0] ) )                              : $separator }
	method selected_text_color (@new) { return @new ? $self->set_look( selected_text_color => cell_color( $self, selected_text_color => $new[0] ) ) : $self->look_value('selected_text_color') }
	method separator_color     (@new) { return @new ? $self->set_look( separator_color => cell_color( $self, separator_color => $new[0] ) )         : $self->look_value('separator_color') }

	method hover_background_color (@new) {
		return @new ? $self->set_look( hover_background_color => cell_color( $self, hover_background_color => $new[0] ) ) : $self->look_value('hover_background_color');
	}

	ADJUSTPARAMS($params) {
		$self->adopt_look_params( $params, @COLOR_NAMES );
	}

	method themed_params :common () {
		return (
			$class->SUPER::themed_params, selected_text_color => [ 'selected_text', 'normal' ], separator_color => [ 'separator', 'normal' ],
			hover_background_color => [ 'hover_background', 'normal' ]
		);
	}

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			options => \&_parse_options,
			option  => \&_parse_options,
			( map { $_ => 'scalar' } qw(value selected_index segment_padding separator) ),
			vertical => 'boolean',
			( map { $_ => 'color' } @COLOR_NAMES ),
		);
	}

	# options "Day" "Week" "Month"
	# option "Year" value="y" disabled=#true
	method _parse_options ($kid) {
		my $name = $kid->name;
		die ref($self) . ": layout property '$name' takes no children" if $kid->children->@*;

		my @labels = map { $_->as_perl } $kid->args->@*;
		if ( $name eq 'options' ) {
			die ref($self) . ": layout property 'options' takes one or more labels and no properties" if !@labels || $kid->props->@*;
			return $self->options( [ $self->options, @labels ] );
		}

		my %props   = map  { $_->[0] => $_->[1]->as_perl } $kid->props->@*;
		my @unknown = grep { !/\A(?:value|disabled)\z/ } sort keys %props;
		die ref($self) . ": layout property 'option' takes one label and optional value=... and disabled=..." if @labels != 1 || @unknown;
		return $self->options( [ $self->options, { label => $labels[0], value => $props{value} // $labels[0], disabled => $props{disabled} // 0 } ] );
	}

	# The options of a layout are added before its value is set.
	method apply_layout_settings :override (@settings) {
		my %is_option = ( options => 1, option => 1 );
		return $self->SUPER::apply_layout_settings( ( grep { $is_option{ $_->[0] } } @settings ), ( grep { !$is_option{ $_->[0] } } @settings ) );
	}

	# ---------------------------------------------------------------------
	# Geometry: where each segment lies along the control
	# ---------------------------------------------------------------------

	method _separator_cells () {
		return defined $separator && !$vertical ? 1 : 0;
	}

	# The cells each segment needs along the control: its label with the
	# padding on both sides; a row each when vertical.
	method _natural_lengths () {
		return map { $vertical ? 1 : string_columns( $_->{label} ) + 2 * $segment_padding } @options;
	}

	# The [start, length] of every segment along the control: the natural
	# lengths, with any extra space shared out from the first segment on.
	method _spans ($length) {
		my @lengths = $self->_natural_lengths or return ();
		my $extra   = $length - sum0(@lengths) - $self->_separator_cells * $#options;
		if ( $extra > 0 ) {
			my $share = int( $extra / @lengths );
			my $left  = $extra % @lengths;
			$lengths[$_] += $share + ( $_ < $left ? 1 : 0 ) foreach 0 .. $#lengths;
		}
		my @spans;
		my $at = 0;
		foreach my $segment_length (@lengths) {
			push @spans, [ $at, $segment_length ];
			$at += $segment_length + $self->_separator_cells;
		}
		return @spans;
	}

	method natural_size () {
		my @lengths = $self->_natural_lengths;
		return ( List::Util::max( 1, map { string_columns( $_->{label} ) + 2 * $segment_padding } @options ),   List::Util::max( 1, scalar @options ) ) if $vertical;
		return ( List::Util::max( 1, sum0(@lengths) + $self->_separator_cells * ( @options ? $#options : 0 ) ), 1 );
	}

	# The segment under a mouse event, or undef.
	method _index_at ($event) {
		my ( $column, $row ) = $self->cell_at($event);
		return undef unless defined $column;
		my $position = $vertical ? $row : $column;
		my @spans    = $self->_spans( $vertical ? $self->rows : $self->columns );
		return first { $position >= $spans[$_][0] && $position < $spans[$_][0] + $spans[$_][1] } 0 .. $#spans;
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method _hover_at ($index) {
		return unless $self->is_enabled;
		return if ( $index // -1 ) == ( $_hover_index // -1 );
		$_hover_index = $index;
		$self->mark_changed;
		return;
	}

	method handle_key ($event) {
		my $name    = $event->main_key_name // return 0;
		my @enabled = grep { !$options[$_]{disabled} } 0 .. $#options;
		return 0 unless @enabled;

		if ( $name =~ /\A[1-9]\z/ ) {
			return 0 if $name > @options;
			$self->choose( $name - 1 );
			return 1;
		}
		my %target = ( Home => $enabled[0], End => $enabled[-1] );
		if ( exists $STEP_BY_KEY{$name} ) {
			my ($at) = grep { $enabled[$_] == ( $selected // -1 ) } 0 .. $#enabled;
			$target{$name} = defined $at ? $enabled[ ( $at + $STEP_BY_KEY{$name} ) % @enabled ] : $STEP_BY_KEY{$name} > 0 ? $enabled[0] : $enabled[-1];
		}
		return 0 unless exists $target{$name};
		$self->choose( $target{$name} );
		return 1;
	}

	method handle_mouse ($event) {
		return 0 unless $event->key == TB_KEY_MOUSE_LEFT;
		my $index = $self->_index_at($event) // return 1;
		$self->choose($index);
		return 1;
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method paint_key :override () {
		return ( $self->SUPER::paint_key, $_hover_index // -1 );
	}

	method paint () {
		my $bg      = $self->paint_focus_background;
		my $length  = $vertical ? $self->rows    : $self->columns;
		my $across  = $vertical ? $self->columns : $self->rows;
		my @spans   = $self->_spans($length);
		my $enabled = $self->is_enabled;

		foreach my $index ( 0 .. $#spans ) {
			my ( $start, $segment_length ) = $spans[$index]->@*;
			my $option      = $options[$index];
			my $is_selected = defined $selected && $selected == $index;
			my $is_hovered  = $enabled && !$option->{disabled} && defined $_hover_index && $_hover_index == $index;
			my $segment_bg  = $is_selected ? $self->accent_attr                              : $is_hovered         ? $self->color_attr( $self->hover_background_color ) : $bg;
			my $fg          = $is_selected ? $self->color_attr( $self->selected_text_color ) : $option->{disabled} ? $self->color_attr( $self->disabled_color )         : $self->foreground_attr;

			my $label  = $option->{label};
			my $width  = $vertical ? $across         : $segment_length;
			my $height = $vertical ? $segment_length : $across;
			my $x0     = $vertical ? 0               : $start;
			my $y0     = $vertical ? $start          : 0;
			$self->fill_attrs( $x0, $y0 + $_, $width, ' ', undef, $segment_bg ) foreach 0 .. $height - 1;
			my $label_x = $x0 + int( ( $width - string_columns($label) ) / 2 );
			$self->paint_text( List::Util::max( $x0, $label_x ), $y0 + int( ( $height - 1 ) / 2 ), $label, $fg, $segment_bg, $x0 + $width );

			next if $vertical || !defined $separator || $index == $#spans;
			$self->put_attrs( $start + $segment_length, $_, $separator, $self->color_attr( $enabled ? $self->separator_color : $self->disabled_color ), $bg ) foreach 0 .. $height - 1;
		}
		return;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::SegmentedControl - Choose one of a few options
shown side by side

=head1 SYNOPSIS

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::SegmentedControl;

	my $period = Term::Fabulous::Widget::SegmentedControl->new(
		id      => 'period',
		options => [ [ Day => 'd' ], [ Week => 'w' ], [ Month => 'm' ], [ Year => 'y' ] ],
		value   => 'w',
	);
	$period->on( Change => sub ($event) {
		reload_chart( $event->value );
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	say $period->value;    # w
	$period->value('m');   # programmatic: fires no Change

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.01/screenshots/widget-segmented-control.svg" alt="Segmented controls: a focused one with Week selected, one stretched to the full width, one with a disabled segment, a vertical one, and a disabled one"></p>

=end html

=head1 DESCRIPTION

The picture shows segmented controls in their forms: a focused one
with C<Week> selected, one stretched to the width of its parent, one
with a disabled segment, a vertical one and a disabled one. The program
is F<examples/widgets/segmented-control.pl>.

A segmented control shows a few options side by side as one bar, with
the selected one highlighted:

=for highlighter language=text

	 Day │ Week │ Month │ Year

(the selected segment is painted on the C<accent_color>). It does what
a L<Term::Fabulous::Widget::RadioGroup> does, in less space and without
marks, and suits a handful of short options such as a period, a view
or a sort order. The user chooses with the arrow keys, C<Home> and
C<End>, the digits (C<1> is the first segment), or a click; the
selection changes at once, there is nothing to confirm. While the
pointer is over a segment, it is shown on C<hover_background_color>.

Each option has a label and a value (the label unless given), and may
be disabled on its own: a disabled segment is drawn in
C<disabled_color>, skipped by the keys and ignored by clicks. The
selected segment keeps its C<selected_text_color> on the accent (gray
while the control is disabled), so it stays readable. The
control may be vertical, one segment per row. When the C<layout> makes
it wider (or, vertical, higher) than its segments need, the extra
space is shared among the segments, so a control with
C<< sizing => { width => sizing_grow() } >> fills its row.

Disabling, colors, focus and sizing are described in
L<Term::Fabulous::Widget::Input>. The control is one row high (or,
vertical, one row per option) and, unless the C<layout> sizes it, as
wide as its labels with C<segment_padding> on each side and a separator
between them.

=head1 CONSTRUCTOR

=head2 new

=for highlighter language=perl

	my $control = Term::Fabulous::Widget::SegmentedControl->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::Input/CONSTRUCTOR>
(C<id>, C<layout>, C<background_color>, the border parameters,
C<disabled>, C<can_focus>, C<text_color>, C<disabled_color>,
C<accent_color>, C<focus_background_color>, the other Box parameters)
and the ones below. Unknown parameters die.

=over

=item C<options>

An array reference of options, each one of:

=over

=item *

a string: the label, which is also the value;

=item *

an array reference C<[ $label, $value ]>;

=item *

a hash reference C<< { label => $label, value => $value, disabled => $bool } >>;
C<value> defaults to the label, C<disabled> to false.

=back

Default: no options (the control is then one empty cell). A value may
be C<undef>; labels must be strings. Anything else dies, and so do
other hash keys.

=item C<value>

The value of the option to select, or C<undef> for none. Default:
C<undef>. Dies when no option has the value. Give C<value> or
C<selected_index>, not both.

=item C<selected_index>

The index of the option to select, from 0, or C<undef>. Default:
C<undef>.

=item C<vertical>

A boolean. Default: 0, a row. True stacks the segments, one per row,
without separators. Stored as 1 or 0; a reference dies.

=item C<segment_padding>

A non-negative integer. Default: 1. The spaces on each side of a
label inside its segment; 0 makes the control compact, 2 roomy.

=item C<separator>

A single character one column wide, or C<undef>. Default:
C<"\x{2502}"> (a thin vertical line). The glyph between two segments
of a horizontal control; C<undef> draws none.

=item C<selected_text_color>

The color of the selected segment's label, which sits on the
C<accent_color>, in any format
L<Term::Fabulous::Widget::Canvas/Colors> accepts. Default: the theme's
C<input.selected_text>, C<[16, 18, 22, 255]> in the dark theme, nearly
black.

=item C<separator_color>

The color of the separators. Default: the theme's C<input.separator>,
C<[90, 96, 110, 255]> in the dark theme, a gray.

=item C<hover_background_color>

The background of the segment under the pointer. Default: the theme's
C<input.hover_background>, C<[60, 66, 80, 255]> in the dark theme, a
dark gray.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Input/METHODS> (C<disabled>,
C<is_enabled>, the color accessors, C<mark_changed>), plus:

=head2 options

	my @options = $control->options;
	$control->options( [ 'List', 'Grid', { label => 'Map', value => 'map', disabled => 1 } ] );

Accessor. The reader returns the options as a list of hash references
C<< { label => ..., value => ..., disabled => ... } >> (copies). Writing
replaces all options, checked as C<new> checks them, keeps the
selection if the new options have the selected value and clears it
otherwise, marks the input changed and returns the new list. Writing
fires no C<Change>.

=head2 value

	my $value = $control->value;
	$control->value('map');
	$control->value(undef);    # no selection

Accessor. The reader returns the selected option's value, or C<undef>.
Writing selects the option with that value (C<undef> deselects), marks
the input changed and returns the new value. Dies when no option has
the value. Fires no C<Change>.

=head2 selected_index

	my $index = $control->selected_index;
	$control->selected_index(2);

Accessor for the selection by index (from 0), or C<undef>. Dies for an
index outside the options. Fires no C<Change>.

=head2 choose

	$control->choose(1);

Selects a segment as the user does: when the selection changes, a
C<Change> event is fired. A disabled segment, or the segment already
selected, changes nothing. Dies for an index outside the options.
Returns the control.

=head2 option_disabled

	my $is_disabled = $control->option_disabled(2);
	$control->option_disabled( 2, 1 );

Reads or sets whether one option is disabled, by index. Writing marks
the input changed and returns the new state. A disabled option that is
selected stays selected.

=head2 vertical

	$control->vertical(1);

Accessor for the C<vertical> parameter. Returns 1 or 0.

=head2 segment_padding

	$control->segment_padding(2);

Accessor for the C<segment_padding> parameter.

=head2 separator

	$control->separator(' ');
	$control->separator(undef);

Accessor for the C<separator> parameter.

=head2 selected_text_color

	$control->selected_text_color('#000000');

Accessor for the C<selected_text_color> parameter; the reader returns
C<[r, g, b, a]>. An invalid color dies and leaves the old one.

=head2 separator_color

	$control->separator_color('#444444');

Accessor for the C<separator_color> parameter; works like
L</selected_text_color>.

=head2 hover_background_color

	$control->hover_background_color( [ 70, 80, 100 ] );

Accessor for the C<hover_background_color> parameter; works like
L</selected_text_color>.

Every writer marks the input changed, so the next frame paints the new
look.

=head1 KEYS

While the control has the focus and is enabled:

=over

=item C<Left>, C<Up>

The previous enabled segment, wrapping around from the first to the
last.

=item C<Right>, C<Down>

The next enabled segment, wrapping around from the last to the first.

=item C<Home>, C<End>

The first and the last enabled segment.

=item C<1> to C<9>

The segment with that number, counted from 1. A disabled segment is
not chosen; a number beyond the last segment bubbles.

=back

Without a selection, C<Right> chooses the first enabled segment and
C<Left> the last. All other keys bubble to the ancestors.

=head1 MOUSE

=over

=item Hover

The segment under the pointer is painted on C<hover_background_color>
while the pointer stays over it; a disabled segment and a disabled
control show nothing. The terminal reports pointer motion only while
the program runs with the mouse enabled.

=item Click

A click on a segment selects it and focuses the control. A click on a
disabled segment or a separator only focuses it.

=back

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> when the user selects another
segment (or L</choose> is called); C<< $event->value >> is the value of
the selected option. Programmatic writes to C<value>,
C<selected_index> and C<options> fire nothing.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Input/KDL PROPERTIES>, plus
C<value>, C<selected_index>, C<segment_padding>, C<separator>,
C<vertical> (C<#true> / C<#false>) and the colors
C<selected_text_color>, C<separator_color> and
C<hover_background_color>. Options are added with two kinds of nodes,
which may be repeated and mixed; each adds to the options given
before:

=over

=item C<options "Label 1" "Label 2" ...>

One or more options whose value is their label.

=item C<option "Label" value="v" disabled=#true>

One option; C<value=> defaults to the label, C<disabled=> to C<#false>.

=back

=for highlighter language=kdl

	use Term::Fabulous::Widget::SegmentedControl as SegmentedControl

	SegmentedControl "period" {
		options "Day" "Week" "Month"
		option "Year" value="y" disabled=#true
		value "Week"
		sizing width=grow
	}

The options of a layout are added before its C<value> and
C<selected_index> are set, wherever they stand in the block. A
C<value> that no option has dies.

=head1 EXAMPLES

=head2 A view switch that fills its row

=for highlighter language=perl

	my $view = Term::Fabulous::Widget::SegmentedControl->new(
		options => [qw(List Grid Map)],
		value   => 'List',
		layout  => { sizing => { width => sizing_grow() } },
	);

=head2 A vertical control as a menu

	my $menu = Term::Fabulous::Widget::SegmentedControl->new(
		options         => [ 'General', 'Network', 'Users', { label => 'Licenses', disabled => 1 } ],
		value           => 'General',
		vertical        => 1,
		segment_padding => 2,
	);

=head1 SEE ALSO

L<Term::Fabulous::Widget::Input>, L<Term::Fabulous::Event::Change>,
L<Term::Fabulous::Widget::RadioGroup>, L<Term::Fabulous::Widget::Dropdown>,
L<the segmented control section of the forms guide|Term::Fabulous::Manual::Forms/Segmented controls>.

=cut
