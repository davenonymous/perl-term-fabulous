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

Term::Fabulous::Role::HasBorderStyle - Border glyphs per side, and
borders that take space

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Enum::BorderStyle;

	my $box = Term::Fabulous::Widget::Box->new(
		border_width => 1,
		border_color => [ 180, 200, 220, 255 ],
		border_style => Term::Fabulous::Enum::BorderStyle->Round,    # all four sides
		layout       => { padding => { left => 1, right => 1 } },    # inside the border
	);

	# Change one side later:
	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Double );

=head1 DESCRIPTION

This role is part of every L<Term::Fabulous::Widget> (and therefore of
every Box, Button, ScrollBox, Canvas and input widget). It does two
things:

=over

=item 1.

It adds the border style parameters and accessors, which choose the
characters a border is drawn with (Clay itself only knows border
widths and colors).

=item 2.

It makes borders take space in the layout, so that the content never
overlaps them.

=back

You do not compose this role yourself; it is already part of the
widget classes. To draw a border, a widget needs a C<border_width>
(from L<Clay::UI::Role::Style::HasBorder>) and normally a border style
and a C<border_color>:

	border_width => 1,
	border_style => Term::Fabulous::Enum::BorderStyle->Round,
	border_color => [ 180, 200, 220, 255 ],

=head2 How a border is drawn

=over

=item * A side is drawn when its border width is greater than 0. It is
always one cell thick, whatever the width; see L</Border space> for
what a larger width does.

=item * The top and bottom sides are drawn over the whole width of the
widget and own the corners: a corner glyph appears where the top or
bottom row meets a drawn left or right side, taken from the style of
the top or bottom side. The left and right sides fill the rows between.

=item * A side that has a width but no style is drawn with the C<Blank>
style, that is with spaces.

=item * The glyphs have the C<border_color> (the terminal's default
foreground color when none is set). Their background is usually the
widget's background; some styles, such as C<Block>, C<Inner>, C<Panel>
or C<Tab>, use the background outside the widget or reverse video for
some glyphs so that they blend with the surroundings. See
L<Term::Fabulous::Enum::BorderStyle> for the styles.

=back

=head2 Border space

Clay, the layout engine, would draw borders on top of the content. This
role prevents that: when a widget has a C<border_width>, the width of
every side is added to that side's padding before Clay lays the widget
out. The effect is:

=over

=item * The content starts inside the border, and the C<padding> in the
widget's C<layout> is extra space between the border and the content.
In the SYNOPSIS the text starts two cells right of the left edge: one
for the border, one for the padding.

=item * A width larger than 1 still draws a one-cell border, followed
by empty cells: C<border_width => 2> is a border plus one cell of
padding.

=item * A widget with C<fit> sizing grows by the border.

=back

C<border_width> is a number for all four sides, or a hash reference
C<< { left => ..., right => ..., top => ..., bottom => ... } >> in which
missing sides count as 0. Each width must be an integer from 0 to 65535
(checked by Clay::UI when it is set). Clay's C<between_children> key is
accepted but has no effect in Term::Fabulous. The widget's stored
C<layout> is not modified; only the configuration handed to Clay is.

=head1 CONSTRUCTOR PARAMETERS

These parameters are accepted by the C<new> of every widget class that
composes the role. Unknown values die.

=over

=item C<border_style>

A L<Term::Fabulous::Enum::BorderStyle> item, for example
C<< Term::Fabulous::Enum::BorderStyle->Round >>; it sets the style of
all four sides. Default: none. Anything else, including the name of a
style as a string, dies. To use a name, convert it:
C<< Term::Fabulous::Enum::BorderStyle->from_name('Round') >>.

=item C<border_style_top>

=item C<border_style_right>

=item C<border_style_bottom>

=item C<border_style_left>

C<undef> or a L<Term::Fabulous::Enum::BorderStyle> item for one side.
Default: C<undef>. These are ignored when C<border_style> is passed as
well (see L</CAVEATS>).

=back

=head1 METHODS

There is no C<border_style> accessor; to change all sides after
construction, call the four side accessors.

=head2 border_style_top

	my $style = $box->border_style_top;
	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the top side. Takes and returns C<undef> or
a L<Term::Fabulous::Enum::BorderStyle> item; anything else dies. The
change shows in the next frame.

=head2 border_style_right

	$box->border_style_right( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the right side, as L</border_style_top>.

=head2 border_style_bottom

	$box->border_style_bottom( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the bottom side, as L</border_style_top>.

=head2 border_style_left

	$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the left side, as L</border_style_top>.

=head2 contribute_layout_inset

	$widget->contribute_layout_inset( \%config );

Called by Clay::UI while it builds the configuration of a frame; it
adds the border widths to the padding as described in
L</Border space>. You do not call it yourself.

=head1 CAVEATS

When both C<border_style> and a side parameter such as
C<border_style_left> are passed to C<new>, C<border_style> wins and the
side parameter is ignored. Set the side with its accessor after
construction instead:

	my $box = Term::Fabulous::Widget::Box->new(
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Solid,
	);
	$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Thick );

In a KDL layout this works directly: C<border style=Solid style-left=Thick>
(see L<Term::Fabulous::Widget::Box/KDL PROPERTIES>).

=head1 SEE ALSO

L<Term::Fabulous::Enum::BorderStyle>, L<Term::Fabulous::Manual/BORDERS>,
L<Term::Fabulous::Widget>, L<Clay::UI::Role::Style::HasBorder>, the
example program F<examples/border-showcase.pl>, which shows every style.

=cut
