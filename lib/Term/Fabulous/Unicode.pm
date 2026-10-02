package Term::Fabulous::Unicode;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(sanitize_text grapheme_clusters cluster_columns string_columns terminal_is_utf8);

use I18N::Langinfo qw(langinfo CODESET);
use Term::Fabulous::Termbox qw(tb_cluster_width);
use Unicode::GCString;

use constant CLUSTER_CACHE_LIMIT => 4096;

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

# Mirrors termbox2's tb_present(): a cluster advances by tb_cluster_width()
# (its widest codepoint, forced to 1 by a text presentation selector and
# to 2 by an emoji presentation selector, a zero-width joiner or a pair of
# regional indicators), and any result below 1 advances by one column.
sub _terminal_columns ($cluster) {
	my $width = tb_cluster_width($cluster);
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
widths its own Unicode tables report: one codepoint by its C<tb_wcwidth>,
a cluster of several codepoints by its C<tb_cluster_width>, which takes
the widest codepoint and then lets a variation selector, a zero-width
joiner or a pair of regional indicators decide between text (1) and
emoji (2) presentation. This module calls those same functions through
L<Term::Fabulous::Termbox>, so the widths it computes are exactly the
widths termbox2 uses, on every platform. Term::Fabulous uses it to
measure text for the layout and to draw text and canvas cells; use it
yourself when you need to know how wide a string will be on screen, for
example to pad or truncate a label.

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

The widths do not depend on the locale, but the terminal does: termbox2
sends UTF-8, and a terminal running under a non-UTF-8 locale such as
C<C> shows the bytes of a wide character as several narrow ones, so
everything after it shifts. L<Term::Fabulous/run> warns when the
locale's character set is not UTF-8 (each time it is called); see
L</terminal_is_utf8>.

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
cluster: L<Term::Fabulous::Termbox/tb_cluster_width> of its code
points (the widest one; 1 when a variation selector 15 asks for text
presentation, 2 when a variation selector 16, a zero-width joiner or a
pair of regional indicators asks for emoji presentation), and at least 1
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
L<Term::Fabulous::Manual/Control characters>, L<Term::Fabulous::Termbox>,
L<Unicode::GCString>.

=cut
