package Term::Fabulous::Widget::TextField;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::TextInput;

our $VERSION = '0.01';

class Term::Fabulous::Widget::TextField
	:isa(Term::Fabulous::Widget::TextInput)
	:strict(params)
{
	use Term::Fabulous::Event::Submit;
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	field $preferred_columns :param = 20;
	field $mask              :param = undef;

	# Columns of the text scrolled out of view on the left; always the
	# start of a cluster.
	field $scroll = 0;

	ADJUST {
		$self->_checked_preferred_columns($preferred_columns);
		$self->_checked_mask($mask);
	}

	method _checked_preferred_columns ($columns) {
		die "Term::Fabulous::Widget::TextField: preferred_columns must be a positive integer, got " . ( defined $columns ? "'$columns'" : 'undef' )
			unless defined $columns && !ref $columns && $columns =~ /\A[0-9]+\z/ && $columns > 0;
		return $columns + 0;
	}

	method _checked_mask ($glyph) {
		return undef unless defined $glyph;
		my @clusters = !ref $glyph ? grapheme_clusters($glyph) : ();
		die "Term::Fabulous::Widget::TextField: mask must be a single character one column wide, got " . ( ref $glyph || "'$glyph'" )
			unless @clusters == 1 && cluster_columns( $clusters[0] ) == 1;
		return $glyph;
	}

	method preferred_columns (@new) {
		return $preferred_columns unless @new;
		$preferred_columns = $self->_checked_preferred_columns( $new[0] );
		$self->mark_changed;
		return $preferred_columns;
	}

	method mask (@new) {
		return $mask unless @new;
		$mask = $self->_checked_mask( $new[0] );
		$self->scroll_to_cursor;
		$self->repaint;
		return $mask;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(preferred_columns mask) );
	}

	method natural_size () {
		return ( $preferred_columns, 1 );
	}

	method display_cluster :override ($cluster) {
		return $mask // $self->SUPER::display_cluster($cluster);
	}

	method handle_key :override ($event) {
		return $self->SUPER::handle_key($event) unless ( $event->key_name // '' ) eq 'Enter';
		$self->fire_event( Term::Fabulous::Event::Submit->new( value => $self->value ) );
		return 1;
	}

	# Scrolls just enough to show the cursor (and the cell after the text
	# when the cursor is there), and no further than needed to fill the
	# field.
	method scroll_to_cursor () {
		my $width = $self->columns;
		return $scroll = 0 if $width < 1;

		my $editor = $self->editor;
		my ( undef, $offset ) = $editor->cursor;
		my @clusters = $self->clusters_between( 0, 0, length $editor->line(0) );
		my ( $cursor_x, $cursor_columns, $x ) = ( undef, 1, 0 );
		foreach my $cluster (@clusters) {
			( $cursor_x, $cursor_columns ) = ( $x, $cluster->[2] ) if $cluster->[0] == $offset;
			$x += $cluster->[2];
		}
		$cursor_x //= $x;

		my $last_scroll = $x + 1 - $width;
		$scroll = $last_scroll if $scroll > $last_scroll;
		$scroll = $cursor_x                           if $cursor_x < $scroll;
		$scroll = $cursor_x + $cursor_columns - $width if $cursor_x + $cursor_columns > $scroll + $width;
		$scroll = 0 if $scroll < 0;

		# Start the view at a cluster, never inside a wide one.
		my $start = 0;
		foreach my $cluster (@clusters) {
			last if $start >= $scroll;
			$start += $cluster->[2];
		}
		$scroll = $start;
		return $scroll;
	}

	method position_at ( $column, $row ) {
		my $editor = $self->editor;
		return ( 0, $self->offset_at_column( 0, 0, length $editor->line(0), $column + $scroll ) );
	}

	method paint () {
		$self->paint_focus_background;
		return $self->paint_placeholder(0) if $self->shows_placeholder;
		$self->paint_line_part( 0, 0, 0, length $self->editor->line(0), $scroll, 1 );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::TextField - Single-line text input

=head1 SYNOPSIS

	use Term::Fabulous::Widget::TextField;

	my $name = Term::Fabulous::Widget::TextField->new(
		id          => 'name',
		placeholder => 'Your name',
		max_length  => 40,
	);
	$name->on( Submit => sub ($event) {
		say 'Hello, ', $event->value;
		return;
	} );

	my $password = Term::Fabulous::Widget::TextField->new(
		id   => 'password',
		mask => '*',
	);

	say $name->value;    # the text, a character string

=begin html

<p><img src="/screenshots/widget-text-field.svg" alt="Four text fields: Ada Lovelace being typed, a placeholder, a masked password and a disabled field"></p>

=end html

=head1 DESCRIPTION

A text field holds one line of text that the user can type, edit, select
and copy. When the text is wider than the field, the field scrolls
sideways to keep the cursor visible. Line breaks never get into the
text: in pasted or assigned text they become spaces. Pressing C<Enter>
fires a L<Term::Fabulous::Event::Submit>.

The text is a Perl character string (decoded text), not UTF-8 encoded
bytes.

The editing keys, mouse selection, the placeholder, C<max_length>,
C<read_only> and the C<Change> event are the same as in the text area
and are described in L<Term::Fabulous::Widget::TextInput>. Disabling,
colors and sizing are described in L<Term::Fabulous::Widget::Input>.

=head1 CONSTRUCTOR

=head2 new

	my $field = Term::Fabulous::Widget::TextField->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::TextInput/CONSTRUCTOR>
(C<value>, C<placeholder>, C<max_length>, C<read_only>,
C<placeholder_color>, C<selection_color>, C<background_color>) and of
L<Term::Fabulous::Widget::Input/CONSTRUCTOR> (C<id>, C<layout>,
C<disabled>, C<can_focus>, C<text_color>, C<disabled_color>,
C<accent_color>, C<focus_background_color>, the border parameters), plus
the two below. Unknown parameters die.

=over

=item C<preferred_columns>

A positive integer. Default: 20. The width of the text in columns when
the C<layout> gives the field no width. The field is one row high unless
the C<layout> gives it a height. Padding and border are added to these
sizes. Dies if not a positive integer.

=item C<mask>

A single character that is one column wide, or C<undef>. Default:
C<undef> (the text is shown). When set, every character of the text is
shown as this character, for passwords. The mask only hides the text on
the screen: C<value>, the C<Change> and C<Submit> events and copying to
the clipboard still give the real text. Dies if the mask is not exactly
one grapheme cluster one column wide.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::TextInput/METHODS> (C<value>,
C<max_length>, C<placeholder>, C<read_only>, C<placeholder_color>,
C<selection_color>, C<editor>, C<cursor_moved>) and of
L<Term::Fabulous::Widget::Input/METHODS> (C<disabled>, C<is_enabled>,
the color accessors, C<repaint>), plus:

=head2 preferred_columns

	my $columns = $field->preferred_columns;
	$field->preferred_columns(30);

Accessor for the C<preferred_columns> parameter. A new value takes
effect at the next frame. Writing returns the new value. Dies if not a
positive integer; the old value then stays.

=head2 mask

	$field->mask('*');      # hide the text
	$field->mask(undef);    # show it again

Accessor for the C<mask> parameter. Writing repaints the field and
returns the new mask. A mask that is not a single one-column character
dies; the old mask then stays.

=head1 KEYS

All keys of L<Term::Fabulous::Widget::TextInput/KEYS>, plus:

=over

=item C<Enter>

Fires L<Term::Fabulous::Event::Submit> with the text. The key is used
(it does not bubble). This also happens when the field is C<read_only>.

=back

C<Up>, C<Down>, C<PageUp> and C<PageDown> are not used by a text field
and bubble to its ancestors, as do C<Escape>, C<Tab>, the function keys
and every other key not listed in L<Term::Fabulous::Widget::TextInput/KEYS>.

=head1 MOUSE

As described in L<Term::Fabulous::Widget::TextInput/MOUSE>: click to
place the cursor, drag (while the pointer stays over the input) to
select, double-click to select a word. The mouse wheel is not used.

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> after every change the user makes to
the text; C<< $event->value >> is the new text.

=item C<Submit>

L<Term::Fabulous::Event::Submit> when the user presses C<Enter>;
C<< $event->value >> is the text.

=back

Neither is fired for changes made by the program. Both bubble to the
ancestors (see L<Term::Fabulous::Manual/Return values and bubbling>).

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::TextInput/KDL PROPERTIES>,
plus C<preferred_columns> and C<mask>:

	use Term::Fabulous::Widget::TextField as TextField

	TextField "email" {
		placeholder "name@example.com"
		preferred_columns 30
		max_length 80
	}

=head1 EXAMPLES

=head2 A search field that reacts to Enter and to typing

	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_grow);
	use Term::Fabulous::Widget::TextField;

	my $search = Term::Fabulous::Widget::TextField->new(
		id          => 'search',
		placeholder => 'Search (Enter to run)',
		layout      => { sizing => { width => sizing_grow() } },
	);
	$search->on( Change => sub ($event) {
		show_suggestions( $event->value );
		return Clay::UI::Enum::Result->CONTINUE;
	} );
	$search->on( Submit => sub ($event) {
		run_search( $event->value );
		return;
	} );

=head2 A password field that is enabled by a checkbox

	use Term::Fabulous::Widget::Checkbox;

	my $password = Term::Fabulous::Widget::TextField->new( mask => '*', disabled => 1 );
	my $enable   = Term::Fabulous::Widget::Checkbox->new( label => 'Set a password' );
	$enable->on( Change => sub ($event) {
		$password->disabled( !$event->value );
		return;
	} );

=head2 Give the field the focus when the program starts

	my $ui = Term::Fabulous->new( root => $root, width => 80, height => 24 );
	$ui->interaction->set_focused_widget($name);
	$ui->run;

=head1 SEE ALSO

L<Term::Fabulous::Widget::TextInput>, L<Term::Fabulous::Widget::TextArea>,
L<Term::Fabulous::Event::Submit>,
L<Term::Fabulous::Manual/FORMS AND INPUT WIDGETS>.

=cut
