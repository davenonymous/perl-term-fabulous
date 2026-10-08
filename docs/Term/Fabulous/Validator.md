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

Every constructor is a class method. The named validators,
["pattern"](#pattern) and ["code"](#code) take a `message` option: the error text
["check"](#check) returns instead of the default. ["all"](#all) and ["coerce"](#coerce) take
no options; give the validators they combine a message of their own.
Unknown options die.

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

A whole number: digits with an optional minus sign in front, nothing
else (`42`, `-7`, `007`; not `+42`, `4.0` or `1e3`). With `min`
or `max`, the number must lie in that range, the limits included. The
default message names the range:

- with `min` and `max`: "Please enter a whole number between 1 and 65535."
- with `min` only: "Please enter a whole number at least 1."
- with `max` only: "Please enter a whole number at most 65535."
- without a range: "Please enter a whole number."

Suggests the accept spec `'0-9-'`: digits and the minus sign, which a
text input lets the user type anywhere, so `4-2` can be typed and is
then rejected. Dies if `min` or `max` is not a number or `min` is
above `max`.

## number

```perl
Term::Fabulous::Validator->number( min => 0 );
```

A decimal number with a point as its decimal separator: an optional
minus sign and digits with an optional fraction (`3`, `3.`, `3.5`,
`.5`, `-0.25`; not `3,5`, `1e3` or `+3`), within `min` and `max`
as for ["integer"](#integer). The default message is built like that of
["integer"](#integer) with "a number" in place of "a whole number", such as
"Please enter a number at least 0." Suggests `'0-9.-'`.

## url

```perl
Term::Fabulous::Validator->url;
```

A scheme (a letter, then letters, digits, `+`, `.` or `-`), `://`
and at least one more character, without whitespace anywhere:
`https://example.com`, `ftp://host/file`. It does not check the
scheme or the host, and `example.com` without a scheme is rejected.
Default message: "Please enter a URL, such as https://example.com."

## hostname

```perl
Term::Fabulous::Validator->hostname;
```

Labels of ASCII letters, digits and hyphens, separated by dots: each
label 1 to 63 characters long and not starting or ending with a hyphen,
the whole name at most 253 characters, with an optional trailing dot.
`localhost`, `db-1.example.com` and `example.com.` pass;
`bad_host`, `-db.example.com` and `a..b` do not. Default message:
"Please enter a host name."

## ip

```perl
Term::Fabulous::Validator->ip;
```

An IPv4 address in dotted quad form (`192.0.2.1`), or an IPv6 address
(`2001:db8::1`, `::1`), as ["inet\_pton" in Socket](https://metacpan.org/pod/Socket#inet_pton) parses them. Host
names, ports (`192.0.2.1:80`) and networks (`192.0.2.0/24`) are
rejected. Default message: "Please enter an IP address."

## date

```perl
Term::Fabulous::Validator->date( message => 'Please enter your birthday as YYYY-MM-DD.' );
```

A calendar day as `YYYY-MM-DD`, with four digits for the year and two
each for the month and the day, that exists: `2024-02-29` passes,
`2026-02-29` and `2026-4-1` do not. Default message: "Please enter a
date as YYYY-MM-DD." Suggests `'0-9-'`.

## time

```perl
Term::Fabulous::Validator->time;
```

`HH:MM` or `HH:MM:SS` on the 24-hour clock, with two digits each:
`07:30` and `23:59:59` pass, `7:30`, `24:00` and `12:60` do not.
Default message: "Please enter a time as HH:MM." Suggests `'0-9:'`.

## pattern

```perl
Term::Fabulous::Validator->pattern( qr/\A[A-Z]{3}\z/, message => 'Three capital letters, please.' );
```

The value must match the regular expression. The expression is not
anchored for you: `qr/[0-9]/` accepts any value with a digit in it, so
anchor it with `\A` and `\z` to describe the whole value. Default
message: "Please match the expected format." Dies for anything but a
regular expression.

## code

```perl
Term::Fabulous::Validator->code( sub ($value) {
        return 'Please enter an even number.' if $value % 2;
        return;
} );
```

Your own check. The code is called with the value and returns what is
wrong with it:

- a string other than `"1"`: the error message;
- `1` (as from a true comparison) or a reference: the validator's
`message`, by default "Invalid value.";
- a false value (`undef`, an empty list, `''` or `0`): the value
is fine.

So `sub ($value) { $value % 2 }` rejects odd numbers with the
validator's `message`. An input never calls the code with an empty
value (see ["required" in Term::Fabulous::Widget::Input](Widget/Input.md#required)); ["check"](#check) does,
if you pass one.

## all

```perl
Term::Fabulous::Validator->all( 'hostname', qr/\.example\.com\z/ );
```

Every validator must pass; they are checked in the given order and the
message of the first one that fails is the error. Each argument is
coerced as ["coerce"](#coerce) does, so names, regular expressions and code
references work too. The combined validator suggests the `accept` spec
of the first validator that has one, and its ["message"](#message) is that of the
first validator. A single argument returns that validator itself; no
argument dies. `all` takes no `message` option.

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
my $message = 'Please enter a hexadecimal number.';
my $hex     = Term::Fabulous::Validator->new(
        name    => 'hex',
        message => $message,
        accept  => '0-9a-fA-F',
        check   => sub ($value) { $value =~ /\A[0-9a-fA-F]+\z/ ? undef : $message },
);
```

The general form the constructors above use, for a validator that also
suggests an `accept` spec. It takes:

- `name`

    Required. A string, returned by ["name"](#name).

- `message`

    Required. A string, returned by ["message"](#message). `check` decides what
    ["check"](#check) returns; `message` is only reported, so `check` usually
    returns it.

- `check`

    Required. Code called with the value that returns the error message,
    or a false value for a valid one. Unlike ["code"](#code), a true value is
    always used as the message as it is.

- `accept`

    Optional. The accept spec suggested to a text input (see
    ["accept" in Term::Fabulous::Widget::TextInput](Widget/TextInput.md#accept)), or `undef`.

Without an `accept`, ["code"](#code) is the shorter way to the same thing.

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
[the checking input section of the forms guide](Manual/Forms.md#checking-input);
the recipes
["Check the values of a form (required, validator)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#check-the-values-of-a-form-required-validator)
(every named validator in one form) and
["Write your own checks and restrict typing (accept, pattern, code)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#write-your-own-checks-and-restrict-typing-accept-pattern-code).
