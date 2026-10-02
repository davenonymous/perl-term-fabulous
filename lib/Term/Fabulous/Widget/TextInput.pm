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
	use Feature::Compat::Try;
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE TB_MOD_MOTION TB_MOD_SHIFT);
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
		$read_only = $read_only ? 1 : 0;
		$self->_checked_placeholder($placeholder);
		$self->_checked_color( placeholder_color => $placeholder_color );
		$self->_checked_color( selection_color   => $selection_color );
		$self->background_color( [ @{ +DEFAULT_BACKGROUND } ] ) unless defined $self->background_color;
		$self->max_length($max_length) if defined $max_length;
		$self->value($value)           if defined $value;
	}

	# Runs an editor call for a public method; the editor's errors are
	# reworded to name this widget, which is the class the caller used.
	method _in_editor ($code) {
		try {
			return $code->();
		}
		catch ($error) {
			$error =~ s/\ATerm::Fabulous::Editor:/ref($self) . ':'/e;
			die $error;
		}
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
		$self->_in_editor( sub { $editor->set_text( $new[0] ) } );
		$self->scroll_to_cursor;
		$self->repaint;
		return $editor->text;
	}

	method max_length (@new) {
		return $editor->max_length unless @new;
		$self->_in_editor( sub { $editor->set_max_length( $new[0] ) } );
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

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, 'read_only' );
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

Term::Fabulous::Widget::TextInput - Common base class of the text input widgets

=head1 SYNOPSIS

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::TextField;

	# The parameters and methods below work the same for both text inputs:
	my $field = Term::Fabulous::Widget::TextField->new(
		value             => 'initial text',
		placeholder       => 'Type here',
		max_length        => 40,
		read_only         => 0,
		placeholder_color => '#787e8a',
		selection_color   => [ 38, 79, 120 ],
	);

	my $text = $field->value;          # a character string
	$field->value('replaced');         # fires no Change event

	$field->on( Change => sub ($event) {
		say 'now: ', $event->value;
		return Clay::UI::Enum::Result->CONTINUE;
	} );

=head1 DESCRIPTION

C<Term::Fabulous::Widget::TextInput> is the abstract base class of
L<Term::Fabulous::Widget::TextField> (one line) and
L<Term::Fabulous::Widget::TextArea> (several lines). It holds what both
have in common: the text with its cursor, selection, undo history and
clipboard (kept in a L<Term::Fabulous::Editor>), the editing keys, mouse
selection, the placeholder and the C<read_only> mode. You do not create
a C<TextInput> directly; its C<new> dies.

The text is a Perl character string (decoded text), not UTF-8 encoded
bytes. The cursor moves by grapheme clusters, that is by what a reader
sees as one character (a letter with a combining accent, an emoji with
modifiers, a flag), and wide characters such as CJK take two columns.

While the input has the focus, its content is painted on
C<focus_background_color> and the cursor is shown as a block: the
character under it in reverse video. Selected text is painted on
C<selection_color>. While the text is empty, the C<placeholder> is
shown instead, in C<placeholder_color>.

Everything described for L<Term::Fabulous::Widget::Input> applies as
well: C<disabled>, the colors, focus, sizing and the C<Change> event.

=head1 CONSTRUCTOR

=head2 new

	my $field = Term::Fabulous::Widget::TextField->new(%parameters);
	my $area  = Term::Fabulous::Widget::TextArea->new(%parameters);

The text inputs accept the parameters of
L<Term::Fabulous::Widget::Input/CONSTRUCTOR> and these. Unknown
parameters die.

=over

=item C<value>

A character string. Default: C<''>. The initial text. The cursor starts
at its end. A text field turns line breaks into spaces; a text area
converts C<"\r\n"> and C<"\r"> to C<"\n">. Dies if the text is longer
than C<max_length>.

=item C<placeholder>

A character string. Default: C<''> (none). A hint shown in
C<placeholder_color> while the text is empty. It is never part of the
C<value>.

=item C<max_length>

A non-negative integer, or C<undef>. Default: C<undef> (no limit). The
most characters the text may hold, counted in grapheme clusters; in a
text area every line break counts as one. Typing and pasting stop at the
limit: pasted text is cut to fit. Dies if the initial C<value> is longer.

=item C<read_only>

A boolean, stored as 1 or 0. Default: 0. A read-only input can still take the focus, and
its text can be selected and copied, but the user cannot change it:
typing and the editing keys are not used and bubble on to the
ancestors. Programmatic writes to C<value> still work.

=item C<placeholder_color>

A color, in any format L<Term::Fabulous::Widget::Input> accepts.
Default: C<[120, 126, 138, 255]>, a gray.

=item C<selection_color>

A color, in any format L<Term::Fabulous::Widget::Input> accepts. The
background of selected text. Default: C<[38, 79, 120, 255]>, a dark blue.

=item C<background_color>

An C<[r, g, b, a]> array reference or C<{ r, g, b, a }> hash reference.
Default: C<[36, 40, 48, 255]>, a dark gray, so the input stands out from
its surroundings. Pass C<[0, 0, 0, 0]> for no background of its own.

=back

=head1 METHODS

=head2 value

	my $text = $input->value;
	$input->value("new text");

Accessor for the text, a character string. Writing replaces the whole
text, puts the cursor at its end, clears the selection and the undo
history, repaints, and returns the new text (after line-break
conversion). It fires no C<Change> event. Dies if the new text is not a
string or is longer than C<max_length>.

=head2 max_length

	my $limit = $input->max_length;
	$input->max_length(10);
	$input->max_length(undef);         # no limit

Accessor for the length limit (see the C<max_length> parameter). Returns
the new limit. Dies if the limit is not a non-negative integer or
C<undef>, or if the current text is already longer; the limit then stays as it
was.

=head2 placeholder

	$input->placeholder('Search');

Accessor for the placeholder text. Writing repaints the input and
returns the new placeholder; a value that is not a string dies and
leaves the placeholder unchanged.

=head2 read_only

	my $is_read_only = $input->read_only;
	$input->read_only(1);

Accessor for the C<read_only> flag. Returns a true or false value: the
writer stores and returns 1 or 0, but a value passed to C<new> is
returned exactly as it was given. Any value is accepted.

=head2 placeholder_color

	$input->placeholder_color('#888888');

Accessor for the placeholder color. Writing repaints and returns the
new color (as given); an invalid color dies and leaves the color
unchanged.

=head2 selection_color

	$input->selection_color([ 60, 60, 120 ]);

Accessor for the selection background. Writing repaints and returns
the new color (as given); an invalid color dies and leaves the color
unchanged.

=head2 editor

	my $editor = $input->editor;

The L<Term::Fabulous::Editor> that holds the text, the cursor, the
selection and the undo history. Use it to move the cursor, select or
edit text from your program. Afterwards call C<< $input->cursor_moved >>,
which scrolls the cursor into view and repaints. Edits made through the
editor fire no C<Change> event.

	$field->editor->select_all;
	$field->cursor_moved;

	$area->editor->move_document_start;
	$area->editor->insert("Dear Sir or Madam,\n");
	$area->cursor_moved;

=head2 cursor_moved

	$input->cursor_moved;

Scrolls the view so the cursor is visible and repaints. Call it after
changing the cursor, the selection or the text through L</editor>.
Returns 1.

=head1 KEYS

The keys below are named as L<Term::Fabulous::Event::KeyPress/key_name>
returns them. A text input uses them while it has the focus and is
enabled; they then do not bubble. All other keys bubble on to the
ancestors: for example C<Escape>, C<Tab>, C<BackTab> (C<Shift+Tab>),
C<F1> to C<F12> and C<Alt+> combinations. L<Term::Fabulous> moves the
focus on C<Tab> and C<BackTab> and stops on C<Ctrl+C>, after the key
has been delivered.

=over

=item Typing

A printable character (pressed without C<Ctrl> or C<Alt>) is inserted at
the cursor, replacing the selection.

=item C<Left>, C<Right>

Move the cursor one character left or right, across line breaks. With a
selection, they move to its start (C<Left>) or end (C<Right>) and clear
it.

=item C<Ctrl+Left>, C<Ctrl+Right>

Move to the start of the word before the cursor, or to the end of the
word after it. Words are runs of letters, digits and C<_>.

=item C<Home>, C<End>

Move to the start or end of the line (in a text area: of the text
line, not of the wrapped row).

=item C<Ctrl+Home>, C<Ctrl+End>

Move to the start or end of the whole text.

=item C<Shift+Left>, C<Shift+Right>, C<Ctrl+Shift+Left>, C<Ctrl+Shift+Right>, C<Shift+Home>, C<Shift+End>, C<Ctrl+Shift+Home>, C<Ctrl+Shift+End>

The movements above, extending the selection.

=item C<Ctrl+A>

Selects the whole text.

=item C<Backspace>, C<Delete>

Delete the selection, or else the character before (C<Backspace>) or
after (C<Delete>) the cursor.

=item C<Ctrl+W>, C<Ctrl+Delete>

Delete the selection, or else the word before (C<Ctrl+W>) or after
(C<Ctrl+Delete>) the cursor.

=item C<Ctrl+U>, C<Ctrl+K>

Delete the selection, or else everything from the start of the line to
the cursor (C<Ctrl+U>) or from the cursor to the end of the line
(C<Ctrl+K>). At the very start (end) of a line, they delete the line
break before (after) it.

=item C<Ctrl+X>, C<Shift+Delete>

Cut: copy the selection to the clipboard and delete it.

=item C<Ctrl+Insert>

Copy the selection to the clipboard. C<Ctrl+C> is not copy: it stops
L<Term::Fabulous>.

=item C<Ctrl+V>, C<Shift+Insert>

Paste the clipboard at the cursor, replacing the selection.

=item C<Ctrl+Z>, C<Ctrl+Y>

Undo and redo. Consecutive typing is undone one word (or one run of
spaces) at a time; up to 100 steps are kept.

=back

The clipboard is the one of L<Term::Fabulous::Editor/clipboard>: one
string shared by all text inputs of the program. It is not the system
clipboard.

While C<read_only> is set, typing and the keys that change the text
(C<Backspace>, C<Delete>, C<Ctrl+W>, C<Ctrl+Delete>, C<Ctrl+U>,
C<Ctrl+K>, C<Ctrl+X>, C<Shift+Delete>, C<Ctrl+V>, C<Shift+Insert>,
C<Ctrl+Z>, C<Ctrl+Y>) are not used and bubble; movement, selection and
copying still work.

L<Term::Fabulous::Widget::TextField> and
L<Term::Fabulous::Widget::TextArea> add keys of their own (C<Enter>,
C<Up>, C<Down>, ...); see their KEYS sections.

=head1 MOUSE

=over

=item Click

A left click places the cursor at the clicked character and focuses the
input. The terminal does not report C<Shift>, C<Ctrl> or C<Alt> with
mouse events, so there is no Shift+click selection; drag instead.

=item Double click

A second left click at the same position within 0.4 seconds selects the
word there (or the single character, when it is not part of a word).

=item Drag

Moving the pointer with the left button held selects from where the
button went down to the pointer, as long as the pointer stays over the
input.

=back

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> after every change the user makes to
the text (typing, deleting, cutting, pasting, undo, redo), with the new
text as its C<value>. Keys that do not change the text (cursor
movement, copying, typing at C<max_length>) fire nothing. Programmatic
changes through C<value> or C<editor> fire nothing.

=back

L<Term::Fabulous::Widget::TextField> also fires
L<Term::Fabulous::Event::Submit> on C<Enter>.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Input/KDL PROPERTIES>, plus
C<value>, C<placeholder>, C<max_length>, C<read_only> (C<#true> /
C<#false>), C<placeholder_color> and C<selection_color>. Give
C<max_length> before C<value>; in the opposite order a too long value is
accepted first and the C<max_length> property then dies.

	TextField "nick" {
		max_length 12
		value "guest"
		placeholder "Nickname"
	}

=head1 SUBCLASS INTERFACE

L<Term::Fabulous::Widget::TextField> and
L<Term::Fabulous::Widget::TextArea> implement these; a new kind of text
input would too.

=head2 is_multi_line

	method is_multi_line :common () { return 1 }

Class method. Whether the editor keeps line breaks (1) or turns them
into spaces (0, the default).

=head2 scroll_to_cursor

	method scroll_to_cursor () { ... }

Required. Adjusts the input's scroll position so the cursor is visible.

=head2 position_at

	method position_at ( $column, $row ) { return ( $line, $offset ) }

Required. The editor position (line index and character offset, see
L<Term::Fabulous::Editor/POSITIONS>) shown at a cell of the buffer.
Used for mouse clicks.

=head2 natural_size

	method natural_size () { return ( $preferred_columns, 1 ) }

Required; see L<Term::Fabulous::Widget::Input/natural_size>.

=head2 paint

	method paint () { ... }

Required; see L<Term::Fabulous::Widget::Input/paint>.

=head2 display_cluster

	method display_cluster ($cluster) { return $shown }

How one grapheme cluster of the text is shown. The default replaces
control characters (see L<Term::Fabulous::Unicode/sanitize_text>); the
text field returns its C<mask> instead when one is set.

=head2 clusters_between

	my @clusters = $self->clusters_between( $line, $from, $to );

The grapheme clusters of a line between two character offsets, as
C<[ $offset, $display_cluster, $columns ]> array references.

=head2 columns_to

	my $columns = $self->columns_to( $line, $from, $offset );

The columns the text of a line takes from offset C<$from> to C<$offset>.

=head2 offset_at_column

	my $offset = $self->offset_at_column( $line, $from, $to, $column );

The offset of the cluster shown at C<$column> when the part
C<[$from, $to)> of a line is painted from column 0; C<$to> for a column
past its end.

=head2 paint_line_part

	my $next_x = $self->paint_line_part( $y, $line, $from, $to, $scroll, $cursor_at_end );

Paints the part C<[$from, $to)> of a line on buffer row C<$y>, shifted
left by C<$scroll> columns, with the selection and the cursor. The
cursor is drawn after the last character only when C<$cursor_at_end> is
true. Returns the column after the text.

=head2 paint_placeholder

	$self->paint_placeholder($y);

Paints the placeholder on buffer row C<$y>, with the cursor on its first
character while the input has the focus.

=head2 shows_placeholder

	return $self->paint_placeholder(0) if $self->shows_placeholder;

True while the text is empty and there is a placeholder.

=head2 apply_edit

	return $self->apply_edit( $self->editor->insert($text) );

Call after an editor edit made on behalf of the user: scrolls to the
cursor, repaints, and fires C<Change> when the argument is true (the
editor's edit methods return whether the text changed). Returns 1, so it
can be returned from C<handle_key> directly.

=head1 SEE ALSO

L<Term::Fabulous::Widget::TextField>, L<Term::Fabulous::Widget::TextArea>,
L<Term::Fabulous::Editor>, L<Term::Fabulous::Widget::Input>.

=cut
