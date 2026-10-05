use v5.32;
use warnings;
use utf8;

use Test2::V0;

use Clay::XS qw(sizing_fixed);
use Term::Fabulous::Layout;
use Term::Fabulous::Static;
use Term::Fabulous::Termbox qw(TB_BOLD TB_UNDERLINE TB_DEFAULT);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::RichText;

my $plain = { set => 0, clear => 0, color => undef, background => undef };

subtest 'spans and markup' => sub {
	my $text = Term::Fabulous::Widget::RichText->new( text => 'error: file', spans => [ [ 0, 5, 'bold red' ], [ 7, 11, { set => TB_UNDERLINE } ] ] );
	is $text->text,   'error: file',                                                                                                       'a Text underneath';
	is $text->spans,  [ [ 0, 5, { %$plain, set => TB_BOLD, color => [ 255, 0, 0, 255 ] } ], [ 7, 11, { %$plain, set => TB_UNDERLINE } ] ], 'spans with normalized styles';
	is $text->markup, undef,                                                                                                               'no markup when given as spans';

	my $marked = Term::Fabulous::Widget::RichText->new( markup => 'Press [bold]Enter[/]' );
	is [ $marked->text, $marked->markup ], [ 'Press Enter', 'Press [bold]Enter[/]' ],  'markup gives the text and keeps itself';
	is $marked->spans,                     [ [ 6, 11, { %$plain, set => TB_BOLD } ] ], 'and the spans';

	$marked->markup('[underline]a[/]b');
	is [ $marked->text, $marked->spans ], [ 'ab', [ [ 0, 1, { %$plain, set => TB_UNDERLINE } ] ] ], 'markup can be set later';
	$marked->text('plain');
	is [ $marked->text, $marked->spans, $marked->markup ], [ 'plain', [], undef ], 'setting the text drops the spans and the markup';
	ref_is $marked->stylize( 'bold', 1, 3 ), $marked, 'stylize chains';
	is $marked->stylize('on #000000')->spans, [ [ 1, 3, { %$plain, set => TB_BOLD } ], [ 0, 5, { %$plain, background => [ 0, 0, 0, 255 ] } ] ], 'stylize appends, the whole text by default';
	is $marked->clear_spans->spans,           [],                                                                                               'clear_spans';
};

subtest 'errors' => sub {
	like dies { Term::Fabulous::Widget::RichText->new( markup => '[bold]x', text => 'x' ) },             qr/markup cannot be given together with text or spans/,  'markup or text';
	like dies { Term::Fabulous::Widget::RichText->new( markup => '[shiny]x' ) },                         qr/unknown style word 'shiny'/,                          'invalid markup';
	like dies { Term::Fabulous::Widget::RichText->new( spans => 'bold' ) },                              qr/spans must be an array reference/,                    'spans is an array';
	like dies { Term::Fabulous::Widget::RichText->new( spans => [ [ 0, 1 ] ] ) },                        qr/a span is \[start, end, style\]/,                     'a span has three parts';
	like dies { Term::Fabulous::Widget::RichText->new( text => 'ab', spans => [ [ 1, 0, 'bold' ] ] ) },  qr/span end 0 lies before its start 1/,                  'end before start';
	like dies { Term::Fabulous::Widget::RichText->new( text => 'ab', spans => [ [ 0, 3, 'bold' ] ] ) },  qr/span end 3 lies past the text \(2 characters\)/,      'past the end';
	like dies { Term::Fabulous::Widget::RichText->new( text => 'ab', spans => [ [ -1, 1, 'bold' ] ] ) }, qr/span start must be a non-negative integer, got '-1'/, 'negative start';
	my $text = Term::Fabulous::Widget::RichText->new( text => 'ab' );
	like dies { $text->stylize( 'shiny', 0, 1 ) }, qr/unknown style word 'shiny'/, 'stylize checks the style';
	like dies { $text->markup('[/]') },            qr/without an open tag/,        'markup checks the markup';
	is [ $text->text, $text->spans ], [ 'ab', [] ], 'and leaves the widget as it was';
};

subtest 'line_styles' => sub {
	my $text = Term::Fabulous::Widget::RichText->new( text => 'abcdefgh', spans => [ [ 2, 6, 'bold #ff0000' ], [ 4, 8, 'not bold on #0000ff' ] ] );
	is $text->line_styles( 0, 8 ),
		[ [ 2, 0, 0, undef, undef ], [ 2, TB_BOLD, 0, 0xFF0000, undef ], [ 2, 0, TB_BOLD, 0xFF0000, 0x0000FF ], [ 2, 0, TB_BOLD, undef, 0x0000FF ] ],
		'runs at every span boundary; a later span clears what an earlier one set';
	is $text->line_styles( 3, 2 ), [ [ 1, TB_BOLD, 0, 0xFF0000, undef ], [ 1, 0, TB_BOLD, 0xFF0000, 0x0000FF ] ], 'a line in the middle gets its part of the runs';
	is $text->line_styles( 6, 0 ), [],                                                                            'an empty line has no runs';
	my $unstyled = Term::Fabulous::Widget::RichText->new( text => 'ab' );
	is $unstyled->line_styles( 0, 2 ), [ [ 2, 0, 0, undef, undef ] ], 'one plain run without spans';
	my $default = Term::Fabulous::Widget::RichText->new( text => 'ab', spans => [ [ 0, 2, 'default' ] ] );
	is $default->line_styles( 0, 2 ), [ [ 2, 0, 0, TB_DEFAULT, undef ] ], 'default is the terminal color, not an untouched one';
};

subtest 'wrapped lines keep their styles' => sub {
	my $root = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(7), height => sizing_fixed(2) } } );
	$root->add_child( Term::Fabulous::Widget::RichText->new( markup => 'ab [bold]cd ef[/] gh', text_color => '#ffffff' ) );
	my $ui = Term::Fabulous::Static->new( root => $root, width => 7, height => 2 );
	$ui->draw;
	my @lines = $ui->render_lines( colors => 1 );
	is $lines[0], "\e[38;2;255;255;255mab \e[0m\e[1;38;2;255;255;255mcd\e[0m", 'the first line ends in the bold span';
	is $lines[1], "\e[1;38;2;255;255;255mef\e[0m\e[38;2;255;255;255m gh\e[0m", 'the second line starts in it';
};

subtest 'a KDL layout sets markup' => sub {
	my $text = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::RichText as RichText
RichText "hint" {
	markup "Press [bold]Enter[/]"
	italic #true
}
KDL
	is [ $text->id, $text->text, $text->italic ], [ 'hint', 'Press Enter', 1 ],               'markup and the Text properties';
	is $text->spans,                              [ [ 6, 11, { %$plain, set => TB_BOLD } ] ], 'the spans';
	like dies { Term::Fabulous::Layout->new( string => "use Term::Fabulous::Widget::RichText as RichText\nRichText { markup 1 }" )->build }, qr/'markup' needs a string argument/, 'markup is a string';
};

done_testing;
