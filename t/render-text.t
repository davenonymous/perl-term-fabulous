use v5.22;
use warnings;
use utf8;

use Test2::V0;

use Object::Pad 0.825;
use Term::Fabulous::Termbox qw(TB_DEFAULT TB_HI_BLACK);
use Term::Fabulous::Render::Text;
use Term::Fabulous::Unicode qw(cluster_columns);

# A cell target that records every call in order.
my @calls;

class TextCanvas :does(Term::Fabulous::Render::Text) {
	field $width  :param :reader = 20;
	field $height :param :reader = 5;

	method set_cell ( @args ) {
		push @calls, [ set => @args ];
		return;
	}

	method extend_cell ( @args ) {
		push @calls, [ extend => @args ];
		return;
	}
}

my $canvas = TextCanvas->new;
my $white  = { r => 255, g => 255, b => 255, a => 255 };

sub draw_text {
	my ( $text, %bbox ) = @_;
	my $buffer = delete $bbox{buffer} // [];
	my $color  = delete $bbox{color}  // $white;
	@calls = ();
	$canvas->render_text(
		{
			boundingBox => { x => 0, y => 0, width => 20, height => 1, %bbox },
			renderData  => { stringContents => $text, textColor => $color },
		},
		undef, $buffer,
	);
	return [ map { [ @{$_}[ 1, 2, 3 ] ] } grep { $_->[0] eq 'set' } @calls ];
}

is draw_text( 'abc', x => 2, y => 1 ), [ [ 2, 1, 'a' ], [ 3, 1, 'b' ], [ 4, 1, 'c' ] ], 'drawn at the bounding box origin';
is draw_text( 'abc', x => 2.7, y => 1.2 ), [ [ 2, 1, 'a' ], [ 3, 1, 'b' ], [ 4, 1, 'c' ] ], 'fractional origin is floored';
is draw_text( 'abcd', width => 2 ), [ [ 0, 0, 'a' ], [ 1, 0, 'b' ] ], 'clipped at the bounding box right edge';
is draw_text( 'abcd', x => 18, width => 10 ), [ [ 18, 0, 'a' ], [ 19, 0, 'b' ] ], 'clipped at the viewport right edge';
is draw_text( 'abc', x => -1 ), [ [ 0, 0, 'b' ], [ 1, 0, 'c' ] ], 'clusters left of the viewport are skipped';
is draw_text( 'abc', y => 5 ),  [], 'row below the viewport is skipped';
is draw_text( 'abc', y => -1 ), [], 'row above the viewport is skipped';

subtest 'wide clusters' => sub {
	skip_all 'locale has no double-width wcwidth for U+3042' unless cluster_columns("\x{3042}") == 2;

	is draw_text( "\x{3042}b", width => 3 ), [ [ 0, 0, "\x{3042}" ], [ 2, 0, 'b' ] ], 'wide cluster advances two columns';
	is draw_text( "a\x{3042}", width => 2 ), [ [ 0, 0, 'a' ] ], 'wide cluster crossing the right edge stops the line';

	my $buffer = [ [ 0x112233 ] ];
	draw_text( "\x{3042}", buffer => $buffer );
	is $buffer->[0], [ 0x112233, 0x112233 ], 'shadow buffer covers both cells of a wide cluster';
};

subtest 'control characters never reach the terminal' => sub {
	draw_text("a\e]0;PWNED\a\tb\x{9B}c");
	my @chars = map { $_->[3] } @calls;
	ok !( grep { /[\x00-\x1F\x7F-\x9F]/ } @chars ), 'no C0/C1 control or DEL was written';
	is scalar( grep { $_ eq "\x{FFFD}" } @chars ), 3, 'ESC, BEL and CSI became U+FFFD';
	ok( ( grep { $_ eq ' ' } @chars ), 'TAB became a space' );
};

subtest 'combining marks extend the base cell' => sub {
	draw_text("e\x{301}x");
	is [ map { [ $_->[0], $_->[1], $_->[3] ] } @calls ], [ [ 'set', 0, 'e' ], [ 'extend', 0, "\x{301}" ], [ 'set', 1, 'x' ] ], 'one cell for the cluster';
};

subtest 'colors' => sub {
	draw_text( 'a', color => { r => 0, g => 0, b => 0, a => 255 } );
	is $calls[0][4], TB_HI_BLACK, 'opaque black foreground is TB_HI_BLACK';

	draw_text( 'a', buffer => [ [ 0x112233 ] ] );
	is $calls[0][5], 0x112233, 'background comes from the shadow buffer';

	draw_text('a');
	is $calls[0][5], TB_DEFAULT, 'unpainted cell uses the terminal default background';
};

done_testing;
