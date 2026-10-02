package Term::Fabulous::Role::CanParseLayout;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Role::CanParseLayout {
	use Term::Fabulous::Color;

	field $kdl_node :param = undef;

	ADJUST {
		if ( defined $kdl_node ) {
			$self->parse_node($kdl_node);
			undef $kdl_node;
		}
	}

	method parse_node ($node);

	# Names of the accessors parse_generic may set from a layout.
	method layout_properties;

	# The names among layout_properties that take #true or #false.
	method boolean_layout_properties;

	# Names of the properties parse_node handles itself (not parse_generic).
	method structured_layout_properties;

	# A node inside a widget's block is a child widget when its name starts
	# with an uppercase letter; every other node is a property.
	sub is_widget_node_name ($name) {
		return $name =~ /\A[A-Z]/ ? 1 : 0;
	}

	method parse_generic ($kid) {
		my $name = $kid->name;
		return if is_widget_node_name($name);    # child widgets are built by Term::Fabulous::Layout

		my @settable = $self->layout_properties;
		die sprintf( "%s: unknown layout property '%s' (known: %s)", ref $self, $name, join( ', ', sort @settable, $self->structured_layout_properties ) )
			unless grep { $_ eq $name } @settable;

		my $value = ( grep { $_ eq $name } $self->boolean_layout_properties ) ? $self->kdl_boolean($kid) : $self->kdl_value($kid);
		$value = [ Term::Fabulous::Color->new( color => $value )->to_rgba ] if $name =~ /_color\z/;
		$self->$name($value);
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

		# Simple "name value" properties: title "Settings", title_color "#ffcc00".
		method layout_properties :override () {
			return ( $self->SUPER::layout_properties, qw(title title_color) );
		}

		# A structured property: shortcut key="F2" action="save".
		method parse_property :override ($kid) {
			return $self->SUPER::parse_property($kid) unless $kid->name eq 'shortcut';
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
For every widget node it calls the widget class's constructor with two
extra parameters:

	$class->new( id => $id, kdl_node => $node );

This role accepts the C<kdl_node> parameter. During construction it
calls L</parse_node> with the node, so the widget can read its
properties from it, and then forgets the node. A class can only be
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
builds it and adds it with C<add_child> after the widget itself has
been constructed. Every other node (C<text>, C<_note>, C<1st>, ...) is
a property of the widget and is handled by the widget's
L</parse_node>. Both sides use the same rule, the function
C<Term::Fabulous::Role::CanParseLayout::is_widget_node_name($name)>.
Properties are processed in the order they appear in the layout.

=head1 CONSTRUCTOR PARAMETERS

=over

=item C<kdl_node>

A L<Text::KDL::XS::Node>, or C<undef> (the default). Passed by
L<Term::Fabulous::Layout>; you do not pass it yourself.

=back

=head1 REQUIRED METHODS

A class composing the role directly must provide these four methods.
Subclasses of L<Term::Fabulous::Widget::Box> already have them and
only override them.

=head2 parse_node

	method parse_node ($node) {
		$self->parse_generic($_) foreach $node->children->@*;
		return;
	}

Called once during construction with the widget's
L<Text::KDL::XS::Node>. A typical implementation looks at every child
node of C<$node>, handles the properties that need special treatment
itself, and passes everything else to L</parse_generic> (which skips
child widget nodes). Die with a clear message on anything invalid; the
error is reported with the widget's name and id.

=head2 layout_properties

	method layout_properties () {
		return qw(background_color border_width title);
	}

Returns the names of the properties that L</parse_generic> may set.
Each name is also the name of the accessor that sets it. This list is
the only way a layout can set a value through C<parse_generic>: a
property that is not in it dies (with the list of known names), so a
layout file can neither call arbitrary methods nor silently ignore a
misspelled property.

=head2 boolean_layout_properties

	method boolean_layout_properties () {
		return qw(collapsed);
	}

Returns the names among L</layout_properties> that take a boolean.
L</parse_generic> reads them with L</kdl_boolean>, so a layout must
write C<#true> or C<#false> (or C<1> and C<0>); a quoted C<"false">
dies instead of counting as true. Return an empty list when there are
none.

=head2 structured_layout_properties

	method structured_layout_properties () {
		return qw(shortcut);
	}

Returns the names of the property nodes that L</parse_node> (or a
C<parse_property> override) handles itself, without
L</parse_generic>. They are only used for the error message of an
unknown property, so that its list of known names is complete. Return
an empty list when there are none.

=head1 METHODS

These helpers are for implementations of L</parse_node> and
C<parse_property>. C<$kid> is always a property node (a child node of
the widget's node).

=head2 parse_generic

	$self->parse_generic($kid);

Sets one simple property: for a node C<name value>, it calls
C<< $self->name($value) >>. The value is read with L</kdl_value>, so it
is either the node's single argument or a hash reference of its
C<key=value> pairs; a name listed by L</boolean_layout_properties> is
read with L</kdl_boolean> instead. For names ending in C<_color>, the
value is parsed with L<Term::Fabulous::Color> first and passed as an
C<[r, g, b, a]> array reference, so layouts can use color strings
(C<"#ffcc00">, C<"rgb(255, 204, 0)">, ...).

Nodes whose name starts with an uppercase letter (child widgets) are
skipped. Dies when the name is not listed by L</layout_properties>
(the message lists those names and L</structured_layout_properties>),
when the node's shape is wrong (see L</kdl_value>) or when the accessor
rejects the value.

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
