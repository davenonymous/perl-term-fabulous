package Term::Fabulous::Render::Target::Termbox;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Target::Mask;

role Term::Fabulous::Render::Target::Termbox :does(Term::Fabulous::Render::Target::Mask) {
	use Term::Fabulous::Termbox qw(tb_clear tb_present tb_set_cell tb_extend_cell tb_get_cell tb_print tb_width tb_height tb_send tf_flush TB_DEFAULT TB_OK);
	use Term::Fabulous::Render::Geometry qw(row_spans_outside);

	field $termbox_inline_top :reader :writer = undef;    # the terminal row of row 0 in inline mode

	# termbox2 keeps its back buffer between frames, so the cells of kept
	# rects still hold what the previous frame painted there.
	method clear_cells (@kept_rects) {
		if ( !@kept_rects ) {
			tb_clear();
			return;
		}
		my $width = tb_width();
		my $rows  = defined $termbox_inline_top ? $self->height : tb_height();
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
		return unless defined $termbox_inline_top;
		tb_send( "\e[" . ( $termbox_inline_top + 1 ) . ";1H" );
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
		return $y + ( $termbox_inline_top // 0 );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Target::Termbox - Cell target that paints into
the terminal through termbox2

=head1 SYNOPSIS

	use Object::Pad 0.825;
	use Clay::UI;
	use Term::Fabulous::Render;
	use Term::Fabulous::Render::Target::Termbox;

	# A UI class that paints into the terminal, without a mouse pointer.
	# (Term::Fabulous is such a class, with an event loop added.)
	class My::Screen
		:isa(Clay::UI)
		:does(Term::Fabulous::Render)
		:does(Term::Fabulous::Render::Target::Termbox)
	{
		method pointer_state () { return undef }
	}

	# After termbox2's tb_init():
	My::Screen->new( root => $root, width => 80, height => 24 )->draw;

=head1 DESCRIPTION

Most programs never use this module directly; L<Term::Fabulous>
composes it.

This is the cell target (see L<Term::Fabulous::Render/CELL TARGET>)
that sends the painted cells to termbox2, built on
L<Term::Fabulous::Render::Target::Mask>. termbox2 collects the cells of
a frame in a back buffer; when the frame is presented, it compares the
back buffer with what is on the screen and writes only the cells that
differ to the terminal.

The terminal must have been opened with termbox2's C<tb_init> (which
L<Term::Fabulous/run> does) before anything is painted; otherwise
termbox2 ignores the calls.

In inline mode (opened with C<tf_init_inline> instead, see
L<Term::Fabulous::Termbox/tf_init_inline>) the layout covers only some
rows of the terminal; L</termbox_inline_top> says which row its first
row is painted on.

=head1 METHODS

These are the primitives required by
L<Term::Fabulous::Render::Target::Mask>, and L</termbox_inline_top>.
The rows of the primitives count from the first row of the layout.

=head2 clear_cells

	$ui->clear_cells(@kept_rects);

Without rectangles, clears the whole back buffer (C<tb_clear>). With
rectangles, overwrites every cell of the layout's rows outside them with
a space in the terminal default colors and leaves the cells inside them
as the previous frame painted them; termbox2 keeps its back buffer
between frames.

=head2 present_cells

	$ui->present_cells;

Shows the frame (C<tb_present>). In inline mode it then moves the
hidden cursor to the start of the layout's first row; a terminal that
rewraps its lines when it is resized moves the cursor along with them,
so asking the terminal for the cursor finds the layout again.

=head2 put_cell

	$ui->put_cell( $x, $y, $glyph, $fg, $bg );

Writes one cell into the back buffer with termbox2's C<tb_set_cell>:
the character C<$glyph> with the foreground attribute C<$fg> and the
background attribute C<$bg>.

=head2 put_extension

	$ui->put_extension( $x, $y, $character );

Appends a combining character to the cell at C<($x, $y)> with
termbox2's C<tb_extend_cell>, completing a grapheme cluster.

=head2 painted_cell

	my ( $glyph, $fg, $bg ) = $ui->painted_cell( $x, $y );

Reads the cell from the back buffer with termbox2's C<tb_get_cell>. A
cell nothing has painted holds the space C<tb_clear> left there. See
L<Term::Fabulous::Render/painted_cell>.

=head2 put_row

	$ui->put_row( $x, $y, $columns, $bg );

Writes C<$columns> spaces from C<($x, $y)> to the right with
termbox2's C<tb_print>, in the background attribute C<$bg> and the
terminal default foreground.

=head2 termbox_inline_top

	my $row = $ui->termbox_inline_top;
	$ui->set_termbox_inline_top(12);
	$ui->set_termbox_inline_top(undef);

The terminal row, counted from 0, that row 0 of the layout is painted
on, or C<undef>, the default, for the full screen. With a row, every
cell is painted that many rows further down, only the layout's
C<height> rows are touched, and after every frame the hidden cursor
is moved to the start of that row. L<Term::Fabulous/run> sets it in
inline mode. C<set_termbox_inline_top> sets it and returns the object.

=head1 SEE ALSO

L<Term::Fabulous>, L<Term::Fabulous::Render/CELL TARGET>,
L<Term::Fabulous::Render::Target::Mask>, L<Term::Fabulous::Termbox>.

=cut
