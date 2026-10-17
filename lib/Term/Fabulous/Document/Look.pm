package Term::Fabulous::Document::Look;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.03';

class Term::Fabulous::Document::Look :strict(params) {
	use Scalar::Util qw(blessed refaddr);
	use Term::Fabulous::Check qw(describe);
	use Term::Fabulous::Text::Style ();
	use Term::Fabulous::Theme;

	# Every kind of styled text a document view shows, as the style words
	# it sets and the palette tokens of its text color and background.
	# A subclass adds kinds by overriding recipes.
	method recipes :common () {
		return (
			bold          => { words      => 'bold' },
			italic        => { words      => 'italic' },
			strike        => { words      => 'strike' },
			code          => { color      => 'warning' },
			file          => { words      => 'italic', color => 'success' },
			match         => { background => 'selection' },
			match_current => { color      => 'text_inverse', background => 'warning' },
			heading1      => { words      => 'bold',         color      => 'accent' },
			heading2      => { words      => 'bold',         color      => 'text_bright' },
			heading3      => { words      => 'bold',         color      => 'text' },
			heading4      => { words      => 'bold italic',  color      => 'text' },
			heading5      => { words      => 'italic',       color      => 'text_bright' },
			heading6      => { words      => 'italic',       color      => 'text_muted' },
			term          => { words      => 'bold',         color      => 'text_bright' },
			marker        => { color      => 'accent' },
			quote         => { color      => 'text_muted' },
			code_block    => { color      => 'text',       background => 'surface_low' },
			clipped       => { color      => 'text_muted', background => 'surface_low' },
		);
	}

	field $theme :param :reader;
	field %style_of;

	ADJUST {
		die ref($self) . ": theme must be a Term::Fabulous::Theme, got " . describe($theme) unless blessed $theme && $theme->isa('Term::Fabulous::Theme');
		my %recipe = __CLASS__->recipes;
		%style_of = map { $_ => _style_of_recipe( $theme, $recipe{$_} ) } keys %recipe;
	}

	sub _style_of_recipe ( $theme, $recipe ) {
		my $style = Term::Fabulous::Text::Style::style( $recipe->{words} // {} );
		$style->{color}      = $theme->token( $recipe->{color} ) if defined $recipe->{color};
		$style->{background} = $theme->token( $recipe->{background} ) if defined $recipe->{background};
		return $style;
	}

	method kinds :common () {
		my %recipe = $class->recipes;
		my @kinds  = sort keys %recipe;
		return @kinds;
	}

	method style ($kind) {
		my $style = $style_of{ $kind // '' } // die ref($self) . ": unknown kind " . describe($kind) . "; the kinds are " . join( ', ', __CLASS__->kinds );
		return { %$style, map { ref $style->{$_} ? ( $_ => [ @{ $style->{$_} } ] ) : () } keys %$style };
	}

	# The look of the theme a widget draws with: its UI's, or the default
	# theme while it is in none, as Term::Fabulous::Role::Themed decides.
	# The last look of each class is kept until the theme or the theme
	# generation changes.
	my %last_of_class;    # class => [ look, theme address, generation ]

	method of :common ($widget) {
		my $ui         = $widget->ui;
		my $theme      = defined $ui ? $ui->theme : Term::Fabulous::Theme->default;
		my $generation = Term::Fabulous::Theme::generation();
		my $last       = $last_of_class{$class};
		return $last->[0] if defined $last && $last->[1] == refaddr($theme) && $last->[2] == $generation;
		my $look = $class->new( theme => $theme );
		$last_of_class{$class} = [ $look, refaddr($theme), $generation ];
		return $look;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Document::Look - The styles of a document's text in a theme

=head1 SYNOPSIS

	use Term::Fabulous::Document::Look;

	my $look = Term::Fabulous::Document::Look->of($widget);    # the theme the widget draws with
	$rich_text->stylize( $look->style('code'), 4, 12 );

	my $light = Term::Fabulous::Document::Look->new( theme => Term::Fabulous::Theme->builtin('light') );

	# A look with kinds of its own:
	class My::Look :isa(Term::Fabulous::Document::Look) {
		method recipes :common () {
			return ( $class->SUPER::recipes, title => { words => 'bold', color => 'accent' } );
		}
	}

=head1 DESCRIPTION

A parser marks what a range of text I<is>: bold, code, a link (see
L<Term::Fabulous::Document::Mark>). A look says how each of these kinds
is I<shown>: as a style of L<Term::Fabulous::Text::Style>, the style
bits to set and clear, a text color and a background, which a
L<Term::Fabulous::Widget::RichText> span takes as it is. Links are not
a kind of the look: a RichText paints its links itself, in the link
looks of the theme (see L<Term::Fabulous::Widget::RichText/Looks>).

Every color comes from the palette of a L<Term::Fabulous::Theme>
(L<Term::Fabulous::Theme/Tokens>), so a document view follows the theme
the program runs with, built in or from a theme file, and a theme
switch restyles the text.

=head1 KINDS

=for highlighter language=text

	Kind           Shown as                     Used for
	-------------  ---------------------------  ---------------------------------------
	bold           bold                         bold text
	italic         italic                       italic text
	strike         strike                       struck-through text
	code           warning                      code in a paragraph
	file           italic, success              a file name
	match          on selection                 a search match
	match_current  text_inverse on warning      the match the view is at
	heading1       bold, accent                 a first-level heading
	heading2       bold, text_bright            a second-level heading
	heading3       bold, text                   a third-level heading
	heading4       bold italic, text            a fourth-level heading
	heading5       italic, text_bright          a fifth-level heading
	heading6       italic, text_muted           a sixth-level heading
	term           bold, text_bright            the term of a definition list
	marker         accent                       bullets and numbers of items
	quote          text_muted                   the bar beside a block quote
	code_block     text on surface_low          verbatim blocks
	clipped        text_muted on surface_low    the marks of clipped code lines

The names in the middle column are palette tokens.

A subclass adds kinds, or changes these, by overriding L</recipes>; a
L<Term::Fabulous::Widget::DocumentView> subclass names its look class
with L<look_class|Term::Fabulous::Widget::DocumentView/look_class>.

=head1 CONSTRUCTORS

=head2 new

=for highlighter language=perl

	my $look = Term::Fabulous::Document::Look->new( theme => $theme );

The look of a L<Term::Fabulous::Theme>. Unknown parameters die, and so
does anything but a theme.

=head2 of

	my $look = Term::Fabulous::Document::Look->of($widget);

The look of the theme a widget draws with: the theme of the
L<Term::Fabulous> it is part of, or the default theme while it is part
of none (the rule of L<Term::Fabulous::Role::Themed>). The look made
last by the class is kept and returned again until the theme is another
one or a theme was switched anywhere
(L<Term::Fabulous::Theme/"generation, bump_generation">), so asking
for it in every frame costs a comparison.

=head1 CLASS METHODS

=head2 recipes

	my %recipe = Term::Fabulous::Document::Look->recipes;

The kinds as C<< kind => { words => 'bold italic', color => TOKEN, background => TOKEN } >>:
the style words of L<Term::Fabulous::Text::Style/Style strings> the
kind sets, and the palette tokens of its text color and its background,
each optional. A subclass returns its parent's recipes plus its own.

=head2 kinds

	my @kinds = Term::Fabulous::Document::Look->kinds;    # bold, clipped, code, ...

The names of the kinds, sorted. A widget that takes kinds from a program
checks them against it.

=head1 METHODS

=head2 theme

	my $theme = $look->theme;

The theme the styles come from.

=head2 style

	my $style = $look->style('code');    # { set => ..., clear => ..., color => [...], background => undef }

The style of a kind, as a new style hash (see
L<Term::Fabulous::Text::Style/Style hashes>). An unknown kind dies
with the list of known ones.

=head1 SEE ALSO

L<Term::Fabulous::Text::Style>, L<Term::Fabulous::Theme>,
L<Term::Fabulous::Manual::Looks/THEMES>, L<Term::Fabulous::Document::Mark>.

=cut
