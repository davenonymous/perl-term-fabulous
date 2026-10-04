# NAME

Term::Fabulous::Layout - Build a widget tree from a KDL layout description

# SYNOPSIS

```perl
use Term::Fabulous;
use Term::Fabulous::Layout;

my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text

Box "root" {
        layout direction=down gap=1
        sizing width=grow height=grow
        padding left=1 right=1
        border style=Round color="rgb(20, 140, 56)"
        border_width 1
        background_color "#141937"

        Text "greeting" {
                text "Hello!"
                text_color "rgba(220, 34, 220, 1.0)"
        }
}
KDL

my $root = $layout->build;
$root->find_by_id('greeting')->text('Hello, KDL!');
Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;

# Or read the layout from a file:
my $from_file = Term::Fabulous::Layout->new( file => 'screens/main.kdl' );
```

# DESCRIPTION

Instead of building a widget tree in Perl, you can describe it in a
layout file written in KDL, a small document language of nested nodes
(see [https://kdl.dev](https://kdl.dev)). Term::Fabulous::Layout parses such a
description with [Text::KDL::XS](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS), loads the widget classes it names and
builds the widget tree. You then hand the root widget to
[Term::Fabulous](../../../README.md) or [Term::Fabulous::Static](Static.md) as usual, and attach
event listeners in Perl.

A layout file describes the static part of a user interface: which
widgets there are, how they are nested, sized, colored and bordered,
and the initial values of input widgets. Behavior (listeners, timers)
stays in Perl. Everything a layout can do, Perl can do as well; a few
options are available only in Perl (see ["LIMITATIONS"](#limitations)).

This page is the reference. The guide is
[the KDL chapter of the manual](Manual/KDL.md#kdl-layout-files),
with complete programs and their screenshots. This is
`examples/kdl-layout.pl`, which builds its screen from the layout file
`examples/kdl-layout.kdl`:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/example-kdl-layout.svg" alt="A title bar, a sidebar with the buttons web, db and mail with db focused, and a main panel showing the details of the db server"></p>
</div>

# CONSTRUCTOR

## new

```perl
my $layout = Term::Fabulous::Layout->new( string => $kdl_text );
my $layout = Term::Fabulous::Layout->new( file   => $path );
```

Parses the document, checks its `use` instructions, loads the widget
classes and finds the root widget node. The widgets themselves are
built later, by ["build"](#build). Every problem dies with a message that starts
with `Term::Fabulous::Layout:` (see ["ERRORS"](#errors)). Unknown parameters
die.

Give exactly one of these parameters; giving none or both dies.

- `string`

    The layout as a Perl character string (decoded text). A here-document
    in a source file with `use utf8` is such a string.

- `file`

    The path of a layout file. The file is read as UTF-8 encoded bytes.
    Dies if it cannot be opened.

# METHODS

## build

```perl
my $root = $layout->build;
```

Builds the widget tree and returns its root widget. The tree is built
only once: later calls return the same root widget. Since a widget can
be part of only one tree, build a new Term::Fabulous::Layout object if
you need a second copy of the same widgets.

Each widget is built with `$class->new( id => $id )`, then its
property nodes are applied to the finished widget with
`$widget->apply_layout_node($node)` (see
[Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md)), and then its child widgets
are built and added. So a layout sets properties like a program calling
the accessors after `new`, and the order of the properties of related
values does not matter (a Slider's `min` and `max`, a Dropdown's
`options` and `value`). Invalid properties die here, not in ["new"](#new).

To get at the other widgets of the tree, call
["find\_by\_id" in Term::Fabulous::Widget](Widget.md#find_by_id) on the root (see ["EXAMPLES"](#examples)).

## root\_widget

```perl
my $root = $layout->root_widget;
```

The root widget built by ["build"](#build), or `undef` before the first call
of ["build"](#build).

## required\_modules

```perl
my %module_by_alias = %{ $layout->required_modules };    # ( Box => 'Term::Fabulous::Widget::Box', ... )
```

A hash reference that maps every widget name declared with `use` to
its Perl module.

## raw

```perl
my $document = $layout->raw;
```

The parsed [Text::KDL::XS::Document](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS%3A%3ADocument), for programs that want to
inspect the layout's nodes themselves, for example a tool that lists the
ids of a layout file.

## walk\_nodes

```perl
$layout->walk_nodes( sub ($node) {
        say $node->name;
} );
```

Calls the code reference once for every node of the document
([Text::KDL::XS::Node](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS%3A%3ANode) objects), including `use` instructions and
property nodes, breadth first: all top-level nodes, then their
children, and so on. Nodes commented out with `/-` are not part of the
document. Returns nothing.

# THE KDL FORMAT

## A short introduction to KDL

A KDL document is a list of nodes. A node has a name, followed by
optional arguments, optional `key=value` properties and an optional
block of child nodes in braces:

```kdl
name argument1 argument2 key=value other="value" {
        child-node
        another-child 42
}
```

Nodes end at a line break or a semicolon, so short nodes can share a
line: `RadioButton { label "Small"; value "s"; }`.

Values are written like this:

| Value                     | Example           | Perl value     |
| ------------------------- | ----------------- | -------------- |
| string in double quotes   | "Hello, world"    | 'Hello, world' |
| bare word                 | grow, Round, down | 'grow', ...    |
| integer or decimal number | 40, 2.5, 0x1f     | 40, 2.5, 31    |
| `boolean`                 | #true, #false     | 1, 0           |
| no value                  | #null             | undef          |

Strings that contain spaces, parentheses, `#`, `=` or other special
characters must be quoted: `"#141937"`, `"fixed(10)"`,
`"rgb(1, 2, 3)"`. Inside quotes, `\n` is a line break, `\"` a quote
and `\\` a backslash; a raw string, `#"C:\path"#`, takes backslashes
as they are. Boolean properties must be written `#true` and `#false`
(`1` and `0` are accepted too); any other value, such as `"no"` or
`"false"` in quotes, dies, and a bare `true` is a syntax error.

Comments are `// to the end of the line`, `/* blocks */`, and `/-`
in front of a node, which comments out the whole node with its
children:

```kdl
/- Text { text "not shown"; }
```

## Top level: use instructions and one root widget

The top level of a layout contains `use` instructions, which declare
the widget classes, and exactly one widget node, the root widget.
Nothing else is allowed at the top level.

```kdl
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::TextField as TextField
use My::App::Widget::Clock as Clock

Box "root" { ... }
```

`use Module::Name as Alias` declares that nodes named `Alias` build
`Module::Name` widgets. `Module::Name` must be a plain Perl package
name (letters, digits, `_` and `::`). `Alias` must start with an
uppercase letter and contain only letters, digits and `_`. Each alias
can be declared only once. The module is loaded with `require` and
must compose [Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md), which all
Term::Fabulous widgets do (see ["NODE TYPES"](#node-types)); your own widgets can
too (see [using your widget in KDL](Manual/CustomWidgets.md#using-your-widget-in-kdl)).

The short form `use Module::Name` uses the full module name as the
widget node name, so the module name must start with an uppercase
letter:

```kdl
use Term::Fabulous::Widget::Box

Term::Fabulous::Widget::Box "root" { ... }
```

`use` takes no `key=value` properties and no children.

## Widget nodes

```kdl
Alias "id" {
        property-node ...
        ChildAlias "child-id" { ... }
}
```

A node whose name is a declared alias builds one widget. It takes at
most one argument, a string, which becomes the widget's `id`, and no
`key=value` properties. Inside its braces:

- Nodes whose names start with an **uppercase** letter are child widgets.
Their names must be declared aliases. Every widget except
[Term::Fabulous::Widget::Text](Widget/Text.md) and [Term::Fabulous::Widget::Table](Widget/Table.md)
accepts children.
- Every other node is a property of the widget, such as `sizing` or
`text`. Each widget class documents its properties in the KDL
PROPERTIES section of its page (see ["NODE TYPES"](#node-types)); an unknown one
dies with the list of the known names.

Properties are applied after the widget was constructed, with the same
checks as the Perl method of the same name, in the order they appear;
values that depend on each other are applied together, wherever they
stand: a dropdown's options before its `value`, a slider's `min`,
`max` and `step` as one range before its `value`, a text field's
`max_length` before its `value`.

Ids are optional. They are used by Clay to keep track of widgets between
frames, they are required for a ScrollBox, and they are how you find
widgets after ["build"](#build) (see ["EXAMPLES"](#examples)). Ids must be unique within
the tree. ["build"](#build) does not check this; the first frame drawn with
duplicate ids dies with
`Clay error: An element with this ID was already previously declared during this layout.`

## Kinds of property nodes

A property node has one of two shapes:

- One argument: `text "Hello"`, `border_width 1`, `checked #true`.
- Only key=value pairs: `padding left=1 right=1`,
`border_width left=1 right=2`.

A property node never has children; the only exceptions are the
structured properties of a few widgets that say so, such as a table's
`column` with its `style` nodes. A property whose name ends in
`_color` takes any color string [Term::Fabulous::Color](Color.md) understands
(`"#61afef"`, `"#61afef80"`, `"rgb(97, 175, 239)"`,
`"rgba(97, 175, 239, 0.5)"`, `"hsl(207, 82%, 66%)"`, ...; see
["Color formats" in Term::Fabulous::Manual::Looks](Manual/Looks.md#color-formats)). Color names such as
`"red"` are not color strings.

# NODE TYPES

Every widget class of Term::Fabulous can be declared in a layout. The
table lists them with the alias the examples use; each link leads to the
list of properties the class accepts. All of them except Text accept
the ["Box properties"](#box-properties).

| Alias            | Class                                    | Properties                       |
| ---------------- | ---------------------------------------- | -------------------------------- |
| Box              | Term::Fabulous::Widget::Box              | Box properties                   |
| Text             | Term::Fabulous::Widget::Text             | text, text_color, wrap_mode, ... |
| Button           | Term::Fabulous::Widget::Button           | Box + focus and press looks      |
| Dialog           | Term::Fabulous::Widget::Dialog           | Box + backdrop, z_index          |
| ScrollBox        | Term::Fabulous::Widget::ScrollBox        | Box + horizontal, vertical       |
| Canvas           | Term::Fabulous::Widget::Canvas           | Box                              |
| PixelCanvas      | Term::Fabulous::Widget::PixelCanvas      | Box                              |
| TextField        | Term::Fabulous::Widget::TextField        | input widget + text options      |
| TextArea         | Term::Fabulous::Widget::TextArea         | input widget + text options      |
| Checkbox         | Term::Fabulous::Widget::Checkbox         | input widget + label, checked    |
| RadioGroup       | Term::Fabulous::Widget::RadioGroup       | Box + value, disabled            |
| RadioButton      | Term::Fabulous::Widget::RadioButton      | input widget + label, value      |
| Dropdown         | Term::Fabulous::Widget::Dropdown         | input widget + options, value    |
| Slider           | Term::Fabulous::Widget::Slider           | input widget + range, value      |
| StarRating       | Term::Fabulous::Widget::StarRating       | input widget + max, value, half  |
| SegmentedControl | Term::Fabulous::Widget::SegmentedControl | input widget + options, value    |
| Divider          | Term::Fabulous::Widget::Divider          | Box + text, line_style, ...      |
| Accordion        | Term::Fabulous::Widget::Accordion        | Box + multiple, bordered, ...    |
| Item             | Term::Fabulous::Widget::Accordion::Item  | Box + title, open, disabled      |
| Tabs             | Term::Fabulous::Widget::Tabs             | Box + side, orientation, ...     |
| Page             | Term::Fabulous::Widget::Tabs::Page       | Box + title, active, disabled    |
| TabBar           | Term::Fabulous::Widget::Tabs::Bar        | Box + side, orientation, ...     |
| Tab              | Term::Fabulous::Widget::Tabs::Button     | Button + title, icon             |
| ProgressBar      | Term::Fabulous::Widget::ProgressBar      | Box + range, value, style, ...   |
| Spinner          | Term::Fabulous::Widget::Spinner          | Box + style, frames, label       |
| Toast            | Term::Fabulous::Widget::Toast            | Box + kind, title, message, ...  |
| Table            | Term::Fabulous::Widget::Table            | Box + columns, lines, sort, ...  |
| LineChart        | Term::Fabulous::Widget::LineChart        | chart + series, axes, ...        |
| AreaChart        | Term::Fabulous::Widget::AreaChart        | chart + series, axes, ...        |
| BarChart         | Term::Fabulous::Widget::BarChart         | chart + series, axes, ...        |
| ScatterPlot      | Term::Fabulous::Widget::ScatterPlot      | chart + series, axes, ...        |
| Histogram        | Term::Fabulous::Widget::Histogram        | chart + series, bins, ...        |
| Sparkline        | Term::Fabulous::Widget::Sparkline        | chart + values, type, ...        |
| PieChart         | Term::Fabulous::Widget::PieChart         | chart + slice, sort, ...         |
| DonutChart       | Term::Fabulous::Widget::DonutChart       | pie chart properties             |
| PolarAreaChart   | Term::Fabulous::Widget::PolarAreaChart   | pie chart + max, ticks           |
| RadarChart       | Term::Fabulous::Widget::RadarChart       | chart + series, labels, ticks    |

The properties of each class:

- [Box](Widget/Box.md#kdl-properties) (summarized in ["Box properties"](#box-properties))
- [Text](Widget/Text.md#kdl-properties)
- [Button](Widget/Button.md#kdl-properties)
- [Dialog](Widget/Dialog.md#kdl-properties)
- [ScrollBox](Widget/ScrollBox.md#kdl-properties)
- [Canvas](Widget/Canvas.md#kdl-properties)
- [PixelCanvas](Widget/PixelCanvas.md#kdl-properties)
- [TextField](Widget/TextField.md#kdl-properties)
- [TextArea](Widget/TextArea.md#kdl-properties)
- [Checkbox](Widget/Checkbox.md#kdl-properties)
- [RadioGroup](Widget/RadioGroup.md#kdl-properties)
- [RadioButton](Widget/RadioButton.md#kdl-properties)
- [Dropdown](Widget/Dropdown.md#kdl-properties)
- [Slider](Widget/Slider.md#kdl-properties)
- [StarRating](Widget/StarRating.md#kdl-properties)
- [SegmentedControl](Widget/SegmentedControl.md#kdl-properties)
- [Divider](Widget/Divider.md#kdl-properties)
- [Accordion](Widget/Accordion.md#kdl-properties) and [Item](Widget/Accordion/Item.md#kdl-properties)
- [Tabs](Widget/Tabs.md#kdl-properties) and [Page](Widget/Tabs/Page.md#kdl-properties), [TabBar](Widget/Tabs/Bar.md#kdl-properties) and [Tab](Widget/Tabs/Button.md#kdl-properties)
- [ProgressBar](Widget/ProgressBar.md#kdl-properties)
- [Spinner](Widget/Spinner.md#kdl-properties)
- [Toast](Widget/Toast.md#kdl-properties)
- [Table](Widget/Table.md#kdl-properties)
- [LineChart](Widget/LineChart.md#kdl-properties)
- [AreaChart](Widget/AreaChart.md#kdl-properties)
- [BarChart](Widget/BarChart.md#kdl-properties)
- [ScatterPlot](Widget/ScatterPlot.md#kdl-properties)
- [Histogram](Widget/Histogram.md#kdl-properties)
- [Sparkline](Widget/Sparkline.md#kdl-properties)
- [PieChart](Widget/PieChart.md#kdl-properties)
- [DonutChart](Widget/DonutChart.md#kdl-properties)
- [PolarAreaChart](Widget/PolarAreaChart.md#kdl-properties)
- [RadarChart](Widget/RadarChart.md#kdl-properties)

The properties shared by several classes are described once, on the
page of their base class: those of all input widgets in
["KDL PROPERTIES" in Term::Fabulous::Widget::Input](Widget/Input.md#kdl-properties), those of TextField and
TextArea in ["KDL PROPERTIES" in Term::Fabulous::Widget::TextInput](Widget/TextInput.md#kdl-properties), those
of all charts in ["KDL PROPERTIES" in Term::Fabulous::Widget::Chart](Widget/Chart.md#kdl-properties) and
those of the charts with axes in
["KDL PROPERTIES" in Term::Fabulous::Widget::XYChart](Widget/XYChart.md#kdl-properties). These four base
classes are abstract and cannot be used as nodes themselves. The parts
other widgets build for themselves (such as
`Term::Fabulous::Widget::Dialog::Backdrop`, `Term::Fabulous::Widget::Dropdown::List`
and the `Term::Fabulous::Widget::Table::*` parts) cannot be built from
a layout either.

A Dialog is not drawn until it is opened from Perl, and it is opened
on its own, not as a child of another widget: describe it as the root of
a layout of its own, build it, and call `$dialog->open($ui)` (see
[Term::Fabulous::Widget::Dialog](Widget/Dialog.md)).

# PROPERTIES

## Box properties

[Term::Fabulous::Widget::Box](Widget/Box.md) and every widget built on it (all widgets
except Text) accept these property nodes. The
[KDL PROPERTIES section of the Box page](Widget/Box.md#kdl-properties)
describes each one with an example, and
[the layout chapter of the manual](Manual/Layout.md#layout)
shows what they do, with pictures.

| Property node                              | Value                                        |
| ------------------------------------------ | -------------------------------------------- |
| layout direction=... gap=N                 | direction: down, ttb, top_to_bottom          |
| line_gap=N line_sizing=...                 | (children top to bottom), right, ltr,        |
|                                            | left_to_right (left to right), wrap,         |
|                                            | ltr_wrap, left_to_right_wrap (left to        |
|                                            | right, wrapping onto new lines) or           |
|                                            | stack, back_to_front, btf (on top of         |
|                                            | each other);                                 |
|                                            | gap (alias child_gap): cells between         |
|                                            | children, an integer >= 0;                   |
|                                            | line_gap: rows between wrapped lines,        |
|                                            | an integer >= 0; line_sizing: grow           |
|                                            | (the default) or fit                         |
| sizing width=... height=...                | each: grow, fit, "grow(MIN)",                |
|                                            | "grow(MIN, MAX)", "fit(MIN)",                |
|                                            | "fit(MIN, MAX)" with MIN and MAX integers    |
|                                            | >= 0 and MIN &lt;= MAX (no MAX: no maximum), |
|                                            | "percent(N)" with N in 0..100 (decimals      |
|                                            | allowed), or "fixed(N)" with N an            |
|                                            | integer >= 0                                 |
| padding left=N right=N top=N bottom=N      | any subset; integers >= 0                    |
| child_alignment x=... y=...                | x: left (the default), center or right;      |
|                                            | y: top (the default), center or bottom       |
| floating attach_to=... parent_id="..."     | takes the box out of the layout and          |
| element=... parent=...                     | draws it on top (see below)                  |
| offset_x=N offset_y=N z_index=N            |                                              |
| pointer_capture=... clip_to=...            |                                              |
| border style=... style-top=...             | style: a border style name (Round, Solid,    |
| style-right=... style-bottom=...           | Heavy, ...) for all four sides; the          |
| style-left=... color=...                   | style-SIDE keys override it for one side;    |
|                                            | color: a color string                        |
| border_width N                             | all four sides, an integer 0..65535          |
| border_width left=N right=N top=N bottom=N | per side; missing sides are 0                |
| background_color "..."                     | a color string                               |
| glyphs_show_through #true                  | #true or #false (the default): whether text  |
|                                            | and borders below a translucent background   |
|                                            | stay visible (see Term::Fabulous::Widget)    |
| border_color "..."                         | a color string (same as border color=)       |
| width_group N                              | an integer 0..1048575; 0 means no group      |
| height_group N                             | an integer 0..1048575; 0 means no group      |

`layout`, `sizing`, `padding`, `border`, `child_alignment` and
`floating` take only the keys shown, and at least one of them. The
border style names are those of
[Term::Fabulous::Enum::BorderStyle](Enum/BorderStyle.md) and are case sensitive. A border
is only drawn on sides with a positive `border_width`.

`width_group` and `height_group` give widgets in different parts of
the tree the same width or height; see
["Equal sizes across the tree" in Term::Fabulous::Manual::Layout](Manual/Layout.md#equal-sizes-across-the-tree).

`floating` sets the widget's `floating` hash (see
["floating" in Term::Fabulous::Widget](Widget.md#floating) and
["Floating widgets" in Term::Fabulous::Manual::Layout](Manual/Layout.md#floating-widgets)); its keys are:

| Key               | Value                                                      |
| ----------------- | ---------------------------------------------------------- |
| `attach_to`       | parent (the default), root or element; element             |
|                   | requires parent_id                                         |
| `parent_id`       | the id of the widget to attach to (with attach_to=element) |
| `element`         | the point of this box placed on the point "parent" of      |
| `parent`          | the widget it is attached to: left_top (the default),      |
|                   | left_center, left_bottom, center_top, center_center,       |
|                   | center_bottom, right_top, right_center, right_bottom       |
| `offset_x`        | an integer added to the position, in cells                 |
| `offset_y`        | an integer added to the position, in cells                 |
| `z_index`         | an integer -32768..32767; higher is drawn on top           |
| `pointer_capture` | capture (the default) or passthrough                       |
| `clip_to`         | none (the default) or attached_parent                      |

```text
Box "root" {
        Button "menu-button" { Text { text "Menu"; } }
        Box "menu" {
                floating attach_to=element parent_id="menu-button" parent=left_bottom
                floating z_index=10
        }
}
```

An unknown name in `child_alignment` or `floating` dies with the
known names.

A property node may appear more than once. A second `padding`,
`sizing`, `layout`, `child_alignment` or `floating` node changes
only the keys it names and keeps the others.

```kdl
Box "panel" {
        layout direction=down gap=1
        sizing width="percent(50)" height=fit
        padding left=1 right=1
        border style=Round style-top=Heavy color="#61afef"
        border_width 1
        background_color "rgb(28, 33, 45)"
}
```

# EXAMPLES

## A form, built from a layout

```perl
use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Layout;

my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text
use Term::Fabulous::Widget::TextField as TextField
use Term::Fabulous::Widget::Checkbox as Checkbox
use Term::Fabulous::Widget::RadioGroup as RadioGroup
use Term::Fabulous::Widget::RadioButton as RadioButton
use Term::Fabulous::Widget::Dropdown as Dropdown
use Term::Fabulous::Widget::Slider as Slider

Box "form" {
        layout direction=down gap=1
        sizing width=grow height=grow
        padding left=1 right=1
        border style=Round color="#61afef"
        border_width 1

        Text "title" {
                text "Sign up"
                text_color "rgb(255, 200, 80)"
        }
        TextField "name" {
                placeholder "Your name"
                max_length 40
        }
        TextField "password" {
                mask "*"
        }
        RadioGroup "plan" {
                layout direction=right gap=2
                value "pro"
                RadioButton { label "Free"; value "free"; }
                RadioButton { label "Pro"; value "pro"; }
        }
        Dropdown "country" {
                placeholder "Country"
                options "Austria" "Germany"
                option "Switzerland" value="CH"
                value "CH"
        }
        Slider "age" {
                min 18
                max 99
                value 30
                value_format "%d years"
        }
        Checkbox "news" {
                label "Send me news"
                checked #true
        }
}
KDL

my $root  = $layout->build;
my $title = $root->find_by_id('title');

# Every Change event bubbles up to the form box.
$root->on( Change => sub ($event) {
        $title->text( 'Changed: ' . $event->target->id );
        return;
} );

Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;
```

`examples/kdl-form.pl` is a longer form of the same kind, and
`examples/kdl-layout.pl` loads its layout from a file; both are shown
with screenshots in ["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](Manual/KDL.md#kdl-layout-files).

## Finding widgets by id

["build"](#build) returns only the root widget. To get at the other widgets,
call ["find\_by\_id" in Term::Fabulous::Widget](Widget.md#find_by_id) on the root: it returns the
first widget (in depth-first order) whose id is the argument, Text
widgets included, or `undef` when there is none. See also
["Find widgets by id" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#find-widgets-by-id).

```perl
my $country = $root->find_by_id('country');
say $country->value;    # CH
```

## Adding what a layout cannot express

Build first, then set the remaining options in Perl:

```perl
my $age = $root->find_by_id('age');
$age->value_format( sub ($value) { $value < 21 ? "$value (young)" : "$value years" } );
$age->on( Change => sub ($event) { ...; return } );
```

# LIMITATIONS

These options exist in Perl but cannot be written in a layout:

- event listeners, and the `classes` of a widget;
- `border_corners` and `outer_border_sides` (see
[Term::Fabulous::Role::HasBorderStyle](Role/HasBorderStyle.md));
- the `expand` key of a widget's `floating` hash;
- the `child_offset` of a ScrollBox;
- code references, such as a Slider's `value_format` as code, and the
other widget-specific options their KDL PROPERTIES sections name as
Perl-only (for example a table's rows and a chart's data callbacks).

Set them in Perl after ["build"](#build), as shown in
["Adding what a layout cannot express"](#adding-what-a-layout-cannot-express).

# ERRORS

Everything that is wrong with a layout dies, either in ["new"](#new) or in
["build"](#build). Messages start with `Term::Fabulous::Layout:`; errors in a
widget's properties also name the widget and its id, followed by the
widget class's own message:

```text
Term::Fabulous::Layout: cannot build widget 'Box' "panel": Term::Fabulous::Widget::Box: unknown layout property 'colour' (known: background_color, border, border_color, border_width, child_alignment, floating, glyphs_show_through, height_group, layout, padding, sizing, width_group)
```

["new"](#new) dies for:

- neither or both of `string` and `file`, or a file that cannot be opened;
- KDL syntax errors (`failed to parse KDL: KDL parse error`; the parser does not report a line number);
- a malformed `use`, an invalid module name or alias, or an alias declared twice;
- a module that cannot be loaded, or that does not compose [Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md);
- a top-level node that is neither `use` nor a declared widget, no root widget, or more than one.

["build"](#build) dies for:

- an undeclared widget name (`unknown widget 'Foo'; declare it with 'use Module::Name as Foo'`);
- a widget node with `key=value` properties, more than one argument, or a non-string id;
- child widgets inside a widget that cannot hold children;
- a widget the class cannot construct with only an id: an abstract base class, or a ScrollBox without an id;
- unknown property names, property nodes of the wrong shape, unknown keys, and invalid values.

# SECURITY

A layout names the Perl modules it loads, and loading a module runs its
code. Only syntactically valid package names are accepted (no paths),
and a module that does not compose [Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md)
is rejected, but only after it has been loaded, so its top-level code
has already run. A layout can therefore load and run any module
installed on the system. Treat layout files like program code: do not
load layouts from untrusted sources.

Properties can only call the accessors a widget class declares in its
`layout_properties` (see [Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md)), so a
layout cannot call arbitrary methods.

# SEE ALSO

["KDL LAYOUT FILES" in Term::Fabulous::Manual::KDL](Manual/KDL.md#kdl-layout-files) (the guide),
[Term::Fabulous::Role::CanParseLayout](Role/CanParseLayout.md) (widget classes in layouts),
["KDL PROPERTIES" in Term::Fabulous::Widget::Box](Widget/Box.md#kdl-properties),
["LAYOUT" in Term::Fabulous::Manual::Layout](Manual/Layout.md#layout),
["Build a form from a KDL file (text fields, radio buttons, dropdown, slider, checkbox)" in Term::Fabulous::Cookbook::Forms](Cookbook/Forms.md#build-a-form-from-a-kdl-file-text-fields-radio-buttons-dropdown-slider-checkbox),
["Describe a table in a KDL layout (columns, lines, sort, groups)" in Term::Fabulous::Cookbook::Tables](Cookbook/Tables.md#describe-a-table-in-a-kdl-layout-columns-lines-sort-groups),
["Describe charts in a KDL layout (series, slices, transforms)" in Term::Fabulous::Cookbook::ChartTechniques](Cookbook/ChartTechniques.md#describe-charts-in-a-kdl-layout-series-slices-transforms),
["Make a widget usable from KDL" in Term::Fabulous::Cookbook::Extending](Cookbook/Extending.md#make-a-widget-usable-from-kdl),
[Text::KDL::XS](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS), [https://kdl.dev](https://kdl.dev).
