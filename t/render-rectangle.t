use v5.22;
use warnings;

use Test2::V0;

use Object::Pad 0.825;
use Term::Fabulous::Termbox qw(TB_DEFAULT TB_HI_BLACK);
use Term::Fabulous::Render::Rectangle;

# A cell target that records every fill_row call as [ $x, $y, $columns, $bg ].
my @prints;

class RectangleCanvas :does(Term::Fabulous::Render::Rectangle) {
	field $width  :param :reader = 10;
	field $height :param :reader = 5;

	method fill_row ( @args ) {
		push @prints, [@args];
		return;
	}
}

my $canvas = RectangleCanvas->new;

sub fill {
	my ( $buffer, %bbox ) = @_;
	my $color = delete $bbox{color} // { r => 1, g => 2, b => 3, a => 255 };
	@prints = ();
	$canvas->render_rectangle( { boundingBox => \%bbox, renderData => { backgroundColor => $color } }, undef, $buffer );
	return [ map { [ $_->[0], $_->[1], $_->[2] ] } @prints ];
}

subtest 'negative origin is clipped' => sub {
	my $buffer = [];
	my $rows   = fill( $buffer, x => -3, y => -2, width => 6, height => 4 );
	is $rows, [ [ 0, 0, 3 ], [ 0, 1, 3 ] ], 'only the visible cells are printed';
	is scalar(@$buffer), 2, 'shadow buffer has only visible rows';
	is $buffer->[0], [ (0x010203) x 3 ], 'shadow buffer has only visible cells';
};

subtest 'oversized box is clipped to the viewport' => sub {
	my $buffer = [];
	is fill( $buffer, x => 8, y => 3, width => 10, height => 10 ), [ [ 8, 3, 2 ], [ 8, 4, 2 ] ], 'right and bottom clipped';
	is scalar( @{ $buffer->[3] } ), 10, 'shadow row ends at the viewport edge';
};

subtest 'invisible boxes draw nothing' => sub {
	is fill( [], x => -10, y => 0, width => 5, height => 2 ), [], 'left of the viewport';
	is fill( [], x => 0,   y => 7, width => 5, height => 2 ), [], 'below the viewport';
	is fill( [], x => 2,   y => 2, width => 0.5, height => 2 ), [], 'narrower than a cell';
};

subtest 'background attributes' => sub {
	fill( [], x => 0, y => 0, width => 1, height => 1, color => { r => 0, g => 0, b => 0, a => 255 } );
	is $prints[0][3], TB_HI_BLACK, 'opaque black';
	fill( [], x => 0, y => 0, width => 1, height => 1, color => { r => 9, g => 9, b => 9, a => 0 } );
	is $prints[0][3], TB_DEFAULT, 'transparent maps to the terminal default';
};

done_testing;
