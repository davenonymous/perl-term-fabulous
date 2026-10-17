package My::Odt::View;

# A document view that knows the block and mark kinds of the OpenDocument
# reader: it draws with My::Odt::Look and shows a title (My::Odt::Title)
# centered, in the title style, with a double rule under it.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::DocumentView;

class My::Odt::View :isa(Term::Fabulous::Widget::DocumentView) :strict(params) {
	use Clay::XS qw(sizing_grow CLAY_ALIGN_X_CENTER CLAY_TEXT_ALIGN_CENTER);
	use My::Odt::Look;
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Divider;

	method look_class :common () {
		return 'My::Odt::Look';
	}

	# The text is the RichText of rich_text_of, so that the view styles it
	# and selects its links like those of every other block. A box of the
	# full width centers it, and its lines are centered when it wraps.
	# boxed puts it and the rule into the box the view lays out, with the
	# padding the view gives: the indent and the blank row above.
	method view_of_title ( $block, $padding ) {
		my $text = $self->rich_text_of($block);
		$text->text_alignment(CLAY_TEXT_ALIGN_CENTER);
		my $centered = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_alignment => { x => CLAY_ALIGN_X_CENTER } } );
		$centered->add_child($text);
		my $rule = Term::Fabulous::Widget::Divider->new( line_style => 'Double' );
		return { widget => $self->boxed( $padding, $centered, $rule ), text => $text };
	}

	# A title is in the title style; its marks and the search matches go
	# over it.
	method spans_of :override ( $index, $look ) {
		my $spans = $self->SUPER::spans_of( $index, $look );
		my $block = $self->document->block($index);
		return $spans unless $block->kind eq 'title';
		return [ [ 0, length $block->text, $look->style('title') ], @$spans ];
	}
}

1;
