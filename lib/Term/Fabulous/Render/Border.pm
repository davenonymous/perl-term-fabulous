package Term::Fabulous::Render::Border;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Border {
	use List::Util qw(min max);
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);    # checks truecolor support first
	use Termbox 2 qw(tb_set_cell TB_DEFAULT TB_TRUECOLOR_REVERSE);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Render::Geometry qw(cell_rect);

	method width;
	method height;

	# Attributes for a border cell from its location code, following
	# Textual's get_box styles: 0 = border color on the widget's background,
	# 1 = border color on the parent's background, 2 and 3 are 1 and 0 in
	# reverse video. Reverse video swaps terminal-default colors correctly,
	# which an explicit fg/bg swap of TB_DEFAULT would not.
	sub _location_attrs ( $location, $border, $inner, $outer ) {
		return ( $border, $inner ) if $location == 0;
		return ( $border, $outer ) if $location == 1;
		return ( $border | TB_TRUECOLOR_REVERSE, $outer ) if $location == 2;
		return ( $border | TB_TRUECOLOR_REVERSE, $inner ) if $location == 3;
		die "Term::Fabulous::Render::Border: invalid border location code '$location'";
	}

	# Draws one glyph line per side whose Clay border width is positive. The
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

		my ( $viewport_width, $viewport_height ) = ( $self->width, $self->height );
		my $border_attr = color_attr( clay_color( $data->{color} ) );
		my $blank       = Term::Fabulous::Enum::BorderStyle->Blank;

		my $shade_at = sub ( $x, $y ) {
			return TB_DEFAULT if $x < 0 || $y < 0;
			my $shade_row = $buffer->[$y] // return TB_DEFAULT;
			return $shade_row->[$x] // TB_DEFAULT;
		};
		my $paint = sub ( $x, $y, $glyph, $location, $outer_x, $outer_y ) {
			return if $y < 0 || $y >= $viewport_height;
			my ( $fg, $bg ) = _location_attrs( $location, $border_attr, $shade_at->( $x, $y ), $shade_at->( $outer_x, $outer_y ) );
			tb_set_cell( $x, $y, $glyph, $fg, $bg );
		};
		my $paint_row = sub ( $y, $outer_y, $glyphs, $locations ) {
			foreach my $x ( max( $x0, 0 ) .. min( $last_x, $viewport_width - 1 ) ) {
				my $slot = $x == $x0 && $left ? 0 : $x == $last_x && $right ? 2 : 1;
				$paint->( $x, $y, $glyphs->[$slot], $locations->[$slot], $x, $outer_y );
			}
		};
		my $paint_column = sub ( $x, $outer_x, $glyph, $location ) {
			return if $x < 0 || $x >= $viewport_width;
			my $from = $top    ? $y0 + 1     : $y0;
			my $to   = $bottom ? $last_y - 1 : $last_y;
			foreach my $y ( max( $from, 0 ) .. min( $to, $viewport_height - 1 ) ) {
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
