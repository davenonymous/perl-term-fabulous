package Term::Fabulous::Role::HasBorderStyle;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;
use Object::Pad::FieldAttr::Checked;
use Data::Checks qw(Isa Maybe);

role Term::Fabulous::Role::HasBorderStyle {
	use Scalar::Util qw(blessed refaddr);
	use Term::Fabulous::Check qw(glyph);
	use Term::Fabulous::Enum::BorderStyle;

	my @SIDES = qw(left right top bottom);

	field $border_style_top    :param :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_right  :param :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_bottom :param :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_style_left   :param :Checked( Maybe( Isa('Term::Fabulous::Enum::BorderStyle') ) ) = undef;
	field $border_corners      :param = undef;
	field $outer_border_sides  :param = [];

	my @CORNERS = qw(top_left top_right bottom_left bottom_right);

	ADJUST {
		$border_corners     = _corner_glyphs( $self, $border_corners );
		$outer_border_sides = _side_names( $self, $outer_border_sides );
	}

	# A copy of a list of side names, each at most once, in @SIDES order.
	sub _side_names ( $owner, $sides ) {
		die ref($owner) . ": outer_border_sides must be an array reference of side names, got " . ( defined $sides ? ( ref $sides ? ref($sides) . ' reference' : "'$sides'" ) : 'undef' )
			unless ref $sides eq 'ARRAY';
		my %is_side = map { $_ => 1 } @SIDES;
		my @unknown = grep { !defined || ref || !$is_side{$_} } @$sides;
		die ref($owner) . ": outer_border_sides knows only the sides @SIDES, got " . join( ', ', map { defined $_ ? "'$_'" : 'undef' } @unknown ) if @unknown;
		my %wanted = map { $_ => 1 } @$sides;
		return [ grep { $wanted{$_} } @SIDES ];
	}

	method outer_border_sides (@new) {
		return [@$outer_border_sides] unless @new;
		$outer_border_sides = _side_names( $self, $new[0] );
		$self->mark_changed;
		return [@$outer_border_sides];
	}

	# Whether a side is drawn on the background outside the widget. Read by
	# Term::Fabulous::Render::Border.
	method is_outer_border_side ($side) {
		return ( grep { $_ eq $side } @$outer_border_sides ) ? 1 : 0;
	}

	# border_style fills the sides that have no style of their own.
	ADJUST :params ( :$border_style = undef ) {
		if ( defined $border_style ) {
			die "Term::Fabulous::Role::HasBorderStyle: border_style must be a Term::Fabulous::Enum::BorderStyle, got "
				. ( ref $border_style || "'$border_style'" )
				unless blessed $border_style && $border_style->isa('Term::Fabulous::Enum::BorderStyle');

			foreach my $side (@SIDES) {
				my $accessor = "border_style_$side";
				$self->$accessor($border_style) unless defined $self->$accessor;
			}
		}
	}

	# Hand-written accessors rather than :accessor ones, so that writing a
	# style marks the widget changed.
	method border_style_top (@new)    { return $self->_set_border_style( top    => \$border_style_top,    @new ) }
	method border_style_right (@new)  { return $self->_set_border_style( right  => \$border_style_right,  @new ) }
	method border_style_bottom (@new) { return $self->_set_border_style( bottom => \$border_style_bottom, @new ) }
	method border_style_left (@new)   { return $self->_set_border_style( left   => \$border_style_left,   @new ) }

	method _set_border_style ( $side, $field_ref, @new ) {
		return $$field_ref unless @new;
		my ($style) = @new;
		die "Term::Fabulous::Role::HasBorderStyle: border_style_$side must be undef or a Term::Fabulous::Enum::BorderStyle, got " . ( ref $style || "'$style'" )
			if defined $style && !( blessed $style && $style->isa('Term::Fabulous::Enum::BorderStyle') );
		$$field_ref = $style;
		$self->mark_changed;
		return $$field_ref;
	}

	# A copy of a corner glyph hash: undef, or a hash of single glyphs one
	# column wide under the names in @CORNERS.
	sub _corner_glyphs ( $owner, $corners ) {
		return undef unless defined $corners;
		die ref($owner) . ": border_corners must be undef or a hash reference of corner glyphs, got " . ( ref $corners ? ref($corners) . ' reference' : "'$corners'" )
			unless ref $corners eq 'HASH';
		my %is_corner = map { $_ => 1 } @CORNERS;
		my @unknown   = grep { !$is_corner{$_} } sort keys %$corners;
		die ref($owner) . ": border_corners does not know @unknown (known: @CORNERS)" if @unknown;
		return { map { $_ => glyph( $owner, "border_corners $_", $corners->{$_} ) } grep { defined $corners->{$_} } sort keys %$corners };
	}

	method border_corners (@new) {
		return defined $border_corners ? { %$border_corners } : undef unless @new;
		$border_corners = _corner_glyphs( $self, $new[0] );
		$self->mark_changed;
		return defined $border_corners ? { %$border_corners } : undef;
	}

	# The glyph drawn at a corner instead of the style's corner glyph, or
	# undef. Read by Term::Fabulous::Render::Border.
	method border_corner_glyph ($corner) {
		return defined $border_corners ? $border_corners->{$corner} : undef;
	}

	# The sides whose style is Hidden; they take no space and draw nothing.
	method _hidden_border_sides () {
		my $hidden = Term::Fabulous::Enum::BorderStyle->Hidden;
		return grep {
			my $style = $self->${ \"border_style_$_" };
			defined $style && refaddr($style) == refaddr($hidden);
		} @SIDES;
	}

	# Per-side widths of a Clay border_width (a number for all sides, or a
	# hashref), with the given sides counted as 0; undef when no side has a
	# width. Clay::UI's HasBorder has already validated the value when it
	# was set.
	sub _border_insets ( $border_width, @zero_sides ) {
		return undef unless defined $border_width;

		my %width_by_side = ref $border_width ? %$border_width : map { $_ => $border_width } @SIDES;
		delete @width_by_side{@zero_sides};
		my %inset = map { $_ => $width_by_side{$_} // 0 } @SIDES;

		return ( grep { $_ > 0 } values %inset ) ? \%inset : undef;
	}

	# Hidden sides keep their border_width but get a Clay width of 0, so the
	# renderer draws nothing there. Clay::UI runs contribute_* methods in
	# alphabetical order, so the name sorts right after contribute_border,
	# which wrote the border slice. Writes fresh hashes, so the widget's own
	# border_width is never modified.
	method contribute_border_hidden ($config) {
		my $border = $config->{border};
		return unless defined $border && ref $border->{width} eq 'HASH';

		my @hidden_sides = $self->_hidden_border_sides;
		return unless @hidden_sides;

		$config->{border} = {
			%$border,
			width => { %{ $border->{width} }, map { $_ => 0 } @hidden_sides },
		};
		return;
	}

	# Clay draws borders over the content box, so the border width is added
	# to the padding: borders occupy cells inside the widget and the user's
	# padding starts after them. Hidden sides take no space. Clay::UI runs
	# contribute_* methods in alphabetical order, so the name sorts after
	# contribute_layout; that way the inset is applied to the final layout
	# slice. Writes fresh hashes, so the widget's own layout is never
	# modified.
	method contribute_layout_inset ($config) {
		return unless $self->can('border_width') && $self->can('layout');

		my $insets = _border_insets( $self->border_width, $self->_hidden_border_sides );
		return unless defined $insets;

		my $layout  = $config->{layout} // {};
		my $padding = $layout->{padding} // {};
		die "Term::Fabulous::Role::HasBorderStyle: layout padding must be a hash reference"
			unless ref $padding eq 'HASH';

		$config->{layout} = {
			%$layout,
			padding => { %$padding, map { $_ => ( $padding->{$_} // 0 ) + $insets->{$_} } @SIDES },
		};
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Role::HasBorderStyle - Border glyphs per side, and
borders that take space

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Enum::BorderStyle;

	my $box = Term::Fabulous::Widget::Box->new(
		border_width => 1,
		border_color => [ 180, 200, 220, 255 ],
		border_style => Term::Fabulous::Enum::BorderStyle->Round,    # all four sides
		layout       => { padding => { left => 1, right => 1 } },    # inside the border
	);

	# Change one side later:
	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Double );

=head1 DESCRIPTION

This role is part of every L<Term::Fabulous::Widget> (and therefore of
every Box, Button, ScrollBox, Canvas and input widget). It does two
things:

=over

=item 1.

It adds the border style parameters and accessors, which choose the
characters a border is drawn with (Clay itself only knows border
widths and colors).

=item 2.

It makes borders take space in the layout, so that the content never
overlaps them.

=back

You do not compose this role yourself; it is already part of the
widget classes. To draw a border, a widget needs a C<border_width>
(from L<Clay::UI::Role::Style::HasBorder>) and normally a border style
and a C<border_color>:

	border_width => 1,
	border_style => Term::Fabulous::Enum::BorderStyle->Round,
	border_color => [ 180, 200, 220, 255 ],

L<The borders section of the looks guide|Term::Fabulous::Manual::Looks/BORDERS>
explains borders with examples. F<examples/border-options.pl> shows per-side styles, a wider
border, a C<Hidden> side, C<border_corners> and
C<outer_border_sides>:

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.01/screenshots/example-border-options.svg" alt="Six bordered panels: a border on the left and top only; a solid border with a double top and a thick left side; a round border of width 2 with an empty cell inside; a round border with a hidden bottom side; a title box and a body box sharing one line; a round border drawn on the parent's background"></p>

=end html

=head2 How a border is drawn

=over

=item * A side is drawn when its border width is greater than 0 and its
style is not C<Hidden>. It is always one cell thick, whatever the
width; see L</Border space> for what a larger width does.

=item * A side with the C<Hidden> style is switched off: it draws
nothing and takes no space, whatever its border width. Use it to turn
one side off without changing C<border_width>.

=item * The top and bottom sides are drawn over the whole width of the
widget and own the corners: a corner glyph appears where the top or
bottom row meets a drawn left or right side, taken from the style of
the top or bottom side. The left and right sides fill the rows between.

=item * A side that has a width but no style is drawn with the C<Blank>
style, that is with spaces.

=item * C<border_corners> replaces the glyph of any corner, for example
to join the box to lines around it (C<\x{251C}> instead of
C<\x{250C}> where a line comes in from above). The corner keeps the
colors its style gives it.

=item * C<outer_border_sides> draws some sides on the background
outside the widget instead of its own (see below).

=item * The glyphs have the C<border_color> (the terminal's default
foreground color when none is set). Their background is usually the
widget's background; some styles, such as C<Block>, C<Inner>, C<Panel>
or C<Wide>, use the background outside the widget or reverse video for
some glyphs so that they blend with the surroundings. See
L<Term::Fabulous::Enum::BorderStyle> for the styles.

=back

=head2 Border space

Clay, the layout engine, would draw borders on top of the content. This
role prevents that: when a widget has a C<border_width>, the width of
every side whose style is not C<Hidden> is added to that side's padding
before Clay lays the widget out. The effect is:

=over

=item * The content starts inside the border, and the C<padding> in the
widget's C<layout> is extra space between the border and the content.
In the SYNOPSIS, a child of the box starts two cells right of the left
edge: one for the border, one for the padding.

=item * A width larger than 1 still draws a one-cell border, followed
by empty cells: C<border_width => 2> is a border plus one cell of
padding.

=item * A widget with C<fit> sizing grows by the border.

=item * A C<Hidden> side adds no padding, so the content reaches that
edge of the widget.

=back

C<border_width> is a number for all four sides, or a hash reference
C<< { left => ..., right => ..., top => ..., bottom => ... } >> in which
missing sides count as 0. Each width must be an integer from 0 to 65535
(checked by Clay::UI when it is set). Clay's C<between_children> key
is not supported. The widget's stored C<layout> is
not modified; only the configuration handed to Clay is.

=head1 CONSTRUCTOR PARAMETERS

These parameters are accepted by the C<new> of every widget class that
composes the role. Unknown values die.

=over

=item C<border_style>

A L<Term::Fabulous::Enum::BorderStyle> item, for example
C<< Term::Fabulous::Enum::BorderStyle->Round >>; it sets the style of
every side that has no side parameter of its own. Default: none.
Anything else, including the name of a style as a string, dies. To use
a name, convert it:
C<< Term::Fabulous::Enum::BorderStyle->from_name('Round') >>.

=item C<border_style_top>

=item C<border_style_right>

=item C<border_style_bottom>

=item C<border_style_left>

C<undef> or a L<Term::Fabulous::Enum::BorderStyle> item for one side.
Default: C<undef>. A side parameter wins over C<border_style>:

	border_style      => Term::Fabulous::Enum::BorderStyle->Solid,
	border_style_left => Term::Fabulous::Enum::BorderStyle->Thick,

gives a thick left side and solid other sides, like
C<border style=Solid style-left=Thick> in a KDL layout file. The side
accessors change one side after construction.

=item C<border_corners>

C<undef> (the default) or a hash reference with any of the keys
C<top_left>, C<top_right>, C<bottom_left> and C<bottom_right>, each a
single character one column wide. A corner named here is drawn with
that glyph instead of the corner glyph of its style; the others keep
theirs. Only corners that are drawn at all are affected (a corner is
drawn where a drawn top or bottom side meets a drawn left or right
side). The colors stay those of the style's corner. Unknown keys and
other glyphs die. L<Term::Fabulous::Widget::Table> uses it to join the
lines of its cells, with the glyphs from
L<Term::Fabulous::Enum::BorderStyle/junction>.

	border_style   => Term::Fabulous::Enum::BorderStyle->Solid,
	border_corners => { top_left => "\x{251C}", bottom_left => "\x{251C}" },

=item C<outer_border_sides>

An array reference of side names (C<top>, C<right>, C<bottom>,
C<left>). Default: C<[]>. The glyphs of these sides are drawn on the
background just outside the widget (what is painted there, usually the
parent's background) instead of the widget's own: the border looks like
part of its surroundings, and a colored widget starts inside it. The
glyphs of a style that already uses the outer background (see
L<Term::Fabulous::Enum::BorderStyle/locations>) are not affected; those
in reverse video use the outer background as well. A corner is drawn
like the side next to it when that side is listed, otherwise like its
top or bottom side. Unknown side names die.
L<Term::Fabulous::Widget::Table> draws its outer frame this way, so a
highlighted row ends at the frame.

=back

C<border_corners> and C<outer_border_sides> cannot be set from a KDL
layout file.

=head1 METHODS

There is no C<border_style> accessor; to change all sides after
construction, call the four side accessors.

=head2 border_style_top

	my $style = $box->border_style_top;
	$box->border_style_top( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the top side. Takes and returns C<undef> or
a L<Term::Fabulous::Enum::BorderStyle> item; anything else dies. The
change shows in the next frame.

=head2 border_style_right

	$box->border_style_right( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the right side, as L</border_style_top>.

=head2 border_style_bottom

	$box->border_style_bottom( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the bottom side, as L</border_style_top>.

=head2 border_style_left

	$box->border_style_left( Term::Fabulous::Enum::BorderStyle->Heavy );

Accessor for the style of the left side, as L</border_style_top>.

=head2 border_corners

	my $corners = $box->border_corners;    # a copy, or undef
	$box->border_corners( { top_left => "\x{253C}" } );
	$box->border_corners(undef);           # the style's corners again

Accessor for the C<border_corners> parameter. The reader returns a new
hash (or C<undef>); the writer takes what the parameter takes, replaces
all corners at once and returns the new value. The change shows in the
next frame.

=head2 outer_border_sides

	my $sides = $box->outer_border_sides;          # a copy, e.g. [ 'left', 'top' ]
	$box->outer_border_sides( [ 'left', 'right' ] );

Accessor for the C<outer_border_sides> parameter. The reader returns a
new array reference of the sides in the order C<left>, C<right>,
C<top>, C<bottom>; the writer takes what the parameter takes and
returns the new value. The change shows in the next frame.

=head2 is_outer_border_side

	my $outer = $box->is_outer_border_side('left');    # 1 or 0

Whether a side is listed in C<outer_border_sides>. Used by
L<Term::Fabulous::Render::Border>.

=head2 border_corner_glyph

	my $glyph = $box->border_corner_glyph('top_left');    # or undef

The glyph drawn at one corner instead of the style's corner glyph, or
C<undef> when the style's glyph is drawn. Used by
L<Term::Fabulous::Render::Border>.

=head2 contribute_border_hidden

	$widget->contribute_border_hidden( \%config );

Called by Clay::UI while it builds the configuration of a frame, after
C<contribute_border>; it sets the border width Clay sees to 0 on every
C<Hidden> side, so nothing is drawn there. The widget's own
C<border_width> is not modified. You do not call it yourself.

=head2 contribute_layout_inset

	$widget->contribute_layout_inset( \%config );

Called by Clay::UI while it builds the configuration of a frame; it
adds the border widths of the sides that are not C<Hidden> to the
padding as described in L</Border space>. You do not call it yourself.

=head1 SEE ALSO

L<Term::Fabulous::Enum::BorderStyle>, L<Term::Fabulous::Manual::Looks/BORDERS>,
L<Term::Fabulous::Widget>, L<Clay::UI::Role::Style::HasBorder>, the
example program F<examples/border-showcase.pl>, which shows every style.

=cut
