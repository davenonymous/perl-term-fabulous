package Term::Fabulous::Widget::Box;

use v5.24;
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
	use Clay::XS qw(
		Clay_GetElementId sizing_fit sizing_fixed sizing_grow sizing_percent CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM
		CLAY_LEFT_TO_RIGHT_WRAP CLAY_BACK_TO_FRONT CLAY_LINE_SIZING_GROW CLAY_LINE_SIZING_FIT
		CLAY_ALIGN_X_LEFT CLAY_ALIGN_X_CENTER CLAY_ALIGN_X_RIGHT CLAY_ALIGN_Y_TOP CLAY_ALIGN_Y_CENTER CLAY_ALIGN_Y_BOTTOM
		CLAY_ATTACH_TO_PARENT CLAY_ATTACH_TO_ROOT CLAY_ATTACH_TO_ELEMENT_WITH_ID
		CLAY_ATTACH_POINT_LEFT_TOP CLAY_ATTACH_POINT_LEFT_CENTER CLAY_ATTACH_POINT_LEFT_BOTTOM
		CLAY_ATTACH_POINT_CENTER_TOP CLAY_ATTACH_POINT_CENTER_CENTER CLAY_ATTACH_POINT_CENTER_BOTTOM
		CLAY_ATTACH_POINT_RIGHT_TOP CLAY_ATTACH_POINT_RIGHT_CENTER CLAY_ATTACH_POINT_RIGHT_BOTTOM
		CLAY_POINTER_CAPTURE_MODE_CAPTURE CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH
		CLAY_CLIP_TO_NONE CLAY_CLIP_TO_ATTACHED_PARENT
	);
	use Term::Fabulous::Enum::BorderStyle;

	my %DIRECTION_BY_NAME = (
		top_to_bottom      => CLAY_TOP_TO_BOTTOM,
		ttb                => CLAY_TOP_TO_BOTTOM,
		down               => CLAY_TOP_TO_BOTTOM,
		left_to_right      => CLAY_LEFT_TO_RIGHT,
		ltr                => CLAY_LEFT_TO_RIGHT,
		right              => CLAY_LEFT_TO_RIGHT,
		wrap               => CLAY_LEFT_TO_RIGHT_WRAP,
		ltr_wrap           => CLAY_LEFT_TO_RIGHT_WRAP,
		left_to_right_wrap => CLAY_LEFT_TO_RIGHT_WRAP,
		stack              => CLAY_BACK_TO_FRONT,
		back_to_front      => CLAY_BACK_TO_FRONT,
		btf                => CLAY_BACK_TO_FRONT,
	);

	my %LINE_SIZING_BY_NAME = ( grow => CLAY_LINE_SIZING_GROW, fit => CLAY_LINE_SIZING_FIT );

	my $DECIMAL = qr/(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)/;

	my %SIZING_WITH_LIMITS = ( grow => \&sizing_grow, fit => \&sizing_fit );

	my %ALIGN_X_BY_NAME = ( left => CLAY_ALIGN_X_LEFT, center => CLAY_ALIGN_X_CENTER, right  => CLAY_ALIGN_X_RIGHT );
	my %ALIGN_Y_BY_NAME = ( top  => CLAY_ALIGN_Y_TOP,  center => CLAY_ALIGN_Y_CENTER, bottom => CLAY_ALIGN_Y_BOTTOM );

	my %ATTACH_TO_BY_NAME = (
		parent  => CLAY_ATTACH_TO_PARENT,
		root    => CLAY_ATTACH_TO_ROOT,
		element => CLAY_ATTACH_TO_ELEMENT_WITH_ID,
	);

	my %ATTACH_POINT_BY_NAME = (
		left_top      => CLAY_ATTACH_POINT_LEFT_TOP,
		left_center   => CLAY_ATTACH_POINT_LEFT_CENTER,
		left_bottom   => CLAY_ATTACH_POINT_LEFT_BOTTOM,
		center_top    => CLAY_ATTACH_POINT_CENTER_TOP,
		center_center => CLAY_ATTACH_POINT_CENTER_CENTER,
		center_bottom => CLAY_ATTACH_POINT_CENTER_BOTTOM,
		right_top     => CLAY_ATTACH_POINT_RIGHT_TOP,
		right_center  => CLAY_ATTACH_POINT_RIGHT_CENTER,
		right_bottom  => CLAY_ATTACH_POINT_RIGHT_BOTTOM,
	);

	my %POINTER_CAPTURE_BY_NAME = ( capture => CLAY_POINTER_CAPTURE_MODE_CAPTURE, passthrough => CLAY_POINTER_CAPTURE_MODE_PASSTHROUGH );
	my %CLIP_TO_BY_NAME         = ( none => CLAY_CLIP_TO_NONE, attached_parent => CLAY_CLIP_TO_ATTACHED_PARENT );

	# Each key of a floating node: where its value goes in the
	# Clay_FloatingElementConfig hash (a key, or a key and a subkey), and
	# how the KDL value is parsed.
	my %FLOATING_KEY = (
		attach_to       => [ ['attach_to'],                  sub ($value) { _named( 'floating attach_to', \%ATTACH_TO_BY_NAME, $value ) } ],
		parent_id       => [ ['parent_id'],                  sub ($value) { _element_id( 'floating parent_id', $value ) } ],
		element         => [ [ attach_points => 'element' ], sub ($value) { _named( 'floating element', \%ATTACH_POINT_BY_NAME, $value ) } ],
		parent          => [ [ attach_points => 'parent' ],  sub ($value) { _named( 'floating parent', \%ATTACH_POINT_BY_NAME, $value ) } ],
		offset_x        => [ [ offset => 'x' ],              sub ($value) { _integer( 'floating offset_x', $value ) } ],
		offset_y        => [ [ offset => 'y' ],              sub ($value) { _integer( 'floating offset_y', $value ) } ],
		z_index         => [ ['z_index'],                    sub ($value) { _integer( 'floating z_index', $value ) } ],
		pointer_capture => [ ['pointer_capture_mode'],       sub ($value) { _named( 'floating pointer_capture', \%POINTER_CAPTURE_BY_NAME, $value ) } ],
		clip_to         => [ ['clip_to'],                    sub ($value) { _named( 'floating clip_to', \%CLIP_TO_BY_NAME, $value ) } ],
	);

	sub _describe ($value) {
		return defined $value ? "'$value'" : 'null';
	}

	sub _non_negative_integer ( $what, $value ) {
		die "Term::Fabulous::Widget::Box: $what must be a non-negative integer, got " . _describe($value)
			unless defined $value && $value =~ /\A[0-9]+\z/;
		return $value + 0;
	}

	sub _integer ( $what, $value ) {
		die "Term::Fabulous::Widget::Box: $what must be an integer, got " . _describe($value)
			unless defined $value && $value =~ /\A-?[0-9]+\z/;
		return $value + 0;
	}

	# The value a name stands for in %$value_by_name; an unknown name dies
	# with the known ones.
	sub _named ( $what, $value_by_name, $name ) {
		return $value_by_name->{$name} if defined $name && exists $value_by_name->{$name};
		die "Term::Fabulous::Widget::Box: invalid $what " . _describe($name) . " (known: " . join( ', ', sort keys %$value_by_name ) . ")";
	}

	# The Clay element id number of the widget with the id $id, hashed the
	# way Clay::UI hashes widget ids.
	sub _element_id ( $what, $id ) {
		die "Term::Fabulous::Widget::Box: $what must be a widget id, got " . _describe($id) unless defined $id && length $id;
		return Clay_GetElementId($id)->{id};
	}

	sub _sizing ( $axis, $spec ) {
		$spec //= '';
		return sizing_grow() if $spec eq 'grow';
		return sizing_fit()  if $spec eq 'fit';
		if ( my ( $kind, $min, $max ) = $spec =~ /\A(grow|fit)\(\s*([0-9]+)\s*(?:,\s*([0-9]+)\s*)?\)\z/ ) {
			die "Term::Fabulous::Widget::Box: sizing $axis minimum $min is greater than maximum $max in '$spec'" if defined $max && $min > $max;
			return $SIZING_WITH_LIMITS{$kind}->( $min + 0, defined $max ? $max + 0 : undef );
		}
		if ( my ($percent) = $spec =~ /\Apercent\(\s*($DECIMAL)\s*\)\z/ ) {
			die "Term::Fabulous::Widget::Box: sizing $axis percentage must be in 0..100, got '$spec'" if $percent > 100;
			return sizing_percent( $percent / 100 );
		}
		if ( my ($cells) = $spec =~ /\Afixed\(\s*([0-9]+)\s*\)\z/ ) {
			return sizing_fixed( $cells + 0 );
		}
		die "Term::Fabulous::Widget::Box: invalid sizing $axis '$spec' (expected grow, fit, grow(MIN), grow(MIN, MAX), fit(MIN), fit(MIN, MAX), percent(0..100) or fixed(N))";
	}

	sub _border_style ($name) {
		return Term::Fabulous::Enum::BorderStyle->from_name( $name // '' )
			// die "Term::Fabulous::Widget::Box: invalid border style " . _describe($name) . " (known: "
			. join( ', ', map { $_->name } Term::Fabulous::Enum::BorderStyle->values ) . ")";
	}

	method layout_properties () {
		return qw(background_color glyphs_show_through border_color border_width width_group height_group);
	}

	method boolean_layout_properties () {
		return qw(glyphs_show_through);
	}

	method structured_layout_properties () {
		return qw(layout border sizing padding child_alignment floating);
	}

	method parse_node ($node) {
		$self->parse_property($_) foreach $node->children->@*;
		return;
	}

	method parse_property ($kid) {
		my $name = $kid->name;
		if    ( $name eq 'layout' )          { $self->_parse_layout($kid) }
		elsif ( $name eq 'border' )          { $self->_parse_border($kid) }
		elsif ( $name eq 'sizing' )          { $self->_parse_sizing($kid) }
		elsif ( $name eq 'padding' )         { $self->_parse_padding($kid) }
		elsif ( $name eq 'child_alignment' ) { $self->_parse_child_alignment($kid) }
		elsif ( $name eq 'floating' )        { $self->_parse_floating($kid) }
		else                                 { $self->parse_generic($kid) }
		return;
	}

	method _parse_layout ($kid) {
		my $props = $self->kdl_properties( $kid, qw(direction child_gap gap line_gap line_sizing) );
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
		$layout{line_gap}    = _non_negative_integer( 'layout line_gap', $props->{line_gap} ) if exists $props->{line_gap};
		$layout{line_sizing} = _named( 'layout line_sizing', \%LINE_SIZING_BY_NAME, $props->{line_sizing} ) if exists $props->{line_sizing};
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
		$self->border_color( $props->{color} ) if exists $props->{color};
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
		my $props  = $self->kdl_properties( $kid, qw(left right top bottom) );
		my %layout = %{ $self->layout };
		$layout{padding} = { %{ $layout{padding} // {} }, map { $_ => _non_negative_integer( "padding $_", $props->{$_} ) } keys %$props };
		$self->layout( \%layout );
		return;
	}

	method _parse_child_alignment ($kid) {
		my $props            = $self->kdl_properties( $kid, qw(x y) );
		my %alignment_by_key = ( x => \%ALIGN_X_BY_NAME, y => \%ALIGN_Y_BY_NAME );
		my %layout           = %{ $self->layout };
		$layout{child_alignment} = { %{ $layout{child_alignment} // {} }, map { $_ => _named( "child_alignment $_", $alignment_by_key{$_}, $props->{$_} ) } keys %$props };
		$self->layout( \%layout );
		return;
	}

	method _parse_floating ($kid) {
		my $props    = $self->kdl_properties( $kid, qw(attach_to parent_id element parent offset_x offset_y z_index pointer_capture clip_to) );
		my %floating = %{ $self->floating // {} };
		foreach my $key ( sort keys %$props ) {
			my ( $slot, $parse ) = $FLOATING_KEY{$key}->@*;
			my ( $field, $subfield ) = @$slot;
			my $value = $parse->( $props->{$key} );
			$floating{$field} = defined $subfield ? { %{ $floating{$field} // {} }, $subfield => $value } : $value;
		}
		$floating{attach_to} //= CLAY_ATTACH_TO_PARENT;    # a floating node means "float"
		die "Term::Fabulous::Widget::Box: floating attach_to=element needs parent_id"
			if ( $floating{attach_to} // -1 ) == CLAY_ATTACH_TO_ELEMENT_WITH_ID && !defined $floating{parent_id};
		$self->floating( \%floating );
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

=begin html

<p><img src="/screenshots/widget-box.svg" alt="A card with a title and body text, and three boxes labeled fit, grow and fixed(14)"></p>

=end html

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
C<layout_direction>, C<child_alignment>, C<line_gap> and
C<line_sizing> that decides the size of
the box and how its children are arranged. Default: C<{}>, which fits
the box to its content and places the children from left to right.

=item C<floating>

A hash reference that takes the box out of its parent's layout and
draws it on top of other widgets, attached to its parent, the root or
another widget. Default: C<undef> (the box is laid out normally).

=item C<background_color>

The color of the box's area, in any format L<Term::Fabulous::Color>
accepts (C<[r, g, b, a]>, C<{ r, g, b, a }>, a string such as
C<'#14192b'>, a Color object). Default: C<undef>, so the box is
transparent.

=item C<border_width>

The border's width, a number for all sides or a hash reference with
C<left>, C<right>, C<top> and C<bottom>. Default: C<undef>, so there is
no border.

=item C<border_color>

The color of the border glyphs, in the same formats as
C<background_color>. Default: C<undef>, which draws the border in the
terminal's default foreground color.

=item C<border_style>

A L<Term::Fabulous::Enum::BorderStyle> item that sets the style of
every side that has no side parameter of its own. Default: C<undef> (no
border style; a side with a width is then drawn with spaces).

=item C<border_style_top>

=item C<border_style_right>

=item C<border_style_bottom>

=item C<border_style_left>

A L<Term::Fabulous::Enum::BorderStyle> item that sets the style of one
side. Default: C<undef>. It wins over C<border_style> for that side.

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
C<fire_event>), the search L<Term::Fabulous::Widget/find_by_id>, the
accessors C<layout>, C<floating>, C<background_color>,
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
		sizing width="fixed(30)" height="fit(3, 10)"
		padding left=1 right=1
		child_alignment x=center
		border style=Round color="#61afef"
		border_width 1
		background_color "rgb(30, 35, 50)"

		Text { text "Title"; text_color "#ffffff"; }
		Text { text "Body text"; text_color "hsl(220, 15%, 80%)"; }
	}

=over

=item C<layout direction=... gap=N line_gap=N line_sizing=...>

C<direction> is C<down> (aliases C<ttb>, C<top_to_bottom>), C<right>
(aliases C<ltr>, C<left_to_right>), C<wrap> (aliases C<ltr_wrap>,
C<left_to_right_wrap>; see L<Term::Fabulous::Manual/Flow layout>) or
C<stack> (aliases C<back_to_front>, C<btf>; see
L<Term::Fabulous::Manual/Stack layout>).
C<gap> (alias C<child_gap>; giving both dies) is the number of cells
between children, a non-negative integer. C<line_gap> is the number of
rows between the lines of a C<wrap> box, a non-negative integer.
C<line_sizing> is C<grow> (the default) or C<fit> and decides what a
C<wrap> box taller than its lines does with the leftover rows. Each key
is optional, but at least one must be given: a bare C<layout> node
dies.

=item C<sizing width=... height=...>

Each value is C<grow>, C<fit>, C<"grow(MIN)">, C<"grow(MIN, MAX)">,
C<"fit(MIN)">, C<"fit(MIN, MAX)">, C<"fixed(N)"> with N a non-negative
integer number of cells, or C<"percent(N)"> with N a number from 0 to
100 (C<"percent(50)"> is half of the parent; note that Perl code uses a
fraction instead: C<sizing_percent(0.5)>). MIN and MAX are
non-negative integer numbers of cells, the limits of
C<sizing_grow($min, $max)> and C<sizing_fit($min, $max)>; without MAX
there is no maximum, and a MIN greater than MAX dies. Values with
parentheses must be quoted. Either key may be left out. A second
C<sizing> node changes only the axes it names.

=item C<child_alignment x=... y=...>

Where the children are placed when they do not fill the box: C<x> is
C<left> (the default), C<center> or C<right>, C<y> is C<top> (the
default), C<center> or C<bottom>. Either key may be left out, but at
least one must be given. A second C<child_alignment> node changes only
the key it names. An unknown name dies with the known ones.

=item C<floating attach_to=... parent_id=... element=... parent=... offset_x=N offset_y=N z_index=N pointer_capture=... clip_to=...>

Sets the C<floating> hash (see L<Term::Fabulous::Widget/floating>).
Each key is optional, but at least one must be given:

=over

=item C<attach_to>

C<parent> (the default), C<root> or C<element>. C<element> requires
C<parent_id>.

=item C<parent_id>

The id of the widget to attach to with C<attach_to=element>, a string.

=item C<element>

=item C<parent>

The point of this box (C<element>) that is placed on the point of the
widget it is attached to (C<parent>): C<left_top> (the default),
C<left_center>, C<left_bottom>, C<center_top>, C<center_center>,
C<center_bottom>, C<right_top>, C<right_center> or C<right_bottom>.

=item C<offset_x>

=item C<offset_y>

Integers added to the position, in cells; negative values move left
and up.

=item C<z_index>

An integer from -32768 to 32767; floating widgets with a higher value
are drawn on top.

=item C<pointer_capture>

C<capture> (the default) or C<passthrough>.

=item C<clip_to>

C<none> (the default) or C<attached_parent>.

=back

A second C<floating> node changes only the keys it names. An unknown
name dies with the known ones.

	Box "menu" {
		floating attach_to=element parent_id="menu-button" element=left_top parent=left_bottom
		floating z_index=10
		border style=Round
		border_width 1
	}

=item C<padding left=N right=N top=N bottom=N>

Any subset of the four sides; non-negative integers. A second
C<padding> node changes only the sides it names, like C<sizing>.

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
C<sizing>, C<padding>, C<border>, C<child_alignment> and C<floating>
itself and passes every other node
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
C<name value> property: C<background_color>, C<glyphs_show_through>,
C<border_color>, C<border_width>, C<width_group> and C<height_group>
for a Box. Subclasses extend the list as shown. See
L<Term::Fabulous::Role::CanParseLayout/layout_properties>.

=head2 boolean_layout_properties

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, qw(collapsed) );
	}

The names of the boolean properties among L</layout_properties>; a
layout must write them as C<#true> or C<#false> (or C<0> and C<1>).
C<glyphs_show_through> for a Box. Subclasses extend the list as shown.

=head2 structured_layout_properties

	method structured_layout_properties :override () {
		return ( $self->SUPER::structured_layout_properties, qw(shortcut) );
	}

The names of the properties L</parse_property> handles itself:
C<layout>, C<border>, C<sizing>, C<padding>, C<child_alignment> and
C<floating> for a Box. They are
listed as known names in the error for an unknown property. A subclass
that handles more nodes in C<parse_property> extends the list as
shown.

=head1 SEE ALSO

L<Term::Fabulous::Widget> for the common parameters and methods,
L<Term::Fabulous::Manual/LAYOUT>, L<Term::Fabulous::Layout>,
L<Term::Fabulous::Role::HasBorderStyle>.

=cut
