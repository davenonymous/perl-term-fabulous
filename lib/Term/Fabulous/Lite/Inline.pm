package Term::Fabulous::Lite::Inline;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Clay::UI::Enum::Result;
use List::Util qw(max);
use Scalar::Util qw(blessed);
use Term::Fabulous;
use Term::Fabulous::Check qw(describe string);
use Term::Fabulous::Lite ();
use Term::Fabulous::OptionList;
use Term::Fabulous::Static;
use Term::Fabulous::Unicode qw(string_columns);
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::RadioButton;
use Term::Fabulous::Widget::RadioGroup;
use Term::Fabulous::Widget::TextField;

use constant OWNER => 'Term::Fabulous::Lite::Inline';
use constant TF    => 'Term::Fabulous::Lite';

use constant DEFAULT_WIDTH => 80;

# The options every question takes, besides its own.
my @COMMON_OPTIONS = qw(help theme terminal);

sub _checked_options ( $what, $options, @own ) {
	my %is_known = map { $_ => 1 } @COMMON_OPTIONS, @own;
	my @unknown  = sort grep { !$is_known{$_} } keys %$options;
	die OWNER . ": $what does not accept " . join( ', ', @unknown ) . ' (known options: ' . join( ', ', sort keys %is_known ) . ')' if @unknown;
	return;
}

sub _checked_question ( $what, $question ) {
	die OWNER . ": $what needs a question, got " . describe($question) unless defined $question && !ref $question && length $question;
	return $question;
}

# Runs a question in the rows below the shell's output and returns what
# the answer code recorded: the answer, or undef after Escape. The
# listeners get the UI through $ui_ref once it exists.
sub _ask ( $root, $rows, $focus, $ui_ref, %options ) {
	my %ui = map { exists $options{$_} ? ( $_ => $options{$_} ) : () } qw(terminal);
	$ui{theme} = TF->theme( $options{theme} ) if exists $options{theme};
	$$ui_ref = Term::Fabulous->new( root => $root, width => DEFAULT_WIDTH, height => $rows, inline => $rows, %ui );
	$$ui_ref->interaction->set_focused_widget($focus);
	$$ui_ref->run;
	return;
}

# Escape cancels every question.
sub _cancel_on_escape ( $root, $ui_ref, $answer_ref ) {
	$root->on(
		KeyPress => sub ($event) {
			return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Escape';
			$$answer_ref = undef;
			$$ui_ref->loop->stop;
			return;
		}
	);
	return;
}

sub prompt ( $class, $question, %options ) {
	_checked_question( prompt => $question );
	_checked_options( prompt => \%options, qw(value placeholder mask required validator columns) );
	my %field = map { exists $options{$_} ? ( $_ => $options{$_} ) : () } qw(value placeholder mask required validator columns);
	$field{columns} //= 40;

	my ( $ui, $answer );
	my $help  = TF->text( $options{help} // 'Enter answers, Escape cancels.' );
	my $field = TF->text_field( id => 'answer', %field );
	my $root  = TF->column( width => 'grow', height => 'grow', TF->text($question), $field, $help );

	# Enter answers only with a valid value; the message takes the help line.
	$field->on(
		Submit => sub ($event) {
			my $error = $field->validate;
			if ( defined $error ) {
				$help->text($error);
				return;
			}
			$answer = $event->value;
			$ui->loop->stop;
			return;
		}
	);
	_cancel_on_escape( $root, \$ui, \$answer );
	_ask( $root, 3, $field, \$ui, %options );
	return $answer;
}

# The ok and cancel buttons of a question, bordered and the first one
# primary, as a Prompt shows them; their labels come from the options.
sub _buttons ( $what, $options ) {
	my %label = ( ok => string( OWNER, "$what ok", $options->{ok} // 'OK' ), cancel => string( OWNER, "$what cancel", $options->{cancel} // 'Cancel' ) );
	return map { $_ => TF->button( $label{$_}, id => $_, border => 1, padding => [ 0, 1 ], classes => [ $_ eq 'ok' ? 'primary' : () ] ) } qw(ok cancel);
}

sub confirm ( $class, $question, %options ) {
	_checked_question( confirm => $question );
	_checked_options( confirm => \%options, qw(ok cancel default) );
	my $default = $options{default} // 'ok';
	die OWNER . ": confirm default must be ok or cancel, got " . describe($default) unless !ref $default && ( $default eq 'ok' || $default eq 'cancel' );

	my ( $ui, $answer );
	my %button  = _buttons( confirm => \%options );
	my $buttons = TF->row( gap => 2, $button{ok}, $button{cancel} );
	my $root    = TF->column( width => 'grow', height => 'grow', TF->text($question), $buttons, TF->text( $options{help} // 'Enter or y answers yes, n answers no, Escape cancels.' ) );

	my $answered = sub ($yes) {
		$answer = $yes;
		$ui->loop->stop;
		return;
	};
	$buttons->on( Activate => sub ($event) { $answered->( $event->target->id eq 'ok' ? 1 : 0 ); return } );
	my %key_answer = ( y => 1, Y => 1, n => 0, N => 0 );
	$root->on(
		KeyPress => sub ($event) {
			my $yes = $key_answer{ $event->key_name // '' } // return Clay::UI::Enum::Result->CONTINUE;
			$answered->($yes);
			return;
		}
	);
	_cancel_on_escape( $root, \$ui, \$answer );
	_ask( $root, 5, $button{$default}, \$ui, %options );    # the buttons have a border: three rows
	return $answer;
}

sub choose ( $class, $question, %options ) {
	_checked_question( choose => $question );
	_checked_options( choose => \%options, qw(options value) );
	my $list = Term::Fabulous::OptionList->new( owner => OWNER )->set_options( $options{options} // die OWNER . ': choose needs options to choose from' );
	die OWNER . ': choose needs at least one option' unless $list->count;

	my ( $ui, $answer );
	my $group = TF->radio_group(
		id => 'choice', exists $options{value} ? ( value => $options{value} ) : (),
		map { TF->radio_button( $_->{label}, value => $_->{value}, disabled => $_->{disabled} ) } $list->options
	);
	my $root = TF->column( width => 'grow', height => 'grow', TF->text($question), $group, TF->text( $options{help} // 'Up and Down move, Enter chooses, Escape cancels.' ) );

	# The group selects the highlighted button on Enter before this runs.
	$group->on(
		KeyPress => sub ($event) {
			return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'Enter';
			$answer = $group->value;
			$ui->loop->stop;
			return;
		}
	);
	_cancel_on_escape( $root, \$ui, \$answer );
	_ask( $root, 2 + $list->count, $group, \$ui, %options );
	return $answer;
}

# A form's fields: { name, label, input }, the input a widget with a
# value; the label is optional.
sub _checked_fields ($fields) {
	die OWNER . ': form needs fields, an array reference of { name, label, input } hashes, got ' . describe($fields) unless ref $fields eq 'ARRAY' && @$fields;
	my ( @parsed, %seen );
	foreach my $field (@$fields) {
		die OWNER . ': a form field must be a hash reference with a name and an input, got ' . describe($field) unless ref $field eq 'HASH';
		my %rest  = %$field;
		my $name  = string( OWNER, 'the name of a form field', delete $rest{name} );
		my $label = exists $rest{label} ? string( OWNER, "the label of the field '$name'", delete $rest{label} ) : undef;
		my $input = delete $rest{input};
		die OWNER . ": the input of the field '$name' must be a widget with a value, got " . describe($input) unless blessed $input && $input->can('value');
		die OWNER . ": the field '$name' has unknown keys: " . join( ', ', sort keys %rest ) if %rest;
		die OWNER . ": two fields have the name '$name'" if $seen{$name}++;
		push @parsed, { name => $name, label => $label, input => $input };
	}
	return @parsed;
}

# One row per field, the labels in a column as wide as the longest.
sub _field_rows ($fields) {
	my $label_columns = max( 0, map { string_columns( $_->{label} // '' ) } @$fields );
	return TF->column(
		width => 'grow',
		map { TF->row( gap => 1, width => 'grow', ( $label_columns ? TF->box( width => "fixed($label_columns)", TF->text( $_->{label} // '' ) ) : () ), $_->{input} ) } @$fields
	);
}

# The first problem with the values: what is wrong and the input it is
# about, or nothing. Every input is checked, then the whole form.
sub _first_problem ( $fields, $check ) {
	foreach my $field (@$fields) {
		my $input = $field->{input};
		my $error = $input->can('validate') ? $input->validate : undef;
		return ( ( $field->{label} // $field->{name} ) . ": $error", $input ) if defined $error;
	}
	my $problem = defined $check ? $check->( _values($fields) ) : undef;
	return ( $problem, undef ) if $problem;
	return ();
}

sub _values ($fields) {
	return { map { $_->{name} => $_->{input}->value } @$fields };
}

# The rows a tree takes, drawn once without a terminal at the width the
# region will have.
sub _rows_of ($root) {
	my @lines = Term::Fabulous::Static->new( root => $root, width => DEFAULT_WIDTH )->render_lines( colors => 0 );
	return scalar @lines;
}

sub form ( $class, $title, %options ) {
	_checked_question( form => $title );
	_checked_options( form => \%options, qw(fields ok cancel check) );
	my @fields = _checked_fields( $options{fields} );
	my $check  = $options{check};
	die OWNER . ': form check must be a code reference, got ' . describe($check) if defined $check && ref $check ne 'CODE';

	my ( $ui, $answer );
	my $help_text = $options{help} // 'Tab moves, Enter answers, Escape cancels.';
	my $help      = TF->text($help_text);
	my %button    = _buttons( form => \%options );
	my $root      = TF->column( width => 'grow', height => 'fit', TF->text( $title, bold => 1 ), _field_rows( \@fields ), TF->row( gap => 2, $button{ok}, $button{cancel} ), $help );

	# The ok button answers only with values that pass every check; the
	# problem takes the help line and the input it is about gets the focus.
	my $answered = sub ($accepted) {
		if ($accepted) {
			my ( $problem, $input ) = _first_problem( \@fields, $check );
			if ( defined $problem ) {
				$help->text($problem);
				$ui->interaction->set_focused_widget($input) if defined $input;
				return;
			}
			$help->text($help_text);
			$answer = _values( \@fields );
		}
		$ui->loop->stop;
		return;
	};
	$button{ok}->on( Activate => sub ($event) { $answered->(1); return } );
	$button{cancel}->on( Activate => sub ($event) { $answered->(0); return } );
	$root->on( Submit => sub ($event) { $answered->(1); return } );    # Enter in a text field
	_cancel_on_escape( $root, \$ui, \$answer );
	_ask( $root, _rows_of($root), $fields[0]{input}, \$ui, %options );
	return $answer;
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Lite::Inline - questions below the shell's output, answered synchronously

=head1 SYNOPSIS

	use Term::Fabulous::Lite;

	my $name = TF->inline->prompt( 'What is your name?', placeholder => 'Ada' );
	my $port = TF->inline->prompt( 'Port?', value => 8080, validator => 'integer', required => 1 );
	my $sure = TF->inline->confirm( 'Delete notes.txt?', ok => 'Delete', default => 'cancel' );
	my $size = TF->inline->choose( 'Which size?', options => [ [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ] ], value => 'm' );

	my $order = TF->inline->form(
		'Your order',
		fields => [
			{ name => 'name', label => 'Name', input => TF->text_field( required => 1 ) },
			{ name => 'size', label => 'Size', input => TF->radio_group( value => 'm', direction => 'ltr', gap => 2, TF->radio_button( 'Small', value => 's' ), TF->radio_button( 'Medium', value => 'm' ) ) },
		],
		ok => 'Order',
	);

	say defined $name ? "Hello, $name!" : 'Cancelled.';

=head1 DESCRIPTION

Each method asks a question (C<form>: several at once) in a few rows
below the shell's earlier output (inline mode, see L<Term::Fabulous/inline>), runs until the
user answers, and returns the answer; the rows stay on the screen as
the last state showed them. Escape cancels every question, and the
method returns C<undef>. Ctrl+C ends the program as everywhere in
Term::Fabulous.

C<TF-E<gt>inline> of L<Term::Fabulous::Lite> returns this package; the
methods are class methods.

=head1 COMMON OPTIONS

=over

=item C<help>

The text of the help line below the question. Each question has its
own default.

=item C<theme>

A theme as L<Term::Fabulous::Lite/theme> takes it.

=item C<terminal>

The terminal to run on, for tests: a L<Term::Fabulous::Terminal::Memory>
with the keys queued.

=back

Any other option dies, listing the known ones.

=head1 METHODS

=head2 prompt

	my $text = TF->inline->prompt( $question, %options );

One line of text in a L<Term::Fabulous::Widget::TextField>; Enter
answers with the text. The field takes C<value> (the text to start
with), C<placeholder>, C<mask>, C<required>, C<validator> (see
L<Term::Fabulous::Widget::TextField>) and C<columns> (default 40).
Enter on an invalid value does not answer; the message replaces the
help line until the value changes.

=head2 confirm

	my $yes = TF->inline->confirm( $question, %options );

Two bordered buttons, the first with the C<primary> class, as a
L<Term::Fabulous::Widget::Prompt> shows them; returns 1 for the first,
0 for the second, C<undef> after Escape. C<ok> and C<cancel> are the labels (C<OK> and C<Cancel>),
C<default> the button that starts with the focus (C<ok>, or C<cancel>
for a destructive question). The keys C<y> and C<n> answer too.

=head2 form

	my $values = TF->inline->form( $title, fields => \@fields, %options );

Several questions at once: a bold title, one row per field with its
label and input, the buttons C<ok> and C<cancel>, and the help line.
Returns a hash reference of the values by field name, or C<undef>
after Cancel or Escape. The region is as high as the form needs,
measured at 80 columns.

Each field is a hash with a C<name> (the key of its value), an
optional C<label> and an C<input>, any widget with a C<value>: a
L<Term::Fabulous::Widget::TextField>, L<Term::Fabulous::Widget::TextArea>,
L<Term::Fabulous::Widget::Checkbox>, L<Term::Fabulous::Widget::RadioGroup>,
L<Term::Fabulous::Widget::Dropdown> or L<Term::Fabulous::Widget::Slider>,
built with the C<TF> helpers. The first input starts with the focus;
Tab moves on to the next, then to the buttons.

The C<ok> button (and Enter in a text field) answers only when every
input is valid (C<required>, C<validator>, see
L<Term::Fabulous::Widget::Input>) and C<check>, a code reference that
gets the values and returns a problem or nothing, is satisfied. The
problem takes the help line, as C<Label: message>, and the input it is
about gets the focus. C<ok> and C<cancel> are the labels of the
buttons (C<OK> and C<Cancel>).

=head2 choose

	my $value = TF->inline->choose( $question, options => \@options, %options );

One choice from a L<Term::Fabulous::Widget::RadioGroup>, one row per
option; Up and Down move, Enter answers with the chosen value.
C<options> are labels, C<[ label, value ]> pairs or hashes with
C<label>, C<value> and C<disabled>, as every option list in
Term::Fabulous (L<Term::Fabulous::OptionList>); C<value> is the option
chosen at the start, by default the first.

=head1 SEE ALSO

L<Term::Fabulous::Lite>, L<Term::Fabulous::Widget::Prompt> (dialogs in
a running program),
L<Term::Fabulous::Cookbook::Forms/Ask for input below the shell's output (inline mode)>.

=cut
