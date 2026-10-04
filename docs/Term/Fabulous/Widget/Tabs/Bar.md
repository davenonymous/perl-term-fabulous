# NAME

Term::Fabulous::Widget::Tabs::Bar - A row of tabs, one of them active

# SYNOPSIS

```perl
use Term::Fabulous::Widget::Tabs::Bar;
use Term::Fabulous::Widget::Tabs::Button;

my $bar = Term::Fabulous::Widget::Tabs::Bar->new( id => 'views', page_border => 1 );
$bar->add_child( map { Term::Fabulous::Widget::Tabs::Button->new( title => $_ ) } qw(List Grid Map) );

$bar->on( Select => sub ($event) {
        show_view( $event->index );    # 0, 1 or 2
        return;
} );

$bar->select(1);    # from the program: fires nothing
say $bar->active->title;    # Grid
```

# DESCRIPTION

A tab bar is the strip of tabs of a [Term::Fabulous::Widget::Tabs](../Tabs.md):
a row of [Term::Fabulous::Widget::Tabs::Button](Button.md)s and the line that
joins them with the page. One tab is the _active_ one. It is drawn
one cell larger toward the page and open on that side, so that it and
the page are one shape, while the other tabs are closed by the line
and so look as if they stood behind the page:

```text
 ╭─────────╮
 │ General │ ╭─────────╮ ╭───────╮
 │         │ │ Network │ │ Users │
╭╯         ╰─┴─────────┴─┴───────┴───────╮
```

The bar can sit on any side of the page (`side`), and the labels can
be written from left to right or downwards (`orientation`), on any
side: tabs along the top with downward labels are tall and narrow,
tabs along the left with horizontal labels make a sidebar. The tabs
start at the beginning of the bar, or sit in its center or at its end
(`tab_alignment`).

The user chooses a tab with a click, or with `Left`, `Right`, `Up`,
`Down`, `Home` and `End` while a tab has the focus. Only the active
tab takes the focus, so `Tab` stops at a bar once. A tab can be
disabled, and the bar fires [Term::Fabulous::Event::Select](../../Event/Select.md) whenever
the user chooses another tab.

A [Term::Fabulous::Widget::Tabs](../Tabs.md) creates and drives its bar and shows
the page of the active tab; you need a bar of your own only to switch
something that is not a page, for example whole layouts. The bar is a
[Term::Fabulous::Widget::Box](../Box.md) that grows along its side and fits
across it unless the `layout` says otherwise; its children are its
tabs, and `add_child` accepts nothing else.

# CONSTRUCTOR

## new

```perl
my $bar = Term::Fabulous::Widget::Tabs::Bar->new(%parameters);
```

Accepts the parameters of ["CONSTRUCTOR" in Term::Fabulous::Widget::Box](../Box.md#constructor)
(`id`, `layout`, `background_color`, ...) and the ones below. All
are optional; unknown parameters die.

- `side`

    `top` (the default), `right`, `bottom` or `left`: the side of the
    page the bar is on. The tabs run from left to right on the top and
    the bottom, from top to bottom on the left and the right; the line
    lies on the side toward the page. Anything else dies.

- `orientation`

    `horizontal` (the default) or `vertical`: whether the labels are
    written from left to right, or downwards, one character per row.
    Independent of `side`.

- `tab_alignment`

    `start` (the default), `center` or `end`: where the tabs sit along
    the bar when they do not fill it.

- `tab_gap`

    A non-negative integer. Default: 1. The cells between two tabs.

- `tab_margin`

    A non-negative integer. Default: 1. The cells between the ends of the
    bar and the first and the last tab; the corners of the page's border
    need one.

- `tab_padding`

    A non-negative integer. Default: 1. The cells on each side of a label
    along its writing direction: left and right of a horizontal label,
    above and below a vertical one.

- `line_style`

    A [Term::Fabulous::Enum::BorderStyle](../../Enum/BorderStyle.md) item with grid joints
    (`Ascii`, `Dashed`, `Double`, `Heavy`, `Round` or `Solid`), or
    the name of one. Default: `Round`. The style of the tabs' borders and
    of the line, whose joints join them. Another style dies, naming the
    known ones.

- `line_color`

    The color of the borders and the line, in any format
    [Term::Fabulous::Color](../../Color.md) accepts. Default: `[90, 96, 110, 255]`, a
    gray.

- `text_color`

    The color of the labels of the inactive tabs. Default:
    `[150, 160, 180, 255]`.

- `active_text_color`

    The color of the active tab's label. Default: `[220, 223, 228, 255]`.

- `active_bold`

    A boolean. Default: 0. Whether the active tab's label is bold.

- `hover_background_color`

    The background of an inactive tab under the pointer. Default:
    `[40, 45, 58, 255]`.

- `focus_border_color`

    The color of the active tab's border, and of the line's corners at
    it, while the tab has the focus; or `undef` for no focus look.
    Default: `[97, 175, 239, 255]`, a blue.

- `disabled_color`

    The color of a disabled tab's border and label. Default:
    `[108, 112, 120, 255]`.

- `page_border`

    A boolean. Default: 0. True draws the ends of the line as the corners
    of a page border that continues from them, as under a
    [Term::Fabulous::Widget::Tabs](../Tabs.md) with a bordered page; false ends the
    line straight.

# METHODS

The methods of [Term::Fabulous::Widget](../../Widget.md), plus:

## add\_child

```perl
$bar->add_child( $tab, $other_tab );
```

Appends tabs. Dies for anything but a
[Term::Fabulous::Widget::Tabs::Button](Button.md). While no tab is active, the
first enabled tab added becomes the active one. Returns the bar.

## remove\_child, remove\_children\_with, clear\_children

As in [Term::Fabulous::Widget](../../Widget.md), for the tabs. When the active tab is
removed, the first enabled tab left becomes the active one.

## buttons

```perl
my @tabs = $bar->buttons;
```

The tabs, in order.

## button

```perl
my $tab = $bar->button(2);
```

The tab at an index, from 0. Dies for an index outside the tabs.

## index\_of

```perl
my $index = $bar->index_of($tab);
```

The index of a tab, or `undef`.

## active

```perl
my $tab = $bar->active;    # or undef
```

The active tab.

## active\_index

```perl
my $index = $bar->active_index;    # or undef
```

Its index.

## select

```perl
$bar->select(1);        # by index
$bar->select($tab);     # or the tab
$bar->select(undef);    # no active tab
```

Makes a tab the active one from the program. Fires nothing. A tab
that had the focus passes it on to the new active tab. Dies for an
index outside the tabs or a tab of another bar. Returns the bar.

## choose

```perl
$bar->choose($index);
```

Chooses a tab as the user does: makes it active, focuses it and fires
`Select` when the active tab changed. A disabled tab changes
nothing. Returns the bar.

## is\_horizontal

```perl
if ( $bar->is_horizontal ) { ... }
```

1 when the bar is on the top or the bottom, so its tabs run from left
to right; 0 on the left and the right.

## toward\_page, away\_from\_page

```perl
my $arm = $bar->toward_page;    # 'down' for a bar on top
```

The directions from the line into the page and away from it, as the
arms of ["junction" in Term::Fabulous::Enum::BorderStyle](../../Enum/BorderStyle.md#junction): `down` and
`up` on the top, `up` and `down` on the bottom, `right` and
`left` on the left, `left` and `right` on the right.

## side

```perl
$bar->side('left');
```

Accessor for the `side` parameter. Changing it lays the bar out
again; a tab that had the focus keeps it.

## orientation

```perl
$bar->orientation('vertical');
```

Accessor for the `orientation` parameter.

## tab\_alignment

```perl
$bar->tab_alignment('end');
```

Accessor for the `tab_alignment` parameter.

## tab\_gap

```perl
$bar->tab_gap(0);
```

Accessor for the `tab_gap` parameter.

## tab\_margin

```perl
$bar->tab_margin(2);
```

Accessor for the `tab_margin` parameter.

## tab\_padding

```perl
$bar->tab_padding(2);
```

Accessor for the `tab_padding` parameter.

## line\_style

```perl
$bar->line_style('Heavy');
$bar->line_style( Term::Fabulous::Enum::BorderStyle->Double );
```

Accessor for the `line_style` parameter; the reader returns the
style item.

## line\_color

```perl
$bar->line_color('#5a606e');
```

Accessor for the `line_color` parameter. The reader returns
`[r, g, b, a]`. An invalid color dies and leaves the old one.

## text\_color

```perl
$bar->text_color('#96a0b4');
```

Accessor for the `text_color` parameter; works like ["line\_color"](#line_color).

## active\_text\_color

```perl
$bar->active_text_color('#ffffff');
```

Accessor for the `active_text_color` parameter; works like
["line\_color"](#line_color).

## hover\_background\_color

```perl
$bar->hover_background_color( [ 40, 45, 58 ] );
```

Accessor for the `hover_background_color` parameter; works like
["line\_color"](#line_color).

## disabled\_color

```perl
$bar->disabled_color('#6c7078');
```

Accessor for the `disabled_color` parameter; works like
["line\_color"](#line_color).

## active\_bold

```perl
$bar->active_bold(1);
```

Accessor for the `active_bold` parameter. Returns 1 or 0.

## focus\_border\_color

```perl
$bar->focus_border_color(undef);
```

Accessor for the `focus_border_color` parameter; `undef` switches
the focus look off.

## page\_border

```perl
$bar->page_border(1);
```

Accessor for the `page_border` parameter. Returns 1 or 0.

Every writer restyles the tabs and the line, so the next frame shows
the new look.

# KEYS

While a tab of the bar has the focus (only the active tab can):

- `Left`, `Up`

    Choose the previous enabled tab, wrapping around from the first to
    the last.

- `Right`, `Down`

    Choose the next enabled tab, wrapping around from the last to the
    first.

- `Home`, `End`

    Choose the first and the last enabled tab.

The chosen tab takes the focus. `Enter` and `Space` activate the
focused tab, which is active already, and change nothing. `Tab` and
`Shift+Tab` move the focus away from the bar, as everywhere. All
other keys bubble to the ancestors.

# MOUSE

A click on a tab chooses it and focuses it; a click on a disabled tab
does nothing. An inactive tab under the pointer is painted on
`hover_background_color`.

# EVENTS

- `Select`

    [Term::Fabulous::Event::Select](../../Event/Select.md) when the user chooses another tab (or
    ["choose"](#choose) is called and the active tab changes); `$event->item`
    is the tab, a [Term::Fabulous::Widget::Tabs::Button](Button.md), and
    `$event->index` its position. Programmatic changes fire nothing.

The `Activate` and the focus events of the tabs bubble through the bar
as well.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::Box](../Box.md#kdl-properties), plus
`side`, `orientation`, `tab_alignment`, `tab_gap`, `tab_margin`,
`tab_padding` and `line_style` (strings and numbers),
`active_bold` and `page_border` (`#true` / `#false`),
`focus_border_color` (a color string, or `#null` for no focus look)
and the colors `line_color`, `text_color`, `active_text_color`,
`hover_background_color` and `disabled_color`. The tabs are child
nodes of [Term::Fabulous::Widget::Tabs::Button](Button.md):

```kdl
use Term::Fabulous::Widget::Tabs::Bar as TabBar
use Term::Fabulous::Widget::Tabs::Button as Tab

TabBar "views" {
        tab_alignment "center"
        line_style "Heavy"
        Tab { title "List"; }
        Tab { title "Grid"; }
        Tab { title "Map"; disabled #true; }
}
```

# SEE ALSO

[Term::Fabulous::Widget::Tabs](../Tabs.md), [Term::Fabulous::Widget::Tabs::Button](Button.md),
[Term::Fabulous::Event::Select](../../Event/Select.md), ["TABS" in Term::Fabulous::Manual::Layout](../../Manual/Layout.md#tabs).
