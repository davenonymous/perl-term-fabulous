use v5.22;
use warnings;
use utf8;

use Test2::V0;

use Clay::XS qw(sizing_fixed sizing_grow);
use Term::Fabulous::Termbox qw(TB_DEFAULT);
use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Canvas;
use Term::Fabulous::Widget::Text;

# A 6x3 canvas with a one-cell border and one cell of left padding, at (1, 1)
# in a 12x6 viewport: its content box is the 3x1 rect at (3, 2).
sub scene {
	my (%args) = @_;
	my $root = Term::Fabulous::Widget::Box->new(
		background_color => [ 1, 1, 1, 255 ],
		layout           => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, top => 1 } },
	);
	my $canvas = Term::Fabulous::Widget::Canvas->new(
		( $args{background} ? ( background_color => $args{background} ) : () ),
		border_width => 1,
		layout       => { sizing => { width => sizing_fixed( $args{width} // 6 ), height => sizing_fixed(3) }, padding => { left => 1 } },
	);
	$root->add_child($canvas);
	return ( Term::Fabulous::Static->new( root => $root, width => 12, height => 6 ), $canvas );
}

sub glyphs_at {
	my ( $ui, $y, $x0, $x1 ) = @_;
	return join '', map { my $cell = $ui->cell( $_, $y ); defined $cell ? $cell->[0] : '.' } $x0 .. $x1 - 1;
}

subtest 'the buffer is painted into the content box' => sub {
	my ( $ui, $canvas ) = scene( background => [ 2, 2, 2, 255 ] );
	my @sizes;
	$canvas->on( CanvasResize => sub { push @sizes, [ $_[0]->columns, $_[0]->rows ]; $canvas->put( 0, 0, 'a', 0x0000FF, 0xFF0000 )->put( 1, 0, 'b' ); return } );
	$ui->draw;

	is \@sizes, [ [ 3, 1 ] ], 'CanvasResize reports the content size before the frame is painted';
	is glyphs_at( $ui, 2, 2, 8 ), ' ab   ', 'the cells start inside border and padding';
	is $ui->cell( 3, 2 ), [ 'a', 0x0000FF, 0xFF0000 ], 'a cell with its own colors';
	is $ui->cell( 4, 2 ), [ 'b', TB_DEFAULT, 0x020202 ], 'a cell without colors: terminal foreground, canvas background';
	is $ui->cell( 5, 2 ), [ ' ', TB_DEFAULT, 0x020202 ], 'an unset cell: a space in the canvas background';
};

subtest 'without a background of its own the canvas shows the nearest ancestor background' => sub {
	my ( $ui, $canvas ) = scene();
	$ui->draw;
	is $ui->cell( 3, 2 ), [ ' ', TB_DEFAULT, 0x010101 ], "the root's background";
};

subtest 'an unchanged canvas keeps its cells' => sub {
	my ( $ui, $canvas ) = scene( background => [ 2, 2, 2, 255 ] );
	$ui->draw;
	$canvas->put( 0, 0, 'a' );
	$ui->draw;

	$ui->set_cell( $_, 2, 'Z', 0, 0 ) foreach 3 .. 5;    # stand-ins for what is still on screen
	$ui->draw;
	is glyphs_at( $ui, 2, 3, 6 ), 'ZZZ', 'nothing is painted again, not even the background below';

	$canvas->put( 1, 0, 'c' );
	$ui->draw;
	is glyphs_at( $ui, 2, 3, 6 ), 'ZcZ', 'only the changed cell is painted';
};

subtest 'a canvas is painted in full when it cannot keep its cells' => sub {
	my ( $ui, $canvas ) = scene();
	$ui->draw;
	$ui->draw;

	$ui->set_cell( 3, 2, 'Z', 0, 0 );
	$ui->invalidate_canvases;
	$ui->draw;
	is glyphs_at( $ui, 2, 3, 4 ), ' ', 'after invalidate_canvases';

	$canvas->add_child( Term::Fabulous::Widget::Text->new( text => 'T' ) );
	$ui->draw;
	$ui->set_cell( 5, 2, 'Z', 0, 0 );
	$ui->draw;
	is glyphs_at( $ui, 2, 3, 6 ), 'T  ', 'while a child is drawn over it';
};

subtest 'a wide glyph crossing the visible edge is painted as spaces' => sub {
	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
	my $canvas = Term::Fabulous::Widget::Canvas->new( layout => { sizing => { width => sizing_fixed(5), height => sizing_fixed(1) } } );
	$root->add_child($canvas);
	my $ui = Term::Fabulous::Static->new( root => $root, width => 4, height => 1 );

	$canvas->on( CanvasResize => sub { $canvas->put_text( 0, 0, 'ab日' ); return } );
	$ui->draw;
	is glyphs_at( $ui, 0, 0, 4 ), 'ab日.', 'fits';

	$ui->width(3);
	$ui->draw;
	is glyphs_at( $ui, 0, 0, 3 ), 'ab ', 'cut by the viewport';
};

done_testing;
