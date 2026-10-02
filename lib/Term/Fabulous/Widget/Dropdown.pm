package Term::Fabulous::Widget::Dropdown;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Dropdown::List;
use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Dropdown
	:isa(Term::Fabulous::Widget::Input)
	:strict(params)
{
	use Clay::XS qw(sizing_fixed CLAY_ATTACH_TO_PARENT CLAY_ATTACH_POINT_LEFT_TOP CLAY_ATTACH_POINT_LEFT_BOTTOM);
	use List::Util qw(first max min);
	use Scalar::Util qw(refaddr);
	use Termbox 2 qw(TB_KEY_MOUSE_LEFT TB_MOD_MOTION);
	use Time::HiRes qw(time);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Unicode qw(string_columns);

	use constant ARROW_DOWN        => "\x{25BE}";
	use constant ARROW_UP          => "\x{25B4}";
	use constant TYPEAHEAD_SECONDS => 1;
	use constant LIST_Z_INDEX      => 1000;

	field @options;
	field $selected;    # index into @options, or undef

	field $placeholder            :param = '';
	field $max_visible_options    :param = 8;
	field $placeholder_color      :param = [ 120, 126, 138, 255 ];
	field $list_background_color  :param = [ 30,  33,  40,  255 ];
	field $highlight_text_color   :param = [ 16,  18,  22,  255 ];

	# The open list, the option it highlights and whether it opened upwards.
	field $list;
	field $highlighted;
	field $opens_upwards = 0;

	# Typed characters that search the labels, and when the last one came.
	field $typed = '';
	field $typed_at = 0;

	ADJUST :params ( :$options = undef, :$value = undef, :$selected_index = undef ) {
		die "Term::Fabulous::Widget::Dropdown: give 'value' or 'selected_index', not both" if defined $value && defined $selected_index;
		$self->_checked_text( placeholder => $placeholder );
		$self->_checked_count($max_visible_options);
		$self->_checked_color( $_->[0] => $_->[1] )
			foreach [ placeholder_color => $placeholder_color ], [ list_background_color => $list_background_color ], [ highlight_text_color => $highlight_text_color ];
		$self->background_color( [ 36, 40, 48, 255 ] ) unless defined $self->background_color;

		$self->options($options)               if defined $options;
		$self->value($value)                   if defined $value;
		$self->selected_index($selected_index) if defined $selected_index;
	}

	method _checked_text ( $name, $text ) {
		die "Term::Fabulous::Widget::Dropdown: $name must be a string, got " . ( ref $text || 'undef' ) unless defined $text && !ref $text;
		return $text;
	}

	method _checked_count ($count) {
		die "Term::Fabulous::Widget::Dropdown: max_visible_options must be a positive integer, got " . ( defined $count ? "'$count'" : 'undef' )
			unless defined $count && !ref $count && $count =~ /\A[0-9]+\z/ && $count > 0;
		return $count + 0;
	}

	# An option is a label (its own value), [ label, value ] or
	# { label => ..., value => ... }.
	method _parse_option ($option) {
		my ( $label, $value ) =
			  ref $option eq 'ARRAY' && @$option == 2 ? @$option
			: ref $option eq 'HASH'                  ? @{$option}{qw(label value)}
			: !ref $option                           ? ( $option, $option )
			:                                          ();
		die "Term::Fabulous::Widget::Dropdown: an option must be a label, [ label, value ] or { label => ..., value => ... }, got "
			. ( defined $option ? ( ref $option || "'$option'" ) : 'undef' )
			unless defined $label && !ref $label && !ref $value;
		die "Term::Fabulous::Widget::Dropdown: a hash option takes only the keys 'label' and 'value'"
			if ref $option eq 'HASH' && grep { $_ ne 'label' && $_ ne 'value' } keys %$option;
		return { label => "$label", value => $value // $label };
	}

	# ---------------------------------------------------------------------
	# Properties
	# ---------------------------------------------------------------------

	method options (@new) {
		return map { +{%$_} } @options unless @new;
		my ($list_of_options) = @new;
		die "Term::Fabulous::Widget::Dropdown: options must be an array reference" unless ref $list_of_options eq 'ARRAY';
		my @parsed = map { $self->_parse_option($_) } @$list_of_options;

		my $kept_value = defined $selected ? $options[$selected]{value} : undef;
		$self->close;
		@options  = @parsed;
		$selected = defined $kept_value ? $self->_index_of_value($kept_value) : undef;
		$self->repaint;
		return map { +{%$_} } @options;
	}

	method _index_of_value ($wanted) {
		return first { defined $options[$_]{value} && $options[$_]{value} eq $wanted } 0 .. $#options;
	}

	method value (@new) {
		return defined $selected ? $options[$selected]{value} : undef unless @new;
		my ($wanted) = @new;
		my $index = defined $wanted ? $self->_index_of_value($wanted) : undef;
		die "Term::Fabulous::Widget::Dropdown: no option has the value '$wanted'" if defined $wanted && !defined $index;
		$self->_select($index);
		return $self->value;
	}

	method selected_index (@new) {
		return $selected unless @new;
		my ($index) = @new;
		die "Term::Fabulous::Widget::Dropdown: selected_index must be undef or an index in 0.." . $#options . ", got '$index'"
			if defined $index && !( !ref $index && $index =~ /\A[0-9]+\z/ && $index < @options );
		$self->_select($index);
		return $selected;
	}

	method selected_label () {
		return defined $selected ? $options[$selected]{label} : undef;
	}

	method _select ($index) {
		$selected = defined $index ? $index + 0 : undef;
		$self->repaint;
		return;
	}

	method placeholder (@new) {
		return $placeholder unless @new;
		$placeholder = $self->_checked_text( placeholder => $new[0] );
		$self->repaint;
		return $placeholder;
	}

	method max_visible_options (@new) {
		return $max_visible_options unless @new;
		return $max_visible_options = $self->_checked_count( $new[0] );
	}

	method placeholder_color (@new) {
		return @new ? $self->_set_color( placeholder_color => \$placeholder_color, @new ) : $placeholder_color;
	}

	method list_background_color (@new) {
		return @new ? $self->_set_color( list_background_color => \$list_background_color, @new ) : $list_background_color;
	}

	method highlight_text_color (@new) {
		return @new ? $self->_set_color( highlight_text_color => \$highlight_text_color, @new ) : $highlight_text_color;
	}

	method disabled :override (@new) {
		$self->close if @new && $new[0];
		return $self->SUPER::disabled(@new);
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(value selected_index placeholder max_visible_options placeholder_color list_background_color highlight_text_color) );
	}

	# The options come as 'options "Red" "Green"' or as one 'option "Red"
	# value="r"' node per option.
	method parse_property :override ($kid) {
		my $name = $kid->name;
		return $self->SUPER::parse_property($kid) unless $name eq 'options' || $name eq 'option';
		die "Term::Fabulous::Widget::Dropdown: layout property '$name' takes no children" if $kid->children->@*;

		my @labels = map { $_->as_perl } $kid->args->@*;
		if ( $name eq 'options' ) {
			die "Term::Fabulous::Widget::Dropdown: layout property 'options' takes one or more labels and no properties"
				if !@labels || $kid->props->@*;
			return $self->options( [ $self->options, @labels ] );
		}

		my %props   = map { $_->[0] => $_->[1]->as_perl } $kid->props->@*;
		my @unknown = grep { $_ ne 'value' } sort keys %props;
		die "Term::Fabulous::Widget::Dropdown: layout property 'option' takes one label and an optional value=..."
			if @labels != 1 || @unknown;
		return $self->options( [ $self->options, { label => $labels[0], value => $props{value} // $labels[0] } ] );
	}

	# ---------------------------------------------------------------------
	# The list
	# ---------------------------------------------------------------------

	method is_open () {
		return defined $list ? 1 : 0;
	}

	method highlighted_index () {
		return $highlighted;
	}

	method open () {
		return $self if defined $list || !@options || !$self->is_enabled;
		$highlighted = $selected // 0;

		my ( $visible, $upwards ) = $self->_list_rows;
		my $scrolls = $visible < @options;
		my $width   = max( $self->_box_width, 2 + ( max map { string_columns( $_->{label} ) } @options ) + 2 + ( $scrolls ? 1 : 0 ) );
		$opens_upwards = $upwards;

		my ( $element, $parent ) = $upwards ? ( CLAY_ATTACH_POINT_LEFT_BOTTOM, CLAY_ATTACH_POINT_LEFT_TOP ) : ( CLAY_ATTACH_POINT_LEFT_TOP, CLAY_ATTACH_POINT_LEFT_BOTTOM );
		$list = Term::Fabulous::Widget::Dropdown::List->new(
			dropdown         => $self,
			visible_rows     => $visible,
			background_color => $self->rgba_of($list_background_color),
			border_color     => $self->rgba_of( $self->accent_color ),
			border_width     => 1,
			border_style     => Term::Fabulous::Enum::BorderStyle->Round,
			layout           => { sizing => { width => sizing_fixed($width), height => sizing_fixed( $visible + 2 ) } },
			floating         => {
				attach_to     => CLAY_ATTACH_TO_PARENT,
				attach_points => { element => $element, parent => $parent },
				z_index       => LIST_Z_INDEX,
			},
		);
		$self->add_child($list);
		$list->show_highlight;
		$self->repaint;
		return $self;
	}

	method close () {
		return $self unless defined $list;
		my $closing = $list;
		undef $list;
		undef $highlighted;
		$self->remove_children_with( sub ($child) { refaddr($child) == refaddr($closing) } );
		$self->repaint;
		return $self;
	}

	# The width of the whole widget in the last frame (its natural width
	# before the first one).
	method _box_width () {
		my ( $left, undef, $right ) = $self->content_insets;
		return $left + ( $self->columns || ( $self->natural_size )[0] ) + $right;
	}

	# How many options the list shows, and whether it opens upwards: below
	# the widget when they fit there or there is at least as much room
	# below as above.
	method _list_rows () {
		my $wanted = min( scalar @options, $max_visible_options );
		my $ui     = $self->ui;
		my @origin = $self->content_origin;
		return ( $wanted, 0 ) unless defined $ui && @origin;

		my ( undef, $top, undef, $bottom ) = $self->content_insets;
		my $room_above = $origin[1] - $top;
		my $room_below = $ui->height - ( $origin[1] + $self->rows + $bottom );
		my $upwards    = $room_below < $wanted + 2 && $room_above > $room_below;
		my $room       = $upwards ? $room_above : $room_below;
		return ( max( 1, min( $wanted, $room - 2 ) ), $upwards ? 1 : 0 );
	}

	# Chooses an option as the user does.
	method choose ($index) {
		die "Term::Fabulous::Widget::Dropdown: choose needs an option index in 0.." . $#options . ", got " . ( defined $index ? "'$index'" : 'undef' )
			unless defined $index && !ref $index && $index =~ /\A[0-9]+\z/ && $index < @options;
		$self->close;
		return $self if defined $selected && $selected == $index;
		$self->_select($index);
		$self->fire_change( $self->value );
		return $self;
	}

	method highlight ($index) {
		return $self unless defined $list;
		$highlighted = min( max( $index, 0 ), $#options );
		$list->show_highlight;
		return $self;
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method focus_changed :override ($is_focused) {
		$self->close unless $is_focused;
		$self->repaint;
		return;
	}

	method handle_mouse ($event) {
		return 0 unless refaddr( $event->target ) == refaddr($self);
		return 0 unless $event->key == TB_KEY_MOUSE_LEFT && !( $event->modifiers & TB_MOD_MOTION );
		$self->is_open ? $self->close : $self->open;
		return 1;
	}

	method handle_key ($event) {
		my $text = $event->text;
		return $self->_type_ahead($text) if defined $text && $text ne ' ';

		my $name = $event->key_name // return 0;
		return $self->_handle_key_while_open($name) if $self->is_open;

		if ( $name eq 'Enter' || $name eq 'Space' || $name eq 'Alt+Down' || $name eq 'F4' ) {
			$self->open;
			return 1;
		}
		my $last = $#options;
		return 0 if $last < 0;
		my %target = (
			Up   => defined $selected ? max( $selected - 1, 0 ) : $last,
			Down => defined $selected ? min( $selected + 1, $last ) : 0,
			Home => 0,
			End  => $last,
		);
		return 0 unless exists $target{$name};
		$self->_choose_closed( $target{$name} );
		return 1;
	}

	method _choose_closed ($index) {
		return if defined $selected && $selected == $index;
		$self->_select($index);
		$self->fire_change( $self->value );
		return;
	}

	method _handle_key_while_open ($name) {
		if ( $name eq 'Escape' ) {
			$self->close;
			return 1;
		}
		if ( $name eq 'Enter' || $name eq 'Space' ) {
			$self->choose($highlighted);
			return 1;
		}
		my $page   = $list->visible_rows;
		my %target = (
			Up       => $highlighted - 1,
			Down     => $highlighted + 1,
			PageUp   => $highlighted - $page,
			PageDown => $highlighted + $page,
			Home     => 0,
			End      => $#options,
		);
		return 0 unless exists $target{$name};
		$self->highlight( $target{$name} );
		return 1;
	}

	# Typing finds the next option whose label starts with the typed text;
	# characters typed within a second of each other form one search.
	method _type_ahead ($character) {
		return 0 unless @options;
		my $now = time;
		$typed    = $now - $typed_at <= TYPEAHEAD_SECONDS ? $typed . $character : $character;
		$typed_at = $now;

		my $current = $self->is_open ? $highlighted : $selected // -1;
		my $start   = length $typed > 1 ? $current : $current + 1;
		my $wanted  = fc $typed;
		my ($match) = grep { fc( substr( $options[$_]{label}, 0, length $typed ) ) eq $wanted } map { ( $start + $_ ) % @options } 0 .. $#options;
		return 1 unless defined $match;

		$self->is_open ? $self->highlight($match) : $self->_choose_closed($match);
		return 1;
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method natural_size () {
		my $widest = max 0, map { string_columns( $_->{label} ) } @options;
		return ( max( $widest, string_columns($placeholder) ) + 2, 1 );
	}

	method paint () {
		my $bg    = $self->paint_focus_background;
		my $label = $self->selected_label;
		my $fg    = defined $label ? $self->foreground_attr : $self->color_attr($placeholder_color);
		$self->paint_text( 0, 0, $label // $placeholder, $fg, $bg, max( 0, $self->columns - 2 ) );
		$self->put_attrs( $self->columns - 1, 0, $opens_upwards && $self->is_open ? ARROW_UP : ARROW_DOWN, $self->accent_attr, $bg );
		return;
	}

	# The attributes of an option's row in the list:
	# ( $fg, $bg ) for the highlighted, the selected and the other options.
	method option_attrs ($index) {
		return ( $self->color_attr($highlight_text_color), $self->accent_attr ) if defined $highlighted && $index == $highlighted;
		return ( $self->accent_attr, undef ) if defined $selected && $index == $selected;
		return ( $self->foreground_attr, undef );
	}

	method option_label ($index) {
		return $options[$index]{label};
	}

	method option_count () {
		return scalar @options;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Dropdown - Choose one of several options from a list that opens

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Dropdown;

	my $color = Term::Fabulous::Widget::Dropdown->new(
		options     => [ 'Red', [ 'Dark green' => 'green' ], { label => 'Blue', value => 'blue' } ],
		placeholder => 'Pick a color',
	);
	$color->on( Change => sub ($event) { paint_with( $event->value ); return } );

=head1 DESCRIPTION

An L<Term::Fabulous::Widget::Input> showing the label of the selected
option and an arrow. Opened by Enter, Space, Alt+Down, F4 or a click,
it shows its options in a list floating over the other widgets, below
the dropdown, or above it when there is more room there. The list
shows up to C<max_visible_options> options at a time and scrolls
through the rest. Unknown constructor parameters die.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::Input>:

=over

=item C<options>

An arrayref of options. Each option is a label (a string that is also
its value), C<[ $label, $value ]> or C<< { label => $label, value =>
$value } >>; a missing value is the label. Default none.

=item C<value>, C<selected_index>

The initial selection, by value or by index; giving both dies. Default
none selected.

=item C<placeholder>

Shown in C<placeholder_color> while nothing is selected; default none.

=item C<max_visible_options>

The most options the list shows at once, a positive integer; default 8.
The list also shrinks to the room left in the terminal.

=item C<placeholder_color>, C<list_background_color>, C<highlight_text_color>

The color of the placeholder, of the list's background and of the text
of the highlighted option, which is shown on the C<accent_color>. The
list's border has the C<accent_color>, and the selected option's label
too.

=item C<background_color>

Defaults to a dark gray, like the text inputs.

=back

=head1 METHODS

=head2 value

	$dropdown->value('green');

Reader and writer of the selected option's value, C<undef> when none
is selected. Writing selects the first option with that value (C<undef>
clears the selection); a value no option has dies. Writing fires no
event.

=head2 selected_index, selected_label

The index of the selected option (reader and writer; C<undef> for none,
an index out of range dies), and its label.

=head2 options

	my @options = $dropdown->options;              # ( { label => ..., value => ... }, ... )
	$dropdown->options( [ 'One', 'Two' ] );

Reader and writer. Writing closes the list and keeps the selection when
an option with the selected value is still there.

=head2 placeholder, max_visible_options, placeholder_color, list_background_color, highlight_text_color

Readers and writers of the constructor parameters.

=head2 open, close, is_open

Open and close the list as the user does; C<open> does nothing without
options or while disabled. Both return the dropdown.

=head2 choose

	$dropdown->choose(2);

Selects the option at an index as the user does: closes the list and
fires C<Change> when the selection changes. An index out of range dies.
Returns the dropdown.

=head2 highlighted_index

The option highlighted in the open list, C<undef> while closed.

=head1 KEYS

While closed: Enter, Space, Alt+Down and F4 open the list. Up and Down
select the previous and next option, Home and End the first and last
one.

While open: Up, Down, Page Up, Page Down, Home and End move the
highlight; Enter and Space select the highlighted option and close the
list, Escape closes it without a change. The list also closes when the
dropdown loses the focus, for example through Tab or a click elsewhere.

Typing letters selects (or, while open, highlights) the next option
whose label starts with them, ignoring case; letters typed within a
second continue the search.

=head1 MOUSE

A click on the dropdown opens or closes the list. Pressing on an option
highlights it; releasing the button over it selects it and closes the
list. The mouse wheel scrolls the list.

=head1 EVENTS

L<Term::Fabulous::Event::Change> when the user selects another option,
with its value.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Input/KDL PROPERTIES> plus C<value>,
C<selected_index>, C<placeholder>, C<max_visible_options> and the colors
above. Options are given as labels, or one at a time with a value:

	Dropdown "color" {
		options "Red" "Green"
		option "Dark blue" value="navy"
		value "navy"
	}

=cut
