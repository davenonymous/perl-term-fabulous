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
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_WHEEL_UP TB_KEY_MOUSE_WHEEL_DOWN);

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

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::TextArea;
	use Clay::XS qw(sizing_grow sizing_fixed);

	my $notes = Term::Fabulous::Widget::TextArea->new(
		id          => 'notes',
		placeholder => 'Notes',
		layout      => { sizing => { width => sizing_grow(), height => sizing_fixed(8) } },
	);

	my $dirty = 0;
	$notes->on( Change => sub ($event) {
		$dirty = 1;
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	my @lines = split /\n/, $notes->value, -1;

=head1 DESCRIPTION

A text area holds text of several lines that the user can type, edit,
select and copy. By default, lines longer than the area are wrapped at
word boundaries; with C<< wrap => 0 >> every line takes one row and the
view scrolls sideways instead. The view scrolls up and down to keep the
cursor visible, and while the text is taller than the area, a scrollbar
is shown in its rightmost column.

The text (C<value>) is a Perl character string; lines are separated by
C<"\n">. C<"\r\n"> and C<"\r"> in assigned or pasted text are converted
to C<"\n">.

The editing keys, mouse selection, the placeholder, C<max_length>,
C<read_only> and the C<Change> event are shared with the text field and
described in L<Term::Fabulous::Widget::TextInput>. Disabling, colors and
sizing are described in L<Term::Fabulous::Widget::Input>.

=head1 CONSTRUCTOR

=head2 new

	my $area = Term::Fabulous::Widget::TextArea->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::TextInput/CONSTRUCTOR>
(C<value>, C<placeholder>, C<max_length>, C<read_only>,
C<placeholder_color>, C<selection_color>, C<background_color>) and of
L<Term::Fabulous::Widget::Input/CONSTRUCTOR> (C<id>, C<layout>,
C<disabled>, C<can_focus>, C<text_color>, C<disabled_color>,
C<accent_color>, C<focus_background_color>, the border parameters), plus
the ones below. Unknown parameters die.

=over

=item C<preferred_columns>

A positive integer. Default: 40. The width of the text in columns when
the C<layout> gives the area no width. Dies if not a positive integer.

=item C<preferred_rows>

A positive integer. Default: 5. The height of the text in rows when the
C<layout> gives the area no height. Dies if not a positive integer.

=item C<wrap>

A boolean. Default: 1. When true, a line longer than the area continues
on the next row, broken after the last space that fits, or inside a word
that is wider than the area. When false, every line takes exactly one
row and the view scrolls sideways with the cursor.

=item C<scrollbar>

A boolean. Default: 1. When true, a scrollbar is shown in the rightmost
column while the text has more rows than the area; it then takes one
column from the text. The scrollbar only shows the position; it cannot
be dragged.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::TextInput/METHODS> (C<value>,
C<max_length>, C<placeholder>, C<read_only>, C<placeholder_color>,
C<selection_color>, C<editor>, C<cursor_moved>) and of
L<Term::Fabulous::Widget::Input/METHODS> (C<disabled>, C<is_enabled>,
the color accessors, C<repaint>), plus:

=head2 value

	my $text = $area->value;
	$area->value("first line\nsecond line");

As described in L<Term::Fabulous::Widget::TextInput/value>. Writing
also scrolls the view back to the top-left before it moves to the
cursor at the end of the new text.

=head2 preferred_columns

	my $columns = $area->preferred_columns;
	$area->preferred_columns(60);

Accessor for the C<preferred_columns> parameter. Writing returns the new
value, which takes effect at the next frame. Dies if not a positive
integer; the old value then stays.

=head2 preferred_rows

	my $rows = $area->preferred_rows;
	$area->preferred_rows(10);

Accessor for the C<preferred_rows> parameter. Writing returns the new
value, which takes effect at the next frame. Dies if not a positive
integer; the old value then stays.

=head2 wrap

	$area->wrap(0);

Accessor for the C<wrap> parameter. Returns a true or false value: the
writer stores and returns 1 or 0, but a value passed to C<new> is
returned exactly as it was given. Writing re-wraps the text, scrolls to
the cursor and repaints. Any value is accepted.

=head2 scrollbar

	$area->scrollbar(0);

Accessor for the C<scrollbar> parameter. Returns a true or false value:
the writer stores and returns 1 or 0, but a value passed to C<new> is
returned exactly as it was given. Writing scrolls to the cursor and
repaints. Any value is accepted.

=head2 scroll_rows

	$area->scroll_rows(-3);    # three rows towards the top
	$area->scroll_rows(10);    # ten rows towards the end

Scrolls the view by visual rows (wrapped rows count separately) without
moving the cursor. Negative numbers scroll towards the top. The view
stops at the first and last row of the text. Returns the area. The view
jumps back to the cursor as soon as the cursor moves.

=head2 top_row

	my $row = $area->top_row;

The index of the first visual row shown, counted from 0. With wrapping,
a long line spans several visual rows.

=head1 KEYS

All keys of L<Term::Fabulous::Widget::TextInput/KEYS>, plus:

=over

=item C<Enter>

Starts a new line (inserts C<"\n"> at the cursor, replacing the
selection). While C<read_only> is set, C<Enter> is not used and
bubbles. A text area fires no C<Submit> event.

=item C<Up>, C<Down>

Move the cursor one visual row up or down. While moving vertically, the
cursor aims for the column it had when vertical movement started. Above
the first row the cursor goes to the start of the text, below the last
row to its end.

=item C<PageUp>, C<PageDown>

Move the cursor by a page: the height of the area minus one row, but
at least one row.

=item C<Shift+Up>, C<Shift+Down>, C<Shift+PageUp>, C<Shift+PageDown>

The movements above, extending the selection.

=back

C<Home> and C<End> move to the start and end of the text line, not of
the wrapped row. C<Tab> is not inserted: it bubbles, and
L<Term::Fabulous> moves the focus to the next widget. C<Escape> and the
function keys bubble too.

=head1 MOUSE

As described in L<Term::Fabulous::Widget::TextInput/MOUSE>: click to
place the cursor, drag (while the pointer stays over the input) to
select, double-click to select a word. Each notch of the mouse wheel
scrolls the view by three rows without moving the cursor.

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> after every change the user makes to
the text (including C<Enter>); C<< $event->value >> is the whole new
text.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::TextInput/KDL PROPERTIES>,
plus C<preferred_columns>, C<preferred_rows>, C<wrap> and C<scrollbar>
(C<#true> / C<#false>):

	use Term::Fabulous::Widget::TextArea as TextArea

	TextArea "log" {
		preferred_rows 10
		wrap #false
		read_only #true
		sizing width=grow
	}

In KDL, C<value> is a single string; write line breaks as C<\n> inside
the string (C<value "first\nsecond">).

=head1 EXAMPLES

=head2 A read-only log that shows the newest line

	my $log = Term::Fabulous::Widget::TextArea->new(
		read_only => 1,
		wrap      => 0,
		layout    => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	sub log_line ($line) {
		my $text = $log->value;
		$log->value( length $text ? "$text\n$line" : $line );    # cursor at the end
		return;
	}

=head2 Count the lines while the user types

	use Clay::UI::Enum::Result;

	$notes->on( Change => sub ($event) {
		my $lines = () = $event->value =~ /\n/g;
		$status->text( sprintf '%d lines', $lines + 1 );
		return Clay::UI::Enum::Result->CONTINUE;
	} );

=head1 CAVEATS

Inside a L<Term::Fabulous::Widget::ScrollBox>, one notch of the mouse
wheel over the text area scrolls both the text area and the scroll box.

=head1 SEE ALSO

L<Term::Fabulous::Widget::TextInput>, L<Term::Fabulous::Widget::TextField>,
L<Term::Fabulous::Editor>,
L<Term::Fabulous::Manual/FORMS AND INPUT WIDGETS>.

=cut
