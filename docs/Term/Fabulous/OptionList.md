# NAME

Term::Fabulous::OptionList - The options of a choice and the one selected

# SYNOPSIS

```perl
use Term::Fabulous::OptionList;

my $list = Term::Fabulous::OptionList->new( owner => 'My::Picker' );
$list->set_options( [ 'Red', [ 'Green', 'g' ], { label => 'Blue', value => 'b', disabled => 1 } ] );

$list->set_value('g');       # select by value (dies for an unknown one)
$list->selected_index;       # 1
$list->selected_label;       # 'Green'
$list->choose(2);            # 0: Blue is disabled
$list->choose(0);            # 1: the selection changed
$list->enabled_indexes;      # ( 0, 1 )
```

# DESCRIPTION

The options of a widget that chooses one of several, and which one is
selected: a [Term::Fabulous::Widget::Dropdown](Widget/Dropdown.md) and a
[Term::Fabulous::Widget::SegmentedControl](Widget/SegmentedControl.md) each hold one. It knows
nothing of widgets or events: ["choose"](#choose) reports whether the selection
changed and the widget fires its `Change` event. Errors start with the
`owner` given to the constructor, the widget's class.

## Options

An option is given as

- a label, which is also its value: `'Red'`;
- `[ $label, $value ]`;
- `{ label => $label, value => $value, disabled => $flag }`,
where `value` defaults to the label and `disabled` to 0.

Labels are strings; a value is a string or a number (compared as a
string), not a reference. A disabled option is shown but the user cannot
choose it (["choose"](#choose)), and the arrow keys skip it (see
[Term::Fabulous::Roving](Roving.md)); the program may still select it with
[set\_value or set\_selected\_index](#set_selected_index-set_value).

# CONSTRUCTOR

## new

```perl
my $list = Term::Fabulous::OptionList->new( owner => ref($self) );
```

`owner` is required: the name the error messages start with. The list
starts empty, with nothing selected.

# METHODS

## set\_options

```perl
$list->set_options( [ 'Red', 'Green' ] );
```

Replaces the options. When an option still has the value that was
selected, it is selected; otherwise nothing is. Dies, changing nothing,
for anything but an array reference of options (see ["Options"](#options)).
Returns the list.

## options

A list of new hashes `{ label, value, disabled }`, one per option.

## count

The number of options.

## label, is\_disabled, set\_disabled

```perl
my $label = $list->label($index);
$list->set_disabled( $index, 1 );
```

An option's label, and whether it is disabled. The index must be one of
an option.

## enabled\_indexes

The indexes of the options that are not disabled, in order.

## index\_of\_value

The index of the first option with a value, or `undef`.

## selected\_index, value, selected\_label

The selected option's index, value and label, or `undef` when nothing
is selected.

## set\_selected\_index, set\_value

```perl
$list->set_selected_index(2);
$list->set_value('g');
$list->set_value(undef);    # nothing selected
```

Select as the program does: any option, disabled or not. Die for an
index outside the options (`OWNER: selected_index must be undef or an
index in 0..N, got ...`) or a value no option has
(`OWNER: no option has the value 'x'`). Return the list.

## choose

```perl
my $changed = $list->choose($index);
```

Selects as the user does: returns 1 when the selection changed, 0 for
the option already selected or a disabled one. Dies for an index outside
the options (`OWNER: choose needs an option index in 0..N, got ...`).

## from\_layout\_node

```perl
my @options = Term::Fabulous::OptionList->from_layout_node( ref($self), $node );
```

Class method. The options a KDL property node gives:
`options "Day" "Week"` (labels) or one
`option "Year" value="y" disabled=#true`. Other shapes die.
[Term::Fabulous::Role::HasOptions](Role/HasOptions.md) reads layouts with it.

# SEE ALSO

[Term::Fabulous::Role::HasOptions](Role/HasOptions.md), [Term::Fabulous::Roving](Roving.md).
