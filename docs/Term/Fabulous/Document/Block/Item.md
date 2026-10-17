# NAME

Term::Fabulous::Document::Block::Item - An item of a bulleted or numbered list

# SYNOPSIS

```perl
my $item = Term::Fabulous::Document::Block::Item->new( marker => "\x{2022}", marker_width => 2, position => 1, text => 'First point.' );
```

# DESCRIPTION

An item of a list: a marker (a bullet or the number) followed by the
item's text, which wraps with a hanging indent so that every line
starts after the marker. The paragraphs that belong to the item follow
as blocks of their own, indented by the marker's width.

All items of one list have the same `marker_width`, wide enough for
the widest marker of the list plus a space, so that their texts line
up (`9.` and `10.`). The view leaves no blank row between the items
of one list, nor between an item and the first item of a list nested
in it; two lists that follow each other stay apart, because the first
item of a list has `position` 1.

# CONSTRUCTOR

## new

```perl
my $item = Term::Fabulous::Document::Block::Item->new( marker => '10.', marker_width => 4, text => 'Tenth.' );
```

The parameters of ["new" in Term::Fabulous::Document::Block](../Block.md#new) plus:

- `marker`

    Required. The marker, a non-empty string: the bullet character or the
    number with its dot.

- `marker_width`

    Required. The columns the marker takes, the space after it included:
    an integer greater than the marker's width in columns.

- `position`

    The position of the item in its list, from 1 (the default).

# METHODS

The methods of [Term::Fabulous::Document::Block](../Block.md), whose
[kind](../Block.md#kind) is `item`, plus:

## marker

```perl
my $marker = $item->marker;
```

The marker.

## marker\_width

```perl
my $columns = $item->marker_width;
```

The columns between the start of the marker and the start of the text.

## position

```perl
my $position = $item->position;
```

The position of the item in its list, from 1.

# SEE ALSO

[Term::Fabulous::Document::Block](../Block.md), [Term::Fabulous::Document::Block::Term](Term.md).
