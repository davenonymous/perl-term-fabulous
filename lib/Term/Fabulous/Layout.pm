package Term::Fabulous::Layout;

use v5.22;

use Object::Pad 0.825;
use utf8;

use Text::KDL::XS qw(parse_kdl);
use Feature::Compat::Try;

class Term::Fabulous::Layout {
	use Data::Printer;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(:all);

	field $raw :reader;
	field $root_widget :reader;
	field $required_modules :reader = {};

	ADJUST :params (:$string = undef, :$file = undef) {
		if (!defined $string && !defined $file) {
			die "Must provide either a string or a file";
		}
		if (defined $string && defined $file) {
			die "Cannot provide both a string and a file";
		}

		my $content = $string;
		if (defined $file) {
			open my $fh, '<', $file or die "Could not open file '$file': $!";
			local $/;
			$content = <$fh>;
			close $fh;
		}

		try {
			$raw = parse_kdl($content);
		} catch ($e) {
			die "Failed to parse KDL: $e";
		}

		$self->_read_instructions($raw);
		try {
			# TODO: Harden this against malicious input (e.g. by sandboxing the module loading) and do proper loading of modules
			foreach my $module (values %$required_modules) {
				(my $file = $module) =~ s/::/\//g;
				require "$file.pm";
			}
		} catch ($e) {
			die "Failed to load required modules: $e";
		}


	}

	method _read_instructions($raw) {
		$required_modules = {};
		foreach my $node ($raw->nodes->@*) {
			if($node->name eq 'use' && $node->args->@*) {
				if(scalar($node->args->@*) == 1) {
					my $module_name = $node->args->[0]->value;
					$required_modules->{$module_name} = $module_name;
				} elsif(scalar($node->args->@*) == 3 && $node->args->[1]->value eq 'as') {
					my $module_name = $node->args->[0]->value;
					my $alias = $node->args->[2]->value;
					$required_modules->{$alias} = $module_name;
				} else {
					die "Invalid 'use' instruction format in KDL layout";
				}
			}
		}
	}

	method _get_tree_from_kdl($raw) {
		my @candidates;
		foreach my $node ($raw->nodes->@*) {
			if ($required_modules->{$node->name}) {
				push @candidates, $node;
			}
		}

		die "No root widget found in KDL layout" if @candidates == 0;
		die "Multiple root widgets found in KDL layout" if @candidates > 1;
		return $candidates[0];
	}

	method _build_widget($node) {
		# If the first letter of the name is lowercase, it's a layout instruction, not a widget -> die
		if ($node->name =~ /^[a-z]/) {
			die "Expected widget node but found attribute: " . $node->name;
		}

		my $id = undef;
		if ($node->args && scalar($node->args->@*) == 1 && $node->args->[0]->type eq 'string') {
			$id = $node->args->[0]->value;
		}

		my $instance;
		try {
			my $class_name = $required_modules->{$node->name} // die "Unknown widget type: " . $node->name;
			if($class_name->DOES('Term::Fabulous::Role::CanParseLayout')) {
				$instance = $class_name->new(id => $id, kdl_node => $node );
			} else {
				die "Widget class '$class_name' does not implement CanParseLayout role, cannot be constructed from KDL node";
			}
		} catch ($e) {
			die "Failed to create instance of widget '$node->name': $e";
		}

		foreach my $child_node ($node->children->@*) {
			next if $child_node->name =~ /^[a-z]/;

			my $child_widget = $self->_build_widget($child_node);
			$instance->add_child($child_widget);
		}

		return $instance;
	}

	method build() {
		unless(defined $root_widget) {
			try {
				my $root_node = $self->_get_tree_from_kdl($raw);
				$root_widget = $self->_build_widget($root_node);
			} catch ($e) {
				die "Failed to build widget tree: $e";
			}
		}

		return $root_widget;
	}

	method walk_nodes($code) {
		my @nodes = ($raw->nodes->@*);
		while (@nodes) {
			my $node = shift @nodes;
			$code->($node);
			push @nodes, $node->children->@* if $node->children;
		}
	}
}





1;
