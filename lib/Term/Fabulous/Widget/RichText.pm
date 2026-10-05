package Term::Fabulous::Widget::RichText;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::RichText
	:isa(Term::Fabulous::Widget::Text)
	:strict(params)
{
	use Clay::UI::Revision qw(bump_revision);
	use Term::Fabulous::Check qw(non_negative_integer);
	use Term::Fabulous::Color;
	use Term::Fabulous::Render::Attr qw(color_attr);
	use Term::Fabulous::Text::Markup qw(parse_markup);
	use Term::Fabulous::Text::Style qw(compose_styles style);

	# The markup the text and spans came from, or undef when they were
	# given directly.
	field $markup :param = undef;

	# The spans as given, checked in ADJUST; the array holds the checked ones.
	field $given_spans :param(spans) = undef;
	field @spans;    # [ $start, $end, $style ]

	# The runs of the whole text (see line_styles), computed on demand and
	# dropped whenever the text or the spans change.
	field $runs = undef;

	# Markup is parsed before the parent sees the text, so that a markup
	# string is just another way to give text and spans.
	sub BUILDARGS ( $class, %params ) {
		return $class->SUPER::BUILDARGS(%params) unless defined $params{markup};
		die "Term::Fabulous::Widget::RichText: markup cannot be given together with text or spans" if exists $params{text} || exists $params{spans};
		my ( $text, $spans ) = parse_markup( $params{markup} );
		return $class->SUPER::BUILDARGS( %params, text => $text, spans => $spans );
	}

	ADJUST {
		die "Term::Fabulous::Widget::RichText: spans must be an array reference of [start, end, style]" if defined $given_spans && ref $given_spans ne 'ARRAY';
		@spans       = map { $self->_checked_span($_) } @{ $given_spans // [] };
		$given_spans = undef;
	}

	# A copy of a span with its offsets checked against the text and its
	# style normalized.
	method _checked_span ($span) {
		die "Term::Fabulous::Widget::RichText: a span is [start, end, style]" unless ref $span eq 'ARRAY' && @$span == 3;
		my ( $start, $end, $style ) = @$span;
		return $self->_span( $style, $start, $end );
	}

	method _span ( $style, $start, $end ) {
		$start = non_negative_integer( $self, 'span start', $start );
		$end   = non_negative_integer( $self, 'span end',   $end );
		my $length = length $self->text;
		die "Term::Fabulous::Widget::RichText: span end $end lies before its start $start" if $end < $start;
		die "Term::Fabulous::Widget::RichText: span end $end lies past the text ($length characters)" if $end > $length;
		return [ $start, $end, style($style) ];
	}

	method _forget_runs () {
		$runs = undef;
		bump_revision();
		return;
	}

	# Setting the text drops the spans: they pointed into the old one.
	method text :override (@new) {
		return $self->SUPER::text unless @new;
		my $text = $self->SUPER::text(@new);
		@spans  = ();
		$markup = undef;
		$self->_forget_runs;
		return $text;
	}

	method markup (@new) {
		return $markup unless @new;
		my ( $text, $spans ) = parse_markup( $new[0] );
		$self->SUPER::text($text);
		@spans  = @$spans;
		$markup = $new[0];
		$self->_forget_runs;
		return $markup;
	}

	method spans () {
		return [ map { [ $_->[0], $_->[1], { %{ $_->[2] } } ] } @spans ];
	}

	method stylize ( $style, $start = 0, $end = undef ) {
		push @spans, $self->_span( $style, $start, $end // length $self->text );
		$markup = undef;
		$self->_forget_runs;
		return $self;
	}

	method clear_spans () {
		@spans  = ();
		$markup = undef;
		$self->_forget_runs;
		return $self;
	}

	# The runs the renderer paints a line with: the part of the text's runs
	# that covers the characters [offset, offset + length).
	method line_styles ( $offset, $length ) {
		return [] if $length <= 0;
		$runs //= $self->_runs_of_text;

		my @slice;
		my $position = 0;
		foreach my $run (@$runs) {
			my $run_start = $position;
			$position += $run->[0];
			next if $position <= $offset;
			last if $run_start >= $offset + $length;

			my $from = $run_start < $offset          ? $offset           : $run_start;
			my $to   = $position > $offset + $length ? $offset + $length : $position;
			push @slice, [ $to - $from, @{$run}[ 1 .. 4 ] ];
		}
		return \@slice;
	}

	# The whole text cut at every span boundary, each piece with the style
	# its spans give it. A run is the tuple Term::Fabulous::Render::Text
	# paints with: [ $characters, $set, $clear, $fg_attr, $bg_attr ], the
	# style's bits and its colors as termbox attributes (undef: the color
	# is not touched), converted once here rather than in every frame.
	method _runs_of_text () {
		my $length = length $self->text;
		return [ [ $length, 0, 0, undef, undef ] ] unless @spans && $length;

		my %seen;
		my @boundaries = sort { $a <=> $b } grep { !$seen{$_}++ } 0, $length, map { @{$_}[ 0, 1 ] } @spans;
		my @runs;
		foreach my $index ( 0 .. $#boundaries - 1 ) {
			my ( $from, $to ) = @boundaries[ $index, $index + 1 ];
			push @runs, [ $to - $from, _look_of( grep { $_->[0] <= $from && $_->[1] >= $to } @spans ) ];
		}
		return \@runs;
	}

	# The set and clear bits and the color attributes that the given spans,
	# stacked in order, give a piece of text.
	sub _look_of (@spans) {
		my $style = compose_styles( map { $_->[2] } @spans );
		return ( $style->{set}, $style->{clear}, _attr_of( $style->{color} ), _attr_of( $style->{background} ) );
	}

	sub _attr_of ($rgba) {
		return undef unless defined $rgba;
		return color_attr( Term::Fabulous::Color->new( color => $rgba ) );
	}

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			markup => \&_parse_markup,
		);
	}

	method _parse_markup ($kid) {
		my $markup_value = $self->kdl_argument($kid);
		die "Term::Fabulous::Widget::RichText: 'markup' needs a string argument" unless $markup_value->is_string;
		$self->markup( $markup_value->value );
		return;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::RichText - Text with styled spans: bold words,
colored phrases, highlighted ranges

=head1 SYNOPSIS

	use Term::Fabulous::Widget::RichText;

	# Markup in the syntax of Python's rich library:
	my $hint = Term::Fabulous::Widget::RichText->new(
		markup => 'Press [bold]Enter[/] to save, [bold red]Esc[/] to leave. [dim]Unsaved changes are lost.[/]',
	);

	# Or text and spans:
	my $line = Term::Fabulous::Widget::RichText->new(
		text  => 'error: file not found',
		spans => [ [ 0, 6, 'bold red' ] ],
	);
	$line->stylize( 'underline', 7, 11 );    # "file"
	$line->stylize('on #3a3f4b');            # the whole text

=head1 DESCRIPTION

A RichText is a L<Term::Fabulous::Widget::Text> whose characters can
differ in look: a I<span> covers a range of the text and sets or
clears style bits (bold, italic, underline, reverse, dim, blink,
strike, overline, conceal), a text color and a background for the
characters it covers. Clay lays the text out exactly like a Text,
wrapping and aligning it; the renderer then paints each wrapped line
with the spans applied. Everything a Text does, a RichText does too:
C<text_color>, C<bold>, C<italic> and C<underline> are the base look
of the whole text, and a span changes it where the span lies.

Spans are given as C<[ $start, $end, $style ]>: the character offsets
of the first character and of the one after the last, and a style
string or hash of L<Term::Fabulous::Text::Style> (C<'bold red on
#202020'>). They may overlap: later spans win where they do. A span
boundary inside a grapheme cluster (a letter with a combining accent,
an emoji with a modifier) snaps to the cluster.

Markup writes the same thing inline: C<[bold]Enter[/]>; see
L<Term::Fabulous::Text::Markup> for the syntax.

The painter of a RichText needs L<Clay::XS> 0.05 or later, which
tells it where every wrapped line starts in the text.

=head1 CONSTRUCTOR

=head2 new

	my $text = Term::Fabulous::Widget::RichText->new(%parameters);

All parameters of L<Term::Fabulous::Widget::Text/new>, plus:

=over

=item C<spans>

An array reference of spans C<[ $start, $end, $style ]>. Default:
C<[]>. Offsets are non-negative integers with
C<< $start <= $end <= length $text >>; C<$style> is a style string or
hash. Anything else dies.

=item C<markup>

A string in the markup syntax of L<Term::Fabulous::Text::Markup>, which
gives both the text and the spans; it cannot be given together with
C<text> or C<spans>. Invalid markup dies.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Text>, plus:

=head2 text

	$text->text('Plain again');

As for a Text, and setting it drops every span and the markup, because
the spans pointed into the old text.

=head2 markup

	my $markup = $text->markup;    # undef when the text was not given as markup
	$text->markup('[bold]New[/] text');

Accessor. Without an argument it returns the markup the text and spans
were last set from, or C<undef> when they were given or changed
directly. With an argument it replaces the text and the spans with
what the markup says, and returns the markup. Invalid markup dies and
leaves the widget as it was. The change shows in the next frame.

=head2 spans

	my $spans = $text->spans;    # [ [ 0, 6, { set => ..., clear => ..., color => ..., background => ... } ], ... ]

The spans, in the order they apply, each with its normalized style
hash (see L<Term::Fabulous::Text::Style/Style hashes>). The result is
a copy.

=head2 stylize

	$text->stylize( 'bold red', 0, 6 );
	$text->stylize('on #3a3f4b');    # the whole text

Adds a span after the existing ones, so it wins where they overlap.
C<$start> defaults to 0, C<$end> to the length of the text. Returns
the widget, so calls chain. Invalid offsets or styles die. The change
shows in the next frame.

=head2 clear_spans

	$text->clear_spans;

Drops every span, keeping the text. Returns the widget.

=head2 line_styles

	my $runs = $text->line_styles( $offset, $length );

Used by the renderer (L<Term::Fabulous::Render::Text>) for each wrapped
line: the characters C<[ $offset, $offset + $length )> of the text cut
into runs of one look, as
C<[ $characters, $set, $clear, $fg_attr, $bg_attr ]>: the number of
characters, the termbox2 style bits the runs's spans set and clear,
and the text and background attributes they give it, C<undef> where
the base look stays. The runs are computed once per change of the
text or the spans.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Text/KDL PROPERTIES>, plus
C<markup>:

=for highlighter language=kdl

	RichText "hint" {
		markup "Press [bold]Enter[/] to save"
	}

C<markup> and C<text> replace each other: whichever comes last wins.
Spans cannot be given in KDL other than through markup.

=head1 SEE ALSO

L<Term::Fabulous::Widget::Text>, L<Term::Fabulous::Text::Style>,
L<Term::Fabulous::Text::Markup>, L<Term::Fabulous::Manual::Looks/TEXT>.

=cut
