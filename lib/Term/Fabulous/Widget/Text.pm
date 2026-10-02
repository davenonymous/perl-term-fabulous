package Term::Fabulous::Widget::Text;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Text
	:isa(Term::Fabulous::Widget::TextNode)
	:does(Term::Fabulous::Role::CanParseLayout)
	:strict(params)
{
	use Clay::XS qw(CLAY_TEXT_WRAP_WORDS CLAY_TEXT_WRAP_NEWLINES CLAY_TEXT_WRAP_NONE CLAY_TEXT_ALIGN_LEFT CLAY_TEXT_ALIGN_CENTER CLAY_TEXT_ALIGN_RIGHT);
	use Feature::Compat::Try;
	use Term::Fabulous::Color;

	my %WRAP_MODE_BY_NAME      = ( words => CLAY_TEXT_WRAP_WORDS, newlines => CLAY_TEXT_WRAP_NEWLINES, none  => CLAY_TEXT_WRAP_NONE );
	my %TEXT_ALIGNMENT_BY_NAME = ( left  => CLAY_TEXT_ALIGN_LEFT, center   => CLAY_TEXT_ALIGN_CENTER,  right => CLAY_TEXT_ALIGN_RIGHT );

	field $id :param :reader = undef;

	# Clay::UI validates text_color before any ADJUST of this class runs,
	# so it is converted while the arguments are still a plain list.
	sub BUILDARGS ( $class, %params ) {
		$params{text_color} = _rgba( $params{text_color} ) if defined $params{text_color};
		return %params;
	}

	# Any Term::Fabulous::Color input as the [r, g, b, a] array Clay::UI takes.
	sub _rgba ($value) {
		try {
			return [ Term::Fabulous::Color->new( color => $value )->to_rgba ];
		}
		catch ($error) {
			die "Term::Fabulous::Widget::Text: text_color is not a color: $error";
		}
	}

	# The value a name stands for in %$value_by_name; an unknown name dies
	# with the known ones.
	sub _named ( $what, $value_by_name, $name ) {
		return $value_by_name->{$name} if defined $name && exists $value_by_name->{$name};
		die "Term::Fabulous::Widget::Text: invalid $what " . ( defined $name ? "'$name'" : 'null' ) . " (known: " . join( ', ', sort keys %$value_by_name ) . ")";
	}

	method text_color :override (@new) {
		return $self->SUPER::text_color( @new && defined $new[0] ? _rgba( $new[0] ) : @new );
	}

	method layout_properties () {
		return qw(font_id font_size letter_spacing line_height);
	}

	method boolean_layout_properties () {
		return ();
	}

	method structured_layout_properties () {
		return qw(text text_color wrap_mode text_alignment);
	}

	method parse_node ($node) {
		foreach my $kid ( $node->children->@* ) {
			my $name = $kid->name;
			if ( $name eq 'text' ) {
				my $text = $self->kdl_argument($kid);
				die "Term::Fabulous::Widget::Text: 'text' needs a string argument" unless $text->is_string;
				$self->text( $text->value );
			}
			elsif ( $name eq 'text_color' ) {
				$self->text_color( $self->kdl_argument($kid)->as_perl );
			}
			elsif ( $name eq 'wrap_mode' ) {
				$self->wrap_mode( _named( wrap_mode => \%WRAP_MODE_BY_NAME, $self->kdl_argument($kid)->as_perl ) );
			}
			elsif ( $name eq 'text_alignment' ) {
				$self->text_alignment( _named( text_alignment => \%TEXT_ALIGNMENT_BY_NAME, $self->kdl_argument($kid)->as_perl ) );
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

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::Text - A piece of text inside a box

=head1 SYNOPSIS

	use utf8;    # this source file contains non-ASCII text
	use Term::Fabulous::Widget::Text;

	my $title = Term::Fabulous::Widget::Text->new(
		text       => 'Settings',
		text_color => [ 255, 255, 255, 255 ],
	);

	# Text is a character string, like everywhere in Term::Fabulous:
	my $greeting = Term::Fabulous::Widget::Text->new(
		id         => 'greeting',
		text       => 'Grüße',
		text_color => [ 230, 230, 230, 255 ],
	);

	# Later, change what it shows:
	$greeting->text('Hello again');

=begin html

<p><img src="/screenshots/widget-text.svg" alt="Colored words, a sentence wrapped left-aligned, centered and right-aligned, and text in five scripts"></p>

=end html

=head1 DESCRIPTION

A Text widget shows text inside its parent widget, usually a
L<Term::Fabulous::Widget::Box>. The layout makes it as wide as its
longest line, wraps it at spaces when the parent is too narrow, and
starts a new line at every C<"\n">. Text has a color but no background
of its own: every cell shows the background that was painted below it.

A Text widget is a leaf: it cannot have children, and it has no
border, padding or background. To give text a background, a border or
a fixed size, put it in a Box. Text widgets do not receive mouse or key
events: a click on text is delivered to the box behind it.

The class is built on L<Clay::UI::Text>.

=head1 CONSTRUCTOR

=head2 new

	my $text = Term::Fabulous::Widget::Text->new(%parameters);

All parameters are optional; unknown parameters die. Every parameter
except C<id> also has an accessor of the same name.

=over

=item C<text>

A character string, like all text in Term::Fabulous. Default: C<''>.

Bytes read from a file, a command or a socket must be decoded first
with C<Encode::decode('UTF-8', $bytes)>; otherwise each byte is shown
as one Latin-1 character. Text read from a KDL layout is used as is.
See L<Term::Fabulous::Manual/Text is character strings>.

Control characters are never sent to the terminal: a TAB is shown as
one space and every other control character as U+FFFD. Wide characters
(most CJK characters and emoji) take two cells.

=item C<text_color>

The color of the characters, in any format L<Term::Fabulous::Color>
accepts: C<[r, g, b, a]> (or C<[r, g, b]>), C<{ r, g, b, a }>, a string
such as C<'#ffffff'> or C<'rgb(255, 255, 255)'>, or a
Term::Fabulous::Color object; it is stored as C<[r, g, b, a]>. Default:
C<[0, 0, 0, 255]>, opaque black, which is invisible on a dark
background; you will almost always want to set it. Pass
C<[0, 0, 0, 0]> (alpha 0) for the terminal's default foreground color.
See L<Term::Fabulous::Manual/COLORS>.

=item C<id>

A string naming the widget, for your own use (for example to find a
Text in a tree built from a layout). Default: none. Unlike a Box's id,
it is not passed to Clay and does not need to be unique, and
L<Term::Fabulous::Widget/remove_child> does not remove Text widgets by
id. Read it with C<< $text->id >>; there is no writer.
L<Term::Fabulous::Widget/find_by_id> finds Text widgets by this id.

=item C<wrap_mode>

How lines are broken, one of the L<Clay::XS> constants:
C<CLAY_TEXT_WRAP_WORDS> (the default: break at C<"\n"> and, where the
text does not fit, at spaces), C<CLAY_TEXT_WRAP_NEWLINES> (break only
at C<"\n">) and C<CLAY_TEXT_WRAP_NONE> (in this version the same as
C<CLAY_TEXT_WRAP_NEWLINES>). A line
that is not broken may be wider than the parent; it is cut off at the
right edge of the terminal.

With every mode, a single word that is wider than the space available
is never broken: it runs past the right edge of its parent and is cut
off only at the edge of the terminal or of an enclosing
L<Term::Fabulous::Widget::ScrollBox>. See
L<Term::Fabulous::Manual/Wrapping>.

=item C<text_alignment>

C<CLAY_TEXT_ALIGN_LEFT> (the default), C<CLAY_TEXT_ALIGN_CENTER> or
C<CLAY_TEXT_ALIGN_RIGHT>. Aligns the lines of a multi-line text against
each other, within the width of its longest line. It has no visible
effect on a single line: to center a Text in its box, set
C<child_alignment> in the box's C<layout> (see
L<Term::Fabulous::Widget/new>).

=item C<line_height>

The number of rows each line takes, an integer from 0 to 65535; other
values (such as C<1.5>) die. Default: 0, which means one row. With
C<2>, an empty row follows every line.

=item C<font_id>

=item C<font_size>

=item C<letter_spacing>

Accepted because Clay::UI supports them, but meaningless in a terminal:
every character is drawn in the terminal's font. C<font_id> and
C<font_size> have no effect. Do not set C<letter_spacing>: Clay uses it
when it decides where to wrap lines, but no spacing is drawn, so lines
wrap too early.

=back

=head1 METHODS

Besides the accessors below, a Text widget has the methods C<parent>,
C<root>, C<ui> and C<on> that every widget has (see
L<Term::Fabulous::Widget>); C<on> is rarely useful, because no events
are fired on Text widgets.

=head2 text

	my $text = $label->text;
	$label->text($new_text);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
text is a character string; the layout adapts to the new length.

=head2 text_color

	my $rgba = $label->text_color;
	$label->text_color( [ 255, 80, 80, 255 ] );
	$label->text_color('#ff5050');

Accessor. Without an argument it returns the current value as
C<[r, g, b, a]>; with an argument it sets it, in any format the
constructor parameter accepts, and returns the stored C<[r, g, b, a]>.
An invalid value dies like the constructor parameter. The change shows
in the next frame.

=head2 id

	my $id = $label->id;

The C<id> given to the constructor, or C<undef>. There is no writer.

=head2 wrap_mode

	$label->wrap_mode(CLAY_TEXT_WRAP_NONE);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
reader returns C<undef> when it was never set, which behaves as
C<CLAY_TEXT_WRAP_WORDS>.

=head2 text_alignment

	$label->text_alignment(CLAY_TEXT_ALIGN_RIGHT);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. The
reader returns C<undef> when it was never set, which behaves as
C<CLAY_TEXT_ALIGN_LEFT>.

=head2 line_height

	$label->line_height(2);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame.

=head2 font_id

	$label->font_id(1);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. It
has no visible effect in a terminal.

=head2 font_size

	$label->font_size(16);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. It
has no visible effect in a terminal; the default is 16.

=head2 letter_spacing

	$label->letter_spacing(0);

Accessor. Without an argument it returns the current value; with an
argument it sets it and returns the new value. An invalid value dies
like the constructor parameter. The change shows in the next frame. Do
not set it to anything but 0: it makes Clay wrap lines too early, and no
spacing is drawn.

=head1 KDL PROPERTIES

	Text "greeting" {
		text "Gr\u{fc}\u{df}e, world"
		text_color "#e6e6e6"
		line_height 2
		wrap_mode newlines
		text_alignment center
	}

The node's argument (C<"greeting">) is the C<id>. Inside the block:

=over

=item C<text "...">

Exactly one string. It is used as is, so write any characters directly
(KDL files are UTF-8).

=item C<text_color "...">

Exactly one argument: any color string L<Term::Fabulous::Color>
understands, such as C<"#ffffff">, C<"rgb(255, 255, 255)"> or
C<"hsl(0, 0%, 100%)">.

=item C<wrap_mode words>

Exactly one name: C<words> (C<CLAY_TEXT_WRAP_WORDS>), C<newlines>
(C<CLAY_TEXT_WRAP_NEWLINES>) or C<none> (C<CLAY_TEXT_WRAP_NONE>). See
the C<wrap_mode> parameter of L</new>.

=item C<text_alignment left>

Exactly one name: C<left> (C<CLAY_TEXT_ALIGN_LEFT>), C<center>
(C<CLAY_TEXT_ALIGN_CENTER>) or C<right> (C<CLAY_TEXT_ALIGN_RIGHT>). See
the C<text_alignment> parameter of L</new>.

=item C<line_height N>

=item C<font_id N>

=item C<font_size N>

=item C<letter_spacing N>

One number each; see L</new> for their (lack of) meaning.

=back

An unknown C<wrap_mode> or C<text_alignment> name dies with the known
names. Any other property dies. A Text node cannot have child widgets.

=head1 SUBCLASS INTERFACE

These methods are used by L<Term::Fabulous::Layout>; you do not call
them yourself.

=head2 layout_properties

	my @names = $text->layout_properties;

The names of the properties a KDL layout may set with
L<Term::Fabulous::Role::CanParseLayout/parse_generic>: C<font_id>,
C<font_size>, C<letter_spacing> and C<line_height>. C<text>,
C<text_color>, C<wrap_mode> and C<text_alignment> are handled by
L</parse_node>; see L</KDL PROPERTIES>.

=head2 boolean_layout_properties

	my @names = $text->boolean_layout_properties;

The names of the boolean properties among L</layout_properties>: none
for a Text widget.

=head2 structured_layout_properties

	my @names = $text->structured_layout_properties;

The names of the properties L</parse_node> handles itself: C<text>,
C<text_color>, C<wrap_mode> and C<text_alignment>. They appear in the "known" list of the error for an
unknown property.

=head2 parse_node

	$text->parse_node($node);

Reads the properties of a KDL node; called during construction when
the widget is built from a layout.

=head1 SEE ALSO

L<Term::Fabulous::Manual/TEXT>, L<Term::Fabulous::Widget::Box>,
L<Term::Fabulous::Unicode>, L<Clay::UI::Text>.

=cut
