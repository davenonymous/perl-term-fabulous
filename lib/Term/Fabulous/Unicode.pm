package Term::Fabulous::Unicode;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Exporter 'import';
our @EXPORT_OK = qw(cluster_columns string_columns);

use Unicode::GCString;
use Unicode::UCD qw(charprop);

my %is_wide_emoji_cp;

sub _cp_is_wide_emoji ($cp) {
	return $is_wide_emoji_cp{$cp} //=
		((charprop($cp, 'Emoji_Presentation') // '') eq 'Yes' ? 1 : 0);
}

sub cluster_columns ($cluster) {
	my $cols = $cluster->columns;
	return $cols if $cols >= 2;

	my @cps = map { ord } split //, "$cluster";
	for my $cp (@cps) {
		return 2 if _cp_is_wide_emoji($cp);
	}
	return 2 if grep { $_ == 0xFE0F } @cps;
	return $cols;
}

sub string_columns ($str) {
	return 0 unless length $str;
	my $gc = Unicode::GCString->new($str);
	my $total = 0;
	$total += cluster_columns($gc->item($_)) for 0 .. $gc->length - 1;
	return $total;
}

1;
