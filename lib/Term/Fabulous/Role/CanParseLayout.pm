package Term::Fabulous::Role::CanParseLayout;

use v5.22;
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

	method parse_generic ($kid) {
		my $name = $kid->name;
		return if $name =~ /\A[A-Z]/;    # child widgets are built by Term::Fabulous::Layout

		my @known = $self->layout_properties;
		die sprintf( "%s: unknown layout property '%s' (known: %s)", ref $self, $name, join( ', ', sort @known ) )
			unless grep { $_ eq $name } @known;

		my $value = $self->kdl_value($kid);
		$value = [ Term::Fabulous::Color->new( color => $value )->to_rgba ] if $name =~ /_color\z/;
		$self->$name($value);
		return;
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

Term::Fabulous::Role::CanParseLayout - Widgets that can be built from a KDL layout

=head1 SYNOPSIS

	class My::Widget :isa(Term::Fabulous::Widget) :does(Term::Fabulous::Role::CanParseLayout) {
		method layout_properties () { return qw(background_color border_width) }

		method parse_node ($node) {
			$self->parse_generic($_) foreach $node->children->@*;
		}
	}

=head1 DESCRIPTION

L<Term::Fabulous::Layout> builds widgets by calling
C<< $class->new( id => $id, kdl_node => $node ) >>. This role accepts the
C<kdl_node> parameter, calls L</parse_node> with it during construction
and then drops the node.

=head1 REQUIRED METHODS

=head2 parse_node

	method parse_node ($node) { ... }

Receives the widget's L<Text::KDL::XS::Node>. Its children whose names
start with a lowercase letter are property nodes; children starting with
an uppercase letter are child widgets, which L<Term::Fabulous::Layout>
builds. A typical implementation handles structured properties itself
and hands everything else to L</parse_generic>.

=head2 layout_properties

	method layout_properties () { return qw(background_color border_width) }

Returns the names of the accessors L</parse_generic> is allowed to call.
This allowlist is the only way a layout can set a property: any other
name dies, so a layout can neither call arbitrary methods nor silently
ignore a typo.

=head1 METHODS

=head2 parse_generic

	$self->parse_generic($kid);

Sets one property from a property node by calling the accessor of the
same name. Nodes whose name starts with an uppercase letter are skipped
(child widgets). A name not listed by L</layout_properties> dies with
the list of known names. The value comes from L</kdl_value>; for names
ending in C<_color> it is parsed by L<Term::Fabulous::Color> and stored
as an C<[r, g, b, a]> arrayref.

=head2 kdl_value

Value of a property node: its single argument (C<border_width 1>), or,
without arguments, a hashref of its key=value properties
(C<border_width left=1 right=2>). Anything else dies.

=head2 kdl_argument

The single L<Text::KDL::XS::Value> argument of a property node; dies
unless there is exactly one argument and no properties or children.

=head2 kdl_properties

	my $props = $self->kdl_properties( $kid, qw(left right top bottom) );

Hashref of the key=value properties of a property node. Dies on
arguments, children, no properties, or keys outside the allowed list.

=cut
