package Term::Fabulous::Widget::Box;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Box
	:isa(Term::Fabulous::Widget)
	:does(Term::Fabulous::Role::CanParseLayout)
	:strict(params)
{
	use Clay::XS qw(sizing_fit sizing_fixed sizing_grow sizing_percent CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM);
	use Term::Fabulous::Color;
	use Term::Fabulous::Enum::BorderStyle;

	my %DIRECTION_BY_NAME = (
		top_to_bottom => CLAY_TOP_TO_BOTTOM,
		ttb           => CLAY_TOP_TO_BOTTOM,
		down          => CLAY_TOP_TO_BOTTOM,
		left_to_right => CLAY_LEFT_TO_RIGHT,
		ltr           => CLAY_LEFT_TO_RIGHT,
		right         => CLAY_LEFT_TO_RIGHT,
	);

	my $DECIMAL = qr/(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)/;

	sub _describe ($value) {
		return defined $value ? "'$value'" : 'null';
	}

	sub _non_negative_integer ( $what, $value ) {
		die "Term::Fabulous::Widget::Box: $what must be a non-negative integer, got " . _describe($value)
			unless defined $value && $value =~ /\A[0-9]+\z/;
		return $value + 0;
	}

	sub _sizing ( $axis, $spec ) {
		$spec //= '';
		return sizing_grow() if $spec eq 'grow';
		return sizing_fit()  if $spec eq 'fit';
		if ( my ($percent) = $spec =~ /\Apercent\(\s*($DECIMAL)\s*\)\z/ ) {
			die "Term::Fabulous::Widget::Box: sizing $axis percentage must be in 0..100, got '$spec'" if $percent > 100;
			return sizing_percent( $percent / 100 );
		}
		if ( my ($cells) = $spec =~ /\Afixed\(\s*([0-9]+)\s*\)\z/ ) {
			return sizing_fixed( $cells + 0 );
		}
		die "Term::Fabulous::Widget::Box: invalid sizing $axis '$spec' (expected grow, fit, percent(0..100) or fixed(N))";
	}

	sub _border_style ($name) {
		return Term::Fabulous::Enum::BorderStyle->from_name( $name // '' )
			// die "Term::Fabulous::Widget::Box: invalid border style " . _describe($name) . " (known: "
			. join( ', ', map { $_->name } Term::Fabulous::Enum::BorderStyle->values ) . ")";
	}

	method layout_properties () {
		return qw(background_color glyphs_show_through border_color border_width width_group height_group);
	}

	method parse_node ($node) {
		$self->parse_property($_) foreach $node->children->@*;
		return;
	}

	method parse_property ($kid) {
		my $name = $kid->name;
		if    ( $name eq 'layout' )  { $self->_parse_layout($kid) }
		elsif ( $name eq 'border' )  { $self->_parse_border($kid) }
		elsif ( $name eq 'sizing' )  { $self->_parse_sizing($kid) }
		elsif ( $name eq 'padding' ) { $self->_parse_padding($kid) }
		else                         { $self->parse_generic($kid) }
		return;
	}

	method _parse_layout ($kid) {
		my $props = $self->kdl_properties( $kid, qw(direction child_gap gap) );
		die "Term::Fabulous::Widget::Box: layout accepts 'child_gap' or its alias 'gap', not both"
			if exists $props->{child_gap} && exists $props->{gap};

		my %layout = %{ $self->layout };
		if ( exists $props->{direction} ) {
			my $direction = $props->{direction} // '';
			$layout{layout_direction} = $DIRECTION_BY_NAME{$direction}
				// die "Term::Fabulous::Widget::Box: invalid layout direction '$direction' (known: " . join( ', ', sort keys %DIRECTION_BY_NAME ) . ")";
		}
		foreach my $gap_name ( grep { exists $props->{$_} } qw(child_gap gap) ) {
			$layout{child_gap} = _non_negative_integer( "layout $gap_name", $props->{$gap_name} );
		}
		$self->layout( \%layout );
		return;
	}

	method _parse_border ($kid) {
		my @sides = qw(top right bottom left);
		my $props = $self->kdl_properties( $kid, 'style', ( map {"style-$_"} @sides ), 'color' );

		foreach my $side (@sides) {
			my ($style_key) = grep { exists $props->{$_} } ( "style-$side", 'style' );    # the side key wins
			next unless defined $style_key;
			my $accessor = "border_style_$side";
			$self->$accessor( _border_style( $props->{$style_key} ) );
		}
		$self->border_color( [ Term::Fabulous::Color->new( color => $props->{color} )->to_rgba ] ) if exists $props->{color};
		return;
	}

	method _parse_sizing ($kid) {
		my $props  = $self->kdl_properties( $kid, qw(width height) );
		my %layout = %{ $self->layout };
		$layout{sizing} = { %{ $layout{sizing} // {} }, map { $_ => _sizing( $_, $props->{$_} ) } keys %$props };
		$self->layout( \%layout );
		return;
	}

	method _parse_padding ($kid) {
		my $props = $self->kdl_properties( $kid, qw(left right top bottom) );
		$self->layout( { %{ $self->layout }, padding => { map { $_ => _non_negative_integer( "padding $_", $props->{$_} ) } keys %$props } } );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Box - The general-purpose container widget

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_grow sizing_fit CLAY_TOP_TO_BOTTOM);

	my $card = Term::Fabulous::Widget::Box->new(
		id               => 'card',
		layout           => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_fit() },
			padding          => { left => 1, right => 1 },
			child_gap        => 1,
		},
		background_color => [ 30, 35, 50, 255 ],
		border_width     => 1,
		border_color     => [ 97, 175, 239, 255 ],
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
	);
	$card->add_child(
		Term::Fabulous::Widget::Text->new( text => 'Title',     text_color => [ 255, 255, 255, 255 ] ),
		Term::Fabulous::Widget::Text->new( text => 'Body text', text_color => [ 200, 205, 215, 255 ] ),
	);

=head1 DESCRIPTION

A Box is a rectangle that holds other widgets and arranges them in a
row or a column. It can have a background color and a border, and it
can receive events. Boxes are the building blocks of every screen:
nest them to divide the terminal into areas, then put
L<Term::Fabulous::Widget::Text> and the other widgets inside.

Box is the concrete form of L<Term::Fabulous::Widget>; most other
widgets (L<Term::Fabulous::Widget::Button>,
L<Term::Fabulous::Widget::ScrollBox>, L<Term::Fabulous::Widget::Canvas>,
the input widgets) are Boxes with extra behavior. A Box can also be
built from a KDL layout file (see L</KDL PROPERTIES>).

The SYNOPSIS above draws this (colors left out):

	+----------------------------+
	| Title                      |
	|                            |
	| Body text                  |
	+----------------------------+

with rounded corners. The border takes one cell on every side and the
padding one more cell left and right; see
L<Term::Fabulous::Role::HasBorderStyle/Border space>.

=head1 CONSTRUCTOR

=head2 new

	my $box = Term::Fabulous::Widget::Box->new(%parameters);

All parameters are optional; unknown parameters die. A Box accepts the
parameters common to all container widgets. Each is listed here with
its meaning in one sentence; L<Term::Fabulous::Widget/new> describes
the accepted values in full.

=over

=item C<id>

A string that names the widget and must be unique in the widget tree.
Default: C<undef> (no id).

=item C<layout>

A hash reference with the keys C<sizing>, C<padding>, C<child_gap>,
C<layout_direction> and C<child_alignment> that decides the size of
the box and how its children are arranged. Default: C<{}>, which fits
the box to its content and places the children from left to right.

=item C<background_color>

The color of the box's area, as C<[r, g, b, a]> or C<{ r, g, b, a }>.
Default: C<undef>, so the box is transparent.

=item C<border_width>

The border's width, a number for all sides or a hash reference with
C<left>, C<right>, C<top> and C<bottom>. Default: C<undef>, so there is
no border.

=item C<border_color>

The color of the border glyphs, as C<[r, g, b, a]> or C<{ r, g, b, a }>.
Default: C<undef>, which draws the border in the terminal's default
foreground color.

=item C<border_style>

A L<Term::Fabulous::Enum::BorderStyle> item that sets the style of all
four sides. Default: C<undef> (no border style; a side with a width is
then drawn with spaces).

=item C<border_style_top>

=item C<border_style_right>

=item C<border_style_bottom>

=item C<border_style_left>

A L<Term::Fabulous::Enum::BorderStyle> item that sets the style of one
side. Default: C<undef>. Ignored when C<border_style> is passed too.

=item C<width_group>

=item C<height_group>

A sizing group number that gives the box the same width (or height) as
the other widgets with that number. Default: 0, which means no group.

=item C<classes>

An array reference of free-form names, returned by
L<Term::Fabulous::Widget/get_classes>. Default: C<[]>.

=back

=head1 METHODS

A Box has all methods of L<Term::Fabulous::Widget>: children
(C<add_child>, C<remove_child>, C<children>, ...), events (C<on>,
C<fire_event>), the accessors C<layout>, C<background_color>,
C<border_color>, C<border_width>, C<border_style_top>,
C<border_style_right>, C<border_style_bottom>, C<border_style_left>,
C<width_group> and C<height_group>, and the state methods. It adds
nothing for applications; the methods in L</SUBCLASS INTERFACE> are for
widget authors.

=head1 EVENTS

A Box fires no events of its own. Events fired on its children bubble
up to it (see L<Term::Fabulous::Manual/EVENTS>), and
L<Term::Fabulous> fires C<KeyPress> on it when it is the root and
nothing has the focus, and C<Mouse> when it is the topmost widget
painted under the pointer. A Box receives C<Mouse> events only on the
cells it paints: its whole area when it has a background color, and
only its border cells when it has a border but no background. A Box
with neither is transparent to the mouse.

=head1 KDL PROPERTIES

A Box built by L<Term::Fabulous::Layout> reads these property nodes
from its block. Child nodes whose names start with an uppercase letter
are child widgets; everything else is a property. Unknown properties,
unknown keys and invalid values die, naming the property.

	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::Text as Text

	Box "card" {
		layout direction=down gap=1
		sizing width="fixed(30)" height=fit
		padding left=1 right=1
		border style=Round color="#61afef"
		border_width 1
		background_color "rgb(30, 35, 50)"

		Text { text "Title"; text_color "#ffffff"; }
		Text { text "Body text"; text_color "hsl(220, 15%, 80%)"; }
	}

=over

=item C<layout direction=... gap=N>

C<direction> is C<down> (aliases C<ttb>, C<top_to_bottom>) or C<right>
(aliases C<ltr>, C<left_to_right>). C<gap> (alias C<child_gap>; giving
both dies) is the number of cells between children, a non-negative
integer. Each key is optional, but at least one must be given: a bare
C<layout> node dies. Child alignment cannot be set from KDL.

=item C<sizing width=... height=...>

Each value is C<grow>, C<fit>, C<"fixed(N)"> with N a non-negative
integer number of cells, or C<"percent(N)"> with N a number from 0 to
100 (C<"percent(50)"> is half of the parent; note that Perl code uses a
fraction instead: C<sizing_percent(0.5)>). Values with parentheses
must be quoted. Either key may be left out. A second C<sizing> node
changes only the axes it names.

=item C<padding left=N right=N top=N bottom=N>

Any subset of the four sides; non-negative integers. A second
C<padding> node replaces the first completely: sides it leaves out
become 0.

=item C<border style=... style-top=... style-right=... style-bottom=... style-left=... color=...>

C<style> sets all four sides, C<style-top> and the other side keys
override it for one side. Values are the names of
L<Term::Fabulous::Enum::BorderStyle> items (C<Round>, C<Solid>,
C<Double>, ...). C<color> takes any color string that
L<Term::Fabulous::Color> understands (C<"#61afef">,
C<"rgb(97, 175, 239)">, C<"hsl(207, 82%, 66%)">, ...). This property
does not make a border appear: also give C<border_width>.

=item C<border_width N> or C<border_width left=N right=N top=N bottom=N>

The border width, for all sides or per side.

=item C<background_color "...">

=item C<border_color "...">

Any L<Term::Fabulous::Color> string.

=item C<width_group N>

=item C<height_group N>

Sizing group numbers, see L<Term::Fabulous::Widget/width_group>.

=back

=head1 SUBCLASS INTERFACE

These methods are for authors of widget classes that should be
buildable from KDL layouts. See also
L<Term::Fabulous::Role::CanParseLayout>.

=head2 parse_property

	method parse_property :override ($kid) {
		return $self->_parse_options($kid) if $kid->name eq 'options';
		return $self->SUPER::parse_property($kid);
	}

Called once for every child node of the widget's KDL node, in the order
they appear, with the L<Text::KDL::XS::Node>. Box handles C<layout>,
C<sizing>, C<padding> and C<border> itself and passes every other node
to L<Term::Fabulous::Role::CanParseLayout/parse_generic>, which sets
the properties listed by L</layout_properties> and skips child widget
nodes. Override it to parse structured properties of your own, and
call C<SUPER::parse_property> for everything else.

=head2 parse_node

	$box->parse_node($node);

Calls L</parse_property> for every child node of C<$node>. Called
during construction when the widget is built from a layout; you
normally do not call or override it.

=head2 layout_properties

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(title) );
	}

The names of the accessors a layout may set with a simple
C<name value> property: C<background_color>, C<border_color>,
C<border_width>, C<width_group> and C<height_group> for a Box.
Subclasses extend the list as shown. See
L<Term::Fabulous::Role::CanParseLayout/layout_properties>.

=head1 SEE ALSO

L<Term::Fabulous::Widget> for the common parameters and methods,
L<Term::Fabulous::Manual/LAYOUT>, L<Term::Fabulous::Layout>,
L<Term::Fabulous::Role::HasBorderStyle>.

=cut
