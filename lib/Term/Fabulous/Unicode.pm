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

Term::Fabulous::Unicode - Terminal cell widths that agree with termbox2

=head1 SYNOPSIS

	use Term::Fabulous::Unicode qw(sanitize_text grapheme_clusters cluster_columns string_columns terminal_is_utf8);

	my $safe    = sanitize_text("a\tb\e]0;title\a");   # "a b\x{FFFD}]0;title\x{FFFD}"
	my @cells   = grapheme_clusters("e\x{301}x");       # ("e\x{301}", "x")
	my $columns = string_columns("\x{3042}!");          # 3
	my $width   = cluster_columns("\x{2764}\x{FE0F}");  # whatever termbox2 advances

	warn "wide characters will misalign\n" unless terminal_is_utf8();

=head1 DESCRIPTION

Text layout (Clay's measure callback) and text rendering must agree
with termbox2 on how many columns every piece of text occupies, or rows
shift. termbox2 advances its cursor with the C library's C<wcwidth> /
C<wcswidth>, so this module uses exactly the same functions (through
L<FFI::Platypus>) and the same rules. The widths therefore follow the
process locale (C<LC_CTYPE>): under a non-UTF-8 locale every non-ASCII
character counts as one column, both here and in termbox2.

All functions take and return Perl character strings (decoded text).

=head1 FUNCTIONS

Nothing is exported by default.

=head2 sanitize_text

	my $safe = sanitize_text($chars);

Returns a copy of C<$chars> that is safe to hand to the terminal: TAB
becomes a space, every other C0 control (U+0000..U+001F), DEL (U+007F)
and every C1 control (U+0080..U+009F) becomes U+FFFD. This keeps escape
sequences in widget text from reaching the terminal and keeps cursor
movement predictable. Measuring and rendering both apply it.

=head2 grapheme_clusters

	my @clusters = grapheme_clusters($chars);

Sanitizes C<$chars> and splits it into grapheme clusters
(L<Unicode::GCString>), returned as plain strings. Each cluster occupies
one terminal cell (plus continuation cells when it is wide).

=head2 cluster_columns

	my $columns = cluster_columns($cluster);

Columns termbox2 advances for one cluster: C<wcwidth> for a single
codepoint, C<wcswidth> for several, and at least 1 (zero-width and
unprintable clusters still occupy one cell). Results are memoized; the
cache is cleared when it reaches 4096 entries. Dies on an empty string.

=head2 string_columns

	my $columns = string_columns($chars);

Sum of L</cluster_columns> over L</grapheme_clusters> of C<$chars>
(0 for the empty string).

=head2 terminal_is_utf8

True when the locale's character set (C<langinfo(CODESET)>) is UTF-8.
Without it, termbox2 cannot place wide characters correctly.

=head1 SEE ALSO

L<Term::Fabulous>, L<Unicode::GCString>, L<wcwidth(3)>.

=cut
