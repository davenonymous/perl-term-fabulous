package InputTest;

# Helpers for the input widget tests: lay widgets out without a terminal,
# send them keys and mouse events, and read back what they painted.

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Exporter 'import';
our @EXPORT = qw(layout_ui press type_text click row_text);

use Clay::XS qw(sizing_grow CLAY_TOP_TO_BOTTOM);
use Term::Fabulous::Termbox qw(
	TB_KEY_ARROW_LEFT TB_KEY_ARROW_RIGHT TB_KEY_ARROW_UP TB_KEY_ARROW_DOWN TB_KEY_HOME TB_KEY_END
	TB_KEY_PGUP TB_KEY_PGDN TB_KEY_INSERT TB_KEY_DELETE TB_KEY_MOUSE_LEFT
	TB_MOD_ALT TB_MOD_CTRL TB_MOD_SHIFT
);
use Term::Fabulous::Event::KeyPress;
use Term::Fabulous::Event::Mouse;
use Term::Fabulous::Static;
use Term::Fabulous::Widget::Box;

my %KEY_BY_NAME = (
	Left      => TB_KEY_ARROW_LEFT,
	Right     => TB_KEY_ARROW_RIGHT,
	Up        => TB_KEY_ARROW_UP,
	Down      => TB_KEY_ARROW_DOWN,
	Home      => TB_KEY_HOME,
	End       => TB_KEY_END,
	PageUp    => TB_KEY_PGUP,
	PageDown  => TB_KEY_PGDN,
	Insert    => TB_KEY_INSERT,
	Delete    => TB_KEY_DELETE,
	Backspace => 0x7F,
	Tab       => 0x09,
	Enter     => 0x0D,
	Escape    => 0x1B,
	Space     => 0x20,
);
my %MODIFIER_BY_NAME = ( Ctrl => TB_MOD_CTRL, Alt => TB_MOD_ALT, Shift => TB_MOD_SHIFT );

# A Term::Fabulous::Static UI with the widgets stacked in a root box, laid
# out once.
sub layout_ui (@widgets) {
	my $root = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_grow() } } );
	$root->add_child(@widgets);
	my $ui = Term::Fabulous::Static->new( root => $root, width => 40, height => 20 );
	$ui->draw;
	return $ui;
}

# Fires a KeyPress named like Term::Fabulous::Event::KeyPress->key_name
# ('Ctrl+Shift+Left', 'Enter', 'Ctrl+W') or typing one character ('a').
sub press ( $widget, $name ) {
	my @parts     = split /\+(?=.)/, $name;
	my $base      = pop @parts;
	my $modifiers = 0;
	$modifiers |= $MODIFIER_BY_NAME{$_} // die "unknown modifier '$_'" foreach @parts;

	my ( $key, $char ) = ( 0, 0 );
	if    ( exists $KEY_BY_NAME{$base} )                       { $key = $KEY_BY_NAME{$base} }
	elsif ( $modifiers & TB_MOD_CTRL && $base =~ /\A[A-Z]\z/ ) { ( $key, $modifiers ) = ( ord($base) - 0x40, $modifiers & ~TB_MOD_CTRL ) }
	elsif ( length $base == 1 )                                { $char = ord $base }
	else                                                       { die "unknown key '$base'" }

	$widget->fire_event( Term::Fabulous::Event::KeyPress->new( key => $key, char => $char, modifiers => $modifiers ) );
	return;
}

sub type_text ( $widget, $text ) {
	press( $widget, $_ ) foreach split //, $text;
	return;
}

# A mouse event at a cell of the widget's buffer, as the widget was laid
# out last. Returns the event.
sub click ( $widget, $x, $y, %options ) {
	my ( $origin_x, $origin_y ) = $widget->content_origin;
	my $event = Term::Fabulous::Event::Mouse->new(
		key       => $options{key} // TB_KEY_MOUSE_LEFT,
		x         => $origin_x + $x,
		y         => $origin_y + $y,
		modifiers => $options{modifiers} // 0,
	);
	$widget->fire_event($event);
	return $event;
}

# The glyphs of one buffer row; unset cells read as spaces, and the cells a
# wide glyph covers are left out.
sub row_text ( $canvas, $y ) {
	my ($glyphs) = $canvas->cell_row($y);
	return join '', map { my $glyph = $glyphs->[$_]; ref $glyph ? $glyph->[0] : defined $glyph ? '' : ' ' } 0 .. $canvas->columns - 1;
}

1;
