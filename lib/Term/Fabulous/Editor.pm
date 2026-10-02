package Term::Fabulous::Editor;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

class Term::Fabulous::Editor :strict(params) {
	use List::Util qw(sum0);
	use Term::Fabulous::Unicode qw(grapheme_clusters);

	use constant UNDO_LIMIT           => 100;
	use constant BOUNDARY_CACHE_LIMIT => 4096;

	# Grapheme cluster boundaries (character offsets) of a line, shared by
	# every editor. Lines are segmented as the renderer segments them.
	my %boundaries_by_line;

	# Shared by every editor of the process, like a desktop clipboard.
	my $clipboard = '';

	field $multi_line :param :reader = 1;
	field $max_length :param = undef;

	field @lines = ('');

	# Positions are [row, offset]: a line index and a character offset that
	# is a grapheme cluster boundary of that line. The anchor is the other
	# end of the selection; it is empty when nothing is selected.
	field @cursor = ( 0, 0 );
	field @anchor;

	# Counts text changes, so views can cache what they derive from the text.
	field $revision :reader = 0;

	field @undo_stack;
	field @redo_stack;

	# The kind of the last undo step when typing may extend it: 'word' or
	# 'space'; undef when the next edit starts a new step.
	field $typing_run;

	ADJUST :params ( :$text = '' ) {
		$self->set_max_length($max_length);
		$self->set_text($text);
	}

	sub _describe ($value) {
		return defined $value ? "'$value'" : 'undef';
	}

	sub _boundaries ($line) {
		my $boundaries = $boundaries_by_line{$line};
		return $boundaries if defined $boundaries;

		%boundaries_by_line = () if keys(%boundaries_by_line) >= BOUNDARY_CACHE_LIMIT;
		my @offsets = (0);
		push @offsets, $offsets[-1] + length $_ foreach grapheme_clusters($line);
		return $boundaries_by_line{$line} = \@offsets;
	}

	sub _compare ( $row_a, $offset_a, $row_b, $offset_b ) {
		return $row_a <=> $row_b || $offset_a <=> $offset_b;
	}

	# ---------------------------------------------------------------------
	# Text
	# ---------------------------------------------------------------------

	# Line breaks become "\n"; a single-line editor turns them into spaces.
	method _normalize ($text) {
		die "Term::Fabulous::Editor: text must be a string, got " . ( ref $text || 'undef' ) unless defined $text && !ref $text;
		$text =~ s/\r\n?/\n/g;
		$text =~ tr/\n/ / unless $multi_line;
		return $text;
	}

	sub _cluster_count ($text) {
		return sum0 map { scalar( @{ _boundaries($_) } ) - 1 } split /\n/, $text, -1;
	}

	method text () {
		return join "\n", @lines;
	}

	method set_text ($text) {
		$text = $self->_normalize($text);
		my $length = _cluster_count($text) + ( $text =~ tr/\n// );
		die "Term::Fabulous::Editor: the text has $length characters, more than max_length $max_length"
			if defined $max_length && $length > $max_length;

		@lines = split /\n/, $text, -1;
		@lines = ('') unless @lines;
		@cursor = ( $#lines, length $lines[-1] );
		@anchor = ();
		@undo_stack = @redo_stack = ();
		$typing_run = undef;
		$revision++;
		return $self;
	}

	method lines () {
		return @lines;
	}

	method line ($row) {
		return $lines[$row];
	}

	method line_count () {
		return scalar @lines;
	}

	method boundaries ($row) {
		return @{ _boundaries( $lines[$row] ) };
	}

	# In grapheme clusters; every line break counts as one.
	method character_count () {
		return sum0( map { scalar( @{ _boundaries($_) } ) - 1 } @lines ) + $#lines;
	}

	method max_length () {
		return $max_length;
	}

	# undef removes the limit; a limit below the current length dies.
	method set_max_length ($limit) {
		die "Term::Fabulous::Editor: max_length must be a non-negative integer or undef, got " . _describe($limit)
			if defined $limit && !( !ref $limit && $limit =~ /\A[0-9]+\z/ );
		die "Term::Fabulous::Editor: the text has " . $self->character_count . " characters, more than max_length $limit"
			if defined $limit && $self->character_count > $limit;
		$max_length = defined $limit ? $limit + 0 : undef;
		return $self;
	}

	method is_empty () {
		return @lines == 1 && $lines[0] eq '';
	}

	# ---------------------------------------------------------------------
	# Cursor and selection
	# ---------------------------------------------------------------------

	method cursor () {
		return @cursor;
	}

	method has_selection () {
		return @anchor && _compare( @anchor, @cursor ) != 0 ? 1 : 0;
	}

	method selection () {
		return () unless $self->has_selection;
		return _compare( @anchor, @cursor ) < 0 ? ( @anchor, @cursor ) : ( @cursor, @anchor );
	}

	method selected_text () {
		my ( $row_0, $offset_0, $row_1, $offset_1 ) = $self->selection;
		return '' unless defined $row_0;
		return $self->_text_between( $row_0, $offset_0, $row_1, $offset_1 );
	}

	method _text_between ( $row_0, $offset_0, $row_1, $offset_1 ) {
		return substr( $lines[$row_0], $offset_0, $offset_1 - $offset_0 ) if $row_0 == $row_1;
		return join "\n", substr( $lines[$row_0], $offset_0 ), @lines[ $row_0 + 1 .. $row_1 - 1 ], substr( $lines[$row_1], 0, $offset_1 );
	}

	# The boundary at or before (direction -1) or after (+1) an offset.
	method _snap ( $row, $offset, $direction ) {
		my $boundaries = _boundaries( $lines[$row] );
		return $boundaries->[-1] if $offset >= $boundaries->[-1];
		return 0 if $offset <= 0;
		my $index = 0;
		$index++ while $boundaries->[ $index + 1 ] <= $offset;
		return $boundaries->[$index] if $boundaries->[$index] == $offset || $direction < 0;
		return $boundaries->[ $index + 1 ];
	}

	method _clamped_position ( $row, $offset ) {
		die "Term::Fabulous::Editor: a position needs integer row and offset, got " . _describe($row) . ', ' . _describe($offset)
			unless grep( { defined && !ref && /\A-?[0-9]+\z/ } $row, $offset ) == 2;
		$row = 0 if $row < 0;
		$row = $#lines if $row > $#lines;
		return ( $row, $self->_snap( $row, $offset, -1 ) );
	}

	# Moves the cursor; with $extend the selection grows from where the
	# cursor was, otherwise it is cleared.
	method move_to ( $row, $offset, $extend = 0 ) {
		my @target = $self->_clamped_position( $row, $offset );
		if ($extend) {
			@anchor = @cursor unless @anchor;
		}
		else {
			@anchor = ();
		}
		@cursor     = @target;
		$typing_run = undef;
		return $self;
	}

	method set_selection ( $anchor_row, $anchor_offset, $cursor_row, $cursor_offset ) {
		my @from = $self->_clamped_position( $anchor_row, $anchor_offset );
		$self->move_to( $cursor_row, $cursor_offset );
		@anchor = @from;
		return $self;
	}

	method select_all () {
		return $self->set_selection( 0, 0, $#lines, length $lines[-1] );
	}

	method clear_selection () {
		@anchor = ();
		return $self;
	}

	# The word (or, between words, the single cluster) starting at or
	# covering a position. A cluster belongs to a word when its first
	# character is a word character.
	method select_word_at ( $row, $offset ) {
		( $row, $offset ) = $self->_clamped_position( $row, $offset );
		my $line       = $lines[$row];
		my @boundaries = @{ _boundaries($line) };
		return $self->move_to( $row, $offset ) if @boundaries == 1;

		my @is_word = map { substr( $line, $boundaries[$_], 1 ) =~ /\w/ ? 1 : 0 } 0 .. $#boundaries - 1;
		my ($index) = grep { $boundaries[$_] <= $offset } reverse 0 .. $#is_word;    # the last cluster at the end

		my ( $first, $last ) = ( $index, $index );
		if ( $is_word[$index] ) {
			$first-- while $first > 0 && $is_word[ $first - 1 ];
			$last++  while $last < $#is_word && $is_word[ $last + 1 ];
		}
		return $self->set_selection( $row, $boundaries[$first], $row, $boundaries[ $last + 1 ] );
	}

	method _position_left_of ( $row, $offset ) {
		return ( $row - 1, length $lines[ $row - 1 ] ) if $offset == 0 && $row > 0;
		return ( $row, $self->_snap( $row, $offset - 1, -1 ) );
	}

	method _position_right_of ( $row, $offset ) {
		return ( $row + 1, 0 ) if $offset == length( $lines[$row] ) && $row < $#lines;
		return ( $row, $self->_snap( $row, $offset + 1, 1 ) );
	}

	# Start of the word before the position, crossing to the previous line
	# from the start of a line.
	method _word_start_before ( $row, $offset ) {
		return ( $row - 1, length $lines[ $row - 1 ] ) if $offset == 0 && $row > 0;
		my $start = substr( $lines[$row], 0, $offset ) =~ /(\w+)\W*\z/ ? $-[1] : 0;
		return ( $row, $self->_snap( $row, $start, -1 ) );
	}

	# End of the word after the position, crossing to the next line from
	# the end of a line.
	method _word_end_after ( $row, $offset ) {
		my $line = $lines[$row];
		return ( $row + 1, 0 ) if $offset == length($line) && $row < $#lines;
		my $end = substr( $line, $offset ) =~ /\A\W*\w+/ ? $offset + $+[0] : length $line;
		return ( $row, $self->_snap( $row, $end, 1 ) );
	}

	# Without $extend, a selection collapses to its start (left) or end
	# (right) instead of moving.
	method move_left ( $extend = 0 ) {
		my @selection = $self->selection;
		return $self->move_to( @selection[ 0, 1 ] ) if @selection && !$extend;
		return $self->move_to( $self->_position_left_of(@cursor), $extend );
	}

	method move_right ( $extend = 0 ) {
		my @selection = $self->selection;
		return $self->move_to( @selection[ 2, 3 ] ) if @selection && !$extend;
		return $self->move_to( $self->_position_right_of(@cursor), $extend );
	}

	method move_word_left ( $extend = 0 ) {
		return $self->move_to( $self->_word_start_before(@cursor), $extend );
	}

	method move_word_right ( $extend = 0 ) {
		return $self->move_to( $self->_word_end_after(@cursor), $extend );
	}

	method move_line_start ( $extend = 0 ) {
		return $self->move_to( $cursor[0], 0, $extend );
	}

	method move_line_end ( $extend = 0 ) {
		return $self->move_to( $cursor[0], length $lines[ $cursor[0] ], $extend );
	}

	method move_document_start ( $extend = 0 ) {
		return $self->move_to( 0, 0, $extend );
	}

	method move_document_end ( $extend = 0 ) {
		return $self->move_to( $#lines, length $lines[-1], $extend );
	}

	# ---------------------------------------------------------------------
	# Editing. Every edit returns whether the text changed; an edit that
	# changes it can be undone.
	# ---------------------------------------------------------------------

	method _snapshot () {
		return { lines => [@lines], cursor => [@cursor], anchor => [@anchor] };
	}

	method _restore ($snapshot) {
		@lines  = @{ $snapshot->{lines} };
		@cursor = @{ $snapshot->{cursor} };
		@anchor = @{ $snapshot->{anchor} };
		$typing_run = undef;
		$revision++;
		return;
	}

	# Runs an edit and records an undo step when it changed the text. Typing
	# extends the last step while the typed text stays words or stays
	# spaces, so undo takes back a word at a time.
	method _edit ( $run, $code ) {
		my $before = $self->_snapshot;
		my $text   = $self->text;
		$code->();
		if ( $self->text eq $text ) {
			$typing_run = undef;
			return 0;
		}

		my $extends_step = defined $run && defined $typing_run && $run eq $typing_run && @undo_stack;
		push @undo_stack, $before unless $extends_step;
		shift @undo_stack while @undo_stack > UNDO_LIMIT;
		@redo_stack = ();
		$typing_run = $run;
		$revision++;
		return 1;
	}

	# Replaces the text between two ordered positions; the cursor ends up
	# after the new text, without a selection.
	method _replace ( $row_0, $offset_0, $row_1, $offset_1, $text ) {
		my @new_lines = split /\n/, $text, -1;
		@new_lines = ('') unless @new_lines;
		my $after = substr( $lines[$row_1], $offset_1 );
		$new_lines[0] = substr( $lines[$row_0], 0, $offset_0 ) . $new_lines[0];
		my @end = ( $row_0 + $#new_lines, length $new_lines[-1] );
		$new_lines[-1] .= $after;

		splice @lines, $row_0, $row_1 - $row_0 + 1, @new_lines;
		@cursor = ( $end[0], $self->_snap( @end, 1 ) );
		@anchor = ();
		return;
	}

	method _delete_selection () {
		my @selection = $self->selection;
		return 0 unless @selection;
		$self->_replace( @selection, '' );
		return 1;
	}

	# The longest prefix of $text that keeps the editor within max_length
	# once the selection is replaced.
	method _fitting ($text) {
		return $text unless defined $max_length;
		my $selected = $self->selected_text;
		my $room     = $max_length - $self->character_count + _cluster_count($selected) + ( $selected =~ tr/\n// );
		return '' if $room <= 0;

		my ( $taken, $length ) = ( 0, 0 );
		foreach my $line ( split /(\n)/, $text ) {
			my @offsets = @{ _boundaries($line) };
			my $clusters = $line eq "\n" ? 1 : $#offsets;
			if ( $taken + $clusters > $room ) {
				$length += $offsets[ $room - $taken ] if $line ne "\n";
				return substr( $text, 0, $length );
			}
			$taken  += $clusters;
			$length += length $line;
		}
		return $text;
	}

	# The selection, or the empty range at the cursor.
	method _replaced_range () {
		my @range = $self->selection;
		return @range ? @range : ( @cursor, @cursor );
	}

	method insert ($text) {
		$text = $self->_fitting( $self->_normalize($text) );
		return 0 unless length $text || $self->has_selection;
		return $self->_edit( undef, sub { $self->_replace( $self->_replaced_range, $text ) } );
	}

	# Like insert, for text the user types: consecutive typing is undone
	# word by word.
	method type ($text) {
		$text = $self->_fitting( $self->_normalize($text) );
		return 0 unless length $text;
		my $run = $text =~ /\A\s+\z/ ? 'space' : 'word';
		return $self->_edit( $run, sub { $self->_replace( $self->_replaced_range, $text ) } );
	}

	method _delete_to ( $row, $offset ) {
		return $self->_edit(
			undef,
			sub {
				return if $self->_delete_selection;
				my @range = _compare( $row, $offset, @cursor ) < 0 ? ( $row, $offset, @cursor ) : ( @cursor, $row, $offset );
				$self->_replace( @range, '' );
			}
		);
	}

	method delete_backward () {
		return $self->_delete_to( $self->_position_left_of(@cursor) );
	}

	method delete_forward () {
		return $self->_delete_to( $self->_position_right_of(@cursor) );
	}

	method delete_word_backward () {
		return $self->_delete_to( $self->_word_start_before(@cursor) );
	}

	method delete_word_forward () {
		return $self->_delete_to( $self->_word_end_after(@cursor) );
	}

	# At the start (end) of a line, joins it with the previous (next) one.
	method delete_to_line_start () {
		return $self->delete_backward if $cursor[1] == 0 && !$self->has_selection;
		return $self->_delete_to( $cursor[0], 0 );
	}

	method delete_to_line_end () {
		return $self->delete_forward if $cursor[1] == length( $lines[ $cursor[0] ] ) && !$self->has_selection;
		return $self->_delete_to( $cursor[0], length $lines[ $cursor[0] ] );
	}

	# ---------------------------------------------------------------------
	# Clipboard
	# ---------------------------------------------------------------------

	method clipboard :common (@new) {
		return $clipboard unless @new;
		die "Term::Fabulous::Editor: the clipboard holds a string, got " . ( ref $new[0] || 'undef' ) unless defined $new[0] && !ref $new[0];
		return $clipboard = $new[0];
	}

	method copy () {
		return 0 unless $self->has_selection;
		$clipboard = $self->selected_text;
		return 1;
	}

	method cut () {
		return 0 unless $self->has_selection;
		$clipboard = $self->selected_text;
		return $self->_edit( undef, sub { $self->_delete_selection } );
	}

	method paste () {
		return $self->insert($clipboard);
	}

	# ---------------------------------------------------------------------
	# Undo
	# ---------------------------------------------------------------------

	method can_undo () {
		return @undo_stack ? 1 : 0;
	}

	method can_redo () {
		return @redo_stack ? 1 : 0;
	}

	method undo () {
		return 0 unless @undo_stack;
		push @redo_stack, $self->_snapshot;
		$self->_restore( pop @undo_stack );
		return 1;
	}

	method redo () {
		return 0 unless @redo_stack;
		push @undo_stack, $self->_snapshot;
		$self->_restore( pop @redo_stack );
		return 1;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Editor - Text, cursor, selection and undo of a text input

=head1 SYNOPSIS

	use Term::Fabulous::Editor;

	my $editor = Term::Fabulous::Editor->new( text => "Hello\nworld" );
	$editor->move_document_start;
	$editor->move_word_right(1);         # select "Hello"
	$editor->type('Goodbye');            # replaces the selection
	$editor->undo;
	say $editor->text;                   # "Hello\nworld"

=head1 DESCRIPTION

The editing model behind L<Term::Fabulous::Widget::TextField> and
L<Term::Fabulous::Widget::TextArea>, without any drawing: a list of
lines, a cursor, a selection, an undo history and a clipboard. Widgets
translate key presses into these methods and draw the result.

Text is a Perl character string, not UTF-8 bytes. The cursor moves by
grapheme clusters (what a reader sees as one character, such as C<e>
followed by a combining accent, or a flag), segmented exactly as the
renderer segments text, and words are runs of C<\w> characters.
Unknown constructor parameters die.

=head1 CONSTRUCTOR

=head2 new

	my $editor = Term::Fabulous::Editor->new( text => '', multi_line => 1, max_length => undef );

=over

=item C<text>

The initial text, see C<set_text>.

=item C<multi_line>

Boolean, default 1. A single-line editor turns every line break it is
given into a space.

=item C<max_length>

The most grapheme clusters the text may hold (every line break counts
as one), or C<undef> (the default) for no limit. Inserted text is cut
to fit; C<set_text> dies on a longer text.

=back

=head1 POSITIONS

A position is a line index (C<$row>, from 0) and a character offset
into that line (C<$offset>) that lies on a grapheme cluster boundary.
Methods that take a position clamp it to the text and move an offset
inside a cluster to the start of that cluster; non-integer values die.

=head1 METHODS

=head2 Text

=over

=item C<text>, C<set_text($text)>

The whole text, lines joined with C<"\n">. C<set_text> replaces it,
turns C<"\r\n"> and C<"\r"> into C<"\n">, puts the cursor at the end,
clears the selection and the undo history, and returns the editor.
It dies when the text is not a string or is longer than C<max_length>.

=item C<lines>, C<line($row)>, C<line_count>

The lines of the text, without line breaks; there is always at least
one.

=item C<boundaries($row)>

The grapheme cluster boundaries of a line as character offsets, from 0
to the length of the line.

=item C<character_count>

The number of grapheme clusters, line breaks included.

=item C<is_empty>

Whether the text is the empty string.

=item C<max_length>, C<set_max_length($limit)>

The length limit, see L</new>. C<set_max_length> takes a non-negative
integer or C<undef> for no limit, dies when the text is already longer,
and returns the editor.

=item C<revision>

A number that changes whenever the text changes, for caching what is
derived from the text.

=back

=head2 Cursor and selection

=over

=item C<cursor>

C<($row, $offset)> of the cursor.

=item C<move_to($row, $offset, $extend = 0)>

Moves the cursor. With C<$extend> true the selection reaches from where
it started (the cursor position before the first extending move) to
the new position, otherwise the selection is cleared.

=item C<move_left($extend)>, C<move_right($extend)>

One grapheme cluster, crossing line breaks. Without C<$extend>, a
selection collapses to its start (left) or end (right) instead.

=item C<move_word_left($extend)>, C<move_word_right($extend)>

To the start of the word before the cursor, or to the end of the word
after it. From the start (end) of a line, they cross to the previous
(next) line.

=item C<move_line_start($extend)>, C<move_line_end($extend)>, C<move_document_start($extend)>, C<move_document_end($extend)>

=item C<set_selection($anchor_row, $anchor_offset, $cursor_row, $cursor_offset)>, C<select_all>, C<clear_selection>

=item C<select_word_at($row, $offset)>

Selects the word of the cluster at the position (the last cluster at
the end of the line), or that single cluster when it is not part of a
word. A cluster is part of a word when its first character matches
C<\w>.

=item C<has_selection>, C<selection>, C<selected_text>

C<selection> returns the ordered positions C<($row_0, $offset_0,
$row_1, $offset_1)>, or the empty list. A selection is never empty.

=back

The movement and selection methods return the editor.

=head2 Editing

Every edit returns 1 when it changed the text and 0 otherwise. Edits
that change the text replace the selection, if there is one, leave no
selection behind and can be undone.

=over

=item C<insert($text)>

Inserts text at the cursor (replacing the selection), cut to
C<max_length>. Line breaks are normalized as in C<set_text>.

=item C<type($text)>

Like C<insert>, for text the user types: consecutive typing forms one
undo step per word and per run of spaces.

=item C<delete_backward>, C<delete_forward>

The selection, or else the cluster (or line break) before or after the
cursor.

=item C<delete_word_backward>, C<delete_word_forward>

The selection, or else up to the start of the word before the cursor
or the end of the word after it.

=item C<delete_to_line_start>, C<delete_to_line_end>

The selection, or else up to the start or end of the line; at the
start (end) of a line, the line break before (after) it.

=back

=head2 Clipboard

=over

=item C<copy>, C<cut>, C<paste>

C<copy> and C<cut> put the selected text on the clipboard and return 1,
or return 0 without a selection. C<paste> inserts the clipboard.

=item C<clipboard>

	my $text = Term::Fabulous::Editor->clipboard;
	Term::Fabulous::Editor->clipboard($text);

The clipboard, shared by all editors of the process. Set it to connect
it to another clipboard.

=back

=head2 Undo

=over

=item C<undo>, C<redo>

Take back the last edit, or redo the last undone one, restoring the
cursor and selection as well. Return 1, or 0 when there is nothing to
undo or redo. Up to 100 steps are kept; a new edit clears the redo
steps.

=item C<can_undo>, C<can_redo>

=back

=cut
