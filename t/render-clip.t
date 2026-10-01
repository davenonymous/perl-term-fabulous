use v5.22;
use warnings;

use Test2::V0;

use Object::Pad 0.825;
use Term::Fabulous::Render::Rectangle;
use Term::Fabulous::Render::Target::Grid;

class ClipCanvas :does(Term::Fabulous::Render::Rectangle) :does(Term::Fabulous::Render::Target::Grid) {
	field $width  :param :reader = 10;
	field $height :param :reader = 5;
}

my $canvas = ClipCanvas->new;

sub scissor {
	my (%bbox) = @_;
	$canvas->render_scissor_start( { boundingBox => \%bbox }, undef, [] );
	return;
}

sub painted_cells {
	return [ map { my $y = $_; map { [ $_, $y ] } grep { defined $canvas->cell( $_, $y ) } 0 .. 9 } 0 .. 4 ];
}

subtest 'scissors narrow the clip rect' => sub {
	is $canvas->clip_rect, [ 0, 0, 10, 5 ], 'no scissor: the viewport';

	scissor( x => 2, y => 1, width => 6, height => 10 );
	is $canvas->clip_rect, [ 2, 1, 8, 5 ], 'a scissor is cut to the viewport';

	scissor( x => 5, y => 0, width => 10, height => 2 );
	is $canvas->clip_rect, [ 5, 1, 8, 2 ], 'a nested scissor is cut to the one around it';

	$canvas->render_scissor_end( {}, undef, [] );
	is $canvas->clip_rect, [ 2, 1, 8, 5 ], 'the end restores the outer scissor';

	$canvas->close_scissors;
	is $canvas->clip_rect, [ 0, 0, 10, 5 ], 'close_scissors restores the viewport';
	like dies { $canvas->render_scissor_end( {}, undef, [] ) }, qr/scissor end without an open scissor/, 'an unmatched end dies';
};

subtest 'drawing stays inside the scissor' => sub {
	$canvas->begin_frame;
	scissor( x => 1, y => 1, width => 2, height => 2 );
	$canvas->render_rectangle( { boundingBox => { x => 0, y => 0, width => 10, height => 5 }, renderData => { backgroundColor => { r => 1, g => 2, b => 3, a => 255 } } }, undef, [] );
	is painted_cells(), [ [ 1, 1 ], [ 2, 1 ], [ 1, 2 ], [ 2, 2 ] ], 'only the scissor cells are filled';

	scissor( x => 20, y => 0, width => 5, height => 5 );
	is $canvas->clip_rect, [ 20, 1, 20, 3 ], 'disjoint scissors leave an empty clip rect';
	$canvas->begin_frame;
	$canvas->render_rectangle( { boundingBox => { x => 0, y => 0, width => 10, height => 5 }, renderData => { backgroundColor => { r => 1, g => 2, b => 3, a => 255 } } }, undef, [] );
	is painted_cells(), [], 'nothing is drawn';
	$canvas->close_scissors;
};

done_testing;
