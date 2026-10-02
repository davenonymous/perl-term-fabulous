package Term::Fabulous::Render::Border;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Clip;

role Term::Fabulous::Render::Border :does(Term::Fabulous::Render::Clip) {
	use List::Util qw(min max);
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);    # checks truecolor support first
	use Term::Fabulous::Termbox qw(TB_DEFAULT TB_REVERSE);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Render::Geometry qw(cell_rect);

	method set_cell;

	# Attributes for a border cell from its location code, following
	# Textual's get_box styles: 0 = border color on the widget's background,
	# 1 = border color on the parent's background, 2 and 3 are 1 and 0 in
	# reverse video. Reverse video swaps terminal-default colors correctly,
	# which an explicit fg/bg swap of TB_DEFAULT would not.
	sub _location_attrs ( $location, $border, $inner, $outer ) {
		return ( $border, $inner ) if $location == 0;
		return ( $border, $outer ) if $location == 1;
		return ( $border | TB_REVERSE, $outer ) if $location == 2;
		return ( $border | TB_REVERSE, $inner ) if $location == 3;
		die "Term::Fabulous::Render::Border: invalid border location code '$location'";
	}

	# Draws one glyph line per side whose Clay border width is positive;
	# HasBorderStyle has already set the width of Hidden sides to 0. The
	# "inner" background of a cell is the shadow buffer at that cell, the
	# "outer" one is the cell just outside the box on the same side. A side
	# without a border style is drawn with the Blank style.
	method render_border ( $command, $widget, $buffer ) {
		return unless defined $widget && $widget->DOES('Term::Fabulous::Role::HasBorderStyle');

		my $data   = $command->{renderData};
		my $widths = $data->{width} // {};
		my ( $top, $right, $bottom, $left ) = map { ( $widths->{$_} // 0 ) > 0 ? 1 : 0 } qw(top right bottom left);
		return unless $top || $right || $bottom || $left;

		my ( $x0, $y0, $x1, $y1 ) = cell_rect( $command->{boundingBox} );
		my ( $last_x, $last_y ) = ( $x1 - 1, $y1 - 1 );
		return if $last_x < $x0 || $last_y < $y0;

		# A box one cell high (wide) has a single row (column): draw it once.
		$bottom = 0 if $top  && $last_y == $y0;
		$right  = 0 if $left && $last_x == $x0;

		my ( $clip_x0, $clip_y0, $clip_x1, $clip_y1 ) = @{ $self->clip_rect };
		my $border_attr = color_attr( clay_color( $data->{color} ) );
		my $blank       = Term::Fabulous::Enum::BorderStyle->Blank;

		my $shade_at = sub ( $x, $y ) {
			return TB_DEFAULT if $x < 0 || $y < 0;
			my $shade_row = $buffer->[$y] // return TB_DEFAULT;
			return $shade_row->[$x] // TB_DEFAULT;
		};
		my $paint = sub ( $x, $y, $glyph, $location, $outer_x, $outer_y ) {
			return if $y < $clip_y0 || $y >= $clip_y1;
			my ( $fg, $bg ) = _location_attrs( $location, $border_attr, $shade_at->( $x, $y ), $shade_at->( $outer_x, $outer_y ) );
			$self->set_cell( $x, $y, $glyph, $fg, $bg );
		};
		my $paint_row = sub ( $y, $outer_y, $glyphs, $locations ) {
			foreach my $x ( max( $x0, $clip_x0 ) .. min( $last_x, $clip_x1 - 1 ) ) {
				my $slot = $x == $x0 && $left ? 0 : $x == $last_x && $right ? 2 : 1;
				$paint->( $x, $y, $glyphs->[$slot], $locations->[$slot], $x, $outer_y );
			}
		};
		my $paint_column = sub ( $x, $outer_x, $glyph, $location ) {
			return if $x < $clip_x0 || $x >= $clip_x1;
			my $from = $top    ? $y0 + 1     : $y0;
			my $to   = $bottom ? $last_y - 1 : $last_y;
			foreach my $y ( max( $from, $clip_y0 ) .. min( $to, $clip_y1 - 1 ) ) {
				$paint->( $x, $y, $glyph, $location, $outer_x, $y );
			}
		};

		if ($top) {
			my $style = $widget->border_style_top // $blank;
			$paint_row->( $y0, $y0 - 1, [ $style->get_top_glyphs ], [ $style->get_top_locations ] );
		}
		if ($bottom) {
			my $style = $widget->border_style_bottom // $blank;
			$paint_row->( $last_y, $last_y + 1, [ $style->get_bottom_glyphs ], [ $style->get_bottom_locations ] );
		}
		if ($left) {
			my $style = $widget->border_style_left // $blank;
			$paint_column->( $x0, $x0 - 1, $style->get_left_glyphs, $style->get_left_locations );
		}
		if ($right) {
			my $style = $widget->border_style_right // $blank;
			$paint_column->( $last_x, $last_x + 1, $style->get_right_glyphs, $style->get_right_locations );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Border - Paint widget borders in their border styles

=head1 SYNOPSIS

	# Composed by Term::Fabulous::Render; called from draw for every
	# border render command:
	$ui->render_border( $command, $widget, $buffer );

=head1 DESCRIPTION

Most programs never use this module directly. It is one of the roles
L<Term::Fabulous::Render> is made of, and it paints the border render
commands Clay emits for widgets with a C<border_width>, using the
widget's border styles (see L<Term::Fabulous::Role::HasBorderStyle> and
L<Term::Fabulous::Enum::BorderStyle>).

=head1 METHODS

=head2 render_border

	$ui->render_border( $command, $widget, $buffer );

Paints the border of C<$widget>:

=over

=item *

Nothing is painted unless C<$widget> composes
L<Term::Fabulous::Role::HasBorderStyle>.

=item *

A side is painted when its border width in the command is positive.
Whatever the width, a side is one cell thick: it is drawn on the
outermost row or column of the widget's box. Corners are drawn where a
painted top or bottom side meets a painted left or right side;
otherwise the top or bottom edge glyph continues to the end of the row.
In a box only one cell high, the top and bottom sides would share the
same row: when both are to be drawn, only the top side is. Likewise in
a box one cell wide only the left side is drawn when both the left and
the right side are to be drawn. A side with the C<Hidden> style arrives
with a width of 0 (see L<Term::Fabulous::Role::HasBorderStyle>), so it
is not painted and the neighboring sides treat it like a side without a
width.

=item *

Each side uses the style of that side (C<border_style_top>, ...). A
side without a style is drawn with the C<Blank> style: spaces.

=item *

Each glyph is colored according to its style's location code (see
L<Term::Fabulous::Enum::BorderStyle/locations>): the border color in
front of either the widget's own background (the background already
painted in that cell, read from C<$buffer>) or the parent's background
(the background of the cell just outside the box, also read from
C<$buffer>), possibly in reverse video.

=item *

Only cells inside the current clip area are painted.

=back

C<$command> is a Clay render command hash (see
L<Clay::XS/RENDER COMMANDS>); C<$buffer> is the array reference of rows
of background attributes, C<< $buffer->[$y][$x] >>, that
L<Term::Fabulous::Render::Rectangle> and the other paint roles fill
during the frame.

=head1 REQUIRED METHODS

The consuming class provides C<set_cell> (from a cell target, see
L<Term::Fabulous::Render/CELL TARGET>) and C<width> and C<height> (for
L<Term::Fabulous::Render::Clip>).

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Enum::BorderStyle>,
L<Term::Fabulous::Role::HasBorderStyle>, L<Term::Fabulous::Manual/BORDERS>.

=cut
