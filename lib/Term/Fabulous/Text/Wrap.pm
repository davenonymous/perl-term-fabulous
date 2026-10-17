package Term::Fabulous::Text::Wrap;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT_OK = qw(wrapped_rows wrapped_row);

use Term::Fabulous::Check qw(describe non_negative_integer positive_integer);
use Term::Fabulous::Unicode qw(string_columns);

# A printable ASCII character takes one column. Most words of a document
# are such, and measuring them is the bulk of the estimates of a long
# document: asking Unicode for every word takes three times as long.
sub _columns_of ($word) {
	return $word =~ /\A[\x20-\x7E]*\z/ ? length $word : string_columns($word);
}

# Clay wraps text at the spaces, and only there (a no-break space is
# part of its word). It measures every word together with the space
# after it, and a word that does not fit on the line starts the next
# one; a word wider than the line has a line of its own, and runs past
# its end. Calls $on_word with the row and the offset after each word
# and its space; a true return value stops the walk. Returns the row of
# the last word.
sub _wrap ( $text, $columns, $on_word ) {
	my @words = split / /, $text, -1;
	my ( $row, $used, $position ) = ( 0, 0, 0 );
	foreach my $index ( 0 .. $#words ) {
		my $width = _columns_of( $words[$index] ) + ( $index < $#words ? 1 : 0 );
		if ( $used > 0 && $used + $width > $columns ) { ( $row, $used ) = ( $row + 1, $width ) }
		else                                          { $used += $width }
		$position += length( $words[$index] ) + 1;
		last if $on_word->( $row, $position );
	}
	return $row;
}

sub _checked_text ( $function, $text ) {
	die "Term::Fabulous::Text::Wrap: $function needs a text, got " . describe($text) unless defined $text && !ref $text;
	return $text;
}

sub wrapped_rows ( $text, $columns ) {
	_checked_text( wrapped_rows => $text );
	$columns = positive_integer( __PACKAGE__, columns => $columns );
	return 1 + _wrap( $text, $columns, sub { return 0 } );
}

sub wrapped_row ( $text, $offset, $columns ) {
	_checked_text( wrapped_row => $text );
	$offset  = non_negative_integer( __PACKAGE__, offset => $offset );
	$columns = positive_integer( __PACKAGE__, columns => $columns );
	return _wrap( $text, $columns, sub ( $row, $position ) { return $offset < $position } );
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Text::Wrap - Predict how many rows a text takes when Clay wraps it

=head1 SYNOPSIS

	use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);

	# In 8 columns, 'some words to wrap' wraps to "some", "words", "to wrap".
	my $rows = wrapped_rows( 'some words to wrap', 8 );     # 3
	my $row  = wrapped_row( 'some words to wrap', 11, 8 );  # 2: character 11 starts "to", on the third row

=head1 DESCRIPTION

Clay lays out the text of a L<Term::Fabulous::Widget::Text> or
L<Term::Fabulous::Widget::RichText> during a frame, so the number of
rows the text takes is known only after that frame. Some widgets need
it earlier. A L<Term::Fabulous::Widget::DocumentView>, for example,
estimates the height of every paragraph it has not laid out yet, and
needs the row of a search match within a paragraph to scroll it into
view. These two functions wrap a text the way Clay does and give those
answers without a frame.

The functions matter mostly to authors of block kinds whose body is
wrapped text: the default
L<body_rows|Term::Fabulous::Document::Block/body_rows> and
L<row_of_character|Term::Fabulous::Document::Block/row_of_character>
of L<Term::Fabulous::Document::Block> call them.

=head2 How Clay wraps

The functions follow these rules, which are Clay's for a text of a
single line:

=over

=item *

Lines break at space characters (U+0020). Every other character
belongs to a word, including a no-break space, which keeps the words on
either side together. Clay also starts a new line at C<"\n">, but these
functions do not: they count a line break as part of a word. Pass them
a single line, as the text of a document's blocks is.

=item *

Every word is measured in terminal columns together with the space
that follows it. The last word of the text has no space after it and is
measured alone.

=item *

A word that does not fit on the current line starts the next line.

=item *

A word that is wider than the line gets a line of its own and runs past
the end of that line.

=back

F<t/text-wrap.t> checks the functions against RichText widgets that
Clay laid out on a memory terminal, so a change in Clay's wrapping
shows up as a test failure.

Printable ASCII characters count as one column each and need no
lookup. Other characters are measured with
L<Term::Fabulous::Unicode/string_columns>, so wide characters such as
CJK ideographs count as two columns.

=head1 FUNCTIONS

Nothing is exported by default.

=head2 wrapped_rows

	my $rows = wrapped_rows( $text, $columns );

Returns the number of rows C<$text> takes when it is wrapped to
C<$columns> columns. The result is at least 1, even for an empty text.
Dies when C<$text> is not a string or C<$columns> is not a positive
integer.

=head2 wrapped_row

	my $row = wrapped_row( $text, $offset, $columns );

Returns the row, counted from 0, of the character at C<$offset> when
C<$text> is wrapped to C<$columns> columns. C<$offset> counts
characters from 0, not columns. A space belongs to the row of the word
before it, and an offset at or past the end of the text lies on the
last row. Dies when C<$text> is not a string, C<$offset> is not a
non-negative integer or C<$columns> is not a positive integer.

=head1 SEE ALSO

L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Widget::Text/wrap_mode>,
L<Term::Fabulous::Manual::Looks/Wrapping>.

=cut
