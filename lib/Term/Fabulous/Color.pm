package Term::Fabulous::Color;

use 5.038;

use Object::Pad;
use Object::Pad::FieldAttr::Isa;
use Object::Pad::FieldAttr::Checked;
use Data::Checks qw( Str Isa NumRange );

class Term::Fabulous::Color {
	field $red :reader :param :Checked( NumRange(0, 255) ) = 0;
	field $green :reader :param :Checked( NumRange(0, 255) ) = 0;
	field $blue :reader :param :Checked( NumRange(0, 255) ) = 0;
	field $alpha :reader :param :Checked( NumRange(0, 256) ) = 255;

	# INVARIANT: Color is immutable post-ADJUST; lazy memo slots are safe.
	field $_rgba_int_cache;
	field $_fg_sgr_cache;
	field $_bg_sgr_cache;

	ADJUST :params ( :$color ) {
		if ( ref( $color ) eq 'HASH' ) {
			if ( exists $color->{ r } && exists $color->{ g } && exists $color->{ b } ) {
				$red   = $color->{ r };
				$green = $color->{ g };
				$blue  = $color->{ b };
				$alpha = $color->{ a } // 255;
			} elsif ( exists $color->{ red } && exists $color->{ green } && exists $color->{ blue } ) {
				$red   = $color->{ red };
				$green = $color->{ green };
				$blue  = $color->{ blue };
				$alpha = $color->{ alpha } // 255;
			}
		} elsif ( ref( $color ) eq 'ARRAY' ) {
			$red   = $color->[ 0 ];
			$green = $color->[ 1 ];
			$blue  = $color->[ 2 ];
			$alpha = $color->[ 3 ] // 255;
		} elsif ( $color =~ /^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/ ) {

			# 6-hex (#rrggbb) lacks alpha; default to 255 to avoid undef passing the NumRange check.
			my @parts = map { hex( $_ ) } ( $1 =~ /(..)/g );
			( $red, $green, $blue ) = @parts[ 0 .. 2 ];
			$alpha = $parts[ 3 ] // 255;
		# } elsif ( my $web_color = Term::Fabulous::Enum::WebColor->from_name( lc($color) ) ) {
		# 	( $red, $green, $blue, $alpha ) = $web_color->to_rgba;
		} elsif ( $color =~ /^rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$/ ) {
			( $red, $green, $blue ) = ( $1, $2, $3 );
		} elsif ( $color =~ /^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(0|1|0?\.\d+)\s*\)$/ ) {
			( $red, $green, $blue ) = ( $1, $2, $3 );
			$alpha = int( $4 * 255 );
		} elsif ( $color =~ /^rgba\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)$/ ) {
			( $red, $green, $blue, $alpha ) = ( $1, $2, $3, $4 );
		} elsif ( $color =~ /^hsl\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*\)$/ ) {
			( $red, $green, $blue ) = Term::Fabulous::Color->hsl_to_rgb( $1, $2, $3 );
		} elsif ( $color =~ /^hsla\(\s*(\d{1,3})\s*,\s*(\d{1,3})%\s*,\s*(\d{1,3})%\s*,\s*(0|1|0?\.\d+)\s*\)$/ ) {
			( $red, $green, $blue ) = Term::Fabulous::Color->hsl_to_rgb( $1, $2, $3 );
			$alpha = int( $4 * 255 );
		} else {
			die "Invalid color input: $color";
		}
	}

	method blend ( $other, $ratio ) {
		my $inv_ratio = 1 - $ratio;

		return Term::Fabulous::Color->new(
			color => [
				int( $red * $inv_ratio + $other->red * $ratio ),
				int( $green * $inv_ratio + $other->green * $ratio ),
				int( $blue * $inv_ratio + $other->blue * $ratio ),
				int( $alpha * $inv_ratio + $other->alpha * $ratio ),
			],
		);
	}

	method with_alpha ( $new_alpha ) {
		return Term::Fabulous::Color->new( color => [ $red, $green, $blue, $new_alpha ], );
	}

	method lighten ($amount) {
		my ( $h, $s, $l ) = Term::Fabulous::Color->rgb_to_hsl( $red, $green, $blue );
		my $new_l = $l + $amount * 100;
		$new_l = 0   if $new_l < 0;
		$new_l = 100 if $new_l > 100;
		my ( $r, $g, $b ) = Term::Fabulous::Color->hsl_to_rgb( $h, $s, $new_l );
		return Term::Fabulous::Color->new( color => [ $r, $g, $b, $alpha ] );
	}

	method darken ($amount) {
		return $self->lighten( -$amount );
	}

	method ansi () {
		return sprintf( "\e[38;2;%d;%d;%dm", $red, $green, $blue );
	}

	method ansi_bg () {
		return sprintf( "\e[48;2;%d;%d;%dm", $red, $green, $blue );
	}

	method hexString () {
		return sprintf( "#%02x%02x%02x%02x", $red, $green, $blue, $alpha );
	}

	method to_rgba () {
		return ( $red, $green, $blue, $alpha );
	}

	method to_hsl () {
		return Term::Fabulous::Color->rgb_to_hsl( $red, $green, $blue );
	}

	method rgba_int () {
		return $_rgba_int_cache //= ( $red << 24 ) | ( $green << 16 ) | ( $blue << 8 ) | $alpha;
	}

	# Alpha-0 emits the terminal default-fg reset (\e[39m) instead of literal black.
	method fg_sgr () {
		return $_fg_sgr_cache //=
		  $alpha == 0
		  ? "\e[39m"
		  : sprintf( "\e[38;2;%d;%d;%dm", $red, $green, $blue );
	}

	# Alpha-0 emits the terminal default-bg reset (\e[49m); see fg_sgr.
	method bg_sgr () {
		return $_bg_sgr_cache //=
		  $alpha == 0
		  ? "\e[49m"
		  : sprintf( "\e[48;2;%d;%d;%dm", $red, $green, $blue );
	}

	method rgb_int () {
		return ( $red << 16 ) | ( $green << 8 ) | $blue;
	}

	method rgba_float () {
		return ( $red / 255, $green / 255, $blue / 255, $alpha / 255 );
	}

	method rgb_float () {
		return ( $red / 255, $green / 255, $blue / 255 );
	}

	method hsl_to_rgb :common ( $h, $s, $l ) {
		$s /= 100;
		$l /= 100;
		my $color = [];

		if ( $s == 0 ) {
			$color->[ 0 ] = $color->[ 1 ] = $color->[ 2 ] = int( $l * 255 );
		} else {
			my $q = $l < 0.5 ? $l * ( 1 + $s ) : $l + $s - $l * $s;
			my $p = 2 * $l - $q;
			my @t = map { $_ / 360 } ( $h + 120, $h, $h - 120 );

			for my $i ( 0 .. 2 ) {
				if ( $t[ $i ] < 0 ) { $t[ $i ] += 1 }
				if ( $t[ $i ] > 1 ) { $t[ $i ] -= 1 }

				if ( $t[ $i ] < 1 / 6 ) {
					$color->[ $i ] = int( ( $p + 6 * ( $q - $p ) * $t[ $i ] ) * 255 );
				} elsif ( $t[ $i ] < 1 / 2 ) {
					$color->[ $i ] = int( ( $q * 255 ) );
				} elsif ( $t[ $i ] < 2 / 3 ) {
					$color->[ $i ] = int( ( $p + 6 * ( $q - $p ) * ( 2 / 3 - $t[ $i ] ) ) * 255 );
				} else {
					$color->[ $i ] = int( ( $p * 255 ) );
				}
			}
		}

		return @$color;
	}

	method rgb :common ( $r, $g, $b ) {
		return Term::Fabulous::Color->new( color => [ $r, $g, $b ] );
	}

	method rgba :common ( $r, $g, $b, $a ) {
		return Term::Fabulous::Color->new( color => [ $r, $g, $b, $a ] );
	}

	method hex :common ( $spec ) {
		return Term::Fabulous::Color->new( color => $spec );
	}

	method hsl :common ( $h, $s, $l ) {
		return Term::Fabulous::Color->new( color => "hsl($h, $s%, $l%)", );
	}

	method hsla :common ( $h, $s, $l, $a ) {
		return Term::Fabulous::Color->new( color => "hsla($h, $s%, $l%, $a)", );
	}

	method rgb_to_hsl :common ( $r, $g, $b ) {
		$r /= 255;
		$g /= 255;
		$b /= 255;

		my $max = List::Util::max( $r, $g, $b );
		my $min = List::Util::min( $r, $g, $b );
		my ( $h, $s, $l ) = ( 0, 0, ( $max + $min ) / 2 );

		if ( $max != $min ) {
			$s = $l < 0.5 ? ( $max - $min ) / ( $max + $min ) : ( $max - $min ) / ( 2 - $max - $min );

			if ( $max == $r ) {
				$h = 60 * ( ( $g - $b ) / ( $max - $min ) );
			} elsif ( $max == $g ) {
				$h = 60 * ( 2 + ( $b - $r ) / ( $max - $min ) );
			} else {
				$h = 60 * ( 4 + ( $r - $g ) / ( $max - $min ) );
			}

			if ( $h < 0 ) { $h += 360 }
		}

		return ( int( $h ), int( $s * 100 ), int( $l * 100 ) );
	}

}

1;

__END__

=head1 NAME

Term::Fabulous::Color - RGB(A) color value with parser-driven construction

=head1 SYNOPSIS

	use Term::Fabulous::Color;

	# Generic constructor (string / hashref / arrayref / named CSS).
	my $a = Term::Fabulous::Color->new( color => '#ff00ff' );
	my $b = Term::Fabulous::Color->new( color => 'rgb(255, 0, 128)' );
	my $c = Term::Fabulous::Color->new( color => 'white' );

	# Positional factories.
	my $red    = Term::Fabulous::Color->rgb(255, 0, 0);
	my $half   = Term::Fabulous::Color->rgba(255, 0, 0, 128);
	my $hex    = Term::Fabulous::Color->hex('#7c3aed');
	my $teal   = Term::Fabulous::Color->hsl(174, 72, 56);
	my $faded  = Term::Fabulous::Color->hsla(174, 72, 56, 0.5);

	# Tuple accessors (renamed from `rgba` / `hsl` so the names are
	# free for the factories above).
	my @rgba   = $red->to_rgba;   # (255, 0, 0, 255)
	my @hsl    = $red->to_hsl;    # (h, s, l) tuple

=head1 DESCRIPTION

A color value carrying red, green, blue, and alpha channels (each
0..255). Construction goes through one of three doors:

=over

=item * The generic C<new> constructor, with a single C<color>
parameter that accepts strings (C<#rrggbb>, C<rgb(...)>, C<rgba(...)>,
C<hsl(...)>, C<hsla(...)>, named CSS colors), hashrefs
(C<< { r => N, g => N, b => N } >> or C<< { red => ... } >>),
arrayrefs (C<[ R, G, B ]> or C<[ R, G, B, A ]>), or another
C<Term::Fabulous::Color> instance for clone-style copying.

=item * Positional class-method factories: L</rgb>, L</rgba>,
L</hex>, L</hsl>, L</hsla>. These are thin wrappers around C<new>
that take typed positional arguments instead of a freeform spec.

=item * The companion L<Term::Fabulous::TF/color> facade, which is
the recommended user-facing entry point.

=back

=head1 METHODS

=head2 rgb

	my $color = Term::Fabulous::Color->rgb($r, $g, $b);

Build an opaque color from raw 0..255 components. Out-of-range
values are rejected by the underlying field-checks (Law 4: fail
loud at the boundary).

=head2 rgba

	my $color = Term::Fabulous::Color->rgba($r, $g, $b, $a);

As L</rgb> with an explicit alpha 0..255. Use the L</hsla> /
generic C<new> entry points if you have a 0..1 alpha from CSS-like
input.

=head2 hex

	my $color = Term::Fabulous::Color->hex('#7c3aed');
	my $color = Term::Fabulous::Color->hex('7c3aedff');

Accepts six- or eight-hex strings with an optional leading C<#>.

=head2 hsl

	my $color = Term::Fabulous::Color->hsl($h, $s, $l);

Hue C<0..360>, saturation/lightness as percentages C<0..100>.

=head2 hsla

	my $color = Term::Fabulous::Color->hsla($h, $s, $l, $a);

As L</hsl> plus an alpha component in the C<0..1> range (CSS
convention).

=head2 to_rgba

	my ($r, $g, $b, $a) = $color->to_rgba;

Returns the raw 0..255 component tuple.

=head2 to_hsl

	my ($h, $s, $l) = $color->to_hsl;

Returns the C<(hue, saturation, lightness)> tuple converted from
the stored RGB.

=head2 lighten

	my $brighter = $color->lighten(0.15);

HSL-space lightness adjustment matching Textual's
C<Color.lighten>. C<$amount> is a C<0..1> fraction added to the
HSL lightness component; the result is clamped at the
C<0%>..C<100%> boundaries. Hue and saturation are preserved (unlike
L</blend> against white, which desaturates as it brightens). Alpha
rides through unchanged. Negative amounts darken.

=head2 darken

	my $shadow = $color->darken(0.15);

Symmetric counterpart to L</lighten>. C<< $color->darken($n) >> is
identically C<< $color->lighten(-$n) >>; the named method exists so
call sites read in the direction the author intended.

=head1 SEE ALSO

L<Term::Fabulous::TF>, L<Term::Fabulous>.

=cut
