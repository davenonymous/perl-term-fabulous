package Term::Fabulous::Widget::FileDialog::FolderLine;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Display;

our $VERSION = '0.03';

class Term::Fabulous::Widget::FileDialog::FolderLine
	:isa(Term::Fabulous::Widget::Display)
	:strict(params)
{
	use Clay::XS qw(sizing_grow);
	use List::Util qw(max min);
	use Term::Fabulous::Check qw(string);
	use Term::Fabulous::Unicode qw(fit_columns string_columns);

	use constant CUT       => '...';
	use constant PATH_ROOM => 10;

	field $label :param = 'Folder: ';
	field $path  :param = '';
	field $after :param = '';

	ADJUST {
		$label = string( $self, label => $label );
		$path  = string( $self, path  => $path );
		$after = string( $self, after => $after );
	}

	method path (@new) {
		return $path unless @new;
		$path = string( $self, path => $new[0] );
		$self->mark_changed;
		return $path;
	}

	# Sets the three parts at once, for a line that says something new.
	method say ( $new_label, $new_path = '', $new_after = '' ) {
		$label = string( $self, label => $new_label );
		$path  = string( $self, path  => $new_path );
		$after = string( $self, after => $new_after );
		$self->mark_changed;
		return $self;
	}

	method text () {
		return $label . $path . $after;
	}

	method natural_size () {
		return ( sizing_grow(), 1 );
	}

	# The label, then as much of the end of the path as fits in front of
	# the text after it. On a narrow line the path keeps some room
	# (PATH_ROOM columns) and the text after it is cut at the right.
	method paint () {
		my $color = $self->color_attr( $self->family_look( text => 'color' ) );
		my $x     = $self->paint_text( 0, 0, $label, $color, undef );
		my $room  = $self->columns - $x;
		$x = $self->paint_text( $x, 0, fit_columns( $path, max( $room - string_columns($after), min( $room, PATH_ROOM ) ), mark => CUT, cut => 'start' ), $color, undef );
		$self->paint_text( $x, 0, $after, $color, undef );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::FileDialog::FolderLine - The line that names
the folder a file dialog shows, and its message line

=head1 DESCRIPTION

This class is internal to L<Term::Fabulous::Widget::FileDialog>.
Applications never create one themselves.

It is a L<Term::Fabulous::Widget::Display> one row high that grows to
the width of its parent and paints a label (C<Folder:>), a path and a
text after the path in the theme's C<text.color>. When the path does
not fit the width the line gets, its start is cut off and replaced by
C<...> (by L<Term::Fabulous::Unicode/fit_columns>), so the end of the
path, the folder itself, stays in view; with fewer than three columns
for the path, the C<...> is cut to them. On a
line too narrow for the label, ten columns of the path and the text
after it, the path keeps up to ten columns and the text after it is
cut at the right; a label too long for the line is cut at the right.

The file dialog uses one for the folder it shows and one for its
message line, which names a path the same way (C<There is no file>,
the path, C<in this folder.>) and is one row high even when it says
nothing.

=head1 CONSTRUCTOR

=head2 new

	my $line = Term::Fabulous::Widget::FileDialog::FolderLine->new( path => '/home/ada/notes' );

Accepts the parameters of L<Term::Fabulous::Widget::Display> and three
character strings: C<label> (default C<'Folder: '>), C<path> (default
C<''>) and C<after> (default C<''>). Unknown parameters die.

=head1 METHODS

=head2 path

	$line->path('/home/ada');

Accessor for the path. Writing paints the line again with the next
frame.

=head2 say

	$line->say( 'There is no file ', 'notes/todo.txt', ' in this folder.' );

Sets the label, the path and the text after it (the last two default
to C<''>) and paints the line again with the next frame. Returns the
line.

=head2 text

	my $text = $line->text;

The whole text of the line, uncut: the label, the path and the text
after it.

=head1 SEE ALSO

L<Term::Fabulous::Widget::FileDialog>.

=cut
