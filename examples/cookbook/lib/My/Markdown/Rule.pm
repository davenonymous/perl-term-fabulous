package My::Markdown::Rule;

# A horizontal rule, a block kind that the built-in kinds of
# Term::Fabulous::Document::Block lack. My::Markdown::View shows it as a
# divider across the view.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

class My::Markdown::Rule :isa(Term::Fabulous::Document::Block) :strict(params) {

	ADJUST {
		die "My::Markdown::Rule: a rule has no text" if length $self->text;
	}

	# The view builds a block of kind "rule" with its view_of_rule.
	method kind () {
		return 'rule';
	}

	# The rows the block takes, which the view asks for before it lays the
	# block out, to size its scrollbar: one for the divider.
	method body_rows :override ($columns) {
		return 1;
	}
}

1;
