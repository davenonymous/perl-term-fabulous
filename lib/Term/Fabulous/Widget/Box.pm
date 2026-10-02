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
		return qw(background_color border_color border_width width_group height_group);
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

Term::Fabulous::Widget::Box - Container widget

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Enum::BorderStyle;
	use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);

	my $box = Term::Fabulous::Widget::Box->new(
		layout           => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() } },
		background_color => [35, 40, 55, 255],
		border_color     => [180, 200, 220, 255],
		border_width     => 1,
		border_style     => Term::Fabulous::Enum::BorderStyle->Round,
	);
	$box->add_child($child);

=head1 DESCRIPTION

The concrete container of L<Term::Fabulous::Widget>: layout, background,
border (see L<Term::Fabulous::Role::HasBorderStyle> for how borders take
space), children and events. Unknown constructor parameters die.

=head1 KDL PROPERTIES

When built by L<Term::Fabulous::Layout>, a Box accepts these property
nodes; unknown nodes or keys die.

=over

=item C<layout direction=... child_gap=N>

C<direction> is one of C<down>, C<ttb>, C<top_to_bottom>, C<right>,
C<ltr>, C<left_to_right>. C<gap> is an alias of C<child_gap>; giving
both dies. The gap is a non-negative integer.

=item C<sizing width=... height=...>

Each is C<grow>, C<fit>, C<percent(N)> with N in 0..100 (decimals
allowed; C<percent(50)> is half the parent) or C<fixed(N)> with N a
non-negative integer.

=item C<padding left=N right=N top=N bottom=N>

Any subset; non-negative integers.

=item C<border style=... style-top=... style-right=... style-bottom=... style-left=... color=...>

Styles are L<Term::Fabulous::Enum::BorderStyle> item names (C<Round>,
C<Solid>, ...); C<style> sets all four sides and the side keys override
it. C<color> takes any L<Term::Fabulous::Color> string.

=item C<background_color>, C<border_color>, C<border_width>, C<width_group>, C<height_group>

Set through L<Term::Fabulous::Role::CanParseLayout/parse_generic>. Colors
take any L<Term::Fabulous::Color> string; C<border_width> takes a number
or C<left=N right=N top=N bottom=N>.

=back

=head1 SUBCLASS INTERFACE

=head2 parse_property

	method parse_property :override ($kid) {
		return $self->_parse_options($kid) if $kid->name eq 'options';
		return $self->SUPER::parse_property($kid);
	}

Called by C<parse_node> for every child node of the widget's KDL node,
property nodes and child widget nodes alike. Handles the properties
above and hands everything else to
L<Term::Fabulous::Role::CanParseLayout/parse_generic>. Subclasses
override it to parse structured properties of their own.

=cut
