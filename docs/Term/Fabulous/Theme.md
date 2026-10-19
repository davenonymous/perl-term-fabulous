# NAME

Term::Fabulous::Theme - Colors and borders for every widget, with
variants per class

# SYNOPSIS

```perl
use Term::Fabulous;
use Term::Fabulous::Theme;

# A built-in theme, or one derived from it in Perl ...
my $theme = Term::Fabulous::Theme->new(
        name    => 'ocean',
        extends => 'dark',
        palette => { accent => '#88c0d0', surface => '#2e3440' },
        slots   => {
                'button.border.style'         => 'Round',
                'button.border.color.focused' => 'accent',
                'text_input.border.enabled'   => 1,
        },
        variants => {
                'button.primary' => { 'border.color' => 'accent', 'text' => 'text_bright' },
        },
);

# ... or from a theme file
my $theme = Term::Fabulous::Theme->from_file('themes/ocean.kdl');

my $ui = Term::Fabulous->new( root => $root, theme => $theme );
$ui->theme('light');    # switch at run time

# What a widget of a family draws with
my $border = $theme->look( 'button', 'border.color', 'focused', ['primary'] );
```

# DESCRIPTION

A theme decides the colors and the borders of every widget that does
not set them itself: whether a text field has a border, the border
color of a focused button, the background of a text field, the color
of the lines of a table, the color of text. It is made of a
_palette_ of named colors (tokens) and of _slots_, one for every
part of every widget family that a theme colors, styles or switches
on, in every state the part can be in. Most slots default to tokens,
so most themes set a few tokens and nothing else. A theme may also
define _variants_: a widget whose `classes` name a variant draws
with it.

Themes are set per UI (["theme" in Term::Fabulous](../../../README.md#theme),
["theme" in Term::Fabulous::Static](Static.md#theme)) and can be switched at any time. A
widget that was given a color or style explicitly keeps it, whatever
the theme says, and so does a widget that was given `bordered`;
["reset\_look" in Term::Fabulous::Widget](Widget.md#reset_look) returns it to the theme. See
["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes) for the guide.

# VOCABULARY

## Tokens

The palette has these tokens. The built-in `dark` theme gives them the
colors the widgets have always been drawn in; `light` gives them
colors for a light screen.

```perl
background surface surface_raised surface_field surface_low group_background
border line outline
text text_bright text_muted text_dim text_inverse placeholder disabled
accent focus_background hover_background hover_low control_hover selected selection
track track_scroll button_face backdrop
success warning danger
```

`border` is the color every border is drawn in unless a theme or the
widget says otherwise, so a frame stays visible on the theme's own
screen. Which widgets have a border at all is a slot of its own (see
["Borders"](#borders)). `background` is the screen behind the widgets: [Term::Fabulous](../../../README.md)
paints the whole screen in it before every frame, so a theme looks the
same whatever colors the terminal shows otherwise, and a light theme is
readable on a dark terminal. A theme that wants the terminal's own
background instead gives the token a color with alpha 0, such as
`rgba(0, 0, 0, 0)`. [Term::Fabulous::Static](Static.md) does not paint it.

## Families, slots and states

A family is the kind of a widget: `text`, `box`, `button`,
`input`, `text_input`, `dropdown`, `menu`, `menu_bar`, `table`,
`scrollbar`, `tabs`, `document_tabs`, `accordion`, `dialog`,
`toast`, `status_bar`, `progress`, `spinner`, `image`, `divider`.
A widget class says which family it belongs to
(["theme\_family" in Term::Fabulous::Role::Themed](Role/Themed.md#theme_family)), and a family may
extend another: `button` extends `box`, so it has the box's slots
too.

A slot is one part a theme decides: `background`, `border.color`,
`border.style`, `border.enabled`, `text`, `accent`,
`line.color`, ... Slots whose name ends in `style` take a border
style name, `border.enabled` takes true or false (see ["Borders"](#borders)),
and all others take a color. A slot has a value for the `normal`
state and, where the widget shows states, for some of `hovered`,
`focused`, `pressed`, `disabled`, `selected`, `active` and
`invalid`; style slots and `border.enabled` have the `normal` state
only. A state that a theme does not set looks like the normal state.
["slots"](#slots) lists the slots of a family with their states.

A theme sets a slot for one family. A family that extends it has the
same slot, but keeps its own value: `box.border.color` does not change
`button.border.color`, and `input.border.enabled` does not change
`text_input.border.enabled` or `dropdown.border.enabled`.

The slots of the status bar are named after the colors they give, not
after the kinds of message: a message of the kind `info` is drawn in
`status_bar.text`, the others in `status_bar.success`,
`status_bar.warning` and `status_bar.danger` (see
[Term::Fabulous::Widget::StatusBar](Widget/StatusBar.md)). A toast of the kind `info`, by
contrast, is drawn in `toast.info`, an accent color.

## Borders

Three slots decide the border of a widget:

- `border.enabled`

    Whether a widget of the family has a border on all four sides when
    the program does not decide it with the widget's `bordered` parameter
    (see ["bordered" in Term::Fabulous::Widget](Widget.md#bordered)). The families `button`,
    `input`, `text_input`, `dropdown`, `menu`, `menu_bar`,
    `accordion`, `dialog`, `toast`, `progress`, `spinner` and
    `image` have it. It is `false` in the built-in themes, except for
    `menu`, `dialog` and `toast`, where it is `true`.

    A border takes one cell on each side, inside the widget's box, so this
    slot has the `normal` state only: a border that came and went with
    the focus would resize the widget and move its neighbors.

- `border.style`

    The border style the border is drawn in: `Round` in the built-in
    themes. A widget may give each side a style of its own; a side whose
    style is `Hidden` has no border, whatever `border.enabled` says.

- `border.color`

    The color of the border's characters, by state.

Every family but `text` has `border.style` and `border.color`. The
families not listed under `border.enabled` above have no
`border.enabled`, and a widget of one of them has a border only where
the program gives it one:

- `box`, the family of plain boxes, scroll boxes, canvases,
charts and every widget that names no family of its own. Widgets build
their parts out of boxes, so a theme that framed every box would frame
those parts too.
- `table`: a table draws its frame and its lines itself, with
its own parameters (see
["Lines between and around the cells" in Term::Fabulous::Manual::TableStyles](Manual/TableStyles.md#lines-between-and-around-the-cells)),
and takes no `bordered` at all.
- `tabs`: the line of a tab bar joins the borders of its tabs,
which the bar draws itself.
- `scrollbar`, `divider`, `status_bar` and `document_tabs`:
lines one cell thick, which a frame does not fit around.
- `text`, which has no border slots.

A widget that frames one of its parts decides that part's border
itself: the tabs of a tab bar, the list of an open dropdown, the items
of an accordion with `item_borders`.

## Values

Where a theme sets a slot, it gives one of:

- a token name, such as `accent`: the palette's color;
- a color, in any format [Term::Fabulous::Color](Color.md) accepts (a color slot);
- a border style name, such as `Round` (a style slot; see [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md));
- `true` or `false`, or `1` or `0`, for `border.enabled` (in a theme file `#true` or `#false`);
- `none`: no color or no style, as if the widget had been given none (not for a required slot, see below);
- `reverse`: for `button.background` in the `pressed` state only, the button is drawn in reverse video.

Some slots are _required_: their widgets draw with the value, or hand
it to a part that needs one, so `none` (and `undef` or `#null`) dies
where the theme is built, with `Term::Fabulous::Theme: SLOT cannot be
'none'`, in every state the slot has. The required slots are
`scrollbar.track` and `scrollbar.thumb`; `tabs.line.style`;
`input.star` and `input.inactive` (in every family extending
`input`); `table.text`, `table.header.text`, `table.cursor`,
`table.muted`, `table.line.color` and `table.pager.button`;
`accordion.title`, `accordion.accent` and `accordion.disabled`;
`toast.text`, `toast.important_text`, `toast.info`,
`toast.success`, `toast.warning` and `toast.danger`, and
`border.enabled` in every family that has it.
`tabs.line.style` also needs a style with joints (see
["get\_grid\_styles" in Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md#get_grid_styles)), because the tab
bar's line joins the tab borders; another style dies.

# THEME FILES

A theme file is a KDL document ([https://kdl.dev](https://kdl.dev)) with a `theme`
node, a `palette` node and one node per family, all optional:

```kdl
theme "ocean" extends="dark"

palette {
        background "#242933"
        accent "#88c0d0"
        surface "#2e3440"
}

button {
        background "surface_raised"
        border style=Round color="border"
        text "text"
        focused { border color="accent" }
        pressed { background "reverse" }
        disabled { text "disabled" }
        variant "primary" {
                border color="accent"
                focused { border color="text_bright" }
        }
}

text_input {
        border enabled=#true style=Solid
        focused { background "focus_background" }
}
```

Inside a family node, `name "value"` sets the slot `name` and
`name key="value"` sets the slot `name.key` for every property, so
`border style=Round color="border"` sets `border.style` and
`border.color`, and `border enabled=#true` sets `border.enabled`. A
node named after a state holds the slots of that state. A
`variant "NAME"` node holds the slots and states of a variant. `#null`
means `none`. `border.enabled` takes `#true` or `#false` only; every
other slot takes a string or `#null`. An unknown family, slot, state,
token or style dies with the known names, and so does `none` or
`#null` for a required slot (see ["Values"](#values)). A palette token takes
exactly one string, its color, and no properties or children; anything
else dies with
`palette token 'accent' needs exactly one string argument`. A palette
token, or a slot of a family, state or variant, that is set twice in one
document dies too (`palette: the token 'accent' is set twice`,
`button: the slot 'text.focused' is set twice`), also when the two
settings are in two nodes of the same family.

# CONSTRUCTORS

## new

```kdl
my $theme = Term::Fabulous::Theme->new(%parameters);
```

- `name`

    A string, for your own use. Default: none.

- `extends`

    The theme this one starts from: a Term::Fabulous::Theme or the name
    of a built-in theme. Default: `'dark'`. Everything the parent sets is
    inherited, including its variants.

- `palette`

    A hash reference of token names and colors. Unknown tokens die.

- `slots`

    A hash reference whose keys are `family.slot` or
    `family.slot.state` and whose values are as in ["Values"](#values).

- `variants`

    A hash reference whose keys are `family.variant` and whose values are
    hash references of `slot` or `slot.state` keys. A variant inherits
    every slot of its family that it does not set.

## builtin

```kdl
my $dark = Term::Fabulous::Theme->builtin('dark');
```

The built-in theme of that name (`dark` or `light`), a shared
object; `undef` for any other name. ["families, tokens, states, builtin\_names"](#families-tokens-states-builtin_names)
lists the names.

## default

```kdl
my $theme = Term::Fabulous::Theme->default;
```

The theme a UI uses when it is given none, and the one a widget that
is in no UI resolves its looks against: the built-in `dark`.

## from\_file

```kdl
my $theme = Term::Fabulous::Theme->from_file('themes/ocean.kdl');
```

Reads a theme file (see ["THEME FILES"](#theme-files)). Dies with the file name and
the node when the file cannot be read or describes something unknown.

## from\_string

```kdl
my $theme = Term::Fabulous::Theme->from_string($kdl);
```

The same for a theme given as a character string.

# METHODS

## name

The `name` given to the constructor, the name of a built-in theme, or
`undef`.

## extends

The theme this one was derived from, or `undef` for a built-in theme.

## palette

A new hash reference with every token's color as `[r, g, b, a]`.

## token

```kdl
my $accent = $theme->token('accent');
```

One token's color as a new `[r, g, b, a]`. Unknown tokens die.

## look

```kdl
my $color = $theme->look( 'button', 'border.color', 'focused' );
my $color = $theme->look( 'button', 'border.color', 'focused', ['primary'] );
```

The value of a slot in a state (`normal` by default) for a widget of a
family with the given classes: `[r, g, b, a]` for a color, a
[Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item for a style, 1 or 0 for
`border.enabled`, `'reverse'`, or `undef` for none. Dies for a slot
or state the family does not have.

## look\_table

```kdl
my $looks = $theme->look_table( 'button', ['primary'] );
my $color = $looks->{'border.color.focused'};
```

The looks of a family for a widget with the given classes, under
`slot.state` keys: the family's values with the variant of every
class that has one laid over them, in the order of the classes. Every
slot has a `slot.normal` entry; a state has an entry only when the
theme gives it a value of its own, so a reader falls back to the
normal entry (as ["look"](#look) does). The hash is shared and cached; do not
change it. This is what widgets read while a frame is drawn.

## has\_variant

```kdl
if ( $theme->has_variant( 'button', 'primary' ) ) { ... }
```

Whether the theme (or one it extends) defines the variant.

# FUNCTIONS

Plain functions, called as `Term::Fabulous::Theme::NAME(...)`.

## families, tokens, states, builtin\_names

The names of the families, the tokens, the states (`normal` first)
and the built-in themes.

## has\_token

```kdl
if ( Term::Fabulous::Theme::has_token('accent') ) { ... }
```

Whether the word names a token of the palette; every theme has the
same tokens. [Term::Fabulous::Text::Style](Text/Style.md) uses it to read a token as
a color.

## slots

```kdl
my %states_of = Term::Fabulous::Theme::slots('button');
```

The slots of a family, each with the list of its states besides
`normal`.

## is\_family, has\_slot

```kdl
Term::Fabulous::Theme::is_family('button');                      # 1
Term::Fabulous::Theme::has_slot( 'button', 'text', 'pressed' );    # 1
```

Whether a family exists, and whether it has a slot in a state.

## slot\_info

```kdl
my $info = Term::Fabulous::Theme::slot_info( 'button', 'background' );
# {
#     kind     => 'color',
#     required => 0,
#     reverse  => 1,
#     grid     => 0,
#     states   => [ 'disabled', 'focused', 'hovered', 'pressed' ],
#     default  => { normal => 'none', pressed => 'reverse', hovered => 'normal', ... },
# }
```

What the vocabulary says about one slot of a family, as a new hash
reference:

- `kind`

    `color`, `style` or `boolean`: whether the slot takes a color, a
    border style, or true or false (see ["Values"](#values)).

- `required`

    1 when the slot cannot be `none` (see ["Values"](#values)), else 0. Always 1
    for a boolean slot.

- `reverse`

    1 when the slot may be `reverse` (`button.background`), else 0.

- `grid`

    1 when the slot needs a border style with joints (`tabs.line.style`),
    else 0.

- `states`

    The states the slot has besides `normal`, sorted by name.

- `default`

    The value of every state, `normal` included, before any theme sets
    it: a token name, a style name, `true` or `false`, `none`,
    `reverse`, or `normal` for a state that looks like the normal
    state. The built-in themes keep these
    defaults and differ only in their palettes.

Dies for an unknown family or slot, naming the known ones.

## check\_value

```kdl
my $value = Term::Fabulous::Theme::check_value( 'button', 'border.color', 'focused', 'accent' );
my $style = Term::Fabulous::Theme::check_value( 'tabs', 'line.style', 'normal', 'Double' );
my $on    = Term::Fabulous::Theme::check_value( 'input', 'border.enabled', 'normal', 1 );    # 'true'
```

Checks a value a theme would give a slot in a state, by the rules of
["Values"](#values), and returns it as the theme stores it: a token name, `none`
or `reverse` as a string, a color as `[r, g, b, a]`, a style as a
[Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) item, a boolean as the string
`true` or `false`; `undef` becomes `none`.
Dies with the reason when the slot cannot take the value, for example
`Term::Fabulous::Theme: tabs.line.style cannot be 'none'`, and for a
slot or state the family does not have. Theme editors use it to check a
value before they write it.

## generation, bump\_generation

```kdl
my $now = Term::Fabulous::Theme::generation();
```

A process-wide counter that a UI bumps when its theme is set, so that
every widget looks its looks up again in the next frame. Widget
authors read it through [Term::Fabulous::Role::Themed](Role/Themed.md); only UI
classes call `bump_generation`.

# SEE ALSO

["THEMES" in Term::Fabulous::Manual::Looks](Manual/Looks.md#themes), [Term::Fabulous::Role::Themed](Role/Themed.md),
[Term::Fabulous::Color](Color.md), [Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md),
["classes" in Term::Fabulous::Widget](Widget.md#classes).
