package Term::Fabulous::ThemeEditor::StatusBar;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Display;

# The last row of the theme editor: a message on the left, in the color
# of its kind, and what the editor shows now on the right.
class Term::Fabulous::ThemeEditor::StatusBar :isa(Term::Fabulous::Widget::Display) :strict(params) {
	use List::Util qw(sum0);
	use Term::Fabulous::Unicode qw(string_columns);

	# code: the right side as [ text, kind ] parts, read for every frame
	field $info :param;

	field $message = '';
	field $kind    = 'info';

	my %SLOT_OF_KIND = (
		info   => [ input => 'text' ], success => [ toast => 'success' ], warning => [ toast => 'warning' ], error => [ toast => 'danger' ], dim => [ input => 'placeholder' ],
		accent => [ input => 'accent' ]
	);

	method natural_size () {
		return ( 0, 1 );
	}

	# Shows a message of a kind: info, success, warning or error.
	method message ( $text, $new_kind = 'info' ) {
		die "Term::Fabulous::ThemeEditor::StatusBar: unknown kind '$new_kind'" unless $SLOT_OF_KIND{$new_kind};
		( $message, $kind ) = ( $text =~ s/\s+/ /gr =~ s/\A | \z//gr, $new_kind );    # one row: no line breaks
		$self->mark_changed;
		return $self;
	}

	method text () {
		return $message;
	}

	method kind () {
		return $kind;
	}

	method _attr ($part_kind) {
		return $self->color_attr( $self->family_look( @{ $SLOT_OF_KIND{$part_kind} } ) );
	}

	method paint_key :override () {
		return ( $self->SUPER::paint_key, $message, $kind, map { @$_ } $info->() );
	}

	method paint () {
		my $background = $self->color_attr( $self->family_look( dropdown => 'list.background' ) );
		$self->fill_attrs( 0, 0, $self->columns, ' ', $self->_attr('info'), $background );
		my @parts = $info->();
		my $right = 1 + sum0( map { string_columns( $_->[0] ) } @parts );
		my $x     = $self->columns - $right;
		foreach my $part (@parts) {
			$x = $self->paint_text( $x, 0, $part->[0], $self->_attr( $part->[1] ), $background );
		}
		my $room  = $self->columns - $right - 3;
		my $shown = $message;
		if ( string_columns($shown) > $room ) {    # cut, with a ~ to say so
			chop $shown while length $shown && string_columns($shown) > $room - 1;
			$shown .= '~';
		}
		$self->paint_text( 1, 0, $shown, $self->_attr($kind), $background );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::StatusBar - The status line of the theme
editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. One row: a message on the left (cut with a C<~> when it does not
fit), drawn in the color of its kind
(the theme's C<toast> colors for C<success>, C<warning> and C<error>),
and on the right what a code reference returns, as C<[ text, kind ]>
parts (kinds C<info>, C<dim>, C<accent>, C<success>, C<warning>,
C<error>), read whenever a frame is drawn.

=head1 METHODS

=head2 message

	$status->message( 'Saved ocean.kdl.', 'success' );

Shows a message of a kind; the message stays until the next one.

=head2 text, kind

The message shown and its kind.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
