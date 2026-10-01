package Term::Fabulous::Role::HasBorderStyle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;
use Object::Pad::FieldAttr::Checked;
use Data::Checks qw(Isa Maybe);

role Term::Fabulous::Role::HasBorderStyle {
	use Scalar::Util qw(blessed);
	use Term::Fabulous::Enum::BorderStyle;

	my @SIDES = qw(left right top bottom);

	field $border_style_top    :param :accessor :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_right  :param :accessor :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_bottom :param :accessor :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_left   :param :accessor :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;

	ADJUST :params ( :$border_style = undef ) {
		if ( defined $border_style ) {
			die "Term::Fabulous::Role::HasBorderStyle: border_style must be a Term::Fabulous::Enum::BorderStyle, got "
				. ( ref $border_style || "'$border_style'" )
				unless blessed $border_style && $border_style->isa('Term::Fabulous::Enum::BorderStyle');

			$self->border_style_top($border_style);
			$self->border_style_right($border_style);
			$self->border_style_bottom($border_style);
			$self->border_style_left($border_style);
		}
	}

	# Per-side widths of a Clay border_width (a number for all sides, or a
	# hashref); undef when no side has a width. Clay::UI's HasBorder has
	# already validated the value when it was set.
	sub _border_insets ($border_width) {
		return undef unless defined $border_width;

		my %width_by_side = ref $border_width ? %$border_width : map { $_ => $border_width } @SIDES;
		my %inset         = map { $_ => $width_by_side{$_} // 0 } @SIDES;

		return ( grep { $_ > 0 } values %inset ) ? \%inset : undef;
	}

	# Clay draws borders over the content box, so the border width is added
	# to the padding: borders occupy cells inside the widget and the user's
	# padding starts after them. Clay::UI runs contribute_* methods in
	# alphabetical order, so the name sorts after contribute_layout; that
	# way the inset is applied to the final layout slice. Writes fresh
	# hashes, so the widget's own layout is never modified.
	method contribute_layout_inset ($config) {
		return unless $self->can('border_width') && $self->can('layout');

		my $insets = _border_insets( $self->border_width );
		return unless defined $insets;

		my $layout  = $config->{layout} // {};
		my $padding = $layout->{padding} // {};
		die "Term::Fabulous::Role::HasBorderStyle: layout padding must be a hash reference"
			unless ref $padding eq 'HASH';

		$config->{layout} = {
			%$layout,
			padding => { %$padding, map { $_ => ( $padding->{$_} // 0 ) + $insets->{$_} } @SIDES },
		};
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Role::HasBorderStyle - Terminal border styles and border space

=head1 SYNOPSIS

	my $box = Term::Fabulous::Widget::Box->new(
		border_width => 1,
		border_color => [180, 200, 220, 255],
		border_style => Term::Fabulous::Enum::BorderStyle->Round,   # all four sides
		layout       => { padding => { left => 1, right => 1 } },
	);
	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Thick );

=head1 DESCRIPTION

Adds per-side border styles to a widget and makes its border take
layout space.

=head2 Border styles

C<border_style_top>, C<border_style_right>, C<border_style_bottom> and
C<border_style_left> are constructor parameters and accessors. Each is
undef or a L<Term::Fabulous::Enum::BorderStyle> item; anything else dies
on construction and on accessor writes. The C<border_style> constructor
parameter sets all four sides and must also be a BorderStyle item. A
side with a positive border width but no style is drawn with the
C<Blank> style.

=head2 Border space

Borders occupy cells inside the widget. When the widget has a
C<border_width> (a number for all sides, or a hashref of C<left>,
C<right>, C<top>, C<bottom>; missing sides count as 0 and
C<between_children> is ignored), the width of each side is added to
that side's padding in the Clay configuration. The padding given in
C<layout> therefore starts inside the border, and children never
overlap it. The widget's stored C<layout> is not modified. Clay::UI
validates C<border_width> when it is set: each width is an integer in
0..65535.

=cut
