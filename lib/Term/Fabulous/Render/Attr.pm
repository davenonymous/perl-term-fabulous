package Term::Fabulous::Render::Attr;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(color_attr clay_color);

use Termbox 2 qw(TB_DEFAULT);

BEGIN {
	die "Term::Fabulous::Render::Attr: the termbox2 library was built without truecolor support (TB_OPT_TRUECOLOR); Term::Fabulous needs 24-bit colors\n"
		unless $Termbox::TRUECOLOR;
}

use Termbox 2 qw(TB_TRUECOLOR_BLACK);

use Term::Fabulous::Color;

use constant CACHE_LIMIT => 4096;

my %attr_by_rgba;
my %color_by_clay_rgba;

sub color_attr ($color) {
	my $rgba = $color->rgba_int;
	my $attr = $attr_by_rgba{$rgba};
	return $attr if defined $attr;

	%attr_by_rgba = () if keys(%attr_by_rgba) >= CACHE_LIMIT;
	return $attr_by_rgba{$rgba} = _termbox_attr($color);
}

sub clay_color ($clay_rgba) {
	die "Term::Fabulous::Render::Attr: a Clay color must be a hash reference with r, g, b, a"
		unless ref $clay_rgba eq 'HASH';

	my $key   = join ',', map { $_ // '' } @{$clay_rgba}{qw(r g b a)};
	my $color = $color_by_clay_rgba{$key};
	return $color if defined $color;

	%color_by_clay_rgba = () if keys(%color_by_clay_rgba) >= CACHE_LIMIT;
	return $color_by_clay_rgba{$key} = Term::Fabulous::Color->new( color => $clay_rgba );
}

# termbox2 in truecolor mode reads 0x000000 as "terminal default", so opaque
# black needs its dedicated flag; alpha 0 means "no color" and maps to the
# terminal default on purpose.
sub _termbox_attr ($color) {
	return TB_DEFAULT if $color->alpha == 0;

	my $rgb = $color->rgb_int;
	return $rgb == 0 ? TB_TRUECOLOR_BLACK : $rgb;
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Attr - Map colors to termbox2 truecolor attributes

=head1 SYNOPSIS

	use Term::Fabulous::Render::Attr qw(color_attr clay_color);

	my $fg = color_attr( Term::Fabulous::Color->rgb(0, 0, 0) );   # TB_TRUECOLOR_BLACK
	my $bg = color_attr( clay_color( $command->{renderData}{backgroundColor} ) );

=head1 DESCRIPTION

Converts L<Term::Fabulous::Color> values into the C<uintattr_t> values
termbox2 expects in C<TB_OUTPUT_TRUECOLOR> mode. Loading the module dies
if the termbox2 library was built without truecolor support.

Nothing is exported by default.

=head1 FUNCTIONS

=head2 color_attr

	my $attr = color_attr($color);

Takes a L<Term::Fabulous::Color> and returns:

=over

=item * C<TB_DEFAULT> (the terminal's default color) when alpha is 0;

=item * C<TB_TRUECOLOR_BLACK> for opaque black (termbox2 would otherwise
read C<0x000000> as the default color);

=item * the packed C<0xRRGGBB> value otherwise.

=back

Alpha values between 1 and 254 are treated as opaque; there is no
blending. Results are memoized by C<rgba_int> (bounded cache).

=head2 clay_color

	my $color = clay_color( { r => 20, g => 25, b => 35, a => 255 } );

Returns the L<Term::Fabulous::Color> for a Clay render-data color hash.
Colors are memoized by their channel values (bounded cache), so
rendering a frame does not re-parse and re-validate colors it has seen
before. Dies unless given a hash reference; invalid channels die in
L<Term::Fabulous::Color>.

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Color>.

=cut
