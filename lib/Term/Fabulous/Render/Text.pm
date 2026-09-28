package Term::Fabulous::Render::Text;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

role Term::Fabulous::Render::Text {
	use Encode qw(decode);
	use List::Util qw(min);
	use Termbox 2 qw(TB_DEFAULT);
	use Term::Fabulous::Render::Attr qw(color_attr clay_color);
	use Term::Fabulous::Render::Geometry qw(cell_rect);
	use Term::Fabulous::Unicode qw(grapheme_clusters cluster_columns);

	use constant CLUSTER_CACHE_LIMIT => 4096;

	# Text contents rarely change between frames: memoize the decoded,
	# sanitized clusters and their widths per UTF-8 string.
	my %clusters_by_text;

	sub _clusters_with_columns ($utf8_text) {
		my $clusters = $clusters_by_text{$utf8_text};
		return $clusters if defined $clusters;

		%clusters_by_text = () if keys(%clusters_by_text) >= CLUSTER_CACHE_LIMIT;
		my $text = decode( 'UTF-8', $utf8_text, Encode::FB_DEFAULT );
		return $clusters_by_text{$utf8_text} = [ map { [ $_, cluster_columns($_) ] } grapheme_clusters($text) ];
	}

	method width;
	method height;
	method set_cell;
	method extend_cell;

	# Draws one line of text from the top-left cell of its bounding box.
	# Clusters are sanitized (no control characters reach the terminal) and
	# advance by the same widths the measure callback reported. Drawing stops
	# before a cluster that would cross the box's right edge or the viewport;
	# clusters left of the viewport are skipped but still advance.
	method render_text ( $command, $widget, $buffer ) {
		my ( $x, $y, $x1 ) = cell_rect( $command->{boundingBox} );
		return if $y < 0 || $y >= $self->height;

		my $right_limit = min( $x1, $self->width );
		my $data        = $command->{renderData};
		my $fg_attr     = color_attr( clay_color( $data->{textColor} ) );
		my $row         = $buffer->[$y] //= [];

		foreach my $cluster_with_columns ( @{ _clusters_with_columns( $data->{stringContents} ) } ) {
			my ( $cluster, $columns ) = @$cluster_with_columns;
			last if $x + $columns > $right_limit;

			if ( $x >= 0 ) {
				my $bg_attr = $row->[$x] // TB_DEFAULT;
				my ( $base, @extenders ) = split //, $cluster;
				$self->set_cell( $x, $y, $base, $fg_attr, $bg_attr );
				$self->extend_cell( $x, $y, $_ ) foreach @extenders;
				$row->[$_] = $bg_attr foreach $x .. $x + $columns - 1;
			}
			$x += $columns;
		}
		return;
	}
}

1;
