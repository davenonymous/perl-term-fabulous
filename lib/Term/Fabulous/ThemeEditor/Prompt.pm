package Term::Fabulous::ThemeEditor::Prompt;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Dialog;

# A dialog with a title, a message, optional fields and a row of buttons:
# the questions, messages and small forms of the theme editor.
class Term::Fabulous::ThemeEditor::Prompt :isa(Term::Fabulous::Widget::Dialog) :strict(params) {
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM);
	use List::Util qw(first);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Dropdown;
	use Term::Fabulous::Widget::RichText;
	use Term::Fabulous::Widget::SegmentedControl;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Widget::TextField;

	field $title   :param;
	field $message :param = '';    # rich markup
	field $fields  :param = [];    # [ { name, label, kind => text|choice|list, options, value, check } ]
	field $buttons :param;    # [ [ id, label, primary ] ], the first primary one takes Enter
	field $width   :param = 60;
	field $on_done :param;    # code: ( $button_id, \%values ); 'cancel' for Escape

	field %input;
	field $error;
	field $done = 0;

	ADJUST {
		$self->layout( { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed($width) }, padding => { left => 2, right => 2, top => 1, bottom => 1 }, child_gap => 1 } );
		$self->add_child( Term::Fabulous::Widget::Text->new( text => $title, bold => 1 ) );
		$self->add_child( Term::Fabulous::Widget::RichText->new( markup => $message ) ) if length $message;
		weaken( my $weak_self = $self );
		foreach my $field (@$fields) {
			my $line = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_gap => 1 } );
			if ( defined $field->{label} ) {
				my $label = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(10) } } );
				$label->add_child( Term::Fabulous::Widget::Text->new( text => $field->{label} ) );
				$line->add_child($label);
			}
			my $widget = $self->_input($field);
			$input{ $field->{name} } = $widget;
			$line->add_child($widget);
			$self->add_child($line);
		}
		$error = Term::Fabulous::Widget::Text->new( text => '' );
		$self->add_child($error) if grep { defined $_->{check} } @$fields;

		my $row = Term::Fabulous::Widget::Box->new( layout => { child_gap => 2 } );
		foreach my $definition (@$buttons) {
			my ( $id, $label, $primary ) = @$definition;
			my $button = Term::Fabulous::Widget::Button->new( bordered => 1, classes => $primary ? ['primary'] : [], layout => { padding => { left => 1, right => 1 } } );
			$button->add_child( Term::Fabulous::Widget::Text->new( text => $label ) );
			$button->on( Activate => sub ($event) { $weak_self->finish($id); return } );
			$row->add_child($button);
		}
		$self->add_child($row);
		$self->on( Close => sub ($event) { $weak_self->_closed; return Clay::UI::Enum::Result->CONTINUE } );
	}

	method _input ($field) {
		my $kind = $field->{kind} // 'text';
		weaken( my $weak_self = $self );
		if ( $kind eq 'choice' ) {
			return Term::Fabulous::Widget::SegmentedControl->new( options => $field->{options}, value => $field->{value} // $field->{options}[0] );
		}
		if ( $kind eq 'list' ) {
			return Term::Fabulous::Widget::Dropdown->new( options => $field->{options}, value => $field->{value} // $field->{options}[0], max_visible_options => 10 );
		}
		my $text = Term::Fabulous::Widget::TextField->new( value => $field->{value} // '', placeholder => $field->{placeholder} // '', layout => { sizing => { width => sizing_grow() } } );
		$text->editor->select_all;    # typing replaces what the field starts with
		$text->on( Submit => sub ($event) { $weak_self->finish( $weak_self->default_button ); return } );
		return $text;
	}

	# The id of the button Enter in a text field presses: the first
	# primary one.
	method default_button () {
		my $primary = first { $_->[2] } @$buttons;
		return ( $primary // $buttons->[0] )->[0];
	}

	method values () {
		return { map { $_ => $input{$_}->value } keys %input };
	}

	method field ($name) {
		return $input{$name};
	}

	# Ends the dialog with a button; a primary button first checks the
	# fields that have a check, and a failed check keeps the dialog open
	# with its message.
	method finish ($id) {
		return $self if $done;
		my $values     = $self->values;
		my $definition = first { $_->[0] eq $id } @$buttons;
		if ( defined $definition && $definition->[2] ) {
			foreach my $field ( grep { defined $_->{check} } @$fields ) {
				my $problem = $field->{check}->( $values->{ $field->{name} }, $values ) // next;
				$error->text($problem);
				return $self;
			}
		}
		$done = 1;
		$self->close;
		$on_done->( $id, $values );
		return $self;
	}

	method _closed () {
		return if $done;
		$done = 1;
		$on_done->( 'cancel', $self->values );
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::Prompt - Questions and small forms of the
theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. A L<Term::Fabulous::Widget::Dialog> with a title, a message in
rich markup (see L<Term::Fabulous::Text::Markup>), optional fields
(a text field, a segmented choice or a dropdown list) and a row of
buttons. A text field starts with its text selected, so typing replaces
it. C<Escape> closes the dialog like a button with the id C<cancel>;
C<Enter> in a text field presses the first primary button. A primary
button runs the checks of the fields first; a field whose check
returns a message keeps the dialog open and shows it.

=head1 CONSTRUCTOR

=head2 new

	Term::Fabulous::ThemeEditor::Prompt->new(
		title   => 'New theme',
		message => 'A theme starts from one of the built-in themes.',
		fields  => [
			{ name => 'name', label => 'Name', value => 'untitled', check => sub ($value, $values) { length $value ? undef : 'A theme needs a name.' } },
			{ name => 'base', label => 'Based on', kind => 'choice', options => [qw(dark light)] },
		],
		buttons => [ [ create => 'Create', 1 ], [ cancel => 'Cancel' ] ],
		on_done => sub ( $button, $values ) { ... },
	)->open($ui);

=head1 METHODS

=head2 finish

Ends the dialog as if a button had been pressed.

=head2 values, field

The values of the fields by name, and one field's widget.

=head2 default_button

The id of the button C<Enter> in a text field presses.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
