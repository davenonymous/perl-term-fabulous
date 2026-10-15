use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use Term::Fabulous::Lite;
use Term::Fabulous::Terminal::Memory;

# A memory terminal with the keys queued, as the user would press them.
sub terminal (@keys) {
	my $terminal = Term::Fabulous::Terminal::Memory->new( width => 60, height => 8 );
	foreach my $key (@keys) {
		if   ( length $key > 1 ) { $terminal->press_key($key) }
		else                     { $terminal->type_text($key) }
	}
	return $terminal;
}

subtest 'prompt' => sub {
	my $terminal = terminal( qw(A d a), 'Enter' );
	is TF->inline->prompt( 'Your name?', terminal => $terminal ), 'Ada', 'Enter answers with the text';
	my @lines = $terminal->lines;
	like $lines[0], qr/\AYour name\?/,                     'the question is the first row';
	like $lines[1], qr/Ada/,                               'the field the second';
	like $lines[2], qr/\AEnter answers, Escape cancels\./, 'the help line the third';

	is TF->inline->prompt( 'Your name?', value => 'Ada', terminal => terminal('Enter') ), 'Ada', 'value is the text to start with';
	is TF->inline->prompt( 'Your name?', terminal => terminal( 'x', 'Escape' ) ), undef, 'Escape cancels';

	my $invalid = terminal( 'Enter', '7', 'Enter' );
	is TF->inline->prompt( 'Port?', required => 1, validator => 'integer', terminal => $invalid ), '7', 'an invalid value is not an answer; the next valid one is';
	is TF->inline->prompt( 'Name?', help => 'Type it.', terminal => terminal('Enter') ), '', 'an empty value answers when nothing is required';

	like dies { TF->inline->prompt( 'Q', nope => 1 ) },
		qr/\ATerm::Fabulous::Lite::Inline: prompt does not accept nope \(known options: columns, help, mask, placeholder, required, terminal, theme, validator, value\)/, 'an unknown option dies';
	like dies { TF->inline->prompt('') }, qr/\ATerm::Fabulous::Lite::Inline: prompt needs a question, got ''/, 'a question is needed';
};

subtest 'confirm' => sub {
	is TF->inline->confirm( 'Sure?', terminal => terminal('Enter') ),                      1,     'Enter on the first button answers yes';
	is TF->inline->confirm( 'Sure?', default => 'cancel', terminal => terminal('Enter') ), 0,     'default cancel: Enter answers no';
	is TF->inline->confirm( 'Sure?', terminal => terminal('n') ),                          0,     'n answers no';
	is TF->inline->confirm( 'Sure?', terminal => terminal('y') ),                          1,     'y answers yes';
	is TF->inline->confirm( 'Sure?', terminal => terminal('Escape') ),                     undef, 'Escape cancels';

	my $terminal = terminal( 'Tab', 'Enter' );
	is TF->inline->confirm( 'Delete?', ok => 'Delete', cancel => 'Keep', terminal => $terminal ), 0, 'Tab moves to the second button';
	like join( "\n", $terminal->lines ),                          qr/Delete.*Keep/,                                      'the buttons show their labels';
	like dies { TF->inline->confirm( 'Q', default => 'maybe' ) }, qr/confirm default must be ok or cancel, got 'maybe'/, 'a bad default dies';
};

subtest 'choose' => sub {
	my @options = ( [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ] );
	is TF->inline->choose( 'Size?', options => \@options, terminal => terminal('Enter') ),                   's',     'Enter chooses the first option';
	is TF->inline->choose( 'Size?', options => \@options, value => 'm', terminal => terminal('Enter') ),     'm',     'value is the option chosen at the start';
	is TF->inline->choose( 'Size?', options => \@options, terminal => terminal( 'Down', 'Down', 'Enter' ) ), 'l',     'Down moves';
	is TF->inline->choose( 'Size?', options => \@options, terminal => terminal('Escape') ),                  undef,   'Escape cancels';
	is TF->inline->choose( 'Color?', options => [qw(Red Green)], terminal => terminal( 'Down', 'Enter' ) ),  'Green', 'a plain label is its own value';

	my $terminal = terminal('Enter');
	TF->inline->choose( 'Size?', options => \@options, terminal => $terminal );
	my @lines = $terminal->lines;
	is scalar @lines, 5, 'the rows: the question, one per option, the help line';
	like $lines[2], qr/Medium/, 'each option is a row';

	like dies { TF->inline->choose('Size?') },                  qr/\ATerm::Fabulous::Lite::Inline: choose needs options to choose from/, 'options are needed';
	like dies { TF->inline->choose( 'Size?', options => [] ) }, qr/choose needs at least one option/,                                    'and at least one';
};

done_testing;
