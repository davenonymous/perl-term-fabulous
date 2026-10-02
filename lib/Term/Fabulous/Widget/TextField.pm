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
		return $preferred_columns = $self->_checked_preferred_columns( $new[0] );
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
	$name->on( Submit => sub ($event) { greet( $event->value ); return } );

	my $password = Term::Fabulous::Widget::TextField->new( mask => '*' );

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::TextInput> for one line of text. Text wider
than the field scrolls sideways to keep the cursor visible. Line breaks
in pasted or assigned text become spaces. Unknown constructor
parameters die.

See L<Term::Fabulous::Widget::TextInput> for the C<value>, the editing
keys, mouse selection and the C<Change> event.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::TextInput>:

=over

=item C<preferred_columns>

The width of the text area in columns when the C<layout> gives the
field no width; a positive integer, default 20. The field is one row
high unless the layout says otherwise.

=item C<mask>

A character, one column wide, shown instead of every character of the
text, for passwords; default C<undef> (the text is shown). Masking
hides the text only on the screen: C<value> and copying through the
clipboard still return it.

=back

Both have readers and writers of the same name.

=head1 KEYS

The keys of L<Term::Fabulous::Widget::TextInput/KEYS>, plus Enter,
which fires L<Term::Fabulous::Event::Submit> with the text. Up, Down,
Page Up and Page Down are not used and bubble.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::TextInput/KDL PROPERTIES> plus
C<preferred_columns> and C<mask>:

	TextField "email" {
		placeholder "name@example.com"
		preferred_columns 30
	}

=cut
