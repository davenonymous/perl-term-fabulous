package Term::Fabulous::Render::Target::Grid;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Target::Mask;

class Term::Fabulous::Render::Target::Grid :does(Term::Fabulous::Render::Target::Mask) :strict(params) {
	use Term::Fabulous::Termbox qw(TB_DEFAULT TB_HI_BLACK TB_REVERSE TB_BOLD TB_UNDERLINE);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant RESET => "\e[0m";

	# Term::Fabulous::Render::Attr packs the color into the low 24 bits and
	# the flags above them.
	use constant COLOR_MASK => 0xFFFFFF;

	# Painted cells, indexed [y][x]; a cell is [ $glyph, $fg, $bg ] or undef
	# when nothing has been painted there. A wide cluster is stored only in
	# the cell it starts in; its continuation cells keep whatever was
	# painted there before (undef on a cleared grid).
	field @rows;

	method clear_cells (@kept_rects) {
		my @kept_rows;
		foreach my $rect (@kept_rects) {
			my ( $x0, $y0, $x1, $y1 ) = @$rect;
			foreach my $y ( $y0 .. $y1 - 1 ) {
				my $row = $rows[$y] // next;
				( $kept_rows[$y] //= [] )->[$_] = $row->[$_] foreach $x0 .. $x1 - 1;
			}
		}
		@rows = @kept_rows;
		return;
	}

	method present_cells () {
		return;
	}

	method put_cell ( $x, $y, $glyph, $fg, $bg ) {
		( $rows[$y] //= [] )->[$x] = [ $glyph, $fg, $bg ];
		return;
	}

	method put_extension ( $x, $y, $character ) {
		my $cell = $rows[$y][$x] // die "Term::Fabulous::Render::Target::Grid: extend_cell($x, $y) on a cell that was never set";
		$cell->[0] .= $character;
		return;
	}

	method put_row ( $x, $y, $columns, $bg ) {
		my $row = $rows[$y] //= [];
		$row->[$_] = [ ' ', 0, $bg ] foreach $x .. $x + $columns - 1;
		return;
	}

	method cell ( $x, $y ) {
		return $rows[$y][$x];
	}

	method painted_cell ( $x, $y ) {
		my $cell = $rows[$y][$x] // return ();
		return @$cell;
	}

	method grid_height () {
		return scalar @rows;
	}

	method grid_row ($y) {
		return $rows[$y] // [];
	}

	method row_text ( $y, %options ) {
		my @unknown = grep { !/\A(?:columns|colors|trim_trailing_whitespace)\z/ } sort keys %options;
		die "Term::Fabulous::Render::Target::Grid: row_text does not accept @unknown (known options: columns, colors, trim_trailing_whitespace)" if @unknown;
		my $columns = $options{columns} // die "Term::Fabulous::Render::Target::Grid: row_text needs the number of columns";

		my $cells = $self->grid_row($y);
		my $last  = $columns - 1;
		if ( $options{trim_trailing_whitespace} // 1 ) {
			$last = $#$cells if $#$cells < $last;
			$last-- while $last >= 0 && _is_blank( $cells->[$last] );
		}

		my $colors = $options{colors} // 0;
		my ( $line, $style ) = ( '', '' );
		my $x = 0;
		while ( $x <= $last ) {
			my $cell = $cells->[$x];
			my ( $glyph, $fg, $bg ) = defined $cell ? @$cell : ( ' ', TB_DEFAULT, TB_DEFAULT );
			if ($colors) {
				my $wanted = _sgr( $fg, $bg );
				if ( $wanted ne $style ) {
					$line .= RESET if length $style;
					$line .= $wanted;
					$style = $wanted;
				}
			}
			$line .= $glyph;
			$x += defined $cell ? string_columns($glyph) : 1;
		}
		$line .= RESET if length $style;
		return $line;
	}

	# A cell that would print as a plain space: never painted, or a space in
	# the terminal's default background.
	sub _is_blank ($cell) {
		return 1 unless defined $cell;
		my ( $glyph, $fg, $bg ) = @$cell;
		return $glyph eq ' ' && $bg == TB_DEFAULT && !( $fg & TB_REVERSE );
	}

	sub _sgr ( $fg, $bg ) {
		my @codes;
		push @codes, 1 if $fg & TB_BOLD;
		push @codes, 4 if $fg & TB_UNDERLINE;
		push @codes, 7 if ( $fg | $bg ) & TB_REVERSE;
		push @codes, _color_codes( 38, $fg );
		push @codes, _color_codes( 48, $bg );
		return @codes ? "\e[" . join( ';', @codes ) . 'm' : '';
	}

	# The terminal default needs no code; opaque black carries its own flag
	# because termbox2 reads 0x000000 as the default color.
	sub _color_codes ( $base, $attr ) {
		return () if $attr == TB_DEFAULT;
		my $rgb = $attr & TB_HI_BLACK ? 0 : $attr & COLOR_MASK;
		return () if !( $attr & TB_HI_BLACK ) && $rgb == 0;
		return ( $base, 2, ( $rgb >> 16 ) & 0xFF, ( $rgb >> 8 ) & 0xFF, $rgb & 0xFF );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Target::Grid - Cell target that keeps the
painted cells in memory

=head1 SYNOPSIS

	use Term::Fabulous::Render::Target::Grid;

	my $grid = Term::Fabulous::Render::Target::Grid->new;

	# Term::Fabulous::Static and Term::Fabulous::Terminal::Memory paint
	# into one; read it back:
	my ( $glyph, $fg, $bg ) = @{ $grid->cell( 0, 0 ) };
	my $line = $grid->row_text( 0, columns => 20, colors => 0 );

=head1 DESCRIPTION

Most programs never use this module directly:
L<Term::Fabulous::Static> and L<Term::Fabulous::Terminal::Memory> paint
into a Grid and read it back as text. Use their C<cell_target> to
inspect exactly what was painted into each cell, for example in tests.

This is a cell target (see L<Term::Fabulous::Render/CELL TARGET>) that
stores every painted cell instead of drawing it, built on
L<Term::Fabulous::Render::Target::Mask>. Each frame starts from an
empty grid, except for the kept rectangles of unchanged canvases.

=head1 CONSTRUCTOR

=head2 new

	my $grid = Term::Fabulous::Render::Target::Grid->new;

An empty grid. It takes no parameters; the grid grows to whatever is
painted into it.

=head1 METHODS

=head2 cell

	my $cell = $grid->cell( $x, $y );
	my ( $glyph, $fg, $bg ) = @$cell if $cell;

The cell at column C<$x>, row C<$y> (from 0) as an array reference
C<[ $glyph, $fg, $bg ]>, or C<undef> if nothing painted it in the last
frame.

=over

=item *

C<$glyph> is a character string: the base character plus any combining
characters of its grapheme cluster.

=item *

C<$fg> and C<$bg> are the termbox2 attributes the render roles computed
(see L<Term::Fabulous::Render::Attr>): C<0xRRGGBB>, C<TB_DEFAULT> (0) for
the terminal default color, C<TB_HI_BLACK> for black, possibly
combined with flags such as C<TB_REVERSE>. Background fills
store C<TB_DEFAULT> as the foreground.

=item *

A wide cluster (two columns) is stored in the cell it starts in only.
The cell to its right is not written for it: it holds whatever was
painted there earlier in the frame (usually the background fill, a
space) or C<undef>. When you read a row cell by cell, skip as many cells
after a glyph as L<Term::Fabulous::Unicode/cluster_columns> reports for
it, as L</row_text> does.

=back

=head2 row_text

	my $line = $grid->row_text( $y, columns => 80 );
	my $line = $grid->row_text( $y, columns => 80, colors => 1, trim_trailing_whitespace => 0 );

Row C<$y> as a line of text, C<columns> cells wide (required); cells
nothing painted read as spaces, and a wide glyph takes the cells it
covers. Options:

=over

=item C<colors>

A boolean, default 0. When true, every run of cells with the same
colors is preceded by an ANSI SGR sequence with 24-bit colors
(C<ESC [ 38;2;R;G;B m> for the foreground, C<48;2;...> for the
background), C<7> (reverse video) for cells in reverse video, and C<1>
(bold) and C<4> (underline) for those termbox2 flags; the line ends
with C<ESC [ 0 m> when it set any. The terminal's default colors get no
sequence.

=item C<trim_trailing_whitespace>

A boolean, default 1. When true, cells at the end of the row that would
print as plain spaces are left out: cells nothing painted, and spaces
in the terminal's default background and not in reverse video.

=back

Unknown options die. L<Term::Fabulous::Static/render_lines> and
L<Term::Fabulous::Terminal::Memory/lines> are built on it.

=head2 grid_height

	my $rows = $grid->grid_height;

The number of rows up to and including the last row anything was
painted in.

=head2 grid_row

	my $cells = $grid->grid_row($y);

The cells of row C<$y> as an array reference of the values L</cell>
returns, which may contain C<undef> holes; an empty array reference for
a row nothing was painted in.

=head2 painted_cell

	my ( $glyph, $fg, $bg ) = $grid->painted_cell( $x, $y );

The contents of L</cell> as a list, or an empty list when the cell is
C<undef>. See L<Term::Fabulous::Render/painted_cell>.

=head2 Cell target methods

C<begin_frame>, C<end_frame>, C<release_rect>, C<set_cell>,
C<extend_cell> and C<fill_row> come from
L<Term::Fabulous::Render::Target::Mask>, which builds them on the
primitives below.

=head2 clear_cells

	$grid->clear_cells(@kept_rects);

Primitive: forgets every cell outside the given C<[x0, y0, x1, y1]>
rectangles (all cells without rectangles).

=head2 present_cells

Primitive. Does nothing.

=head2 put_cell

	$grid->put_cell( $x, $y, $glyph, $fg, $bg );

Primitive: stores one cell.

=head2 put_extension

	$grid->put_extension( $x, $y, $character );

Primitive: appends a combining character to a stored cell. Dies if
nothing was stored there.

=head2 put_row

	$grid->put_row( $x, $y, $columns, $bg );

Primitive: stores C<$columns> spaces with the background C<$bg>.

=head1 SEE ALSO

L<Term::Fabulous::Static>, L<Term::Fabulous::Terminal::Memory>,
L<Term::Fabulous::Render/CELL TARGET>,
L<Term::Fabulous::Render::Target::Mask>.

=cut
