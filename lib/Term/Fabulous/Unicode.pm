package Term::Fabulous::Unicode;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(sanitize_text grapheme_clusters cluster_columns string_columns terminal_is_utf8);

use FFI::Platypus 2;
use I18N::Langinfo qw(langinfo CODESET);
use Unicode::GCString;

use constant CLUSTER_CACHE_LIMIT => 4096;

FFI::Platypus->new( api => 2, lib => [undef] )->attach( [ wcwidth => '_libc_wcwidth' ] => ['wchar_t'] => 'int' );

my %columns_by_cluster;

sub sanitize_text ($text) {
	return $text =~ tr/\t\x00-\x08\x0A-\x1F\x7F-\x9F/ \x{FFFD}/r;
}

sub grapheme_clusters ($text) {
	return map { $_->as_string } @{ Unicode::GCString->new( sanitize_text($text) )->as_arrayref };
}

sub cluster_columns ($cluster) {
	my $columns = $columns_by_cluster{$cluster};
	return $columns if defined $columns;

	die "Term::Fabulous::Unicode: cluster_columns needs a non-empty cluster" unless length $cluster;
	%columns_by_cluster = () if keys(%columns_by_cluster) >= CLUSTER_CACHE_LIMIT;
	return $columns_by_cluster{$cluster} = _terminal_columns($cluster);
}

sub string_columns ($text) {
	my $columns = 0;
	$columns += cluster_columns($_) foreach grapheme_clusters($text);
	return $columns;
}

sub terminal_is_utf8 () {
	return langinfo(CODESET) =~ /\Autf-?8\z/i ? 1 : 0;
}

# Mirrors termbox2's tb_present(): a single codepoint advances by
# wcwidth(), a cluster by wcswidth() (the sum, or -1 as soon as one
# codepoint is -1), and any result below 1 advances by one column.
sub _terminal_columns ($cluster) {
	my $width = 0;
	foreach my $codepoint ( unpack 'W*', $cluster ) {
		my $codepoint_width = _libc_wcwidth($codepoint);
		if ( $codepoint_width < 0 ) {
			$width = -1;
			last;
		}
		$width += $codepoint_width;
	}
	return $width < 1 ? 1 : $width;
}

1;

__END__

=head1 NAME

Term::Fabulous::Unicode - Measure text in terminal cells, exactly as
termbox2 draws it

=head1 SYNOPSIS

	use Term::Fabulous::Unicode qw(sanitize_text grapheme_clusters cluster_columns string_columns terminal_is_utf8);

	my $columns  = string_columns("\x{3042}!");          # 3: a wide Hiragana letter and '!'
	my @clusters = grapheme_clusters("e\x{301}x");       # ("e\x{301}", "x"): e with a combining accent, x
	my $width    = cluster_columns("\x{1F600}");          # 2 under a UTF-8 locale
	my $safe     = sanitize_text("a\tb\e]0;title\a");      # "a b\x{FFFD}]0;title\x{FFFD}"

	warn "Wide characters will be misaligned\n" unless terminal_is_utf8();

=head1 DESCRIPTION

A terminal shows text in a grid of cells. Most characters take one
cell, but East Asian characters and most emoji take two, and combining
marks (such as an accent written after a letter) take none of their own.
Layout and drawing must agree on these widths, or everything after a
wide character shifts.

termbox2, which draws Term::Fabulous programs, moves its cursor by the
widths the C library's C<wcwidth> and C<wcswidth> functions report. This
module calls the same C<wcwidth> (through L<FFI::Platypus>) and applies
termbox2's C<wcswidth> rule for clusters of several code points in Perl,
so the widths it computes are exactly the widths termbox2 uses.
Term::Fabulous uses it to measure text for the layout and to draw text
and canvas cells; use it yourself when you need to know how wide a
string will be on screen, for example to pad or truncate a label.

All functions take and return Perl character strings (decoded text),
not UTF-8 encoded bytes.

=head2 Grapheme clusters

A grapheme cluster is what a reader sees as one character: a letter
plus its combining accents, a flag made of two regional indicator
symbols, an emoji with a skin tone modifier, and so on. Term::Fabulous
never splits a cluster: each one is drawn into one cell (plus the cells
to its right when it is wide). Clusters are found with
L<Unicode::GCString>.

=head2 The locale matters

C<wcwidth> follows the character type locale of the process
(C<LC_CTYPE>, usually set through C<LANG> or C<LC_ALL>). Under a UTF-8
locale such as C<en_US.UTF-8> or C<C.UTF-8>, wide characters are two
columns. Under a non-UTF-8 locale such as C<C>, every character counts
as one column, both here and in termbox2, and wide characters overlap on
screen. L<Term::Fabulous/run> warns when the locale is not UTF-8 (each
time it is called); see L</terminal_is_utf8>.

=head1 FUNCTIONS

Nothing is exported by default. Import the functions you need by name.

=head2 sanitize_text

	my $safe = sanitize_text($text);

Returns a copy of C<$text> that is safe to send to the terminal:

=over

=item *

TAB (U+0009) becomes a space.

=item *

Every other C0 control character (U+0000 to U+001F, including the line
breaks U+000A and U+000D and ESC U+001B), DEL (U+007F) and every C1
control character (U+0080 to U+009F) becomes U+FFFD REPLACEMENT
CHARACTER.

=item *

Everything else is unchanged.

=back

Without this, text from a file or a user could contain escape sequences
that change the terminal's title, colors or clipboard, or move the
cursor. Every text Term::Fabulous measures or draws is sanitized this
way, so you do not need to call it for widget text. Note that a line
break inside one line of text (one Text line, one canvas cell) is shown
as U+FFFD; split multi-line text into lines first. Text widgets do this
for you, because Clay breaks their text into lines at C<"\n"> before it
is drawn.

=head2 grapheme_clusters

	my @clusters = grapheme_clusters($text);

Sanitizes C<$text> (see L</sanitize_text>) and returns its grapheme
clusters as a list of character strings, in order. Returns the empty
list for the empty string.

=head2 cluster_columns

	my $columns = cluster_columns($cluster);

Returns the number of columns termbox2 advances for one grapheme
cluster: C<wcwidth> of its code point when it has one code point; for several
code points, the sum of their C<wcwidth> values, or -1 as soon as one
of them is -1 (the rule of C<wcswidth>); and at least 1
in any case. Zero-width and unprintable clusters therefore still occupy
one cell. The argument should be a single cluster as returned by
L</grapheme_clusters>. Dies if C<$cluster> is the empty string.

Results are cached per cluster; the cache is emptied when it reaches
4096 entries.

=head2 string_columns

	my $columns = string_columns($text);

Returns the number of columns C<$text> occupies on screen: the sum of
L</cluster_columns> over all L</grapheme_clusters> of C<$text>. Returns
0 for the empty string. This is the width Term::Fabulous reports to Clay
for layout.

=head2 terminal_is_utf8

	warn "Wide characters will be misaligned\n" unless terminal_is_utf8();

Returns 1 when the character set of the current locale
(C<langinfo(CODESET)>) is UTF-8, and 0 otherwise. Without a UTF-8
locale, termbox2 cannot place wide characters correctly.

=head1 SEE ALSO

L<Term::Fabulous::Manual/Wide characters and emoji>,
L<Term::Fabulous::Manual/Control characters>, L<Unicode::GCString>,
L<wcwidth(3)>.

=cut
