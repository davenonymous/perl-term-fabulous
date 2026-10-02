package Term::Fabulous::Widget::Checkbox;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Checkbox
	:isa(Term::Fabulous::Widget::Input)
	:strict(params)
{
	use List::Util qw(max);
	use Term::Fabulous::Unicode qw(string_columns);

	field $label              :param = '';
	field $checked            :param = 0;
	field $indeterminate      :param = 0;
	field $checked_mark       :param = '[x]';
	field $unchecked_mark     :param = '[ ]';
	field $indeterminate_mark :param = '[-]';

	ADJUST {
		$self->_checked_string( $_->[0], $_->[1] )
			foreach [ label => $label ], [ checked_mark => $checked_mark ], [ unchecked_mark => $unchecked_mark ], [ indeterminate_mark => $indeterminate_mark ];
		( $checked, $indeterminate ) = ( $checked ? 1 : 0, $indeterminate ? 1 : 0 );
	}

	method _checked_string ( $name, $value ) {
		die "Term::Fabulous::Widget::Checkbox: $name must be a string, got " . ( ref $value || 'undef' ) unless defined $value && !ref $value;
		return $value;
	}

	method _set_string ( $name, $field_ref, @new ) {
		return $$field_ref unless @new;
		$$field_ref = $self->_checked_string( $name => $new[0] );
		$self->repaint;
		return $$field_ref;
	}

	method label (@new)              { return $self->_set_string( label              => \$label,              @new ) }
	method checked_mark (@new)       { return $self->_set_string( checked_mark       => \$checked_mark,       @new ) }
	method unchecked_mark (@new)     { return $self->_set_string( unchecked_mark     => \$unchecked_mark,     @new ) }
	method indeterminate_mark (@new) { return $self->_set_string( indeterminate_mark => \$indeterminate_mark, @new ) }

	method checked (@new) {
		return $checked unless @new;
		$checked       = $new[0] ? 1 : 0;
		$indeterminate = 0;
		$self->repaint;
		return $checked;
	}

	method indeterminate (@new) {
		return $indeterminate unless @new;
		$indeterminate = $new[0] ? 1 : 0;
		$self->repaint;
		return $indeterminate;
	}

	method value () {
		return $checked;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(label checked indeterminate checked_mark unchecked_mark indeterminate_mark) );
	}

	method _mark () {
		return $indeterminate ? $indeterminate_mark : $checked ? $checked_mark : $unchecked_mark;
	}

	method natural_size () {
		my $mark_columns = max map { string_columns($_) } $checked_mark, $unchecked_mark, $indeterminate_mark;
		return ( $mark_columns + ( length $label ? 1 + string_columns($label) : 0 ), 1 );
	}

	method paint () {
		my $bg = $self->paint_focus_background;
		my $mark_fg = $checked || $indeterminate ? $self->accent_attr : $self->foreground_attr;
		my $x       = $self->paint_text( 0, 0, $self->_mark, $mark_fg, $bg );
		$self->paint_text( $x + 1, 0, $label, $self->foreground_attr, $bg ) if length $label;
		return;
	}

	method toggle () {
		$self->checked( $indeterminate || !$checked );
		$self->fire_change($checked);
		return $self;
	}

	method handle_key ($event) {
		my $name = $event->key_name // return 0;
		return 0 unless $name eq 'Space' || $name eq 'Enter';
		$self->toggle;
		return 1;
	}

	method activate () {
		$self->toggle;
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::Checkbox - A box the user can check

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Checkbox;

	my $terms = Term::Fabulous::Widget::Checkbox->new( label => 'I accept the terms' );
	$terms->on( Change => sub ($event) { $submit->disabled( !$event->value ); return } );

=head1 DESCRIPTION

An L<Term::Fabulous::Widget::Input> showing a check mark followed by a
label, C<[x] I accept the terms>. Space, Enter and a click toggle it.
Unknown constructor parameters die.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::Input>:

=over

=item C<label>

The text after the mark, a character string; default none.

=item C<checked>

Boolean, default 0.

=item C<indeterminate>

Boolean, default 0: shows the indeterminate mark whatever C<checked>
says, for a box that stands for a group of mixed states. Checking or
unchecking clears it.

=item C<checked_mark>, C<unchecked_mark>, C<indeterminate_mark>

The marks, by default C<[x]>, C<[ ]> and C<[-]>. A checked or
indeterminate mark is painted in the accent color.

=back

All have readers and writers of the same name; writing C<checked>
clears C<indeterminate>. Writing fires no event.

=head1 METHODS

=head2 value

The same as C<checked>.

=head2 toggle

Checks an unchecked or indeterminate box and unchecks a checked one,
as the user does, and fires C<Change>. Returns the checkbox.

=head1 EVENTS

L<Term::Fabulous::Event::Change> when the user toggles the box, with
C<checked> (1 or 0) as its value.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Input/KDL PROPERTIES> plus the
constructor parameters above:

	Checkbox "newsletter" {
		label "Send me the newsletter"
		checked #true
	}

=cut
