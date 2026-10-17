package My::Odt::Title;

# The title of a document, a block kind that the built-in kinds of
# Term::Fabulous::Document::Block lack. My::Odt::View shows it centered,
# with a double rule under it.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

class My::Odt::Title :isa(Term::Fabulous::Document::Block) :strict(params) {

	# The view builds a block of kind "title" with its view_of_title.
	method kind () {
		return 'title';
	}

	# The rows of the wrapped text, and one for the rule. The view asks
	# for them before it lays the title out, to size its scrollbar.
	method body_rows :override ($columns) {
		return $self->SUPER::body_rows($columns) + 1;
	}
}

1;
