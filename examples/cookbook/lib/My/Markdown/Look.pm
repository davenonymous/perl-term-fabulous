package My::Markdown::Look;

# The styles of My::Markdown::View: those of every document view, plus
# the mark kind the Markdown reader adds, the alternative text of an
# image.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Look;

class My::Markdown::Look :isa(Term::Fabulous::Document::Look) :strict(params) {

	# Colors are palette tokens of the theme, so that the style follows a
	# switch to another theme.
	method recipes :common () {
		return (
			$class->SUPER::recipes,
			image => { words => 'italic', color => 'text_muted' },
		);
	}
}

1;
