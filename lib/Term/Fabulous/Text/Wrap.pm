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

Term::Fabulous::Text::Wrap - How many rows a text takes when Clay wraps it

=head1 SYNOPSIS

	use Term::Fabulous::Text::Wrap qw(wrapped_rows wrapped_row);

	my $rows = wrapped_rows( 'some words to wrap', 8 );    # 3
	my $row  = wrapped_row( 'some words to wrap', 11, 8 ); # 1: "to" is on the second row

=head1 DESCRIPTION

Clay lays out the text of a L<Term::Fabulous::Widget::Text> and knows
how many rows it took only after the frame. A widget that must know
before, such as a L<Term::Fabulous::Widget::DocumentView> estimating
the height of a paragraph it has not laid out yet, or finding the row
of a search match within a paragraph, wraps the text the way Clay does
with these two functions.

Clay wraps at the spaces, and only there, so a no-break space is part
of its word. Every word is measured in terminal columns together with
the space after it; a word that does not fit on the line starts the
next one, and a word wider than a line has a line of its own, past
whose end it runs. F<t/text-wrap.t> checks the functions against a
RichText that Clay laid out on a memory terminal.

Printable ASCII characters take one column each without a lookup; other
characters are measured with L<Term::Fabulous::Unicode/string_columns>.

=head1 FUNCTIONS

Nothing is exported by default.

=head2 wrapped_rows

	my $rows = wrapped_rows( $text, $columns );

The rows the text wraps to in that many columns, at least one. The
text must be a string and the columns a positive integer; anything else
dies.

=head2 wrapped_row

	my $row = wrapped_row( $text, $offset, $columns );

The row, from 0, of the character at the offset when the text is
wrapped to that many columns. A space belongs to the word before it; an
offset past the end is on the last row. The offset must be a
non-negative integer.

=head1 SEE ALSO

L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Widget::Text/wrap_mode>,
L<Term::Fabulous::Manual::Looks/Wrapping>.

=cut
