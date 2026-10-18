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
# rows given; the ids it activated and the cursor moves it reported.
sub settings_list (@rows) {
	my %seen = ( activated => [], cursor => [] );
	my $list = Term::Fabulous::ThemeEditor::SettingsList->new(
		id          => 'settings',
		on_activate => sub ($id) { push @{ $seen{activated} }, $id; return },
		on_cursor   => sub ($id) { push @{ $seen{cursor} },    $id; return },
	);
	$list->rows( \@rows );
	my $ui = layout_ui($list);
	return ( $list, $ui, \%seen );
}

# The screen line that shows the setting.
sub line_of ( $ui, $setting ) {
	$ui->step;
	my ($line) = grep { /\b\Q$setting\E\b/ } $ui->terminal->lines;
	return $line;
}

subtest 'a cut value keeps its clusters whole' => sub {
	my ( $list, $ui ) = settings_list( { id => 'theme.name', setting => 'name', value => "abcdefg\x{2764}\x{FE0F}ijk", origin => 'file', set => 1 } );
	my $line = line_of( $ui, 'name' );
	like $line,   qr/ abcdefg~ /, 'the emoji and its variation selector go together';
	unlike $line, qr/\x{2764}/,   'no heart without its selector is left';
};

done_testing;
