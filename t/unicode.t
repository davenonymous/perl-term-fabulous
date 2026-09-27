use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FFI::Platypus 2;
use Term::Fabulous::Unicode qw(sanitize_text grapheme_clusters cluster_columns string_columns);

my $wcwidth = FFI::Platypus->new( api => 2, lib => [undef] )->function( wcwidth => ['wchar_t'] => 'int' );

subtest 'sanitize_text' => sub {
	is sanitize_text("a\tb"),              'a b',                                  'TAB becomes a space';
	is sanitize_text("\e]0;x\a"),          "\x{FFFD}]0;x\x{FFFD}",                 'ESC and BEL become U+FFFD';
	is sanitize_text("\x00\x1F\x7F\x85\x9F"), "\x{FFFD}" x 5,                      'C0, DEL and C1 become U+FFFD';
	is sanitize_text("\x{A0}\x{3042}"),    "\x{A0}\x{3042}",                       'printable text is untouched';
};

subtest 'widths follow the termbox2 rule' => sub {
	my $emoji_width = $wcwidth->call(0x2764) + $wcwidth->call(0xFE0F);
	is cluster_columns("\x{2764}\x{FE0F}"), $emoji_width < 1 ? 1 : $emoji_width, 'VS16 cluster uses wcswidth';
	is cluster_columns("e\x{301}"),         1, 'combining sequence';
	is cluster_columns("\x{200B}"),         1, 'zero-width cluster still occupies a cell';
	is cluster_columns("\x{FFFD}"),         1, 'replacement character';
	is [ grapheme_clusters("a\e") ], [ 'a', "\x{FFFD}" ], 'clusters are sanitized';
	is string_columns("ab\tc"),             4, 'string_columns sanitizes before measuring';
	is string_columns(''),                  0, 'empty string';
	like dies { cluster_columns('') }, qr/non-empty cluster/, 'empty cluster dies';
};

done_testing;
