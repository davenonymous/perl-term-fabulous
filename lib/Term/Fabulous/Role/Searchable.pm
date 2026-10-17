package Term::Fabulous::Role::Searchable;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT_OK = qw(searchables_in);

use Scalar::Util qw(blessed);

# The widgets of a subtree that answer a search: a widget that does the
# role answers for everything inside it; the children of any other
# widget are looked at in layout order.
sub searchables_in ($widget) {
	return () unless blessed $widget;
	return $widget if $widget->DOES(__PACKAGE__);
	return () unless $widget->can('layout_children');
	return map { searchables_in($_) } @{ $widget->layout_children };
}

use Object::Pad 0.825;

role Term::Fabulous::Role::Searchable {
	method search_texts;
	method search_revision;
	method highlight_text;
	method clear_text_highlights;
	method reveal_text;
}

1;

__END__

=head1 NAME

Term::Fabulous::Role::Searchable - The texts of a widget, for search and highlights

=head1 SYNOPSIS

	use Term::Fabulous::Role::Searchable qw(searchables_in);

	foreach my $widget ( searchables_in($item) ) {
		foreach my $entry ( $widget->search_texts ) {
			my ( $key, $text ) = @$entry;
			next unless $text =~ /needle/;
			$widget->highlight_text( $key, [ [ $-[0], $+[0], 'on yellow' ] ] );
			my ( $shown, $row ) = @{ $widget->reveal_text( $key, $-[0] ) };
		}
	}

=head1 DESCRIPTION

A widget that composes this role can be searched: it says which texts
it shows, marks ranges of a text with a style, and brings a text into
view inside itself. L<Term::Fabulous::Widget::Text> and
L<Term::Fabulous::Widget::CodeBlock> do it for the one text each of
them holds. A widget that builds its texts only when it needs them,
such as a L<table|Term::Fabulous::Widget::Table> with cells on other
pages, does it from its own data, so that a search reaches text that
is not on the screen. L<Term::Fabulous::Widget::DocumentView> searches
its items through this role.

The role declares the methods below and provides none, so a class that
composes it defines all of them.

=head1 REQUIRED METHODS

=head2 search_texts

	my @entries = $widget->search_texts;    # ( [ $key, $text ], ... )

The texts the widget shows, in the order they appear, each with a
I<key>: any value that names that text within the widget and stays the
same while the text exists, such as C<undef> for a widget with one
text, or a row and a column for a table cell. Offsets into C<$text> are
character offsets.

=head2 search_revision

	my $revision = $widget->search_revision($key);

A value that changes whenever the text named by the key changes, so a
caller can tell whether offsets it recorded earlier still point where
they did. Comparing two values with C<ne> is enough.

=head2 highlight_text

	$widget->highlight_text( $key, [ [ $start, $end, $style ], ... ] );

Marks ranges of the text named by the key with styles (strings or hash
references as L<Term::Fabulous::Text::Style> reads them), replacing the
ranges given before for that text. The widget shows them over its own
styles whenever it shows that text, also when it builds the widget for
it later. Offsets past the text die.

=head2 clear_text_highlights

	$widget->clear_text_highlights;

Removes every highlight of every text of the widget.

=head2 reveal_text

	my ( $shown, $row ) = @{ $widget->reveal_text( $key, $offset ) };

Makes the text named by the key visible inside the widget, as far as
the widget can: a table turns to the page of the row, a tab control
activates the page. Returns an array reference of two values, each of
which may be C<undef>: the L<Term::Fabulous::Widget::Text> that shows
the text, once it exists, and the row within the widget on which the
character at the offset lies, when the widget knows it before a layout
(a code block knows its line). A caller that scrolls the widget into
view uses the row, else the text widget's painted lines, else the
widget's own box.

=head1 FUNCTIONS

=head2 searchables_in

	my @widgets = searchables_in($widget);

The widgets at or below C<$widget> that compose this role, in layout
order: C<$widget> itself if it does, else those found among its
layout children, the children of a widget that does the role not
included (it answers for them). Exported on request.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Text>, L<Term::Fabulous::Widget::CodeBlock>,
L<Term::Fabulous::Widget::DocumentView>.

=cut
