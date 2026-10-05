# NAME

Term::Fabulous::Roving - Which entry an arrow key moves to

# SYNOPSIS

```perl
use Term::Fabulous::Roving qw(roving_target);

# Segments 0 .. 4, segment 2 disabled, segment 3 selected:
my $next = roving_target( [ 0, 1, 3, 4 ], 3, 'Right' );                       # 4
my $wrap = roving_target( [ 0, 1, 3, 4 ], 4, 'Right' );                       # 0: around
my $stop = roving_target( [ 0, 1, 3, 4 ], 4, 'Down', policy => 'clamp', keys => 'vertical' );    # 4
my $none = roving_target( [ 0, 1, 3, 4 ], 3, 'Tab' );                         # undef
```

# DESCRIPTION

Widgets that hold a row or a column of entries, of which some may be
disabled, move a selection, a cursor or the focus between them with the
arrow keys: segments, tabs, radio buttons, accordion headers, the
options of a dropdown. This module has the one rule for all of them, as
a pure function. Nothing is exported by default.

# FUNCTIONS

## roving\_target

```perl
my $index = roving_target( \@enabled, $current, $key_name, %options );
```

`\@enabled` holds the indexes of the enabled entries, in order;
`$current` is the index of the current entry, or `undef`; `$key_name`
is a key name such as ["main\_key\_name" in Term::Fabulous::Event::KeyPress](Event/KeyPress.md#main_key_name)
returns. Returns the index of the entry the key moves to, or `undef`
when the key is not one of the `keys` or no entry is enabled.

A key that steps moves by one enabled entry (disabled entries are
skipped), `PageUp` and `PageDown` by `page` of them. From a current
entry that is not enabled (or none), a step forward goes to the first
enabled entry and a step back to the last. `Home` and `End` go to the
first and the last enabled entry. Options:

- `keys`

    Which keys move: `arrows` (the default: `Left`, `Up`, `Right`,
    `Down`, `Home`, `End`), `vertical` (`Up`, `Down`, `Home`,
    `End`), `list` (`vertical` and `PageUp`, `PageDown`) or `pages`
    (`Ctrl+PageUp`, `Ctrl+PageDown`, the keys that turn the pages of a
    [Term::Fabulous::Widget::Tabs](Widget/Tabs.md)).

- `policy`

    `wrap` (the default): a step past the last entry goes on at the first
    and the other way round. `clamp`: it stays at the end.

- `page`

    How many entries `PageUp` and `PageDown` move. Default: 1.

Unknown options, kinds of keys and policies die.

# SEE ALSO

[Term::Fabulous::OptionList](OptionList.md), [Term::Fabulous::Widget::SegmentedControl](Widget/SegmentedControl.md),
[Term::Fabulous::Widget::Dropdown](Widget/Dropdown.md).
