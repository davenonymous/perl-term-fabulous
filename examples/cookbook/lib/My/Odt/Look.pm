package My::Odt::Look;

# The styles of My::Odt::View: those of every document view, plus the
# two kinds the OpenDocument reader adds, underlined text and the title.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Look;

class My::Odt::Look :isa(Term::Fabulous::Document::Look) :strict(params) {

	# Colors are palette tokens of the theme, so that the title follows a
	# switch to another theme.
	method recipes :common () {
		return (
			$class->SUPER::recipes,
			underline => { words => 'underline' },
			title     => { words => 'bold', color => 'accent' },
		);
	}
}

1;
