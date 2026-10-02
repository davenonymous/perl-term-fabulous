package Term::Fabulous::Widget::RadioGroup;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Focusable;
use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::RadioGroup
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(CLAY_TOP_TO_BOTTOM);
	use List::Util qw(first);
	use Scalar::Util qw(blessed refaddr weaken);
	use Term::Fabulous::Event::Change;

	use constant BUTTON_CLASS => 'Term::Fabulous::Widget::RadioButton';

	# Arrow keys: key name => step through the enabled buttons.
	my %STEP_BY_KEY = ( Up => -1, Left => -1, Down => 1, Right => 1 );

	field $value    :param = undef;
	field $disabled :param = 0;

	# The can_focus the group goes back to when it is enabled again.
	field $can_focus_when_enabled;

	ADJUST {
		my $layout = $self->layout;
		$self->layout( { %$layout, layout_direction => CLAY_TOP_TO_BOTTOM } )
			unless exists $layout->{layout_direction} || exists $layout->{layoutDirection};
		$disabled               = $disabled ? 1 : 0;
		$can_focus_when_enabled = $self->can_focus ? 1 : 0;
		$self->_sync_focusability;

		weaken( my $weak_self = $self );
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		my $own      = sub ($event) { defined $weak_self && refaddr( $event->target ) == refaddr($weak_self) };
		$self->on( OnFocus => sub ($event) { $weak_self->repaint_buttons if $own->($event); return $continue } );
		$self->on( OnBlur  => sub ($event) { $weak_self->repaint_buttons if $own->($event); return $continue } );
		$self->on(
			KeyPress => sub ($event) {
				return Clay::UI::Enum::Result->HANDLED if $weak_self->is_enabled && $weak_self->handle_key($event);
				return $continue;
			}
		);
	}

	method value (@new) {
		return $value unless @new;
		$value = $new[0];
		$self->repaint_buttons;
		return $value;
	}

	method disabled (@new) {
		return $disabled unless @new;
		my $disable = $new[0] ? 1 : 0;
		return $disabled if $disable == $disabled;
		$can_focus_when_enabled = $self->can_focus ? 1 : 0 if $disable;
		$disabled               = $disable;
		$self->_sync_focusability;
		$self->repaint_buttons;
		return $disabled;
	}

	# A disabled group cannot take the focus and gives it up; an enabled
	# one gets back the can_focus it had before it was disabled.
	method _sync_focusability () {
		$self->can_focus( $disabled ? 0 : $can_focus_when_enabled );
		my $ui = $self->ui;
		$ui->interaction->set_focused_widget(undef) if $disabled && defined $ui && $self->is_focused;
		return;
	}

	method is_enabled () {
		return !$disabled;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(value disabled can_focus) );
	}

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, qw(disabled can_focus) );
	}

	# The radio buttons of the group in tree order: its descendants, except
	# those of nested groups.
	method buttons () {
		my @buttons;
		my @stack = @{ $self->children };
		while (@stack) {
			my $node = shift @stack;
			next unless blessed $node;
			next if $node->isa(__PACKAGE__);
			push @buttons, $node if $node->isa(BUTTON_CLASS);
			unshift @stack, @{ $node->children } if $node->DOES('Clay::UI::Role::Core::Element');
		}
		return @buttons;
	}

	method holds_value ($candidate) {
		return defined $value && defined $candidate && $candidate eq $value;
	}

	method selected_button () {
		return first { $self->holds_value( $_->value ) } $self->buttons;
	}

	# The button the keyboard is on: the selected one, or else the first
	# enabled one.
	method cursor_button () {
		my $selected = $self->selected_button;
		return $selected if defined $selected && $selected->is_enabled;
		return first { $_->is_enabled } $self->buttons;
	}

	method repaint_buttons () {
		$_->repaint foreach $self->buttons;
		return $self;
	}

	# Selects a button as the user does: fires Change when the value
	# changes.
	method choose ($button) {
		die "Term::Fabulous::Widget::RadioGroup: choose needs one of the group's radio buttons"
			unless blessed $button && grep { refaddr($_) == refaddr($button) } $self->buttons;
		return $self if $self->holds_value( $button->value );
		$self->value( $button->value );
		$self->fire_event( Term::Fabulous::Event::Change->new( value => $value ) );
		return $self;
	}

	method handle_key ($event) {
		my $name = $event->key_name // return 0;
		my $cursor = $self->cursor_button // return 0;

		if ( $name eq 'Space' || $name eq 'Enter' ) {
			$self->choose($cursor);
			return 1;
		}

		my @enabled = grep { $_->is_enabled } $self->buttons;
		my ($index) = grep { refaddr( $enabled[$_] ) == refaddr($cursor) } 0 .. $#enabled;
		my %target  = (
			Home => 0,
			End  => $#enabled,
			( exists $STEP_BY_KEY{$name} ? ( $name => ( $index + $STEP_BY_KEY{$name} ) % @enabled ) : () ),
		);
		return 0 unless exists $target{$name};
		$self->choose( $enabled[ $target{$name} ] );
		return 1;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::RadioGroup - A group of radio buttons of which
one is selected

=head1 SYNOPSIS

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::RadioGroup;
	use Term::Fabulous::Widget::RadioButton;

	my $size = Term::Fabulous::Widget::RadioGroup->new( id => 'size', value => 'm' );
	$size->add_child( Term::Fabulous::Widget::RadioButton->new( label => $_->[0], value => $_->[1] ) )
		foreach [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ];

	$size->on( Change => sub ($event) {
		say 'size: ', $event->value;    # 's', 'm' or 'l'
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	$size->value('l');    # programmatic: selects "Large", fires no Change

=begin html

<p><img src="/screenshots/widget-radio.svg" alt="Radio buttons in a row with Medium chosen, in a column with Express shipping chosen, and a disabled group"></p>

=end html

=head1 DESCRIPTION

A radio group lets the user choose exactly one of several options, all
visible at once. It is a L<Term::Fabulous::Widget::Box> that holds
L<Term::Fabulous::Widget::RadioButton>s, directly or inside other boxes.
The group's C<value> is the value of the selected button; at most one
button is selected (or several, if you gave several buttons the same
value). Buttons inside a nested radio group belong to that inner group.

The group, not its buttons, takes the keyboard focus, so C<Tab> moves
past the whole group in one step, and the arrow keys move the selection.
While the group has the focus, the button the keyboard is on (the
selected one, or the first enabled one when none is selected) is painted
on C<focus_background_color>.

The buttons are laid out from top to bottom unless the C<layout> sets a
C<layout_direction>. Use C<CLAY_LEFT_TO_RIGHT> for buttons side by side:

	use Clay::XS qw(CLAY_LEFT_TO_RIGHT);

	my $size = Term::Fabulous::Widget::RadioGroup->new(
		value  => 'm',
		layout => { layout_direction => CLAY_LEFT_TO_RIGHT, child_gap => 2 },
	);

A radio group is not an L<Term::Fabulous::Widget::Input>; it has its own
C<disabled> and C<value>, and no colors (the buttons have them).

=head1 CONSTRUCTOR

=head2 new

	my $group = Term::Fabulous::Widget::RadioGroup->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::Box> (C<id>,
C<layout>, C<background_color>, C<border_width>, C<border_color>,
C<border_style>, ...) and the ones below. Unknown parameters die.

=over

=item C<value>

A string, a number or C<undef>. Default: C<undef> (no button selected).
The value of the button to select.

=item C<disabled>

A boolean. Default: 0. A disabled group cannot take the focus, ignores
keys and clicks, and all its buttons are painted in their
C<disabled_color>.

=item C<can_focus>

A boolean, stored as 1 or 0. Default: 1. Whether the group can take the
keyboard focus. A disabled group has C<can_focus> 0 whatever was passed;
the value given here is what it gets back when it is enabled (see
L</disabled>).

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Box> (C<add_child>,
C<remove_child>, C<children>, C<layout>, C<on>, ...), plus:

=head2 value

	my $value = $group->value;
	$group->value('l');
	$group->value(undef);    # select nothing

Accessor. Returns the value of the selected button, or C<undef>. Writing
selects the button(s) whose value equals the new value (compared as
strings), or no button when none has it; it repaints the buttons and
fires no C<Change> event. Returns the new value.

=head2 disabled

	my $is_disabled = $group->disabled;
	$group->disabled(1);

Accessor. Returns 1 or 0; writing returns the new value. Writing a true
value disables the group: its buttons are painted disabled, keys and
clicks are ignored, C<can_focus> becomes 0 and the group gives up the
focus if it had it. Writing a false value enables it again and gives
C<can_focus> back the value it had when the group was disabled (or the
C<can_focus> passed to C<new>, when it was constructed disabled).
Writing the value the group already has changes nothing.

=head2 is_enabled

	if ( $group->is_enabled ) { ... }

True when the group is not disabled.

=head2 buttons

	my @buttons = $group->buttons;

The group's radio buttons, in tree order (top to bottom as they were
added), including buttons inside boxes in the group but not buttons
inside a nested radio group.

=head2 selected_button

	my $button = $group->selected_button;

The first button whose value equals the group's value, or C<undef>.

=head2 cursor_button

	my $button = $group->cursor_button;

The button the keyboard is on: the selected button if it is enabled,
otherwise the first enabled button, or C<undef> when there is none.

=head2 choose

	$group->choose($button);

Selects one of the group's buttons as the user does: sets the group's
value to the button's value and fires a C<Change> event, unless that
button is already selected (then nothing happens). Works even while the
group is disabled. Dies if C<$button> is not one of L</buttons>.
Returns the group.

=head2 holds_value

	if ( $group->holds_value('m') ) { ... }

True when the group's value is defined and equals the given value
(compared as strings).

=head2 repaint_buttons

	$group->repaint_buttons;

Repaints all buttons of the group. Called automatically when the value,
the focus or C<disabled> changes. Returns the group.

=head1 KEYS

While the group has the focus and is enabled:

=over

=item C<Up>, C<Left>

Select the previous enabled button. From the first one, wrap around to
the last one. With nothing selected, the "current" button is the first
enabled one, so C<Up> selects the last.

=item C<Down>, C<Right>

Select the next enabled button, wrapping around from the last to the
first. With nothing selected, C<Down> selects the second enabled button.

=item C<Home>, C<End>

Select the first or last enabled button.

=item C<Space>, C<Enter>

Select the button the keyboard is on (see L</cursor_button>). Useful
when nothing is selected yet; on a selected button they change nothing.

=back

Each of these keys is used (it does not bubble), even when it changes
nothing. All other keys, including C<Tab>, bubble to the group's
ancestors. Disabled buttons are skipped. When the group has no enabled
button at all, every key bubbles.

=head1 MOUSE

A click on a button (left button pressed and released over it) selects
it, and the press focuses the group. Clicks are ignored while the group
or the button is disabled.

A click whose press and release both arrive within one frame (1/30
second), such as a quick touchpad tap, is not seen as a click; see
L<Term::Fabulous::Manual/Clicks, hover and press>.

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change>, fired on the group (not on the
button) when the user selects another button, or when L</choose>
selects one; C<< $event->value >> is the new value. Writing C<value>
fires nothing.

=item C<OnFocus>, C<OnBlur>

Fired by Clay::UI when the group gains or loses the focus.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<value>, C<disabled> and C<can_focus> (C<#true> / C<#false>). The radio
buttons are
written as child nodes:

	use Term::Fabulous::Widget::RadioGroup as RadioGroup
	use Term::Fabulous::Widget::RadioButton as RadioButton

	RadioGroup "size" {
		value "m"
		layout direction=right gap=2
		RadioButton { label "Small"; value "s"; }
		RadioButton { label "Medium"; value "m"; }
		RadioButton { label "Large"; value "l"; }
	}

The C<value> may come before the buttons: it is only compared with the
buttons' values when they are painted.

=head1 EXAMPLES

=head2 Enable a text field for the choice "Other"

	my $source = Term::Fabulous::Widget::RadioGroup->new( value => 'web' );
	$source->add_child( Term::Fabulous::Widget::RadioButton->new( label => $_ ) ) foreach qw(web friend other);
	my $other = Term::Fabulous::Widget::TextField->new( disabled => 1, placeholder => 'Where?' );

	$source->on( Change => sub ($event) {
		$other->disabled( $event->value ne 'other' );
		return;
	} );

=head1 SUBCLASS INTERFACE

=head2 handle_key

	class My::RadioGroup :isa(Term::Fabulous::Widget::RadioGroup) {
		method handle_key :override ($event) {
			if ( ( $event->key_name // '' ) eq 'Delete' ) {
				$self->value(undef);    # clear the selection
				return 1;
			}
			return $self->SUPER::handle_key($event);
		}
	}

Called with every L<Term::Fabulous::Event::KeyPress> fired on the group
(or bubbling up to it) while the group is enabled. Returns true when it
used the key, which then stops bubbling, and false to let the key bubble
on. Override it to add keys; call C<SUPER::handle_key> for the keys
above.

=head1 SEE ALSO

L<Term::Fabulous::Widget::RadioButton>, L<Term::Fabulous::Event::Change>,
L<Term::Fabulous::Manual/FORMS AND INPUT WIDGETS>.

=cut
