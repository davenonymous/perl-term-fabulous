package Term::Fabulous::Widget::Box;

use v5.22;

use Object::Pad 0.825;

our $VERSION = '0.01';


class Term::Fabulous::Widget::Box
	:isa(Term::Fabulous::Widget)
	:does(Term::Fabulous::Role::CanParseLayout)
{
	use Clay::XS qw(:all);

	method _parse_sizing_value($value) {
		# sizing_fit sizing_grow sizing_fixed sizing_percent
		if ($value eq 'grow') {
			return sizing_grow();

		} elsif ($value eq 'fit') {
			return sizing_fit();

		} elsif ($value eq 'percent') {
			die "Percent sizing requires a value, e.g. percent(50)";
		} elsif ($value =~ /^percent\((\d+)\)$/) {
			return sizing_percent($1);

		} elsif ($value eq 'fixed') {
			die "Fixed sizing requires a value, e.g. fixed(10)";
		} elsif ($value =~ /^fixed\((\d+)\)$/) {
			return sizing_fixed($1);

		} else {
			die "Invalid sizing value: $value";
		}
	}

	method _parse_layout_direction($value) {
		my %directions = (
			top_to_bottom    => CLAY_TOP_TO_BOTTOM,
			ttb              => CLAY_TOP_TO_BOTTOM,
			down             => CLAY_TOP_TO_BOTTOM,
			left_to_right    => CLAY_LEFT_TO_RIGHT,
			ltr              => CLAY_LEFT_TO_RIGHT,
			right            => CLAY_LEFT_TO_RIGHT,
		);
		return $directions{$value} // die "Invalid layout direction: $value";
	}

	method _parse_border_style($value) {
		return Term::Fabulous::Enum::BorderStyle->from_name($value) // die "Invalid border style: $value";
	}

	method parse_node($node) {
		foreach my $kid ($node->children->@*) {
			next unless ($kid->name =~ /^[a-z]/);

			if($kid->name eq 'layout') {
				if(my $direction = $kid->prop('direction')) {
					$self->layout->{layout_direction} = $self->_parse_layout_direction($direction->value);
				}
				if(my $child_gap = $kid->prop('child_gap') // $kid->prop('gap')) {
					$self->layout->{child_gap} = $child_gap->value;
				}

			} elsif($kid->name eq 'border') {
				if(my $style = $kid->prop('style')) {
					my $all_sides = $self->_parse_border_style($style->value);
					$self->border_style_top($all_sides);
					$self->border_style_right($all_sides);
					$self->border_style_bottom($all_sides);
					$self->border_style_left($all_sides);
				}
				if(my $style = $kid->prop('style-top')) {
					$self->border_style_top($self->_parse_border_style($style->value));
				}
				if(my $style = $kid->prop('style-right')) {
					$self->border_style_right($self->_parse_border_style($style->value));
				}
				if(my $style = $kid->prop('style-bottom')) {
					$self->border_style_bottom($self->_parse_border_style($style->value));
				}
				if(my $style = $kid->prop('style-left')) {
					$self->border_style_left($self->_parse_border_style($style->value));
				}

				if(my $color = $kid->prop('color')) {
					$self->border_color([Term::Fabulous::Color->new(color => $color->value)->to_rgba]);
				}

			} elsif($kid->name eq 'sizing') {
				if(my $width = $kid->prop('width')) {
					$self->layout->{sizing}->{width} = $self->_parse_sizing_value($width->value);
				}
				if(my $height = $kid->prop('height')) {
					$self->layout->{sizing}->{height} = $self->_parse_sizing_value($height->value);
				}

			} elsif($kid->name eq 'padding') {
				$self->layout->{padding} = $kid->as_data->{props};
			} else {
				$self->parse_generic($kid);
			}
		}
	}
}

1;
