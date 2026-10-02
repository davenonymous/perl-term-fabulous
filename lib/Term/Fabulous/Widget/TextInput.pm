package Term::Fabulous::Widget::TextInput;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Editor;
use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::TextInput
	:isa(Term::Fabulous::Widget::Input)
	:abstract
{
	use Termbox 2 qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_MOD_MOTION TB_MOD_SHIFT);
	use Time::HiRes qw(time);
	use Term::Fabulous::Unicode qw(sanitize_text grapheme_clusters cluster_columns);

	use constant DOUBLE_CLICK_SECONDS => 0.4;
	use constant DEFAULT_BACKGROUND   => [ 36, 40, 48, 255 ];

	# Cursor movement: key name => [ editor method, extend the selection ].
	my %MOVEMENT_BY_KEY = (
		'Left'             => [ move_left           => 0 ],
		'Shift+Left'       => [ move_left           => 1 ],
		'Right'            => [ move_right          => 0 ],
		'Shift+Right'      => [ move_right          => 1 ],
		'Ctrl+Left'        => [ move_word_left      => 0 ],
		'Ctrl+Shift+Left'  => [ move_word_left      => 1 ],
		'Ctrl+Right'       => [ move_word_right     => 0 ],
		'Ctrl+Shift+Right' => [ move_word_right     => 1 ],
		'Home'             => [ move_line_start     => 0 ],
		'Shift+Home'       => [ move_line_start     => 1 ],
		'End'              => [ move_line_end       => 0 ],
		'Shift+End'        => [ move_line_end       => 1 ],
		'Ctrl+Home'        => [ move_document_start => 0 ],
		'Ctrl+Shift+Home'  => [ move_document_start => 1 ],
		'Ctrl+End'         => [ move_document_end   => 0 ],
		'Ctrl+Shift+End'   => [ move_document_end   => 1 ],
	);

	# Edits: key name => editor method.
	my %EDIT_BY_KEY = (
		'Backspace'    => 'delete_backward',
		'Delete'       => 'delete_forward',
		'Ctrl+W'       => 'delete_word_backward',
		'Ctrl+Delete'  => 'delete_word_forward',
		'Ctrl+U'       => 'delete_to_line_start',
		'Ctrl+K'       => 'delete_to_line_end',
		'Ctrl+X'       => 'cut',
		'Shift+Delete' => 'cut',
		'Ctrl+V'       => 'paste',
		'Shift+Insert' => 'paste',
		'Ctrl+Z'       => 'undo',
		'Ctrl+Y'       => 'redo',
	);

	field $editor :reader = Term::Fabulous::Editor->new( multi_line => __CLASS__->is_multi_line );

	field $placeholder       :param = '';
	field $read_only         :param = 0;
	field $placeholder_color :param = [ 120, 126, 138, 255 ];
	field $selection_color   :param = [ 38,  79,  120, 255 ];

	# Mouse: whether a press in the widget started a drag, and the time and
	# position of the last press, for double clicks.
	field $dragging = 0;
	field @last_press;

	ADJUST :params ( :$value = undef, :$max_length = undef ) {
		$self->_checked_placeholder($placeholder);
		$self->_checked_color( placeholder_color => $placeholder_color );
		$self->_checked_color( selection_color   => $selection_color );
		$self->background_color( [ @{ +DEFAULT_BACKGROUND } ] ) unless defined $self->background_color;
		$editor->set_max_length($max_length) if defined $max_length;
		$self->value($value)                 if defined $value;
	}

	method is_multi_line :common () {
		return 0;
	}

	# Keeps the cursor inside the visible part of the text.
	method scroll_to_cursor;

	# The editor position ($row, $offset) shown at a buffer cell.
	method position_at;

	# ---------------------------------------------------------------------
	# Properties
	# ---------------------------------------------------------------------

	method value (@new) {
		return $editor->text unless @new;
		$editor->set_text( $new[0] );
		$self->scroll_to_cursor;
		$self->repaint;
		return $editor->text;
	}

	method max_length (@new) {
		return $editor->max_length unless @new;
		$editor->set_max_length( $new[0] );
		return $editor->max_length;
	}

	method _checked_placeholder ($text) {
		die ref($self) . ": placeholder must be a string, got " . ( ref $text || 'undef' ) unless defined $text && !ref $text;
		return $text;
	}

	method placeholder (@new) {
		return $placeholder unless @new;
		$placeholder = $self->_checked_placeholder( $new[0] );
		$self->repaint;
		return $placeholder;
	}

	method read_only (@new) {
		return $read_only unless @new;
		$read_only = $new[0] ? 1 : 0;
		return $read_only;
	}

	method placeholder_color (@new) {
		return @new ? $self->_set_color( placeholder_color => \$placeholder_color, @new ) : $placeholder_color;
	}

	method selection_color (@new) {
		return @new ? $self->_set_color( selection_color => \$selection_color, @new ) : $selection_color;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(value placeholder max_length read_only placeholder_color selection_color) );
	}

	# ---------------------------------------------------------------------
	# Keys
	# ---------------------------------------------------------------------

	method handle_key ($event) {
		my $text = $event->text;
		return $self->apply_edit( $editor->type($text) ) if defined $text && !$read_only;

		my $name = $event->key_name // return 0;
		if ( my $movement = $MOVEMENT_BY_KEY{$name} ) {
			my ( $method, $extend ) = @$movement;
			$editor->$method($extend);
			return $self->cursor_moved;
		}
		if ( my $edit = $EDIT_BY_KEY{$name} ) {
			return 0 if $read_only;
			return $self->apply_edit( $editor->$edit );
		}
		if ( $name eq 'Ctrl+A' ) {
			$editor->select_all;
			return $self->cursor_moved;
		}
		if ( $name eq 'Ctrl+Insert' ) {
			$editor->copy;
			return 1;
		}
		return 0;
	}

	method cursor_moved () {
		$self->scroll_to_cursor;
		$self->repaint;
		return 1;
	}

	# After an editor edit: shows the result and fires Change when the text
	# changed. Returns 1, the key was used either way.
	method apply_edit ($changed) {
		$self->cursor_moved;
		$self->fire_change( $editor->text ) if $changed;
		return 1;
	}

	# ---------------------------------------------------------------------
	# Mouse: a press places the cursor (Shift extends the selection), a
	# double click selects a word, dragging selects.
	# ---------------------------------------------------------------------

	method handle_mouse ($event) {
		my $key = $event->key;
		if ( $key == TB_KEY_MOUSE_RELEASE ) {
			$dragging = 0;
			return 1;
		}
		return 0 unless $key == TB_KEY_MOUSE_LEFT;

		my ( $column, $row ) = $self->cell_at($event);
		return 1 unless defined $column;
		my @position = $self->position_at( $column, $row );

		if ( $event->modifiers & TB_MOD_MOTION ) {
			$editor->move_to( @position, 1 ) if $dragging;
			return $self->cursor_moved;
		}

		my $now = time;
		if ( @last_press && $now - $last_press[0] <= DOUBLE_CLICK_SECONDS && "@last_press[1, 2]" eq "@position" ) {
			$editor->select_word_at(@position);
			@last_press = ();
		}
		else {
			$editor->move_to( @position, $event->modifiers & TB_MOD_SHIFT ? 1 : 0 );
			@last_press = ( $now, @position );
		}
		$dragging = 1;
		return $self->cursor_moved;
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	method size_changed :override () {
		$self->scroll_to_cursor;
		$self->repaint;
		return;
	}

	method focus_changed :override ($is_focused) {
		$dragging = 0;
		$self->repaint;
		return;
	}

	# How a cluster of the text is shown; a password field masks it.
	method display_cluster ($cluster) {
		return sanitize_text($cluster);
	}

	# The clusters of a line between two boundaries, as
	# [ $offset, $display_cluster, $columns ].
	method clusters_between ( $row, $from, $to ) {
		my $line       = $editor->line($row);
		my @boundaries = grep { $_ >= $from && $_ <= $to } $editor->boundaries($row);
		return map {
			my $display = $self->display_cluster( substr( $line, $boundaries[$_], $boundaries[ $_ + 1 ] - $boundaries[$_] ) );
			[ $boundaries[$_], $display, cluster_columns($display) ]
		} 0 .. $#boundaries - 1;
	}

	# Columns from the start of a line part to an offset inside it.
	method columns_to ( $row, $from, $offset ) {
		my $columns = 0;
		$columns += $_->[2] foreach $self->clusters_between( $row, $from, $offset );
		return $columns;
	}

	# The boundary of the part [from, to) of a line shown at a column:
	# the start of the cluster covering it, or $to past the end.
	method offset_at_column ( $row, $from, $to, $column ) {
		my $x = 0;
		foreach my $cluster ( $self->clusters_between( $row, $from, $to ) ) {
			return $cluster->[0] if $column < $x + $cluster->[2];
			$x += $cluster->[2];
		}
		return $to;
	}

	sub _is_selected ( $selection, $row, $offset ) {
		my ( $row_0, $offset_0, $row_1, $offset_1 ) = @$selection;
		return 0 unless defined $row_0;
		return 0 if $row < $row_0 || ( $row == $row_0 && $offset < $offset_0 );
		return 0 if $row > $row_1 || ( $row == $row_1 && $offset >= $offset_1 );
		return 1;
	}

	# Paints the part [from, to) of a line on buffer row $y, scrolled left
	# by $scroll columns, with the selection and (when $cursor_at_end allows
	# a cursor at $to) the cursor. Returns the column after the text.
	method paint_line_part ( $y, $row, $from, $to, $scroll, $cursor_at_end ) {
		my $width      = $self->columns;
		my @selection  = $editor->selection;
		my ( $cursor_row, $cursor_offset ) = $editor->cursor;
		my $has_cursor = $self->is_focused && $cursor_row == $row;
		my $fg         = $self->foreground_attr;
		my $bg         = $self->focus_background_attr;
		my $selected   = $self->color_attr($selection_color);

		my $x = -$scroll;
		foreach my $cluster ( $self->clusters_between( $row, $from, $to ) ) {
			my ( $offset, $display, $columns ) = @$cluster;
			my $cell_bg = _is_selected( \@selection, $row, $offset ) ? $selected : $bg;
			my $cell_fg = $has_cursor && $offset == $cursor_offset ? $self->reverse_attr($fg) : $fg;
			$self->put_attrs( $x, $y, $display, $cell_fg, $cell_bg ) if $x >= 0 && $x + $columns <= $width;
			$x += $columns;
		}
		$self->put_attrs( $x, $y, ' ', $self->reverse_attr($fg), $bg )
			if $has_cursor && $cursor_at_end && $cursor_offset == $to && $x >= 0 && $x < $width;
		return $x;
	}

	method paint_placeholder ($y) {
		my $bg = $self->focus_background_attr;
		$self->paint_text( 0, $y, $placeholder, $self->color_attr($placeholder_color), $bg );
		return unless $self->is_focused;

		my ($first) = grapheme_clusters($placeholder);
		$self->put_attrs( 0, $y, $first // ' ', $self->reverse_attr( $self->foreground_attr ), $bg );
		return;
	}

	method shows_placeholder () {
		return $editor->is_empty && length $placeholder;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::TextInput - Abstract base class of the text input widgets

=head1 DESCRIPTION

The common part of L<Term::Fabulous::Widget::TextField> and
L<Term::Fabulous::Widget::TextArea>: a L<Term::Fabulous::Editor> holding
the text, the cursor, the selection and the undo history, the editing
keys, mouse selection and the painting of text with its selection and
cursor. The text is a Perl character string, not UTF-8 bytes.

The focused widget shows a block cursor (the character under it in
reverse video) and paints its content in C<focus_background_color>.
Selected text is shown on C<selection_color>.

=head1 CONSTRUCTOR

Unknown parameters die. Besides the parameters of
L<Term::Fabulous::Widget::Input>, text inputs accept:

=over

=item C<value>

The initial text, default empty. The cursor starts at its end.

=item C<placeholder>

A hint shown in C<placeholder_color> while the text is empty; default
none.

=item C<max_length>

The most characters (grapheme clusters, line breaks included) the text
may hold, or C<undef> (the default) for no limit. Typing and pasting
stop at the limit; setting a longer C<value> dies.

=item C<read_only>

Boolean, default 0. A read-only input can be focused, and its text can
be selected and copied, but not changed by the user.

=item C<placeholder_color>, C<selection_color>

Colors as for L<Term::Fabulous::Widget::Input>.

=item C<background_color>

Defaults to a dark gray, so the input stands out from its surroundings.

=back

=head1 METHODS

=head2 value

	my $text = $input->value;
	$input->value("new text");

Reader and writer of the text. Writing puts the cursor at the end,
clears the selection and the undo history, and fires no event.

=head2 editor

The L<Term::Fabulous::Editor> holding the text, for programmatic cursor
and selection changes. Call C<repaint> after changing it.

=head2 max_length, placeholder, read_only, placeholder_color, selection_color

Readers and writers of the constructor parameters.

=head1 KEYS

=over

=item Typing

Inserts the character at the cursor, replacing the selection.

=item Left, Right, Home, End

Move the cursor by a character or to the start or end of the line. With
Ctrl, Left and Right move by words, Home and End to the start or end of
the text. With Shift, every movement extends the selection.

=item Ctrl+A

Selects everything.

=item Backspace, Delete

Delete the selection, or the character before or after the cursor.
Ctrl+W deletes the word before the cursor, Ctrl+Delete the word after
it, Ctrl+U everything before the cursor in its line and Ctrl+K
everything after it.

=item Ctrl+X, Ctrl+V, Ctrl+Insert, Shift+Delete, Shift+Insert

Cut, paste and copy through the clipboard of L<Term::Fabulous::Editor>,
which all text inputs of the process share. Ctrl+C is not copy: it
stops L<Term::Fabulous>.

=item Ctrl+Z, Ctrl+Y

Undo and redo. Typing is undone a word at a time.

=back

Keys the input does not use, such as Tab, Escape and function keys,
bubble to its ancestors. While C<read_only> is set, typing and the
editing keys bubble too.

=head1 MOUSE

A left click places the cursor; with Shift it extends the selection.
Dragging selects, a double click selects a word.

=head1 EVENTS

L<Term::Fabulous::Event::Change> after every change the user makes to
the text, with the new text as its C<value>.

=head1 SUBCLASS INTERFACE

Subclasses implement C<scroll_to_cursor> (keep the cursor visible),
C<position_at($column, $row)> (the editor position at a buffer cell),
C<is_multi_line> (a class method, whether the editor keeps line
breaks), and the C<natural_size> and C<paint> methods of
L<Term::Fabulous::Widget::Input>. They paint with
C<paint_line_part($y, $row, $from, $to, $scroll, $cursor_at_end)>,
C<paint_placeholder($y)> and C<paint_focus_background>, and measure with
C<clusters_between>, C<columns_to> and C<offset_at_column>.
C<display_cluster> decides how a cluster is shown. C<handle_key> may be
extended; call C<cursor_moved> after moving the cursor and
C<apply_edit($changed)> after an edit.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Input/KDL PROPERTIES> plus C<value>,
C<placeholder>, C<max_length>, C<read_only>, C<placeholder_color> and
C<selection_color>.

=cut
