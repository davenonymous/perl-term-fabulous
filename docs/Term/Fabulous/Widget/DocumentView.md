# NAME

Term::Fabulous::Widget::DocumentView - A scrollable, searchable view of a structured document

# SYNOPSIS

```perl
use Clay::XS qw(sizing_grow);
use Term::Fabulous::Widget::DocumentView;

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'document',
        document => $document,    # a Term::Fabulous::Document, usually from a parser
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);

# Follow links, and keep a status line up to date.
$view->on( LinkActivate => sub ($event) { open_page( $event->link ); return } );
$view->on( ViewChange   => sub ($event) { show_position( $event->percent ); return } );

# Search the text, and jump to a section.
$view->search('frobnicate');
my $methods = $view->document->find_section('METHODS');
$view->show_block($methods) if defined $methods;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-document-view.svg" alt="A framed document view: a first-level heading with a rule under it, indented paragraphs with bold and code spans, a bulleted list, a quoted paragraph with a bar on its left, a code block on a darker background, a selected link in inverse colors, and search matches highlighted"></p>
</div>

The program is `examples/widgets/document-view.pl`.

# DESCRIPTION

A document view is the main pane of a document reader. It shows a
[Term::Fabulous::Document](../Document.md), which is a list of _blocks_ (headings,
paragraphs, list items, code and so on) as a parser produced them, and
lets the user read it: the view wraps the text to its width, scrolls
with the keyboard, the mouse wheel and the scrollbar, selects and
follows links, and searches the text.

The view does not know the format the document was parsed from.
[Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous) uses it to show POD, and
[Term::Fabulous::Widget::Markdown](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AMarkdown) (part of Term::Fabulous::Extras)
uses it to show Markdown. Worked examples for showing documents,
following links, searching, building a table of contents and writing a
reader for a new format are in [Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md).

A few terms are used throughout this page:

- Every block has a _kind_: `heading`, `paragraph`, `item`, `term`
or `verbatim` for the blocks Term::Fabulous ships (see
[Term::Fabulous::Document::Block](../Document/Block.md)), or a kind of its own for a block
class a reader adds (see ["BLOCK KINDS"](#block-kinds)).
- _Marks_ label ranges of a block's text as bold, code, a link and so
on (see [Term::Fabulous::Document::Mark](../Document/Mark.md)). Each mark has a kind as
well.
- The _look_ ([Term::Fabulous::Document::Look](../Document/Look.md)) turns each kind of mark
into a style in the colors of the current theme.

The view is a [Term::Fabulous::Widget::VirtualList](VirtualList.md): it builds widgets
only for the blocks near the visible area. A document with thousands of
blocks ([perlfunc](https://metacpan.org/pod/perlfunc) has about 2000) therefore opens and scrolls as fast
as a short one, and every frame stays within Clay's limits on elements
and words (see ["LIMITATIONS" in Term::Fabulous](../../../../README.md#limitations)). The view also composes
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable), so it can take the keyboard
focus.

To draw a frame around the view, place it inside a bordered Box rather
than giving the view a border of its own. A scroll container's own
border is drawn over its content, so content scrolled under it shows
its background in the border cells; a Box around the view avoids
that.

## How blocks are shown

The view builds a widget, or a small tree of widgets, for each block,
depending on the block's kind:

- Headings, paragraphs and terms are [Term::Fabulous::Widget::RichText](RichText.md)
widgets, which Clay wraps to the width of the view. Every mark of the
block becomes a span in the style the look gives its kind. A heading is
drawn in the style of its level (`heading1` to `heading6`), and a
first-level heading has a horizontal rule
([Term::Fabulous::Widget::Divider](Divider.md)) under it. A term is drawn in the
`term` style.
- Link marks do not become spans. They become links of the RichText, with
the mark's link as the target, and the RichText paints them on top of
the spans in the link looks of the theme (see
["Looks" in Term::Fabulous::Widget::RichText](RichText.md#looks)). A link therefore looks like
a link even when it is also marked as code. The RichText widgets are
created with `can_focus => 0`, so they are not Tab stops; the view
selects the links of all blocks itself (see ["KEYS"](#keys)).
- A list item is a row of two columns: the marker (a bullet or a number)
in the `marker` style, and the text. The text wraps within its own
column, so every line of it starts after the marker.
- Verbatim blocks are [Term::Fabulous::Widget::CodeBlock](CodeBlock.md) widgets. They
do not wrap; instead, the view scrolls all code blocks sideways
together (see ["scroll\_code"](#scroll_code)).
- A block inside a block quote (["quote" in Term::Fabulous::Document::Block](../Document/Block.md#quote))
gets a vertical bar on its left for each quote it is in, drawn in the
`quote` style and followed by one column of space. The blank row above
a quoted block lies inside its bars, so the bars of the blocks of one
quote join up.
- Every block except a heading is indented by the view's ["indent"](#indent) plus
the block's own indent (["indent" in Term::Fabulous::Document::Block](../Document/Block.md#indent)), in
columns.
- One blank row separates consecutive blocks, with two exceptions. There
is none between the items of one list, nor between an item and the
first item of a list nested in it. There is also none between a term
and the block that follows it, if that block is not a term and is
indented deeper than the term. The view adds these blank rows itself, so do not give its
layout a `child_gap`: the gap would be added between all blocks, on
top of the blank rows.

[Term::Fabulous::Document::Geometry](../Document/Geometry.md) implements these layout rules and
wraps text the same way Clay does. The view asks it for the height of a
block that has not been laid out yet, and for the row of a character
within a block when it scrolls a link or a search match into view.

## Overlays

Two kinds of highlighting, the _overlays_, are drawn on top of the
blocks' own styles without rebuilding any widget:

- The _selected link_ is the link that `Enter` follows. The view keeps
one selection for the whole document and shows it through the RichText
of the link's block, with
[select\_link](RichText.md#select_link). The
selection is shown again when the block's widgets are rebuilt.
- The _search matches_ are the occurrences of the text of the last
["search"](#search), drawn in the `match` style. One of them, the _current
match_, is drawn in the `match_current` style instead;
[next\_match and previous\_match](#next_match-previous_match) move it.

[Term::Fabulous::Document::Overlays](../Document/Overlays.md) holds both overlays and their
rules, and tells the view which blocks to restyle after each change.
When the theme changes, the view restyles every block it has built in
the colors of the new theme.

# CONSTRUCTOR

## new

```perl
my $view = Term::Fabulous::Widget::DocumentView->new( id => 'document', %parameters );
```

Creates a document view. It takes all parameters of
[Term::Fabulous::Widget::VirtualList](VirtualList.md) except `build`, `estimate` and
`count`, which the view derives from its document; passing any of them
dies. As for every scroll container, an `id` is required. Unknown
parameters and invalid values die. The additional parameters are:

- `document`

    The [Term::Fabulous::Document](../Document.md) to show, or `undef` (the default) for
    an empty view. The constructor dies if a mark of the document has a
    kind that the view's look does not know (see
    ["KINDS" in Term::Fabulous::Document::Look](../Document/Look.md#kinds) and ["look\_class"](#look_class)). Link marks
    are exempt from this check, because the RichText widgets draw links
    themselves.

- `highlighter`

    `undef` (the default), or a code reference that all code blocks of the
    view use to highlight their code, called with the code and the language
    of the verbatim block; see
    ["highlighter" in Term::Fabulous::Widget::CodeBlock](CodeBlock.md#highlighter).

- `indent`

    A non-negative integer, default 2: the number of columns by which every
    block except a heading is indented.

# METHODS

The view has all methods of [Term::Fabulous::Widget::VirtualList](VirtualList.md),
plus the following. Unless stated otherwise, the methods that scroll,
select or search return 1 when they changed something and 0 when there
was nothing to change, so a key binding can tell whether the key had an
effect.

## document

```perl
my $document = $view->document;
$view->document($new_document);
```

Gets or sets the document. Setting it checks the new document as
["new"](#new) does and shows it from the top: the code blocks are scrolled
back to their left edge, the selected link and the search are dropped,
and a `ViewChange` event fires after the next frame. Setting `undef`
empties the view. Returns the document.

## highlighter

```perl
$view->highlighter( \&highlight );
```

Gets or sets the highlighter. Setting it passes the new highlighter to
every code block the view has built, and the view hands it to the code
blocks it builds later; each code block highlights its code again the
next time it is painted. Dies for anything but a code reference or
`undef`.

## indent

```perl
$view->indent(4);
```

Gets or sets the indent, in columns. Setting it rebuilds the widgets of
all blocks, so the new indent takes effect in the next frame. Dies for
anything but a non-negative integer.

## geometry

```perl
my $geometry = $view->geometry;
```

Returns the [Term::Fabulous::Document::Geometry](../Document/Geometry.md) of the document shown,
or `undef` when the view has no document. The view creates a new
geometry whenever the document or the indent changes.

## document\_look

```perl
my $look = $view->document_look;
```

Returns the [Term::Fabulous::Document::Look](../Document/Look.md) the view currently draws
with: an object of the class that ["look\_class"](#look_class) names, for the theme
of the view's UI, or for the default theme while the view is not part
of a UI (see ["of" in Term::Fabulous::Document::Look](../Document/Look.md#of)).

## scroll\_lines

```perl
$view->scroll_lines(3);     # down
$view->scroll_lines(-1);    # up
```

Scrolls by the given number of rows: down for a positive number, up for
a negative one. Scrolling stops at the top and at the end of the
document. Returns 1 if the view moved and 0 if it could not. Before the
view is part of a UI, the method does nothing and returns 0; after
that, a number that is not an integer dies.

## scroll\_pages

```perl
$view->scroll_pages(1);     # down
$view->scroll_pages(-1);    # up
```

Scrolls by the given number of pages. A page is the number of rows the
view shows inside its border and padding, less one, so that one row of
the previous page stays in view (see [Term::Fabulous::Scrolling](../Scrolling.md)).
Return value and errors are as for ["scroll\_lines"](#scroll_lines).

## scroll\_to\_top, scroll\_to\_bottom

```perl
$view->scroll_to_top;
$view->scroll_to_bottom;
```

Scrolls so that the first or the last block starts at the top of the
view, or as close to the top as the end of the document allows. The
scroll takes effect in the next frame. Unlike the other scrolling
methods, these return 1 whenever the view has blocks, even if it is
already at the top or the end, and 0 when the view is empty.

## show\_block

```perl
$view->show_block($index);
```

Scrolls so that the block with the given index starts at the top of the
view, or as close to the top as the end of the document allows. The
scroll takes effect in the next frame. Returns the view. Dies if the
document has no block with that index.

## top\_block

```perl
my $index = $view->top_block;
```

Returns the index of the block at the top of the view in the last
frame, or `undef` if the view has not been laid out yet or shows no
blocks.

## scroll\_code

```perl
$view->scroll_code(8);     # show columns further right
$view->scroll_code(-8);    # back towards the start of the lines
```

Scrolls all code blocks sideways by the given number of columns. A
positive number moves the view to the right along the lines, so the
code shifts to the left and later columns come into view; a negative
number moves back. All code
blocks share one horizontal offset, the way `less -S` scrolls long
lines. The offset grows only as far as the widest code block that was
in view in the last frame requires to show the end of its longest line.
Code blocks out of view take the same offset, so that they line up when
they come into view.

Returns 1 if the offset changed, and 0 if it did not, for example
because no code block in view is wider than the view.

## code\_offset

```perl
my $columns = $view->code_offset;
```

Returns the number of columns by which the code blocks are currently
scrolled sideways (see ["scroll\_code"](#scroll_code)). The offset is 0 after a new
document is set.

## select\_next\_link, select\_previous\_link

```perl
$view->select_next_link;
```

Selects the next or the previous link of the document, and scrolls the
line it starts on into view, with as little movement as possible.

If the block of the selected link is in view, the selection moves on
from that link. Otherwise, select\_next\_link starts at the first link in
or below the view, and select\_previous\_link at the last link in or
above it. The selection does not wrap around: at the last link of the
document, select\_next\_link returns 0 and the selection stays where it
is, and the same applies to select\_previous\_link at the first link.
Both return 0 as well when the document has no links.

The scrolling may take a few frames: a block that has not been laid
out yet is first scrolled to the top of the view, and the view then
adjusts until the line is visible.

## selected\_link

```perl
my $link = $view->selected_link;    # the mark's link, or undef
```

Returns the target of the selected link, as the parser stored it in the
link mark (["link" in Term::Fabulous::Document::Mark](../Document/Mark.md#link)), or `undef` if no
link is selected. The selected link is the one last chosen with
[select\_next\_link or select\_previous\_link](#select_next_link-select_previous_link),
or the one the user clicked last.

## follow\_link

```perl
$view->follow_link;
```

Fires a [LinkActivate](../Event/LinkActivate.md) event on
the view for the selected link. In the event, `link` is the target of
the link mark, `index` is the position of the link among the links of
its block, counted from 0, and `start` and `end` are the character
offsets of the link in the block's text. The view does not navigate
anywhere itself; a listener decides what following the link means.
Returns 1 when it fired the event, and 0 when no link is selected.

## search

```perl
my $count = $view->search('hash');
```

Searches the document for the text and marks every occurrence as a
search match. ["find\_text" in Term::Fabulous::Document](../Document.md#find_text) defines the
matching rules; in short, a text without capital letters matches
regardless of case. The current match becomes the first match in or
after the block at the top of the view, or the first match of the
document if there is none from there on. Its line is scrolled into
view as described for [select\_next\_link](#select_next_link-select_previous_link).

Returns the number of matches. A new search replaces the previous one;
the selected link is not affected. An empty text ends the search and
returns 0. Dies if the argument is not a string.

## next\_match, previous\_match

```perl
$view->next_match;
```

Makes the next or the previous match current and scrolls its line into
view. The current match wraps around from the last match to the first,
and from the first to the last. Returns 0 when there are no matches,
and 1 otherwise.

## query, match\_count, current\_match

```perl
printf "%s: %d of %d\n", $view->query, $view->current_match, $view->match_count if $view->match_count;
```

Return the text of the current search (`undef` without a search), the
number of matches (0 without a search), and the number of the current
match, counted from 1 (`undef` when there are no matches).

## clear\_marks

```perl
$view->clear_marks;
```

Ends the search and drops the selected link in one step. Returns 1 when
there was a search or a selected link to drop, even a search without
matches, and 0 otherwise.

## view\_state

```perl
my $state = $view->view_state;
```

Returns a summary of what the view shows, as a hash reference with the
keys of the parameters of [Term::Fabulous::Event::ViewChange](../Event/ViewChange.md):
`top`, `bottom`, `section`, `section_title`, `percent`, `link`,
`query`, `match` and `matches`. The positions describe the last
frame; the link and the search are the current ones. After every frame,
the view compares this summary with the last one it reported and fires
`ViewChange` when they differ.

## build, estimate, count

```perl
my $blocks = $view->count;
```

Without an argument, these accessors of
[Term::Fabulous::Widget::VirtualList](VirtualList.md) return the values the view
installed: its builder, its height estimate, and the number of blocks
of the document (0 without a document). Passing an argument dies,
because the view derives all three from its document.

# KEYS

While the view has the focus, it handles these keys:

```text
Down, j            scroll down one row
Up, k              scroll up one row
PageDown, Space    scroll down one page
PageUp, b          scroll up one page
Home, g            go to the top of the document
End, G             go to the end of the document
Left, Right        scroll the code blocks eight columns sideways
l, L               select the next or the previous link
Enter              follow the selected link
n, N               go to the next or the previous search match
Escape             end the search and drop the selected link
```

The view consumes every key in this table, even when the key has
nothing to do: at the end of the document, `Down` still belongs to the
view and does not reach the enclosing widgets. There are two
exceptions. When no link is selected, the view does not consume
`Enter`; the key bubbles up to the enclosing widgets. The same applies
to `Escape` when there is neither a search nor a selected link. All
other keys bubble up as well (see
["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard)).

# MOUSE

The mouse wheel and the scrollbar scroll the view vertically, as in
every [Term::Fabulous::Widget::ScrollBox](ScrollBox.md). The horizontal wheel (or
tilting the wheel sideways) scrolls the code blocks three columns per
notch, as ["scroll\_code"](#scroll_code) does, while the pointer is over a code block.
(When the view is the root widget of the UI, anywhere over the view
works: mouse events go to the widget whose painted cells are under the
pointer, and the blank rows and the text of other blocks belong to no
painted widget.) Once the code cannot scroll further in that
direction, the event is passed on to the enclosing widgets. A click on
the text of a block or on a code block focuses the view.

A left click on a link selects the link and follows it. The RichText of
the link's block fires
[LinkActivate](../Event/LinkActivate.md), with the target of
the link mark as its `link`. As the event bubbles up through the view,
the view makes the clicked link its selected link and lets the event
continue, so listeners on the view and on the widgets around it receive
it. The link under the mouse pointer is drawn as hovered.

# EVENTS

- `LinkActivate` ([Term::Fabulous::Event::LinkActivate](../Event/LinkActivate.md))

    Fired on the view when the user presses `Enter` while a link is
    selected, or when the program calls ["follow\_link"](#follow_link). When the user
    clicks a link, the RichText of the link's block fires the event, and it
    bubbles up through the view (see ["MOUSE"](#mouse)). In both cases,
    `$event->link` is the target of the link mark, exactly as the
    parser stored it.

- `ViewChange` ([Term::Fabulous::Event::ViewChange](../Event/ViewChange.md))

    Fired on the view after a frame in which the summary that
    ["view\_state"](#view_state) returns differs from the one the view reported last, for
    example because the user scrolled, selected a link or searched. It also
    fires after the first frame of a new document. A link target that is a
    reference counts as changed only when it is a different reference.

- The events of [Term::Fabulous::Widget::VirtualList](VirtualList.md)

    `OnScroll` and `Mouse`, as well as `OnFocus` and `OnBlur` from
    [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable).

# BLOCK KINDS

The view shows the five block kinds Term::Fabulous ships: `heading`,
`paragraph`, `item`, `term` and `verbatim`. A reader for a format
with other kinds of blocks, such as tables, horizontal rules or images,
adds them by subclassing the view, and the look if the new blocks need
styles of their own. A complete example is in
["Add a block kind and a mark kind of your own (view\_of\_KIND, look\_class)" in Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md#add-a-block-kind-and-a-mark-kind-of-your-own-view_of_kind-look_class).
In outline:

- Define the block. A new kind of block is a subclass of
[Term::Fabulous::Document::Block](../Document/Block.md) whose `kind` method returns a word
of its own, for example `rule`. If the body of the block is not
wrapped text, the subclass also overrides
[body\_rows](../Document/Block.md#body_rows) and
[row\_of\_character](../Document/Block.md#row_of_character),
so that the view can estimate the height of the block and scroll to a
character in it.
- Build its widgets. The view builds a block of kind `KIND` by calling
its method `view_of_KIND` as
`$view->view_of_KIND( $block, $padding )`. `$padding` is a hash
reference `{ left => $columns, top => $rows }`: the indent of the
block and the blank row above it, which the returned widget must apply
as its padding (["boxed"](#boxed) creates such a box). The quote bars of a
quoted block are not part of the padding; the view adds them around
the returned widget itself.

    The method returns a hash reference `{ widget => $widget, text => $text }`.
    `widget` is a new widget without a parent, which the list shows for
    the block. `text` is the [Term::Fabulous::Widget::RichText](RichText.md) or
    [Term::Fabulous::Widget::CodeBlock](CodeBlock.md) inside it that shows the block's
    text, or `undef` if there is none. The view sets the spans of this
    widget from the block's marks and the overlays (see ["spans\_of"](#spans_of)).

    The view dies when it builds a block whose kind has no `view_of_KIND`
    method, when the method does not return a hash reference with a
    widget, and when its `text` is neither of the widget types above nor
    `undef`.

- Style new kinds of marks. If the format has marks of kinds the base
look does not know, subclass [Term::Fabulous::Document::Look](../Document/Look.md), add
[recipes](../Document/Look.md#recipes) for the new kinds,
and return the subclass from the view's ["look\_class"](#look_class). The view
refuses documents with marks of unknown kinds (see ["new"](#new)).

A horizontal rule, for example, needs a block class and a builder:

```perl
use Object::Pad;
use Term::Fabulous::Widget::Divider;

class My::Block::Rule :isa(Term::Fabulous::Document::Block) {
        method kind () { return 'rule' }
        method body_rows ($columns) { return 1 }
        method row_of_character ( $offset, $columns ) { return 0 }
}

class My::DocumentView :isa(Term::Fabulous::Widget::DocumentView) {
        method view_of_rule ( $block, $padding ) {
                return { widget => $self->boxed( $padding, Term::Fabulous::Widget::Divider->new ), text => undef };
        }
}
```

The parser then creates the block as `My::Block::Rule->new( text => '' )`.

The methods below are the building blocks for such subclasses.

## look\_class

```perl
method look_class :common () { return 'My::Look' }
```

Class method that returns the name of the
[Term::Fabulous::Document::Look](../Document/Look.md) class the view draws with. The
default is `Term::Fabulous::Document::Look`. A subclass that adds
kinds of marks overrides it to return a subclass of that class. The
view uses the class to check the marks of a document and, through
["document\_look"](#document_look), to style the blocks, and hands it to every code
block it builds (see ["look\_class" in Term::Fabulous::Widget::CodeBlock](CodeBlock.md#look_class)).

## view\_of\_heading, view\_of\_paragraph, view\_of\_item, view\_of\_term, view\_of\_verbatim

```perl
my $view_of_block = $view->view_of_paragraph( $block, $padding );
```

The builders of the built-in kinds, which produce the widgets described
in ["How blocks are shown"](#how-blocks-are-shown). They follow the contract described above,
so a subclass may override any of them to show a built-in kind
differently.

## rich\_text\_of

```perl
my $text = $view->rich_text_of($block);
```

Returns a new [Term::Fabulous::Widget::RichText](RichText.md) with the block's text
and the block's link marks as links, each with the mark's link as its
target. The RichText is created with `can_focus => 0`, so that the
view handles the links (see ["Overlays"](#overlays)). The built-in builders show
their text with it, and a builder of a new kind can use it too.

## boxed

```perl
my $box = $view->boxed( $padding, @children );
```

Returns a new [Term::Fabulous::Widget::Box](Box.md) that stacks the children
from top to bottom, grows to the full width available, and applies the
given padding, a hash reference as passed to a `view_of_KIND` method.

## spans\_of

```perl
my $spans = $view->spans_of( $index, $look );
```

Returns the spans of the text of the block with the given index, in the
given look, as an array reference of `[ $start, $end, $style ]`, where
`$style` is a style hash of the look. The spans come in this order:
the style of a heading's level or of a term over the whole text, the
styles of the block's marks except links, and the overlays (`match` and
`match_current`). Later spans are applied on top of earlier ones. The
view calls this method whenever it restyles a block.

A subclass that styles blocks of its own kinds overrides it. Putting
its own spans first keeps the overlays on top. This example assumes a
`caption` recipe in the view's ["look\_class"](#look_class):

```perl
method spans_of :override ( $index, $look ) {
        my $spans = $self->SUPER::spans_of( $index, $look );
        my $block = $self->document->block($index);
        unshift @$spans, [ 0, length $block->text, $look->style('caption') ] if $block->kind eq 'caption';
        return $spans;
}
```

# KDL PROPERTIES

The view accepts the properties of
["KDL PROPERTIES" in Term::Fabulous::Widget::ScrollBox](ScrollBox.md#kdl-properties), plus `indent`.
A layout file cannot give the document; the program sets it with
["document"](#document) after loading the layout:

```kdl
use Term::Fabulous::Widget::DocumentView as DocumentView

Box "page-pane" {
        sizing width=grow height=grow
        bordered #true
        DocumentView "document" {
                sizing width=grow height=grow
                padding left=1 right=1
                indent 2
        }
}
```

```perl
$ui->find_by_id('document')->document($document);
```

# SEE ALSO

[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md), [Term::Fabulous::Document](../Document.md),
[Term::Fabulous::Widget::CodeBlock](CodeBlock.md), [Term::Fabulous::Document::Look](../Document/Look.md),
[Term::Fabulous::Document::Overlays](../Document/Overlays.md),
[Term::Fabulous::Document::Geometry](../Document/Geometry.md), [Term::Fabulous::Scrolling](../Scrolling.md),
[Term::Fabulous::Widget::VirtualList](VirtualList.md), [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous).
