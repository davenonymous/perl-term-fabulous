package Term::Fabulous::Terminal::Termbox::Cells;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Target::Mask;

class Term::Fabulous::Terminal::Termbox::Cells :does(Term::Fabulous::Render::Target::Mask) :strict(params) {
	use Term::Fabulous::Termbox qw(tb_clear tb_present tb_set_cell tb_extend_cell tb_get_cell tb_print tb_width tb_height tb_send tf_flush TB_DEFAULT TB_OK);
	use Term::Fabulous::Render::Geometry qw(row_spans_outside);

	# In inline mode, the terminal row of row 0 and the rows of the region.
	field $region_top :reader = undef;
	field $region_rows :reader = undef;

	method place_region ( $top, $rows ) {
		die "Term::Fabulous::Terminal::Termbox::Cells: place_region needs both a top row and a number of rows, or neither"
			if defined $top != defined $rows;
		( $region_top, $region_rows ) = ( $top, $rows );
		return;
	}

	# termbox2 keeps its back buffer between frames, so the cells of kept
	# rects still hold what the previous frame painted there.
	method clear_cells (@kept_rects) {
		if ( !@kept_rects ) {
			tb_clear();
			return;
		}
		my $width = tb_width();
		my $rows  = $region_rows // tb_height();
		foreach my $y ( 0 .. $rows - 1 ) {
			foreach my $span ( row_spans_outside( $y, 0, $width, @kept_rects ) ) {
				my ( $from, $to ) = @$span;
				tb_print( $from, $self->_terminal_row($y), TB_DEFAULT, TB_DEFAULT, ' ' x ( $to - $from ) );
			}
		}
		return;
	}

	# In inline mode the hidden cursor waits at the start of the region's
	# first row: a terminal that rewraps its lines on a resize moves it
	# along, so asking for it finds the region again.
	method present_cells () {
		tb_present();
		return unless defined $region_top;
		tb_send( "\e[" . ( $region_top + 1 ) . ";1H" );
		tf_flush();
		return;
	}

	method put_cell ( $x, $y, $glyph, $fg, $bg ) {
		tb_set_cell( $x, $self->_terminal_row($y), $glyph, $fg, $bg );
		return;
	}

	method put_extension ( $x, $y, $character ) {
		tb_extend_cell( $x, $self->_terminal_row($y), $character );
		return;
	}

	method put_row ( $x, $y, $columns, $bg ) {
		tb_print( $x, $self->_terminal_row($y), TB_DEFAULT, $bg, ' ' x $columns );
		return;
	}

	# A cleared cell holds a space, so the back buffer always has a glyph.
	method painted_cell ( $x, $y ) {
		my ( $status, $glyph, $fg, $bg ) = tb_get_cell( $x, $self->_terminal_row($y), 1 );
		return () unless $status == TB_OK;
		return ( $glyph, $fg, $bg );
	}

	method _terminal_row ($y) {
		return $y + ( $region_top // 0 );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Terminal::Termbox::Cells - Cell target that paints into
the terminal through termbox2

=head1 SYNOPSIS

	# Created and placed by Term::Fabulous::Terminal::Termbox:
	my $cells = $terminal->cell_target;
	$cells->place_region( $top, $rows );    # inline mode
	$cells->place_region( undef, undef );   # full screen

=head1 DESCRIPTION

Most programs never use this module directly. It is the cell target
(see L<Term::Fabulous::Render/CELL TARGET>) of
L<Term::Fabulous::Terminal::Termbox>: it writes the painted cells into
termbox2's back buffer and shows the frame with C<tb_present>, which
sends only the cells that changed since the last frame. It builds on
L<Term::Fabulous::Render::Target::Mask>, so it also provides
C<begin_frame>, C<end_frame>, C<release_rect>, C<set_cell>,
C<extend_cell> and C<fill_row>.

In inline mode, row 0 of a frame is the first row of the region, and
the hidden cursor is left at the start of that row after every frame.
The terminal must be open (C<tb_init> or C<tf_init_inline>);
otherwise termbox2 ignores the drawing.

=head1 METHODS

=head2 place_region

	$cells->place_region( $top, $rows );

Paints into the C<$rows> rows of an inline region starting at the
terminal row C<$top> (from 0); with C<undef> for both, into the whole
screen, which is the default. Dies when only one of them is given.

=head2 region_top, region_rows

The values of the last L</place_region>: C<undef> for the full screen.

=head2 clear_cells

Primitive for L<Term::Fabulous::Render::Target::Mask>. Without kept
rectangles, clears the back buffer (C<tb_clear>); otherwise overwrites
every cell of the screen (or region) outside them with a space in the
default colors, so that the kept cells hold what the previous frame
painted.

=head2 present_cells

Primitive: C<tb_present>, then in inline mode the cursor goes to the
start of the region.

=head2 put_cell, put_extension, put_row

Primitives: C<tb_set_cell>, C<tb_extend_cell> and C<tb_print> of
spaces, at the terminal row of the frame row.

=head2 painted_cell

	my ( $glyph, $fg, $bg ) = $cells->painted_cell( $x, $y );

Reads a cell back from termbox2's back buffer (C<tb_get_cell>). See
L<Term::Fabulous::Render/painted_cell>.

=head1 SEE ALSO

L<Term::Fabulous::Terminal::Termbox>, L<Term::Fabulous::Render/CELL TARGET>,
L<Term::Fabulous::Render::Target::Mask>, L<Term::Fabulous::Termbox>.

=cut
