use v5.24;
use warnings;
use utf8;

use Test2::V0;

use Term::Fabulous::Widget::Text;

subtest 'text and color' => sub {
	my $text = Term::Fabulous::Widget::Text->new( id => 'title', text => 'Grüße', text_color => '#ff8000' );
	is [ $text->id, $text->text, $text->text_color ], [ 'title', 'Grüße', [ 255, 128, 0, 255 ] ], 'a color string becomes [r, g, b, a]';
	$text->text_color('rgb(1, 2, 3)');
	is $text->text_color, [ 1, 2, 3, 255 ], 'also when set later';
	$text->text('Hallo');
	is $text->text, 'Hallo', 'the text can change';
	like dies { Term::Fabulous::Widget::Text->new( text => 'x', text_color => 'nope' ) }, qr/\ATerm::Fabulous::Widget::Text: text_color must be a color, got 'nope'/, 'an invalid color dies';
	like dies { $text->text_color('nope') }, qr/\ATerm::Fabulous::Widget::Text: text_color must be a color, got 'nope'/, 'also when set later';
	is $text->text_color, [ 1, 2, 3, 255 ], 'and leaves the color as it was';
};

done_testing;
