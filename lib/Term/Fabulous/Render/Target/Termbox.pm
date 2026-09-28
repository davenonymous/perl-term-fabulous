package Term::Fabulous::Render::Target::Termbox;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Target::Termbox {
	use Termbox 2 qw(tb_clear tb_present tb_set_cell tb_extend_cell tb_print TB_DEFAULT);

	method begin_frame () {
		tb_clear();
		return;
	}

	method end_frame () {
		tb_present();
		return;
	}

	method set_cell ( $x, $y, $glyph, $fg, $bg ) {
		tb_set_cell( $x, $y, $glyph, $fg, $bg );
		return;
	}

	method extend_cell ( $x, $y, $codepoint ) {
		tb_extend_cell( $x, $y, $codepoint );
		return;
	}

	method fill_row ( $x, $y, $columns, $bg ) {
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
call of the same meaning. C<begin_frame> clears the back buffer,
C<end_frame> presents it. See L<Term::Fabulous::Render/CELL TARGET> for the
contract.

=cut
