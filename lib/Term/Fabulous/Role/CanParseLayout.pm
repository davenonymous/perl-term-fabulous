package Term::Fabulous::Role::CanParseLayout;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Role::CanParseLayout {
	use Term::Fabulous::Check qw(color);

	my %IS_SIMPLE_KIND = map { $_ => 1 } qw(scalar boolean color);

	# The class's KDL properties: name => 'scalar', 'boolean', 'color', or
	# a code reference that parses the property node and applies it.
	method layout_properties;

	# A node inside a widget's block is a child widget when its name starts
	# with an uppercase letter; every other node is a property.
	sub is_widget_node_name ($name) {
		return $name =~ /\A[A-Z]/ ? 1 : 0;
	}

	method apply_layout_node ($node) {
		my %kind_of = $self->_checked_layout_properties;
		my @settings = map { $self->_layout_setting( $_, \%kind_of ) } grep { !is_widget_node_name( $_->name ) } $node->children->@*;
		$self->apply_layout_settings(@settings);
		return $self;
	}

	method _checked_layout_properties () {
		my %kind_of = ref($self)->layout_properties;
		foreach my $name ( sort keys %kind_of ) {
			my $kind = $kind_of{$name};
			next if ref $kind eq 'CODE' || ( defined $kind && $IS_SIMPLE_KIND{$kind} );
			die sprintf( "%s: layout property '%s' is declared as %s; use 'scalar', 'boolean', 'color' or a code reference",
				ref $self, $name, defined $kind ? "'$kind'" : 'undef' );
		}
		return %kind_of;
	}

	# [ name, value ]: the value read from the node, or for a structured
	# property the node itself, for its handler.
	method _layout_setting ( $kid, $kind_of ) {
		my $name = $kid->name;
		my $kind = $kind_of->{$name}
			// die sprintf( "%s: unknown layout property '%s' (known: %s)", ref $self, $name, join( ', ', sort keys %$kind_of ) );
		return [ $name, $kid ]                                            if ref $kind eq 'CODE';
		return [ $name, $self->kdl_boolean($kid) ]                        if $kind eq 'boolean';
		return [ $name, color( $self, $name, $self->kdl_value($kid) ) ] if $kind eq 'color';
		return [ $name, $self->kdl_value($kid) ];
	}

	method apply_layout_settings (@settings) {
		my %kind_of = ref($self)->layout_properties;
		foreach my $setting (@settings) {
			my ( $name, $value ) = @$setting;
			my $handler = $kind_of{$name};
			ref $handler eq 'CODE' ? $self->$handler($value) : $self->$name($value);
		}
		return;
	}

	# The single argument of a boolean property node as 1 or 0: #true,
	# #false, 1 or 0. Any other value dies, so "false" cannot count as true.
	method kdl_boolean ($kid) {
		my $argument = $self->kdl_argument($kid);
		return $argument->as_perl ? 1 : 0 if $argument->is_bool;
		return $argument->as_perl + 0 if $argument->is_number && $argument->as_perl =~ /\A[01]\z/;
		die sprintf( "%s: layout property '%s' must be #true or #false, got %s", ref $self, $kid->name, $argument->is_null ? '#null' : "'" . $argument->as_perl . "'" );
	}

	# The value of a property node: its single argument, or a hashref of its
	# key=value properties.
	method kdl_value ($kid) {
		my @args  = $kid->args->@*;
		my @props = $kid->props->@*;
		return $args[0]->as_perl if @args == 1 && !@props && !$kid->children->@*;
		return { map { $_->[0] => $_->[1]->as_perl } @props } if !@args && @props && !$kid->children->@*;
		die sprintf( "%s: layout property '%s' needs either exactly one argument or key=value properties, and no children", ref $self, $kid->name );
	}

	# The single argument of a property node, as a Text::KDL::XS::Value.
	method kdl_argument ($kid) {
		my @args = $kid->args->@*;
		return $args[0] if @args == 1 && !$kid->props->@* && !$kid->children->@*;
		die sprintf( "%s: layout property '%s' needs exactly one argument", ref $self, $kid->name );
	}

	# The key=value properties of a property node as a hashref; only the
	# given keys are allowed and at least one is required.
	method kdl_properties ( $kid, @allowed ) {
		my $name = $kid->name;
		die sprintf( "%s: layout property '%s' takes key=value properties only", ref $self, $name )
			if $kid->args->@* || $kid->children->@* || !$kid->props->@*;

		my %properties = map { $_->[0] => $_->[1]->as_perl } $kid->props->@*;
		my %is_allowed = map { $_ => 1 } @allowed;
		my @unknown    = grep { !$is_allowed{$_} } sort keys %properties;
		die sprintf( "%s: layout property '%s' does not accept %s (allowed: %s)", ref $self, $name, join( ', ', @unknown ), join( ', ', @allowed ) )
			if @unknown;
		return \%properties;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Role::CanParseLayout - Let a widget class be built from
a KDL layout

=head1 SYNOPSIS

	package My::Panel;
	use v5.24;
	use warnings;
	use feature 'signatures';
	no warnings 'experimental::signatures';
	use Object::Pad 0.825;
	use Term::Fabulous::Widget::Box;

	# Box already composes Term::Fabulous::Role::CanParseLayout.
	# This class only stores what the layout says; drawing the title is
	# up to the class (see examples/custom-widget.pl for a full widget).
	class My::Panel :isa(Term::Fabulous::Widget::Box) :strict(params) {
		field $title       :param :accessor = '';
		field $title_color :param :accessor = [ 255, 255, 255, 255 ];
		field @shortcuts;

		# The properties a layout may set, and how each is read:
		# title "Settings", title_color "#ffcc00", shortcut key="F2" action="save".
		method layout_properties :common () {
			return (
				$class->SUPER::layout_properties,
				title       => 'scalar',
				title_color => 'color',
				shortcut    => \&_parse_shortcut,
			);
		}

		method _parse_shortcut ($kid) {
			my $props = $self->kdl_properties( $kid, qw(key action) );
			push @shortcuts, [ $props->{key}, $props->{action} ];
			return;
		}

		method shortcuts () { return @shortcuts }
	}

	1;

and in a layout:

	use My::Panel as Panel

	Panel "settings" {
		title "Settings"
		title_color "#ffcc00"
		border_width 1
		shortcut key="F2" action="save"
		shortcut key="F10" action="quit"
	}

=head1 DESCRIPTION

L<Term::Fabulous::Layout> builds a widget tree from a KDL document.
For every widget node it constructs the widget with only its id, and
then hands the node to the finished widget:

	my $widget = $class->new( id => $id );
	$widget->apply_layout_node($node);

This role provides L</apply_layout_node>. It reads every property node
of the widget's node as the class declares it in L</layout_properties>,
and then applies them all through L</apply_layout_settings>. Since the
widget is fully constructed by then, a layout sets its properties
exactly like a program calling the accessors after C<new>: every check
and default of the constructor has run, and nothing depends on the
order in which roles and subclasses are built. A class can only be
used in a layout when it composes this role; L<Term::Fabulous::Layout>
checks that when the layout declares the class with C<use>.

All widget classes of Term::Fabulous compose the role (through
L<Term::Fabulous::Widget::Box>, or directly as
L<Term::Fabulous::Widget::Text> does). To make your own widget usable
in layouts, the easiest way is to subclass Box or one of its
subclasses, as in the SYNOPSIS: you inherit the parsing of C<layout>,
C<sizing>, C<padding>, C<border> and the color properties, and only add
your own.

=head2 Property nodes and child nodes

Inside a widget's block, a node whose name starts with an uppercase
letter (C<Text>, C<Box>, ...) is a child widget; L<Term::Fabulous::Layout>
builds it and adds it with C<add_child> after the widget's properties
were applied. Every other node (C<text>, C<_note>, C<1st>, ...) is a
property of the widget. Both sides use the same rule, the function
C<Term::Fabulous::Role::CanParseLayout::is_widget_node_name($name)>.

=head1 REQUIRED METHODS

=head2 layout_properties

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			title     => 'scalar',
			collapsed => 'boolean',
			accent    => 'color',
			shortcut  => \&_parse_shortcut,
		);
	}

A class method (C<:common>) returning the properties a layout may set,
as pairs of a name and how its node is read:

=over

=item C<'scalar'>

The node's value, read with L</kdl_value>: its single argument
(C<title "x">) or a hash reference of its C<key=value> pairs
(C<border_width left=1 right=2>).

=item C<'boolean'>

The node's single argument, read with L</kdl_boolean>: a layout must
write C<#true> or C<#false> (or C<1> and C<0>), so a quoted C<"false">
dies instead of counting as true.

=item C<'color'>

The node's value, read with L</kdl_value> and turned into
C<[r, g, b, a]> with L<Term::Fabulous::Check/color>, so a layout can
write any color string (C<"#ffcc00">, C<"rgb(255, 204, 0)">,
C<"Tomato">).

=item a code reference

A I<structured> property: the code is called as a method with the
property node, C<< $self->$code($kid) >>, and parses and applies the
node itself, typically with the helpers below. Use it for nodes that do
not fit the other kinds, such as an argument together with C<key=value>
pairs.

=back

Each name of the first three kinds is also the name of the accessor
that sets it: the value is applied as C<< $self->name($value) >>, so
the accessor checks it, as for a program. This table is the only way a
layout can set a value: a property that is not in it dies with the list
of known names, so a layout file can neither call arbitrary methods nor
silently ignore a misspelled property. A subclass returns its parent's
table (C<< $class->SUPER::layout_properties >>) plus its own pairs; a
later pair for a name replaces the parent's. Any other kind dies when a
layout is applied.

=head1 METHODS

=head2 apply_layout_node

	$widget->apply_layout_node($node);

Applies the properties of a L<Text::KDL::XS::Node> to the widget and
returns the widget. Called by L<Term::Fabulous::Layout> right after
C<new>. It reads every property node in the order of the layout (child
widget nodes are skipped) into a I<setting>, C<[ $name, $value ]>: the
value read as L</layout_properties> declares it, or for a structured
property the node itself. Then it calls L</apply_layout_settings> with
all of them. Dies when a property is unknown (the message lists the
known names), when a node's shape is wrong, or when an accessor rejects
a value; L<Term::Fabulous::Layout> adds the widget's name and id to the
message.

=head2 apply_layout_settings

	method apply_layout_settings :override (@settings) {
		my %range = map {@$_} grep { $_->[0] =~ /\A(?:min|max)\z/ } @settings;
		$self->set_range(%range) if %range;
		return $self->SUPER::apply_layout_settings( grep { $_->[0] !~ /\A(?:min|max)\z/ } @settings );
	}

Applies the settings in the order given: an accessor call for a simple
property, the handler for a structured one. Override it to apply related
values together, so that a layout may give them in any order:
L<Term::Fabulous::Widget::Slider> sets C<min>, C<max> and C<step>
through one range setter, and L<Term::Fabulous::Widget::Dropdown> sets
its options before the value that picks one of them. Pass the other
settings on to C<SUPER::apply_layout_settings>.

=head1 HELPERS

These are for the handlers of structured properties. C<$kid> is always
a property node (a child node of the widget's node).

=head2 kdl_boolean

	my $flag = $self->kdl_boolean($kid);    # 1 or 0

The single argument of a boolean property node: C<#true> and C<1> give
C<1>, C<#false> and C<0> give C<0>. Anything else dies, including
C<#null>, other numbers and strings such as C<"false">:

	Term::Fabulous::Widget::Checkbox: layout property 'checked' must be #true or #false, got 'false'

=head2 kdl_value

	my $value = $self->kdl_value($kid);

The value of a property node as Perl data: its single argument
(C<border_width 1> gives C<1>, C<title "x"> gives C<'x'>, C<#true>
gives a true value), or, for a node with only C<key=value> pairs, a
hash reference of them (C<border_width left=1 right=2> gives
C<< { left => 1, right => 2 } >>). Dies when the node has several
arguments, both arguments and pairs, nothing at all, or child nodes.

=head2 kdl_argument

	my $argument = $self->kdl_argument($kid);
	die "title needs a string" unless $argument->is_string;
	my $text = $argument->value;

The single argument of a property node as a L<Text::KDL::XS::Value>
object, for when you need to check its type. Dies unless the node has
exactly one argument and no pairs or children.

=head2 kdl_properties

	my $props = $self->kdl_properties( $kid, qw(key action) );

The C<key=value> pairs of a property node as a hash reference of Perl
values. The listed names are the keys allowed; at least one pair must
be present, but not every allowed key. Dies when the node has
arguments or child nodes, has no pairs, or has a key that is not
allowed (the message lists the allowed keys).

=head1 SEE ALSO

L<Term::Fabulous::Layout>, L<Term::Fabulous::Manual/KDL LAYOUT FILES>,
L<Term::Fabulous::Widget::Box/SUBCLASS INTERFACE>,
L<Term::Fabulous::Manual/WRITING YOUR OWN WIDGETS>, L<Text::KDL::XS>,
the example program F<examples/custom-widget.pl>.

=cut
