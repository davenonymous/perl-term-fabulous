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

	ADJUST {
		my $layout = $self->layout;
		$self->layout( { %$layout, layout_direction => CLAY_TOP_TO_BOTTOM } )
			unless exists $layout->{layout_direction} || exists $layout->{layoutDirection};
		$self->disabled($disabled);

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
		$disabled = $new[0] ? 1 : 0;
		$self->can_focus( $disabled ? 0 : 1 );
		my $ui = $self->ui;
		$ui->interaction->set_focused_widget(undef) if $disabled && defined $ui && $self->is_focused;
		$self->repaint_buttons;
		return $disabled;
	}

	method is_enabled () {
		return !$disabled;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(value disabled can_focus) );
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

Term::Fabulous::Widget::RadioGroup - A group of radio buttons of which one is selected

=head1 SYNOPSIS

	use Term::Fabulous::Widget::RadioGroup;
	use Term::Fabulous::Widget::RadioButton;

	my $size = Term::Fabulous::Widget::RadioGroup->new( value => 'm' );
	$size->add_child( Term::Fabulous::Widget::RadioButton->new( label => $_->[0], value => $_->[1] ) )
		foreach [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ];
	$size->on( Change => sub ($event) { say 'size: ', $event->value; return } );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Box> holding
L<Term::Fabulous::Widget::RadioButton>s, directly or inside other
boxes. At most one of them is selected: the one whose C<value> equals
the group's C<value>. Buttons inside a nested group belong to that
group. Unknown constructor parameters die.

The group, not its buttons, takes the keyboard focus, so Tab moves past
the whole group in one step. While the group has the focus, the
selected button (or the first enabled one, when none is) shows the
focus background. Clicking a button selects it and focuses the group.

The children are laid out from top to bottom unless the C<layout> sets
a C<layout_direction>.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::Box>:

=over

=item C<value>

The value of the selected button; default C<undef>, nothing selected.

=item C<disabled>

Boolean, default 0: a disabled group cannot take the focus, ignores
keys and clicks, and its buttons are painted disabled.

=item C<can_focus>

Boolean, default 1; see L<Clay::UI::Role::Interaction::Focusable>.

=back

=head1 METHODS

=head2 value

	$group->value('l');

Reader and writer. Writing selects the button with that value (none,
when no button has it) and fires no event.

=head2 disabled, is_enabled

Reader and writer of C<disabled>, and its opposite.

=head2 buttons

The radio buttons of the group, in tree order.

=head2 selected_button, cursor_button

The selected button (or C<undef>), and the button the keyboard is on.

=head2 choose

	$group->choose($button);

Selects one of the group's buttons as the user does, firing C<Change>
when the value changes. Dies for a button outside the group. Returns
the group.

=head1 KEYS

Up and Left select the previous enabled button, Down and Right the next
one (wrapping around), Home and End the first and last one. Space and
Enter select the button the keyboard is on when nothing is selected.
Other keys bubble.

=head1 EVENTS

L<Term::Fabulous::Event::Change> on the group when the user selects
another button, with the new C<value>.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Box/KDL PROPERTIES> plus C<value>,
C<disabled> and C<can_focus>:

	use Term::Fabulous::Widget::RadioGroup as RadioGroup
	use Term::Fabulous::Widget::RadioButton as RadioButton

	RadioGroup "size" {
		value "m"
		RadioButton { label "Small"; value "s"; }
		RadioButton { label "Medium"; value "m"; }
	}

=cut
