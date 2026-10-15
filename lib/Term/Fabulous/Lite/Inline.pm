package Term::Fabulous::Lite::Inline;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Clay::UI::Enum::Result;
use Term::Fabulous;
use Term::Fabulous::Check qw(describe string);
use Term::Fabulous::Lite ();
use Term::Fabulous::OptionList;
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

sub confirm ( $class, $question, %options ) {
	_checked_question( confirm => $question );
	_checked_options( confirm => \%options, qw(ok cancel default) );
	my %label   = ( ok => string( OWNER, 'confirm ok', $options{ok} // 'OK' ), cancel => string( OWNER, 'confirm cancel', $options{cancel} // 'Cancel' ) );
	my $default = $options{default} // 'ok';
	die OWNER . ": confirm default must be ok or cancel, got " . describe($default) unless !ref $default && ( $default eq 'ok' || $default eq 'cancel' );

	my ( $ui, $answer );
	my %button  = map { $_ => TF->button( $label{$_}, id => $_, border => 1, padding => [ 0, 1 ], classes => [ $_ eq 'ok' ? 'primary' : () ] ) } qw(ok cancel);
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

	say defined $name ? "Hello, $name!" : 'Cancelled.';

=head1 DESCRIPTION

Each method asks one question in a few rows below the shell's earlier
output (inline mode, see L<Term::Fabulous/inline>), runs until the
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
