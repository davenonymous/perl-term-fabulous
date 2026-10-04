# NAME

Term::Fabulous::Widget::Table::Style - Check the style hashes of a table

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Table::Style qw(style_hash);

my $style = style_hash( $table, 'row style', row => {
        background_color => '#203040',
        bold             => 1,
        border_bottom    => 'Heavy',
} );
```

# DESCRIPTION

[Term::Fabulous::Widget::Table](../Table.md) takes looks and lines as _style
hashes_ at four levels: the table, its columns, its rows and single
cells (see ["STYLES AND BORDERS" in Term::Fabulous::Manual::TableStyles](../../Manual/TableStyles.md#styles-and-borders)). This
module checks them where they are given. You do not need it unless you
write a table subclass.

# FUNCTIONS

## style\_hash

```perl
my $copy = style_hash( $owner, $name, $kind, \%style );
```

A validated copy of `\%style`, or an empty hash for `undef`. `$kind`
says which keys are allowed: `cell`, `row`, `column` or `header`
(the look of a header cell; see
["Style keys" in Term::Fabulous::Manual::TableStyles](../../Manual/TableStyles.md#style-keys)). Colors become
`[r, g, b, a]` (any format [Term::Fabulous::Color](../../Color.md) takes), booleans 1
or 0, and lines [Term::Fabulous::Enum::BorderStyle](../../Enum/BorderStyle.md) items (an item, a
style name such as `'Heavy'`, or `'none'` for no line, which is the
`Hidden` style). Keys whose value is `undef` are left out. Unknown keys
and invalid values die with a message that starts with `$owner`'s class
and names `$name`.

## border\_style\_of

```perl
my $style = border_style_of( $owner, $name, 'Double' );
```

One line style as ["style\_hash"](#style_hash) reads it.

## merge\_styles

```perl
my $style = merge_styles( $cell_style, $row_style, $column_style, $table_style );
```

A new hash with, for every key, the value of the first style hash that
has it (`undef` arguments are skipped).

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md), ["Style keys" in Term::Fabulous::Manual::TableStyles](../../Manual/TableStyles.md#style-keys),
["Which style wins" in Term::Fabulous::Manual::TableStyles](../../Manual/TableStyles.md#which-style-wins).
