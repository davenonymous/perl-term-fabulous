package Term::Fabulous::Enum::WebColor;
use v5.22;
use warnings;

our $VERSION = '0.01';

use Object::Pad;
use Object::PadX::Enum;

enum Term::Fabulous::Enum::WebColor :isa(Term::Fabulous::Color) {

}

1;

__END__

=head1 NAME

Term::Fabulous::Enum::WebColor - Placeholder for named web colors
(defines no colors yet)

=head1 SYNOPSIS

	use Term::Fabulous::Enum::WebColor;

	my @colors = Term::Fabulous::Enum::WebColor->values;    # currently the empty list

=head1 DESCRIPTION

This enumeration is meant to hold named colors (such as the CSS color
names) as L<Term::Fabulous::Color> objects. It does not define any
items yet: C<values> returns the empty list and C<from_name> returns
C<undef> for every name. Nothing in Term::Fabulous uses it, and color
strings such as C<'red'> are not accepted anywhere.

Until it is filled, write colors as hex strings, C<rgb()> or C<hsl()>
notation, or C<[r, g, b, a]> arrays; see
L<Term::Fabulous::Color/new> and L<Term::Fabulous::Manual/COLORS>.

=head1 METHODS

=head2 values

	my @colors = Term::Fabulous::Enum::WebColor->values;

Class method. All items; currently the empty list.

=head2 from_name

	my $color = Term::Fabulous::Enum::WebColor->from_name('red');    # undef

Class method. The item with that name; currently always C<undef>.

=head1 SEE ALSO

L<Term::Fabulous::Color>, L<Object::PadX::Enum>.

=cut
