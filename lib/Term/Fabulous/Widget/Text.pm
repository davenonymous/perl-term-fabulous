package Term::Fabulous::Widget::Text;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Text
	:does(Clay::UI::Text)
	:does(Term::Fabulous::Role::CanParseLayout)
	:strict(params)
{
	use Encode qw(encode);
	use Term::Fabulous::Color;

	field $id :param :reader = undef;

	method layout_properties () {
		return qw(font_id font_size letter_spacing line_height);
	}

	method parse_node ($node) {
		foreach my $kid ( $node->children->@* ) {
			my $name = $kid->name;
			if ( $name eq 'text' ) {
				my $text = $self->kdl_argument($kid);
				die "Term::Fabulous::Widget::Text: 'text' needs a string argument" unless $text->is_string;
				$self->text( encode( 'UTF-8', $text->value ) );
			}
			elsif ( $name eq 'text_color' ) {
				$self->text_color( [ Term::Fabulous::Color->new( color => $self->kdl_argument($kid)->as_perl )->to_rgba ] );
			}
			else {
				$self->parse_generic($kid);
			}
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Text - Text leaf widget

=head1 SYNOPSIS

	use Encode qw(encode);
	use Term::Fabulous::Widget::Text;

	my $label = Term::Fabulous::Widget::Text->new(
		id         => 'greeting',
		text       => encode('UTF-8', "Gr\x{fc}\x{df}e"),
		text_color => [255, 255, 255, 255],
	);

=head1 DESCRIPTION

A L<Clay::UI::Text> leaf. Unknown constructor parameters die.

=head2 text

Holds UTF-8 encoded bytes, not a character string: Clay reads text as
bytes, and the renderer decodes it again. Encode character strings with
C<Encode::encode('UTF-8', ...)> before passing them. Text built from a
KDL layout is encoded automatically. Control characters are shown as
U+FFFD (TAB as a space) instead of reaching the terminal.

=head2 id

Optional identifier (the widget node's argument in a KDL layout),
available through the C<id> reader.

=head1 KDL PROPERTIES

=over

=item C<text "...">

Exactly one string argument.

=item C<text_color "...">

Exactly one argument, any L<Term::Fabulous::Color> string.

=item C<font_id>, C<font_size>, C<letter_spacing>, C<line_height>

One argument each, set through
L<Term::Fabulous::Role::CanParseLayout/parse_generic>.

=back

Any other property node dies.

=cut
