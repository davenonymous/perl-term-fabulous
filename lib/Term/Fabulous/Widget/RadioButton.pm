package Term::Fabulous::Widget::RadioButton;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Input;

our $VERSION = '0.01';

class Term::Fabulous::Widget::RadioButton
	:isa(Term::Fabulous::Widget::Input)
	:strict(params)
{
	use List::Util qw(max);
	use Scalar::Util qw(refaddr);
	use Term::Fabulous::Unicode qw(string_columns);

	field $label           :param = '';
	field $value           :param = undef;
	field $selected_mark   :param = "(\x{2022})";
	field $unselected_mark :param = '( )';

	ADJUST {
		$self->_checked_string( $_->[0], $_->[1] ) foreach [ label => $label ], [ selected_mark => $selected_mark ], [ unselected_mark => $unselected_mark ];
		die "Term::Fabulous::Widget::RadioButton: value must be a string or number, got " . ref $value if ref $value;
	}

	method _checked_string ( $name, $text ) {
		die "Term::Fabulous::Widget::RadioButton: $name must be a string, got " . ( ref $text || 'undef' ) unless defined $text && !ref $text;
		return $text;
	}

	method _set_string ( $name, $field_ref, @new ) {
		return $$field_ref unless @new;
		$$field_ref = $self->_checked_string( $name => $new[0] );
		$self->repaint;
		return $$field_ref;
	}

	method label (@new)           { return $self->_set_string( label           => \$label,           @new ) }
	method selected_mark (@new)   { return $self->_set_string( selected_mark   => \$selected_mark,   @new ) }
	method unselected_mark (@new) { return $self->_set_string( unselected_mark => \$unselected_mark, @new ) }

	# The value defaults to the label.
	method value (@new) {
		return $value // $label unless @new;
		die "Term::Fabulous::Widget::RadioButton: value must be a string or number, got " . ref $new[0] if ref $new[0];
		$value = $new[0];
		$self->repaint;
		return $value // $label;
	}

	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(label value selected_mark unselected_mark) );
	}

	# The group takes the focus for its buttons.
	method accepts_focus () {
		return 0;
	}

	method group () {
		for ( my $node = $self->parent; defined $node; $node = $node->parent ) {
			return $node if $node->isa('Term::Fabulous::Widget::RadioGroup');
		}
		return undef;
	}

	method is_selected () {
		my $group = $self->group;
		return defined $group && $group->holds_value( $self->value ) ? 1 : 0;
	}

	method is_enabled :override () {
		my $group = $self->group;
		return $self->SUPER::is_enabled && ( !defined $group || $group->is_enabled );
	}

	method focus_background_attr :override () {
		my $group = $self->group;
		return undef unless defined $group && $group->is_focused;
		my $cursor = $group->cursor_button;
		return undef unless defined $cursor && refaddr($cursor) == refaddr($self);
		return $self->color_attr( $self->focus_background_color );
	}

	method natural_size () {
		my $mark_columns = max map { string_columns($_) } $selected_mark, $unselected_mark;
		return ( $mark_columns + ( length $label ? 1 + string_columns($label) : 0 ), 1 );
	}

	method paint () {
		my $bg       = $self->paint_focus_background;
		my $selected = $self->is_selected;
		my $x        = $self->paint_text( 0, 0, $selected ? $selected_mark : $unselected_mark, $selected ? $self->accent_attr : $self->foreground_attr, $bg );
		$self->paint_text( $x + 1, 0, $label, $self->foreground_attr, $bg ) if length $label;
		return;
	}

	method activate () {
		my $group = $self->group // die "Term::Fabulous::Widget::RadioButton: a radio button must be inside a Term::Fabulous::Widget::RadioGroup";
		$group->choose($self);
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::RadioButton - One choice of a radio group

=head1 SYNOPSIS

	my $button = Term::Fabulous::Widget::RadioButton->new( label => 'Medium', value => 'm' );
	$group->add_child($button);

=head1 DESCRIPTION

An L<Term::Fabulous::Widget::Input> showing a mark and a label,
C<(E<0x2022>) Medium>, inside a L<Term::Fabulous::Widget::RadioGroup>,
which keeps track of the selected button, takes the keyboard focus and
fires the C<Change> event. A click selects the button. Clicking a radio
button outside a group dies. Unknown constructor parameters die.

A radio button is disabled when it or its group is.

=head1 CONSTRUCTOR

Besides the parameters of L<Term::Fabulous::Widget::Input>:

=over

=item C<label>

The text after the mark, a character string; default none.

=item C<value>

The value the group takes when the button is selected, a string or a
number; defaults to the label. The values of a group's buttons should
differ: the group selects every button whose value equals its own.

=item C<selected_mark>, C<unselected_mark>

The marks, by default C<(E<0x2022>)> and C<( )>. The selected mark is
painted in the accent color.

=back

All have readers and writers of the same name.

=head1 METHODS

=head2 group

The nearest L<Term::Fabulous::Widget::RadioGroup> ancestor, or C<undef>.

=head2 is_selected

Whether the group's value equals the button's value.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Input/KDL PROPERTIES> plus C<label>,
C<value>, C<selected_mark> and C<unselected_mark>.

=cut
