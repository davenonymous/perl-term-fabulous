use v5.22;
use warnings;
use utf8;

use Test2::V0;

use Encode qw(decode encode);
use Clay::XS qw(sizing_grow sizing_fit sizing_fixed CLAY_TOP_TO_BOTTOM);
use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Enum::BorderStyle;

sub page {
	my (%args) = @_;
	my $root = Term::Fabulous::Widget::Box->new(
		layout => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => $args{height} // sizing_fit() },
			padding          => { left => 1, right => 1 },
		},
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Round,
		border_color => [ 200, 0, 0, 255 ],
		( $args{background} ? ( background_color => $args{background} ) : () ),
	);
	$root->add_child( Term::Fabulous::Widget::Text->new( text => encode( 'UTF-8', $_ ), text_color => [ 255, 255, 255, 255 ] ) ) foreach @{ $args{lines} // ['Hello'] };
	return Term::Fabulous::Static->new( root => $root, width => $args{width} // 12, %{ $args{static} // {} } );
}

subtest 'plain text' => sub {
	my @lines = page( lines => [ 'Hello', 'Grüße' ] )->render_lines( colors => 0 );
	is \@lines, [ "╭──────────╮", "│ Hello    │", "│ Grüße    │", "╰──────────╯" ], 'border, padding and text, no rows beyond the content';
	is page( lines => ['Hello'] )->render_string( colors => 0 ), "╭──────────╮\n│ Hello    │\n╰──────────╯\n", 'render_string ends every row with a newline';
};

subtest 'trailing whitespace' => sub {
	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(3), height => sizing_fixed(1) } } );
	$root->add_child( Term::Fabulous::Widget::Text->new( text => 'ab' ) );
	is [ Term::Fabulous::Static->new( root => $root, width => 10 )->render_lines( colors => 0 ) ], ['ab'], 'default-background spaces at the end of a row are dropped';
	is [ Term::Fabulous::Static->new( root => $root, width => 3, trim_trailing_whitespace => 0 )->render_lines( colors => 0 ) ], ['ab '], 'rows are padded to the width when trimming is off';

	$root->background_color( [ 1, 2, 3, 255 ] );
	is [ Term::Fabulous::Static->new( root => $root, width => 10 )->render_lines( colors => 0 ) ], ['ab '], 'spaces in a colored background are kept';
};

subtest 'height' => sub {
	is scalar( my @rows = page( height => sizing_grow(), static => { height => 6 } )->render_lines( colors => 0 ) ), 6, 'a growing root fills the given height';
	is scalar( my @fit = page()->render_lines( colors => 0 ) ), 3, 'a fitting root ends after its content';
};

subtest 'colors' => sub {
	my ($line) = page( lines => ['Hi'] )->render_lines;
	is $line, "\e[38;2;200;0;0m╭──────────╮\e[0m", 'a row in one color is one SGR run, reset at the end';

	my @lines = page( lines => ['Hi'], background => [ 10, 20, 30, 255 ] )->render_lines;
	is $lines[1], "\e[38;2;200;0;0;48;2;10;20;30m│\e[0m\e[48;2;10;20;30m \e[0m\e[38;2;255;255;255;48;2;10;20;30mHi\e[0m\e[48;2;10;20;30m       \e[0m\e[38;2;200;0;0;48;2;10;20;30m│\e[0m",
		'foreground and background change per run, background spaces keep only the background';

	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(1), height => sizing_fixed(1) } }, background_color => [ 0, 0, 0, 255 ] );
	is [ Term::Fabulous::Static->new( root => $root, width => 1 )->render_lines ], ["\e[48;2;0;0;0m \e[0m"], 'opaque black is emitted as black, not as the default';

	$root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(2), height => sizing_fixed(1) } }, border_width => 1, border_style => Term::Fabulous::Enum::BorderStyle->Panel, border_color => [ 9, 9, 9, 255 ] );
	like [ Term::Fabulous::Static->new( root => $root, width => 2 )->render_lines ]->[0], qr/\e\[7;38;2;9;9;9m/, 'reverse video locations use SGR 7';
};

subtest 'scroll box' => sub {
	my $log = Term::Fabulous::Widget::ScrollBox->new(
		id           => 'log',
		layout       => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_fixed(4) } },
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Round,
	);
	$log->add_child( Term::Fabulous::Widget::Text->new( text => "line $_" ) ) foreach 1 .. 9;
	my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() } } );
	$root->add_child($_) foreach $log, Term::Fabulous::Widget::Text->new( text => 'below' );

	is [ Term::Fabulous::Static->new( root => $root, width => 8 )->render_lines( colors => 0 ) ], [ "╭──────╮", "│line 1│", "│line 2│", "╰──────╯", "below" ],
		'content beyond the box is clipped and the layout continues after it';
};

subtest 'print' => sub {
	my $output = '';
	open my $fh, '>', \$output or die $!;
	page( lines => ['Grüße'] )->print( fh => $fh );
	close $fh;
	is decode( 'UTF-8', $output ), "╭──────────╮\n│ Grüße    │\n╰──────────╯\n", 'UTF-8 bytes without colors on a non-terminal handle';
	like dies { page()->print( fh => 'not a handle' ) }, qr/fh must be an open file handle/, 'invalid handle dies';
};

subtest 'construction' => sub {
	like dies { Term::Fabulous::Static->new( root => Term::Fabulous::Widget::Box->new, width => 10, bogus => 1 ) }, qr/bogus/, 'unknown parameters die';
	is( Term::Fabulous::Static->new( root => Term::Fabulous::Widget::Box->new, width => 10 )->height, 4096, 'default height' );
	is( Term::Fabulous::Static->new( root => Term::Fabulous::Widget::Box->new, width => 10, height => 7 )->height, 7, 'explicit height' );
};

done_testing;
