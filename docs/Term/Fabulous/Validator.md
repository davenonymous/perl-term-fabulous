# NAME

Term::Fabulous::Validator - Checks the value of an input widget

# SYNOPSIS

```perl
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
```

# DESCRIPTION

A validator checks one value and says what is wrong with it: ["check"](#check)
returns an error message for a value it rejects and `undef` for one it
accepts. The input widgets take one through their `validator`
parameter (see ["validator" in Term::Fabulous::Widget::Input](Widget/Input.md#validator)), check their
value with it on every change and show the invalid look while the
check fails; the message is theirs to read through
["error" in Term::Fabulous::Widget::Input](Widget/Input.md#error).

The named validators (["email"](#email), ["integer"](#integer), ["number"](#number), ["url"](#url),
["hostname"](#hostname), ["ip"](#ip), ["date"](#date), ["time"](#time)) cover the common types of a
form. ["pattern"](#pattern) checks a value against a regular expression, ["code"](#code)
runs your own check, and ["all"](#all) combines several. A widget's
`validator` parameter takes any of them as an object, and also the
shorthands ["coerce"](#coerce) understands: the name of a named validator, a
regular expression, a code reference, or a list of those.

Validators check text, not meaning: `email` accepts anything shaped
like `name@host.tld` and does not look the host up, `integer` does not
know about the field's purpose. They do not care about an empty value
either; whether a field may be left empty is the input's `required`
parameter.

Some named validators also know which characters their values are made
of: `integer`, `number`, `date` and `time` suggest an
[accept](Widget/TextInput.md#accept) spec, which a text
input uses as long as it was not given one of its own.

# CONSTRUCTORS

Every constructor is a class method and takes a `message` option, the
error text ["check"](#check) returns instead of the default. Unknown options
die.

## email

```perl
Term::Fabulous::Validator->email;
```

Something shaped like an e-mail address: a local part, `@`, and a host
with at least one dot, without whitespace. Default message: "Please
enter an e-mail address."

## integer

```perl
Term::Fabulous::Validator->integer;
Term::Fabulous::Validator->integer( min => 1, max => 65535 );
```

A whole number, with an optional minus sign, within `min` and `max`
when they are given. Default message: "Please enter a whole number
between 1 and 65535." (or "at least 1", "at most 65535", or without a
range). Suggests the accept spec `'0-9-'`. Dies if `min` or `max` is
not a number or `min` is above `max`.

## number

```perl
Term::Fabulous::Validator->number( min => 0 );
```

A decimal number: an optional minus sign, digits, an optional fraction
(`3`, `3.`, `3.5`, `.5`), within `min` and `max` as for
["integer"](#integer). Default message: "Please enter a number ...". Suggests
`'0-9.-'`.

## url

A scheme, `://` and anything without whitespace after it. Default
message: "Please enter a URL, such as https://example.com."

## hostname

Labels of letters, digits and hyphens (not at the ends, up to 63 each)
separated by dots, at most 253 characters, an optional trailing dot.
Default message: "Please enter a host name."

## ip

An IPv4 address in dotted quad form, or an IPv6 address as
["inet\_pton" in Socket](https://metacpan.org/pod/Socket#inet_pton) parses it. Default message: "Please enter an IP
address."

## date

A calendar day as `YYYY-MM-DD` that exists (`2026-02-29` does not).
Default message: "Please enter a date as YYYY-MM-DD." Suggests
`'0-9-'`.

## time

`HH:MM` or `HH:MM:SS` on the 24-hour clock. Default message: "Please
enter a time as HH:MM." Suggests `'0-9:'`.

## pattern

```perl
Term::Fabulous::Validator->pattern( qr/\A[A-Z]{3}\z/, message => 'Three capital letters, please.' );
```

The value must match the regular expression. Default message: "Please
match the expected format." Dies for anything but a regular expression.

## code

```perl
Term::Fabulous::Validator->code( sub ($value) {
        return 'Please enter an even number.' if $value % 2;
        return;
} );
```

Your own check. The code is called with the value and returns what is
wrong with it: a message, which becomes the error, or any other true
value for the validator's `message` (default: "Invalid value."); it
returns false for a value it accepts. The code never sees an empty
value (see ["required" in Term::Fabulous::Widget::Input](Widget/Input.md#required)).

## all

```perl
Term::Fabulous::Validator->all( 'hostname', qr/\.example\.com\z/ );
```

Every validator must pass; the first error message wins. Each argument
is coerced as ["coerce"](#coerce) does. A single argument returns that validator
itself; no argument dies.

## coerce

```perl
my $validator = Term::Fabulous::Validator->coerce($spec);
```

What an input's `validator` parameter does with its value: a
`Term::Fabulous::Validator` is returned as it is, a string names one
of the named constructors (["names"](#names) lists them; anything else dies
with the list), a regular expression becomes ["pattern"](#pattern), a code
reference ["code"](#code), an array reference ["all"](#all) over its items, and
`undef` stays `undef`. Any other kind of value dies.

## new

```perl
Term::Fabulous::Validator->new( name => 'odd', message => 'Please enter an odd number.', check => sub ($value) { $value % 2 ? undef : 'Please enter an odd number.' } );
```

The general form the constructors above use: a `name`, the `message`
["message"](#message) reports, `check` code that is called with the value and
returns the error message or false, and an optional suggested
`accept`. ["code"](#code) is the shorter way to the same thing.

# METHODS

## check

```perl
my $error = $validator->check($value);
```

The error message for a value the validator rejects, `undef` for one
it accepts.

## name

The name of the constructor that made the validator (`'email'`,
`'pattern'`, `'code'`, `'all'`, ...).

## message

The message ["check"](#check) returns for a value the validator rejects, unless
["code"](#code) or ["all"](#all) gives a more specific one.

## accept

The [accept](Editor.md#set_accept) spec the validator
suggests for a text input, or `undef`.

## names

```perl
my @names = Term::Fabulous::Validator->names;
```

The names ["coerce"](#coerce) accepts, as a list of strings.

# SEE ALSO

["validator" in Term::Fabulous::Widget::Input](Widget/Input.md#validator) and
["required" in Term::Fabulous::Widget::Input](Widget/Input.md#required), where validators are used;
["accept" in Term::Fabulous::Widget::TextInput](Widget/TextInput.md#accept) for restricting the
characters of a text input;
[the checking input section of the forms guide](Manual/Forms.md#checking-input).
