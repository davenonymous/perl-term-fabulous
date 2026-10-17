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
