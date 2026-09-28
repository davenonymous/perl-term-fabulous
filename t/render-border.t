use v5.22;
use warnings;

use Test2::V0;

use Object::Pad 0.825;
use Termbox 2 qw(TB_DEFAULT TB_TRUECOLOR_REVERSE);
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Render::Border;
use Term::Fabulous::Widget::Box;

# A cell target that records every painted cell once; painting a cell
# twice is a bug.
my %cells;

class BorderCanvas :does(Term::Fabulous::Render::Border) {
	field $width  :param :reader = 10;
	field $height :param :reader = 6;

	method set_cell ( $x, $y, $glyph, $fg, $bg ) {
		die "cell ($x, $y) painted twice\n" if exists $cells{"$x,$y"};
		$cells{"$x,$y"} = [ $glyph, $fg, $bg ];
		return;
	}
}

my $canvas = BorderCanvas->new;
my $red    = { r => 200, g => 0, b => 0, a => 255 };

sub draw_border {
	my (%args) = @_;
	my $widget = Term::Fabulous::Widget::Box->new( border_style => Term::Fabulous::Enum::BorderStyle->from_name( $args{style} // 'Solid' ) );
	my %width  = ( top => 0, right => 0, bottom => 0, left => 0, betweenChildren => 0, %{ $args{width} } );
	%cells = ();
	$canvas->render_border(
		{
			boundingBox => $args{bbox} // { x => 1, y => 1, width => 4, height => 3 },
			renderData  => { color => $red, width => \%width },
		},
		$widget, $args{buffer} // [],
	);
	return { map { $_ => $cells{$_}[0] } keys %cells };
}

subtest 'per-side widths' => sub {
	is draw_border( width => { top => 1 } ), { map { ( "$_,1" => "\x{2500}" ) } 1 .. 4 }, 'top only: plain edge glyphs, no corners';

	is draw_border( width => { top => 1, right => 1, bottom => 1, left => 1 } ),
		{
		'1,1' => "\x{250C}", '2,1' => "\x{2500}", '3,1' => "\x{2500}", '4,1' => "\x{2510}",
		'1,2' => "\x{2502}", '4,2' => "\x{2502}",
		'1,3' => "\x{2514}", '2,3' => "\x{2500}", '3,3' => "\x{2500}", '4,3' => "\x{2518}",
		},
		'all sides';

	is draw_border( width => { top => 1, left => 2 } ),
		{ '1,1' => "\x{250C}", '2,1' => "\x{2500}", '3,1' => "\x{2500}", '4,1' => "\x{2500}", '1,2' => "\x{2502}", '1,3' => "\x{2502}" },
		'top and left: one corner, left side runs to the bottom';

	is draw_border( width => {} ), {}, 'no widths, nothing drawn';
};

subtest 'degenerate and clipped boxes' => sub {
	ok lives { draw_border( width => { top => 1, right => 1, bottom => 1, left => 1 }, bbox => { x => 2, y => 2, width => 1, height => 1 } ) },
		'1x1 box paints each cell once';
	is [ keys %cells ], ['2,2'], 'single cell';

	draw_border( width => { top => 1, right => 1, bottom => 1, left => 1 }, bbox => { x => -2, y => -1, width => 5, height => 3 } );
	is [ sort keys %cells ], [ '0,1', '1,1', '2,0', '2,1' ], 'only visible cells, no negative coordinates';
};

subtest 'location colors' => sub {
	my $buffer = [];
	$buffer->[$_] = [ (0x0A0B0C) x 6 ] for 1 .. 3;    # widget background inside the box
	$buffer->[0] = [ (0x010101) x 6 ];                 # parent background above it

	draw_border( style => 'Wide', width => { right => 1, top => 1 }, buffer => $buffer );
	is $cells{'4,2'}, [ "\x{258A}", 0xC80000 | TB_TRUECOLOR_REVERSE, 0x0A0B0C ], 'location 3: reverse video over the widget background';
	is $cells{'2,1'}, [ "\x{2581}", 0xC80000, 0x010101 ], 'location 1: border color over the parent background';

	draw_border( style => 'Solid', width => { top => 1 }, buffer => $buffer );
	is $cells{'2,1'}[2], 0x0A0B0C, 'location 0: border color over the widget background';

	draw_border( style => 'Panel', width => { top => 1, left => 1 } );
	is $cells{'1,1'}[1], 0xC80000 | TB_TRUECOLOR_REVERSE, 'location 2 is reverse video';
	is $cells{'1,1'}[2], TB_DEFAULT, 'location 2 background is the unpainted parent cell (terminal default)';
};

done_testing;
