package Term::Fabulous::Widget::Checkbox;

use v5.24;
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

	method boolean_layout_properties :override () {
		return ( $self->SUPER::boolean_layout_properties, qw(checked indeterminate) );
	}

	method _mark () {
		return $indeterminate ? $indeterminate_mark : $checked ? $checked_mark : $unchecked_mark;
	}

	# The columns reserved for the mark: those of the widest one, so the
	# label stays in place when the mark changes.
	method _mark_columns () {
		return max map { string_columns($_) } $checked_mark, $unchecked_mark, $indeterminate_mark;
	}

	method natural_size () {
		return ( $self->_mark_columns + ( length $label ? 1 + string_columns($label) : 0 ), 1 );
	}

	method paint () {
		my $bg = $self->paint_focus_background;
		my $mark_fg = $checked || $indeterminate ? $self->accent_attr : $self->foreground_attr;
		$self->paint_text( 0, 0, $self->_mark, $mark_fg, $bg );
		$self->paint_text( $self->_mark_columns + 1, 0, $label, $self->foreground_attr, $bg ) if length $label;
		return;
	}

	method toggle () {
		$self->checked( $indeterminate || !$checked );
		$self->fire_change($checked);
		return $self;
	}

	method handle_key ($event) {
		my $name = $event->main_key_name // return 0;
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

Term::Fabulous::Widget::Checkbox - A box the user can check and uncheck

=head1 SYNOPSIS

	use Clay::UI::Enum::Result;
	use Term::Fabulous::Widget::Checkbox;

	my $terms = Term::Fabulous::Widget::Checkbox->new(
		id    => 'terms',
		label => 'I accept the terms',
	);
	$terms->on( Change => sub ($event) {
		say $event->value ? "accepted" : "declined";
		return Clay::UI::Enum::Result->CONTINUE;
	} );

	say $terms->checked ? 'accepted' : 'not accepted';
	$terms->checked(1);    # programmatic: fires no Change

=begin html

<p><img src="/screenshots/widget-checkbox.svg" alt="Five check boxes: focused, unchecked, checked, indeterminate and disabled"></p>

=end html

=head1 DESCRIPTION

A checkbox shows a mark followed by a label:

	[x] I accept the terms
	[ ] Send me the newsletter
	[-] Some of the items

The user toggles it with C<Space>, C<Enter> or a mouse click. Its value
is 1 (checked) or 0 (unchecked).

A checkbox can also be I<indeterminate>: it then shows the indeterminate
mark (C<[-]>) whatever C<checked> says, which is useful for a box that
stands for a group of other boxes, some checked and some not. Toggling
an indeterminate box checks it.

Disabling, colors, focus and sizing are described in
L<Term::Fabulous::Widget::Input>. The checkbox is one row high and as
wide as its widest mark plus a space and the label, unless the
C<layout> sizes it.

=head1 CONSTRUCTOR

=head2 new

	my $checkbox = Term::Fabulous::Widget::Checkbox->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::Input/CONSTRUCTOR>
(C<id>, C<layout>, C<background_color>, the border parameters,
C<disabled>, C<can_focus>, C<text_color>, C<disabled_color>,
C<accent_color>, C<focus_background_color>) and the ones below. Unknown
parameters die.

=over

=item C<label>

A character string. Default: C<''> (no label, only the mark). The text
after the mark, painted in C<text_color>. Dies if not a string.

=item C<checked>

A boolean. Default: 0. Whether the box starts checked. Stored as 1 or 0.

=item C<indeterminate>

A boolean. Default: 0. Whether the box starts indeterminate (see
L</DESCRIPTION>). Stored as 1 or 0.

=item C<checked_mark>

A character string. Default: C<'[x]'>. The mark of a checked box,
painted in C<accent_color>. Dies if not a string.

=item C<unchecked_mark>

A character string. Default: C<'[ ]'>. The mark of an unchecked box,
painted in C<text_color>. Dies if not a string.

=item C<indeterminate_mark>

A character string. Default: C<'[-]'>. The mark of an indeterminate box,
painted in C<accent_color>. Dies if not a string.

=back

The label is painted after the width of the widest mark, so it stays
in place when the box is toggled, even with marks of different widths.

=head1 METHODS

The methods of L<Term::Fabulous::Widget::Input/METHODS> (C<disabled>,
C<is_enabled>, the color accessors, C<repaint>), plus:

=head2 checked

	my $is_checked = $checkbox->checked;
	$checkbox->checked(1);

Accessor. Returns 1 or 0. Writing sets the state, clears
C<indeterminate>, repaints, and returns the new state. Writing fires no
C<Change> event.

=head2 value

	my $is_checked = $checkbox->value;

The same as reading C<checked>: 1 or 0. Read-only; use C<checked> to
change the state. This is the value C<Change> events carry.

=head2 indeterminate

	my $is_indeterminate = $checkbox->indeterminate;
	$checkbox->indeterminate(1);

Accessor. Returns 1 or 0. Writing repaints, returns the new state and
fires no event; it does not change C<checked>.

=head2 toggle

	$checkbox->toggle;

Toggles the box as the user does: an unchecked or indeterminate box
becomes checked, a checked box becomes unchecked, C<indeterminate> is
cleared, and a C<Change> event is fired. Works even while the box is
disabled. Returns the checkbox.

=head2 label

	my $label = $checkbox->label;
	$checkbox->label('Remember me');

Accessor for the label. Writing repaints and returns the new label; the
new width takes effect at the next frame. A value that is not a string
dies and leaves the label unchanged.

=head2 checked_mark

	my $mark = $checkbox->checked_mark;
	$checkbox->checked_mark('[*]');

Accessor for the C<checked_mark> parameter. Writing repaints and returns
the new mark. A value that is not a string dies and leaves the mark
unchanged.

=head2 unchecked_mark

	$checkbox->unchecked_mark('[_]');

Accessor for the C<unchecked_mark> parameter; works like
L</checked_mark>.

=head2 indeterminate_mark

	$checkbox->indeterminate_mark('[~]');

Accessor for the C<indeterminate_mark> parameter; works like
L</checked_mark>.

=head1 KEYS

While the checkbox has the focus and is enabled:

=over

=item C<Space>, C<Enter>

Toggle the box (see L</toggle>).

=back

All other keys bubble to the ancestors.

=head1 MOUSE

A click (left button pressed and released over the checkbox, mark or
label) toggles it and focuses it.

=head1 EVENTS

=over

=item C<Change>

L<Term::Fabulous::Event::Change> when the user toggles the box (or
L</toggle> is called); C<< $event->value >> is 1 (now checked) or 0
(now unchecked). It bubbles to the ancestors.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Input/KDL PROPERTIES>, plus
C<label>, C<checked> and C<indeterminate> (C<#true> / C<#false>),
C<checked_mark>, C<unchecked_mark> and C<indeterminate_mark>:

	use Term::Fabulous::Widget::Checkbox as Checkbox

	Checkbox "newsletter" {
		label "Send me the newsletter"
		checked #true
	}

=head1 EXAMPLES

=head2 A "select all" box for a group of boxes

	my @items = map { Term::Fabulous::Widget::Checkbox->new( label => $_ ) } qw(Apples Pears Plums);
	my $all   = Term::Fabulous::Widget::Checkbox->new( label => 'All fruit' );

	sub update_all () {
		my $checked = grep { $_->checked } @items;
		if    ( $checked == 0 )      { $all->checked(0) }
		elsif ( $checked == @items ) { $all->checked(1) }
		else                         { $all->indeterminate(1) }
		return;
	}

	$_->on( Change => sub ($event) { update_all(); return } ) foreach @items;
	$all->on( Change => sub ($event) {
		$_->checked( $event->value ) foreach @items;    # fires no Change
		return;
	} );

=head2 Ballot-box marks

All three marks are one column wide, so the label never moves (see
L</CONSTRUCTOR>).

	my $box = Term::Fabulous::Widget::Checkbox->new(
		label              => 'Done',
		checked_mark       => "\x{2611}",    # BALLOT BOX WITH CHECK
		unchecked_mark     => "\x{2610}",    # BALLOT BOX
		indeterminate_mark => "\x{25A3}",    # WHITE SQUARE CONTAINING BLACK SMALL SQUARE
	);

=head1 SEE ALSO

L<Term::Fabulous::Widget::Input>, L<Term::Fabulous::Event::Change>,
L<Term::Fabulous::Manual/FORMS AND INPUT WIDGETS>.

=cut
