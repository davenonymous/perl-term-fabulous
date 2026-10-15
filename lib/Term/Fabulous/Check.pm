package Term::Fabulous::Check;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT_OK
	= qw(positive_integer non_negative_integer integer number string boolean glyph color cell_color sizing class_names one_of direction line_sizing align_x align_y border_style border_sides value_format optional describe);

use Carp qw(croak);
use Clay::XS qw(
	check_struct sizing_fit sizing_fixed sizing_grow sizing_percent
	CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM CLAY_LEFT_TO_RIGHT_WRAP CLAY_BACK_TO_FRONT CLAY_LINE_SIZING_GROW CLAY_LINE_SIZING_FIT
	CLAY_ALIGN_X_LEFT CLAY_ALIGN_X_CENTER CLAY_ALIGN_X_RIGHT CLAY_ALIGN_Y_TOP CLAY_ALIGN_Y_CENTER CLAY_ALIGN_Y_BOTTOM
);
use Feature::Compat::Try;
use Scalar::Util qw(blessed looks_like_number);
use Term::Fabulous::Color;
use Term::Fabulous::Enum::BorderStyle;
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

my $DECIMAL            = qr/(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)/;
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
	return sizing_fit() if $spec eq 'fit';
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

# A copy of an array of class names: defined strings, no references.
sub class_names ( $owner, $name, $value ) {
	_fail( $owner, $name,              'an array reference of names', $value ) unless ref $value eq 'ARRAY';
	_fail( $owner, 'every class name', 'a string',                    $_ ) foreach grep { !_is_plain($_) } @$value;
	return [@$value];
}

# One of a fixed set of words; the message lists them sorted.
sub one_of ( $owner, $name, $value, @allowed ) {
	_fail( $owner, $name, 'one of ' . join( ', ', sort @allowed ), $value ) unless _is_plain($value) && grep { $_ eq $value } @allowed;
	return $value;
}

# The names a layout file and Term::Fabulous::Lite use for the Clay
# layout directions and child alignments.
my %DIRECTION_BY_NAME = (
	top_to_bottom      => CLAY_TOP_TO_BOTTOM,
	ttb                => CLAY_TOP_TO_BOTTOM,
	down               => CLAY_TOP_TO_BOTTOM,
	left_to_right      => CLAY_LEFT_TO_RIGHT,
	ltr                => CLAY_LEFT_TO_RIGHT,
	right              => CLAY_LEFT_TO_RIGHT,
	wrap               => CLAY_LEFT_TO_RIGHT_WRAP,
	ltr_wrap           => CLAY_LEFT_TO_RIGHT_WRAP,
	left_to_right_wrap => CLAY_LEFT_TO_RIGHT_WRAP,
	stack              => CLAY_BACK_TO_FRONT,
	back_to_front      => CLAY_BACK_TO_FRONT,
	btf                => CLAY_BACK_TO_FRONT,
);

my %LINE_SIZING_BY_NAME = ( grow => CLAY_LINE_SIZING_GROW, fit => CLAY_LINE_SIZING_FIT );

my %ALIGN_X_BY_NAME = ( left => CLAY_ALIGN_X_LEFT, center => CLAY_ALIGN_X_CENTER, right  => CLAY_ALIGN_X_RIGHT );
my %ALIGN_Y_BY_NAME = ( top  => CLAY_ALIGN_Y_TOP,  center => CLAY_ALIGN_Y_CENTER, bottom => CLAY_ALIGN_Y_BOTTOM );

sub _named ( $owner, $name, $value_by_name, $value ) {
	return $value_by_name->{ one_of( $owner, $name, $value, keys %$value_by_name ) };
}

sub direction ( $owner, $name, $value ) {
	return _named( $owner, $name, \%DIRECTION_BY_NAME, $value );
}

sub line_sizing ( $owner, $name, $value ) {
	return _named( $owner, $name, \%LINE_SIZING_BY_NAME, $value );
}

sub align_x ( $owner, $name, $value ) {
	return _named( $owner, $name, \%ALIGN_X_BY_NAME, $value );
}

sub align_y ( $owner, $name, $value ) {
	return _named( $owner, $name, \%ALIGN_Y_BY_NAME, $value );
}

# A border style item, given as an item or its name. 'none' is accepted
# only where an option says what it means (Hidden in table styles); grid
# restricts to the styles with joints.
sub border_style ( $owner, $name, $value, %options ) {
	my @unknown = grep { $_ ne 'none' && $_ ne 'grid' } sort keys %options;
	croak "Term::Fabulous::Check: border_style does not take @unknown (known: grid, none)" if @unknown;
	return $options{none} if exists $options{none} && _is_plain($value) && $value eq 'none';
	my $style
		= blessed $value && $value->isa('Term::Fabulous::Enum::BorderStyle') ? $value
		: _is_plain($value)                                                  ? Term::Fabulous::Enum::BorderStyle->from_name($value)
		:                                                                      undef;
	_fail( $owner, $name, _border_style_words(%options), $value, 'known: ' . _border_style_names(%options) )
		unless defined $style && ( !$options{grid} || $style->joints );
	return $style;
}

sub _border_style_words (%options) {
	my $kind = $options{grid} ? 'a border style with joints' : 'a border style';
	return exists $options{none} ? "$kind, its name or 'none'" : "$kind or its name";
}

sub _border_style_names (%options) {
	my @styles = $options{grid} ? Term::Fabulous::Enum::BorderStyle->get_grid_styles : Term::Fabulous::Enum::BorderStyle->values;
	return join ', ', sort map { $_->name } @styles;
}

# The sides a border is drawn on: one boolean for all four sides, or a
# hash of booleans under the side names, where a missing side is false.
# Returned as a new hash with every side, as 1 or 0.
my @BORDER_SIDES = qw(top right bottom left);

sub border_sides ( $owner, $name, $value ) {
	my $expected = 'a boolean or a hash reference of booleans under the sides top, right, bottom and left';
	return { map { $_ => $value ? 1 : 0 } @BORDER_SIDES } unless ref $value;
	_fail( $owner, $name, $expected, $value ) unless ref $value eq 'HASH';
	my %is_side = map  { $_ => 1 } @BORDER_SIDES;
	my @unknown = grep { !$is_side{$_} } sort keys %$value;
	_fail( $owner, $name, $expected, $value, "unknown side @unknown" ) if @unknown;
	my @not_plain = grep { ref $value->{$_} } @BORDER_SIDES;
	_fail( $owner, $name, $expected, $value, "the side $not_plain[0] is " . describe( $value->{ $not_plain[0] } ) ) if @not_plain;
	return { map { $_ => $value->{$_} ? 1 : 0 } @BORDER_SIDES };
}

# How a widget writes a number: undef (its default), a sprintf format
# string or a code reference.
sub value_format ( $owner, $name, $value ) {
	_fail( $owner, $name, 'a sprintf format string or a code reference', $value ) if ref $value && ref $value ne 'CODE';
	return $value;
}

# Runs a check for a defined value; undef stays undef.
sub optional ( $check, $owner, $name, $value, @options ) {
	return defined $value ? $check->( $owner, $name, $value, @options ) : undef;
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

=head2 one_of

	my $side = one_of( $self, side => $value, qw(top right bottom left) );

One of a fixed set of words, given after the value. Anything else
dies, listing the words in sorted order:
C<My::Widget: side must be one of bottom, left, right, top, got 'middle'>.

=head2 direction

	my $direction = direction( $self, direction => 'ttb' );

A Clay layout direction by name: C<top_to_bottom>, C<ttb> or C<down>
(C<CLAY_TOP_TO_BOTTOM>); C<left_to_right>, C<ltr> or C<right>
(C<CLAY_LEFT_TO_RIGHT>); C<wrap>, C<ltr_wrap> or C<left_to_right_wrap>
(C<CLAY_LEFT_TO_RIGHT_WRAP>); C<stack>, C<back_to_front> or C<btf>
(C<CLAY_BACK_TO_FRONT>). Returns the constant. Any other value dies
like L</one_of>, listing the names.

=head2 line_sizing

	my $line_sizing = line_sizing( $self, line_sizing => 'fit' );

How the rows of a wrapping layout share the space left over below
them: C<grow> (C<CLAY_LINE_SIZING_GROW>) or C<fit>
(C<CLAY_LINE_SIZING_FIT>). Returns the constant; any other value dies
like L</one_of>.

=head2 align_x, align_y

	my $x = align_x( $self, 'child_alignment x' => 'center' );
	my $y = align_y( $self, 'child_alignment y' => 'bottom' );

A Clay child alignment by name: C<left>, C<center> or C<right> for
C<align_x>, C<top>, C<center> or C<bottom> for C<align_y>. Returns the
constant; any other value dies like L</one_of>.

=head2 border_style

	my $style = border_style( $self, line_style => 'Double' );
	my $line  = border_style( $self, column_lines => 'none', none => Term::Fabulous::Enum::BorderStyle->Hidden );
	my $grid  = border_style( $self, line_style => $value, grid => 1 );

A L<Term::Fabulous::Enum::BorderStyle> item, given as the item or its
name (case sensitive, C<'Round'>). Returns the item. Options:

=over

=item C<< none => $meaning >>

Also accept the word C<'none'> and return C<$meaning> for it (an item
such as C<Hidden>, or C<undef>). Without this option C<'none'> dies.

=item C<< grid => 1 >>

Accept only the styles with grid joints (see
L<Term::Fabulous::Enum::BorderStyle/get_grid_styles>).

=back

The message lists the names it accepts:
C<My::Widget: line_style must be a border style or its name, got 'Fancy' (known: Ascii, Blank, ...)>.

=head2 border_sides

	my $sides = border_sides( $self, bordered => 1 );                         # every side
	my $rule  = border_sides( $self, bordered => { top => 1, bottom => 1 } );  # two sides

The sides a border is drawn on: one plain value, true or false, for all
four sides, or a hash reference whose keys are C<top>, C<right>,
C<bottom> and C<left> and whose values are plain booleans; a side the
hash leaves out has no border. Returns a new hash reference with all
four sides, each 1 or 0 (C<< { top => 1, right => 0, bottom => 1, left => 0 } >>
for the second example). Another reference, an unknown key or a
reference as a side's value dies:
C<My::Widget: bordered must be a boolean or a hash reference of booleans under the sides top, right, bottom and left, got a HASH reference (unknown side middle)>.

=head2 value_format

How a widget writes a number: C<undef> (the widget's default), a
C<sprintf> format string such as C<'%d%%'> or a code reference.
Returns the value; anything else dies.

=head2 optional

	my $icon  = optional( \&string, $self, icon => $value );
	my $style = optional( \&border_style, $self, border_style_top => $value );

Runs the check given as a code reference for a defined value, with the
owner, the name, the value and any further arguments; returns C<undef>
for C<undef>. For properties where C<undef> means "none".

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
