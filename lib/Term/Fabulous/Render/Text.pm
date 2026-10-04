package Term::Fabulous::Render::Text;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Text {
	use List::Util qw(min);
	use Term::Fabulous::Termbox qw(TB_DEFAULT);
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);
	use Term::Fabulous::Render::Geometry qw(cell_rect);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	use constant CLUSTER_CACHE_LIMIT => 4096;

	# Text contents rarely change between frames: memoize the sanitized
	# clusters and their widths per string.
	my %clusters_by_text;

	sub _clusters_with_columns ($text) {
		my $clusters = $clusters_by_text{$text};
		return $clusters if defined $clusters;

		%clusters_by_text = () if keys(%clusters_by_text) >= CLUSTER_CACHE_LIMIT;
		return $clusters_by_text{$text} = [ map { [ $_, cluster_columns($_) ] } grapheme_clusters($text) ];
	}

	# The cells the command being painted may touch (Term::Fabulous::Render).
	method clip_rect;

	# The cell target the frame is painted into (Term::Fabulous::Render).
	method cell_target;

	# Draws one line of text from the top-left cell of its bounding box.
	# Clusters are sanitized (no control characters reach the terminal) and
	# advance by the same widths the measure callback reported. Drawing stops
	# before a cluster that would cross the box's right edge or the clip
	# rect; clusters left of the clip rect are skipped but still advance.
	method render_text ( $command, $widget, $buffer ) {
		my ( $x, $y, $x1 ) = cell_rect( $command->{boundingBox} );
		my ( $clip_x0, $clip_y0, $clip_x1, $clip_y1 ) = @{ $self->clip_rect };
		return if $y < $clip_y0 || $y >= $clip_y1;

		my $right_limit = min( $x1, $clip_x1 );
		my $data        = $command->{renderData};
		my $fg_attr     = color_attr( clay_color( $data->{textColor} ) ) | ( defined $widget && $widget->can('style_attrs') ? $widget->style_attrs : 0 );
		my $row         = $buffer->[$y] //= [];
		my $target      = $self->cell_target;

		foreach my $cluster_with_columns ( @{ _clusters_with_columns( $data->{stringContents} ) } ) {
			my ( $cluster, $columns ) = @$cluster_with_columns;
			last if $x + $columns > $right_limit;

			if ( $x >= $clip_x0 ) {
				my $bg_attr = $row->[$x] // TB_DEFAULT;
				my ( $base, @extenders ) = split //, $cluster;
				$target->set_cell( $x, $y, $base, $fg_attr, $bg_attr );
				$target->extend_cell( $x, $y, $_ ) foreach @extenders;
				$row->[$_] = $bg_attr foreach $x .. $x + $columns - 1;
			}
			$x += $columns;
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Render::Text - Paint lines of text

=head1 SYNOPSIS

	# Composed by Term::Fabulous::Render; called from draw for every
	# text render command:
	$ui->render_text( $command, $widget, $buffer );

=head1 DESCRIPTION

Most programs never use this module directly, and neither do widgets
of your own. It is one of the roles L<Term::Fabulous::Render> is made
of, and it paints the text render commands Clay emits for
L<Term::Fabulous::Widget::Text> widgets. Clay breaks a widget's text
into lines; each text command is one line. Read it if you write your
own UI class or want to know exactly how text is drawn.

=head1 METHODS

=head2 render_text

	$ui->render_text( $command, $widget, $buffer );

Paints one line of text, starting at the top-left cell of the command's
bounding box, in the command's text color with the style bits of the
widget (bold, italic, underline; see
L<Term::Fabulous::Widget::Text/style_attrs>), when the widget has any:

=over

=item *

The text (C<stringContents>, a character string) has its control
characters replaced (see L<Term::Fabulous::Unicode/sanitize_text>) and
is split into grapheme clusters.

=item *

Every cluster advances by the number of columns termbox2 uses for it
(see L<Term::Fabulous::Unicode/cluster_columns>), so measuring and
drawing agree.

=item *

The line ends before the first cluster that would cross the right edge
of the bounding box or of the clip area. Clusters left of the clip area
are not painted but still advance.

=item *

The background of each cell is the one recorded in C<$buffer> (an array
reference of rows of attributes, C<< $buffer->[$y][$x] >>) by whatever
was painted there before in this frame, or the terminal default.

=back

The line is skipped when its row lies outside the clip area. Segmented
lines are cached by their text (the cache is emptied when it reaches
4096 entries), because texts rarely change between frames.

=head1 REQUIRED METHODS

The consuming class provides C<cell_target>, which returns the cell
target the text is painted into (its C<set_cell> and C<extend_cell> are
called; see L<Term::Fabulous::Render/CELL TARGET>), and C<clip_rect>
(from L<Term::Fabulous::Render>, see L<Term::Fabulous::Render/clip_rect>).

=head1 SEE ALSO

L<Term::Fabulous::Render>, L<Term::Fabulous::Widget::Text>,
L<Term::Fabulous::Unicode>.

=cut
