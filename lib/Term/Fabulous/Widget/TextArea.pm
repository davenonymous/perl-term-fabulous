package Term::Fabulous::Widget::TextArea;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::TextInput;

our $VERSION = '0.01';

class Term::Fabulous::Widget::TextArea
	:isa(Term::Fabulous::Widget::TextInput)
	:strict(params)
{
	use List::Util qw(max min sum0);
	use Termbox 2 qw(TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN);

	use constant WHEEL_ROWS      => 3;
	use constant SCROLLBAR_TRACK => "\x{2502}";
	use constant SCROLLBAR_THUMB => "\x{2503}";

	# Vertical movement: key name => [ direction, unit, extend the selection ].
	my %VERTICAL_BY_KEY = (
		'Up'             => [ -1, 'row',  0 ],
		'Shift+Up'       => [ -1, 'row',  1 ],
		'Down'           => [ 1,  'row',  0 ],
		'Shift+Down'     => [ 1,  'row',  1 ],
		'PageUp'         => [ -1, 'page', 0 ],
		'Shift+PageUp'   => [ -1, 'page', 1 ],
		'PageDown'       => [ 1,  'page', 0 ],
		'Shift+PageDown' => [ 1,  'page', 1 ],
	);

	field $preferred_columns :param = 40;
	field $preferred_rows    :param = 5;
	field $wrap              :param = 1;
	field $scrollbar         :param = 1;

	# The first visual row shown, and (without wrapping) the columns
	# scrolled out on the left.
	field $top    = 0;
	field $scroll = 0;

	# The column Up and Down aim for, kept while moving vertically.
	field $goal_column;

	# The visual rows of the text for one width, see _layout.
	field $layout_cache;

	ADJUST {
		$preferred_columns = _checked_size( preferred_columns => $preferred_columns );
		$preferred_rows    = _checked_size( preferred_rows    => $preferred_rows );
	}

	method is_multi_line :common :override () {
		return 1;
	}

	sub _checked_size ( $name, $value ) {
		die "Term::Fabulous::Widget::TextArea: $name must be a positive integer, got " . ( defined $value ? "'$value'" : 'undef' )
			unless defined $value && !ref $value && $value =~ /\A[0-9]+\z/ && $value > 0;
		return $value + 0;
	}

	method preferred_columns (@new) {
		return $preferred_columns unless @new;
		return $preferred_columns = _checked_size( preferred_columns => $new[0] );
	}

	method preferred_rows (@new) {
		return $preferred_rows unless @new;
		return $preferred_rows = _checked_size( preferred_rows => $new[0] );
	}

	method wrap (@new) {
		return $wrap unless @new;
		$wrap   = $new[0] ? 1 : 0;
		$scroll = 0;
		$self->cursor_moved;
		return $wrap;
	}

	method scrollbar (@new) {
		return $scrollbar unless @new;
		$scrollbar = $new[0] ? 1 : 0;
		$self->cursor_moved;
		return $scrollbar;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(preferred_columns preferred_rows wrap scrollbar) );
	}

	method natural_size () {
		return ( $preferred_columns, $preferred_rows );
	}

	method top_row () {
		return $top;
	}

	# ---------------------------------------------------------------------
	# Visual rows: every line is cut into the parts shown on one row each.
	# ---------------------------------------------------------------------

	# The parts [from, to) of a line for a text width. Wrapping breaks
	# after the last space that fits, or else before the cluster that does
	# not fit. A line whose last part fills the width gets an empty part
	# after it, where the cursor can stand at its end.
	method _wrap_line ( $row, $width ) {
		my @clusters = $self->clusters_between( $row, 0, length $self->editor->line($row) );
		my $end      = length $self->editor->line($row);
		return [ 0, $end ] unless $wrap;

		my ( @parts, $break );
		my ( $start, $used ) = ( 0, 0 );
		foreach my $index ( 0 .. $#clusters ) {
			my ( undef, $display, $columns ) = @{ $clusters[$index] };
			if ( $used + $columns > $width && $index > $start ) {
				my $cut = defined $break && $break > $start ? $break : $index;
				push @parts, [ $clusters[$start][0], $clusters[$cut][0] ];
				$used  = sum0 map { $_->[2] } @clusters[ $cut .. $index - 1 ];
				$start = $cut;
				undef $break;
			}
			$used += $columns;
			$break = $index + 1 if $display =~ /\A\s\z/;
		}
		push @parts, [ @clusters ? $clusters[$start][0] : 0, $end ];
		push @parts, [ $end, $end ] if @clusters && $used >= $width;
		return @parts;
	}

	# { width, scrollbar, rows => [ [ $row, $from, $to, $is_last_part ], ... ],
	# first => [ the first visual row of each line ] } for the current size.
	method _layout () {
		my ( $columns, $height ) = ( $self->columns, $self->rows );
		my $key = join ':', $self->editor->revision, $columns, $height, $wrap, $scrollbar;
		return $layout_cache if defined $layout_cache && $layout_cache->{key} eq $key;

		my $layout = $self->_layout_for( max( $columns, 1 ) );
		$layout = $self->_layout_for( $columns - 1, 1 ) if $scrollbar && $columns > 1 && @{ $layout->{rows} } > $height;
		$layout->{key} = $key;
		return $layout_cache = $layout;
	}

	method _layout_for ( $width, $has_scrollbar = 0 ) {
		my ( @rows, @first );
		foreach my $row ( 0 .. $self->editor->line_count - 1 ) {
			my @parts = $self->_wrap_line( $row, $width );
			push @first, scalar @rows;
			push @rows, map { [ $row, @{ $parts[$_] }, $_ == $#parts ] } 0 .. $#parts;
		}
		return { width => $width, scrollbar => $has_scrollbar, rows => \@rows, first => \@first };
	}

	# The visual row index showing an editor position.
	method _visual_row_of ( $layout, $row, $offset ) {
		my $index = $layout->{first}[$row];
		$index++ while !$layout->{rows}[$index][3] && $offset >= $layout->{rows}[$index][2];
		return $index;
	}

	method _max_top ($layout) {
		return max( 0, scalar( @{ $layout->{rows} } ) - $self->rows );
	}

	# ---------------------------------------------------------------------
	# Scrolling and positions
	# ---------------------------------------------------------------------

	method scroll_to_cursor () {
		return if $self->columns < 1 || $self->rows < 1;
		my $layout = $self->_layout;
		my ( $row, $offset ) = $self->editor->cursor;
		my $visual = $self->_visual_row_of( $layout, $row, $offset );

		$top = $visual                   if $visual < $top;
		$top = $visual - $self->rows + 1 if $visual >= $top + $self->rows;
		$top = min( max( $top, 0 ), $self->_max_top($layout) );
		return if $wrap;

		my $width    = $layout->{width};
		my $cursor_x = $self->columns_to( $row, 0, $offset );
		my ($cursor) = $self->clusters_between( $row, $offset, length $self->editor->line($row) );
		my $cursor_columns = defined $cursor ? $cursor->[2] : 1;
		$scroll = $cursor_x                            if $cursor_x < $scroll;
		$scroll = $cursor_x + $cursor_columns - $width if $cursor_x + $cursor_columns > $scroll + $width;
		$scroll = 0                                    if $scroll < 0;
		return;
	}

	method scroll_rows ($rows) {
		my $layout = $self->_layout;
		$top = min( max( $top + $rows, 0 ), $self->_max_top($layout) );
		$self->repaint;
		return $self;
	}

	method position_at ( $column, $row ) {
		my $layout = $self->_layout;
		my $rows   = $layout->{rows};
		my $index  = min( $top + $row, $#$rows );
		my ( $line, $from, $to, $is_last ) = @{ $rows->[$index] };
		my $offset = $self->offset_at_column( $line, $from, $to, $column + ( $wrap ? 0 : $scroll ) );

		# The end of a wrapped part is shown at the start of the next row;
		# a click past it stays on its own row, before its last cluster.
		if ( !$is_last && $offset == $to && $to > $from ) {
			my @clusters = $self->clusters_between( $line, $from, $to );
			$offset = $clusters[-1][0];
		}
		return ( $line, $offset );
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method handle_key :override ($event) {
		my $name = $event->key_name // '';
		if ( my $vertical = $VERTICAL_BY_KEY{$name} ) {
			my ( $direction, $unit, $extend ) = @$vertical;
			$self->_move_vertically( $direction * ( $unit eq 'page' ? max( 1, $self->rows - 1 ) : 1 ), $extend );
			return $self->cursor_moved;
		}

		undef $goal_column;
		return $self->apply_edit( $self->editor->insert("\n") ) if $name eq 'Enter' && !$self->read_only;
		return $self->SUPER::handle_key($event);
	}

	# Moves the cursor by visual rows, aiming for the column it had when
	# vertical movement started. Beyond the first (last) row it goes to the
	# start (end) of the text, which starts a new aim.
	method _move_vertically ( $rows, $extend ) {
		my $editor = $self->editor;
		my $layout = $self->_layout;
		my ( $row, $offset ) = $editor->cursor;
		my $visual = $self->_visual_row_of( $layout, $row, $offset );
		my $part   = $layout->{rows}[$visual];
		$goal_column //= $self->columns_to( $row, $part->[1], $offset );

		my $target = $visual + $rows;
		if ( $target < 0 || $target > $#{ $layout->{rows} } ) {
			$target < 0 ? $editor->move_document_start($extend) : $editor->move_document_end($extend);
			undef $goal_column;
			return;
		}

		my ( $line, $from, $to, $is_last ) = @{ $layout->{rows}[$target] };
		my $target_offset = $self->offset_at_column( $line, $from, $to, $goal_column );
		if ( !$is_last && $target_offset == $to && $to > $from ) {
			my @clusters = $self->clusters_between( $line, $from, $to );
			$target_offset = $clusters[-1][0];
		}
		my $goal = $goal_column;
		$editor->move_to( $line, $target_offset, $extend );
		$goal_column = $goal;
		return;
	}

	method handle_mouse :override ($event) {
		my $key = $event->key;
		if ( $key == TB_KEY_MOUSE_WHEEL_UP || $key == TB_KEY_MOUSE_WHEEL_DOWN ) {
			$self->scroll_rows( $key == TB_KEY_MOUSE_WHEEL_UP ? -WHEEL_ROWS : WHEEL_ROWS );
			return 1;
		}
		undef $goal_column;
		return $self->SUPER::handle_mouse($event);
	}

	method value :override (@new) {
		return $self->SUPER::value unless @new;
		( $top, $scroll ) = ( 0, 0 );
		undef $goal_column;
		return $self->SUPER::value(@new);
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method paint () {
		$self->paint_focus_background;
		my $layout = $self->_layout;
		$top = min( $top, $self->_max_top($layout) );

		if ( $self->shows_placeholder ) {
			$self->paint_placeholder(0);
		}
		else {
			my $rows = $layout->{rows};
			foreach my $y ( 0 .. min( $self->rows, @$rows - $top ) - 1 ) {
				my ( $line, $from, $to, $is_last ) = @{ $rows->[ $top + $y ] };
				my $end_x = $self->paint_line_part( $y, $line, $from, $to, $wrap ? 0 : $scroll, $is_last );
				$self->_paint_selected_line_break( $y, $line, $end_x, $layout->{width} ) if $is_last;
			}
		}
		$self->_paint_scrollbar($layout) if $layout->{scrollbar};
		return;
	}

	# A selection reaching over the end of a line shows a selected cell
	# after it.
	method _paint_selected_line_break ( $y, $line, $x, $width ) {
		my $editor = $self->editor;
		return if $line == $editor->line_count - 1 || $x < 0 || $x >= $width;
		my ( $row_0, $offset_0, $row_1 ) = $editor->selection;
		return unless defined $row_0 && $line < $row_1;
		return if $line < $row_0 || ( $line == $row_0 && $offset_0 > length $editor->line($line) );

		my ( $cursor_row, $cursor_offset ) = $editor->cursor;
		return if $self->is_focused && $cursor_row == $line && $cursor_offset == length $editor->line($line);
		$self->put_attrs( $x, $y, ' ', undef, $self->color_attr( $self->selection_color ) );
		return;
	}

	method _paint_scrollbar ($layout) {
		my ( $height, $x ) = ( $self->rows, $self->columns - 1 );
		my $total     = scalar @{ $layout->{rows} };
		my $thumb     = max( 1, int( $height * $height / $total + 0.5 ) );
		my $max_top   = $self->_max_top($layout);
		my $thumb_top = $max_top ? int( ( $height - $thumb ) * $top / $max_top + 0.5 ) : 0;
		my $track_fg  = $self->color_attr( $self->disabled_color );
		my $thumb_fg  = $self->accent_attr;
		my $bg        = $self->focus_background_attr;

		foreach my $y ( 0 .. $height - 1 ) {
			my $is_thumb = $y >= $thumb_top && $y < $thumb_top + $thumb;
			$self->put_attrs( $x, $y, $is_thumb ? SCROLLBAR_THUMB : SCROLLBAR_TRACK, $is_thumb ? $thumb_fg : $track_fg, $bg );
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::TextArea - Multi-line text input

=head1 SYNOPSIS

	use Term::Fabulous::Widget::TextArea;
	use Clay::XS qw(sizing_grow sizing_fixed);

	my $notes = Term::Fabulous::Widget::TextArea->new(
		id          => 'notes',
		placeholder => 'Notes',
		layout      => { sizing => { width => sizing_grow(), height => sizing_fixed(8) } },
	);
	$notes->on( Change => sub ($event) { $dirty = 1; return } );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::TextInput> for text of several lines. Long
lines wrap at word boundaries (or scroll sideways, see C<wrap>), and the
view scrolls vertically to keep the cursor visible. When the text is
taller than the area, a scrollbar is shown in its rightmost column.
Unknown constructor parameters die.

See L<Term::Fabulous::Widget::TextInput> for the C<value>, the editing
keys, mouse selection and the C<Change> event. Lines in C<value> are
separated by C<"\n">; C<"\r\n"> and C<"\r"> are converted on input.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::TextInput>:

=over

=item C<preferred_columns>, C<preferred_rows>

The size of the text area in cells when the C<layout> gives no width
or height; positive integers, default 40 and 5.

=item C<wrap>

Boolean, default 1: lines longer than the area continue on the next
row, broken after the last space that fits (or inside a word that is
wider than the area). With 0, every line takes one row and the view
scrolls sideways with the cursor.

=item C<scrollbar>

Boolean, default 1: show a scrollbar while the text is taller than the
area. It takes one column from the text.

=back

All four have readers and writers of the same name.

=head1 METHODS

=head2 scroll_rows

	$area->scroll_rows(-3);

Scrolls the view by visual rows (negative: towards the top), without
moving the cursor; the view stays within the text. Returns the area.

=head2 top_row

The first visual row shown.

=head1 KEYS

The keys of L<Term::Fabulous::Widget::TextInput/KEYS>, plus:

=over

=item Enter

Starts a new line.

=item Up, Down, Page Up, Page Down

Move the cursor by visual rows (a page is the height of the area less
one row), keeping its column while moving vertically. Above the first
row the cursor goes to the start of the text, below the last row to its
end. With Shift they extend the selection.

=back

Home and End move to the start and end of the line, not of the wrapped
row. Tab is not inserted; it moves the focus.

=head1 MOUSE

As described in L<Term::Fabulous::Widget::TextInput/MOUSE>; the mouse
wheel scrolls the view by three rows per notch.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::TextInput/KDL PROPERTIES> plus
C<preferred_columns>, C<preferred_rows>, C<wrap> and C<scrollbar>.

=cut
