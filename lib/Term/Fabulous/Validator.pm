package Term::Fabulous::Validator;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

class Term::Fabulous::Validator :strict(params) {
	use Scalar::Util qw(blessed);
	use Socket qw(inet_pton AF_INET AF_INET6);
	use Term::Fabulous::Check qw(describe optional string);

	# The named validators a widget parameter may ask for by name.
	my @NAMES    = qw(email integer number url hostname ip date time);
	my %IS_NAMED = map { $_ => 1 } @NAMES;

	my %DEFAULT_MESSAGE = (
		email    => 'Please enter an e-mail address.',
		url      => 'Please enter a URL, such as https://example.com.',
		hostname => 'Please enter a host name.',
		ip       => 'Please enter an IP address.',
		date     => 'Please enter a date as YYYY-MM-DD.',
		time     => 'Please enter a time as HH:MM.',
		pattern  => 'Please match the expected format.',
		code     => 'Invalid value.',
	);

	my @DAYS_IN_MONTH = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

	field $name    :param :reader;
	field $message :param :reader;
	field $accept  :param :reader = undef;

	# Called with the value; returns the error message, or false for a
	# valid value.
	field $check :param;

	ADJUST {
		$name    = string( $self, name    => $name );
		$message = string( $self, message => $message );
		die 'Term::Fabulous::Validator: check must be a code reference, got ' . describe($check) unless ref $check eq 'CODE';
	}

	method check ($value) {
		my $error = $check->($value);
		return $error ? "$error" : undef;
	}

	# ---------------------------------------------------------------------
	# Coercion: what a widget's validator parameter takes
	# ---------------------------------------------------------------------

	method coerce :common ($spec) {
		return undef unless defined $spec;
		return $spec if blessed($spec) && $spec->isa(__PACKAGE__);
		return $class->pattern($spec) if ref $spec eq 'Regexp';
		return $class->code($spec) if ref $spec eq 'CODE';
		return $class->all(@$spec) if ref $spec eq 'ARRAY';
		die 'Term::Fabulous::Validator: a validator is a name, a regular expression, a code reference, a list of those or a Term::Fabulous::Validator, got ' . describe($spec) if ref $spec;
		die "Term::Fabulous::Validator: unknown validator '$spec'; the names are " . join( ', ', @NAMES ) unless $IS_NAMED{$spec};
		return $class->$spec;
	}

	method names :common () {
		return @NAMES;
	}

	# ---------------------------------------------------------------------
	# Named validators
	# ---------------------------------------------------------------------

	# A validator from a predicate (true for a valid value) and the message
	# of %options, or the default of $name.
	method _from_test :common ( $name, $test, $accept, %options ) {
		my $message = delete $options{message} // $DEFAULT_MESSAGE{$name};
		my $unknown = join ', ', sort keys %options;
		die "Term::Fabulous::Validator: $name does not take $unknown" if length $unknown;
		return $class->new( name => $name, message => $message, accept => $accept, check => sub ($value) { $test->($value) ? undef : $message } );
	}

	# "Please enter a whole number between 1 and 10." and the like.
	sub _range_message ( $noun, $min, $max ) {
		my $range
			= defined $min && defined $max ? " between $min and $max"
			: defined $min                 ? " at least $min"
			: defined $max                 ? " at most $max"
			:                                '';
		return "Please enter a $noun$range.";
	}

	# A validator for numbers of a kind (matching $shape) within the min and
	# max options, which are removed from %options.
	method _within :common ( $name, $noun, $shape, $accept, %options ) {
		my $min = optional( \&Term::Fabulous::Check::number, $class, "$name min", delete $options{min} );
		my $max = optional( \&Term::Fabulous::Check::number, $class, "$name max", delete $options{max} );
		die "Term::Fabulous::Validator: $name min $min is above max $max" if defined $min && defined $max && $min > $max;
		$options{message} //= _range_message( $noun, $min, $max );
		my $test = sub ($value) { $value =~ $shape && ( !defined $min || $value >= $min ) && ( !defined $max || $value <= $max ) };
		return $class->_from_test( $name, $test, $accept, %options );
	}

	method email :common (%options) {
		return $class->_from_test( email => sub ($value) { $value =~ /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ }, undef, %options );
	}

	method integer :common (%options) {
		return $class->_within( integer => 'whole number', qr/\A-?[0-9]+\z/, '0-9-', %options );
	}

	method number :common (%options) {
		return $class->_within( number => 'number', qr/\A-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)\z/, '0-9.-', %options );
	}

	method url :common (%options) {
		return $class->_from_test( url => sub ($value) { $value =~ m{\A[a-z][a-z0-9+.-]*://\S+\z}i }, undef, %options );
	}

	method hostname :common (%options) {
		my $label = qr/[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?/i;
		return $class->_from_test( hostname => sub ($value) { length $value <= 253 && $value =~ /\A$label(?:\.$label)*\.?\z/ }, undef, %options );
	}

	method ip :common (%options) {
		return $class->_from_test( ip => \&_is_ip_address, undef, %options );
	}

	sub _is_ip_address ($value) {
		return 0 unless $value =~ /\A[0-9a-f.:]+\z/i;
		return defined inet_pton( AF_INET, $value ) || defined inet_pton( AF_INET6, $value ) ? 1 : 0;
	}

	method date :common (%options) {
		return $class->_from_test( date => \&_is_calendar_day, '0-9-', %options );
	}

	sub _is_calendar_day ($value) {
		my ( $year, $month, $day ) = $value =~ /\A([0-9]{4})-([0-9]{2})-([0-9]{2})\z/ or return 0;
		return 0 if $month < 1 || $month > 12 || $day < 1;
		my $is_leap_year = $year % 4 == 0 && ( $year % 100 != 0 || $year % 400 == 0 );
		my $days         = $DAYS_IN_MONTH[ $month - 1 ] + ( $month == 2 && $is_leap_year ? 1 : 0 );
		return $day <= $days ? 1 : 0;
	}

	method time :common (%options) {
		return $class->_from_test( time => sub ($value) { $value =~ /\A(?:[01][0-9]|2[0-3]):[0-5][0-9](?::[0-5][0-9])?\z/ }, '0-9:', %options );
	}

	# ---------------------------------------------------------------------
	# Validators from a pattern, from code, and of several at once
	# ---------------------------------------------------------------------

	method pattern :common ( $regexp, %options ) {
		die 'Term::Fabulous::Validator: pattern takes a regular expression, got ' . describe($regexp) unless ref $regexp eq 'Regexp';
		return $class->_from_test( pattern => sub ($value) { $value =~ $regexp }, undef, %options );
	}

	# $code returns what is wrong with the value (a message, or any true
	# value for the validator's message) and false when it is fine.
	method code :common ( $code, %options ) {
		die 'Term::Fabulous::Validator: code takes a code reference, got ' . describe($code) unless ref $code eq 'CODE';
		my $message = string( $class, message => delete $options{message} // $DEFAULT_MESSAGE{code} );
		my $unknown = join ', ', sort keys %options;
		die "Term::Fabulous::Validator: code does not take $unknown" if length $unknown;
		my $check = sub ($value) {
			my $error = $code->($value);
			return undef unless $error;
			return ref $error || $error eq '1' ? $message : $error;
		};
		return $class->new( name => 'code', message => $message, check => $check );
	}

	# Every validator must pass; the first message wins. The suggested
	# accept is the first one any of them has.
	method all :common (@specs) {
		my @validators = map { $class->coerce($_) } @specs;
		die 'Term::Fabulous::Validator: all needs at least one validator' unless @validators;
		return $validators[0] if @validators == 1;

		my ($accept) = grep { defined } map { $_->accept } @validators;
		my $check = sub ($value) {
			foreach my $validator (@validators) {
				my $error = $validator->check($value);
				return $error if defined $error;
			}
			return undef;
		};
		return $class->new( name => 'all', message => $validators[0]->message, accept => $accept, check => $check );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Validator - Checks the value of an input widget

=head1 SYNOPSIS

	use Term::Fabulous::Validator;
	use Term::Fabulous::Widget::TextField;

	# By name, as a pattern or as code, through an input's validator:
	my $email = Term::Fabulous::Widget::TextField->new( validator => 'email' );
	my $code  = Term::Fabulous::Widget::TextField->new( validator => qr/\A[A-Z]{3}\z/ );
	my $even  = Term::Fabulous::Widget::TextField->new( validator => sub ($value) { $value % 2 ? 'Please enter an even number.' : undef } );

	# As an object, when a validator takes options:
	my $port = Term::Fabulous::Widget::TextField->new(
		validator => Term::Fabulous::Validator->integer( min => 1, max => 65535 ),
	);
	my $host = Term::Fabulous::Widget::TextField->new(
		validator => Term::Fabulous::Validator->hostname( message => 'Bitte einen Rechnernamen eingeben.' ),
	);

	# Several at once: all must pass, the first message wins.
	my $name = Term::Fabulous::Widget::TextField->new( validator => [ qr/\A\S/, qr/\S\z/ ] );

	# Checking a value yourself:
	my $validator = Term::Fabulous::Validator->coerce('email');
	my $error     = $validator->check('me@example');    # 'Please enter an e-mail address.'

=head1 DESCRIPTION

A validator checks one value and says what is wrong with it: L</check>
returns an error message for a value it rejects and C<undef> for one it
accepts. The input widgets take one through their C<validator>
parameter (see L<Term::Fabulous::Widget::Input/validator>), check their
value with it on every change and show the invalid look while the
check fails; the message is theirs to read through
L<Term::Fabulous::Widget::Input/error>.

The named validators (L</email>, L</integer>, L</number>, L</url>,
L</hostname>, L</ip>, L</date>, L</time>) cover the common types of a
form. L</pattern> checks a value against a regular expression, L</code>
runs your own check, and L</all> combines several. A widget's
C<validator> parameter takes any of them as an object, and also the
shorthands L</coerce> understands: the name of a named validator, a
regular expression, a code reference, or a list of those.

Validators check text, not meaning: C<email> accepts anything shaped
like C<name@host.tld> and does not look the host up, C<integer> does not
know about the field's purpose. They do not care about an empty value
either; whether a field may be left empty is the input's C<required>
parameter.

Some named validators also know which characters their values are made
of: C<integer>, C<number>, C<date> and C<time> suggest an
L<accept|Term::Fabulous::Widget::TextInput/accept> spec, which a text
input uses as long as it was not given one of its own.

=head1 CONSTRUCTORS

Every constructor is a class method and takes a C<message> option, the
error text L</check> returns instead of the default. Unknown options
die.

=head2 email

	Term::Fabulous::Validator->email;

Something shaped like an e-mail address: a local part, C<@>, and a host
with at least one dot, without whitespace. Default message: "Please
enter an e-mail address."

=head2 integer

	Term::Fabulous::Validator->integer;
	Term::Fabulous::Validator->integer( min => 1, max => 65535 );

A whole number, with an optional minus sign, within C<min> and C<max>
when they are given. Default message: "Please enter a whole number
between 1 and 65535." (or "at least 1", "at most 65535", or without a
range). Suggests the accept spec C<'0-9-'>. Dies if C<min> or C<max> is
not a number or C<min> is above C<max>.

=head2 number

	Term::Fabulous::Validator->number( min => 0 );

A decimal number: an optional minus sign, digits, an optional fraction
(C<3>, C<3.>, C<3.5>, C<.5>), within C<min> and C<max> as for
L</integer>. Default message: "Please enter a number ...". Suggests
C<'0-9.-'>.

=head2 url

A scheme, C<://> and anything without whitespace after it. Default
message: "Please enter a URL, such as https://example.com."

=head2 hostname

Labels of letters, digits and hyphens (not at the ends, up to 63 each)
separated by dots, at most 253 characters, an optional trailing dot.
Default message: "Please enter a host name."

=head2 ip

An IPv4 address in dotted quad form, or an IPv6 address as
L<Socket/inet_pton> parses it. Default message: "Please enter an IP
address."

=head2 date

A calendar day as C<YYYY-MM-DD> that exists (C<2026-02-29> does not).
Default message: "Please enter a date as YYYY-MM-DD." Suggests
C<'0-9-'>.

=head2 time

C<HH:MM> or C<HH:MM:SS> on the 24-hour clock. Default message: "Please
enter a time as HH:MM." Suggests C<'0-9:'>.

=head2 pattern

	Term::Fabulous::Validator->pattern( qr/\A[A-Z]{3}\z/, message => 'Three capital letters, please.' );

The value must match the regular expression. Default message: "Please
match the expected format." Dies for anything but a regular expression.

=head2 code

	Term::Fabulous::Validator->code( sub ($value) {
		return 'Please enter an even number.' if $value % 2;
		return;
	} );

Your own check. The code is called with the value and returns what is
wrong with it: a message, which becomes the error, or any other true
value for the validator's C<message> (default: "Invalid value."); it
returns false for a value it accepts. The code never sees an empty
value (see L<Term::Fabulous::Widget::Input/required>).

=head2 all

	Term::Fabulous::Validator->all( 'hostname', qr/\.example\.com\z/ );

Every validator must pass; the first error message wins. Each argument
is coerced as L</coerce> does. A single argument returns that validator
itself; no argument dies.

=head2 coerce

	my $validator = Term::Fabulous::Validator->coerce($spec);

What an input's C<validator> parameter does with its value: a
C<Term::Fabulous::Validator> is returned as it is, a string names one
of the named constructors (L</names> lists them; anything else dies
with the list), a regular expression becomes L</pattern>, a code
reference L</code>, an array reference L</all> over its items, and
C<undef> stays C<undef>. Any other kind of value dies.

=head2 new

	Term::Fabulous::Validator->new( name => 'odd', message => 'Please enter an odd number.', check => sub ($value) { $value % 2 ? undef : 'Please enter an odd number.' } );

The general form the constructors above use: a C<name>, the C<message>
L</message> reports, C<check> code that is called with the value and
returns the error message or false, and an optional suggested
C<accept>. L</code> is the shorter way to the same thing.

=head1 METHODS

=head2 check

	my $error = $validator->check($value);

The error message for a value the validator rejects, C<undef> for one
it accepts.

=head2 name

The name of the constructor that made the validator (C<'email'>,
C<'pattern'>, C<'code'>, C<'all'>, ...).

=head2 message

The message L</check> returns for a value the validator rejects, unless
L</code> or L</all> gives a more specific one.

=head2 accept

The L<accept|Term::Fabulous::Editor/set_accept> spec the validator
suggests for a text input, or C<undef>.

=head2 names

	my @names = Term::Fabulous::Validator->names;

The names L</coerce> accepts, as a list of strings.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Input/validator> and
L<Term::Fabulous::Widget::Input/required>, where validators are used;
L<Term::Fabulous::Widget::TextInput/accept> for restricting the
characters of a text input;
L<the checking input section of the forms guide|Term::Fabulous::Manual::Forms/Checking input>.

=cut
