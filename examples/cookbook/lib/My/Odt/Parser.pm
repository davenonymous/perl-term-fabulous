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
