package Term::Fabulous::Check;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(positive_integer non_negative_integer integer number string boolean glyph color cell_color sizing describe);

use Carp qw(croak);
use Clay::XS qw(check_struct sizing_fit sizing_fixed sizing_grow sizing_percent);
use Feature::Compat::Try;
use Scalar::Util qw(blessed looks_like_number);
use Term::Fabulous::Color;
use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

use constant MAX_RGB => 0xFFFFFF;

sub _owner_name ($owner) {
	return ref $owner || $owner;
}

# How the messages name a value: undef, a reference by its type, or the
# value quoted.
sub describe ($value) {
	return 'undef' unless defined $value;
	return ( ref($value) =~ /\A[AEIOU]/ ? 'an ' : 'a ' ) . ref($value) . ' reference' if ref $value;
	return "'$value'";
}

sub _fail ( $owner, $name, $expected, $value, $detail = undef ) {
	croak _owner_name($owner) . ": $name must be $expected, got " . describe($value) . ( defined $detail ? " ($detail)" : '' );
}

sub _is_plain ($value) {
	return defined $value && !ref $value;
}

sub positive_integer ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a positive integer', $value ) unless _is_plain($value) && $value =~ /\A[0-9]+\z/ && $value > 0;
	return $value + 0;
}

sub non_negative_integer ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a non-negative integer', $value ) unless _is_plain($value) && $value =~ /\A[0-9]+\z/;
	return $value + 0;
}

sub integer ( $owner, $name, $value ) {
	_fail( $owner, $name, 'an integer', $value ) unless _is_plain($value) && $value =~ /\A-?[0-9]+\z/;
	return $value + 0;
}

sub number ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a finite number', $value )
		unless _is_plain($value) && looks_like_number($value) && $value == $value && $value - $value == 0;
	return $value + 0;
}

sub string ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a string', $value ) unless _is_plain($value);
	return $value;
}

sub boolean ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a plain boolean value', $value ) if ref $value;
	return $value ? 1 : 0;
}

sub glyph ( $owner, $name, $value ) {
	my @clusters = _is_plain($value) ? grapheme_clusters($value) : ();
	_fail( $owner, $name, 'a single character one column wide', $value ) unless @clusters == 1 && cluster_columns( $clusters[0] ) == 1;
	return $value;
}

sub color ( $owner, $name, $value ) {    ## no critic (Subroutines::RequireFinalReturn) PPI does not parse try/catch
	_fail( $owner, $name, 'a color', $value ) unless defined $value;
	try {
		my $object = blessed $value && $value->isa('Term::Fabulous::Color') ? $value : Term::Fabulous::Color->new( color => $value );
		return [ $object->to_rgba ];
	}
	catch ($error) {
		$error =~ s/\ATerm::Fabulous::Color: //;
		$error =~ s/ at \S+ line \d+\.?\n?\z//;
		_fail( $owner, $name, 'a color', $value, $error );
	}
}

my $DECIMAL = qr/(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)/;
my %SIZING_WITH_LIMITS = ( grow => \&sizing_grow, fit => \&sizing_fit );

# One axis of a Clay sizing: a spec string (grow, fit, grow(MIN, MAX),
# fit(MIN, MAX), percent(0..100), fixed(N)) or a hash a sizing_* function
# of Clay::XS returned.
sub sizing ( $owner, $name, $value ) {
	if ( ref $value eq 'HASH' ) {
		try {
			check_struct( 'Clay_SizingAxis', $value, $name );
		}
		catch ($error) {
			croak _owner_name($owner) . ": invalid $name: $error";
		}
		return {%$value};
	}
	my $spec = $value // '';
	croak _owner_name($owner) . ": invalid $name " . describe($value) . " (expected grow, fit, grow(MIN), grow(MIN, MAX), fit(MIN), fit(MIN, MAX), percent(0..100), fixed(N) or a sizing_* hash)"
		if ref $spec;
	return sizing_grow() if $spec eq 'grow';
	return sizing_fit()  if $spec eq 'fit';
	if ( my ( $kind, $min, $max ) = $spec =~ /\A(grow|fit)\(\s*([0-9]+)\s*(?:,\s*([0-9]+)\s*)?\)\z/ ) {
		croak _owner_name($owner) . ": $name minimum $min is greater than maximum $max in '$spec'" if defined $max && $min > $max;
		return $SIZING_WITH_LIMITS{$kind}->( $min + 0, defined $max ? $max + 0 : undef );
	}
	if ( my ($percent) = $spec =~ /\Apercent\(\s*($DECIMAL)\s*\)\z/ ) {
		croak _owner_name($owner) . ": $name percentage must be in 0..100, got '$spec'" if $percent > 100;
		return sizing_percent( $percent / 100 );
	}
	if ( my ($cells) = $spec =~ /\Afixed\(\s*([0-9]+)\s*\)\z/ ) {
		return sizing_fixed( $cells + 0 );
	}
	croak _owner_name($owner) . ": invalid $name '$spec' (expected grow, fit, grow(MIN), grow(MIN, MAX), fit(MIN), fit(MIN, MAX), percent(0..100), fixed(N) or a sizing_* hash)";
}

# Canvas cells also take a packed 0xRRGGBB integer, which is opaque.
sub cell_color ( $owner, $name, $value ) {
	return color( $owner, $name, $value ) unless _is_plain($value) && $value =~ /\A[0-9]+\z/;
	_fail( $owner, $name, 'a color', $value, 'a packed color is at most 0xFFFFFF' ) if $value > MAX_RGB;
	return [ ( $value >> 16 ) & 0xFF, ( $value >> 8 ) & 0xFF, $value & 0xFF, 255 ];
}

1;

__END__

=head1 NAME

Term::Fabulous::Check - Validate the values of widget properties

=head1 SYNOPSIS

	use Term::Fabulous::Check qw(positive_integer string color);

	# In a widget class: each check returns the value to store, or dies.
	$columns = positive_integer( $self, preferred_columns => $new[0] );
	$label   = string( $self, label => $new[0] );
	$color   = color( $self, accent_color => '#ff8800' );    # [ 255, 136, 0, 255 ]

=head1 DESCRIPTION

Most programs never use this module directly. The widgets of
Term::Fabulous check the values of their constructor parameters and
accessors with it, so every property of a kind is checked the same way
and fails with the same wording. Use it in widget classes of your own
for the same reason.

Every function takes the I<owner> (the widget, or its class name), the
property name and the value. It returns the value as the widget stores
it (numbers as numbers, booleans as 1 or 0, colors as
C<[r, g, b, a]>), or dies with a message in one wording:

=for highlighter language=text

	My::Widget: preferred_columns must be a positive integer, got '0'
	My::Widget: label must be a string, got a HASH reference
	My::Widget: accent_color must be a color, got 'nope' (unrecognized color string 'nope')

The message starts with the owner's class name and names the line that
called the check. Nothing is exported by default.

=head1 FUNCTIONS

=head2 positive_integer

An integer of at least 1, written with digits only (C<'12'>, C<12>).

=head2 non_negative_integer

An integer of at least 0, written with digits only.

=head2 integer

An integer, written with digits and an optional leading minus.

=head2 number

A finite number: no C<inf>, no C<nan>, no reference.

=head2 string

A defined value that is not a reference. Numbers count as strings.

=head2 boolean

Any plain value, stored as 1 (true in Perl) or 0. A reference dies, so
that a mistaken C<[]> or C<{}> does not count as true.

=head2 glyph

A string of exactly one grapheme cluster that takes one terminal column
(see L<Term::Fabulous::Unicode>): the marks and track pieces of the
widgets.

=head2 color

Any color L<Term::Fabulous::Color> accepts: a color string such as
C<'#ff8800'>, C<'rgb(255, 136, 0)'> or C<'hsl(32, 100%, 50%)'>, an C<[r, g, b, a]>
array, an C<{ r, g, b, a }> hash or a Term::Fabulous::Color object.
Returns C<[r, g, b, a]>, the form Clay::UI takes. C<undef> dies; a
property that can be switched off handles C<undef> before it checks.

=head2 sizing

=for highlighter language=perl

	my $width = sizing( $self, 'width', 'fit(4, 30)' );    # the hash sizing_fit(4, 30) returns

One axis of a Clay sizing, as the C<sizing> of a
L<Term::Fabulous::Widget/new> layout takes it: a hash returned by
C<sizing_fit>, C<sizing_grow>, C<sizing_fixed> or C<sizing_percent> of
L<Clay::XS> (copied), or a string in the notation of KDL layouts:
C<fit>, C<grow>, C<fit(MIN)>, C<fit(MIN, MAX)>, C<grow(MIN)>,
C<grow(MIN, MAX)>, C<fixed(N)> or C<percent(P)> with C<P> from 0 to 100.
Its messages differ from the others: C<invalid NAME 'SPEC' (expected
...)>, C<NAME minimum MIN is greater than maximum MAX in 'SPEC'> and
C<NAME percentage must be in 0..100, got 'SPEC'>.

=head2 cell_color

Like L</color>, and also a packed C<0xRRGGBB> integer, opaque, as the
cells of a L<Term::Fabulous::Widget::Canvas> take it. Returns
C<[r, g, b, a]>.

=head2 describe

	croak ref($self) . ": a slice label must be a string, got " . describe($label);

Not a check: the words the messages of this module use for a value, for
messages of your own. C<undef> for an undefined value, C<an ARRAY
reference>, C<a HASH reference> and so on for references, and the value
in single quotes otherwise (C<'nope'>).

=head1 SEE ALSO

L<Term::Fabulous::Role::CanParseLayout>, L<Term::Fabulous::Color>,
L<Term::Fabulous::Manual::CustomWidgets/WRITING YOUR OWN WIDGETS>.

=cut
