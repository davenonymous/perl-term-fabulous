package Term::Fabulous::Widget::Text;

use v5.22;

use Object::Pad 0.825;

our $VERSION = '0.01';


class Term::Fabulous::Widget::Text
	:does(Clay::UI::Text)
	:does(Term::Fabulous::Role::CanParseLayout)
{

	method parse_node($node) {
		for my $node ($node->children->@*) {
			if($node->name eq 'text') {
				$self->text($node->args->[0]->value // '');
			} elsif($node->name eq 'text_color') {
				$self->text_color([Term::Fabulous::Color->new(color => $node->args->[0]->value)->to_rgba]);
			} else {
				$self->parse_generic($node);
			}
		}
	}
}

1;
