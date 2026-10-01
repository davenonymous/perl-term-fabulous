package Term::Fabulous::Widget::Canvas;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Canvas
	:isa(Term::Fabulous::Widget::Box)
	:strict(params)
{
	use List::Util qw(max min);
	use POSIX qw(ceil);
	use Scalar::Util qw(blessed looks_like_number);
	use Termbox 2 qw(TB_DEFAULT TB_TRUECOLOR_BLACK);
	use Term::Fabulous::Color;
	use Term::Fabulous::Event::CanvasResize;
	use Term::Fabulous::Render::Attr qw(color_attr);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	use constant GLYPH_CACHE_LIMIT => 4096;
	use constant MAX_RGB           => 0xFFFFFF;

	# Stored in the cells a wide glyph covers to the right of its own cell.
	use constant TAIL => '';

	# Glyph records, shared by every cell showing the glyph:
	# [ $cluster, $columns, $base_character, @extending_characters ].
	my %glyph_by_string;
	my $SPACE = [ ' ', 1, ' ' ];

	field $columns :reader = 0;
	field $rows    :reader = 0;

	# Cells by [y][x]: a glyph record, TAIL, or undef for an unset cell; the
	# attributes are undef where the cell has none of its own.
	field @glyph_rows;
	field @fg_rows;
	field @bg_rows;

	# Per row, the [from, to) columns changed since take_changed_spans.
	field @changed_spans;
	field $everything_changed = 1;

	sub _describe ($value) {
		return defined $value ? "'$value'" : 'undef';
	}

	sub _is_tail ($cell) {
		return defined $cell && !ref $cell;
	}

	# Rounds down; int() and a comparison are much cheaper than POSIX::floor.
	sub _coordinate ( $what, $value ) {
		die "Term::Fabulous::Widget::Canvas: $what must be a number, got " . _describe($value)
			unless looks_like_number($value) && $value == $value;
		my $whole = int $value;
		return $whole <= $value ? $whole : $whole - 1;
	}

	sub _glyph_of_cluster ($cluster) {
		my $glyph = $glyph_by_string{$cluster};
		return $glyph if defined $glyph;

		%glyph_by_string = () if keys(%glyph_by_string) >= GLYPH_CACHE_LIMIT;
		my ( $base, @extenders ) = split //, $cluster;
		return $glyph_by_string{$cluster} = [ $cluster, cluster_columns($cluster), $base, @extenders ];
	}

	sub _glyph ($string) {
		die "Term::Fabulous::Widget::Canvas: a glyph must be a non-empty string, got " . _describe($string)
			unless defined $string && !ref $string && length $string;
		my $glyph = $glyph_by_string{$string};
		return $glyph if defined $glyph;

		my @clusters = grapheme_clusters($string);
		die "Term::Fabulous::Widget::Canvas: a glyph must be exactly one grapheme cluster, got " . scalar(@clusters) . " in '$string'"
			unless @clusters == 1;
		return _glyph_of_cluster( $clusters[0] );
	}

	# undef, and colors with alpha 0, leave the cell without a color of its own.
	sub _color_attr ( $what, $color ) {
		return undef unless defined $color;
		if ( !ref $color && $color =~ /\A[0-9]+\z/ ) {
			die "Term::Fabulous::Widget::Canvas: $what must be a packed 0xRRGGBB value, got $color" if $color > MAX_RGB;
			return $color == 0 ? TB_TRUECOLOR_BLACK : $color + 0;
		}
		my $object = blessed $color && $color->isa('Term::Fabulous::Color') ? $color : Term::Fabulous::Color->new( color => $color );
		my $attr   = color_attr($object);
		return $attr == TB_DEFAULT ? undef : $attr;
	}

	method contribute_custom ($config) {
		$config->{custom} = { custom_data => 1 };
		return;
	}

	method put ( $x, $y, $glyph, $fg = undef, $bg = undef ) {
		$self->_store( _coordinate( x => $x ), _coordinate( y => $y ), _glyph($glyph), _color_attr( fg => $fg ), _color_attr( bg => $bg ) );
		return $self;
	}

	method put_text ( $x, $y, $text, $fg = undef, $bg = undef ) {
		die "Term::Fabulous::Widget::Canvas: text must be a string, got " . _describe($text) unless defined $text && !ref $text;
		my ( $column, $row ) = ( _coordinate( x => $x ), _coordinate( y => $y ) );
		my ( $fg_attr, $bg_attr ) = ( _color_attr( fg => $fg ), _color_attr( bg => $bg ) );

		foreach my $cluster ( grapheme_clusters($text) ) {
			last if $column >= $columns;
			my $glyph = _glyph_of_cluster($cluster);
			$self->_store( $column, $row, $glyph, $fg_attr, $bg_attr );
			$column += $glyph->[1];
		}
		return $self;
	}

	method fill ( $x, $y, $width, $height, $glyph, $fg = undef, $bg = undef ) {
		my ( $x0, $y0 ) = ( _coordinate( x => $x ), _coordinate( y => $y ) );
		my ( $x1, $y1 ) = ( $x0 + _coordinate( width => $width ), $y0 + _coordinate( height => $height ) );
		my $record = _glyph($glyph);
		my ( $fg_attr, $bg_attr ) = ( _color_attr( fg => $fg ), _color_attr( bg => $bg ) );

		# Glyphs repeat from x0 on; skip the repeats left of the buffer.
		my $step  = $record->[1];
		my $first = $x0 < 0 ? $x0 + $step * ceil( -$x0 / $step ) : $x0;
		foreach my $row ( max( $y0, 0 ) .. min( $y1, $rows ) - 1 ) {
			for ( my $column = $first; $column + $step <= min( $x1, $columns ); $column += $step ) {
				$self->_store( $column, $row, $record, $fg_attr, $bg_attr );
			}
		}
		return $self;
	}

	method erase ( $x, $y ) {
		$self->_store( _coordinate( x => $x ), _coordinate( y => $y ), undef, undef, undef );
		return $self;
	}

	method clear () {
		@$_ = () foreach @glyph_rows, @fg_rows, @bg_rows;
		$everything_changed = 1;
		return $self;
	}

	method cell ( $x, $y ) {
		my ( $column, $row ) = ( _coordinate( x => $x ), _coordinate( y => $y ) );
		return undef if $row < 0 || $row >= $rows || $column < 0 || $column >= $columns;

		my $glyph = $glyph_rows[$row][$column];
		return undef unless ref $glyph;
		return [ $glyph->[0], $fg_rows[$row][$column], $bg_rows[$row][$column] ];
	}

	method cell_row ($y) {
		return ( $glyph_rows[$y], $fg_rows[$y], $bg_rows[$y] );
	}

	method take_changed_spans () {
		my @spans = $everything_changed ? map { [ 0, $columns ] } 1 .. $rows : @changed_spans;
		@changed_spans      = ();
		$everything_changed = 0;
		return \@spans;
	}

	method content_insets () {
		my $padding = $self->to_config->{layout}{padding} // {};
		return map { $padding->{$_} // 0 } qw(left top right bottom);
	}

	method fit_to ( $new_columns, $new_rows ) {
		die "Term::Fabulous::Widget::Canvas: fit_to needs a non-negative integer size, got " . _describe($new_columns) . " x " . _describe($new_rows)
			unless grep( { defined && /\A[0-9]+\z/ } $new_columns, $new_rows ) == 2;
		return if $new_columns == $columns && $new_rows == $rows;

		foreach my $rows_of_cells ( \@glyph_rows, \@fg_rows, \@bg_rows ) {
			$#$rows_of_cells = $new_rows - 1;
			foreach my $cells (@$rows_of_cells) {
				$cells //= [];
				$#$cells = $new_columns - 1 if @$cells > $new_columns;
			}
		}
		_unset_cut_glyph( $_, $new_columns ) foreach @glyph_rows;

		( $columns, $rows ) = ( $new_columns + 0, $new_rows + 0 );
		@changed_spans      = ();
		$everything_changed = 1;
		$self->fire_event( Term::Fabulous::Event::CanvasResize->new( columns => $columns, rows => $rows ) );
		return;
	}

	# A wide glyph that no longer fits at the right edge leaves its cells unset.
	sub _unset_cut_glyph ( $glyphs, $columns ) {
		my $head = $columns - 1;
		$head-- while $head > 0 && _is_tail( $glyphs->[$head] );
		return unless ref $glyphs->[$head] && $head + $glyphs->[$head][1] > $columns;
		$glyphs->[$_] = undef foreach $head .. $columns - 1;
		return;
	}

	# Writes one glyph (undef unsets the cell). Writes that do not fit into
	# the buffer are dropped. A wide glyph partly overwritten here leaves
	# spaces in its other cells.
	method _store ( $x, $y, $glyph, $fg, $bg ) {
		my $width = defined $glyph ? $glyph->[1] : 1;
		return if $y < 0 || $y >= $rows || $x < 0 || $x + $width > $columns;

		my ( $glyphs, $fgs, $bgs ) = ( $glyph_rows[$y], $fg_rows[$y], $bg_rows[$y] );
		my ( $from, $to ) = ( $x, $x + $width );
		my $first = $glyphs->[$x];
		if ( defined $first && !ref $first ) {
			$from-- while _is_tail( $glyphs->[$from] );
			$glyphs->[$_] = $SPACE foreach $from .. $x - 1;
		}
		while ( $to < $columns && _is_tail( $glyphs->[$to] ) ) {
			$glyphs->[ $to++ ] = $SPACE;
		}

		( $glyphs->[$x], $fgs->[$x], $bgs->[$x] ) = ( $glyph, $fg, $bg );
		if ( $width > 1 ) {
			my @covered = ( $x + 1 .. $x + $width - 1 );
			@{$glyphs}[@covered] = (TAIL) x @covered;
			@{$fgs}[@covered]    = ($fg) x @covered;
			@{$bgs}[@covered]    = ($bg) x @covered;
		}

		return if $everything_changed;
		my $span = $changed_spans[$y];
		if ( !defined $span ) {
			$changed_spans[$y] = [ $from, $to ];
			return;
		}
		$span->[0] = $from if $from < $span->[0];
		$span->[1] = $to   if $to > $span->[1];
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Canvas - Free-drawing cell buffer widget

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Canvas;
	use Clay::XS qw(sizing_grow);

	my $canvas = Term::Fabulous::Widget::Canvas->new(
		background_color => [10, 10, 20, 255],
		layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	$canvas->on( CanvasResize => sub ($event) {
		$canvas->clear;
		$canvas->put( $_, $event->rows - 1, "\x{2500}", 0x808080 ) foreach 0 .. $event->columns - 1;
	} );

	$canvas->put( 3, 1, "\x{2580}", 0xFF0000, 0x0000FF );         # upper half block, red over blue
	$canvas->put_text( 0, 0, "Gr\x{fc}\x{df}e", '#ffcc00' );
	$canvas->fill( 0, 2, 10, 1, '#', Term::Fabulous::Color->rgb( 0, 200, 0 ) );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Box> that holds a buffer of cells and draws
it inside its content box (the box without its border and padding). Any
grapheme cluster with any foreground and background color can be put at
any cell; it is a base for plotters, half-block pixel images and other
text art. Unknown constructor parameters die.

=head2 Buffer size

The buffer follows the layout: before the first frame it has 0 x 0
cells, and whenever the laid-out content box gets a new size, the
buffer is resized to it and the canvas fires a
L<Term::Fabulous::Event::CanvasResize> before that frame is painted.
Cells inside the new size are kept, a wide glyph cut by the new right
edge is unset. Draw in the C<CanvasResize> listener (or later); writes
outside the buffer are dropped. Use C<fixed(N)> sizing for a canvas of
a fixed size.

=head2 Only changes are painted

The canvas records which cells changed since it was last painted.
Under L<Term::Fabulous>, a canvas that is at the same place as in the
previous frame, has the same visible part and the same background, and
that nothing was drawn over in this frame or the previous one, is not
painted again: only its changed cells are sent to termbox2, and termbox2
writes only the cells that differ to the terminal. Otherwise (the first
frame, after a resize, while scrolling or when other widgets, including
the canvas's own children, overlap it) every visible cell is painted. See
L<Term::Fabulous::Render::Canvas>.

=head2 Cells

A cell is unset, or holds one grapheme cluster with a foreground and a
background color. Unset cells, and set cells without a background color,
show the background of the canvas (its C<background_color>), or else of
the nearest ancestor that has one, or else the terminal's default.
Cells without a foreground color use the terminal's default.

A glyph that is two (or more) columns wide, such as most CJK characters
and emoji, covers the cells to its right. Writing over any of its cells
replaces its other cells with spaces in its colors. A glyph that would
cross the right edge of the buffer is dropped.

=head2 Colors

The C<$fg> and C<$bg> arguments accept a packed C<0xRRGGBB> integer
(the fast path), C<undef> for no color of the cell's own, a
L<Term::Fabulous::Color>, or anything C<< Term::Fabulous::Color->new >>
accepts (C<[r, g, b, a]>, C<'#rrggbb'>, C<'hsl(...)'>, ...). A color with
alpha 0 counts as no color. Integers above C<0xFFFFFF> and invalid
colors die.

=head2 Coordinates

C<$x> counts columns from the left, C<$y> rows from the top of the
buffer, both from 0. Coordinates must be numbers and are rounded down,
so a plotter can pass computed positions directly. Anything else dies.

=head1 METHODS

The drawing methods return the canvas, so calls chain.

=head2 put

	$canvas->put( $x, $y, $glyph, $fg = undef, $bg = undef );

Sets one cell. C<$glyph> is a character string (not UTF-8 bytes) of
exactly one grapheme cluster; anything else dies. Control characters
are shown as U+FFFD (TAB as a space), as in
L<Term::Fabulous::Widget::Text>.

=head2 put_text

	$canvas->put_text( $x, $y, $text, $fg = undef, $bg = undef );

Puts the grapheme clusters of a character string from C<$x> to the
right, each advancing by its width in columns. Clusters outside the
buffer are dropped.

=head2 fill

	$canvas->fill( $x, $y, $width, $height, $glyph, $fg = undef, $bg = undef );

Puts C<$glyph> into every cell of the rect, repeated from C<$x> on
in steps of its width.

=head2 erase

	$canvas->erase( $x, $y );

Unsets one cell.

=head2 clear

Unsets every cell.

=head2 cell

	my $cell = $canvas->cell( $x, $y );

C<[ $glyph, $fg, $bg ]> for a set cell: the (sanitized) cluster and the
termbox2 attributes (see L<Term::Fabulous::Render::Attr>), C<undef> for
a missing color. C<undef> for an unset cell, a cell covered by a wide
glyph to its left, or a cell outside the buffer.

=head2 columns, rows

The size of the buffer in cells.

=head1 RENDERER INTERFACE

Used by L<Term::Fabulous::Render::Canvas>; applications do not call
these.

=over

=item C<content_insets>

C<($left, $top, $right, $bottom)>: the cells between the widget's box
and its content box (padding plus border width).

=item C<< fit_to($columns, $rows) >>

Resizes the buffer and fires C<CanvasResize>, unless it already has
that size.

=item C<take_changed_spans>

An arrayref indexed by row of C<[from, to]> column spans (C<to>
exclusive) changed since the last call, C<undef> for unchanged rows;
every row in full after a resize or C<clear>. Forgets the changes.

=item C<< cell_row($y) >>

The glyph, foreground and background arrayrefs of one row. A glyph is
C<undef> (unset), C<''> (covered by a wide glyph to the left) or
C<[ $cluster, $columns, $base_character, @extending_characters ]>.

=back

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Box/KDL PROPERTIES>.

=cut
