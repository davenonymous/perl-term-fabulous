package Term::Fabulous::Layout;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class Term::Fabulous::Layout :strict(params) {
	use Encode qw(encode);
	use Feature::Compat::Try;
	use Text::KDL::XS qw(parse_kdl);

	my $MODULE_NAME = qr/\A[A-Za-z_]\w*(?:::\w+)*\z/a;
	my $ALIAS       = qr/\A[A-Z]\w*\z/a;
	my $LAYOUT_ROLE = 'Term::Fabulous::Role::CanParseLayout';

	field $raw :reader;
	field $root_widget :reader;
	field $required_modules :reader = {};
	field $_root_node;

	ADJUST :params ( :$string = undef, :$file = undef ) {
		die "Term::Fabulous::Layout: provide either 'string' or 'file'" if !defined $string && !defined $file;
		die "Term::Fabulous::Layout: provide 'string' or 'file', not both" if defined $string && defined $file;

		my $source = defined $string ? encode( 'UTF-8', $string ) : _read_file($file);
		try {
			$raw = parse_kdl($source);
		}
		catch ($error) {
			die "Term::Fabulous::Layout: failed to parse KDL: $error";
		}

		$required_modules = _use_instructions($raw);
		_load_widget_class( $_, $required_modules->{$_} ) foreach sort keys %$required_modules;
		$_root_node = _root_node( $raw, $required_modules );
	}

	sub _read_file ($path) {
		open my $handle, '<:raw', $path or die "Term::Fabulous::Layout: cannot open '$path': $!";
		local $/;
		my $content = <$handle>;
		close $handle;
		return $content;
	}

	# Maps every alias declared by a top-level 'use' node to its module.
	sub _use_instructions ($document) {
		my %module_by_alias;
		foreach my $node ( $document->nodes->@* ) {
			next unless $node->name eq 'use';
			my ( $alias, $module ) = _parse_use($node);
			die "Term::Fabulous::Layout: widget alias '$alias' is declared twice" if exists $module_by_alias{$alias};
			$module_by_alias{$alias} = $module;
		}
		return \%module_by_alias;
	}

	sub _parse_use ($node) {
		my @args = map { $_->is_string ? $_->value : undef } $node->args->@*;
		my $well_formed = !$node->props->@* && !$node->children->@* && !grep { !defined } @args;

		if ( $well_formed && @args == 1 ) {
			my ($module) = @args;
			_check_module_name($module);
			die "Term::Fabulous::Layout: 'use $module' without 'as' needs a module name starting with an uppercase letter, because the name is also the widget node name"
				unless $module =~ /\A[A-Z]/;
			return ( $module, $module );
		}
		if ( $well_formed && @args == 3 && $args[1] eq 'as' ) {
			my ( $module, undef, $alias ) = @args;
			_check_module_name($module);
			die "Term::Fabulous::Layout: invalid widget alias '$alias'; it must start with an uppercase letter and contain only letters, digits and '_'"
				unless $alias =~ $ALIAS;
			return ( $alias, $module );
		}
		die "Term::Fabulous::Layout: invalid 'use' instruction; expected 'use Module::Name' or 'use Module::Name as Alias'";
	}

	sub _check_module_name ($module) {
		die "Term::Fabulous::Layout: invalid module name '$module' in 'use'" unless $module =~ $MODULE_NAME;
		return;
	}

	sub _load_widget_class ( $alias, $module ) {
		( my $path = "$module.pm" ) =~ s{::}{/}g;
		try {
			require $path;
		}
		catch ($error) {
			die "Term::Fabulous::Layout: cannot load '$module' for widget alias '$alias': $error";
		}
		die "Term::Fabulous::Layout: '$module' (widget alias '$alias') does not compose $LAYOUT_ROLE, so it cannot be built from a layout"
			unless $module->DOES($LAYOUT_ROLE);
		return;
	}

	sub _root_node ( $document, $module_by_alias ) {
		my @widget_nodes;
		foreach my $node ( $document->nodes->@* ) {
			my $name = $node->name;
			next if $name eq 'use';
			die "Term::Fabulous::Layout: unexpected top-level node '$name'; only 'use' instructions and one root widget are allowed"
				unless exists $module_by_alias->{$name};
			push @widget_nodes, $node;
		}
		die "Term::Fabulous::Layout: no root widget found in the layout" unless @widget_nodes;
		die "Term::Fabulous::Layout: multiple root widgets found in the layout (" . join( ', ', map { $_->name } @widget_nodes ) . ")"
			if @widget_nodes > 1;
		return $widget_nodes[0];
	}

	sub _widget_id ($node) {
		my $name = $node->name;
		die "Term::Fabulous::Layout: widget '$name' does not accept key=value properties (got: " . join( ', ', map { $_->[0] } $node->props->@* ) . ")"
			if $node->props->@*;

		my @args = $node->args->@*;
		return undef unless @args;
		die "Term::Fabulous::Layout: widget '$name' takes at most one argument, a string id" unless @args == 1 && $args[0]->is_string;
		return $args[0]->value;
	}

	method _build_widget ($node) {
		my $name  = $node->name;
		my $class = $required_modules->{$name}
			// die "Term::Fabulous::Layout: unknown widget '$name'; declare it with 'use Module::Name as $name'";
		my $id = _widget_id($node);

		my $widget;
		try {
			$widget = $class->new( id => $id, kdl_node => $node );
		}
		catch ($error) {
			die "Term::Fabulous::Layout: cannot build widget '$name'" . ( defined $id ? " \"$id\"" : '' ) . ": $error";
		}

		foreach my $child ( $node->children->@* ) {
			next if $child->name =~ /\A[a-z]/;    # properties, parsed by the widget itself
			die "Term::Fabulous::Layout: widget '$name' cannot contain child widgets (found '" . $child->name . "')"
				unless $widget->can('add_child');
			$widget->add_child( $self->_build_widget($child) );
		}
		return $widget;
	}

	method build () {
		$root_widget //= $self->_build_widget($_root_node);
		return $root_widget;
	}

	method walk_nodes ($code) {
		my @nodes = ( $raw->nodes->@* );
		while (@nodes) {
			my $node = shift @nodes;
			$code->($node);
			push @nodes, $node->children->@* if $node->children;
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Layout - Build a widget tree from a KDL document

=head1 SYNOPSIS

	use Term::Fabulous::Layout;

	my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::Text as Text

	Box "root" {
		layout direction=down gap=1
		sizing width=grow height="percent(50)"
		padding left=1 right=1
		border style=Round color="rgb(20, 140, 56)"
		background_color "#141937"
		border_width 1

		Text "greeting" {
			text "Hello!"
			text_color "rgba(220, 34, 220, 1.0)"
		}
	}
	KDL

	my $root = $layout->build;

=head1 DESCRIPTION

Parses a KDL document (via L<Text::KDL::XS>), loads the widget classes
it declares and builds the widget tree. Every widget class must compose
L<Term::Fabulous::Role::CanParseLayout>; each widget parses its own
property nodes.

=head1 CONSTRUCTOR

=head2 new

	Term::Fabulous::Layout->new( string => $kdl_characters );
	Term::Fabulous::Layout->new( file   => $path );

Exactly one of C<string> (a Perl character string, i.e. decoded text) or
C<file> (read as UTF-8 bytes) is required. Parsing, C<use> validation and
module loading happen here; any problem dies.

=head1 KDL GRAMMAR

=over

=item C<use Module::Name as Alias>

Declares a widget class. C<Module::Name> must be a plain Perl package
name (C<[A-Za-z_]\w*(::\w+)*>), C<Alias> a name starting with an
uppercase letter (C<[A-Z]\w*>), and each alias may be declared once. The
short form C<use Module::Name> uses the full module name as the alias,
so the module name must start with an uppercase letter. The module is
loaded and must compose L<Term::Fabulous::Role::CanParseLayout>. C<use>
takes no key=value properties and no children.

=item Widget nodes

A node whose name is a declared alias builds that widget. It takes an
optional single string argument, the widget id, and no key=value
properties. Its children whose names start with a lowercase letter are
properties of the widget (see the widget classes, for example
L<Term::Fabulous::Widget::Box> and L<Term::Fabulous::Widget::Text>);
all other children are child widgets, which only container widgets
(those with C<add_child>) accept.

=item Top level

Only C<use> nodes and exactly one widget node (the root) are allowed.

=back

=head1 METHODS

=head2 build

Builds the widget tree once and returns the root widget; later calls
return the same tree.

=head2 raw

The parsed L<Text::KDL::XS::Document>.

=head2 required_modules

Hashref of widget alias to module name.

=head2 root_widget

The built root widget, or undef before L</build>.

=head2 walk_nodes

	$layout->walk_nodes( sub ($node) { ... } );

Calls the code reference for every KDL node, breadth first.

=head1 ERRORS

All errors die with a message starting with C<Term::Fabulous::Layout:>
(or with the widget class name for property errors): unreadable file,
KDL syntax errors, malformed C<use> instructions, invalid module names
or aliases, duplicate aliases, modules that fail to load or do not
compose the layout role, unexpected top-level nodes, missing or multiple
root widgets, unknown widget names, malformed widget ids and unknown or
malformed properties.

=head1 SECURITY

A layout names the Perl modules it loads. Only syntactically valid
package names are accepted (no paths), and a module that does not
compose L<Term::Fabulous::Role::CanParseLayout> is rejected, but it has
already been compiled and its top-level code has run by then. A layout
may therefore load and run any installed module. Treat layout files like
code and do not load layouts from untrusted sources.

=cut
