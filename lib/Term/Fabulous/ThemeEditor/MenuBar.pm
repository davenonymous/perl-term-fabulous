package Term::Fabulous::ThemeEditor::MenuBar;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Display;
use Term::Fabulous::Widget::Input;

# A menu bar: menu titles in one row, each opening a list of commands.
# It takes the focus only while a menu is open and gives it back when the
# menu closes.
class Term::Fabulous::ThemeEditor::MenuBar :isa(Term::Fabulous::Widget::Input) :strict(params) {
	use Clay::UI::Enum::Result;
	use Clay::XS qw(CLAY_ATTACH_TO_PARENT CLAY_ATTACH_POINT_LEFT_TOP CLAY_ATTACH_POINT_LEFT_BOTTOM);
	use List::Util qw(first sum0);
	use Scalar::Util qw(refaddr weaken);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_MOD_MOTION TB_UNDERLINE);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant MENU_Z_INDEX => 32000;
	use constant GAP          => 2;    # columns between two titles

	# [ { title, key, items => [ { label, command, keys } or '-' ] } ]
	field @menus;
	field $run     :param;    # code: runs a command
	field $enabled :param;    # code: whether a command can run now
	field $caption :param = '';

	field $open;    # the index of the open menu, or undef
	field $highlight;    # the index of the highlighted item
	field $popup;
	field $focus_before;

	ADJUST :params ( :$menus ) {
		die "Term::Fabulous::ThemeEditor::MenuBar: menus must be an array reference" unless ref $menus eq 'ARRAY';
		@menus = map {
			{
				%$_, items => [ map { ref $_ ? {%$_} : $_ } @{ $_->{items} } ]
			}
		} @$menus;
		$self->can_focus(0);
		weaken( my $weak_self = $self );
		$self->on(
			MouseMove => sub ($event) {
				$weak_self->pointer_over($event) if refaddr( $event->target ) == refaddr($weak_self);
				return Clay::UI::Enum::Result->CONTINUE;
			}
		);
	}

	method natural_size () {
		return ( sum0( map { string_columns( $_->{title} ) + GAP } @menus ), 1 );
	}

	# An input has a value: the open menu's index, or undef.
	method value () {
		return $open;
	}

	method is_open () {
		return defined $open ? 1 : 0;
	}

	method open_menu () {
		return $open;
	}

	method highlighted () {
		return $highlight;
	}

	method menus () {
		return @menus;
	}

	# The column a menu's title starts at.
	method _title_column ($index) {
		return 1 + sum0( map { string_columns( $menus[$_]{title} ) + GAP } 0 .. $index - 1 );
	}

	# The menu whose title covers a column, or undef.
	method _menu_at ($column) {
		foreach my $index ( 0 .. $#menus ) {
			my $start = $self->_title_column($index) - 1;
			return $index if $column >= $start && $column < $start + string_columns( $menus[$index]{title} ) + 2;
		}
		return undef;
	}

	# The menu with this mnemonic letter (Alt+F opens File), or undef.
	method menu_for_key ($letter) {
		return first { lc $menus[$_]{key} eq lc $letter } 0 .. $#menus;
	}

	method item_enabled ($item) {
		return ref $item && $enabled->( $item->{command} ) ? 1 : 0;
	}

	# ---------------------------------------------------------------------
	# Opening and closing
	# ---------------------------------------------------------------------

	method open ($index) {
		my $ui = $self->ui // return $self;
		$index %= @menus;
		if ( !defined $open ) {
			my $focused = $ui->interaction->get_focused_widget;
			$focus_before = defined $focused && refaddr $focused != refaddr $self ? $focused : undef;
			weaken $focus_before if defined $focus_before;
		}
		$self->remove_child($popup) if defined $popup;
		$open      = $index;
		$highlight = first { $self->item_enabled( $menus[$index]{items}[$_] ) } 0 .. $#{ $menus[$index]{items} };
		$popup     = Term::Fabulous::ThemeEditor::MenuBar::Popup->new( bar => $self, menu => $menus[$index], floating => $self->_popup_floating($index) );
		$self->add_child($popup);
		$self->can_focus(1);
		$ui->interaction->set_focused_widget($self) unless $self->is_focused;
		return $self->mark_changed;
	}

	method _popup_floating ($index) {
		return {
			attach_to     => CLAY_ATTACH_TO_PARENT,
			attach_points => { element => CLAY_ATTACH_POINT_LEFT_TOP,       parent => CLAY_ATTACH_POINT_LEFT_BOTTOM },
			offset        => { x       => $self->_title_column($index) - 1, y      => 0 },
			z_index       => MENU_Z_INDEX,
		};
	}

	# Closes the open menu and gives the focus back to the widget that had
	# it.
	method close () {
		return $self unless defined $open;
		my $closing = $popup;
		( $open, $highlight, $popup ) = ( undef, undef, undef );
		$self->remove_child($closing);
		my $ui = $self->ui;
		if ( defined $ui && $self->is_focused ) {
			my $back = $focus_before;
			$back = undef if defined $back && !$ui->interaction->can_take_focus($back);
			$ui->interaction->set_focused_widget($back);
		}
		$focus_before = undef;
		$self->can_focus(0);
		return $self->mark_changed;
	}

	method focus_changed :override ($is_focused) {
		$self->close unless $is_focused;
		return;
	}

	# Runs an item: the menu closes first, so the command finds the focus
	# where it was before the menu opened.
	method activate_item ($index) {
		return $self unless defined $open;
		my $item = $menus[$open]{items}[$index];
		return $self unless $self->item_enabled($item);
		$self->close;
		$run->( $item->{command} );
		return $self;
	}

	method highlight_item ($index) {
		return $self unless defined $open && $self->item_enabled( $menus[$open]{items}[$index] );
		$highlight = $index;
		$popup->mark_changed if defined $popup;
		return $self->mark_changed;
	}

	# ---------------------------------------------------------------------
	# Keys and mouse
	# ---------------------------------------------------------------------

	method handle_key ($event) {
		return 0 unless defined $open;
		my $name   = $event->main_key_name // '';
		my %switch = ( Left => $open - 1, BackTab => $open - 1, Right => $open + 1, Tab => $open + 1 );
		if ( $name eq 'Escape' || $name eq 'F10' ) {
			$self->close;
			return 1;
		}
		if ( exists $switch{$name} ) {
			$self->open( $switch{$name} );
			return 1;
		}
		return $self->_move_highlight(-1) if $name eq 'Up';
		return $self->_move_highlight(1) if $name eq 'Down';
		return $self->_move_highlight( -1, 1 ) if $name eq 'Home' || $name eq 'PageUp';
		return $self->_move_highlight(  1, 1 ) if $name eq 'End'  || $name eq 'PageDown';
		if ( $name eq 'Enter' || $name eq 'Space' ) {
			$self->activate_item($highlight) if defined $highlight;
			return 1;
		}
		if ( my ($letter) = $name =~ /\AAlt\+(.)\z/ ) {
			my $menu = $self->menu_for_key($letter);
			if ( defined $menu ) {
				$self->open($menu);
				return 1;
			}
		}
		return 1 if $name !~ /\A(?:Ctrl|Alt)\+/;    # the menu takes plain keys while open
		$self->close;
		return 0;
	}

	# While a menu is open, Tab and Shift+Tab switch menus.
	method captures_tab () {
		return $self->is_open;
	}

	# Moves the highlight to the next enabled item in a direction, or to
	# the last one that way.
	method _move_highlight ( $direction, $to_end = 0 ) {
		my $items  = $menus[$open]{items};
		my @usable = grep { $self->item_enabled( $items->[$_] ) } 0 .. $#$items;
		return 1 unless @usable;
		my $current = $highlight // ( $direction > 0 ? -1 : scalar @$items );
		my $target
			= $to_end        ? ( $direction > 0 ? $usable[-1] : $usable[0] )
			: $direction > 0 ? ( first { $_ > $current } @usable ) // $usable[0]
			:                  ( first { $_ < $current } reverse @usable ) // $usable[-1];
		$self->highlight_item($target);
		return 1;
	}

	method handle_mouse ($event) {
		return 0 unless refaddr( $event->target ) == refaddr($self);
		return 0 unless $event->key == TB_KEY_MOUSE_LEFT && !( $event->modifiers & TB_MOD_MOTION );
		my ($column) = $self->cell_at($event);
		return 0 unless defined $column;
		my $menu = $self->_menu_at($column);
		return 1 unless defined $menu;
		defined $open && $open == $menu ? $self->close : $self->open($menu);
		return 1;
	}

	# While a menu is open, the pointer over another title opens that menu.
	method pointer_over ($event) {
		return unless defined $open;
		my ($column) = $self->cell_at($event);
		my $menu = defined $column ? $self->_menu_at($column) : undef;
		$self->open($menu) if defined $menu && $menu != $open;
		return;
	}

	# ---------------------------------------------------------------------
	# Painting
	# ---------------------------------------------------------------------

	# The colors the bar and its menus are drawn in, from the theme's
	# dropdown family: [ fg, bg ] of the bar, a highlight, a dim text.
	method colors () {
		return (
			bar        => [ $self->color_attr( $self->family_look( input => 'text' ) ), $self->color_attr( $self->family_look( dropdown => 'list.background' ) ) ],
			highlight  => [ $self->color_attr( $self->family_look( dropdown => 'highlight.text' ) ), $self->color_attr( $self->family_look( dropdown => 'highlight.background' ) ) ],
			dim        => $self->color_attr( $self->family_look( input => 'placeholder' ) ),
			disabled   => $self->color_attr( $self->family_look( input => 'text', 'disabled' ) ),
			border     => $self->family_look( dropdown => 'list.border.color' ),
			style      => $self->family_look( dropdown => 'list.border.style' ),
			background => $self->family_look( dropdown => 'list.background' ),
		);
	}

	method paint_key :override () {
		return ( $self->SUPER::paint_key, $open // -1, $self->is_focused );
	}

	method paint () {
		my %color = $self->colors;
		my ( $fg, $bg ) = @{ $color{bar} };
		$self->fill_attrs( 0, 0, $self->columns, ' ', $fg, $bg );
		foreach my $index ( 0 .. $#menus ) {
			my $column = $self->_title_column($index) - 1;
			my ( $title_fg, $title_bg ) = defined $open && $open == $index ? @{ $color{highlight} } : ( $fg, $bg );
			$self->fill_attrs( $column, 0, string_columns( $menus[$index]{title} ) + 2, ' ', $title_fg, $title_bg );
			my $title = $menus[$index]{title};
			my $mark  = index( lc $title, lc $menus[$index]{key} );
			my $x     = $column + 1;
			foreach my $position ( 0 .. length($title) - 1 ) {
				my $glyph = substr( $title, $position, 1 );
				$self->put_attrs( $x, 0, $glyph, $position == $mark ? $title_fg | TB_UNDERLINE : $title_fg, $title_bg );
				$x += string_columns($glyph);
			}
		}
		my $width = string_columns($caption);
		$self->paint_text( $self->columns - $width - 1, 0, $caption, $color{dim}, $bg ) if $width + 2 < $self->columns - ( $self->natural_size )[0];
		return;
	}
}

# The list of an open menu.
class Term::Fabulous::ThemeEditor::MenuBar::Popup :isa(Term::Fabulous::Widget::Display) :strict(params) {
	use Clay::UI::Enum::Result;
	use List::Util qw(max);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant SEPARATOR => "\x{2500}";

	field $bar :param :weak;
	field $menu :param;

	ADJUST {
		$self->border_width(1);
		weaken( my $weak_self = $self );
		$self->on( Mouse     => sub ($event) { $weak_self->_mouse($event); return Clay::UI::Enum::Result->HANDLED } );
		$self->on( MouseMove => sub ($event) { $weak_self->_hover($event); return Clay::UI::Enum::Result->HANDLED } );
	}

	method _label_columns () {
		return max( 0, map { string_columns( $_->{label} ) } grep { ref } @{ $menu->{items} } );
	}

	method _keys_columns () {
		return max( 0, map { string_columns( $_->{keys} // '' ) } grep { ref } @{ $menu->{items} } );
	}

	method natural_size () {
		my $keys = $self->_keys_columns;
		return ( 1 + $self->_label_columns + ( $keys ? 3 + $keys : 0 ) + 1, scalar @{ $menu->{items} } );
	}

	method background_color :override (@new) {
		return $self->SUPER::background_color(@new) if @new;
		return defined $bar ? { $bar->colors }->{background} : undef;
	}

	method border_color :override (@new) {
		return $self->SUPER::border_color(@new) if @new;
		return defined $bar ? { $bar->colors }->{border} : undef;
	}

	method derived_border_style ($side) {
		return defined $bar ? { $bar->colors }->{style} : undef;
	}

	method contribute_look_theme :override ($config) {
		return unless defined $bar;
		$config->{background_color} = $self->background_color;
		my $border = $config->{border} // return;
		$config->{border} = { %$border, color => $self->border_color };
		return;
	}

	method paint_key :override () {
		return ( $self->SUPER::paint_key ) unless defined $bar;
		return ( $self->SUPER::paint_key, $bar->highlighted // -1, map { $bar->item_enabled($_) } @{ $menu->{items} } );
	}

	method paint () {
		return unless defined $bar;
		my %color = $bar->colors;
		my ( $fg, $bg ) = @{ $color{bar} };
		my $items = $menu->{items};
		foreach my $row ( 0 .. $#$items ) {
			my $item = $items->[$row];
			if ( !ref $item ) {
				$self->fill_attrs( 0, $row, $self->columns, SEPARATOR, $color{dim}, $bg );
				next;
			}
			my $is_highlighted = defined $bar->highlighted && $bar->highlighted == $row;
			my $is_enabled     = $bar->item_enabled($item);
			my ( $item_fg, $item_bg ) = $is_highlighted ? @{ $color{highlight} } : ( $is_enabled ? $fg : $color{disabled}, $bg );
			$self->fill_attrs( 0, $row, $self->columns, ' ', $item_fg, $item_bg );
			$self->paint_text( 1, $row, $item->{label}, $item_fg, $item_bg );
			my $keys = $item->{keys} // next;
			$self->paint_text( $self->columns - 1 - string_columns($keys), $row, $keys, $is_highlighted ? $item_fg : $color{dim}, $item_bg );
		}
		return;
	}

	method _row_of ($event) {
		my ( undef, $row ) = $self->cell_at($event);
		return $row;
	}

	method _mouse ($event) {
		return unless defined $bar;
		my $row = $self->_row_of($event) // return;
		$bar->highlight_item($row) if $event->key == TB_KEY_MOUSE_LEFT;
		$bar->activate_item($row) if $event->key == TB_KEY_MOUSE_RELEASE;
		return;
	}

	method _hover ($event) {
		return unless defined $bar;
		my $row = $self->_row_of($event) // return;
		$bar->highlight_item($row);
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::MenuBar - The menu bar of the theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. One row of menu titles; a menu opens below its title as a list of
commands with their keys. The bar takes the focus only while a menu is
open, and gives it back to the widget that had it when the menu closes.
It is drawn in the colors of the theme's C<dropdown> family.

Keys while a menu is open: C<Left> and C<Right> (or C<Shift+Tab> and
C<Tab>) switch menus, C<Up>,
C<Down>, C<Home>, C<End> move between the commands that can run now,
C<Enter> or C<Space> runs one, C<Escape> or C<F10> closes the menu, and
C<Alt> with a menu's underlined letter switches to that menu. Other
plain keys do nothing; keys with C<Ctrl> or C<Alt> close the menu and
go on to the editor. The mouse opens a menu with a click on
its title, switches menus by moving over the titles, and runs a
command when the button is released over it.

=head1 CONSTRUCTOR

=head2 new

	my $bar = Term::Fabulous::ThemeEditor::MenuBar->new(
		menus   => [ { title => 'File', key => 'f', items => [ { label => 'Save', command => 'save', keys => 'Ctrl+S' }, '-' ] } ],
		run     => sub ($command) { ... },
		enabled => sub ($command) { ... },
		caption => 'Theme editor',
	);

C<menus> lists the menus with their mnemonic letter and items; C<'-'>
is a separator. C<run> runs a command, C<enabled> says whether one can
run now. C<caption> is shown at the right end of the bar.

=head1 METHODS

=head2 value

The index of the open menu, or C<undef> (what an input widget reports
as its value).

=head2 open, close, is_open, open_menu

Open a menu by index (taking the focus), close it (giving the focus
back), whether one is open and which.

=head2 menu_for_key

The index of the menu with a mnemonic letter, or C<undef>.

=head2 highlighted, highlight_item, activate_item

The highlighted item of the open menu, highlight one, run one.

=head2 captures_tab

True while a menu is open: C<Tab> and C<Shift+Tab> switch menus then.

=head2 item_enabled

Whether an item's command can run now.

=head2 menus

The menus as given.

=head2 colors

The termbox attributes the bar and its menus are drawn with.

=head2 pointer_over

Opens the menu under the pointer while another one is open.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
