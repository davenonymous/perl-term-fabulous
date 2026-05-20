package Term::Fabulous::Role::HasBorderStyle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

role Term::Fabulous::Role::HasBorderStyle {

	field $border_style_top    :param :accessor = undef;
	field $border_style_right  :param :accessor = undef;
	field $border_style_bottom :param :accessor = undef;
	field $border_style_left   :param :accessor = undef;

	ADJUST :params ( :$border_style = undef ) {
		if($border_style) {
			$self->border_style_top    ( $border_style );
			$self->border_style_right  ( $border_style );
			$self->border_style_bottom ( $border_style );
			$self->border_style_left   ( $border_style );
		}
	}

}

1;
