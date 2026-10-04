# NAME

Term::Fabulous::Widget::Table::Mutator - Ready-made mutators for table columns

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table;
use Term::Fabulous::Widget::Table::Mutator qw(datetime number bytes boolean lookup truncate);

my $table = Term::Fabulous::Widget::Table->new(
        id      => 'files',
        columns => [
                { key => 'name',     title => 'Name', mutator => truncate(30) },
                { key => 'size',     title => 'Size', type => 'number', mutator => bytes() },
                { key => 'modified', title => 'Modified', type => 'date', mutator => datetime('%d.%m.%Y %H:%M') },
                { key => 'price',    title => 'Price', type => 'number', mutator => number( decimals => 2, prefix => '$' ) },
                { key => 'shared',   title => 'Shared', mutator => boolean( 'yes', '' ) },
                { key => 'state',    title => 'State', mutator => lookup( { r => 'running', s => 'sleeping' }, default => '?' ) },
        ],
);
```

# DESCRIPTION

A _mutator_ turns the raw value of a table cell into the text the cell
shows: a code reference called as `$mutator->( $value, $row )`
with the raw value and a copy of the row's data, returning the text.
Give a column one, or an array reference of several that run one after
the other, with its `mutator` option (see
["mutator" in Term::Fabulous::Widget::Table::Column](Column.md#mutator)). The table keeps the
raw value for sorting and, unless told otherwise, for filtering.

This module makes the common ones. Each function below returns a new
mutator; nothing is exported by default, `:all` exports everything.
Unknown options die. Every mutator turns a blank value (`undef`, and
except for ["boolean"](#boolean) and ["lookup"](#lookup) also `''`) into `''`, and a
value it cannot read (a word where a number belongs) into that value as
text, so bad data stays visible.

# FUNCTIONS

## datetime

```perl
datetime()                          # 2024-05-03 14:30
datetime('%d.%m.%Y %H:%M:%S')
datetime( '%H:%M', utc => 1 )
```

A date or time in a ["strftime" in POSIX](https://metacpan.org/pod/POSIX#strftime) format, default
`'%Y-%m-%d %H:%M'`. The value may be epoch seconds, a date string
(`2024-05-03 14:30`) or an object with an `epoch` method (see
["date\_epoch" in Term::Fabulous::Widget::Table::Value](Value.md#date_epoch)). Local time, or
UTC with `utc => 1`.

## date

```perl
date()             # 2024-05-03
date('%e %b %Y')   #  3 May 2024
```

["datetime"](#datetime) with the default format `'%Y-%m-%d'`.

## number

```perl
number()                                      # 1234567.5 -> 1,234,567.5
number( decimals => 2 )                       # 1,234,567.50
number( decimals => 0, separator => '.' )     # 1.234.568
number( decimals => 2, separator => "\x{202F}", point => ',', suffix => ' EUR' )
```

A number with a separator between groups of three digits. Options:
`decimals` (default: as many as the value has), `separator` (default
`','`, `''` for none), `point` (the decimal point, default `'.'`),
`prefix` and `suffix` (default `''`).

## percent

```perl
percent()                     # 0.153 -> 15%
percent( decimals => 1 )      # 15.3%
percent( scale => 1 )         # 15.3 -> 15%
```

A fraction as a percentage. Options: `decimals` (default 0), `scale`
(what the value is multiplied by, default 100; use 1 for values that
are percentages already), `separator` and `point` (as for
["number"](#number)).

## bytes

```perl
bytes()                         # 1536 -> 1.5 KiB
bytes( binary => 0 )            # 1536 -> 1.5 kB
bytes( decimals => 0 )          # 2 KiB
```

A size in bytes with a unit: B, KiB, MiB, GiB, ... (steps of 1024), or
with `binary => 0` B, kB, MB, GB, ... (steps of 1000). Option
`decimals`, default 1; sizes below one step are shown as they are,
with the unit B (`512 B`).

## duration

```perl
duration()                  # 3725 -> 1h 02m
duration( parts => 3 )      # 1h 02m 05s
```

Seconds as days, hours, minutes and seconds, showing at most `parts`
units (default 2) from the largest one that is not 0. Negative
durations get a minus sign; 0 is `0s`.

## boolean

```perl
boolean()                     # yes / no
boolean( "\x{2714}", '' )    # a check mark, nothing for false
```

The first text for true values, the second for false ones (Perl's
truth: `0`, `''` and `'0'` are false). `undef` gives `''`.

## lookup

```perl
lookup( { r => 'running', s => 'sleeping' } )
lookup( { 1 => 'high', 2 => 'normal' }, default => 'unknown' )
```

The text the hash gives for the value; a value it does not have gives
`default`, or the value itself when there is no `default`. The hash is
copied.

## truncate

```perl
truncate(20)                       # long text cut to 20 columns, with an ellipsis
truncate( 20, ellipsis => '...' )
```

Text that is wider than that many terminal columns is cut so that it
fits with the ellipsis (default `"\x{2026}"`, one column). Wide
characters count as two columns; no character is cut in half. To keep
long text whole but narrow, give the column a maximum width instead
(`width => 'fit(0, 20)'`), and it wraps.

## sprintf\_format

```perl
sprintf_format('%05d')       # 42 -> 00042
sprintf_format('%.1f %%')    # 12.34 -> 12.3 %
```

The value formatted with ["sprintf" in perlfunc](https://metacpan.org/pod/perlfunc#sprintf).

## chain

```perl
chain( truncate(10), sub ( $text, $row ) { uc $text } )
```

One mutator that runs several in order, each getting the result of the
one before. A column's `mutator` option does the same with an array
reference.

# WRITING YOUR OWN

Any code reference with this signature is a mutator:

```perl
my $temperature = sub ( $value, $row ) {
        return '' unless defined $value;
        return sprintf '%.1f %s', $value, $row->{unit} eq 'F' ? "\x{2109}" : "\x{2103}";
};
```

It should return a character string and not change `$row` (a copy is
passed anyway). It is called again whenever the row or the column
changes, and once per cell otherwise: the table keeps the results.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md), [Term::Fabulous::Widget::Table::Column](Column.md),
[Term::Fabulous::Widget::Table::Value](Value.md),
["DISPLAY TEXT AND MUTATORS" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#display-text-and-mutators),
["Format cells: dates, numbers, sizes and flags (mutators)" in Term::Fabulous::Cookbook::Tables](../../Cookbook/Tables.md#format-cells-dates-numbers-sizes-and-flags-mutators).
