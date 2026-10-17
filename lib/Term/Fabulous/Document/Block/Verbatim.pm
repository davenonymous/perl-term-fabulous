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

Term::Fabulous::Document::Block::Verbatim - A verbatim paragraph: code, shown as it is

=head1 SYNOPSIS

	my $code = Term::Fabulous::Document::Block::Verbatim->new( text => "my \$x = 1;\nsay \$x;", language => 'perl' );
	say for $code->lines;

=head1 DESCRIPTION

A verbatim paragraph of a document, usually code. Its text is shown
exactly as written: the lines are kept, formatting codes are not
interpreted, and nothing wraps. The parser is expected to remove the
indentation all lines share and to expand tabs.

The C<language> names what the code is written in, for a syntax
highlighter (see L<Term::Fabulous::Widget::CodeBlock/highlighter>).

=head1 CONSTRUCTOR

=head2 new

	my $code = Term::Fabulous::Document::Block::Verbatim->new( text => 'ls -l', language => 'shell' );

The parameters of L<Term::Fabulous::Document::Block/new> plus:

=over

=item C<language>

C<undef> (the default), or the name of the language, a non-empty
string.

=back

A verbatim block has no marks: giving any dies.

=head1 METHODS

The methods of L<Term::Fabulous::Document::Block>, whose
L<kind|Term::Fabulous::Document::Block/kind> is C<verbatim>, plus:

=head2 language

	my $language = $code->language;    # 'perl', or undef

The language, or C<undef> when the document names none.

=head2 lines

	my @lines = $code->lines;

The lines of the text, without line ends.

=head2 body_rows, row_of_character

A row per line, whatever the columns; a character is on the row of its
line.

=head1 SEE ALSO

L<Term::Fabulous::Document::Block>, L<Term::Fabulous::Widget::CodeBlock>.

=cut
