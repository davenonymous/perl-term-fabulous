package Term::Fabulous::Widget::Toast;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::Toast::Stack;

our $VERSION = '0.01';

class Term::Fabulous::Widget::Toast
	:isa(Term::Fabulous::Widget::Box)
	:strict(params)
{
	use Clay::XS qw(sizing_fit sizing_grow CLAY_TOP_TO_BOTTOM CLAY_TEXT_WRAP_WORDS);
	use IO::Async::Loop;
	use IO::Async::Timer::Countdown;
	use Scalar::Util qw(blessed refaddr weaken);
	use Term::Fabulous::Check qw(boolean describe integer non_negative_integer number string);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Event::Close;

	use constant STACK_CLASS => 'Term::Fabulous::Widget::Toast::Stack';
	use constant CLOSE_MARK  => "\x{2715}";

	# The color and the default icon of each kind.
	my %KIND = (
		info    => { color => [ 97,  175, 239, 255 ], icon => 'i' },
		success => { color => [ 152, 195, 121, 255 ], icon => "\x{2713}" },
		warning => { color => [ 229, 192, 123, 255 ], icon => '!' },
		danger  => { color => [ 224, 108, 117, 255 ], icon => "\x{2717}" },
	);

	my %DEFAULT_SIZING = ( width => sizing_fit( 20, 44 ) );

	field $kind       :param = 'info';
	field $title      :param = '';
	field $message    :param = '';
	field $icon       :param = undef;
	field $closable   :param = 1;
	field $timeout    :param = 5;
	field $important  :param = 0;
	field $position   :param = 'top_right';
	field $z_index    :param = 2000;
	field $margin     :param = 1;
	field $color      :param = undef;
	field $text_color :param = [ 220, 223, 228, 255 ];

	# The parts of the toast, and the stack it is shown in.
	field $_icon_text;
	field $_title_text;
	field $_message_text;
	field $_body;
	field $_close_button;
	field $_timer;
	field $_built = 0;

	# The background behind a toast that is not important: the one given
	# to new or written later, kept while an important toast is filled.
	field $_panel_color;
	field $_styling = 0;

	# A toast looks like a toast unless told otherwise.
	sub BUILDARGS ( $class, %params ) {
		$params{background_color} //= [ 28, 33, 45, 255 ];
		$params{border_width} //= 1;
		$params{border_style} //= Term::Fabulous::Enum::BorderStyle->Round;
		$params{layout} = { padding => { left => 1, right => 1 }, child_gap => 1, %{ $params{layout} // {} } };
		$params{layout}{sizing} = { %DEFAULT_SIZING, %{ $params{layout}{sizing} // {} } };
		return $class->SUPER::BUILDARGS(%params);
	}

	ADJUST {
		$kind       = $self->_checked_kind($kind);
		$title      = string( $self, title   => $title );
		$message    = string( $self, message => $message );
		$icon       = defined $icon ? string( $self, icon => $icon ) : undef;
		$closable   = boolean( $self, closable  => $closable );
		$timeout    = $self->_checked_timeout($timeout);
		$important  = boolean( $self, important => $important );
		$position   = $self->_checked_position($position);
		$z_index    = integer( $self, z_index => $z_index );
		$margin     = non_negative_integer( $self, margin => $margin );
		$color      = defined $color ? Term::Fabulous::Check::color( $self, color => $color ) : undef;
		$text_color = Term::Fabulous::Check::color( $self, text_color => $text_color );

		weaken( my $weak_self = $self );
		$_icon_text    = Term::Fabulous::Widget::Text->new( text => '' );
		$_title_text   = Term::Fabulous::Widget::Text->new( text => '', bold => 1 );
		$_message_text = Term::Fabulous::Widget::Text->new( text => '', wrap_mode => CLAY_TEXT_WRAP_WORDS );
		$_body         = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() } } );
		$_close_button = Term::Fabulous::Widget::Button->new( can_focus => 0, pressed_background_color => undef );
		$_close_button->add_child( Term::Fabulous::Widget::Text->new( text => CLOSE_MARK ) );
		$_close_button->on( Activate => sub ($event) { $weak_self->hide if $weak_self; return } );
		$_panel_color = $self->background_color;
		$self->SUPER::add_child( $_icon_text, $_body, $_close_button );
		$_built = 1;
		$self->_refresh_look;
	}

	method background_color :override (@new) {
		my $result = $self->SUPER::background_color(@new);
		$_panel_color = $result if @new && !$_styling;
		return $result;
	}

	method _checked_kind ($name) {
		die ref($self) . ": kind must be info, success, warning or danger, got " . describe($name) unless defined $name && !ref $name && $KIND{$name};
		return $name;
	}

	method _checked_timeout ($seconds) {
		return undef unless defined $seconds;
		$seconds = number( $self, timeout => $seconds );
		die ref($self) . ": timeout must be positive, or undef for no timeout, got $seconds" unless $seconds > 0;
		return $seconds;
	}

	method _checked_position ($name) {
		my %is_position = map { $_ => 1 } STACK_CLASS->positions;
		die ref($self) . ": position must be one of " . join( ', ', STACK_CLASS->positions ) . ", got " . describe($name) unless defined $name && !ref $name && $is_position{$name};
		return $name;
	}

	# ---------------------------------------------------------------------
	# The parts: children of the program go into the body, below the
	# message
	# ---------------------------------------------------------------------

	method add_child :override (@kids) {
		return $self->SUPER::add_child(@kids) unless $_built;
		$_body->add_child(@kids);
		return $self;
	}

	method remove_child :override ($target_id) {
		$_body->remove_child($target_id);
		return $self;
	}

	method remove_children_with :override ($predicate) {
		$_body->remove_children_with( sub ($child) { refaddr($child) != refaddr($_title_text) && refaddr($child) != refaddr($_message_text) && $predicate->($child) } );
		return $self;
	}

	method clear_children :override () {
		$self->remove_children_with( sub { 1 } );
		return $self;
	}

	method body () { return $_body }

	# ---------------------------------------------------------------------
	# Look
	# ---------------------------------------------------------------------

	method kind_color () {
		return $color // $KIND{$kind}{color};
	}

	method _refresh_look () {
		my $accent = $self->kind_color;
		my $dark   = [ 16, 18, 22, 255 ];
		$_styling = 1;
		$self->border_color($accent);
		$self->background_color( $important ? $accent : $_panel_color );
		$_styling = 0;

		$_icon_text->text( $icon // $KIND{$kind}{icon} );
		$_icon_text->text_color( $important ? $dark : $accent );
		$_title_text->text($title);
		$_title_text->text_color( $important ? $dark : $accent );
		$_message_text->text($message);
		$_message_text->text_color( $important ? $dark : $text_color );
		$_close_button->children->[0]->text_color( $important ? $dark : $text_color );

		$self->_order_body( ( length $title ? $_title_text : () ), ( length $message ? $_message_text : () ) );
		$self->SUPER::remove_children_with( sub ($child) { refaddr($child) == refaddr($_close_button) } );
		$self->SUPER::add_child($_close_button) if $closable;
		return;
	}

	# The title and the message that have a text come first in the body,
	# then whatever the program added.
	method _order_body (@texts) {
		my %is_text = map { refaddr($_) => 1 } $_title_text, $_message_text;
		my @others  = grep { !$is_text{ refaddr($_) } } $_body->children->@*;
		$_body->clear_children;
		$_body->add_child( @texts, @others );
		return;
	}

	# ---------------------------------------------------------------------
	# Accessors
	# ---------------------------------------------------------------------

	method _set ( $field_ref, $value ) {
		$$field_ref = $value;
		$self->_refresh_look;
		return $$field_ref;
	}

	method kind (@new)       { return @new ? $self->_set( \$kind,       $self->_checked_kind( $new[0] ) ) : $kind }
	method title (@new)      { return @new ? $self->_set( \$title,      string( $self, title => $new[0] ) ) : $title }
	method message (@new)    { return @new ? $self->_set( \$message,    string( $self, message => $new[0] ) ) : $message }
	method icon (@new)       { return @new ? $self->_set( \$icon,       defined $new[0] ? string( $self, icon => $new[0] ) : undef ) : $icon }
	method closable (@new)   { return @new ? $self->_set( \$closable,   boolean( $self, closable => $new[0] ) ) : $closable }
	method important (@new)  { return @new ? $self->_set( \$important,  boolean( $self, important => $new[0] ) ) : $important }
	method color (@new)      { return @new ? $self->_set( \$color,      defined $new[0] ? Term::Fabulous::Check::color( $self, color => $new[0] ) : undef ) : $color }
	method text_color (@new) { return @new ? $self->_set( \$text_color, Term::Fabulous::Check::color( $self, text_color => $new[0] ) ) : $text_color }

	method timeout (@new) {
		return $timeout unless @new;
		$timeout = $self->_checked_timeout( $new[0] );
		$self->_restart_timer if $self->is_shown;
		return $timeout;
	}

	method position (@new) {
		return $position unless @new;
		my $wanted = $self->_checked_position( $new[0] );
		die ref($self) . ": position cannot change while the toast is shown; hide it first" if $self->is_shown && $wanted ne $position;
		return $position = $wanted;
	}

	method z_index (@new) {
		return $z_index unless @new;
		$z_index = integer( $self, z_index => $new[0] );
		my $stack = $self->stack;
		$stack->floating( { %{ $stack->floating }, z_index => $z_index } ) if defined $stack;
		return $z_index;
	}

	method margin (@new) {
		return $margin unless @new;
		return $margin = non_negative_integer( $self, margin => $new[0] );
	}

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			( map { $_ => 'scalar' } qw(kind title message icon timeout position z_index margin color) ),
			( map { $_ => 'boolean' } qw(closable important) ),
			text_color => 'color',
		);
	}

	# ---------------------------------------------------------------------
	# Showing and hiding
	# ---------------------------------------------------------------------

	# The stack the toast is shown in, or undef.
	method stack () {
		my $parent = $self->parent;
		return blessed $parent && $parent->isa(STACK_CLASS) ? $parent : undef;
	}

	method is_shown () {
		return defined $self->stack ? 1 : 0;
	}

	# The stack of the toast's position on the root of a UI, created when
	# there is none yet.
	method _stack_on ($root) {
		my ($stack) = $root->get_children_with( sub { blessed $_ && $_->isa(STACK_CLASS) && $_->position eq $position } );
		return $stack if defined $stack;
		$stack = STACK_CLASS->new( position => $position, z_index => $z_index, margin => $margin );
		$root->add_child($stack);
		return $stack;
	}

	method show ($ui) {
		die ref($self) . ": show needs the Term::Fabulous object, got " . ( ref $ui || $ui // 'undef' ) unless blessed $ui && $ui->isa('Clay::UI');
		if ( $self->is_shown ) {
			$self->_restart_timer;
			return $self;
		}
		die ref($self) . ": a toast that is a child of another widget cannot be shown" if defined $self->parent;
		$self->_stack_on( $ui->root )->add_child($self);
		$self->_restart_timer;
		return $self;
	}

	# Takes the toast off the screen, and the stack with it when it was the
	# last toast there; fires Close. Does nothing for a toast that is not
	# shown.
	method hide () {
		my $stack = $self->stack // return $self;
		$self->_stop_timer;
		$stack->remove_children_with( sub ($child) { refaddr($child) == refaddr($self) } );
		my $holder = $stack->parent;
		$holder->remove_children_with( sub ($child) { refaddr($child) == refaddr($stack) } ) if defined $holder && !$stack->children->@*;
		$self->fire_event( Term::Fabulous::Event::Close->new );
		return $self;
	}

	# The timeout runs on the process-wide IO::Async loop, which run
	# drives; without a running loop (step in tests) the toast stays.
	method _restart_timer () {
		$self->_stop_timer;
		return unless defined $timeout;
		weaken( my $weak_self = $self );
		$_timer = IO::Async::Timer::Countdown->new( delay => $timeout, on_expire => sub { $weak_self->hide if $weak_self; return } );
		IO::Async::Loop->new->add($_timer);
		$_timer->start;
		return;
	}

	method _stop_timer () {
		return unless defined $_timer;
		$_timer->stop if $_timer->is_running;
		$_timer->remove_from_parent if defined $_timer->loop;
		$_timer = undef;
		return;
	}

	# Lets the timeout run out now, as the loop would: for tests.
	method expire () {
		return $self unless defined $_timer;
		$self->_stop_timer;
		$self->hide;
		return $self;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::Toast - A notification that appears in a corner
and goes away by itself

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Toast;

	# From a listener or a timer, while the program runs:
	Term::Fabulous::Widget::Toast->new(
		kind    => 'success',
		title   => 'Saved',
		message => 'Your changes were written to disk.',
	)->show($ui);

	# Stays until closed, in another corner, filled with its color:
	my $alert = Term::Fabulous::Widget::Toast->new(
		kind      => 'danger',
		title     => 'Connection lost',
		message   => 'Reconnecting in the background.',
		timeout   => undef,
		important => 1,
		position  => 'bottom_right',
	);
	$alert->show($ui);
	$alert->on( Close => sub ($event) { ...; return } );
	$alert->hide;    # from the program

	# Inside the layout, as an alert box: add it as a child instead of showing it.
	$form->add_child( Term::Fabulous::Widget::Toast->new( kind => 'warning', message => 'Unsaved changes.', closable => 0 ) );

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.01/screenshots/widget-toast.svg" alt="Toasts stacked in the top right corner: an info, a success and a warning toast with titles, messages and close marks, a filled danger toast in the bottom right corner, and an alert box inside the form"></p>

=end html

=head1 DESCRIPTION

The picture shows toasts of every kind stacked in the top right
corner, a filled (important) one in the bottom right corner, and one
used as an alert box inside the layout. The program is
F<examples/widgets/toast.pl>.

A toast is a short message the program shows the user without
stopping them: a box with an icon, a title, a message and a close
mark, in the color of its C<kind> (C<info>, C<success>, C<warning> or
C<danger>):

=for highlighter language=text

	╭────────────────────────────────────╮
	│ ✓ Saved                          ✕ │
	│   Your changes were written to disk.│
	╰────────────────────────────────────╯

L</show> floats it into a corner of the screen, over everything
else, where it lines up below the toasts shown there before, and
takes it away again after C<timeout> seconds (or never, when the
timeout is C<undef>); a click on the close mark takes it away at
once, and so does L</hide>. Whichever way a toast goes, it fires
C<Close> (L<Term::Fabulous::Event::Close>). Toasts take no focus and
no keys, so the user goes on working while they are there. A hidden
toast can be shown again.

The same widget is an I<alert> when it is added to the layout as a
child instead of being shown: it then stays where it is put, with or
without a close mark (which removes it from its parent). C<important>
fills a toast with its color, for messages that must not be missed.
The children you add to a toast go below the message, for a button
or a link.

A toast is a L<Term::Fabulous::Widget::Box> with a round border in
its color, a dark panel background (C<[28, 33, 45, 255]>), a cell of
padding and a width that fits its text up to 44 columns, at which the
message wraps; every one of these is an ordinary Box parameter and
can be overridden.

=head1 CONSTRUCTOR

=head2 new

=for highlighter language=perl

	my $toast = Term::Fabulous::Widget::Toast->new(%parameters);

Accepts the parameters of L<Term::Fabulous::Widget::Box/CONSTRUCTOR>
(C<id>, C<layout>, C<background_color>, the border parameters, ...)
and the ones below. All are optional; unknown parameters die.

=over

=item C<kind>

C<info> (the default), C<success>, C<warning> or C<danger>: the color
of the border, the icon and the title (blue, green, yellow, red) and
the default icon. Anything else dies.

=item C<title>

A character string, shown bold in the kind's color. Default: C<''>
(no title line).

=item C<message>

A character string, wrapped at words when it is wider than the toast.
Default: C<''> (no message line).

=item C<icon>

A character string shown before the title, or C<undef> for the kind's
icon: C<i>, a check mark, C<!> and a cross. Default: C<undef>.

=item C<closable>

A boolean. Default: 1. Whether the close mark is shown; a click on it
hides the toast.

=item C<timeout>

A positive number of seconds after which a shown toast hides itself,
or C<undef> to stay until it is closed. Default: 5. Counted from
L</show>, on the event loop of L<Term::Fabulous/run>; under
L<Term::Fabulous/step>, which runs no loop, the toast stays (see
L</expire>).

=item C<important>

A boolean. Default: 0. True fills the toast with its color and writes
the texts in a dark color on it.

=item C<position>

Where L</show> puts the toast: C<top_right> (the default), C<top_left>,
C<top_center>, C<bottom_right>, C<bottom_left> or C<bottom_center>.
Toasts of one position stack top to bottom, newest last, with a row
between them, C<margin> cells from the edges. Anything else dies.

=item C<z_index>

An integer. Default: 2000, above a L<Term::Fabulous::Widget::Dialog>
(1000), so toasts show over an open dialog.

=item C<margin>

A non-negative integer. Default: 1. The cells between the stack of
toasts and the edges of the screen.

=item C<color>

A color in any format L<Term::Fabulous::Color> accepts, or C<undef>.
Default: C<undef>, the color of the kind. A color of your own for the
border, the icon and the title (and the fill of an important toast).

=item C<text_color>

The color of the message and the close mark. Default:
C<[220, 223, 228, 255]>.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget>, of which C<add_child>,
C<remove_child>, C<remove_children_with> and C<clear_children> act on
the widgets below the message, plus:

=head2 show

	$toast->show($ui);

Shows the toast: adds it to the stack of its position on the root
widget of the L<Term::Fabulous> object (creating the stack when it is
the first toast there) and starts the timeout. Showing a toast that
is shown restarts its timeout. Dies without a L<Term::Fabulous> (or
L<Term::Fabulous::Static>) object, or for a toast that is a child of
another widget. Returns the toast.

=head2 hide

	$toast->hide;

Takes a shown toast off the screen, removes the stack when it was the
last toast there, and fires C<Close> on the toast. Does nothing for a
toast that is not shown. Returns the toast.

=head2 is_shown

	if ( $toast->is_shown ) { ... }

True while the toast is on the screen through L</show>.

=head2 expire

	$toast->expire;

Lets the timeout run out now: hides the toast as the loop would when
the time is up. For tests, which run no loop. A toast without a
timeout, or one that is not shown, is left alone. Returns the toast.

=head2 stack

	my $stack = $toast->stack;

The L<Term::Fabulous::Widget::Toast::Stack> the toast is shown in, or
C<undef>.

=head2 body

	my $box = $toast->body;

The box below the icon that holds the title, the message and the
children you added.

=head2 kind_color

	my $rgba = $toast->kind_color;

The color in use: C<color>, or the kind's.

=head2 kind

	$toast->kind('danger');

Accessor for the C<kind> parameter: C<info>, C<success>, C<warning>
or C<danger>.

=head2 title

	$toast->title('Saved');

Accessor for the C<title> parameter.

=head2 message

	$toast->message('Still trying.');

Accessor for the C<message> parameter.

=head2 icon

	$toast->icon("\x{2691}");
	$toast->icon(undef);    # the kind's icon

Accessor for the C<icon> parameter.

=head2 closable

	$toast->closable(0);

Accessor for the C<closable> parameter. Returns 1 or 0.

=head2 important

	$toast->important(1);

Accessor for the C<important> parameter. Returns 1 or 0.

=head2 color

	$toast->color('#c678dd');
	$toast->color(undef);    # the kind's color

Accessor for the C<color> parameter. The reader returns
C<[r, g, b, a]> or C<undef>. An invalid color dies and leaves the old
one.

=head2 text_color

	$toast->text_color('#ffffff');

Accessor for the C<text_color> parameter; works like L</color>, but
takes no C<undef>.

Every writer updates the look, so the next frame shows it.

=head2 timeout

	$toast->timeout(10);
	$toast->timeout(undef);

Accessor for the C<timeout> parameter. Writing restarts the timeout
of a shown toast.

=head2 position

	$toast->position('bottom_left');

Accessor for the C<position> parameter. Dies while the toast is
shown; hide it first.

=head2 z_index

	$toast->z_index(3000);

Accessor for the C<z_index> parameter; a shown toast's stack moves
at once.

=head2 margin

	$toast->margin(2);

Accessor for the C<margin> parameter, used when the stack is created.

=head1 MOUSE

A click on the close mark hides the toast. The rest of the toast
paints its background and border, so clicks on it reach nothing
behind it.

=head1 EVENTS

=over

=item C<Close>

L<Term::Fabulous::Event::Close> when a shown toast goes: by its
timeout, the close mark or L</hide>. Fired on the toast after it has
left the screen, so only listeners on the toast itself see it.

=back

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::Box/KDL PROPERTIES>, plus
C<kind>, C<title>, C<message>, C<icon>, C<timeout>, C<position>,
C<z_index>, C<margin> and C<color> (strings, numbers and a color
string), C<closable> and C<important> (C<#true> / C<#false>) and
C<text_color> (a color string). A toast built from a layout is a child
of the widget it is in, an alert box; show one from Perl instead to
float it.

=for highlighter language=kdl

	use Term::Fabulous::Widget::Toast as Toast

	Toast "unsaved" {
		kind "warning"
		message "You have unsaved changes."
		closable #false
	}

=head1 EXAMPLES

=head2 A helper for the whole program

=for highlighter language=perl

	sub notify ( $kind, $title, $message = '' ) {
		Term::Fabulous::Widget::Toast->new( kind => $kind, title => $title, message => $message )->show($ui);
		return;
	}
	$save->on( Activate => sub ($event) { save(); notify( success => 'Saved' ); return } );

=head2 A toast with a button

	my $toast = Term::Fabulous::Widget::Toast->new( kind => 'info', title => 'Update available', timeout => undef );
	my $later = Term::Fabulous::Widget::Button->new( layout => { padding => { left => 1, right => 1 } } );
	$later->add_child( Term::Fabulous::Widget::Text->new( text => 'Later', text_color => '#ffffff' ) );
	$later->on( Activate => sub ($event) { $toast->hide; return } );
	$toast->add_child($later);
	$toast->show($ui);

=head1 SEE ALSO

L<Term::Fabulous::Widget::Toast::Stack>, L<Term::Fabulous::Event::Close>,
L<Term::Fabulous::Widget::Dialog>,
L<Term::Fabulous::Manual::Feedback/TOASTS AND ALERTS>.

=cut
