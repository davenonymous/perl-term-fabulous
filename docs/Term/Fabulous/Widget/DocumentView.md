# NAME

Term::Fabulous::Widget::DocumentView - A scrolling, searchable view of a document of blocks

# SYNOPSIS

```perl
use Clay::XS qw(sizing_grow);
use Term::Fabulous::Widget::DocumentView;

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'document',
        document => $document,    # a Term::Fabulous::Document, from a parser
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);

$view->on( LinkActivate => sub ($event) { open_page( $event->link ); return } );
$view->on( ViewChange   => sub ($event) { show_position( $event->percent ); return } );

$view->search('frobnicate');
$view->show_block( $view->document->find_section('METHODS') );
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/widget-document-view.svg" alt="A framed document view: a first-level heading with a rule under it, indented paragraphs with bold and code spans, a bulleted list, a quoted paragraph with a bar on its left, a code block on a darker background, a selected link in inverse colors, and search matches highlighted"></p>
</div>

The program is `examples/widgets/document-view.pl`.

# DESCRIPTION

The view shows a [Term::Fabulous::Document](../Document.md): every block in the look
of its kind, wrapped to the view's width, scrolled with the keys, the
mouse wheel and the scrollbar, its links selected and followed, its
text searched. It is the main pane of a reader, whatever the format the
document was parsed from: [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous) shows POD with it,
[Term::Fabulous::Widget::Markdown](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3AWidget%3A%3AMarkdown) shows Markdown.

It is a [Term::Fabulous::Widget::VirtualList](VirtualList.md): it builds widgets only
for the blocks near the viewport, so a document of thousands of
paragraphs ([perlfunc](https://metacpan.org/pod/perlfunc) has about 2000 blocks) opens and scrolls as
fast as a short one, and stays below Clay's limits on elements and
words per frame (see ["LIMITATIONS" in Term::Fabulous](../../../../README.md#limitations)). It also composes
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable), so it takes the keyboard
focus. Frame it with a Box around it rather than giving it a border of
its own: content scrolled under the border of a scroll container shows
its background in the border's cells.

## How blocks are shown

- Paragraphs, terms and headings are [Term::Fabulous::Widget::RichText](RichText.md)
widgets: Clay wraps them, and their marks become spans in the styles of
the view's look ([Term::Fabulous::Document::Look](../Document/Look.md)). Link marks become
links of the RichText instead, with the mark's link as their target; the
RichText paints them over the spans in the link looks of the theme
(see ["Looks" in Term::Fabulous::Widget::RichText](RichText.md#looks)), so that a link looks
like a link even when it is code. The RichTexts are created with
`can_focus => 0`: they are no Tab stops, the view selects the
links of all blocks itself (see ["KEYS"](#keys)). Headings are drawn in the
style of their level, a first-level heading with a rule under it
([Term::Fabulous::Widget::Divider](Divider.md)); terms in the `term` style.
- An item is a row of two columns: its marker, and its text, which wraps
within its own column, so that every line starts after the marker.
- Verbatim blocks are [Term::Fabulous::Widget::CodeBlock](CodeBlock.md) widgets, which
do not wrap; the view scrolls them all sideways together.
- A block inside a block quote (["quote" in Term::Fabulous::Document::Block](../Document/Block.md#quote))
has a bar on its left for every quote it is in, in the `quote` style,
and a space after the bar.
- Every block but a heading is indented by the view's ["indent"](#indent) plus
its own (["indent" in Term::Fabulous::Document::Block](../Document/Block.md#indent)). A blank row
separates the blocks, except the items of one list (and the first item
of a list nested in an item from that item) and a term from the
paragraphs that define it. The view spaces the blocks itself: give its
layout no `child_gap`, or the gap is added to every block.

[Term::Fabulous::Document::Geometry](../Document/Geometry.md) holds these rules, and wraps the
text of a block as Clay does: the view asks it for the height of a
block it has not laid out yet, and for the line a search match is on.

## Overlays

Two things are drawn over the blocks' own styles, without building
anything again: the _selected link_, the one `Enter` follows, and the
matches of a _search_, the current one in a style of its own. The view
keeps one selection across all blocks and shows it through the RichText
of the link's block, with
[select\_link](RichText.md#select_link), also when
the block's view is built again. A theme switch restyles every block in
the new theme's colors. [Term::Fabulous::Document::Overlays](../Document/Overlays.md) holds both
and their rules, and tells the view which blocks to restyle.

# CONSTRUCTOR

## new

```perl
my $view = Term::Fabulous::Widget::DocumentView->new( id => 'document', %parameters );
```

All parameters of [Term::Fabulous::Widget::VirtualList](VirtualList.md) except
`build`, `estimate` and `count`, which the view takes from its
document (giving them dies); an `id` is required. Plus:

- `document`

    The [Term::Fabulous::Document](../Document.md) to show, or `undef` (the default) for
    an empty view. A document with a mark whose kind the view's look does
    not know dies (see ["KINDS" in Term::Fabulous::Document::Look](../Document/Look.md#kinds)).

- `highlighter`

    `undef` (the default), or a code reference that every code block of
    the view uses to highlight its code; see
    ["highlighter" in Term::Fabulous::Widget::CodeBlock](CodeBlock.md#highlighter).

- `indent`

    A non-negative integer, default 2: the columns every block but a
    heading is indented by.

# METHODS

The methods of [Term::Fabulous::Widget::VirtualList](VirtualList.md), plus the
following. The methods that scroll or select return 1 when they
changed something and 0 when there was nothing to change, so a key
binding can tell.

## document

```perl
$view->document($document);
```

Accessor. Setting shows the new document from its top, with its code
not scrolled sideways, drops the selected link and the search, and
makes the next frame fire a `ViewChange`.

## highlighter

```perl
$view->highlighter( \&highlight );
```

Accessor; setting hands the new highlighter to every code block.

## indent

```perl
$view->indent(4);
```

Accessor; setting builds the views of the blocks again.

## geometry

```perl
my $geometry = $view->geometry;
```

The [Term::Fabulous::Document::Geometry](../Document/Geometry.md) of the document shown, or
`undef` without a document.

## document\_look

```perl
my $look = $view->document_look;
```

The [Term::Fabulous::Document::Look](../Document/Look.md) the view draws with at the
moment: that of the theme of its UI (see
["of" in Term::Fabulous::Document::Look](../Document/Look.md#of)).

## scroll\_lines

```perl
$view->scroll_lines(3);     # down
$view->scroll_lines(-1);    # up
```

Scrolls by rows, stopping at the top and the end. The number of rows,
and of pages below, must be an integer; anything else dies.

## scroll\_pages

```perl
$view->scroll_pages(1);
```

Scrolls by pages; a page is the rows the view shows inside its border
and padding, less one row, which stays in view (see
[Term::Fabulous::Scrolling](../Scrolling.md)).

## scroll\_to\_top, scroll\_to\_bottom

```perl
$view->scroll_to_bottom;
```

Scrolls to the first or the last block.

## show\_block

```perl
$view->show_block($index);
```

Scrolls so that the block starts at the top of the view (or as near as
the end of the document allows), in the next frame. Returns the view.

## top\_block

```perl
my $index = $view->top_block;
```

The index of the first block in view in the last frame, or `undef`.

## scroll\_code

```perl
$view->scroll_code(8);     # to the right
$view->scroll_code(-8);
```

Scrolls every code block sideways by columns: one offset for all of
them, as `less -S` scrolls long lines. It reaches as far as the widest
code block in view allows; the blocks out of view take the same offset,
so that they match when they come into view. Returns 1 when the offset
changed, 0 when there is nothing in view to scroll.

## code\_offset

```perl
my $columns = $view->code_offset;
```

How far the code blocks are scrolled sideways by ["scroll\_code"](#scroll_code).

## select\_next\_link, select\_previous\_link

```perl
$view->select_next_link;
```

Selects the next or previous link: from the selected one while its
block is in view, otherwise from the first link in view (the last,
going back). The selection stops at the first and the last link of the
document. The line of the selected link is scrolled into view, with as
little movement as possible.

## selected\_link

```perl
my $link = $view->selected_link;    # the mark's link, or undef
```

The destination of the selected link: the one
[select\_next\_link or select\_previous\_link](#select_next_link-select_previous_link)
selected last, or the one clicked last.

## follow\_link

```perl
$view->follow_link;
```

Fires [LinkActivate](../Event/LinkActivate.md) on the view
for the selected link: its `link` is the mark's link, its `index`
the place of the link among the links of its block, and its `start`
and `end` the link's offsets in the block's text. Returns 0 when no
link is selected.

## search

```perl
my $count = $view->search('hash');
```

Marks every occurrence of the text in the document (see
["find\_text" in Term::Fabulous::Document](../Document.md#find_text) for the rules), makes the first
one at or after the top of the view current and scrolls its line into
view. Returns the number of matches. An empty text ends the search.

## next\_match, previous\_match

```perl
$view->next_match;
```

Makes the next or previous match current, around from the last to the
first, and scrolls it into view.

## query, match\_count, current\_match

```perl
printf "%s: %d of %d\n", $view->query, $view->current_match, $view->match_count;
```

The text searched for (or `undef`), the number of matches, and the
number of the current match, from 1 (or `undef`).

## clear\_marks

```perl
$view->clear_marks;
```

Ends the search and drops the selected link.

## view\_state

```perl
my $state = $view->view_state;
```

What the last frame showed, as the hash of the parameters of a
[Term::Fabulous::Event::ViewChange](../Event/ViewChange.md).

## build, estimate, count

The list's own accessors return what the view gave them; setting them
dies.

# KEYS

While the view has the focus:

```text
Down, j / Up, k          a row down or up
PageDown, Space          a page down
PageUp, b                a page up
Home, g / End, G         the top or the end of the document
Left / Right             the code blocks eight columns sideways
l / L                    select the next or previous link
Enter                    follow the selected link
n / N                    the next or previous search match
Escape                   end the search and drop the selected link
```

`Enter` without a selected link and `Escape` without anything to
drop go on to the widgets around, and so does every other key (see
["KEYBOARD" in Term::Fabulous::Manual::Events](../Manual/Events.md#keyboard)).

# MOUSE

The wheel and the scrollbar scroll the view, as in every
[Term::Fabulous::Widget::ScrollBox](ScrollBox.md). Each notch of the horizontal
wheel (or a sideways tilt of the wheel) anywhere over the view scrolls
the code blocks three columns sideways while they can move, as
["scroll\_code"](#scroll_code) does; at the end, the notch goes on to the widgets
around. A click focuses the view.

A left click on a link selects it and follows it: the RichText of its
block fires [LinkActivate](../Event/LinkActivate.md), with
the mark's link as its `link`, and the event bubbles up through the
view, which makes the clicked link its selected link and lets the event
go on. The link under the mouse pointer looks hovered.

# EVENTS

- `LinkActivate` ([Term::Fabulous::Event::LinkActivate](../Event/LinkActivate.md))

    When the user presses `Enter` on the selected link, or the program
    calls ["follow\_link"](#follow_link): fired on the view. When the user clicks a link:
    fired on the RichText of its block, and on its way up through the view
    (see ["MOUSE"](#mouse)). Either way, `$event->link` is the link of the
    mark, whatever the parser put there.

- `ViewChange` ([Term::Fabulous::Event::ViewChange](../Event/ViewChange.md))

    After a frame whose view differs from the one reported last.

- The events of [Term::Fabulous::Widget::VirtualList](VirtualList.md)

    `OnScroll` and `Mouse`, and `OnFocus` and `OnBlur` from
    [Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable).

# BLOCK KINDS

A viewer for a format whose documents have blocks the five built-in
kinds do not cover (a table, a horizontal rule, a picture) subclasses
the view and the look:

- A new kind of block is a subclass of [Term::Fabulous::Document::Block](../Document/Block.md)
whose `kind` is a word of its own, say `rule`, and which answers
[body\_rows](../Document/Block.md#body_rows) for a body that
is not wrapped text.
- The view builds a block of kind `KIND` with its method
`view_of_KIND`, called as `$view->view_of_KIND( $block, $padding )`,
where `$padding` is `{ left => $columns, top => $rows }`, the
indent of the block and the blank row above it. It returns a hash
reference `{ widget => $widget, text => $text }`: the widget the
list shows, which takes the padding (["boxed"](#boxed) makes such a box), and
the [Term::Fabulous::Widget::RichText](RichText.md) or
[Term::Fabulous::Widget::CodeBlock](CodeBlock.md) that shows the block's text, whose
spans the view sets from the marks and the overlays, or `undef` for a
block without such a text. A view method of a name the base class does
not have dies when the block is built.
- New kinds of marks need styles: a subclass of
[Term::Fabulous::Document::Look](../Document/Look.md) with more [recipes](../Document/Look.md#recipes),
named by the view's ["look\_class"](#look_class).

The methods a subclass builds with:

## look\_class

```text
method look_class :common () { return 'My::Look' }
```

Class method. The [Term::Fabulous::Document::Look](../Document/Look.md) class the view
draws with; default `Term::Fabulous::Document::Look`. A subclass
returns a subclass of it.

## view\_of\_heading, view\_of\_paragraph, view\_of\_item, view\_of\_term, view\_of\_verbatim

The builders of the built-in kinds, as described above; a subclass may
replace one.

## rich\_text\_of

```text
my $text = $view->rich_text_of($block);
```

A RichText of the block's text with the block's links, and
`can_focus => 0`: what the built-in builders show the text with.

## boxed

```text
my $box = $view->boxed( $padding, @children );
```

A Box with the children in a column, the given padding and the width
of the view.

## spans\_of

```text
my $spans = $view->spans_of( $index, $look );
```

The spans of a block's text in a look, as `[ $start, $end, $style ]`:
the style of a heading or a term over the whole text, the marks, then
the overlays. A subclass that styles blocks of its own kinds extends
it.

# KDL PROPERTIES

The properties of ["KDL PROPERTIES" in Term::Fabulous::Widget::ScrollBox](ScrollBox.md#kdl-properties),
plus `indent`. The document comes from the program:

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

# SEE ALSO

[Term::Fabulous::Document](../Document.md), [Term::Fabulous::Widget::CodeBlock](CodeBlock.md),
[Term::Fabulous::Document::Look](../Document/Look.md), [Term::Fabulous::Document::Overlays](../Document/Overlays.md),
[Term::Fabulous::Document::Geometry](../Document/Geometry.md), [Term::Fabulous::Scrolling](../Scrolling.md),
[Term::Fabulous::Widget::VirtualList](VirtualList.md), [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous).
