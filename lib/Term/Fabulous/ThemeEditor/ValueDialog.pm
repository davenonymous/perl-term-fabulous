package Term::Fabulous::ThemeEditor::ValueDialog;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Dialog;

# The dialog that edits one setting of a theme: a list of tokens or
# border styles to choose from and, for a color, a field and sliders for
# a color of its own. Every change shows in the preview at once; Apply
# writes it to the theme, Cancel takes it back.
class Term::Fabulous::ThemeEditor::ValueDialog :isa(Term::Fabulous::Widget::Dialog) :strict(params) {
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM CLAY_ATTACH_TO_ROOT CLAY_ATTACH_POINT_RIGHT_CENTER);
	use Feature::Compat::Try;
	use List::Util qw(first min);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Check qw(color);
	use Term::Fabulous::Color;
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Theme;
	use Term::Fabulous::Theme::Document;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Slider;
	use Term::Fabulous::Widget::Table;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Widget::TextField;

	use constant LIST_ID => 'theme-editor-value-list';
	use constant SWATCH  => "\x{2588}" x 3;    # full blocks in the token's color

	field $key        :param :reader;
	field $current    :param;    # the value the theme has now (effective)
	field $is_set     :param = 0;    # whether the theme sets it
	field $default    :param = undef;    # what the key falls back to, for the hint
	field $palette    :param;    # token => [r, g, b, a], for the swatches
	field $on_preview :param;    # code: shows a value (undef: the theme as it is)
	field $on_apply   :param;    # code: writes a value
	field $on_reset   :param;    # code: removes the setting
	field $list_rows  :param = 12;    # how many rows the list shows

	field $kind;    # color, palette, style, name, base
	field $value;    # the value chosen now
	field $list;
	field $hex;
	field %slider;
	field $swatch;
	field $message;
	field $updating = 0;

	ADJUST {
		my $parsed = Term::Fabulous::Theme::Document::parse_key($key);
		$kind
			= $parsed->{section} eq 'palette' ? 'palette'
			: $parsed->{section} eq 'theme'   ? ( $parsed->{field} eq 'name' ? 'name' : 'base' )
			:                                   Term::Fabulous::Theme::slot_info( @{$parsed}{qw(family slot)} )->{kind};
		$value = $current;

		# At the right edge of the screen and without dimming it, so the
		# preview on the left shows the value being chosen in its true
		# colors.
		$self->backdrop_color( [ 0, 0, 0, 0 ] );
		$self->floating(
			{
				attach_to     => CLAY_ATTACH_TO_ROOT,
				attach_points => { element => CLAY_ATTACH_POINT_RIGHT_CENTER, parent => CLAY_ATTACH_POINT_RIGHT_CENTER },
				offset        => { x       => -1,                             y      => 0 },
				z_index       => $self->z_index + 1,
			}
		);
		$self->layout( { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed(64) }, padding => { left => 2, right => 2, top => 1, bottom => 1 }, child_gap => 1 } );

		$self->add_child( Term::Fabulous::Widget::Text->new( text => "Edit $key", bold => 1 ) );
		$self->add_child( Term::Fabulous::Widget::Text->new( text => $self->_hint($parsed) ) );
		$self->add_child( $self->_chooser($parsed) );
		$message = Term::Fabulous::Widget::Text->new( text => '' );
		$self->add_child( $message, $self->_buttons );

		weaken( my $weak_self = $self );
		$self->on( Close => sub ($event) { $weak_self->_closed; return Clay::UI::Enum::Result->CONTINUE } );
	}

	method value () {
		return $value;
	}

	# What the setting is now and what Reset gives it; tokens are named as
	# tokens (a token may be called like a state: disabled).
	method _hint ($parsed) {
		my $now
			= $is_set
			? 'The theme sets it to ' . $self->_words($current) . '.'
			: 'The theme does not set it' . ( defined $current ? '; it is ' . $self->_words($current) . ' now.' : '.' );
		return $now unless defined $default;
		return "$now That is its default, too." if $is_set && defined $current && $current eq $default;
		return "$now Reset gives it back to " . $self->_words($default) . '.';
	}

	method _words ($spec) {
		return exists $palette->{$spec} ? qq{the token "$spec"} : $spec;
	}

	# A list in a frame of its own (a table's own frame scrolls with its
	# rows), drawn in the accent while the list has the focus.
	sub _framed ( $list, $rows ) {
		my $frame = Term::Fabulous::Widget::Box->new( border_width => 1, layout => { sizing => { width => sizing_grow(), height => sizing_fixed( $rows + 2 ) } } );
		$frame->add_child($list);
		weaken( my $weak_frame = $frame );
		weaken( my $weak_list  = $list );
		$list->on( OnFocus => sub ($event) { $weak_frame->border_color( $weak_frame->family_look( input => 'accent' ) ) if $event->target == $weak_list; return Clay::UI::Enum::Result->CONTINUE } );
		$list->on( OnBlur  => sub ($event) { $weak_frame->reset_look('border_color') if $event->target == $weak_list;                                    return Clay::UI::Enum::Result->CONTINUE } );
		return $frame;
	}

	# ---------------------------------------------------------------------
	# What the dialog offers
	# ---------------------------------------------------------------------

	method _chooser ($parsed) {
		return $self->_name_field if $kind eq 'name';
		return $self->_list( map { [ $_, $_ ] } Term::Fabulous::Theme::builtin_names() ) if $kind eq 'base';
		return $self->_style_list($parsed) if $kind eq 'style';
		return $self->_color_editor if $kind eq 'palette';
		my $info    = Term::Fabulous::Theme::slot_info( @{$parsed}{qw(family slot)} );
		my @choices = map { [ $_, $_ ] } Term::Fabulous::Theme::tokens();
		push @choices, [ 'none',    'none (no color)' ] unless $info->{required};
		push @choices, [ 'reverse', 'reverse video' ] if $info->{reverse} && $parsed->{state} eq 'pressed';
		my $box = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_gap => 2 } );
		$box->add_child( $self->_list(@choices), $self->_color_editor );
		return $box;
	}

	method _name_field () {
		my $field = Term::Fabulous::Widget::TextField->new( value => $current // '', placeholder => 'The theme\'s name', layout => { sizing => { width => sizing_grow() } } );
		$field->editor->select_all;
		weaken( my $weak_self = $self );
		$field->on( Change => sub ($event) { $weak_self->_choose( $event->value, 0 ); return Clay::UI::Enum::Result->CONTINUE } );
		$field->on( Submit => sub ($event) { $weak_self->apply;                       return } );
		$hex = $field;
		return $field;
	}

	method _style_list ($parsed) {
		my $info    = Term::Fabulous::Theme::slot_info( @{$parsed}{qw(family slot)} );
		my @styles  = $info->{grid} ? Term::Fabulous::Enum::BorderStyle->get_grid_styles : Term::Fabulous::Enum::BorderStyle->values;
		my @choices = map {
			my ( $corner, $edge, $other ) = $_->get_top_glyphs;
			[ $_->name, $_->name, "$corner$edge$edge$other" ]
		} @styles;
		push @choices, [ 'none', 'none (no border style)' ] unless $info->{required};
		return $self->_list(@choices);
	}

	# A list of [ value, label, sample ] choices; the cursor on one
	# chooses it.
	method _list (@choices) {
		my %palette = %$palette;
		$list = Term::Fabulous::Widget::Table->new(
			id           => LIST_ID,
			row_id       => 'value',
			selection    => 'single',
			header       => 0,
			border       => 'none',
			column_lines => 'none',
			columns      => [
				{ key => 'sample', width => 'fixed(6)', cell_style => sub ($cell) { my $color = $palette{ $cell->{row}{value} }; return defined $color ? { text_color => $color } : {} } },
				{ key => 'label',  width => 'grow' },
			],
			rows   => [ map { { value => $_->[0], label => $_->[1], sample => $_->[2] // ( exists $palette{ $_->[0] } ? SWATCH : '' ) } } @choices ],
			layout => { sizing => { width => sizing_grow(), height => sizing_grow() } },
		);
		my ($chosen) = grep { $choices[$_][0] eq ( $current // '' ) } 0 .. $#choices;
		if ( defined $chosen ) {
			my $below = min( $#choices, $chosen + int( $list_rows / 2 ) );
			$list->cursor( $choices[$below][0] );    # scrolls so that the chosen value is near the middle
			$list->cursor( $choices[$chosen][0] );
			$list->set_selection( $choices[$chosen][0] );
		}
		weaken( my $weak_self = $self );
		$list->on( CursorMove  => sub ($event) { $weak_self->_choose( $event->row_id, 1 ) if defined $event->row_id; return Clay::UI::Enum::Result->CONTINUE } );
		$list->on( RowActivate => sub ($event) { $weak_self->apply;                                                  return } );
		return _framed( $list, $list_rows );
	}

	method _color_editor () {
		my $box = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() }, child_gap => 0 } );
		$hex    = Term::Fabulous::Widget::TextField->new( placeholder => '#rrggbb or #rrggbbaa', max_length => 32, layout => { sizing => { width => sizing_fixed(22) } } );
		$swatch = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(6), height => sizing_fixed(1) } } );
		my $row = Term::Fabulous::Widget::Box->new( layout => { child_gap => 1, padding => { bottom => 1 } } );
		$row->add_child( $hex,                                                               $swatch );
		$box->add_child( Term::Fabulous::Widget::Text->new( text => 'A color of its own:' ), $row );

		weaken( my $weak_self = $self );
		foreach my $channel ( [ red => 'R' ], [ green => 'G' ], [ blue => 'B' ], [ alpha => 'A' ] ) {
			my ( $name, $label ) = @$channel;
			my $slider = Term::Fabulous::Widget::Slider->new( min => 0, max => 255, step => 1, value => 0, value_format => '%3d', layout => { sizing => { width => sizing_grow() } } );
			my $line   = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_gap => 1 } );
			$line->add_child( Term::Fabulous::Widget::Text->new( text => $label ), $slider );
			$box->add_child($line);
			$slider{$name} = $slider;
			$slider->on( Change => sub ($event) { $weak_self->_slid; return Clay::UI::Enum::Result->CONTINUE } );
		}
		$hex->on( Change => sub ($event) { $weak_self->_typed( $event->value ); return Clay::UI::Enum::Result->CONTINUE } );
		$hex->on( Submit => sub ($event) { $weak_self->apply;                   return } );
		$self->_show_color( $self->_rgba_of($current) );
		$hex->value( $current // '' ) if defined $current && $current =~ /\A#/;
		$hex->editor->select_all;    # typing replaces the color
		return $box;
	}

	method _buttons () {
		my $row = Term::Fabulous::Widget::Box->new( layout => { child_gap => 2 } );
		weaken( my $weak_self = $self );
		my @buttons = ( [ 'Apply', ['primary'], sub { $weak_self->apply } ], [ 'Reset to default', [], sub { $weak_self->reset } ], [ 'Cancel', [], sub { $weak_self->cancel } ] );
		foreach my $definition (@buttons) {
			my ( $label, $classes, $action ) = @$definition;
			next if $label =~ /\AReset/ && !$is_set;
			my $button = Term::Fabulous::Widget::Button->new( border_width => 1, classes => $classes, layout => { padding => { left => 1, right => 1 } } );
			$button->add_child( Term::Fabulous::Widget::Text->new( text => $label ) );
			$button->on( Activate => sub ($event) { $action->(); return } );
			$row->add_child($button);
		}
		return $row;
	}

	# ---------------------------------------------------------------------
	# Choosing
	# ---------------------------------------------------------------------

	# The color a value stands for: a token's from the palette, or the
	# value read as a color; undef for none.
	method _rgba_of ($spec) {
		return undef unless defined $spec;
		return $palette->{$spec} if exists $palette->{$spec};
		try {
			return color( __CLASS__, 'value', $spec );
		}
		catch ($error) {
			return undef;
		}
	}

	method _show_color ($rgba) {
		return unless %slider;
		$updating = 1;
		my @channels = defined $rgba ? @$rgba : ( 0, 0, 0, 255 );
		$slider{red}->value( $channels[0] );
		$slider{green}->value( $channels[1] );
		$slider{blue}->value( $channels[2] );
		$slider{alpha}->value( $channels[3] );
		$updating = 0;
		defined $rgba && $rgba->[3] > 0 ? $swatch->background_color($rgba) : $swatch->reset_look('background_color');
		return;
	}

	# A value was chosen; the list (when the choice came from elsewhere)
	# and the color editor follow, the preview shows it.
	method _choose ( $chosen, $from_list ) {
		$value = $chosen;
		if ( $kind eq 'color' || $kind eq 'palette' ) {
			$self->_show_color( $self->_rgba_of($chosen) );
			if ($from_list) {
				$updating = 1;
				$hex->value( $chosen =~ /\A#/ ? $chosen : '' );
				$updating = 0;
			}
		}
		$list->set_selection if !$from_list && defined $list;
		$message->text('');
		$on_preview->( $self->_checked($chosen) ? $chosen : undef );
		return;
	}

	method _slid () {
		return if $updating;
		my $spec = _hex_of( map { $slider{$_}->value } qw(red green blue alpha) );
		$updating = 1;
		$hex->value($spec);
		$updating = 0;
		$self->_choose( $spec, 0 );
		return;
	}

	sub _hex_of ( $red, $green, $blue, $alpha ) {
		return sprintf( '#%02x%02x%02x', $red, $green, $blue ) if $alpha == 255;
		return sprintf( '#%02x%02x%02x%02x', $red, $green, $blue, $alpha );
	}

	method _typed ($text) {
		return if $updating;
		my $rgba = length $text ? $self->_rgba_of($text) : undef;
		if ( !defined $rgba ) {
			$message->text('Not a color yet: write #rrggbb, #rrggbbaa, rgb(...) or a color name.');
			return;
		}
		$self->_choose( $text, 0 );
		return;
	}

	# Whether the key can take a value; the message says why not.
	method _checked ($spec) {
		try {
			Term::Fabulous::Theme::Document->parse('')->with_setting( $key, $spec );
		}
		catch ($error) {
			$error =~ s/\ATerm::Fabulous::Theme::Document: //;
			$error =~ s/\n\z//;
			$message->text($error);
			return 0;
		}
		return 1;
	}

	# ---------------------------------------------------------------------
	# Leaving
	# ---------------------------------------------------------------------

	field $finished = 0;

	method apply () {
		return $self unless defined $value && length $value && $self->_checked($value);
		$finished = 1;
		$self->close;
		$on_apply->($value);
		return $self;
	}

	method reset () {
		$finished = 1;
		$self->close;
		$on_reset->();
		return $self;
	}

	method cancel () {
		$self->close;
		return $self;
	}

	# Closed without Apply or Reset (Cancel, Escape): the preview shows the
	# theme as it is again.
	method _closed () {
		$on_preview->(undef) unless $finished;
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::ValueDialog - The dialog that edits one
setting in the theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. The dialog opens at the right edge of the screen and does not dim
the screen behind it, so the preview on the left shows the value being
chosen in its true colors. What the dialog offers depends on the
setting:

=over

=item a color slot

A list of the palette's tokens with their colors (and C<none> where the
slot may have no color, C<reverse> for C<button.background.pressed>),
and a color of its own: a field for C<#rrggbb>, C<#rrggbbaa>,
C<rgb(...)>, C<rgba(...)> or a color name, a swatch, and sliders for
red, green, blue and alpha.

=item a palette token

The color of its own only: a token's value must be a color.

=item a style slot

A list of the border styles with a sample of each (only those with
joints for C<tabs.line.style>, and C<none> where the slot may have no
style).

=item C<theme.name>, C<theme.extends>

A field for the name; a list of the built-in themes.

=back

The list shows that it has the keyboard focus with its frame in the
accent color. Every choice shows in the preview at once. C<Apply> (or C<Enter> in the
list or a field) writes the value to the theme as one undo step,
C<Reset to default> removes the setting, and C<Cancel> or C<Escape>
leaves the theme as it was. A value the setting cannot take is not
applied; the line above the buttons says why.

=head1 CONSTRUCTOR

=head2 new

	my $dialog = Term::Fabulous::ThemeEditor::ValueDialog->new(
		key        => 'button.border.color.focused',
		current    => 'accent',
		is_set     => 0,
		default    => 'accent',
		palette    => $theme->palette,
		on_preview => sub ($value) { ... },    # undef: show the theme as it is
		on_apply   => sub ($value) { ... },
		on_reset   => sub () { ... },
		list_rows  => 12,    # the rows of the list of tokens or styles
	);

=head1 METHODS

=head2 key, value

The setting's key and the value chosen now.

=head2 apply, reset, cancel

What the buttons do.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
