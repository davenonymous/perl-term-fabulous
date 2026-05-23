package Term::Fabulous::Role::CanParseLayout;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

role Term::Fabulous::Role::CanParseLayout {
	field $kdl_node :param = undef;

	ADJUST {
		if(defined $kdl_node) {
			$self->parse_node($kdl_node);
		}
	}

	method parse_node ($node);

	method parse_generic ($kid) {
		my $name = $kid->name;
		return if $name =~ /^[A-Z]/; # Ignore child widgets
		return unless $self->can($name);

		if($kid->args && scalar($kid->args->@*) == 1) {
			if($name =~ m/color/i) {
				$self->$name([Term::Fabulous::Color->new(color => $kid->args->[0]->value)->to_rgba]);
			} else {
				$self->$name($kid->args->[0]->value);
			}
		} elsif($kid->as_data->{props}) {
			$self->$name($kid->as_data->{props});
		} else {
			warn "Invalid property format for '" . $kid->name . "'";
		}
	}
}

1;
