package Term::Fabulous::Render::Target::Termbox;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Render::Target::Mask;

role Term::Fabulous::Render::Target::Termbox :does(Term::Fabulous::Render::Target::Mask) {
	use Termbox 2 qw(tb_clear tb_present tb_set_cell tb_extend_cell tb_print tb_width tb_height TB_DEFAULT);
	use Term::Fabulous::Render::Geometry qw(row_spans_outside);

	# termbox2 keeps its back buffer between frames, so the cells of kept
	# rects still hold what the previous frame painted there.
	method clear_cells (@kept_rects) {
		if ( !@kept_rects ) {
			tb_clear();
			return;
		}
		my $width = tb_width();
		foreach my $y ( 0 .. tb_height() - 1 ) {
			foreach my $span ( row_spans_outside( $y, 0, $width, @kept_rects ) ) {
				my ( $from, $to ) = @$span;
				tb_print( $from, $y, TB_DEFAULT, TB_DEFAULT, ' ' x ( $to - $from ) );
			}
		}
		return;
	}

	method present_cells () {
		tb_present();
		return;
	}

	method put_cell ( $x, $y, $glyph, $fg, $bg ) {
		tb_set_cell( $x, $y, $glyph, $fg, $bg );
		return;
	}

	method put_extension ( $x, $y, $codepoint ) {
		tb_extend_cell( $x, $y, $codepoint );
		return;
	}

	method put_row ( $x, $y, $columns, $bg ) {
		tb_print( $x, $y, TB_DEFAULT, $bg, ' ' x $columns );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Target::Termbox - Paint render cells into termbox2

=head1 SYNOPSIS

	class My::UI :isa(Clay::UI) :does(Term::Fabulous::Render) :does(Term::Fabulous::Render::Target::Termbox) { ... }

=head1 DESCRIPTION

The cell target of L<Term::Fabulous>: every method forwards to the termbox2
call of the same meaning. C<begin_frame> clears the back buffer, except
for the kept rects (see L<Term::Fabulous::Render::Target::Mask>), which
keep what the previous frame painted there; C<end_frame> presents it, and
termbox2 then writes only the cells that changed to the terminal. See
L<Term::Fabulous::Render/CELL TARGET> for the contract.

=cut
