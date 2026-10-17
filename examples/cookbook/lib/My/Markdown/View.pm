package My::Markdown::View;

# A document view that knows the block and mark kinds of the Markdown
# reader: it draws with My::Markdown::Look and shows a rule
# (My::Markdown::Rule) as a divider.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::DocumentView;

class My::Markdown::View :isa(Term::Fabulous::Widget::DocumentView) :strict(params) {
	use My::Markdown::Look;
	use Term::Fabulous::Widget::Divider;

	method look_class :common () {
		return 'My::Markdown::Look';
	}

	# boxed puts the divider into the box the view lays out, with the
	# padding the view gives: the indent and the blank row above. A rule
	# has no text for the view to style or search.
	method view_of_rule ( $block, $padding ) {
		return { widget => $self->boxed( $padding, Term::Fabulous::Widget::Divider->new ), text => undef };
	}
}

1;
