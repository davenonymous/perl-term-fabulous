# NAME

Term::Fabulous::Cookbook::Layout - Recipes: layout, borders, colors and themes

# DESCRIPTION

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Forms](Forms.md). Next page: [Term::Fabulous::Cookbook::Tables](Tables.md).

This page shows how to arrange widgets and how they look: labels of
equal width, borders that differ per side, colors derived from one
base color and switched at run time, states and classes to style
widgets from, and a layout that changes with the terminal size. It
uses [Term::Fabulous::Widget::Box](../Widget/Box.md), [Term::Fabulous::Color](../Color.md),
[Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md) and the `Start` and `Resize`
events. The concepts are explained in
[Term::Fabulous::Manual::Layout](../Manual/Layout.md) (sizing, alignment, groups) and
[Term::Fabulous::Manual::Looks](../Manual/Looks.md) (colors and borders); the common
widget parameters and methods are listed in [Term::Fabulous::Widget](../Widget.md).

The recipes on this page:

- ["Line up labels with equal widths (width\_group)"](#line-up-labels-with-equal-widths-width_group)
- ["Use a different border style on each side"](#use-a-different-border-style-on-each-side)
- ["Switch themes at run time (built-in themes and a theme file)"](#switch-themes-at-run-time-built-in-themes-and-a-theme-file)
- ["Mark widgets with states and classes"](#mark-widgets-with-states-and-classes)
- ["Change the layout with the terminal size (Start and Resize events)"](#change-the-layout-with-the-terminal-size-start-and-resize-events)

# Line up labels with equal widths (width\_group)

Goal: line up the values of a list of label/value rows, whatever the
length of each label.

This program is shipped as `examples/cookbook/width-group.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(CLAY_TOP_TO_BOTTOM);

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM } );

foreach my $pair ( [ 'Name', 'Ada Lovelace' ], [ 'Occupation', 'Mathematician' ], [ 'Born', '1815' ] ) {
        my ( $name, $value ) = @$pair;
        my $row   = Term::Fabulous::Widget::Box->new( layout      => { child_gap => 2 } );
        my $label = Term::Fabulous::Widget::Box->new( width_group => 1 );    # all labels: one group
        $label->add_child( Term::Fabulous::Widget::Text->new( text => "$name:", text_color => [ 150, 160, 180, 255 ] ) );
        $row->add_child( $label, Term::Fabulous::Widget::Text->new( text => $value, text_color => [ 255, 255, 255, 255 ] ) );
        $root->add_child($row);
}

# Colors only when STDOUT is a terminal.
Term::Fabulous::Static->new( root => $root, width => 40 )->print;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-width-group.svg" alt="Three label and value rows whose values start in the same column"></p>
</div>

In a pipe or a file, the program prints the same without colors:

```text
Name:        Ada Lovelace
Occupation:  Mathematician
Born:        1815
```

- Widgets with the same non-zero `width_group` get the same width: the
width of the widest of them. The groups work across the whole tree, so
the labels need not share a parent. `height_group` does the same for
heights. See ["Equal sizes across the tree" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#equal-sizes-across-the-tree).
- Group ids are integers from 1 to 1048575; 0 means "no group". Text
widgets cannot join a group, so each label is wrapped in a Box.
- Only widgets sized by their content (the default `fit`, or `grow`)
take part; `fixed` and `percent` sizes are kept.

# Use a different border style on each side

Goal: different border styles on different sides of a box, or a border
on some sides only.

This program is shipped as `examples/cookbook/border-sides.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Static;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $Style = 'Term::Fabulous::Enum::BorderStyle';

sub panel ( $title, %border ) {
        my $box = Term::Fabulous::Widget::Box->new(
                border_color => [ 120, 180, 240, 255 ],
                layout       => { sizing => { width => sizing_grow() }, padding => { left => 1, right => 1 } },
                %border,
        );
        $box->add_child( Term::Fabulous::Widget::Text->new( text => $title, text_color => [ 230, 230, 230, 255 ] ) );
        return $box;
}

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() }, child_gap => 1 } );

# Lines above and below only: no left and right border.
my $rules = panel(
        'Rules above and below',
        border_width        => { top => 1, bottom => 1, left => 0, right => 0 },
        border_style_top    => $Style->Double,
        border_style_bottom => $Style->Solid,
);

# A box with a heavy top edge. border_style sets the sides that have no
# style of their own.
my $header = panel( 'Heavy top edge', border_width => 1, border_style => $Style->Solid, border_style_top => $Style->Heavy );

# A tab-like look: thick left edge only.
my $marker = panel( 'Thick left edge', border_width => { left => 1 }, border_style_left => $Style->Thick );

$root->add_child( $rules, $header, $marker );
Term::Fabulous::Static->new( root => $root, width => 32 )->print( colors => 0 );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-border-sides.svg" alt="Three boxes: double and single rules above and below, a heavy top edge, and a thick left edge"></p>
</div>

The program prints three boxes: the first with a double line above and
a single line below the text and nothing at the sides, the second a
single-line frame with a heavy top edge, the third only a solid block
at the left of its text. In a pipe or a file, it prints the same
without colors:

```text
════════════════════════════════
 Rules above and below
────────────────────────────────
```

```text
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
│ Heavy top edge               │
└──────────────────────────────┘
```

```text
█ Thick left edge
```

- `border_width` decides which sides have a border: a number for all
sides, or a hash with `top`, `right`, `bottom` and `left` (missing
sides have none). Borders take one cell per side inside the box. See
["BORDERS" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#borders).
- `border_style_top`, `border_style_right`, `border_style_bottom` and
`border_style_left` choose the style of each side, `border_style` of
all sides that have no style of their own. So the second box passes
both: `border_style` for three sides and `border_style_top` for the
side that differs. A KDL layout does the same with
`border style=Solid style-top=Heavy`. The four side parameters are
also accessors, which change a side later, for example
`$header->border_style_top( $Style->Double )`;
`border_style` exists only as a parameter of `new`. See
[Term::Fabulous::Role::HasBorderStyle](../Role/HasBorderStyle.md).
- The styles are the items of [Term::Fabulous::Enum::BorderStyle](../Enum/BorderStyle.md), for
example `Solid`, `Round`, `Heavy`, `Double`, `Thick` and `Ascii`;
`examples/border-showcase.pl` shows all of them.

# Switch themes at run time (built-in themes and a theme file)

Goal: let the user switch between the built-in `dark` and `light`
themes and a theme of your own, written in a file, with a key.

This program is shipped as `examples/cookbook/theme-switch.pl`; the
theme file is `examples/themes/ocean.kdl`:

```kdl
theme "ocean" extends="dark"

palette {
        background "#0b1a24"
        background "#0b1a24"
        surface "#10242f"
        border "#2b5a70"
        text "#d8e8ee"
        accent "#5fd3c0"
        success "#9ad46b"
        warning "#f0c674"
        danger "#f27e7e"
}

button {
        border style=Round
        variant "primary" {
                border color="accent"
                text "accent"
                focused { border color="text" }
        }
}

divider {
        line style=Double
}
```

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use Term::Fabulous;
use Term::Fabulous::Theme;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

# Three themes: the two built-in ones, and one from a file. The file
# starts from the dark theme and changes its palette, gives buttons a
# round border and defines a 'primary' variant for them.
my @themes  = ( 'dark', 'light', Term::Fabulous::Theme->from_file("$FindBin::Bin/../themes/ocean.kdl") );
my $current = 0;

# No widget here is given a color: the theme supplies them all. The
# screen is painted in the theme's background, the panel is a Box,
# which paints nothing of its own, and the text, the field and the
# buttons take their family's looks.
my $root = Term::Fabulous::Widget::Box->new(
        layout => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_grow() },
                padding          => { left  => 2, right => 2, top => 1, bottom => 1 },
                child_gap        => 1,
        },
);
my $label = Term::Fabulous::Widget::Text->new( text => 'Theme: dark. Press F2 to switch to the next theme.' );
my $field = Term::Fabulous::Widget::TextField->new( placeholder => 'Type here' );
my $save  = Term::Fabulous::Widget::Button->new( classes => ['primary'], border_width => 1, layout => { padding => { left => 2, right => 2 } } );
$save->add_child( Term::Fabulous::Widget::Text->new( text => 'Save' ) );
$root->add_child( $label, $field, $save );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24, theme => $themes[$current] );

# Setting the theme of the UI is all it takes: every widget reads its
# colors again in the next frame.
$root->on(
        KeyPress => sub ($event) {
                return unless ( $event->key_name // '' ) eq 'F2';
                $current = ( $current + 1 ) % @themes;
                $ui->theme( $themes[$current] );
                $label->text( 'Theme: ' . $ui->theme->name . '. Press F2 to switch to the next theme.' );
                return;
        }
);

$ui->interaction->set_focused_widget($field);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-theme-switch.svg" alt="The ocean theme after two presses of F2: teal text on a dark blue background, a text field holding Light and readable, and a Save button with a teal border"></p>
</div>

- A theme file is KDL, like the layout files: a `theme` node that names
the theme and the built-in theme it extends, a `palette` with the
tokens to change, and a node per widget family with its slots, states
and variants. Everything the file does not set stays as in the theme
it extends. See ["Theme files" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#theme-files) and
["THEME FILES" in Term::Fabulous::Theme](../Theme.md#theme-files).
- `Term::Fabulous::Theme->from_file` reads the file and dies, naming
the node, for anything it does not know. The built-in themes are
passed by name; `$ui->theme` takes either.
- The widgets take their colors from the theme because they were given
none. A widget with a color of its own (`text_color => '#ff5050'`)
keeps it under every theme, and `$widget->reset_look('text_color')`
returns it to the theme. See ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes).
- The Save button has the class `primary`, so under the ocean theme it
draws with the theme's `primary` variant of the `button` family;
under the built-in themes, which define no variant, it looks like any
other button. See ["Variants and classes" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#variants-and-classes).
- Colors for a theme of your own can be computed with
[Term::Fabulous::Color](../Color.md): `lighten`, `darken` and `blend` return
new colors that a palette or a slot takes as they are (see
["Working with colors" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#working-with-colors) and
["new" in Term::Fabulous::Theme](../Theme.md#new)).

# Mark widgets with states and classes

Goal: mark widgets with names, such as "selected" or "danger", and
style them from those marks in one place.

This program is shipped as `examples/cookbook/states-and-classes.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

# One look per state, applied by a single function.
sub restyle ($item) {
        $item->background_color( $item->has_state('selected') ? [ 60, 90, 140, 255 ] : [ 30, 35, 50, 255 ] );
        return;
}

my $menu = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() } } );
my @items;
foreach my $name (qw(Open Save Quit)) {
        my $item = Term::Fabulous::Widget::Button->new(
                id      => lc $name,
                classes => [ 'menu-item', $name eq 'Quit' ? 'danger' : () ],
                layout  => { sizing => { width => sizing_grow() }, padding => { left => 1 } },
        );
        $item->add_child( Term::Fabulous::Widget::Text->new( text => $name, text_color => [ 230, 230, 230, 255 ] ) );
        restyle($item);
        push @items, $item;
}
$menu->add_child(@items);

# The derived states (hovered, pressed, focused) need a UI that owns the
# tree; a Static one is enough here.
my $page = Term::Fabulous::Static->new( root => $menu, width => 20 );

# User states: any name you like.
$items[1]->add_state('selected');
$items[2]->toggle_state('selected')->toggle_state('selected');    # on and off again
restyle($_) foreach @items;

# Derived states follow the interaction tracker and cannot be set.
$page->interaction->set_focused_widget( $items[0] );

# The menu, with Save in the color of the selected state (colors only when
# STDOUT is a terminal), and the states and classes of each item.
$page->print;

foreach my $item (@items) {
        printf "%-5s states: %-18s classes: %s\n", $item->id, join( ',', sort $item->states ), join( ' ', sort $item->get_classes );
}
printf "Save selected: %d, Open focused: %d\n", $items[1]->has_state('selected'), $items[0]->has_state('focused');
eval { $items[0]->add_state('focused'); 1 } or print "add_state('focused') dies\n";
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-states-and-classes.svg" alt="A menu of three items with Save in the selected color, followed by the states and classes of each item"></p>
</div>

In a pipe or a file, the program prints the same without colors:

```text
 Open
 Save
 Quit
open  states: focused            classes: menu-item state_focused
save  states: selected           classes: menu-item state_selected
quit  states:                    classes: danger menu-item
Save selected: 1, Open focused: 1
add_state('focused') dies
```

- Every widget except Text has a set of states: names you choose.
`add_state`, `remove_state`, `toggle_state` and `clear_states`
(which removes all of them) change them and return the widget, so
calls chain; `has_state` tests one, `states` returns all (in no
particular order). See ["add\_state" in Term::Fabulous::Widget](../Widget.md#add_state).
- `hovered`, `pressed`, `focused` and `disabled` are derived states:
they follow the mouse, the focus and the `disabled` flag of widgets
that have them (buttons and input widgets), appear in `states` and
`has_state`, and cannot be changed (`add_state('focused')` dies).
`hovered`, `pressed` and `focused` need a UI that owns the widget
tree; here the [Term::Fabulous::Static](../Static.md) object, which also prints the
menu.
- `classes` is a constructor parameter: a list of names that never
changes. `get_classes` returns the classes followed by `state_NAME`
for every current state, a single list to decide a widget's look from.
- Term::Fabulous does not style widgets from states or classes by
itself; your code does, as `restyle` shows. Call it after changing a
state, or from the listeners of the events that change the derived
states (`OnFocus`, `OnBlur`, `OnPress`, `OnRelease`).

# Change the layout with the terminal size (Start and Resize events)

Goal: arrange two panes side by side on a wide terminal and above each
other on a narrow one.

This program is shipped as `examples/cookbook/resize-aware-layout.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use IO::Async::Loop;
use Term::Fabulous;
use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Text;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM CLAY_LEFT_TO_RIGHT);

use constant NARROW_COLUMNS => 70;

my $root = Term::Fabulous::Widget::Box->new(
        background_color => [ 20, 25, 35, 255 ],
        layout           => { sizing => { width => sizing_grow(), height => sizing_grow() }, child_gap => 1 },
);
foreach my $name (qw(Inbox Message)) {
        my $pane = Term::Fabulous::Widget::Box->new(
                border_width => 1,
                border_style => Term::Fabulous::Enum::BorderStyle->Round,
                border_color => [ 120, 160, 220, 255 ],
                layout       => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1 } },
        );
        $pane->add_child( Term::Fabulous::Widget::Text->new( text => $name, text_color => [ 230, 230, 230, 255 ] ) );
        $root->add_child($pane);
}

# Panes side by side on a wide terminal, stacked on a narrow one.
sub arrange ($columns) {
        my $direction = $columns < NARROW_COLUMNS ? CLAY_TOP_TO_BOTTOM : CLAY_LEFT_TO_RIGHT;
        $root->layout( { %{ $root->layout }, layout_direction => $direction } );
        return;
}

# Start is fired on the root once, when run() has opened the terminal
# and knows its size. Resize is fired twice per resize: before the new
# size is applied (is_pre_event) and after it (is_post_event).
$root->on( Start => sub ($event) { arrange( $event->width ); return } );
$root->on(
        Resize => sub ($event) {
                arrange( $event->width ) if $event->is_post_event;
                return;
        }
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-resize-aware-layout.svg" alt="The Inbox and Message panes side by side on a terminal 80 columns wide"></p>
</div>

The same program on a terminal 60 columns wide:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-resize-aware-layout-narrow.svg" alt="The Inbox and Message panes above each other on a terminal 60 columns wide"></p>
</div>

- [Term::Fabulous::Event::Resize](../Event/Resize.md) is fired on the root widget when the
terminal changes size (once the size has been stable for a tenth of a
second), twice: before the new size is applied (`is_pre_event`) and
after it (`is_post_event`). `width` and `height` are the new size in
cells.
- `run` starts with the real terminal size, not the 80 x 24 given to
`new`, and fires [Term::Fabulous::Event::Start](../Event/Start.md) with it before the
first frame, so the same `arrange` runs at the start and after every
resize.
- `layout` is an accessor: give it a new hash to change the layout.
`arrange` copies the current hash and changes only
`layout_direction`. The next frame uses the new layout. See
["Changing the layout at run time" in Term::Fabulous::Manual::Layout](../Manual/Layout.md#changing-the-layout-at-run-time).
- Usually you need none of this: `grow` and `percent` sizes follow the
terminal size by themselves.

# SEE ALSO

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Forms](Forms.md). Next page: [Term::Fabulous::Cookbook::Tables](Tables.md).
