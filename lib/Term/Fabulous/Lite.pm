package Term::Fabulous::Lite;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT = ('TF');    ## no critic (Modules::ProhibitAutomaticExportation) the one export is the point of the module

use Feature::Compat::Try;
use Scalar::Util qw(blessed weaken);
use Clay::UI::Enum::Result;
use Term::Fabulous;
use Term::Fabulous::Check qw(describe);
use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Layout;
use Term::Fabulous::Lite::Params qw(split_arguments widget_params);
use Term::Fabulous::Static;
use Term::Fabulous::Theme;

use constant TF => __PACKAGE__;

use constant DEFAULT_WIDTH  => 80;
use constant DEFAULT_HEIGHT => 24;

my $WIDGET_NAMESPACE = 'Term::Fabulous::Widget';

# Each helper: the widget class below Term::Fabulous::Widget, the
# parameter its main value goes to (label_child: a Text child, as a
# Button takes its label), and the options it presets.
my %HELPER = (
	box          => { class => 'Box' },
	column       => { class => 'Box',      preset => { direction => 'ttb' } },
	row          => { class => 'Box',      preset => { direction => 'ltr' } },
	screen       => { class => 'Box',      preset => { direction => 'ttb', width => 'grow', height => 'grow' } },
	text         => { class => 'Text',     main   => 'text' },
	rich_text    => { class => 'RichText', main   => 'markup' },
	button       => { class => 'Button',   main   => 'label_child' },
	text_field   => { class => 'TextField' },
	text_area    => { class => 'TextArea' },
	checkbox     => { class => 'Checkbox', main => 'label' },
	radio_group  => { class => 'RadioGroup' },
	radio_button => { class => 'RadioButton', main => 'label' },
	dropdown     => { class => 'Dropdown' },
	slider       => { class => 'Slider' },
	scroll_box   => { class => 'ScrollBox' },
	divider      => { class => 'Divider', main => 'text' },
	progress_bar => { class => 'ProgressBar' },
	status_bar   => { class => 'StatusBar', main => 'message' },
	table        => { class => 'Table' },
	tabs         => { class => 'Tabs' },
	page         => { class => 'Tabs::Page', main => 'title' },
);

sub box          ( $class, @arguments ) { return $class->_build( box          => @arguments ) }
sub column       ( $class, @arguments ) { return $class->_build( column       => @arguments ) }
sub row          ( $class, @arguments ) { return $class->_build( row          => @arguments ) }
sub screen       ( $class, @arguments ) { return $class->_build( screen       => @arguments ) }
sub text         ( $class, @arguments ) { return $class->_build( text         => @arguments ) }
sub rich_text    ( $class, @arguments ) { return $class->_build( rich_text    => @arguments ) }
sub button       ( $class, @arguments ) { return $class->_build( button       => @arguments ) }
sub text_field   ( $class, @arguments ) { return $class->_build( text_field   => @arguments ) }
sub text_area    ( $class, @arguments ) { return $class->_build( text_area    => @arguments ) }
sub checkbox     ( $class, @arguments ) { return $class->_build( checkbox     => @arguments ) }
sub radio_group  ( $class, @arguments ) { return $class->_build( radio_group  => @arguments ) }
sub radio_button ( $class, @arguments ) { return $class->_build( radio_button => @arguments ) }
sub dropdown     ( $class, @arguments ) { return $class->_build( dropdown     => @arguments ) }
sub slider       ( $class, @arguments ) { return $class->_build( slider       => @arguments ) }
sub scroll_box   ( $class, @arguments ) { return $class->_build( scroll_box   => @arguments ) }
sub divider      ( $class, @arguments ) { return $class->_build( divider      => @arguments ) }
sub progress_bar ( $class, @arguments ) { return $class->_build( progress_bar => @arguments ) }
sub status_bar   ( $class, @arguments ) { return $class->_build( status_bar   => @arguments ) }
sub table        ( $class, @arguments ) { return $class->_build( table        => @arguments ) }
sub tabs         ( $class, @arguments ) { return $class->_build( tabs         => @arguments ) }
sub page         ( $class, @arguments ) { return $class->_build( page         => @arguments ) }

sub helper_names ($class) {
	my @names = sort keys %HELPER;
	return @names;
}

# Any widget class by its name below Term::Fabulous::Widget ('Table',
# 'Tabs::Page') or its full module name; no main value.
sub widget ( $class, $name, @arguments ) {
	die "Term::Fabulous::Lite: widget needs a class name, got " . describe($name) unless defined $name && !ref $name && length $name;
	my $module = $name =~ /::/ ? $name : "${WIDGET_NAMESPACE}::$name";
	return _construct( $name, _loaded($module), undef, {}, @arguments );
}

sub _build ( $class, $name, @arguments ) {
	my $helper = $HELPER{$name};
	my $module = _loaded("${WIDGET_NAMESPACE}::$helper->{class}");
	return _construct( $name, $module, $helper->{main}, $helper->{preset} // {}, @arguments );
}

# The presets of a helper lose against the same option in the call.
sub _construct ( $what, $module, $main_parameter, $preset, @arguments ) {
	my ( $main, $options, $children ) = split_arguments( $what, $main_parameter, @arguments );
	my ( $params, $listeners ) = widget_params( $what, $module, { %$preset, %$options } );

	if ( defined $main && $main_parameter eq 'label_child' ) {
		unshift @$children, TF->text($main);
	}
	elsif ( defined $main ) {
		die "Term::Fabulous::Lite: $what has both a main value and $main_parameter; give one of them" if exists $params->{$main_parameter};
		$params->{$main_parameter} = $main;
	}

	my $widget = $module->new(%$params);
	_adopt( $what, $widget, $children );
	$widget->on( $_ => $listeners->{$_} ) foreach sort keys %$listeners;
	return $widget;
}

sub _adopt ( $what, $widget, $children ) {
	return unless @$children;
	die "Term::Fabulous::Lite: $what widgets take no children (" . ref($widget) . " has no add_child), got " . ref( $children->[0] ) unless $widget->can('add_child');
	$widget->add_child(@$children);
	return;
}

sub _loaded ($module) {    ## no critic (Subroutines::RequireFinalReturn) PPI does not parse try/catch
	( my $path = "$module.pm" ) =~ s{::}{/}g;
	try {
		require $path;
	}
	catch ($error) {
		die "Term::Fabulous::Lite: cannot load the widget class $module: $error";
	}
	return $module;
}

# The Term::Fabulous for a root: the theme, the size defaults, the
# focus and the quit keys are Lite's; everything else is passed on.
sub app ( $class, $root, %options ) {
	die "Term::Fabulous::Lite: app needs a root widget, got " . describe($root) unless blessed $root;
	my @quit_keys = _checked_quit_keys( delete $options{quit_keys} );
	my $focus     = delete $options{focus};
	$options{theme} = $class->theme( $options{theme} ) if exists $options{theme};

	my $ui = Term::Fabulous->new( root => $root, width => DEFAULT_WIDTH, height => DEFAULT_HEIGHT, %options );
	$ui->interaction->set_focused_widget($focus) if defined $focus;
	_stop_on_keys( $ui, @quit_keys ) if @quit_keys;
	return $ui;
}

sub run ( $class, $root, %options ) {
	my $ui = $class->app( $root, %options );
	$ui->run;
	return $ui;
}

sub _checked_quit_keys ($keys) {
	return () unless defined $keys;
	die "Term::Fabulous::Lite: quit_keys must be an array reference of key names, got " . describe($keys) unless ref $keys eq 'ARRAY';
	foreach my $key (@$keys) {
		die "Term::Fabulous::Lite: quit_keys holds an invalid key name " . describe($key) unless defined $key && !ref $key && length $key;
		Term::Fabulous::Event::KeyPress->fields_for_name($key);    # dies for an unknown name
	}
	return @$keys;
}

# A quit key stops the loop wherever it is pressed; the listener holds
# the UI weakly, because the UI holds the root that holds the listener.
sub _stop_on_keys ( $ui, @keys ) {
	my %is_quit_key = map { $_ => 1 } @keys;
	my $weak_ui     = $ui;
	weaken $weak_ui;
	$ui->root->on(
		KeyPress => sub ($event) {
			return Clay::UI::Enum::Result->CONTINUE unless $is_quit_key{ $event->key_name // '' } && defined $weak_ui;
			$weak_ui->loop->stop;
			return;
		}
	);
	return;
}

sub print ( $class, $root, %options ) {
	my %print = map { exists $options{$_} ? ( $_ => delete $options{$_} ) : () } qw(fh colors);
	return _static( $root, %options )->print(%print);
}

sub render ( $class, $root, %options ) {
	my %render = map { exists $options{$_} ? ( $_ => delete $options{$_} ) : () } qw(colors);
	return _static( $root, %options )->render_string(%render);
}

sub _static ( $root, %options ) {
	die "Term::Fabulous::Lite: print and render need a root widget, got " . describe($root) unless blessed $root;
	$options{theme} = TF->theme( $options{theme} ) if exists $options{theme};
	return Term::Fabulous::Static->new( root => $root, width => DEFAULT_WIDTH, %options );
}

# The root widget of a KDL layout: a file by its path, or a string by
# reference.
sub load ( $class, $source, %options ) {
	die "Term::Fabulous::Lite: load needs the path of a layout file or a reference to a KDL string, got " . describe($source)
		unless defined $source && ( !ref $source || ref $source eq 'SCALAR' );
	my %from = ref $source ? ( string => $$source ) : ( file => $source );
	return Term::Fabulous::Layout->new( %from, %options )->build;
}

# A theme: an object, the name of a built-in theme or the path of a
# theme file.
sub theme ( $class, $spec ) {
	return $spec if blessed $spec && $spec->isa('Term::Fabulous::Theme');
	die "Term::Fabulous::Lite: theme must be a Term::Fabulous::Theme, the name of a built-in theme ("
		. join( ', ', Term::Fabulous::Theme::builtin_names() )
		. ") or the path of a .kdl theme file, got "
		. describe($spec)
		unless defined $spec && !ref $spec;
	return Term::Fabulous::Theme->from_file($spec) if $spec =~ /\.kdl\z/i;
	return Term::Fabulous::Theme->builtin($spec)
		// die "Term::Fabulous::Lite: unknown built-in theme '$spec' (known: " . join( ', ', Term::Fabulous::Theme::builtin_names() ) . "); a theme file ends in .kdl";
}

sub alert   ( $class, @arguments ) { return _loaded("${WIDGET_NAMESPACE}::Prompt")->alert(@arguments) }
sub confirm ( $class, @arguments ) { return _loaded("${WIDGET_NAMESPACE}::Prompt")->confirm(@arguments) }
sub ask     ( $class, @arguments ) { return _loaded("${WIDGET_NAMESPACE}::Prompt")->ask(@arguments) }

sub inline ($class) {
	return _loaded('Term::Fabulous::Lite::Inline');
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Lite - build and run Term::Fabulous programs with less code

=head1 SYNOPSIS

	use Term::Fabulous::Lite;    # exports TF

	my $name;
	my $root = TF->screen( gap => 1, padding => [ 1, 2 ],
		TF->text('Tab moves between inputs. Ctrl+C quits.'),
		TF->column( border => 'Round', border_color => '#61afef', width => 'grow', padding => [ 0, 1 ],
			TF->row( gap => 1, TF->box( width => 'fixed(12)', TF->text('Name') ), $name = TF->text_field( id => 'name', columns => 30 ) ),
			TF->row( gap => 1, TF->box( width => 'fixed(12)', TF->text('Notes') ), TF->text_area( id => 'notes', width => 'grow', height => 'fixed(4)' ) ),
		),
		TF->text( 'Change something.', id => 'status' ),
	);
	$root->on( Change => sub ($event) { $root->find_by_id('status')->text( 'Changed: ' . $event->target->id ); return } );

	TF->run( $root, focus => $name, quit_keys => [qw(q Escape)] );

	# A report, printed without opening the terminal
	TF->print( TF->column( TF->text('Three files copied.') ), width => 40 );

	# A screen from a KDL layout file
	TF->run( TF->load('layout.kdl'), theme => 'light' );

	# Questions below the shell's output, answered synchronously
	my $answer = TF->inline->prompt('What is your name?');
	my $size   = TF->inline->choose( 'Which size?', options => [ [ Small => 's' ], [ Medium => 'm' ], [ Large => 'l' ] ] );
	my $sure   = TF->inline->confirm('Delete the file?');

=head1 DESCRIPTION

C<Term::Fabulous::Lite> is a facade over L<Term::Fabulous>: one import,
C<TF>, whose class methods build the widgets, run a program, print a
tree, load a layout and ask questions. It adds no behavior of its own:
every helper returns a full widget, every option maps to one parameter
of the widget's C<new>, and the full parameters still work in the same
call. Programs start with Lite and reach for the full API wherever they
need it.

The vocabulary is the one of the layout files
(L<Term::Fabulous::Layout>): C<width => 'grow'>, C<direction => 'ttb'>,
C<align => 'center'>, C<border => 'Round'>. Learn it once for Perl and
KDL.

=head2 Children

Every widget among the arguments of a helper is a child, in order;
the other arguments are the options:

	TF->column( gap => 1, width => 'grow',
		TF->text('first'),
		TF->text('second'),
	);

A helper whose widget takes no children (C<text>, C<table>) dies when
given one. A L<Term::Fabulous::Widget::Text> has no layout of its own
either: it is as wide as its text, and a layout option such as
C<width> on it dies; size the box around it instead. A widget as the value of an option is not possible with the
helpers; such a parameter is given through the full API.

=head2 The main value

Some helpers take their main content as a leading value, before the
options: C<text> and C<rich_text> the text, C<button>, C<checkbox> and
C<radio_button> the label, C<divider> the text on the line,
C<status_bar> the message, C<page> the title. The value must come
first; C<TF-E<gt>text( 'Hello', bold =E<gt> 1 )>. A button's label
becomes a L<Term::Fabulous::Widget::Text> child, as the Button widget
takes it.

=head1 THE OPTIONS

Each Lite option stands for one parameter of the widget's C<new>.
Giving both in one call dies.

=over

=item C<width>, C<height>

C<layout.sizing.width> and C<layout.sizing.height>: C<grow>, C<fit>,
C<grow(MIN)>, C<grow(MIN, MAX)>, C<fit(MIN)>, C<fit(MIN, MAX)>,
C<fixed(N)>, C<percent(0..100)>, or a hash from the C<sizing_*>
functions of L<Clay::XS>. See L<Term::Fabulous::Check/sizing>.

=item C<direction>

C<layout.layout_direction>: C<ttb> (also C<top_to_bottom>, C<down>),
C<ltr> (C<left_to_right>, C<right>), C<wrap> (C<ltr_wrap>,
C<left_to_right_wrap>) or C<stack> (C<back_to_front>, C<btf>). See
L<Term::Fabulous::Check/direction>.

=item C<gap>, C<line_gap>, C<line_sizing>

C<layout.child_gap>, C<layout.line_gap> (non-negative integers) and
C<layout.line_sizing> (C<grow> or C<fit>).

=item C<padding>

C<layout.padding>: a number for every side, C<[ vertical, horizontal ]>,
C<[ top, right, bottom, left ]> or a hash of sides.

=item C<align>

C<layout.child_alignment>: C<center> (both axes), C<left> or C<right>
(the x axis), C<top> or C<bottom> (the y axis), C<[ x, y ]> or a hash
C<{ x =E<gt> ..., y =E<gt> ... }>.

=item C<border>

C<bordered> and C<border_style>: a boolean (the theme's style on every
side or no border), a style name such as C<Round> (that style on every
side) or a hash of sides with an optional C<style>:
C<{ top =E<gt> 1, bottom =E<gt> 1, style =E<gt> 'Double' }>. The color
is C<border_color>, as in the full API.

=item C<bg>, C<fg>

C<background_color> and C<text_color>, any color the widget accepts
(C<'#61afef'>, C<[ 97, 175, 239, 255 ]>, a L<Term::Fabulous::Color>).

=item C<columns>

C<preferred_columns> of a text field, slider or progress bar.

=back

A Lite option that is also a parameter of the widget's C<new> goes to
the widget untouched: C<border> and C<columns> of a Table are the
table's frame style and its column specs.

=over

=item C<on>

A hash of event name to handler, registered with the widget's C<on>
after construction: C<< on => { Activate => sub ($event) { ... } } >>.

=back

=head1 WIDGET HELPERS

Each helper builds the widget named, loading its class on first use.
The options are the Lite options above and the parameters of the
widget's C<new>.

=over

=item C<box>, C<column>, C<row>, C<screen>

A L<Term::Fabulous::Widget::Box>. C<column> presets
C<direction =E<gt> 'ttb'>, C<row> presets C<direction =E<gt> 'ltr'>,
C<screen> presets a column with C<width> and C<height> C<grow>, the
root of a full-screen program. A preset is replaced by the same option
in the call.

=item C<text>, C<rich_text>

L<Term::Fabulous::Widget::Text> and L<Term::Fabulous::Widget::RichText>;
the main value is the text, or the markup of a RichText.

=item C<button>

A L<Term::Fabulous::Widget::Button>; the main value is the label.

=item C<text_field>, C<text_area>, C<checkbox>, C<radio_group>, C<radio_button>, C<dropdown>, C<slider>

The input widgets of the same names; C<checkbox> and C<radio_button>
take their label as the main value.

=item C<scroll_box>, C<divider>, C<progress_bar>, C<status_bar>, C<table>, C<tabs>, C<page>

L<Term::Fabulous::Widget::ScrollBox>, L<Term::Fabulous::Widget::Divider>
(main value: the text on the line), L<Term::Fabulous::Widget::ProgressBar>,
L<Term::Fabulous::Widget::StatusBar> (main value: the message),
L<Term::Fabulous::Widget::Table>, L<Term::Fabulous::Widget::Tabs> and
L<Term::Fabulous::Widget::Tabs::Page> (main value: the title). A
ScrollBox and a Table need an C<id>.

=item C<widget>

	my $picker = TF->widget( 'ColorPicker', value => '#e5c07b' );
	my $own    = TF->widget( 'My::Widget', width => 'grow' );

Any widget class: a name below C<Term::Fabulous::Widget> or a full
module name. The Lite options and children work the same; there is no
main value.

=item C<helper_names>

The names of the helpers, sorted.

=back

=head1 PROGRAMS

=over

=item C<app>

	my $ui = TF->app( $root, %options );

A L<Term::Fabulous> for the root. Lite handles C<quit_keys> (an array
of key names as L<Term::Fabulous::Event::KeyPress/key_name> gives them;
each stops the program wherever it is pressed; default none, Ctrl+C
quits anyway), C<focus> (the widget that starts with the keyboard
focus) and C<theme> (see L</theme>); C<width> and C<height> default to
80 and 24, the size before the terminal reports its own. Every other
option goes to L<Term::Fabulous/new> (C<inline>, C<mouse>,
C<terminal>, ...).

=item C<run>

	TF->run( $root, %options );

C<app>, then L<Term::Fabulous/run>. Returns the L<Term::Fabulous> when
the program ends.

=item C<print>, C<render>

	TF->print( $root, width => 60 );
	my $text = TF->render( $root, colors => 0 );

Draw the tree once without opening the terminal, through
L<Term::Fabulous::Static>: C<print> prints it (C<fh> and C<colors> as
L<Term::Fabulous::Static/print> takes them), C<render> returns the
text. C<width> defaults to 80; C<theme> is handled by Lite; the other
options go to L<Term::Fabulous::Static/new>.

=item C<load>

	my $root = TF->load('layout.kdl');
	my $root = TF->load( \$kdl, allowed_namespaces => ['Term::Fabulous::Widget'] );

The root widget built from a layout file, or from a KDL string given by
reference, through L<Term::Fabulous::Layout>.

=item C<theme>

	my $theme = TF->theme('light');
	my $theme = TF->theme('themes/ocean.kdl');

A L<Term::Fabulous::Theme>: the object itself, the name of a built-in
theme, or the path of a theme file (ending in C<.kdl>).

=item C<alert>, C<confirm>, C<ask>

The class methods of L<Term::Fabulous::Widget::Prompt> of the same
names: a dialog in a running program, answered by an C<Answer> event.

=item C<inline>

	my $answer = TF->inline->prompt('Your name?');

The synchronous questions of L<Term::Fabulous::Lite::Inline>, asked in
the rows below the shell's output.

=back

=head1 SEE ALSO

L<Term::Fabulous>, L<Term::Fabulous::Lite::Inline>,
L<Term::Fabulous::Layout>, L<Term::Fabulous::Cookbook::GettingStarted>.

=cut
