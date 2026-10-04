# NAME

Term::Fabulous::Widget::Tabs::Button - The button of one tab in a tab
bar

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Tabs::Bar;
use Term::Fabulous::Widget::Tabs::Button;

my $bar = Term::Fabulous::Widget::Tabs::Bar->new;
$bar->add_child(
        Term::Fabulous::Widget::Tabs::Button->new( title => 'General' ),
        Term::Fabulous::Widget::Tabs::Button->new( title => 'Network', icon => "\x{2601}" ),
        Term::Fabulous::Widget::Tabs::Button->new( title => 'Licenses', disabled => 1 ),
);
```

# DESCRIPTION

A tab button is one tab of a [Term::Fabulous::Widget::Tabs::Bar](Bar.md): a
[Term::Fabulous::Widget::Button](../Button.md) with a border on three sides, open
toward the page, that shows a title and an optional icon. The bar
makes one tab the _active_ one: it is drawn one cell larger toward
the page, so that it joins the page's border, and its label is drawn
in the bar's `active_text_color`. The other tabs are closed by the
line of the bar and show their labels in `text_color`.

The look (the side the bar is on, whether the label is written
horizontally or downwards, the padding, the line style and the
colors) comes from the bar, see
["CONSTRUCTOR" in Term::Fabulous::Widget::Tabs::Bar](Bar.md#constructor). As a Button, a tab
takes the focus (only the active tab does, see
["KEYS" in Term::Fabulous::Widget::Tabs::Bar](Bar.md#keys)), reacts to clicks and
`Enter` and `Space`, shows the focus with its border color, the
pointer with `hover_background_color` and can be disabled; a pressed
tab shows no pressed look.

A [Term::Fabulous::Widget::Tabs](../Tabs.md) makes the tab buttons for its pages
itself; you create them only for a bar of your own.

# CONSTRUCTOR

## new

```perl
my $tab = Term::Fabulous::Widget::Tabs::Button->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Button](../Button.md#constructor)
(`id`, `layout`, `disabled`, `can_focus`, ...), of which the
border, the padding, the layout direction, the colors and
`pressed_background_color` are set by the look, and the ones below.
Unknown parameters die.

- `title`

    A character string. Default: `''`. The text of the tab.

- `icon`

    A character string, or `undef`. Default: `undef`. A short text, for
    example a symbol, shown before the title with a cell between them;
    above the title in a tab with a vertical label.

# METHODS

The methods of [Term::Fabulous::Widget::Button](../Button.md) (`disabled`,
`is_enabled`, `is_focused`, `is_hovered`, `activate`, ...), plus:

## title

```perl
$tab->title('Advanced');
```

Accessor for the title; the new text shows in the next frame.

## icon

```perl
$tab->icon("\x{2699}");
$tab->icon(undef);
```

Accessor for the icon.

## is\_active

```perl
if ( $tab->is_active ) { ... }
```

1 while the tab is the active one of its bar. The bar sets it: see
["select" in Term::Fabulous::Widget::Tabs::Bar](Bar.md#select).

## focus

```perl
$tab->focus;
```

Gives the keyboard focus to the tab. Dies when the tab is not part of
a [Term::Fabulous](../../../../../README.md), or cannot take the focus (an inactive or
disabled tab).

## bar

```perl
my $bar = $tab->bar;
```

The [Term::Fabulous::Widget::Tabs::Bar](Bar.md) the tab is in, or `undef`.

## refresh\_look

```perl
$tab->refresh_look;
```

Updates the borders, the padding, the label and the colors from the
tab's state and the bar's settings. The bar calls it when its
settings change; call it yourself after changing the tab's look
behind its back. Returns the tab.

## default\_look

```perl
my %look = Term::Fabulous::Widget::Tabs::Button->default_look;
```

Class method: the look a tab shows outside a bar, as a hash of the
bar's look parameters (`side`, `orientation`, `tab_padding`,
`line_style`, `line_color`, `text_color`, `active_text_color`,
`active_bold`, `hover_background_color`, `focus_border_color`,
`disabled_color`) and their defaults.

# EVENTS

A tab fires the events of a Button: `Activate` for a click or
`Enter` or `Space`, `OnFocus`, `OnBlur`, `OnHoverStart`, ... The
bar fires [Term::Fabulous::Event::Select](../../Event/Select.md) when a tab is chosen.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Button](../Button.md#kdl-properties),
plus `title` and `icon` (strings):

```kdl
use Term::Fabulous::Widget::Tabs::Button as Tab

Tab "network" {
        title "Network"
        icon "#"
        disabled #true
}
```

# SEE ALSO

[Term::Fabulous::Widget::Tabs::Bar](Bar.md), [Term::Fabulous::Widget::Tabs](../Tabs.md),
[Term::Fabulous::Widget::Button](../Button.md),
["TABS" in Term::Fabulous::Manual::Layout](../../Manual/Layout.md#tabs).
