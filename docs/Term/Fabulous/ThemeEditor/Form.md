# NAME

Term::Fabulous::ThemeEditor::Form - The form mode of the theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous::ThemeEditor::SettingsList](SettingsList.md) that lists every
setting a theme can have, in sections: the `theme` node (name and base), the
palette, one section per family with every slot in every state, and in
a family's section one per variant. Each row shows a swatch (the color,
or the corner and edge of a border style), the setting, its value and
where the value comes from: `set` when the theme sets it, the base
theme (`dark` or `light`) for a palette token it does not set,
`default` for the vocabulary's default, `normal` for a state that
looks like the normal state, `family` for a variant's slot that
follows its family. Rows the theme sets are bold; a section row shows
how many settings in it are set.

Above the list, a search field filters the rows by any text in them,
and `Only set` hides the settings the theme does not set. Below it, a
line explains the setting under the cursor.

# CONSTRUCTOR

## new

```perl
my $form = Term::Fabulous::ThemeEditor::Form->new(
        on_activate => sub ($key) { ... },    # Enter or a double click on a setting
        on_cursor   => sub ($id)  { ... },    # the cursor moved
);
```

# METHODS

## show

```perl
$form->show( $tab, $document, @extra_variants );
```

Shows a tab's document, with `[ family, name ]` pairs of variants that
have no settings yet. The rows are built again when the tab or its
variants changed; otherwise only the rows whose values changed are
updated.

## keep\_state

Remembers the cursor and the open sections in the tab's
`form_state`, before another tab is shown.

## current, current\_key

The row under the cursor (a hash reference with `id` and `key` or
`section`), and its setting key.

## section\_of, keys\_in, has\_row

The section of a row, the setting keys inside a section, and whether
a row exists.

## focus\_list

Gives the list the focus; the cursor goes to the first setting the list
shows when it is not on a setting the list shows (after a search, say).

## go\_to

Puts the cursor on a row, opening the sections above it and clearing
a search or filter that hides it.

## read\_only, show\_banner, hide\_banner

Whether the form takes changes, and a banner (rich markup) above the
list.

## explain\_with, explain\_current

The code that writes the line below the list for a row, and a call to
write it again.

## search, only\_set, list

The search field, the `Only set` check box and the list.

# FUNCTIONS

## slot\_keys

```perl
my @keys = Term::Fabulous::ThemeEditor::Form::slot_keys( 'button', 'primary' );
```

The keys of a family's (or a variant's) slots in every state, in the
order the form lists them.

## section\_id

```perl
my $id = Term::Fabulous::ThemeEditor::Form::section_id( 'family', 'button' );    # '#family:button'
```

The row id of a section: `theme`, `palette`, `family` with its
name, or `variant` with the family and the variant's name.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md), [Term::Fabulous::ThemeEditor::SettingsList](SettingsList.md).
