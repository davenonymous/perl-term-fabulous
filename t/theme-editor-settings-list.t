use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use FindBin qw($Bin);
use lib "$Bin/lib";
use InputTest;
use Term::Fabulous::ThemeEditor::SettingsList;

# A settings list on the 40x20 memory terminal of InputTest, with the
# rows given and a clock for the UI if the first argument is a code
# reference; the ids it activated and the cursor moves it reported.
sub settings_list (@rows) {
	my @options = ref $rows[0] eq 'CODE' ? { clock => shift @rows } : ();
	my %seen    = ( activated => [], cursor => [] );
	my $list    = Term::Fabulous::ThemeEditor::SettingsList->new(
		id          => 'settings',
		on_activate => sub ($id) { push @{ $seen{activated} }, $id; return },
		on_cursor   => sub ($id) { push @{ $seen{cursor} },    $id; return },
	);
	$list->rows( \@rows );
	my $ui = layout_ui( $list, @options );
	return ( $list, $ui, \%seen );
}

# The screen line that shows the setting.
sub line_of ( $ui, $setting ) {
	$ui->step;
	my ($line) = grep { /\b\Q$setting\E\b/ } $ui->terminal->lines;
	return $line;
}

# A click on the terminal at a cell of the screen.
sub click_at ( $ui, $x, $y ) {
	$ui->terminal->click( $x, $y );
	$ui->step;
	return;
}

subtest 'a cut value keeps its clusters whole' => sub {
	my ( $list, $ui ) = settings_list( { id => 'theme.name', setting => 'name', value => "abcdefg\x{2764}\x{FE0F}ijk", origin => 'file', set => 1 } );
	my $line = line_of( $ui, 'name' );
	like $line,   qr/ abcdefg~ /, 'the emoji and its variation selector go together';
	unlike $line, qr/\x{2764}/,   'no heart without its selector is left';
};

subtest 'a double click on a setting activates it' => sub {
	my $now = 1000;
	my ( $list, $ui, $seen ) = settings_list( sub { $now }, map { { id => $_, setting => $_, value => 'on', origin => 'file' } } qw(alpha beta) );
	click_at( $ui, 10, 1 );
	$now += 0.3;
	click_at( $ui, 10, 1 );
	is $seen->{activated}, ['alpha'], 'two clicks 0.3 seconds apart';
	click_at( $ui, 10, 2 );
	$now += 0.5;
	click_at( $ui, 10, 2 );
	is $seen->{activated}, ['alpha'], 'two clicks 0.5 seconds apart are two clicks';
	is $list->cursor,      'beta',    'that put the cursor on the row';
};

done_testing;
