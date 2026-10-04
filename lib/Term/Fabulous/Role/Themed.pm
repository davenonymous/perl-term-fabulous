package Term::Fabulous::Role::Themed;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Role::Themed {
	use Term::Fabulous::Check qw(describe);
	use Term::Fabulous::Theme;

	# The family of the class (a class method): button, input, ...
	method theme_family;

	# The themed parameters of the class (a class method), as
	# name => [ slot, state ]; a subclass adds its own to its parent's.
	method themed_params;

	# The state the widget shows now, from the states its family's slots
	# have: 'normal', 'focused', ...
	method look_state;

	# Called by reset_look for a parameter whose explicit value the class
	# keeps outside the role (a Clay::UI field, say): clears it.
	method look_reset ($name);

	# The class names of the widget (an array reference), which select the
	# theme's variants.
	method classes;

	# Explicit values, under the parameter name; the theme fills the rest.
	field %_override;

	# The looks of the family for the widget's classes, from the theme of
	# the UI the widget is in, as of a theme generation.
	field $_look_table;
	field $_look_generation = -1;

	# name => [ slot, state ] and "slot.state" => name per class, checked
	# against the family once.
	my %themed_params_of;
	my %param_of_look_of;

	sub _themed_params_of ($class) {
		return $themed_params_of{$class} //= do {
			my %params = $class->themed_params;
			my $family = $class->theme_family;
			foreach my $name ( sort keys %params ) {
				my $mapping = $params{$name};
				die "$class: themed parameter '$name' must map to [ slot, state ], got " . describe($mapping)
					unless ref $mapping eq 'ARRAY' && @$mapping == 2;
				my ( $slot, $state ) = @$mapping;
				die "$class: themed parameter '$name' maps to $slot" . ( $state eq 'normal' ? '' : ".$state" ) . ", which the family $family does not have"
					unless Term::Fabulous::Theme::has_slot( $family, $slot, $state );
			}
			\%params;
		};
	}

	sub _param_of_look_of ($class) {
		return $param_of_look_of{$class} //= do {
			my $params       = _themed_params_of($class);
			my %name_of_look = map { join( '.', @{ $params->{$_} } ) => $_ } keys %$params;
			\%name_of_look;
		};
	}

	# The looks of the widget, fetched again after a theme change.
	method _look_table () {
		my $generation = Term::Fabulous::Theme::generation();
		return $_look_table if $_look_generation == $generation;

		my $ui    = $self->ui;
		my $theme = defined $ui && $ui->can('theme') ? $ui->theme : Term::Fabulous::Theme->default;
		$_look_table      = $theme->look_table( ref($self)->theme_family, $self->classes );
		$_look_generation = $generation;
		return $_look_table;
	}

	# Forgets the fetched looks of the widget and of everything below it,
	# for when the widget joins or leaves a tree; a widget that copies
	# looks into its parts takes them again from the UI it is in now.
	method forget_looks () {
		$_look_generation = -1;
		$self->theme_changed if $self->can('theme_changed') && defined $self->ui;
		return unless $self->can('layout_children');
		$_->forget_looks foreach grep { $_->DOES(__PACKAGE__) } @{ $self->layout_children };
		return;
	}

	# The theme's value of a slot in a state: a state the theme gives no
	# value of its own looks like the normal state.
	method look ( $slot, $state = 'normal' ) {
		my $table = $_look_generation == Term::Fabulous::Theme::generation() ? $_look_table : $self->_look_table;
		return exists $table->{"$slot.$state"} ? $table->{"$slot.$state"} : $table->{"$slot.normal"};
	}

	# The value a slot has in a state, given what it has in the normal
	# state (an explicit value or the theme's): the explicit value of the
	# state's parameter, else the theme's own value for the state, else
	# the normal value.
	method themed_value ( $slot, $state, $normal_value ) {
		return $normal_value if $state eq 'normal';
		my $name = _param_of_look_of( ref $self )->{"$slot.$state"};
		return $_override{$name} if defined $name && exists $_override{$name};
		my $table = $_look_generation == Term::Fabulous::Theme::generation() ? $_look_table : $self->_look_table;
		return exists $table->{"$slot.$state"} ? $table->{"$slot.$state"} : $normal_value;
	}

	# What a themed parameter is worth: its explicit value, or the theme's.
	method look_value ($name) {
		return $_override{$name} if exists $_override{$name};
		my $mapping = _themed_params_of( ref $self )->{$name} // die ref($self) . ": '$name' is not a themed parameter (known: " . join( ', ', sort keys %{ _themed_params_of( ref $self ) } ) . ")";
		return $self->look(@$mapping);
	}

	method has_look_override ($name) {
		return exists $_override{$name} ? 1 : 0;
	}

	# Takes the named constructor parameters out of $params (an
	# ADJUSTPARAMS hash) and gives each one to its accessor, which checks
	# and records it; a parameter left out stays with the theme.
	method adopt_look_params ( $params, @names ) {
		foreach my $name ( grep { exists $params->{$_} } @names ) {
			$self->$name( delete $params->{$name} );
		}
		return;
	}

	# Records an explicit value (already checked by the caller).
	method set_look ( $name, $value ) {
		$_override{$name} = $value;
		$self->mark_changed;
		return $value;
	}

	method reset_look (@names) {
		my $params = _themed_params_of( ref $self );
		foreach my $name (@names) {
			die ref($self) . ": reset_look does not know " . describe($name) . " (known: " . join( ', ', sort keys %$params ) . ")" unless defined $name && !ref $name && exists $params->{$name};
			delete $_override{$name};
			$self->look_reset($name);
		}
		$self->mark_changed;
		return $self;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Role::Themed - How a widget reads its colors and
border styles from the theme

=head1 SYNOPSIS

	use Object::Pad 0.825;

	class My::Gauge :isa(Term::Fabulous::Widget::Display) :strict(params) {
		field $fill_color :param = undef;    # undef: the theme's progress.color

		method theme_family :common () { return 'progress' }

		method themed_params :common () {
			return ( $class->SUPER::themed_params, fill_color => [ 'color', 'normal' ] );
		}

		ADJUST {
			$self->set_look( fill_color => cell_color( $self, fill_color => $fill_color ) ) if defined $fill_color;
		}

		method fill_color (@new) {
			return $self->look_value('fill_color') unless @new;
			return $self->set_look( fill_color => cell_color( $self, fill_color => $new[0] ) );
		}

		method paint () {
			my $fill = $self->color_attr( $self->look_value('fill_color') );
			...
		}
	}

	$gauge->fill_color('#ff8800');    # explicit, wins over the theme
	$gauge->reset_look('fill_color');  # back to the theme

=head1 DESCRIPTION

Every Term::Fabulous widget composes this role (through
L<Term::Fabulous::Widget> or L<Term::Fabulous::Widget::Text>). It
holds the widget's I<explicit> looks, the colors and border styles the
program set, and reads everything else from the
L<Term::Fabulous::Theme> of the UI the widget is in, for the widget's
I<family> and I<classes>. A widget in no UI reads the default theme.

The looks are fetched once and kept until the theme changes
(L<Term::Fabulous::Theme/generation>) or the widget joins or leaves a
tree, so reading a look while a frame is drawn costs one hash lookup.

This page is for widget authors; L<Term::Fabulous::Manual::Looks/THEMES>
explains themes to users, and
L<Term::Fabulous::Manual::CustomWidgets> shows the role in a widget.

=head1 CLASS METHODS A WIDGET DEFINES

=head2 theme_family

	method theme_family :common () { return 'input' }

The family whose slots the widget draws with, one of
L<Term::Fabulous::Theme/Families, slots and states>. A subclass
inherits its parent's family unless it defines its own.

=head2 themed_params

	method themed_params :common () {
		return ( $class->SUPER::themed_params, accent_color => [ 'accent', 'normal' ], focus_background_color => [ 'background', 'focused' ] );
	}

The parameters whose value the theme supplies when the program gives
none: C<< name => [ slot, state ] >>. The slot and state must exist in
the family; the first use of the class checks that and dies otherwise.
A subclass returns its parent's list plus its own.

=head1 METHODS A WIDGET DEFINES

=head2 look_state

	method look_state () { return $self->is_focused ? 'focused' : 'normal' }

The state the widget shows now: C<normal>, or a state its family's
slots have. L<Term::Fabulous::Widget> answers C<normal>; a widget with
states overrides it and decides the precedence (a disabled button is
disabled, not focused).

=head2 look_reset

	method look_reset ($name) { ... }

Called by L</reset_look> for every parameter name, after the role
dropped its explicit value. A class that keeps the explicit value of a
parameter outside the role (L<Term::Fabulous::Widget> keeps
C<background_color> and C<border_color> in the Clay::UI roles) clears
it here; the others do nothing.

=head2 classes

The widget's class names as an array reference; see
L<Term::Fabulous::Widget/classes>.

=head2 theme_changed

	method theme_changed () { $self->request_prepare; return }

Optional. Called on every widget of a UI's tree, top down, when the
UI is created and when its theme is set to another one, and on a
widget (and everything below it) when it joins a tree that is in a
UI. Most widgets need none, because they read their looks when a
frame is drawn. A widget that copies looks into the parts it builds
(L<Term::Fabulous::Widget::Table> colors its cells, its pager and its
scrollbar) builds or colors them again here.

=head1 METHODS

=head2 look

	my $color = $self->look('accent');
	my $color = $self->look( 'border.color', 'focused' );

The theme's value of a slot of the widget's family in a state
(C<normal> by default), for the widget's classes: C<[r, g, b, a]>, a
L<Term::Fabulous::Enum::BorderStyle> item, C<'reverse'> or C<undef>
for none. A state the theme gives no value of its own looks like the
normal state.

=head2 look_value

	my $color = $self->look_value('accent_color');

What a themed parameter is worth: the explicit value when the program
set one, else the theme's value of the slot and state the parameter
maps to. Dies for a name that is not in L</themed_params>.

=head2 themed_value

	my $background = $self->themed_value( 'background', $state, $explicit // $self->look('background') );

The value of a slot in a state, given the value of the normal state:
the explicit value of the parameter mapped to that state (such as
C<focus_background_color>), else the theme's own value for the state,
else the normal value. This is how an explicit normal color stays in
states the theme does not color differently.

=head2 adopt_look_params

	ADJUSTPARAMS ($params) {
		$self->adopt_look_params( $params, qw(accent_color focus_background_color) );
	}

For the constructor: takes the named parameters out of the
C<ADJUSTPARAMS> hash and passes each one that was given to the
accessor of the same name, which checks and records it. A parameter
the program left out stays with the theme. Themed parameters are not
declared as fields, so that "not given" and "given as C<undef>" (for
a look that C<undef> switches off) stay apart.

=head2 set_look

	$self->set_look( accent_color => $checked_color );

Records an explicit value, already validated by the caller, and marks
the widget changed. Returns the value.

=head2 has_look_override

	if ( $self->has_look_override('accent_color') ) { ... }

Whether the program set the parameter explicitly.

=head2 reset_look

	$widget->reset_look('accent_color');
	$widget->reset_look( 'border_color', 'background_color' );

Drops the explicit values of the named parameters, so the theme
supplies them again, and marks the widget changed. Returns the widget.
Dies for a name that is not in L</themed_params>.

=head2 forget_looks

	$widget->forget_looks;

Drops the fetched looks of the widget and of every widget below it;
the next read fetches them from the theme of the UI the widget is in
now. Term::Fabulous calls it when a widget joins or leaves a tree.

=head1 SEE ALSO

L<Term::Fabulous::Theme>, L<Term::Fabulous::Widget>,
L<Term::Fabulous::Manual::CustomWidgets>.

=cut
