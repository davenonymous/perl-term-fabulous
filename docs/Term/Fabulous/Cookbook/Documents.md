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
in [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous), Markdown, and the OpenDocument files of the guide
at the end of this page.

A document has three layers:

- A [Term::Fabulous::Document](../Document.md) is an ordered list of _blocks_.
- A [block](../Document/Block.md) is one paragraph-like unit:
a heading, a paragraph, a list item, the term of a definition list, or
a code block. Its _kind_ says which. A block holds plain text, with all
formatting removed.
- A [mark](../Document/Mark.md) records where the formatting
was: a range of the block's text and the kind of formatting (`bold`,
`code`, `link`, ...). The view turns kinds into colors and styles of
the current theme with a [look](../Document/Look.md).

The first two recipes build documents, by hand and with a small
parser. The next ones use that parser to show what the view can do:
links, search, a table of contents, syntax highlighting and styles of
your own. The last recipe is a step-by-step guide to a reader for a new
format, OpenDocument text (`.odt`), including a block kind and a mark
kind that the built-in view does not have.

The recipes on this page:

- ["Show a document built in Perl (Document, blocks, marks)"](#show-a-document-built-in-perl-document-blocks-marks)
- ["Turn a simple markup into a document (a small parser)"](#turn-a-simple-markup-into-a-document-a-small-parser)
- ["Follow links: jump to sections, open other pages, go back (LinkActivate)"](#follow-links-jump-to-sections-open-other-pages-go-back-linkactivate)
- ["Search a document and show the reader's position (search, ViewChange)"](#search-a-document-and-show-the-reader-s-position-search-viewchange)
- ["Show a table of contents beside the document (sections, KDL)"](#show-a-table-of-contents-beside-the-document-sections-kdl)
- ["Highlight the syntax of code blocks (highlighter, CodeBlock)"](#highlight-the-syntax-of-code-blocks-highlighter-codeblock)
- ["Change the styles of a document and add mark kinds (Look)"](#change-the-styles-of-a-document-and-add-mark-kinds-look)
- ["Scroll any scroll box like a pager (Term::Fabulous::Scrolling)"](#scroll-any-scroll-box-like-a-pager-term-fabulous-scrolling)
- ["Write a reader for a new document format (OpenDocument text)"](#write-a-reader-for-a-new-document-format-opendocument-text)

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
- A [heading](../Document/Block/Heading.md) has a level from
1 to 6. Level 1 gets a rule under it. Headings are never indented.
- A [verbatim block](../Document/Block/Verbatim.md) keeps its
lines and never wraps. Its optional `language` is passed to a syntax
highlighter, if the view has one (see
["Highlight the syntax of code blocks (highlighter, CodeBlock)"](#highlight-the-syntax-of-code-blocks-highlighter-codeblock)).
- A [term](../Document/Block/Term.md) starts an entry of a
definition list, and the paragraph after it is its definition. Indent
the definition (here by 4 columns) so that the view keeps it directly
under the term, without a blank row.
- Every [item](../Document/Block/Item.md) of a list is a block
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

# Turn a simple markup into a document (a small parser)

Goal: show a text file written in a simple markup. The parser here
reads a small part of Markdown: headings, paragraphs, bulleted and
numbered lists, block quotes, fenced code blocks, and `**bold**`,
`*italic*`, `~~strike~~`, `` `code` `` and `[links](target)`. The other
recipes on this page use it to load their documents.

The parser is shipped as `examples/cookbook/lib/My/MiniMark.pm`:

```perl
package My::MiniMark;

# A parser for a small part of Markdown, used by the recipes of
# Term::Fabulous::Cookbook::Documents. It reads headings, paragraphs,
# bulleted and numbered lists (nested by two spaces), block quotes,
# fenced code blocks, and **bold**, *italic*, ~~strike~~, `code` and
# [links](target) that do not nest, and turns them into a
# Term::Fabulous::Document.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class My::MiniMark {
        use Term::Fabulous::Document;
        use Term::Fabulous::Document::Block::Heading;
        use Term::Fabulous::Document::Block::Item;
        use Term::Fabulous::Document::Block::Paragraph;
        use Term::Fabulous::Document::Block::Verbatim;
        use Term::Fabulous::Document::Mark;

        use constant {
                BULLET_WIDTH => 2,    # "- " becomes a bullet and a space
                NUMBER_WIDTH => 4,    # room for "99. "
        };

        my $INLINE = qr{
                  \*\*(?<bold>.+?)\*\*
                | \*(?<italic>.+?)\*
                | ~~(?<strike>.+?)~~
                | `(?<code>[^`]+)`
                | \[(?<link>[^\]]+)\]\((?<target>[^)]+)\)
        }x;

        field @lines;    # the lines not read yet
        field @blocks;    # the blocks made so far
        field @lists;    # the lists the reader is in, outermost first: { indent, marker_width, position }
        field $open;    # the paragraph or item whose lines are being collected: { class, text, parameters }

        method parse :common ( $source, %document_options ) {
                my @blocks = $class->new->_blocks_of($source);
                return Term::Fabulous::Document->new( blocks => \@blocks, %document_options );
        }

        method parse_file :common ($path) {
                open my $handle, '<:encoding(UTF-8)', $path or die "My::MiniMark: cannot read $path: $!\n";
                my $source = do { local $/; <$handle> };
                close $handle;
                return $class->parse( $source, source => $path );
        }

        method _blocks_of ($source) {
                @lines = split /\n/, $source;
                while ( defined( my $line = shift @lines ) ) {
                        $self->_read($line);
                }
                $self->_close;
                return @blocks;
        }

        method _read ($line) {
                return $self->_code_block($1) if $line                        =~ /\A```(\w*)\s*\z/;
                return $self->_close if $line                                 =~ /\A\s*\z/;
                return $self->_heading( length $1, $2 ) if $line              =~ /\A(#{1,6})\s+(.*)\z/;
                return $self->_quote( length( $1 =~ s/\s//gr ), $2 ) if $line =~ /\A((?:>\s?)+)(.*)\z/;
                return $self->_item( length $1, $2, $3 ) if $line             =~ /\A( *)([-*]|[0-9]+\.)\s+(.*)\z/;
                return $self->_continue($line) if $open;
                return $self->_paragraph($line);
        }

        # The open paragraph or item becomes a block, its text split into
        # plain text and marks.
        method _close () {
                return unless $open;
                push @blocks, $open->{class}->new( %{ $open->{parameters} }, _inline( $open->{text} ) );
                $open = undef;
                return;
        }

        method _code_block ($language) {
                $self->_close;
                my @code;
                push @code, shift @lines while @lines && $lines[0] !~ /\A```\s*\z/;
                shift @lines;
                push @blocks, Term::Fabulous::Document::Block::Verbatim->new( text => join( "\n", @code ), length $language ? ( language => $language ) : () );
                @lists = ();
                return;
        }

        method _heading ( $level, $text ) {
                $self->_close;
                push @blocks, Term::Fabulous::Document::Block::Heading->new( level => $level, text => $text );
                @lists = ();
                return;
        }

        # "> text" is a paragraph in one quote, "> > text" in two; a line
        # with only ">" ends the paragraph.
        method _quote ( $depth, $text ) {
                my $continues = $open && ( $open->{parameters}{quote} // 0 ) == $depth;
                $self->_close unless $continues;
                return unless length $text;
                return $self->_continue($text) if $continues;
                $open  = { class => 'Term::Fabulous::Document::Block::Paragraph', text => $text, parameters => { quote => $depth } };
                @lists = ();
                return;
        }

        # Every two spaces before the marker nest the item one list deeper;
        # its text starts where the text of the item above it starts.
        method _item ( $spaces, $marker, $text ) {
                $self->_close;
                my $level = int( $spaces / 2 );
                $level = @lists if $level > @lists;
                splice @lists, $level + 1;
                my $numbered = $marker =~ /\A[0-9]/;
                my $parent   = $level ? $lists[ $level - 1 ] : undef;
                my $list     = $lists[$level] //= {
                        indent       => $parent   ? $parent->{indent} + $parent->{marker_width} : 0,
                        marker_width => $numbered ? NUMBER_WIDTH                                : BULLET_WIDTH,
                        position     => 0,
                };
                my $position = ++$list->{position};
                $open = {
                        class      => 'Term::Fabulous::Document::Block::Item',
                        text       => $text,
                        parameters => { marker => $numbered ? "$position." : "\x{2022}", marker_width => $list->{marker_width}, position => $position, indent => $list->{indent} },
                };
                return;
        }

        method _continue ($line) {
                $open->{text} .= ' ' . ( $line =~ s/\A\s+//r );
                return;
        }

        # An indented paragraph after a list item belongs to the item; one at
        # the left margin ends the lists.
        method _paragraph ($line) {
                my $in_item = @lists && $line =~ /\A\s{2}/;
                @lists = () unless $in_item;
                my $indent = $in_item ? $lists[-1]{indent} + $lists[-1]{marker_width} : 0;
                $open = { class => 'Term::Fabulous::Document::Block::Paragraph', text => $line =~ s/\A\s+//r, parameters => { indent => $indent } };
                return;
        }

        # The text without the markup, and a mark for every piece of markup.
        sub _inline ($source) {
                my ( $text, @marks ) = ('');
                my $after_last = 0;
                while ( $source =~ /$INLINE/g ) {
                        my %found = %+;
                        $text .= substr( $source, $after_last, $-[0] - $after_last );
                        $after_last = $+[0];
                        my ($kind) = grep { defined $found{$_} } qw(bold italic strike code link);
                        my $start = length $text;
                        $text .= $found{$kind};
                        push @marks, Term::Fabulous::Document::Mark->new( start => $start, end => length $text, kind => $kind, $kind eq 'link' ? ( link => $found{target} ) : () );
                }
                $text .= substr( $source, $after_last );
                return ( text => $text, marks => \@marks );
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
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use Clay::XS qw(sizing_grow);
use My::MiniMark;
use Term::Fabulous;
use Term::Fabulous::Widget::DocumentView;

my $file     = shift // "$FindBin::Bin/documents/snapback.md";
my $document = My::MiniMark->parse_file($file);

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

- The parser reads the source line by line. A line either completes a
block on its own (a heading, the fences of a code block) or adds to the
_open_ block, the paragraph or item whose lines are still being
collected. A blank line or the start of another block closes the open
block: only then are its lines joined, its markup removed and the block
built. Paragraph text is a single line; the view wraps it to the width
it has.
- `_inline` removes the markup and creates the marks. It finds each
piece of markup with one regular expression that has a named group per
kind, copies the text before the match to the result, then appends the
marked text and records where it starts and ends in the result. The
offsets of a mark are always offsets into the text _without_ markup.
- The parser keeps a stack of the lists it is in. Every two spaces in
front of a list marker go one list deeper, and a nested list starts
where the text of its parent item starts. That is the rule from the
first recipe, now computed: `indent` of the parent plus its
`marker_width`.
- A link keeps its target exactly as written between the parentheses,
for example `#Settings` or `faq.md#Hooks`. The parser does not
interpret it; the program does, when the user follows the link (see the
next recipe).
- `parse_file` passes the file name as the document's `source`, so the
program can show it or open relative links from there.
- This is a teaching parser, not a Markdown implementation. Marks do not
nest, a code block cannot be part of a list item, and HTML, tables and
images are not supported. The point is the shape: lines in, blocks and
marks out.

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
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use My::MiniMark;
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
        return $document_of{$name} //= My::MiniMark->parse_file("$directory/$name");
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
# between the parentheses of [text](target).
$view->on(
        LinkActivate => sub ($event) {
                my $target = $event->link;
                if ( $target =~ m{\A\w+://} ) {
                        $status->message( "Open $target in your browser.", 'info' );
                        return;
                }
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
as the parser created it. What a target means is up to the program:
this one splits it at `#` into a file name and a section name.
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
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow sizing_fixed CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_NONE);
use My::MiniMark;
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::DocumentView;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;

my $view = Term::Fabulous::Widget::DocumentView->new(
        id       => 'manual',
        document => My::MiniMark->parse_file("$FindBin::Bin/documents/snapback.md"),
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
use lib "$FindBin::Bin/lib";    # where My/MiniMark.pm lives

use My::MiniMark;
use Term::Fabulous;
use Term::Fabulous::Layout;

my $root = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::RichText as RichText
use Term::Fabulous::Widget::DocumentView as DocumentView

Box "root" {
        sizing width=grow height=grow

        Box "contents-pane" {
                sizing width="fixed(34)" height=grow
                padding left=1 right=1
                border style=Round
                bordered #true
                RichText "contents" { text ""; }
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
my $document = My::MiniMark->parse_file("$FindBin::Bin/documents/snapback.md");
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
- The contents are a [RichText](../Widget/RichText.md) written
in markup: every heading is a link whose target is its section number.
A heading that contains `[` is escaped as `\[`, so that the markup
parser does not read it as a tag. A RichText with links is a Tab stop:
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
[verbatim block](../Document/Block/Verbatim.md). The
program sets it directly; a parser takes it from the source, as
`My::MiniMark` does with the word after the opening fence of a code
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
the file named on its command line, or the parser of the second recipe.

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

my $file = shift // "$FindBin::Bin/lib/My/MiniMark.pm";
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

# Write a reader for a new document format (OpenDocument text)

This recipe is a guide in eight steps. It builds a reader for
OpenDocument text files (`.odt`), the format of LibreOffice Writer and
other word processors, and shows the complete path from an unknown
format to a working viewer:

- reading the source and mapping it to blocks and marks;
- adding a block kind of your own, the document title, with its own
widget and height;
- adding a mark kind of your own, underlined text, with its own style;
- testing the parser without a terminal.

The reader handles a deliberately small part of the format: the title,
headings, paragraphs, bulleted and numbered lists (also nested), bold,
italic, underlined and struck-through text, and links. That is enough to
read a typical letter, recipe or report. Tables, pictures, footnotes and
page layout are left out; the last step explains how to add them.

This is the finished reader:

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-odt-reader.svg" alt="The pancake recipe from an OpenDocument file: the centered title Pancakes over a double rule, a paragraph with bold and italic words and a selected link, the headings Ingredients and Method with rules, a bulleted list with struck-through text, a numbered list with an underlined phrase and a nested list, a second-level heading Tips, a paragraph with a link and an italic paragraph; the status bar shows Top 100%"></p>
</div>

## What you need, and the files of the reader

The parser reads the XML inside the file with [XML::Twig](https://metacpan.org/pod/XML%3A%3ATwig), which you
may have to install first (`cpanm XML::Twig`). The archive is unpacked
with [IO::Uncompress::Unzip](https://metacpan.org/pod/IO%3A%3AUncompress%3A%3AUnzip), which comes with Perl.

The reader consists of five small modules in
`examples/cookbook/lib/My/Odt/` and two programs in
`examples/cookbook/`; the example document is
`examples/cookbook/documents/pancakes.odt`.

```text
My/Odt/Styles.pm    reads the styles: which text is bold, italic, ...; which paragraph is a title; list markers
My/Odt/Title.pm     the block kind "title"
My/Odt/Parser.pm    turns the file into a Term::Fabulous::Document
My/Odt/Look.pm      the styles of the new kinds "title" and "underline"
My/Odt/View.pm      a document view that shows titles and uses that look
odt-outline.pl      prints what the parser made, for checking it
odt-reader.pl       the reader
```

The parser knows nothing about the screen, and the view knows nothing
about OpenDocument. Keep that separation in your own readers: it lets
you test the parser without a terminal (step 6), and it lets the same
view show documents of any format.

## Step 1: Look inside an OpenDocument file

An OpenDocument file is a ZIP archive. List it with `unzip -l`:

```text
$ unzip -l examples/cookbook/documents/pancakes.odt
  Length      Date    Time    Name
---------  ---------- -----   ----
       39  2026-06-01 09:41   mimetype
      478  2026-06-01 09:41   META-INF/manifest.xml
     2069  2026-06-01 09:41   styles.xml
     4434  2026-06-01 09:41   content.xml
---------                     -------
     7020                     4 files
```

Files written by a word processor contain more (pictures, settings,
metadata), but two are all a reader of the text needs:

- `content.xml`

    The text itself, in the element `<office:text>`, and the
    _automatic styles_: styles the word processor creates for direct
    formatting, for example when the user selects a word and presses
    Ctrl+B. They have generated names such as `T1`.

- `styles.xml`

    The _named styles_ the user chooses from a list in the word
    processor, such as "Title", "Heading 1" or "Strong Emphasis". In the
    XML, spaces in names are written as `_20_`: `Strong_20_Emphasis`.

This is the start of the text in `content.xml` of the example, with
one of its automatic styles (shortened):

```xml
<office:automatic-styles>
 <style:style style:name="T1" style:family="text">
  <style:text-properties fo:font-weight="bold"/>
 </style:style>
 ...
 <text:list-style style:name="L2">
  <text:list-level-style-number text:level="1" style:num-suffix="." style:num-format="1"/>
  <text:list-level-style-bullet text:level="2" text:bullet-char="◦"/>
 </text:list-style>
</office:automatic-styles>
<office:body>
 <office:text>
  <text:p text:style-name="Title">Pancakes</text:p>
  <text:p text:style-name="Text_20_body">A quick breakfast for four. It takes
   <text:span text:style-name="T1">20 minutes</text:span>, ... Read the
   <text:a xlink:type="simple" xlink:href="#Method|outline">method</text:a> once before you start.</text:p>
  <text:h text:style-name="Heading_20_1" text:outline-level="1">Ingredients</text:h>
  <text:list text:style-name="L1">
   <text:list-item><text:p text:style-name="List_20_Contents">250 g flour</text:p></text:list-item>
   ...
```

Three things stand out:

- The formatting is not in the text, but in _styles_. A span of bold
text is a `<text:span>` whose style, `T1`, says
`fo:font-weight="bold"`. The parser must look the style up.
- Styles inherit from a parent style (`style:parent-style-name`). The
paragraph style `P1` of the example is "Text body" plus italic; the
"Title" style inherits from "Heading". A title is any paragraph whose
style is "Title" or inherits from it.
- Lists say only that they are lists. Whether their items get bullets or
numbers, and which, is in the _list style_ (`L2` above), per nesting
level.

## Step 2: Decide what becomes a block and what becomes a mark

Before writing code, map the elements of the format to the document
model. For this reader:

| OpenDocument                             | Term::Fabulous::Document                                    |
| ---------------------------------------- | ----------------------------------------------------------- |
| &lt;text:p> with a "Title" style         | a block of the new kind "title" (My::Odt::Title)            |
| &lt;text:h text:outline-level="N">       | Heading, level N (1 to 6)                                   |
| &lt;text:p>                              | Paragraph; empty paragraphs are left out                    |
| &lt;text:list> / &lt;text:list-item>     | an Item per list item; nested lists are indented            |
| 2nd and later &lt;text:p> of a list item | Paragraph, indented to the item's text                      |
| &lt;text:span> whose style is bold, ...  | marks of kind bold, italic, strike, and the new "underline" |
| a paragraph style that is bold, ...      | the same marks, over the whole paragraph                    |
| &lt;text:a xlink:href="...">             | a link mark whose target is the href                        |
| &lt;text:s text:c="N">, &lt;text:tab>    | N spaces, one space                                         |
| &lt;text:section>                        | its content, read like the body                             |
| everything else (tables, frames, notes)  | left out                                                    |

Two kinds in this table do not exist in Term::Fabulous: the _title_
block and the _underline_ mark. A reader for a new format usually needs
a few such kinds. Steps 4 and 7 add them.

When a format has more structure than the model (a footnote, a table),
you have three choices: leave it out, flatten it into the existing kinds
(a table row as a paragraph), or add a block kind. Start with the first
two and add kinds where readers will notice the difference.

## Step 3: Read the styles

`My::Odt::Styles` collects all styles of both files and answers the
three questions the parser has: which marks does the text of a style
get, is a paragraph style a title, and what is the marker of a list item.

```perl
package My::Odt::Styles;

# The styles of an OpenDocument text, as far as the reader of
# Term::Fabulous::Cookbook::Documents needs them: which marks the text of
# a style gets (bold, italic, underline, strike), which paragraph styles
# make a title, and the marker of a list item at each level of a list
# style. Styles come from styles.xml (the named styles a user picks) and
# content.xml (the automatic styles a word processor makes for direct
# formatting), and inherit from their parent style.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class My::Odt::Styles :strict(params) {
        use constant BULLET => "\x{2022}";

        # Style name => the name of the style it inherits from; style name =>
        # its own text properties as { attribute => value }; list style name =>
        # { level => { numbered, bullet, prefix, suffix } }.
        field %parent_of;
        field %properties_of;
        field %levels_of_list;

        # The root elements of styles.xml and content.xml, read with the
        # namespace prefixes office, style, text and fo.
        ADJUST :params ( :$roots ) {
                foreach my $root (@$roots) {
                        $self->_read_style($_)      foreach $root->descendants('style:style');
                        $self->_read_list_style($_) foreach $root->descendants('text:list-style');
                }
        }

        method _read_style ($style) {
                my $name   = $style->att('style:name');
                my $parent = $style->att('style:parent-style-name');
                $parent_of{$name} = $parent if defined $parent;
                my $properties = $style->first_child('style:text-properties') or return;
                $properties_of{$name} = { map { $_ => $properties->att($_) } grep { defined $properties->att($_) } qw(fo:font-weight fo:font-style style:text-underline-style style:text-line-through-style) };
                return;
        }

        method _read_list_style ($list_style) {
                my $name = $list_style->att('style:name');
                foreach my $level ( $list_style->children ) {
                        my $number = $level->att('text:level') // next;
                        $levels_of_list{$name}{$number}
                                = $level->tag eq 'text:list-level-style-number'
                                ? { numbered => 1, prefix => $level->att('style:num-prefix') // '', suffix => $level->att('style:num-suffix') // '' }
                                : { numbered => 0, bullet => $level->att('text:bullet-char') // BULLET };
                }
                return;
        }

        # The style and the styles it inherits from, the style itself first.
        method _lineage ($name) {
                my @lineage;
                while ( defined $name ) {
                        die "My::Odt::Styles: the style $name inherits from itself\n" if grep { $_ eq $name } @lineage;
                        push @lineage, $name;
                        $name = $parent_of{$name};
                }
                return @lineage;
        }

        # The mark kinds of the text of a style. Each property comes from the
        # nearest style that sets it, so a style can switch off what its
        # parent switches on.
        method kinds_of ($name) {
                my %property;
                foreach my $style ( $self->_lineage($name) ) {
                        my $own = $properties_of{$style} // next;
                        $property{$_} //= $own->{$_} foreach keys %$own;
                }
                my $weight = $property{'fo:font-weight'} // 'normal';
                my @kinds;
                push @kinds, 'bold' if $weight eq 'bold' || ( $weight =~ /\A[0-9]+\z/ && $weight >= 600 );
                push @kinds, 'italic' if ( $property{'fo:font-style'} // 'normal' ) ne 'normal';
                push @kinds, 'underline' if ( $property{'style:text-underline-style'} // 'none' ) ne 'none';
                push @kinds, 'strike' if ( $property{'style:text-line-through-style'} // 'none' ) ne 'none';
                return @kinds;
        }

        # A paragraph is a title when its style is "Title" or inherits from it.
        method is_title ($name) {
                return ( grep { $_ eq 'Title' } $self->_lineage($name) ) ? 1 : 0;
        }

        # The marker of the item at $position (from 1) in a list of the style
        # at $level (from 1): a bullet, or the number with the prefix and the
        # suffix of the style ("1."). Lists without a style get bullets.
        method marker_of ( $list_style, $level, $position ) {
                my $format = defined $list_style ? $levels_of_list{$list_style}{$level} : undef;
                return BULLET unless $format;
                return $format->{numbered} ? "$format->{prefix}$position$format->{suffix}" : $format->{bullet};
        }
}

1;
```

- The constructor receives the root elements of both XML files and reads
every `<style:style>` and `<text:list-style>` in them. For each
style it keeps the name of its parent and its own text properties: the
four attributes that the reader turns into marks.
- `kinds_of` walks from a style up through its parents. Each property
comes from the nearest style that sets it, so a style can switch off
what its parent switches on (`fo:font-weight="normal"` under a bold
parent). It returns the mark kinds of the style: `bold` for a font
weight of `bold` or at least 600, `italic` for any slanted font
style, and `underline` and `strike` for any line style other than
`none`. `_lineage` dies on a style that inherits from itself, rather
than looping forever.
- `is_title` answers whether "Title" is among the styles a paragraph
style inherits from.
- `marker_of` builds the marker of an item from the list style: the
bullet character of the level, or the number with the level's prefix
and suffix (`1.`). Number formats other than 1, 2, 3 (letters, Roman
numerals) are shown as plain numbers; supporting them would mean
converting the position in `marker_of`.

## Step 4: Add a block kind for the title

The title is not a heading: it is not part of the table of contents,
and it looks different. The built-in kinds have nothing like it, so the
reader adds a kind.

```perl
package My::Odt::Title;

# The title of a document, a block kind that the built-in kinds of
# Term::Fabulous::Document::Block lack. My::Odt::View shows it centered,
# with a double rule under it.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

class My::Odt::Title :isa(Term::Fabulous::Document::Block) :strict(params) {

        # The view builds a block of kind "title" with its view_of_title.
        method kind () {
                return 'title';
        }

        # The rows of the wrapped text, and one for the rule. The view asks
        # for them before it lays the title out, to size its scrollbar.
        method body_rows :override ($columns) {
                return $self->SUPER::body_rows($columns) + 1;
        }
}

1;
```

- A block kind is a subclass of [Term::Fabulous::Document::Block](../Document/Block.md) with a
`kind` method that returns a name. The name decides which method of the
view builds the widget of the block: `view_of_title` (step 7). Every
block takes the parameters `text`, `marks`, `indent` and `quote`.
- The view does not build widgets for blocks that are far out of view,
so it must estimate how tall they are, for the scrollbar. It asks
[body\_rows](../Document/Block.md#body_rows): the rows the
block takes in the given number of columns, without the blank row
above it. The default wraps the text the way the layout wraps it. The
title adds one row for the rule under its text. An estimate that is
off does no harm beyond a scrollbar thumb that jumps a little when the
block comes into view.
- The view also asks the block for the row of a character, to scroll a
link or a search match into view
([row\_of\_character](../Document/Block.md#row_of_character)).
The rule is under the text, so the default is right for the title. A
block with rows above its text, such as a border, adds them there too.

## Step 5: Write the parser

`My::Odt::Parser` reads the file and builds the document. Every method
reads one kind of element and appends blocks to `@blocks`, in the
order of the text.

```perl
package My::Odt::Parser;

# Reads an OpenDocument text (.odt) into a Term::Fabulous::Document: the
# title, headings, paragraphs and lists of the text, with bold, italic,
# underlined and struck text and links as marks. Everything else (tables,
# pictures, notes, fields) is left out. Needs XML::Twig.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class My::Odt::Parser :strict(params) {
        use IO::Uncompress::Unzip qw(unzip $UnzipError);
        use List::Util qw(max min);
        use My::Odt::Styles;
        use My::Odt::Title;
        use Term::Fabulous::Document;
        use Term::Fabulous::Document::Block::Heading;
        use Term::Fabulous::Document::Block::Item;
        use Term::Fabulous::Document::Block::Paragraph;
        use Term::Fabulous::Document::Mark;
        use Term::Fabulous::Unicode qw(string_columns);
        use XML::Twig;

        # The prefixes the parser uses, whatever prefixes the file declares.
        use constant NAMESPACES => {
                'urn:oasis:names:tc:opendocument:xmlns:office:1.0'            => 'office',
                'urn:oasis:names:tc:opendocument:xmlns:style:1.0'             => 'style',
                'urn:oasis:names:tc:opendocument:xmlns:text:1.0'              => 'text',
                'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0' => 'fo',
                'http://www.w3.org/1999/xlink'                                => 'xlink',
        };

        # The elements of the text that become blocks, and the method that
        # reads each. A section holds more of them.
        my %READER_OF = (
                'text:h'       => '_heading',
                'text:p'       => '_paragraph',
                'text:list'    => '_list',
                'text:section' => '_body',
        );

        field $styles :param;
        field @blocks;

        method parse_file :common ($path) {
                my %twig_of = map { $_ => _twig_of_member( $path, "$_.xml" ) } qw(styles content);
                my $parser  = $class->new( styles => My::Odt::Styles->new( roots => [ map { $_->root } @twig_of{qw(styles content)} ] ) );
                my $text    = $twig_of{content}->root->first_descendant('office:text') or die "My::Odt::Parser: $path is not a text document\n";
                $parser->_body($text);
                return Term::Fabulous::Document->new( blocks => [ $parser->blocks ], source => $path );
        }

        method blocks () {
                return @blocks;
        }

        # A file of the archive, parsed. With keep_spaces, XML::Twig keeps
        # whitespace with a line break between two elements, which it would
        # drop as indentation; between two spans, it separates two words.
        sub _twig_of_member ( $path, $member ) {
                unzip( $path => \my $xml, Name => $member ) or die "My::Odt::Parser: cannot read $member from $path: $UnzipError\n";
                my $twig = XML::Twig->new( keep_spaces => 1, map_xmlns => NAMESPACES );
                $twig->parse($xml);
                return $twig;
        }

        method _body ( $element, %place ) {
                foreach my $child ( $element->children ) {
                        my $reader = $READER_OF{ $child->tag } // next;
                        $self->$reader( $child, %place );
                }
                return;
        }

        method _heading ( $element, %place ) {
                my $level = $element->att('text:outline-level') // 1;
                $level = max( 1, min( 6, $level ) );
                push @blocks, Term::Fabulous::Document::Block::Heading->new( level => $level, $self->_inline($element) );
                return;
        }

        # A paragraph in a list item is indented to the item's text. Empty
        # paragraphs, which word processors use as spacing, are left out. The
        # style of a title says how titles look, which is the view's business,
        # so it gives no marks.
        method _paragraph ( $element, %place ) {
                my $style    = $element->att('text:style-name');
                my $is_title = $styles->is_title($style);
                my %inline   = $self->_inline( $element, $is_title ? undef : $style );
                return unless $inline{text} =~ /\S/;
                push @blocks, $is_title ? My::Odt::Title->new(%inline) : Term::Fabulous::Document::Block::Paragraph->new( %inline, indent => $place{indent} // 0 );
                return;
        }

        # All items of a list share the width of the widest marker and a
        # space, so that their texts line up. A nested list keeps the style
        # of the list around it unless it names its own.
        method _list ( $list, %place ) {
                my $style   = $list->att('text:style-name') // $place{list_style};
                my $level   = ( $place{level} // 0 ) + 1;
                my @items   = $list->children('text:list-item') or return;
                my @markers = map         { $styles->marker_of( $style, $level, $_ ) } 1 .. @items;
                my $width   = 1 + max map { string_columns($_) } @markers;
                foreach my $position ( 1 .. @items ) {
                        my %item = ( marker => $markers[ $position - 1 ], marker_width => $width, position => $position, indent => $place{indent} // 0 );
                        $self->_list_item( $items[ $position - 1 ], \%item, list_style => $style, level => $level );
                }
                return;
        }

        # The first paragraph of an item is its text. The paragraphs and lists
        # after it belong to the item and start where its text starts.
        method _list_item ( $element, $item, %list ) {
                my @parts  = grep { $_->tag eq 'text:p' || $_->tag eq 'text:list' } $element->children;
                my $first  = @parts && $parts[0]->tag eq 'text:p' ? shift @parts                                             : undef;
                my %inline = defined $first                       ? $self->_inline( $first, $first->att('text:style-name') ) : ( text => '' );
                push @blocks, Term::Fabulous::Document::Block::Item->new( %$item, %inline );
                my $indent = $item->{indent} + $item->{marker_width};
                foreach my $part (@parts) {
                        my $reader = $READER_OF{ $part->tag };
                        $self->$reader( $part, %list, indent => $indent );
                }
                return;
        }

        # The text of a paragraph or heading without its markup, and its
        # marks: one over the whole text for each kind of the paragraph's own
        # style (if given), then the spans and links inside, in the order of
        # the text.
        method _inline ( $element, $style = undef ) {
                my %found = ( text => '', marks => [] );
                $self->_collect( $element, \%found );
                my $length = length $found{text};
                my @whole  = map { Term::Fabulous::Document::Mark->new( start => 0, end => $length, kind => $_ ) } $length && defined $style ? $styles->kinds_of($style) : ();
                return ( text => $found{text}, marks => [ @whole, @{ $found{marks} } ] );
        }

        # Text, spaces, spans and links, in order. Whitespace in the XML is
        # one space; <text:s text:c="3"/> is three. A span gets a mark for
        # each kind of its style, a link (<text:a>) a link mark to its
        # address. Other elements, such as notes and bookmarks, are skipped.
        method _collect ( $element, $found ) {
                foreach my $node ( $element->children ) {
                        if ( $node->is_pcdata ) {
                                $found->{text} .= $node->pcdata =~ s/[ \t\r\n]+/ /gr;
                                next;
                        }
                        my $tag = $node->tag;
                        if ( $tag eq 'text:s' ) {
                                $found->{text} .= ' ' x ( $node->att('text:c') // 1 );
                                next;
                        }
                        if ( $tag eq 'text:tab' || $tag eq 'text:line-break' ) {
                                $found->{text} .= ' ';
                                next;
                        }
                        next unless $tag eq 'text:span' || $tag eq 'text:a';

                        my $start = length $found->{text};
                        $self->_collect( $node, $found );
                        my $end = length $found->{text};
                        next if $end == $start;
                        my @marks
                                = $tag eq 'text:a'
                                ? { kind => 'link', link => $node->att('xlink:href') }
                                : map { +{ kind => $_ } } $styles->kinds_of( $node->att('text:style-name') );
                        push @{ $found->{marks} }, map { Term::Fabulous::Document::Mark->new( start => $start, end => $end, %$_ ) } @marks;
                }
                return;
        }
}

1;
```

- `parse_file` unpacks and parses both XML files, builds the styles,
reads the body of the text and returns a [Term::Fabulous::Document](../Document.md).
It dies with a clear message when the file is not a ZIP archive, lacks
one of the two files, or is not a text document; XML::Twig dies on
malformed XML. A viewer for user files should catch these errors and
show them.
- `map_xmlns` makes the parser independent of the namespace prefixes a
file uses: an element is `text:p` whatever prefix the file declares
for the text namespace. `keep_spaces` keeps whitespace that contains a
line break between two elements. By default XML::Twig drops it as
indentation of the XML, but between two spans of a paragraph it
separates two words. `_collect` then reduces every run of whitespace
to one space, as the format prescribes.
- `%READER_OF` maps each element that becomes a block to the method
that reads it. `_body` reads the children of an element in order and
skips the elements it does not know, so a table in the text is left out
without disturbing anything else. A section is read like the body.
- `_list` works out the markers of all its items first, so that it knows
the widest one: `marker_width` is the width of the widest marker plus
a space, and all items of the list share it. A nested list increases
the level and is indented to the text of its item, as in the
[first recipe](#show-a-document-built-in-perl-document-blocks-marks).
The `%place` hash carries this context (indent, list style, level)
down to the elements inside.
- `_inline` produces the `text` and `marks` parameters of a block.
`_collect` walks the children of the paragraph: text is appended,
spaces and tabs become spaces, and spans and links are entered
recursively. When a span is complete, its start and end offsets are
known, and its marks are created. Marks of a paragraph style cover the
whole paragraph and come first, so that marks inside it are drawn over
them.
- Link marks are created in the order of the text, because spans are read
in order and links do not nest. The view relies on that order when it
selects links. A parser that creates marks in another order must sort
the link marks by their start.
- The title gets no marks from its paragraph style: "Title" is bold in
the word processor, but how a title looks is decided by the view's look
(step 7). The same applies to headings.

## Step 6: Check the parser without a terminal

A document is plain data, so you can check what the parser made before
you show it. This program prints every block with its kind and every
mark with the text it covers. It is shipped as
`examples/cookbook/odt-outline.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Odt/Parser.pm lives

use My::Odt::Parser;

binmode STDOUT, ':encoding(UTF-8)';

my $document = My::Odt::Parser->parse_file( shift // "$FindBin::Bin/documents/pancakes.odt" );

# A line per block: its kind, then its text, indented as the view
# indents it and with the marker of an item. Under it a line per mark:
# its kind and the text it covers.
foreach my $block ( $document->blocks ) {
        my $kind   = $block->kind eq 'heading' ? 'heading ' . $block->level : $block->kind;
        my $marker = $block->kind eq 'item'    ? $block->marker . ' '       : '';
        printf "%-10s %s%s%s\n", $kind, ' ' x $block->indent, $marker, $block->text;
        foreach my $mark ( $block->marks ) {
                my $covered = substr( $block->text, $mark->start, $mark->span_length );
                printf "%-10s %s%s \"%s\"%s\n", '', ' ' x $block->indent, $mark->kind, $covered, $mark->is_link ? ' -> ' . $mark->link : '';
        }
}
```

For the example document it prints:

```text
title      Pancakes
paragraph  A quick breakfast for four. It takes 20 minutes, and the batter can rest overnight in the fridge. Read the method once before you start.
           bold "20 minutes"
           italic "overnight"
           link "method" -> #Method|outline
heading 1  Ingredients
item       • 250 g flour
item       • 500 ml milk
item       • 3 eggs
item       • a pinch of salt and two spoons of sugar (the toppings are sweet enough)
           strike "two spoons of sugar"
item       • butter for the pan
heading 1  Method
item       1. Whisk the flour and the milk until the batter is smooth.
item       2. Beat in the eggs and the salt, then let the batter rest for at least 30 minutes.
           underline "at least"
item       3. Melt a little butter in a pan and pour in a ladle of batter.
item          ◦ Use a medium heat.
item          ◦ Turn the pancake when its edges come loose, after about two minutes.
item       4. Keep the pancakes warm in the oven until all are done.
heading 2  Tips
paragraph  For thinner pancakes, add another 100 ml of milk. More recipes are at recipes.example.org.
           bold "another 100 ml of milk"
           link "recipes.example.org" -> https://recipes.example.org/
paragraph  Leftover batter keeps for a day in the fridge.
           italic "Leftover batter keeps for a day in the fridge."
```

Check the output against the document in a word processor: every
heading at the right level, the nested items indented by the width of
their parent's marker (here 3 columns, for `1.` and a space), every mark
over the right words. The bold "another 100 ml of milk" comes from the
named character style "Strong Emphasis" in `styles.xml`, and the
italic last paragraph from its automatic paragraph style `P1`.

The same checks fit into a test with [Test2::V0](https://metacpan.org/pod/Test2%3A%3AV0): parse a small file
and compare `[ map { $_->kind } $document->blocks ]`, the texts and
the marks with what you expect. The constructors of blocks and marks
already die on inconsistent data, such as a mark that ends after the
text or an item whose `marker_width` leaves no room after the marker.

## Step 7: Teach the view the new kinds

The built-in view would refuse this document: it dies when it is given
a document with a mark kind its look does not know (`underline`), and
it would die again when it builds a block without a `view_of_KIND`
method (`title`). Two small subclasses fix that. First the look:

```perl
package My::Odt::Look;

# The styles of My::Odt::View: those of every document view, plus the
# two kinds the OpenDocument reader adds, underlined text and the title.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Look;

class My::Odt::Look :isa(Term::Fabulous::Document::Look) :strict(params) {

        # Colors are palette tokens of the theme, so that the title follows a
        # switch to another theme.
        method recipes :common () {
                return (
                        $class->SUPER::recipes,
                        underline => { words => 'underline' },
                        title     => { words => 'bold', color => 'accent' },
                );
        }
}

1;
```

- `underline` is the mark kind the parser creates for underlined text,
and `title` the style of the title block. Both are recipes as in the
recipe ["Change the styles of a document and add mark kinds (Look)"](#change-the-styles-of-a-document-and-add-mark-kinds-look).

Then the view:

```perl
package My::Odt::View;

# A document view that knows the block and mark kinds of the OpenDocument
# reader: it draws with My::Odt::Look and shows a title (My::Odt::Title)
# centered, in the title style, with a double rule under it.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::DocumentView;

class My::Odt::View :isa(Term::Fabulous::Widget::DocumentView) :strict(params) {
        use Clay::XS qw(sizing_grow CLAY_ALIGN_X_CENTER CLAY_TEXT_ALIGN_CENTER);
        use My::Odt::Look;
        use Term::Fabulous::Widget::Box;
        use Term::Fabulous::Widget::Divider;

        method look_class :common () {
                return 'My::Odt::Look';
        }

        # The text is the RichText of rich_text_of, so that the view styles it
        # and selects its links like those of every other block. A box of the
        # full width centers it, and its lines are centered when it wraps.
        # boxed puts it and the rule into the box the view lays out, with the
        # padding the view gives: the indent and the blank row above.
        method view_of_title ( $block, $padding ) {
                my $text = $self->rich_text_of($block);
                $text->text_alignment(CLAY_TEXT_ALIGN_CENTER);
                my $centered = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_alignment => { x => CLAY_ALIGN_X_CENTER } } );
                $centered->add_child($text);
                my $rule = Term::Fabulous::Widget::Divider->new( line_style => 'Double' );
                return { widget => $self->boxed( $padding, $centered, $rule ), text => $text };
        }

        # A title is in the title style; its marks and the search matches go
        # over it.
        method spans_of :override ( $index, $look ) {
                my $spans = $self->SUPER::spans_of( $index, $look );
                my $block = $self->document->block($index);
                return $spans unless $block->kind eq 'title';
                return [ [ 0, length $block->text, $look->style('title') ], @$spans ];
        }
}

1;
```

- `look_class` makes the view draw with `My::Odt::Look` and accept its
kinds.
- `view_of_title` builds the widgets of a title block. The view calls
`view_of_KIND` for every block of kind `KIND` with the block and a
hash of padding, `{ left => $columns, top => $rows }`: the indent
of the block and the blank row above it. The method returns a hash
reference with two entries:

    - `widget`

        The widget the view shows for the block. It must apply the padding;
        [boxed](../Widget/DocumentView.md#boxed) creates a box of
        the view's width with the padding and the given children, one under the
        other.

    - `text`

        The [RichText](../Widget/RichText.md) that shows the text
        of the block, or `undef` for a block without text. The view styles
        this widget with the marks, the selected link and the search matches.
        [rich\_text\_of](../Widget/DocumentView.md#rich_text_of)
        creates it with the text and the links of the block, set up so that the
        view can select its links.

    The title widget is a full-width box that centers the text, followed by
    a [double rule](../Widget/Divider.md). That is the extra row
    that `body_rows` of step 4 counts.

- `spans_of` returns the styles of a block's text, as
`[ $start, $end, $style ]`, and the view applies them in order: the
base class returns the style of a heading or a term over the whole text,
then those of the marks, then those of the search matches. The subclass
puts the title style first, so that marks and search matches inside the
title are drawn over it.

## Step 8: Put the reader together

The program parses the file, shows it in the new view, and adds a status
bar and the handling of links. It is shipped as
`examples/cookbook/odt-reader.pl`.

```perl
use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use FindBin;
use lib "$FindBin::Bin/lib";    # where My/Odt/*.pm live

use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use My::Odt::Parser;
use My::Odt::View;
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::StatusBar;

my $file     = shift // "$FindBin::Bin/documents/pancakes.odt";
my $document = My::Odt::Parser->parse_file($file);

my $view = My::Odt::View->new(
        id       => 'document',
        document => $document,
        layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1 } },
);

my $where  = '';
my $status = Term::Fabulous::Widget::StatusBar->new(
        message => 'l selects a link, Enter follows it',
        timeout => 4,
        parts   => sub { return ( [ $where, 'dim' ] ) },
);

my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
$root->add_child( $view, $status );

$view->on(
        ViewChange => sub ($event) {
                $where = sprintf '%s  %d%%', $event->section_title // 'Top', $event->percent;
                return;
        }
);

# LibreOffice writes a link to a heading as "#Heading|outline", a link to
# a bookmark as "#Name"; anything else is an address for a browser.
$view->on(
        LinkActivate => sub ($event) {
                my $target = $event->link;
                my ($name) = $target =~ /\A#(.*?)(?:\|outline)?\z/;
                my $index  = defined $name ? $document->find_section($name) : undef;
                if ( defined $index ) {
                        $view->show_block($index);
                }
                else {
                        $status->message( "Open $target in your browser.", 'info' );
                }
                return;
        }
);

my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
$ui->interaction->set_focused_widget($view);
$ui->run;
```

<div>
    <p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/master/screenshots/cookbook-odt-reader.svg" alt="The pancake recipe from an OpenDocument file: the centered title Pancakes over a double rule, a paragraph with bold and italic words and a selected link, the headings Ingredients and Method with rules, a bulleted list with struck-through text, a numbered list with an underlined phrase and a nested list, a second-level heading Tips, a paragraph with a link and an italic paragraph; the status bar shows Top 100%"></p>
</div>

The picture shows the reader after `l` selected the first link.

- The program uses `My::Odt::View` where the earlier recipes used
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md). Everything else works as
before: the keys, search with `n` and `N` after a call of `search`,
`ViewChange`, `LinkActivate`.
- LibreOffice writes a link to a heading of the same document as
`#Heading|outline`. The program removes the `|outline` suffix and
looks the heading up with
[find\_section](../Document.md#find_section). Other targets
are web addresses or files, which the program only reports.
- Try it on your own files: `perl examples/cookbook/odt-reader.pl
letter.odt`. Text in tables, frames and footnotes is not shown.

## Where to go from here

The same steps apply to any format: look at the source, map it to
blocks and marks, add the kinds the built-in ones cannot express, check
the parser without a terminal, and teach a view subclass the new kinds.
Some directions for this reader:

- **Tables** (`<table:table>`). The simplest approach is a paragraph
per row with the cells separated by a few spaces. A real table needs a
block kind whose `view_of_table` builds a [Term::Fabulous::Widget::Table](../Widget/Table.md)
or a grid of boxes, and whose `body_rows` counts the rows of the table
and of its borders.
- **Footnotes** (`<text:note>`). Leave a marker such as `[1]` in the
text, as a link mark whose target names the note, and append the notes
as paragraphs at the end of the document.
- **Pictures** (`<draw:frame>`). Show a placeholder paragraph with the
name of the picture, or a block kind that shows it with
[Term::Fabulous::Widget::Image](../Widget/Image.md).
- **Preformatted text** (the paragraph style "Preformatted Text"). Join
consecutive paragraphs of that style into one
[Term::Fabulous::Document::Block::Verbatim](../Document/Block/Verbatim.md), so that the code keeps its
lines and can be highlighted.
- **Block quotes** (the paragraph style "Quotations"). Give such
paragraphs `quote => 1`, and the view draws the bar.

The reference of the extension points is in
["BLOCK KINDS" in Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md#block-kinds),
[Term::Fabulous::Document::Block](../Document/Block.md), [Term::Fabulous::Document::Look](../Document/Look.md)
and [Term::Fabulous::Document::Geometry](../Document/Geometry.md). [Pod::Fabulous](https://metacpan.org/pod/Pod%3A%3AFabulous) is a
complete reader built the same way, for POD.

# SEE ALSO

This page is part of [Term::Fabulous::Cookbook](../Cookbook.md). Previous page: [Term::Fabulous::Cookbook::Canvases](Canvases.md). Next page: [Term::Fabulous::Cookbook::Output](Output.md).
