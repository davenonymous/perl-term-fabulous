# NAME

Term::Fabulous::Cookbook::Documents - Recipes: show, search and extend documents

# DESCRIPTION

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Canvases](Canvases.md). Next page: [Term::Fabulous::Cookbook::Output](Output.md).

This page shows how to display long, structured text: a manual, a
help file, a recipe, anything with headings, paragraphs, lists and
code. The widget for this is [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md).
It shows a [Term::Fabulous::Document](../Document.md), scrolls it with the keyboard
and the mouse, lets the user select and follow links, and searches the
text.

The view does not read any file format itself. A _parser_ turns the
source into a document, and the view shows the document. This
separation is what makes the view reusable: the same widget shows POD
in [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous) and the Markdown pages of the recipes below.

A document has three layers:

- A [Term::Fabulous::Document](../Document.md) is an ordered list of _blocks_.
- A [block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock) is one paragraph-like unit:
a heading, a paragraph, a list item, the term of a definition list, or
a code block. Its _kind_ says which. A block holds plain text, with all
formatting removed.
- A [mark](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3AMark) records where the formatting
was: a range of the block's text and the kind of formatting (`bold`,
`code`, `link`, ...). The view turns kinds into colors and styles of
the current theme with a [look](../Document/Look.md).

The first two recipes build documents, by hand and from Markdown with
[Markdent](https://metacpan.org/pod/Markdent). The next ones use that reader to show what the view can
do: links, search, a table of contents, syntax highlighting and styles
of your own. The last recipe adds a block kind and a mark kind that the
built-in view does not have, for the rules and pictures of Markdown.

The recipes on this page:

- ["Show a document built in Perl (Document, blocks, marks)"](#show-a-document-built-in-perl-document-blocks-marks)
- ["Turn Markdown into a document (Markdent)"](#turn-markdown-into-a-document-markdent)
- ["Follow links: jump to sections, open other pages, go back (LinkActivate)"](#follow-links-jump-to-sections-open-other-pages-go-back-linkactivate)
- ["Search a document and show the reader's position (search, ViewChange)"](#search-a-document-and-show-the-reader-s-position-search-viewchange)
- ["Show a table of contents beside the document (sections, KDL)"](#show-a-table-of-contents-beside-the-document-sections-kdl)
- ["Highlight the syntax of code blocks (highlighter, CodeBlock)"](#highlight-the-syntax-of-code-blocks-highlighter-codeblock)
- ["Change the styles of a document and add mark kinds (Look)"](#change-the-styles-of-a-document-and-add-mark-kinds-look)
- ["Scroll any scroll box like a pager (Term::Fabulous::Scrolling)"](#scroll-any-scroll-box-like-a-pager-term-fabulous-scrolling)
- ["Add a block kind and a mark kind of your own (view\_of\_KIND, look\_class)"](#add-a-block-kind-and-a-mark-kind-of-your-own-view_of_kind-look_class)

# Show a document built in Perl (Document, blocks, marks)

Goal: build a document from the five built-in block kinds and the
built-in mark kinds, and show it in a document view. This is what every
parser does in the end, so it is worth seeing once without a parser in
between.

This program is shipped as `examples/cookbook/document-basics.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_grow);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Item;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Term;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Document::Mark;
use Term::Fabulous::Widget::DocumentView;

# Joins pieces of text into the text of a block and the marks over it.
# A piece is a plain string, [ KIND => 'text' ] for a styled piece, or
# [ link => 'text', TARGET ] for a link.
sub inline (@pieces) {
        my ( $text, @marks ) = ('');
        foreach my $piece (@pieces) {
                if ( !ref $piece ) {
                        $text .= $piece;
                        next;
                }
                my ( $kind, $words, $target ) = @$piece;
                my $start = length $text;
                $text .= $words;
                push @marks, Term::Fabulous::Document::Mark->new( start => $start, end => length $text, kind => $kind, $kind eq 'link' ? ( link => $target ) : () );
        }
        return ( text => $text, marks => \@marks );
}

sub heading ( $level, $text ) {
        return Term::Fabulous::Document::Block::Heading->new( level => $level, text => $text );
}

sub paragraph ( $options, @pieces ) {
        return Term::Fabulous::Document::Block::Paragraph->new( %$options, inline(@pieces) );
}

my $document = Term::Fabulous::Document->new(
        blocks => [
                heading( 1, 'snapback' ),
                paragraph(
                        {},
                        [ bold   => 'snapback' ],    ' copies the files of a directory to a backup disk, but ',
                        [ italic => 'only' ],        ' those that changed since the last run. It reads its settings from ',
                        [ file   => '~/.snapback' ], '. The old option ', [ strike => '--all' ], ' is gone.',
                ),

                heading( 2, 'Usage' ),
                Term::Fabulous::Document::Block::Verbatim->new(
                        language => 'shell',
                        text     => "snapback ~/Documents /mnt/backup\nsnapback --dry-run ~/Photos /mnt/backup",
                ),

                heading( 2, 'Options' ),
                Term::Fabulous::Document::Block::Term->new( text => '--dry-run' ),
                paragraph( { indent => 4 }, 'Lists the files it would copy, and copies nothing.' ),
                Term::Fabulous::Document::Block::Term->new( text => '--keep N' ),
                paragraph( { indent => 4 }, 'Keeps the last ', [ code => 'N' ], ' backups and deletes older ones.' ),

                heading( 2, 'Before the first run' ),
                Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 1, inline('Connect the backup disk.') ),
                Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 2, inline('Check that it has enough free space:') ),
                Term::Fabulous::Document::Block::Item->new( marker => '1.', marker_width => 3, position => 1, indent => 2, inline( 'Run ', [ code => 'df -h /mnt/backup' ], '.' ) ),
                Term::Fabulous::Document::Block::Item->new( marker => '2.', marker_width => 3, position => 2, indent => 2, inline('Compare it with the size of the directory.') ),
                Term::Fabulous::Document::Block::Item->new( marker => '-',  marker_width => 2, position => 3, inline( 'Try a dry run first (see ', [ link => 'Options', 'Options' ], ').' ) ),

                heading( 3, 'From the mailing list' ),
                paragraph( { quote => 1 }, 'Ada wrote:' ),
                paragraph( { quote => 2 }, 'Restore a file now and then. A backup that was never restored is a hope, not a backup.' ),
                paragraph( {}, 'More at ', [ link => 'snapback.example.org', 'https://snapback.example.org' ], '.' ),
        ],
);

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'manual',
        document => $document,
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1, top => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-basics.svg" alt="A manual page in a document view: a first-level heading with a rule under it, a paragraph with bold, italic, file and struck-through text, a code block, two terms with their indented definitions, a bulleted list with a nested numbered list and a link, and a quote inside a quote with two bars on the left"></p>
</div>

- The text of a block is plain text, and a mark points into it by
_character offsets_: `start` is the offset of the first character
the mark covers, `end` the offset after the last one. Counting offsets
by hand is error-prone, so the program builds every text from pieces
with the small `inline` function: it appends the pieces and records
the offsets of each styled piece as it goes. A parser does the same
while it removes the formatting from its source.
- The built-in look has the mark kinds `bold`, `italic`, `strike`,
`code` and `file` for formatting inside a paragraph, and `link` is
the kind of a link. A link mark also carries a _target_, which can be
any defined value: a URL, the name of a section, a hash reference or an
object of your program. The view hands it back unchanged when the user
follows the link (see the next recipes). ["KINDS" in Term::Fabulous::Document::Look](../Document/Look.md#kinds)
lists every kind and its colors.
- A [heading](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AHeading) has a level from
1 to 6. Level 1 gets a rule under it. Headings are never indented.
- A [verbatim block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AVerbatim) keeps its
lines and never wraps. Its optional `language` is passed to a syntax
highlighter, if the view has one (see
["Highlight the syntax of code blocks (highlighter, CodeBlock)"](#highlight-the-syntax-of-code-blocks-highlighter-codeblock)).
- A [term](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3ATerm) starts an entry of a
definition list, and the paragraph after it is its definition. Indent
the definition (here by 4 columns) so that the view keeps it directly
under the term, without a blank row.
- Every [item](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AItem) of a list is a block
of its own. `marker` is the bullet or number, and `marker_width` the
columns from the start of the marker to the start of the text. Give all
items of one list the same `marker_width`, so that their texts line
up. `position` counts the items of a list from 1; an item with
position 1 starts a new list. It gets a blank row above it, unless it
starts a list nested in the item before it.
- A nested list is a list whose items are indented: the `indent` of a
nested item is the `indent` of its parent item plus the parent's
`marker_width`, so that the nested marker sits exactly under the
parent's text. The view shows the first nested item directly under its
parent.
- `quote` is the number of block quotes a block is inside. The view
draws a bar on the left for each level.
- The view needs an `id`, like every scroll container. The view itself
indents every block except headings by 2 columns (the `indent`
parameter), and spaces the blocks with blank rows on its own; do not
give its layout a `child_gap`.
- The program focuses the view, so the keys of
["KEYS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#keys) work at once: the arrow
keys, `PageUp` and `PageDown`, `Home` and `End`, or `j`, `k`,
`Space`, `b`, `g` and `G` as in `less`. The mouse wheel and the
scrollbar scroll as well.

# Turn Markdown into a document (Markdent)

Goal: show a Markdown file. Reading Markdown is a solved problem:
[Markdent](https://metacpan.org/pod/Markdent) from CPAN parses it, with the fenced code blocks and the
struck-through text of the GitHub dialect. What remains is the part
that belongs to this page: turning what Markdent found into blocks and
marks. The other recipes on this page use this reader to load their
documents.

The reader is shipped as `examples/cookbook/lib/My/Markdown.pm`. It
needs Markdent, which you may have to install first
(`cpanm Markdent`).

```perl
package My::Markdown;

# Reads Markdown with Markdent and turns it into a Term::Fabulous::Document,
# for the recipes of Term::Fabulous::Cookbook::Documents. Headings,
# paragraphs, list items, block quotes, code blocks and horizontal rules
# become blocks; bold, italic and struck-through text, code, links and
# images become marks. HTML is left out.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class My::Markdown {
        use HTML::Entities qw(decode_entities);
        use List::Util qw(min);
        use Markdent::Handler::CaptureEvents;
        use Markdent::Parser;
        use My::Markdown::Rule;
        use Term::Fabulous::Document;
        use Term::Fabulous::Document::Block::Heading;
        use Term::Fabulous::Document::Block::Item;
        use Term::Fabulous::Document::Block::Paragraph;
        use Term::Fabulous::Document::Block::Verbatim;
        use Term::Fabulous::Document::Mark;

        use constant {
                ITEM         => 'Term::Fabulous::Document::Block::Item',
                BULLET_WIDTH => 2,    # a bullet and a space
                NUMBER_WIDTH => 4,    # room for "99. "
        };

        # The mark kind of each piece of inline markup Markdent reports
        my %MARK_KIND = ( strong => 'bold', emphasis => 'italic', strikethrough => 'strike', code => 'code', link => 'link' );

        field @blocks;    # the blocks made so far
        field $open;    # the block whose text is being collected: { class, parameters, text, marks, unfinished }
        field @lists;    # the lists the reader is in, outermost first: { numbered, position, indent, marker_width }
        field $quote = 0;    # how many block quotes the reader is in

        method parse :common ( $source, %document_options ) {
                my $events = Markdent::Handler::CaptureEvents->new;
                Markdent::Parser->new( dialects => 'GitHub', handler => $events )->parse( markdown => $source );
                my @blocks = $class->new->_blocks_of( $events->captured_events->events );
                return Term::Fabulous::Document->new( blocks => \@blocks, %document_options );
        }

        method parse_file :common ($path) {
                open my $handle, '<:encoding(UTF-8)', $path or die "My::Markdown: cannot read $path: $!\n";
                my $source = do { local $/; <$handle> };
                close $handle;
                return $class->parse( $source, source => $path );
        }

        # Every event becomes a call of the method named after it; the inline
        # markup that becomes a mark is handled in one place. Events without
        # a method (HTML, the document itself) are skipped.
        method _blocks_of (@events) {
                foreach my $event (@events) {
                        my $kind = $MARK_KIND{ lc $event->name };
                        if ( defined $kind && $event->is_start ) {
                                $self->_start_mark( $kind, $kind eq 'link' ? $event->uri : undef );
                        }
                        elsif ( defined $kind ) {
                                $self->_end_mark;
                        }
                        elsif ( my $method = $self->can( '_' . $event->event_name ) ) {
                                $self->$method($event);
                        }
                }
                $self->_close_block;
                return @blocks;
        }

        # ---------------------------------------------------------------------
        # Blocks
        # ---------------------------------------------------------------------

        method _start_header ($event) {
                return $self->_open_block( 'Term::Fabulous::Document::Block::Heading', level => $event->level );
        }

        method _end_header ($event) {
                return $self->_close_block;
        }

        # The first paragraph of a list item is the text of the item; a later
        # one starts under it.
        method _start_paragraph ($event) {
                return if $open && $open->{class} eq ITEM;
                return $self->_open_block('Term::Fabulous::Document::Block::Paragraph');
        }

        method _end_paragraph ($event) {
                return $self->_close_block;
        }

        method _start_unordered_list ($event) {
                return $self->_enter_list(0);
        }

        method _start_ordered_list ($event) {
                return $self->_enter_list(1);
        }

        method _end_unordered_list ($event) {
                return $self->_leave_list;
        }

        method _end_ordered_list ($event) {
                return $self->_leave_list;
        }

        method _start_list_item ($event) {
                my $list     = $lists[-1];
                my $position = ++$list->{position};
                return $self->_open_block(
                        ITEM,
                        marker       => $list->{numbered} ? "$position." : "\x{2022}",
                        marker_width => $list->{marker_width},
                        position     => $position,
                        indent       => $list->{indent},
                );
        }

        # The text of a tight item has no paragraph around it, so the item is
        # still open here.
        method _end_list_item ($event) {
                return $self->_close_block;
        }

        method _start_blockquote ($event) {
                $self->_close_block;
                $quote++;
                return;
        }

        method _end_blockquote ($event) {
                $self->_close_block;
                $quote--;
                return;
        }

        # A fenced code block, with the word after the opening fence as its
        # language
        method _code_block ($event) {
                my $language = $event->language;
                return $self->_add_block( 'Term::Fabulous::Document::Block::Verbatim', text => $event->code =~ s/\n\z//r, defined $language && length $language ? ( language => $language ) : () );
        }

        # An indented code block
        method _preformatted ($event) {
                return $self->_add_block( 'Term::Fabulous::Document::Block::Verbatim', text => $event->text =~ s/\n\z//r );
        }

        # A block kind of our own: see the last recipe of the cookbook page
        method _horizontal_rule ($event) {
                return $self->_add_block( 'My::Markdown::Rule', text => '' );
        }

        # A nested list starts where the text of its parent item starts.
        method _enter_list ($numbered) {
                $self->_close_block;
                push @lists, { numbered => $numbered, position => 0, indent => $self->_indent, marker_width => $numbered ? NUMBER_WIDTH : BULLET_WIDTH };
                return;
        }

        method _leave_list () {
                $self->_close_block;
                pop @lists;
                return;
        }

        # Where the text after the marker of the current list item starts: the
        # indent of everything inside the item that is not its first paragraph.
        method _indent () {
                return 0 unless @lists;
                return $lists[-1]{indent} + $lists[-1]{marker_width};
        }

        # Starts collecting the text and marks of a block. Its parameters are
        # those of Term::Fabulous::Document::Block and its kinds.
        method _open_block ( $class, %parameters ) {
                $self->_close_block;
                $open = { class => $class, parameters => { indent => $self->_indent, quote => $quote, %parameters }, text => '', marks => [], unfinished => [] };
                return;
        }

        # Blank space at the end of the text is dropped, and a mark that
        # covered it ends with the text. Outer marks come first, so that the
        # view draws the marks nested in them on top.
        method _close_block () {
                return unless $open;
                my $text  = $open->{text} =~ s/\s+\z//r;
                my @marks = map { Term::Fabulous::Document::Mark->new( %$_, end => min( $_->{end}, length $text ) ) } sort { $a->{start} <=> $b->{start} || $b->{end} <=> $a->{end} } $open->{marks}->@*;
                push @blocks, $open->{class}->new( $open->{parameters}->%*, text => $text, marks => \@marks );
                $open = undef;
                return;
        }

        # A block that comes complete: code and rules.
        method _add_block ( $class, %parameters ) {
                $self->_close_block;
                push @blocks, $class->new( indent => $self->_indent, quote => $quote, %parameters );
                return;
        }

        # ---------------------------------------------------------------------
        # Text and marks
        # ---------------------------------------------------------------------

        # The text of a block arrives in pieces, between the events of its
        # marks. A line end is a space: the view wraps the text itself.
        method _text ($event) {
                return $self->_append( $event->text =~ s/\s*\n\s*/ /gr );
        }

        method _line_break ($event) {
                return $self->_append(' ');
        }

        method _html_entity ($event) {
                return $self->_append( decode_entities( '&' . $event->entity . ';' ) );
        }

        # A bare address is a link whose text is the address.
        method _auto_link ($event) {
                $self->_start_mark( link => $event->uri );
                $self->_append( $event->uri );
                return $self->_end_mark;
        }

        # A picture cannot be shown in the text; its alternative text is, in a
        # mark kind of our own (see the last recipe of the cookbook page).
        method _image ($event) {
                $self->_start_mark('image');
                $self->_append( $event->alt_text );
                return $self->_end_mark;
        }

        method _append ($text) {
                my $block = $self->_block_being_collected;
                $text =~ s/\A\s+// unless length $block->{text};
                $block->{text} .= $text;
                return;
        }

        # A mark starts at the end of the text collected so far and ends at the
        # end of the text when its end event comes.
        method _start_mark ( $kind, $link = undef ) {
                my $block = $self->_block_being_collected;
                push $block->{unfinished}->@*, { kind => $kind, start => length $block->{text}, defined $link ? ( link => $link ) : () };
                return;
        }

        method _end_mark () {
                my $block = $self->_block_being_collected;
                my $mark  = pop $block->{unfinished}->@*;
                push $block->{marks}->@*, { %$mark, end => length $block->{text} };
                return;
        }

        method _block_being_collected () {
                return $open // die "My::Markdown: text outside of a block\n";
        }
}

1;
```

The program, shipped as `examples/cookbook/document-from-markup.pl`,
shows the file named on its command line, or the manual
`examples/cookbook/documents/snapback.md`:

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm lives

use Clay::XS qw(sizing_grow);
use My::Markdown;
use Term::Fabulous;
use Term::Fabulous::Widget::DocumentView;

my $file     = shift // "$FindBin::Bin/documents/snapback.md";
my $document = My::Markdown->parse_file($file);

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'manual',
        document => $document,
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-from-markup.svg" alt="The start of the snapback manual: the title snapback with a rule, a paragraph with bold and italic words, a paragraph with five underlined links, the heading Installation, a code block and a numbered list"></p>
</div>

- Markdent reports what it finds as a stream of _events_:
`start_header`, `text`, `start_strong`, `end_strong`, `end_header`
and so on, in the order of the source, and hands them to a handler.
The reader uses the ready-made [Markdent::Handler::CaptureEvents](https://metacpan.org/pod/Markdent%3A%3AHandler%3A%3ACaptureEvents),
which records the events, and walks them afterwards; that keeps it a
plain Object::Pad class. A handler of your own is a [Moose](https://metacpan.org/pod/Moose) class that
does [Markdent::Role::Handler](https://metacpan.org/pod/Markdent%3A%3ARole%3A%3AHandler); it receives the same events one by
one.
- An event that starts a block _opens_ it: the reader remembers the
class of the block and its parameters, and collects the text that
follows. The event that ends the block, or the start of the next block,
closes it; only then is the block built. Which event becomes which
block:
    - `start_header`: a [heading](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AHeading)
    with the level of the event.
    - `start_paragraph`: a
    [paragraph](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AParagraph), unless it is
    the first paragraph of a list item. That one is the text of the item.
    - `start_list_item`: an [item](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AItem).
    Its marker, `marker_width` and `position` come from the list it is
    in.
    - `code_block` (a fenced block) and `preformatted` (an indented one): a
    [verbatim block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AVerbatim), with the
    word after the opening fence as its `language`.
    - `horizontal_rule`: a block of the kind `rule`, a kind that
    Term::Fabulous does not have. The last recipe adds it.
    - `start_blockquote` and `end_blockquote`: no block of their own, but
    every block between them gets a `quote` one higher.
- The text of a block arrives in pieces, between the events of its marks,
and the reader appends them. A line end inside a paragraph becomes a
space; the view wraps the text itself. The start event of a piece of
inline markup records a mark whose `start` is the length of the text
collected so far, and the end event completes it with the length at
that time as its `end`. The offsets of a mark are therefore always
offsets into the text _without_ markup, which is what the view
expects. Which event becomes which mark: `strong` is `bold`,
`emphasis` is `italic`, `strikethrough` is `strike`, `code` is
`code`, and `link` is a `link` whose target is the address between
the parentheses, exactly as written. `auto_link`, an address in angle
brackets, is a link whose text is the address. `image` becomes a mark
of the kind `image` over the alternative text of the picture, the
other kind of the last recipe.
- The reader keeps a stack of the lists it is in. A nested list, which
Markdown indents by four spaces, starts where the text of its parent
item starts: its `indent` is the parent's `indent` plus the parent's
`marker_width`. That is the rule from the first recipe, now computed.
A second paragraph of an item and a code block inside one start there
too.
- `parse_file` passes the file name as the document's `source`, so the
program can show it or open relative links from there.
- Markdown has more than this: HTML is skipped (the text inside an
inline tag stays), and a table comes through as a paragraph with its
bars. The pages of the next recipes have no rule and no picture, so
the built-in view shows them. The last recipe shows what happens
otherwise, and what to do about it.

# Follow links: jump to sections, open other pages, go back (LinkActivate)

Goal: a small help browser. Links to a section of the same page jump
there, links to another file open it, web addresses are reported in the
status bar, and `Backspace` goes back to where the reader was.

This program is shipped as `examples/cookbook/document-links.pl`. It
shows `snapback.md` and `faq.md` from `examples/cookbook/documents`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm lives

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use My::Markdown;
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::DocumentView;
use Term::Fabulous::Widget::StatusBar;

my $directory = "$FindBin::Bin/documents";
my %document_of;    # the pages read so far, by file name
my @history;    # where Backspace goes back to: [ page, block at the top ]
my $page  = 'snapback.md';
my $where = '';    # the section and the percentage, from the last ViewChange

sub document_of ($name) {
        return $document_of{$name} //= My::Markdown->parse_file("$directory/$name");
}

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'manual',
        document => document_of($page),
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);
my $status = Term::Fabulous::Widget::StatusBar->new(
        message => 'l: next link  Enter: follow  Backspace: back',
        timeout => 4,
        parts   => sub { return ( [ $page, 'accent' ], [ $where, 'dim' ] ) },
);
my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $view, $status );

# Shows a page, at the block of a section when the link names one, and
# remembers where the reader was.
sub open_page ( $name, $section ) {
        unless ( -e "$directory/$name" ) {
                $status->message( "There is no page $name.", 'danger' );
                return;
        }
        my $document = document_of($name);
        my $index    = length $section ? $document->find_section($section) : 0;
        unless ( defined $index ) {
                $status->message( "$name has no section \"$section\".", 'danger' );
                return;
        }
        push @history, [ $page, $view->top_block // 0 ];
        $view->document($document) if $name ne $page;
        $view->show_block($index);
        $page = $name;
        return;
}

# A link's target is what the parser put into the mark: here the text
# between the parentheses of [text](target). A Markdown target cannot
# contain a space, so the pages write a section name with %20.
$view->on(
        LinkActivate => sub ($event) {
                my $target = $event->link;
                if ( $target =~ m{\A\w+://} ) {
                        $status->message( "Open $target in your browser.", 'info' );
                        return;
                }
                $target =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
                my ( $name, $section ) = $target =~ /\A([^#]*)(?:#(.*))?\z/;
                open_page( length $name ? $name : $page, $section // '' );
                return;
        }
);

$view->on(
        ViewChange => sub ($event) {
                $where = sprintf '%s  %d%%', $event->section_title // '', $event->percent;
                return;
        }
);

$root->on(
        KeyPress => sub ($event) {
                return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Backspace';
                my $back = pop @history;
                unless ($back) {
                        $status->message( 'This is the first page.', 'warning' );
                        return;
                }
                ( $page, my $top ) = @$back;
                $view->document( document_of($page) );
                $view->show_block($top);
                return;
        }
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-links.svg" alt="The FAQ page of the snapback manual in a document view, opened from a link of the manual, with the link hook selected; the status bar shows the key hints, the page name faq.md, the section and 0%"></p>
</div>

The picture shows the FAQ, opened with the fifth link of the manual,
after `l` selected its first link.

- The user selects links with `l` (the next link) and `L` (the previous
one). Selection starts at the first link in view, and the view scrolls
as little as possible to keep the selected link visible. `Enter`
follows the selected link, and so does a click on any link.
- Following a link fires [LinkActivate](../Event/LinkActivate.md)
on the view. `$event->link` is the target of the link mark, exactly
as the parser created it. What a target means is up to the program.
A Markdown target cannot contain a space, so the pages write `%20`
for one; this program decodes that, then splits the target at `#`
into a file name and a section name.
- [find\_section](../Document.md#find_section) turns a section
name into the index of the block to show. It tries headings and terms,
first for an exact match, then ignoring case, then for a heading or
term that starts with the name. It returns `undef` when nothing
matches, which the program reports instead of jumping.
- [show\_block](../Widget/DocumentView.md#show_block) scrolls
the block to the top of the view in the next frame.
[document](../Widget/DocumentView.md#document) replaces the
document; the view then starts at the top, without a selected link or a
search. The program keeps the parsed documents in `%document_of`, so
going back does not parse a file again.
- The history stores the page and
[top\_block](../Widget/DocumentView.md#top_block), the
index of the block at the top of the view. Going back shows that block
at the top again, which restores the position closely enough for a help
browser.
- After every frame that shows something new, the view fires
[ViewChange](../Event/ViewChange.md). The program keeps the
title of the current section and the percentage in `$where`, and the
[status bar](../Widget/StatusBar.md) shows it on the right.
- `Backspace` is not a key of the view, so the view lets it pass, and it
reaches the handler on the root box. The same is true for every key the
view does not use.

# Search a document and show the reader's position (search, ViewChange)

Goal: search like `less`. `/` moves to a search field, `Enter`
there searches and returns to the document, `n` and `N` step through
the matches, `Escape` ends the search. A line at the bottom shows the
current match, the section and how far down the reader is.

This program is shipped as `examples/cookbook/document-search.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm lives

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow sizing_fixed CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_NONE);
use My::Markdown;
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::DocumentView;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'manual',
        document => My::Markdown->parse_file("$FindBin::Bin/documents/snapback.md"),
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

# The bottom line: a search field on the left, the position on the right.
my $field = Term::Fabulous::Widget::TextField->new(
        placeholder => '/ to search',
        layout      => { sizing => { width => sizing_fixed(24) } },
);
my $position = Term::Fabulous::Widget::Text->new( text => '', wrap_mode => CLAY_TEXT_WRAP_NONE, text_color => [ 150, 160, 180, 255 ] );
my $line     = Term::Fabulous::Widget::Box->new(
        layout => { layout_direction => CLAY_LEFT_TO_RIGHT, sizing => { width => sizing_grow() }, padding => { left => 1, right => 1 }, child_gap => 2 },
);
$line->add_child( $field, $position );

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $view, $line );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

# / moves to the search field, Enter there searches and returns to the
# document, where n and N step through the matches and Escape ends the
# search.
$view->on(
        KeyPress => sub ($event) {
                return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq '/';
                $ui->interaction->set_focused_widget($field);
                return;
        }
);
$field->on(
        KeyPress => sub ($event) {
                return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Escape';
                $ui->interaction->set_focused_widget($view);
                return;
        }
);
$field->on(
        Submit => sub ($event) {
                $view->search( $event->value );
                $ui->interaction->set_focused_widget($view);
                return;
        }
);

# After every frame that shows something new, the view says what it
# shows: the section at the top, how far down the reader is, and the
# search.
$view->on(
        ViewChange => sub ($event) {
                my $search
                        = !defined $event->query ? ''
                        : $event->matches        ? sprintf( 'match %d of %d  ', $event->match, $event->matches )
                        :                          sprintf( 'no "%s"  ', $event->query );
                $position->text( sprintf '%s%s  %d%%', $search, $event->section_title // 'top', $event->percent );
                return;
        }
);

$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-search.svg" alt="The snapback manual with every occurrence of the word disk highlighted, the current one in a stronger color; at the bottom the search field with the word disk and the text match 3 of 6, Installation, 16%"></p>
</div>

The picture shows the manual after searching for `disk` and pressing
`n` twice.

- [search](../Widget/DocumentView.md#search) highlights every
occurrence of the text and makes the first one at or below the top of
the view the _current match_, which has a color of its own. The view
scrolls the current match into view and returns the number of matches.
The search ignores case unless the text contains a capital letter
(`disk` finds `Disk`, `Disk` does not find `disk`), and the text is
plain text, not a regular expression.
- `n` and `N` move to the next and previous match, wrapping around at
the ends. `Escape` ends the search and also drops a selected link. All
three are keys of the view; the program does not handle them. Program
code can do the same with
[next\_match, previous\_match](../Widget/DocumentView.md#next_match-previous_match)
and [clear\_marks](../Widget/DocumentView.md#clear_marks).
- The `ViewChange` event carries everything a status line needs, so the
program never has to ask the view: `section_title` (`undef` above the
first heading), `percent` (0 at the top, 100 at the end, and 100 for a
document that fits), `query`, `matches` and `match`, the number of
the current match from 1. A search can find nothing; then `query` is
set and `matches` is 0.
- The view knows what a frame shows only after the frame was drawn, so
`ViewChange` comes right after the frame it describes. Changes made
in the handler, such as the new text of `$position`, appear in the
next frame, which Term::Fabulous draws at once.
- `/` is not a key of the view, so it reaches the handler that the
program registered on the view. The handler moves the focus to the
[TextField](../Widget/TextField.md), whose `Submit` event
starts the search. An `Escape` in the field returns the focus to the
view without searching.

# Show a table of contents beside the document (sections, KDL)

Goal: a list of all headings beside the document. A click on a heading,
or `Enter` on a selected one, shows its section; a mark in front of a
heading follows the reader through the document. The layout comes from
a KDL description.

This program is shipped as `examples/cookbook/document-contents.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm lives

use My::Markdown;
use Term::Fabulous;
use Term::Fabulous::Layout;

my $root = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text
use Term::Fabulous::Widget::DocumentView as DocumentView

Box "root" {
        sizing width=grow height=grow

        Box "contents-pane" {
                sizing width="fixed(34)" height=grow
                padding left=1 right=1
                border style=Round
                bordered #true
                Text "contents" { text ""; }
        }

        // The view is framed by a box around it rather than by a border of its
        // own, as its documentation advises.
        Box "page-pane" {
                sizing width=grow height=grow
                border style=Round
                bordered #true
                DocumentView "manual" {
                        sizing width=grow height=grow
                        padding left=1 right=1
                        indent 2
                }
        }
}
KDL

my $view     = $root->find_by_id('manual');
my $contents = $root->find_by_id('contents');
my $document = My::Markdown->parse_file("$FindBin::Bin/documents/snapback.md");
$view->document($document);

# One line per heading, indented by its level, each a link to its
# section number; a mark in front of the section the reader is in.
sub show_contents ($current) {
        my @lines = map {
                my $heading = $document->heading_of_section($_);
                my $title   = $heading->text =~ s/\[/\\[/gr;
                my $mark    = defined $current && $current == $_ ? '[bold]>[/] ' : '  ';
                $mark . '  ' x ( $heading->level - 1 ) . "[link=$_]$title\[/link]";
        } 0 .. $document->heading_indexes - 1;
        $contents->markup( join "\n", @lines );
        return;
}
show_contents(undef);

# The view reports the section at its top after every frame that shows
# something new; the contents follow it.
my $shown_section = -1;
$view->on(
        ViewChange => sub ($event) {
                my $section = $event->section // -1;
                return if $section == $shown_section;
                $shown_section = $section;
                show_contents( $event->section );
                return;
        }
);

# A click on a heading, or Enter on the selected one, shows its section.
$contents->on(
        LinkActivate => sub ($event) {
                $view->show_block( $document->block_of_section( $event->link ) );
                return;
        }
);

my $ui = Term::Fabulous->new( root => $root, width => 100, height => 26 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-contents.svg" alt="Two framed panes: on the left the headings of the snapback manual as links, indented by level, with a mark in front of Hooks; on the right the Hooks section with a Perl code block"></p>
</div>

The picture shows the program after three presses of `PageDown`.

- A document numbers its headings from 0 in the order they appear, and
calls the part from one heading to the next a _section_. Section `$n`
starts with `$document->heading_of_section($n)`, which is the block
at index `$document->block_of_section($n)`.
[heading\_indexes](../Document.md#heading_indexes) returns the
block indexes of all headings, so its length is the number of sections.
- `$event->section` of `ViewChange` is the number of the section
the block at the top of the view belongs to, or `undef` above the
first heading. The program rebuilds the contents only when this number
changes, not after every scrolled row.
- The contents are a [Text](../Widget/Text.md) written
in markup: every heading is a link whose target is its section number.
A heading that contains `[` is escaped as `\[`, so that the markup
parser does not read it as a tag. A Text with links is a Tab stop:
`Tab` moves the focus between the contents and the document, and in
the contents `Left`, `Right` and `Enter` select and follow the
links. Setting the markup keeps the focus.
- The KDL layout uses the view like any other widget, after
`use Term::Fabulous::Widget::DocumentView as DocumentView`. KDL can set
`indent` and the properties of every scroll container; the document
itself comes from the program, through
[document](../Widget/DocumentView.md#document). See
["KDL PROPERTIES" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#kdl-properties).
- The view is framed by a box around it, not by a border of its own. In a
scroll container, content scrolled under the container's own border
shows its background in the border cells; a frame outside avoids that.

# Highlight the syntax of code blocks (highlighter, CodeBlock)

Goal: color the code blocks of a document by language, and scroll long
lines sideways.

This program is shipped as `examples/cookbook/code-highlighting.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Clay::XS qw(sizing_grow);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Block::Verbatim;
use Term::Fabulous::Widget::DocumentView;

# The styles of the kinds of token, and for each language a pattern
# that finds its tokens, one named group per kind.
my %STYLE_OF = (
        comment  => 'italic #7f848e',
        string   => '#98c379',
        variable => '#e06c75',
        keyword  => 'bold #c678dd',
        command  => 'bold #61afef',
        option   => '#d19a66',
        key      => '#e06c75',
);
my %TOKENS_OF = (
        perl => qr{
                  (?<comment>  \#.* )
                | (?<string>   "(?:[^"\\]|\\.)*" | '(?:[^'\\]|\\.)*' )
                | (?<variable> [\$\@%][\w:]+ )
                | (?<keyword>  \b(?:my|our|use|sub|return|if|unless|foreach|while|or|and|die)\b )
        }x,
        shell => qr{
                  (?<comment> \#.* )
                | (?<option>  (?<=\s) --?[\w-]+ )
                | (?<command> ^\w[\w-]* )
        }xm,
        ini => qr{
                  (?<comment> ^\s*\#.* )
                | (?<key>     ^\w+ (?=\s*=) )
        }xm,
);

# A highlighter gets the code of a block and its language, and returns
# spans [ start, end, style ] of character offsets into the code.
sub highlight ( $code, $language ) {
        my $tokens = $TOKENS_OF{ $language // '' } or return [];
        my @spans;
        while ( $code =~ /$tokens/g ) {
                my ($kind) = keys %+;
                push @spans, [ $-[0], $+[0], $STYLE_OF{$kind} ];
        }
        return \@spans;
}

# A code block with the language a highlighter gets. A parser takes the
# language from the source, such as the word after ``` in Markdown.
sub code ( $language, $text ) {
        return Term::Fabulous::Document::Block::Verbatim->new( language => $language, text => $text =~ s/\n\z//r );
}

my $document = Term::Fabulous::Document->new(
        blocks => [
                Term::Fabulous::Document::Block::Heading->new( level => 2, text => 'Highlighted code' ),
                Term::Fabulous::Document::Block::Paragraph->new(
                        text => 'Each code block names its language, and the highlighter colors its tokens. Left and Right scroll all code blocks sideways together.'
                ),
                code( perl => <<'PERL' ),
#!/usr/bin/env perl
use v5.32;
use warnings;

my ($backup) = @ARGV or die "usage: $0 BACKUP-DIRECTORY\n";
say "snapback: new backup in $backup";    # a long comment that runs past the right edge of the view, to scroll to
PERL
                code( shell => <<'SHELL' ),
snapback --dry-run ~/Documents /mnt/backup    # lists, copies nothing
SHELL
                code( ini => <<'INI' ),
# ~/.snapback
target = /mnt/backup
keep   = 14
INI
        ],
);

my $view = Term::Fabulous::Widget::DocumentView->new(
        id          => 'code',
        document    => $document,
        highlighter => \&highlight,
        layout      => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-code-highlighting.svg" alt="Three code blocks with highlighted syntax: a Perl script with gray comments, purple keywords, red variables and green strings, whose long last line ends in a clip mark at the right edge; a shell command with a blue command name and an orange option; a configuration file with red keys"></p>
</div>

After two presses of `Right`, the code blocks are scrolled sideways
together:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-code-highlighting-scrolled.svg" alt="The same code blocks, the Perl script scrolled sixteen columns to the left with clip marks on the left of every line; the shorter shell and configuration lines did not move"></p>
</div>

- A _highlighter_ is a code reference that receives the code of a block
and its language, and returns an array reference of spans
`[ $start, $end, $style ]`: character offsets into the code and a style
string such as `'bold #c678dd'` (see
["Style strings" in Term::Fabulous::Text::Style](../Text/Style.md#style-strings)). Give it to the view with
the `highlighter` parameter; the view passes it to every code block.
- Each code block calls the highlighter once and keeps the result until
its code, its language or the highlighter changes, so scrolling does
not run it again. A language it does not know gets `[]`, plain code.
- This highlighter finds the tokens of a language with one regular
expression with a named group per kind of token. Because the
alternatives are tried left to right at each position, a `#` inside a
string stays part of the string. For real syntax highlighting, a
highlighter can use a proper tokenizer, such as [PPI](https://metacpan.org/pod/PPI) for Perl.
- The language comes from the `language` of the
[verbatim block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock%3A%3AVerbatim). The
program sets it directly; a parser takes it from the source, as
`My::Markdown` does with the word after the opening fence of a code
block (```` ```perl ````).
- Code never wraps. A line wider than the view ends at its edge with a
clip mark. `Left` and `Right` scroll all code blocks of the view
sideways together, 8 columns at a time; a horizontal mouse wheel over
a code block does the same. Each block moves only as far as its own longest line needs,
so short blocks stay where they are. [scroll\_code](../Widget/DocumentView.md#scroll_code)
does it from code.
- The style strings here are fixed colors, which suit a dark theme. The
highlighter is called with no access to the theme; to follow the
theme, look the colors up with `$ui->theme->token('success')` (see
["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens)) and set a new highlighter after every
theme switch.
- [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md) is also a widget on its own, for
code outside a document. It takes the same `highlighter`, plus spans
of the program's own.

# Change the styles of a document and add mark kinds (Look)

Goal: change how some kinds of text look, and add mark kinds of your
own: keys shown like keycaps, underlined text, and a highlighter pen.
F2 switches between the dark and the light theme, and the styles follow.

This program is shipped as `examples/cookbook/document-styles.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Look;
use Term::Fabulous::Document::Mark;
use Term::Fabulous::Widget::DocumentView;

# The styles of the view: two built-in kinds changed, three kinds added.
# Colors are palette tokens of the theme, so the styles follow a theme
# switch.
class My::ManualLook :isa(Term::Fabulous::Document::Look) {

        method recipes :common () {
                return (
                        $class->SUPER::recipes,
                        heading1  => { words => 'bold', color => 'success' },
                        code      => { color => 'accent' },
                        key       => { words => 'bold', color => 'text_bright', background => 'surface_raised' },
                        underline => { words => 'underline' },
                        highlight => { color => 'text_inverse', background => 'warning' },
                );
        }
}

# A view that draws with that look. It accepts documents with marks of
# the new kinds, which the built-in view refuses.
class My::ManualView :isa(Term::Fabulous::Widget::DocumentView) {

        method look_class :common () {
                return 'My::ManualLook';
        }
}

# A piece is a plain string or [ KIND => 'text' ].
sub paragraph (@pieces) {
        my ( $text, @marks ) = ('');
        foreach my $piece (@pieces) {
                my ( $kind, $words ) = ref $piece ? @$piece : ( undef, $piece );
                my $start = length $text;
                $text .= $words;
                push @marks, Term::Fabulous::Document::Mark->new( start => $start, end => length $text, kind => $kind ) if defined $kind;
        }
        return Term::Fabulous::Document::Block::Paragraph->new( text => $text, marks => \@marks );
}

my $document = Term::Fabulous::Document->new(
        blocks => [
                Term::Fabulous::Document::Block::Heading->new( level => 1, text => 'Keys of the editor' ),
                paragraph( 'Press ', [ key => 'Ctrl+S' ], ' to save the file and ',  [ key => 'Ctrl+Q' ], ' to quit. Unsaved changes are ', [ underline => 'never' ], ' lost: the editor asks first.' ),
                paragraph( 'The settings live in ', [ code => '~/.editorrc' ], '. ', [ highlight => 'New in version 3:' ], ' ', [ key => 'F2' ], ' switches between the dark and the light theme.' ),
                Term::Fabulous::Document::Block::Heading->new( level => 2, text => 'Moving around' ),
                paragraph( [ key => 'Home' ], ' and ', [ key => 'End' ], ' go to the start and the end of a line, ', [ bold => 'Ctrl' ], ' with them to the start and the end of the file.' ),
        ],
);

my $view = My::ManualView->new(
        id       => 'manual',
        document => $document,
        indent   => 4,
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1, top => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );

$view->on(
        KeyPress => sub ($event) {
                return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'F2';
                $ui->theme( $ui->theme->name eq 'dark' ? 'light' : 'dark' );
                return;
        }
);

$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-styles.svg" alt="A short manual in the light theme: a green first-level heading, key names such as Ctrl+S in bold on a gray background, an underlined word, a file name in blue and a phrase highlighted on a yellow background"></p>
</div>

The picture shows the light theme, after `F2`.

- A [look](../Document/Look.md) maps each kind to a style.
Its class method [recipes](../Document/Look.md#recipes)
returns a list of `kind => recipe` pairs. A recipe has up to three
entries: `words`, style words such as `'bold italic'`; `color`, the
text color; and `background`. Colors are _palette tokens_ of the
theme, such as `accent` or `surface_raised` (see
["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens)), not fixed colors, so a theme switch
restyles the document.
- The subclass returns the recipes of its parent followed by its own.
Later pairs win, so `heading1` and `code` replace the built-in
recipes, and `key`, `underline` and `highlight` are new. Keep the
parent's recipes: the view uses kinds such as `heading2`, `marker`
and `match` itself.
- The view finds its look through the class method
[look\_class](../Widget/DocumentView.md#look_class). A
subclass of the view that returns the name of the new look draws with
it. It also accepts documents with marks of the new kinds; the built-in
view dies when it is given a document with a mark kind its look does
not know, and names the kinds it knows.
- A theme switch with `$ui->theme(...)` makes the view build all
styles again from the recipes; nothing else is needed.
- `indent => 4` indents the paragraphs by four columns instead of
two. Headings are never indented.

# Scroll any scroll box like a pager (Term::Fabulous::Scrolling)

Goal: page through a text in a plain [ScrollBox](../Widget/ScrollBox.md)
with the keys of a pager, show how far down the reader is, and bring a
given line into view. The document view scrolls with the same
functions, and so can any program.

This program is shipped as `examples/cookbook/pager-keys.pl`. It shows
the file named on its command line, or the reader of the second recipe.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_NONE);
use List::Util qw(first);
use Text::Tabs qw(expand);
use Term::Fabulous;
use Term::Fabulous::Scrolling qw(inner_rows reveal_rows scroll_by_pages scroll_by_rows scroll_to_end scroll_to_start scrolled_percent);
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;

use constant {
        PLAIN  => [ 200, 210, 230, 255 ],
        MARKED => [ 229, 192, 123, 255 ],
};

my $file = shift // "$FindBin::Bin/lib/My/Markdown.pm";
open my $handle, '<:encoding(UTF-8)', $file or die "Cannot read $file: $!\n";
chomp( my @lines = <$handle> );
close $handle;
$Text::Tabs::tabstop = 4;
@lines               = expand(@lines);

my $text = Term::Fabulous::Widget::ScrollBox->new(
        id     => 'text',
        layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);
my @rows = map { Term::Fabulous::Widget::Text->new( text => length $_ ? $_ : "\x{A0}", wrap_mode => CLAY_TEXT_WRAP_NONE, text_color => PLAIN ) } @lines;
$text->add_child(@rows);

my $status = Term::Fabulous::Widget::Text->new( text => '', wrap_mode => CLAY_TEXT_WRAP_NONE, text_color => [ 150, 160, 180, 255 ] );
my $root   = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $text, $status );

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );

# n marks the next line that starts a sub or a method and scrolls it
# into view. reveal_rows takes screen rows: line $index of the text is
# on the row where the content starts, plus $index, less how far the
# text is scrolled.
my $marked = -1;

sub mark_next_definition () {
        my $next = first { $lines[$_] =~ /\A\s*(?:sub|method)\b/ } $marked + 1 .. $#lines;
        return 0 unless defined $next;
        $rows[$marked]->text_color(PLAIN) if $marked >= 0;
        $rows[$next]->text_color(MARKED);
        $marked = $next;
        my ($top) = inner_rows( $ui, $text ) or return 1;    # nothing is laid out before the first frame
        my $row = $top + $next + sprintf( '%.0f', $ui->scroll_state($text)->{position}{y} );
        reveal_rows( $ui, $text, $row, $row + 1 );
        return 1;
}

# Each function returns 1 when it moved the text and 0 when it could
# not, at the start or the end.
my %action_of_key = (
        j        => sub { scroll_by_rows( $ui, $text,  1 ) },
        Down     => sub { scroll_by_rows( $ui, $text,  1 ) },
        k        => sub { scroll_by_rows( $ui, $text, -1 ) },
        Up       => sub { scroll_by_rows( $ui, $text, -1 ) },
        Space    => sub { scroll_by_pages( $ui, $text,  1 ) },
        PageDown => sub { scroll_by_pages( $ui, $text,  1 ) },
        b        => sub { scroll_by_pages( $ui, $text, -1 ) },
        PageUp   => sub { scroll_by_pages( $ui, $text, -1 ) },
        g        => sub { scroll_to_start( $ui, $text ) },
        G        => sub { scroll_to_end( $ui, $text ) },
        n        => \&mark_next_definition,
);

my $note = 'j k Space b g G scroll, n marks the next definition';

sub show_status () {
        my $percent = scrolled_percent( $ui, $text ) // 0;
        $status->text( sprintf ' %s  %d%%  %s', $file =~ s{.*/}{}r, $percent, $note );
        return;
}
show_status();

$root->on(
        KeyPress => sub ($event) {
                my $action = $action_of_key{ $event->key_name // '' } or return Clay::UI::Enum::Result->CONTINUE;
                $note = $action->() ? '' : 'Nothing more in that direction.';
                show_status();
                return;
        }
);

# A frame that moved the text reports it; the percentage is that of
# the frame just laid out.
$text->on(
        OnScroll => sub ($event) {
                show_status();
                return;
        }
);

$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-pager-keys.svg" alt="A Perl module in a scroll box, scrolled to 43 percent, with the line method _code_block highlighted in yellow at the bottom; the status line shows the file name and the percentage"></p>
</div>

The picture shows the program after six presses of `n`.

- [Term::Fabulous::Scrolling](../Scrolling.md) moves the content of any scroll container
(a ScrollBox, a VirtualList, a document view) by rows, by pages and to
its ends. Each function takes the UI and the container, so it works on
any container of any program.
- A _page_ is the number of rows the container shows inside its border
and padding, less one: the last row of a page stays in view as the first
row of the next, as in `less`.
- Every function that scrolls returns 1 when it moved the content and 0
when it could not, at the top or the end. The program shows a note when
a key did nothing. Before the first frame nothing is laid out: the
functions that scroll return 0, and `scrolled_percent` returns
`undef`, which the program shows as 0%.
- [scrolled\_percent](../Scrolling.md#scrolled_percent) returns
how far the content is scrolled, from 0 to 100. The program reads it in
the handler of `OnScroll`, which the ScrollBox fires in every frame
that moved its content.
- [reveal\_rows](../Scrolling.md#reveal_rows) scrolls a range of
_screen rows_, as the last frame laid them out, into view with the
smallest movement. A widget that is out of view has no position on the
screen (`$ui->bounding_box` returns `undef` for it), so the
program computes the row itself: here every line is one row, so line
`$index` is on the first row of the content plus `$index`, plus the
current scroll position, which is negative when the content is scrolled
down.

# Add a block kind and a mark kind of your own (view\_of\_KIND, look\_class)

Goal: show `examples/cookbook/documents/news.md`, the release notes of
snapback. They have two things the pages of the other recipes do not:
horizontal rules between the releases, and pictures. The reader of the
second recipe turns a rule into a block of the kind `rule` and the
alternative text of a picture into a mark of the kind `image`. Neither
kind exists in Term::Fabulous, and the program of the second recipe
refuses the page:

```text
$ perl examples/cookbook/document-from-markup.pl examples/cookbook/documents/news.md
Term::Fabulous::Widget::DocumentView: the document has a mark of kind 'image',
which Term::Fabulous::Document::Look does not know; the kinds are bold, clipped,
code, code_block, file, heading1, ..., quote, strike, term
```

The view checks the marks of a document when it gets it. It would die
again when it builds the first rule, because it has no `view_of_rule`.
Three small classes in `examples/cookbook/lib/My/Markdown/` teach it
both kinds.

## The block kind

```perl
package My::Markdown::Rule;

# A horizontal rule, a block kind that the built-in kinds of
# Term::Fabulous::Document::Block lack. My::Markdown::View shows it as a
# divider across the view.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

class My::Markdown::Rule :isa(Term::Fabulous::Document::Block) :strict(params) {

        ADJUST {
                die "My::Markdown::Rule: a rule has no text" if length $self->text;
        }

        # The view builds a block of kind "rule" with its view_of_rule.
        method kind () {
                return 'rule';
        }

        # The rows the block takes, which the view asks for before it lays the
        # block out, to size its scrollbar: one for the divider.
        method body_rows :override ($columns) {
                return 1;
        }
}

1;
```

- A block kind is a subclass of [Term::Fabulous::Document::Block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock) with a
`kind` method that returns a name. The name decides which method of the
view builds the widget of the block: `view_of_rule`. Every block takes
the parameters `text`, `marks`, `indent` and `quote`; the reader
creates a rule with an empty text, and the `ADJUST` block refuses
anything else.
- The view does not build widgets for blocks that are far out of view,
so it must estimate how tall they are, for the scrollbar. It asks
[body\_rows](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock#body_rows): the rows the
block takes in the given number of columns, without the blank row
above it. The default wraps the text the way the layout wraps it; a
rule is one row. An estimate that is off does no harm beyond a
scrollbar thumb that jumps a little when the block comes into view.
- The view also asks a block for the row of a character, to scroll a
link or a search match into view
([row\_of\_character](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock#row_of_character)).
A kind with text and rows above it, say a caption under a frame,
overrides that too. A rule has no text, so the default is right.

## The mark kind

```perl
package My::Markdown::Look;

# The styles of My::Markdown::View: those of every document view, plus
# the mark kind the Markdown reader adds, the alternative text of an
# image.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Look;

class My::Markdown::Look :isa(Term::Fabulous::Document::Look) :strict(params) {

        # Colors are palette tokens of the theme, so that the style follows a
        # switch to another theme.
        method recipes :common () {
                return (
                        $class->SUPER::recipes,
                        image => { words => 'italic', color => 'text_muted' },
                );
        }
}

1;
```

- `image` is a recipe as in
["Change the styles of a document and add mark kinds (Look)"](#change-the-styles-of-a-document-and-add-mark-kinds-look): the
alternative text of a picture is shown in italics and the muted text
color, so that it reads as what it is, a stand-in. The parent's recipes
stay in front of it; the view needs them.

## The view

```perl
package My::Markdown::View;

# A document view that knows the block and mark kinds of the Markdown
# reader: it draws with My::Markdown::Look and shows a rule
# (My::Markdown::Rule) as a divider.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::DocumentView;

class My::Markdown::View :isa(Term::Fabulous::Widget::DocumentView) :strict(params) {
        use My::Markdown::Look;
        use Term::Fabulous::Widget::Divider;

        method look_class :common () {
                return 'My::Markdown::Look';
        }

        # boxed puts the divider into the box the view lays out, with the
        # padding the view gives: the indent and the blank row above. A rule
        # has no text for the view to style or search.
        method view_of_rule ( $block, $padding ) {
                return { widget => $self->boxed( $padding, Term::Fabulous::Widget::Divider->new ), text => undef };
        }
}

1;
```

- `look_class` makes the view draw with `My::Markdown::Look`, and
accept documents with marks of its kinds.
- `view_of_rule` builds the widget of a rule. The view calls
`view_of_KIND` for every block of kind `KIND` with the block and a
hash of padding, `{ left => $columns, top => $rows }`: the indent
of the block and the blank row above it. The method returns a hash
reference with two entries:
    - `widget`

        The widget the view shows for the block. It must apply the padding;
        [boxed](../Widget/DocumentView.md#boxed) creates a box of
        the view's width with the padding and the given children, one under the
        other. Here the only child is a [divider](../Widget/Divider.md),
        the one row that `body_rows` counts.

    - `text`

        The [Text](../Widget/Text.md) that shows the text
        of the block, or `undef` for a block without text. The view styles
        this widget with the marks, the selected link and the search matches.
        A kind with text creates it with
        [rich\_text\_of](../Widget/DocumentView.md#rich_text_of),
        which sets it up so that the view can select its links.
- A kind with a style of its own, say a caption in the `caption` style
of the look, also overrides
[spans\_of](../Widget/DocumentView.md#spans_of), which
returns the styles of a block's text; its own span goes first, so that
marks and search matches are drawn over it.

## The program

The program is shipped as `examples/cookbook/document-kinds.pl`:

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Markdown.pm and My/Markdown/*.pm live

use Clay::XS qw(sizing_grow);
use My::Markdown;
use My::Markdown::View;
use Term::Fabulous;

my $file     = shift // "$FindBin::Bin/documents/news.md";
my $document = My::Markdown->parse_file($file);

my $view = My::Markdown::View->new(
        id       => 'news',
        document => $document,
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-document-kinds.svg" alt="The release notes of snapback: the heading snapback news with a rule, a paragraph that ends in the alternative text of a picture in italics, a divider, the heading 2.1, a bulleted list with a nested list, a paragraph, a divider, the heading 2.0 and the start of a numbered list"></p>
</div>

- The program differs from the one of the second recipe in one line: the
view is a `My::Markdown::View`. The reader is the same. It knows
nothing about the screen, and the view knows nothing about Markdown.
Keep that separation in readers of your own: the same view shows
documents of any format, and a reader can be checked without a
terminal, by looking at the blocks it makes.
- The rule keeps the `indent` and `quote` of its place in the document
like every block: inside a block quote, the view draws the bars around
the divider too.

Some directions from here:

- **Pictures.** A picture that stands alone in a paragraph can be a block
of its own kind, whose builder shows it with
[Term::Fabulous::Widget::Image](../Widget/Image.md) and whose `body_rows` returns the
rows the picture takes.
- **Tables.** A block kind whose builder makes a
[Term::Fabulous::Widget::Table](../Widget/Table.md), and whose `body_rows` counts the
rows of the table and of its borders. The reader would collect the
cells of a table instead of its text.
- **Footnotes.** Leave a marker such as `[1]` in the text, as a link mark
whose target names the note, and append the notes as paragraphs at the
end of the document.

The reference of the extension points is in
["BLOCK KINDS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#block-kinds),
[Term::Fabulous::Document::Block](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3ABlock), [Term::Fabulous::Document::Look](../Document/Look.md)
and [Term::Fabulous::Document::Geometry](https://metacpan.org/pod/Term%3A%3AFabulous%3A%3ADocument%3A%3AGeometry). [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous) is a
complete reader built the same way, for POD.

# SEE ALSO

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Canvases](Canvases.md). Next page: [Term::Fabulous::Cookbook::Output](Output.md).
