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
