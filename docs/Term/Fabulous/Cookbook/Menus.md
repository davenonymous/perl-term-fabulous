# NAME

Term::Fabulous::Cookbook::Menus - Recipes: menu bars, context menus and status bars

# DESCRIPTION

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Forms](Forms.md). Next page: [Term::Fabulous::Cookbook::Layout](Layout.md).

The recipes on this page give a program the parts that most
applications share: a menu bar that shows what the program can do, a
menu that opens where the user right-clicks, and a status bar that says
what just happened. Each recipe is a complete program, shipped in
`examples/cookbook/`, with a screenshot and notes on the lines that
matter.

The recipes use [Term::Fabulous::Commands](../Commands.md) and
[Term::Fabulous::Command](../Command.md), which keep the program's commands and their
keys in one place, [Term::Fabulous::Widget::MenuBar](../Widget/MenuBar.md) and
[Term::Fabulous::Widget::Menu](../Widget/Menu.md), which show the commands, and
[Term::Fabulous::Widget::StatusBar](../Widget/StatusBar.md). How these work together is
explained in [Term::Fabulous::Manual::Menus](../Manual/Menus.md). The status bar is part
of ["STATUS BARS" in Term::Fabulous::Manual::Feedback](../Manual/Feedback.md#status-bars). The prompts that
the menu commands open are in
["Confirm before quitting (Prompt)" in Term::Fabulous::Cookbook::Forms](Forms.md#confirm-before-quitting-prompt).

The recipes on this page:

- ["Give a program a menu bar (MenuBar, Commands)"](#give-a-program-a-menu-bar-menubar-commands)
- ["Open a menu with a right click or the Menu key (Menu)"](#open-a-menu-with-a-right-click-or-the-menu-key-menu)
- ["Show messages and state in a status bar (StatusBar)"](#show-messages-and-state-in-a-status-bar-statusbar)

# Give a program a menu bar (MenuBar, Commands)

Goal: a to-do list with a menu bar. The menus add to-dos, remove the
finished ones, switch a setting on and off, and quit. Every menu item
also has a key that works without the menu.

This program is shipped as `examples/cookbook/menu-bar.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Commands;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Checkbox;
use Term::Fabulous::Widget::MenuBar;
use Term::Fabulous::Widget::Prompt;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
my $list = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 2, top => 1 } } );

my @todos     = ( [ 'Water the plants', 1 ], [ 'Call the bank', 0 ], [ 'Fix the bike', 0 ], [ 'Book the train', 1 ], [ 'Answer Grace', 0 ] );
my $show_done = 1;

# The list shows a check box per to-do; checking one marks it done.
sub show_todos () {
        $list->clear_children;
        foreach my $todo ( grep { $show_done || !$_->[1] } @todos ) {
                my $box = Term::Fabulous::Widget::Checkbox->new( label => $todo->[0], checked => $todo->[1] );
                $box->on( Change => sub ($event) { $todo->[1] = $event->value; return } );
                $list->add_child($box);
        }
        return;
}
show_todos();

my $ui;
my $commands = Term::Fabulous::Commands->new(
        commands => [
                {
                        id    => 'add',
                        label => 'Add...',
                        keys  => ['Ctrl+N'],
                        run   => sub {
                                Term::Fabulous::Widget::Prompt->ask( $ui, title => 'New to-do', label => 'To do', required => 1 )->on(
                                        Answer => sub ($event) {
                                                return if $event->button ne 'ok';
                                                push @todos, [ $event->value('value'), 0 ];
                                                show_todos();
                                                return;
                                        }
                                );
                        },
                },
                {
                        id    => 'clean',
                        label => 'Remove done',
                        keys  => ['Ctrl+D'],
                        run   => sub {
                                @todos = grep { !$_->[1] } @todos;
                                show_todos();
                        },
                        enabled => sub {
                                grep { $_->[1] } @todos;
                        },
                },
                { id => 'quit', label => 'Quit', keys => ['Ctrl+Q'], run => sub { $ui->loop->stop } },
                { id => 'done', label => 'Show done', keys => ['Alt+d'], run => sub { $show_done = !$show_done; show_todos() }, checked => sub { $show_done } },
        ],
);

my $menu_bar = Term::Fabulous::Widget::MenuBar->new(
        commands => $commands,
        caption  => 'To-do',
        menus    => [ { title => 'List', items => [qw(add clean - quit)] }, { title => 'View', items => ['done'] } ],
);
$root->add_child( $menu_bar, $list );

$ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$commands->listen($root);
$menu_bar->listen($root);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-menu-bar.svg" alt="A to-do list of five check boxes below a menu bar with List and View and the caption To-do. The View menu is open and shows Show done with a check mark and the key Alt+d"></p>
</div>

- The program does not build menus item by item. It describes its
commands once, in a [Term::Fabulous::Commands](../Commands.md) table: an id, the label
the menus show, the keys, and the code that runs. The menus then name
the commands by id, and `'-'` draws a line between groups of items.
- `$commands->listen($root)` makes the keys work everywhere. A key
press goes to the focused check box first and bubbles up to the root,
so the keys a check box does not use, such as `Ctrl+N`, reach the
commands. `$menu_bar->listen($root)` does the same for the keys
that open the menus: `F10` opens the first menu, and `Alt` with the
underlined letter of a title opens that menu (`Alt+l` for List,
`Alt+v` for View).
- Remove done has an `enabled` code reference. While no to-do is
checked, the menu shows the item dimmed and skips it, and `Ctrl+D`
does nothing.
- Show done is a _toggle_: its `checked` code reference tells the menu
whether to draw the check mark. The menu asks the code each time it
draws, so the mark always shows the current setting, whether the user
switched it with the menu or with `Alt+d`.
- Add opens a prompt that asks for the text of the new to-do (see
["ask" in Term::Fabulous::Widget::Prompt](../Widget/Prompt.md#ask)). The menu closes before the
command runs, so the prompt gives the focus back to the to-do list when
it closes.
- The bar takes the keyboard focus only while a menu is open, so Tab
moves between the check boxes and never stops on the bar.

# Open a menu with a right click or the Menu key (Menu)

Goal: a text area with a context menu of Cut, Copy, Paste and Select
all. A right click opens it where the pointer is, and `Shift+F10` or
the Menu key opens it from the keyboard.

This program is shipped as `examples/cookbook/context-menu.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_RIGHT TB_MOD_MOTION);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Menu;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextArea;
use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $root = Term::Fabulous::Widget::Box->new(
        layout => {
                layout_direction => CLAY_TOP_TO_BOTTOM,
                sizing           => { width => sizing_grow(), height => sizing_grow() },
                padding          => { left  => 2, right => 2, top => 1, bottom => 1 },
                child_gap        => 1,
        },
);
my $notes = Term::Fabulous::Widget::TextArea->new(
        value  => "Select some words, then right-click,\nor press Shift+F10 or the Menu key.\n",
        layout => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);
$root->add_child( Term::Fabulous::Widget::Text->new( text => 'Notes' ), $notes );

# The text area knows these keys already; the menu shows them, and
# offers Cut and Copy only while text is selected.
my $editor = $notes->editor;
my $menu   = Term::Fabulous::Widget::Menu->new(
        items => [
                { label => 'Cut',   keys => ['Ctrl+X'], run => sub { $editor->cut },  enabled => sub { $editor->has_selection } },
                { label => 'Copy',  keys => ['Ctrl+C'], run => sub { $editor->copy }, enabled => sub { $editor->has_selection } },
                { label => 'Paste', keys => ['Ctrl+V'], run => sub { $editor->paste } },
                '-',
                { label => 'Select all', keys => ['Ctrl+A'], run => sub { $editor->select_all } },
        ],
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24, stop_on_ctrl_c => 0 );

# A right click opens the menu at the pointer...
$notes->on(
        Mouse => sub ($event) {
                return Clay::UI::Enum::Result->CONTINUE unless $event->key == TB_KEY_MOUSE_RIGHT && !( $event->modifiers & TB_MOD_MOTION );
                $menu->open( $ui, x => $event->x, y => $event->y );
                return;
        }
);

# ... and the keyboard opens it in the top left corner of the text area.
# Ctrl+Q quits.
$root->on(
        KeyPress => sub ($event) {
                my $key = $event->key_name // '';
                if ( $key eq 'Shift+F10' || $key eq 'Menu' ) {
                        my $box = $ui->bounding_box($notes);
                        $menu->open( $ui, x => $box->{x} + 1, y => $box->{y} + 1 );
                        return;
                }
                if ( $key eq 'Ctrl+Q' ) {
                        $ui->loop->stop;
                        return;
                }
                return Clay::UI::Enum::Result->CONTINUE;
        }
);

$ui->interaction->set_focused_widget($notes);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-context-menu.svg" alt="A text area whose first two words are selected, with a context menu opened over it where it was right-clicked: Cut is highlighted, then Copy, Paste, a line and Select all, each with its key"></p>
</div>

- The items are hash references, because they belong to this menu only:
a label, the keys to show, the code to run, and for Cut and Copy an
`enabled` code that asks the editor of the text area whether text is
selected. A menu of items that are used elsewhere too takes the ids of
a [Term::Fabulous::Commands](../Commands.md) table instead, as in the recipe above.
- The menu is built once and opened as often as needed.
`$menu->open( $ui, x => ..., y => ... )` puts its top left corner
at a cell of the screen. Near the edge of the screen it moves left or
up as far as it must, so it is always shown whole.
- The listener on the text area checks for the right button and lets
every other mouse event pass with `CONTINUE`, so a left click still
places the cursor. A right click does not change the selection, which
is why Cut and Copy are available in the picture.
- Not every terminal reports the Menu key. `Shift+F10`, the usual
alternative on other systems, works everywhere. The keyboard has no
pointer to open the menu at, so the program opens it at the top left
corner of the text area. To open a menu below a widget instead, pass
`below => $widget`.
- While the menu is open, it has the keyboard focus. The arrow keys, a
letter or the mouse highlight an item, and `Enter` or a click chooses
it. `Escape` or a click anywhere else closes the menu, and the focus
goes back to the text area. Choosing an item closes the menu before the
item runs, so Cut and Paste act on the text area as if the user had
pressed their keys.
- The program passes `stop_on_ctrl_c => 0`, so `Ctrl+C` copies, as
the menu says, and quits with `Ctrl+Q` instead.

# Show messages and state in a status bar (StatusBar)

Goal: a journal with a status bar. The bar shows a hint when the
program starts, a message when the user saves, and on the right the
number of words and whether the entry has unsaved changes.

This program is shipped as `examples/cookbook/status-bar.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::StatusBar;
use Term::Fabulous::Widget::TextArea;
use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

my $root    = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
my $journal = Term::Fabulous::Widget::TextArea->new( wrap => 1, layout => { sizing => { width => sizing_grow(), height => sizing_grow() } } );
my $saved   = '';

# The parts on the right are read whenever a frame is drawn, so they
# follow the typing without any code that updates them.
my $status = Term::Fabulous::Widget::StatusBar->new(
        message => 'Write today\'s entry. Ctrl+S saves, Ctrl+Q quits.',
        timeout => 3,
        parts   => sub {
                my $text  = $journal->value;
                my $words = () = $text =~ /\S+/g;
                return ( ( $text ne $saved ? [ 'unsaved', 'accent' ] : () ), [ "$words words", 'dim' ] );
        },
);
$root->add_child( $journal, $status );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

$root->on(
        KeyPress => sub ($event) {
                my $key = $event->key_name // '';
                if ( $key eq 'Ctrl+S' ) {
                        my $text = $journal->value;
                        if ( $text =~ /\S/ ) {
                                $saved = $text;
                                $status->message( 'Saved the entry.', 'success' );
                        }
                        else {
                                $status->message( 'Nothing to save yet.', 'warning' );
                        }
                        return;
                }
                if ( $key eq 'Ctrl+Q' ) {
                        $ui->loop->stop;
                        return;
                }
                return Clay::UI::Enum::Result->CONTINUE;
        }
);

$ui->interaction->set_focused_widget($journal);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-status-bar.svg" alt="A journal entry in a text area and, below it, a status bar with the green message Saved the entry. on the left and 8 words on the right"></p>
</div>

- `message` shows a message on the left. Its second argument is the
kind, which gives the color: `success` is green, `warning` yellow,
`danger` red, and `info`, the default, the color of plain text.
- With `timeout => 3`, every message goes away three seconds after
it was shown. The hint given to `new` is the exception and stays until
the first message replaces it.
- The parts on the right come from a code reference. The bar calls it
whenever a frame is drawn, and a frame is drawn after every key, so the
word count follows the typing and nothing has to update it. The code
returns a list of parts, each a text with a kind. `unsaved` appears
only while the text differs from the saved one.

# SEE ALSO

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Forms](Forms.md). Next page: [Term::Fabulous::Cookbook::Layout](Layout.md).

[Term::Fabulous::Manual::Menus](../Manual/Menus.md) - commands, keys, menu bars and
context menus.

["STATUS BARS" in Term::Fabulous::Manual::Feedback](../Manual/Feedback.md#status-bars) - the status bar.

[Term::Fabulous::Widget::MenuBar](../Widget/MenuBar.md), [Term::Fabulous::Widget::Menu](../Widget/Menu.md),
[Term::Fabulous::Widget::StatusBar](../Widget/StatusBar.md), [Term::Fabulous::Commands](../Commands.md) - the
class pages.
