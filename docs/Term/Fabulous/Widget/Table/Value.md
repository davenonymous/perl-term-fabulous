# NAME

Term::Fabulous::Widget::Table::Value - Read numbers and dates from table values

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table::Value qw(date_epoch date_interval number_of);

my $epoch = date_epoch('2024-05-03 14:30');    # local time
my $same  = date_epoch(1714739400);            # epoch seconds stay as they are
my ( $from, $until ) = @{ date_interval('2024-05') };    # all of May 2024
my $price = number_of('12.50');                # 12.5; undef for 'n/a'
```

# DESCRIPTION

The functions [Term::Fabulous::Widget::Table](../Table.md) uses to read the values of
`number` and `date` columns when it sorts and filters them. They are
exported on request. Use them in comparators and filters of your own to
read values the same way.

# FUNCTIONS

## is\_blank

```perl
is_blank($value)    # 1 for undef and '', else 0
```

## number\_of

The value as a finite number, or `undef` when it is blank, a
reference, not a number (`looks_like_number`), infinite or NaN.

## date\_interval

```perl
my $span = date_interval('2024-05-03');    # [ first second, first second of the next day ]
```

The span of time a date string names, as an array reference
`[ $first, $after ]` of epoch seconds: `$first` is the first second
of the span, `$after` the first second after it. The span is as long
as the last part the string gives:

```text
2024                   the year 2024
2024-05                May 2024
2024-05-03             that day
2024-05-03 14:30       that minute (also 2024-05-03T14:30)
2024-05-03 14:30:15    that second
```

Months, days and hours may have one digit. The string is read as local
time (the time zone of the program, `TZ`), unless it ends with `Z`
after a time (`2024-05-03T14:30Z`), which means UTC. Spaces around it
are allowed. Returns `undef` for anything else, including dates that do
not exist (`2024-02-30`).

## date\_epoch

The epoch seconds of a date value, or `undef`:

- a number is taken as epoch seconds, also a string of digits: `'2024'`
is 2024 seconds after the epoch, not the year (write `'2024-01-01'`
for the year);
- an object with an `epoch` method ([DateTime](https://metacpan.org/pod/DateTime), [Time::Piece](https://metacpan.org/pod/Time%3A%3APiece),
[Time::Moment](https://metacpan.org/pod/Time%3A%3AMoment)) gives what that method returns;
- a string gives the first second of its ["date\_interval"](#date_interval).

## compare\_values

```perl
my $order = compare_values( 'number', $left, $right );    # -1, 0 or 1
```

Orders two values of a column type: `string` (case-insensitive,
["fc" in perlfunc](https://metacpan.org/pod/perlfunc#fc)), `number` (by ["number\_of"](#number_of)) or `date` (by
["date\_epoch"](#date_epoch)). Both values must be readable as the type; the table
sorts blank and unreadable values after all others before it calls
this. An unknown type dies.

## natural\_compare

```perl
my @sorted = sort { natural_compare( $a, $b ) } qw(file10 File9 file1);    # file1 File9 file10
```

Orders text the way people count: runs of digits compare as numbers,
so `file9` comes before `file10`; the rest compares
case-insensitively. Returns -1, 0 or 1.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md), [Term::Fabulous::Widget::Table::Filter](Filter.md),
["Dates and numbers" in Term::Fabulous::Manual::Tables](../../Manual/Tables.md#dates-and-numbers),
["How values are compared" in Term::Fabulous::Manual::TableRows](../../Manual/TableRows.md#how-values-are-compared),
["Filter rows from Perl (numbers, dates, text, raw or shown values)" in Term::Fabulous::Cookbook::TableRows](../../Cookbook/TableRows.md#filter-rows-from-perl-numbers-dates-text-raw-or-shown-values).
