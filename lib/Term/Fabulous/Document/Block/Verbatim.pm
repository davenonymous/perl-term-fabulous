package Term::Fabulous::Document::Block::Verbatim;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Document::Block;

our $VERSION = '0.03';

class Term::Fabulous::Document::Block::Verbatim :isa(Term::Fabulous::Document::Block) :strict(params) {
	use Term::Fabulous::Check qw(string);

	field $language :param :reader = undef;

	ADJUST {
		$language = string( $self, language => $language ) if defined $language;
		die "Term::Fabulous::Document::Block::Verbatim: language must not be empty" if defined $language && !length $language;
		die "Term::Fabulous::Document::Block::Verbatim: a verbatim block has no marks" if $self->marks;
	}

	method kind () {
		return 'verbatim';
	}

	method lines () {
		return split /\n/, $self->text, -1;
	}

	# Code does not wrap: a row per line, and a character is on the row
	# of its line.
	method body_rows :override ($columns) {
		return scalar( my @lines = $self->lines );
	}

	method row_of_character :override ( $offset, $columns ) {
		return substr( $self->text, 0, $offset ) =~ tr/\n//;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Block::Verbatim - A verbatim block: code, shown exactly as written

=head1 SYNOPSIS

	my $code = Term::Fabulous::Document::Block::Verbatim->new( text => "my \$x = 1;\nsay \$x;", language => 'perl' );
	say for $code->lines;

=head1 DESCRIPTION

A verbatim block holds a verbatim paragraph of a document, usually
code. The document view shows its text exactly as written: the lines
are kept, nothing in the text is interpreted as formatting, and lines
are never wrapped. A line wider than the view is cut off at the edge,
and the view scrolls all its verbatim blocks sideways together (see
L<Term::Fabulous::Widget::CodeBlock>).

The parser prepares the text: it separates the lines with C<"\n">,
removes the indentation that all lines share, and expands tabs to
spaces, because the code block shows a tab as a single space. The text
should not end with C<"\n">, which would add an empty last line.

The optional C<language> names the language the code is written in.
The view passes it, together with the code, to its syntax highlighter
(see L<Term::Fabulous::Widget::DocumentView/highlighter> and
L<Term::Fabulous::Widget::CodeBlock/highlighter>).

=head1 CONSTRUCTOR

=head2 new

	my $code = Term::Fabulous::Document::Block::Verbatim->new( text => 'ls -l', language => 'shell' );

Creates a verbatim block. It accepts the parameters of
L<Term::Fabulous::Document::Block/new>, plus:

=over

=item C<language>

C<undef> (the default), or the name of the language as a non-empty
string. An empty string or a reference dies.

=back

A verbatim block cannot have marks: giving a non-empty C<marks> array
dies. The view still highlights search matches in the code.

=head1 METHODS

A verbatim block has the methods of L<Term::Fabulous::Document::Block>;
its L<kind|Term::Fabulous::Document::Block/kind> is C<verbatim>. It
adds or overrides these methods:

=head2 language

	my $language = $code->language;    # 'perl', or undef

Returns the language of the code, or C<undef> when the source names
none.

=head2 lines

	my @lines = $code->lines;

Returns the lines of the text, split at C<"\n">, without the line
breaks. A text that ends with C<"\n"> has an empty last line, and an
empty text has no lines at all.

=head2 body_rows, row_of_character

	my $rows = $code->body_rows($columns);
	my $row  = $code->row_of_character( $offset, $columns );

Because code does not wrap, the width does not matter: C<body_rows>
returns the number of L</lines>, and C<row_of_character> returns the
number of line breaks before the character offset, which is the index
of the line that contains the character.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Widget::CodeBlock>.

=cut
