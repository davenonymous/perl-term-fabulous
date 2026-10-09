# NAME

Term::Fabulous::ThemeEditor::MenuBar - The menu bar of the theme editor

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. One row of menu titles; a menu opens below its title as a list of
commands with their keys. The bar takes the focus only while a menu is
open, and gives it back to the widget that had it when the menu closes.
It is drawn in the colors of the theme's `dropdown` family.

Keys while a menu is open: `Left` and `Right` (or `Shift+Tab` and
`Tab`) switch menus, `Up`,
`Down`, `Home`, `End` move between the commands that can run now,
`Enter` or `Space` runs one, `Escape` or `F10` closes the menu, and
`Alt` with a menu's underlined letter switches to that menu. Other
plain keys do nothing; keys with `Ctrl` or `Alt` close the menu and
go on to the editor. The mouse opens a menu with a click on
its title, switches menus by moving over the titles, and runs a
command when the button is released over it.

# CONSTRUCTOR

## new

```perl
my $bar = Term::Fabulous::ThemeEditor::MenuBar->new(
        menus   => [ { title => 'File', key => 'f', items => [ { label => 'Save', command => 'save', keys => 'Ctrl+S' }, '-' ] } ],
        run     => sub ($command) { ... },
        enabled => sub ($command) { ... },
        caption => 'Theme editor',
);
```

`menus` lists the menus with their mnemonic letter and items; `'-'`
is a separator. `run` runs a command, `enabled` says whether one can
run now. `caption` is shown at the right end of the bar.

# METHODS

## value

The index of the open menu, or `undef` (what an input widget reports
as its value).

## open, close, is\_open, open\_menu

Open a menu by index (taking the focus), close it (giving the focus
back), whether one is open and which.

## menu\_for\_key

The index of the menu with a mnemonic letter, or `undef`.

## highlighted, highlight\_item, activate\_item

The highlighted item of the open menu, highlight one, run one.

## captures\_tab

True while a menu is open: `Tab` and `Shift+Tab` switch menus then.

## item\_enabled

Whether an item's command can run now.

## menus

The menus as given.

## colors

The termbox attributes the bar and its menus are drawn with.

## pointer\_over

Opens the menu under the pointer while another one is open.

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md).
