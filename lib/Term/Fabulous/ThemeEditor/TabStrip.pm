package Term::Fabulous::ThemeEditor::TabStrip;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Display;

# The row of the open themes: a tab per theme with its name, a mark for
# unsaved changes or errors and a close button, and a button for a new
# theme.
class Term::Fabulous::ThemeEditor::TabStrip :isa(Term::Fabulous::Widget::Display) :strict(params) {
	use Clay::UI::Enum::Result;
	use List::Util qw(sum0);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_MIDDLE TB_MOD_MOTION TB_BOLD);
	use Term::Fabulous::Unicode qw(string_columns);

	use constant MODIFIED   => "\x{25CF}";    # a dot: unsaved changes
	use constant HAS_ERRORS => '!';
	use constant CLOSE      => "\x{00D7}";
	use constant NEW        => ' + ';
	use constant MORE_LEFT  => "\x{25C2}";
	use constant MORE_RIGHT => "\x{25B8}";

	# code: the tabs as [ { title, modified, errors, active } ]
	field $tabs      :param;
	field $on_select :param;
	field $on_close  :param;
	field $on_new    :param;

	# What the last paint put where: [ from, to, action, index ] per region.
	field @regions;

	ADJUST {
		weaken( my $weak_self = $self );
		$self->on( Mouse => sub ($event) { return $weak_self->_mouse($event) ? Clay::UI::Enum::Result->HANDLED : Clay::UI::Enum::Result->CONTINUE } );
	}

	method natural_size () {
		return ( 0, 1 );
	}

	method _label ($tab) {
		my $mark = $tab->{errors} ? HAS_ERRORS : $tab->{modified} ? MODIFIED : ' ';
		return " $tab->{title} $mark " . CLOSE . ' ';
	}

	method paint_key :override () {
		return ( $self->SUPER::paint_key, map { join "\x{1E}", @{$_}{qw(title modified errors active)} } $tabs->() );
	}

	method paint () {
		my @tabs   = $tabs->();
		my $width  = $self->columns;
		my $bar_bg = $self->color_attr( $self->family_look( dropdown => 'list.background' ) );
		my $dim    = $self->color_attr( $self->family_look( tabs     => 'text' ) );
		my $active = $self->color_attr( $self->family_look( tabs     => 'text',       'active' ) );
		my $tab_bg = $self->color_attr( $self->family_look( input    => 'background', 'focused' ) );
		my $accent = $self->color_attr( $self->family_look( input    => 'accent' ) );
		my $danger = $self->color_attr( $self->family_look( input    => 'text', 'invalid' ) );
		@regions = ();
		$self->fill_attrs( 0, 0, $width, ' ', $dim, $bar_bg );

		my @widths    = map { string_columns( $self->_label($_) ) } @tabs;
		my ($current) = grep { $tabs[$_]{active} } 0 .. $#tabs;
		my $first     = $self->_first_shown( \@widths, $current // 0, $width - 2 - length NEW );
		my $x         = 0;
		if ( $first > 0 ) {
			$self->put_attrs( 0, 0, MORE_LEFT, $accent, $bar_bg );
			push @regions, [ 0, 0, 'select', $first - 1 ];
			$x = 1;
		}
		foreach my $index ( $first .. $#tabs ) {
			last if $x + $widths[$index] > $width - 1 - length NEW;
			my $tab = $tabs[$index];
			my ( $fg, $bg ) = $tab->{active} ? ( $active | TB_BOLD, $tab_bg ) : ( $dim, $bar_bg );
			my $label = $self->_label($tab);
			$self->paint_text( $x, 0, $label, $fg, $bg );
			my $mark_x = $x + 1 + string_columns( $tab->{title} ) + 1;
			$self->put_attrs( $mark_x, 0, $tab->{errors} ? HAS_ERRORS : MODIFIED, $tab->{errors} ? $danger : $accent, $bg ) if $tab->{errors} || $tab->{modified};
			push @regions, [ $x, $mark_x + 1, 'select', $index ], [ $mark_x + 2, $mark_x + 2, 'close', $index ];
			$x += $widths[$index];
			$self->put_attrs( $x - 1, 0, ' ', $fg, $bg );

			if ( $index < $#tabs && $x + $widths[ $index + 1 ] > $width - 1 - length NEW ) {
				$self->put_attrs( $x, 0, MORE_RIGHT, $accent, $bar_bg );
				push @regions, [ $x, $x, 'select', $index + 1 ];
				$x++;
				last;
			}
		}
		$self->paint_text( $x, 0, NEW, $accent, $bar_bg );
		push @regions, [ $x, $x + length(NEW) - 1, 'new', undef ];
		return;
	}

	# The first tab shown: the strip scrolls so that the active tab fits.
	method _first_shown ( $widths, $active, $room ) {
		my $first = 0;
		$first++ while $first < $active && sum0( @{$widths}[ $first .. $active ] ) + ( $first > 0 ? 1 : 0 ) > $room;
		return $first;
	}

	method _mouse ($event) {
		return 0 if $event->modifiers & TB_MOD_MOTION;
		my ($column) = $self->cell_at($event);
		return 0 unless defined $column;
		my ($region) = grep { $column >= $_->[0] && $column <= $_->[1] } @regions;
		return 1 unless defined $region;
		my ( undef, undef, $action, $index ) = @$region;
		if ( $event->key == TB_KEY_MOUSE_MIDDLE && defined $index ) {
			$on_close->($index);
			return 1;
		}
		return 1 unless $event->key == TB_KEY_MOUSE_LEFT;
		$action eq 'select' ? $on_select->($index) : $action eq 'close' ? $on_close->($index) : $on_new->();
		return 1;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::TabStrip - The row of open themes in the
theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. One row with a tab per open theme: its name, a dot when it has
unsaved changes or an exclamation mark when its text has errors, and a
close button; a C<+> button at the end makes a new theme. The active
tab is drawn in the colors of the theme's C<tabs> family. When the
tabs do not fit, the strip scrolls to the active one and shows arrows
at the ends, which select the next hidden tab.

A click on a tab selects it, a click on its close button or a middle
click on it closes it, a click on C<+> makes a new theme.

=head1 CONSTRUCTOR

=head2 new

	my $strip = Term::Fabulous::ThemeEditor::TabStrip->new(
		tabs      => sub { ( { title => 'ocean.kdl', modified => 1, errors => 0, active => 1 }, ... ) },
		on_select => sub ($index) { ... },
		on_close  => sub ($index) { ... },
		on_new    => sub () { ... },
	);

C<tabs> returns the tabs to show, read whenever a frame is drawn.

=head1 METHODS

=head2 natural_size, paint, paint_key

As in L<Term::Fabulous::Widget::Display>.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
