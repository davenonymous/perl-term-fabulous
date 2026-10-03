package Term::Fabulous::Widget::Histogram;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::XYChart;

class Term::Fabulous::Widget::Histogram
	:isa(Term::Fabulous::Widget::XYChart)
	:strict(params)
{
	use Carp qw(croak);
	use List::Util ();
	use POSIX qw(ceil floor);
	use Term::Fabulous::Check qw(boolean);
	use Term::Fabulous::Chart::Format qw(format_value);
	use Term::Fabulous::Chart::Transform qw(apply_transforms);
	use Term::Fabulous::Widget::Table::Value qw(number_of);

	use constant {
		MOST_AUTO_BINS  => 50,
		OVERLAP_OPACITY => 0.6,
	};

	my %IS_MEASURE = map { $_ => 1 } qw(count percent density);

	field $bins       :param = 'auto';
	field $bin_width  :param = undef;
	field $range      :param = undef;
	field $measure    :param = 'count';
	field $cumulative :param = 0;

	ADJUST {
		$bins       = $self->_checked_bins($bins);
		$bin_width  = $self->_checked_bin_width($bin_width);
		$range      = $self->_checked_range($range);
		$measure    = $self->_check_choice( measure => $measure, \%IS_MEASURE );
		$cumulative = boolean( $self, cumulative => $cumulative );
	}

	method default_series_type ()           { return 'bar' }
	method series_types :override ()        { return 'bar' }

	method _checked_bins ($value) {
		return 'auto' if defined $value && !ref $value && $value eq 'auto';
		$self->_fail( 'bins', "'auto' or a positive integer", $value ) unless defined $value && !ref $value && $value =~ /\A[1-9][0-9]*\z/;
		return $value + 0;
	}

	method _checked_bin_width ($value) {
		return undef unless defined $value;
		$self->_fail( 'bin_width', 'a positive number or undef', $value ) unless defined number_of($value) && $value > 0;
		return $value + 0;
	}

	method _checked_range ($value) {
		return undef unless defined $value;
		$self->_fail( 'range', 'an array reference [ low, high ] with low below high, or undef', $value )
			unless ref $value eq 'ARRAY' && @$value == 2 && ( grep { defined number_of($_) } @$value ) == 2 && $value->[0] < $value->[1];
		return [ map { $_ + 0 } @$value ];
	}

	method _set ( $field_ref, $value ) {
		$$field_ref = $value;
		$self->mark_changed;
		return $value;
	}

	method bins (@new)       { return @new ? $self->_set( \$bins,       $self->_checked_bins( $new[0] ) )                       : $bins }
	method bin_width (@new)  { return @new ? $self->_set( \$bin_width,  $self->_checked_bin_width( $new[0] ) )                  : $bin_width }
	method measure (@new)    { return @new ? $self->_set( \$measure,    $self->_check_choice( measure => $new[0], \%IS_MEASURE ) ) : $measure }
	method cumulative (@new) { return @new ? $self->_set( \$cumulative, boolean( $self, cumulative => $new[0] ) )              : $cumulative }

	method range (@new) {
		return defined $range ? [@$range] : undef unless @new;
		$self->_set( \$range, $self->_checked_range( $new[0] ) );
		return $self->range;
	}

	# ---------------------------------------------------------------------
	# Bins
	# ---------------------------------------------------------------------

	# The observations of a series: its y values (plain numbers), after its
	# transform.
	method _observations ($series) {
		my @values;
		foreach my $point ( $series->points->@* ) {
			croak ref($self) . ": series '" . $series->name . "' of a histogram takes plain numbers, not [ x, y ] points" if defined $point->[0];
			push @values, $point->[1] if defined $point->[1];
		}
		if ( my $steps = $self->series_option( $series, 'transform' ) ) {
			( undef, my $ys ) = apply_transforms( $steps, [ 0 .. $#values ], \@values );
			@values = grep { defined } @$ys;
		}
		return \@values;
	}

	# A nice width near $width: 1, 2, 2.5 or 5 times a power of ten.
	sub _nice_width ($width) {
		my $power = 10**floor( log($width) / log(10) );
		foreach my $mantissa ( 1, 2, 2.5, 5, 10 ) {
			return $mantissa * $power if $mantissa * $power >= $width * 0.75;
		}
		return 10 * $power;
	}

	# The edges of the bins over all observations.
	method bin_edges (@samples) {
		my @all = map {@$_} @samples;
		my ( $low, $high ) = $range ? @$range : @all ? ( List::Util::min(@all), List::Util::max(@all) ) : ( 0, 1 );
		$high = $low + 1 if $high <= $low;
		if ( defined $bin_width || $bins eq 'auto' ) {
			my $width = $bin_width // _nice_width( _auto_width( \@all, $low, $high ) );
			my $first = $range ? $low  : floor( $low / $width + 1e-9 ) * $width;
			my $last  = $range ? $high : ceil( $high / $width - 1e-9 ) * $width;
			$last += $width if $last <= $first;
			my $count = List::Util::max( 1, ceil( ( $last - $first ) / $width - 1e-9 ) );
			return map { List::Util::min( $first + $_ * $width, $last ) } 0 .. $count;
		}
		return map { $low + ( $high - $low ) * $_ / $bins } 0 .. $bins;
	}

	# Freedman-Diaconis (twice the interquartile range over the cube root
	# of the count), or Sturges' rule when the quartiles coincide.
	sub _auto_width ( $values, $low, $high ) {
		my @sorted = sort { $a <=> $b } @$values;
		my $count  = @sorted;
		return ( $high - $low ) / 10 if $count < 2;
		my $quartile = sub ($p) {
			my $at = ( $count - 1 ) * $p;
			my $below = floor($at);
			return $sorted[$below] + ( $sorted[ List::Util::min( $below + 1, $#sorted ) ] - $sorted[$below] ) * ( $at - $below );
		};
		my $spread = $quartile->(0.75) - $quartile->(0.25);
		my $width  = $spread > 0 ? 2 * $spread / $count**( 1 / 3 ) : ( $high - $low ) / ( ceil( log($count) / log(2) ) + 1 );
		my $least  = ( $high - $low ) / MOST_AUTO_BINS;
		return List::Util::max( $width, $least ) || 1;
	}

	# The counts of the series per bin, as the measure says.
	method prepare_series :override () {
		my @series  = $self->visible_series;
		my @samples = map { $self->_observations($_) } @series;
		my @edges   = $self->bin_edges(@samples);
		my $last    = $#edges - 1;
		my @labels  = map { format_value( $edges[$_] ) . "\x{2013}" . format_value( $edges[ $_ + 1 ] ) } 0 .. $last;
		my @prepared;
		foreach my $index ( 0 .. $#series ) {
			my @counts = (0) x ( $last + 1 );
			foreach my $value ( $samples[$index]->@* ) {
				next if $value < $edges[0] || $value > $edges[-1];
				my $bin = 0;
				my ( $low, $high ) = ( 0, $last );
				while ( $low < $high ) {
					my $middle = int( ( $low + $high + 1 ) / 2 );
					$edges[$middle] <= $value ? ( $low = $middle ) : ( $high = $middle - 1 );
				}
				$counts[$low]++;
			}
			my $total = List::Util::sum0(@counts) || 1;
			my @values
				= $measure eq 'percent' ? map { $_ / $total } @counts
				: $measure eq 'density' ? map { $counts[$_] / $total / ( $edges[ $_ + 1 ] - $edges[$_] ) } 0 .. $last
				:                         @counts;
			if ($cumulative) {
				my $sum = 0;
				@values = map { $sum += $_ } @values;
			}
			push @prepared, {
				series => $series[$index],
				name   => $series[$index]->name,
				type   => 'bar',
				xs     => [ map { ( $edges[$_] + $edges[ $_ + 1 ] ) / 2 } 0 .. $last ],
				ys     => \@values,
				edges  => [ map { [ $edges[$_], $edges[ $_ + 1 ] ] } 0 .. $last ],
				labels => \@labels,
			};
		}
		$self->stack_series( \@prepared );
		return ( 'linear', [], \@prepared );
	}

	# Overlapping datasets show through each other; stacked ones are opaque.
	method default_bar_opacity :override ($bars) {
		my @overlapping = grep { !defined $_->{group} } @$bars;
		return @overlapping > 1 ? OVERLAP_OPACITY : 1;
	}

	method value_format :override () {
		my $format = $self->SUPER::value_format;
		return $format // ( $measure eq 'percent' ? 'percent' : undef );
	}

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			bins       => 'scalar',
			bin_width  => 'scalar',
			measure    => 'scalar',
			cumulative => 'boolean',
			range      => \&_parse_range,
		);
	}

	# range 0 100
	method _parse_range ($kid) {
		my @args = map { $_->as_perl } $kid->args->@*;
		croak ref($self) . ": layout property 'range' takes a low and a high value" unless @args == 2 && !$kid->props->@* && !$kid->children->@*;
		$self->range( \@args );
		return;
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::Histogram - How values are distributed: counts in
bins

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Histogram;

	my $chart = Term::Fabulous::Widget::Histogram->new(
		title  => 'Response times',
		x_axis => { title => 'milliseconds' },
		y_axis => { title => 'requests' },
		series => [
			{ name => 'eu-west', data => \@durations_eu },    # plain numbers: the observations
			{ name => 'us-east', data => \@durations_us },
		],
	);

	$chart->bin_width(25);                    # bins 25 ms wide
	$chart->range( [ 0, 500 ] );              # from 0 to 500 ms
	$chart->measure('percent');               # the share of the observations per bin
	$chart->cumulative(1);                    # running total: a distribution function
	$chart->add_points( 'eu-west', 131.5 );  # bins are counted again

=begin html

<p><img src="/screenshots/widget-histogram.svg" alt="Two overlapping translucent histograms of response times in milliseconds, with the number of requests on the y axis"></p>

=end html

=head1 DESCRIPTION

A histogram shows how a set of numbers is distributed: the x axis is
divided into bins of equal width, and each bin is a bar as high as the
number of observations that fall into it. Give each series its
observations as plain numbers; the chart counts them when a frame is
drawn, and counts again when the data or the bins change.

By default the chart chooses the bin width from the data (the
Freedman-Diaconis rule: twice the interquartile range over the cube root
of the count, rounded to 1, 2, 2.5 or 5 times a power of ten, at most
fifty bins), and the bins start at a multiple of that width. C<bins>
asks for a number of bins over the data's range, C<bin_width> for a
width, C<range> fixes the ends. With several series, the same bins count
every series, and the bars of different series overlap, translucent, so
both distributions are visible; with C<stacked> they stack.

C<measure> decides what a bar's height is: the C<count> of
observations, their C<percent> of the series (as a fraction; the axis
shows percentages), or the C<density> (the share divided by the bin
width, so the area under the histogram is 1 and bins of different
widths compare). C<cumulative> accumulates the bins from the left.

A Histogram is a L<Term::Fabulous::Widget::XYChart> of bar series, with
the x axis fixed to numbers from the first bin's left edge to the last
bin's right edge, so C<labels>, C<horizontal> and the other series types
are not for it; the axis keys, C<value_labels>, C<marker>,
C<fill_opacity>, transforms (run on the observations before they are
counted) and hover work as described there. Hover reports the bin as the
point: its range as the label and its count as the value.

=head1 CONSTRUCTOR

=head2 new

	my $chart = Term::Fabulous::Widget::Histogram->new(%parameters);

The parameters of L<Term::Fabulous::Widget::XYChart/CONSTRUCTOR> and
L<Term::Fabulous::Widget::Chart/CONSTRUCTOR>, and:

=over

=item C<bins>

C<auto> (the default) or a positive integer: the number of bins over the
range of the data (or C<range>).

=item C<bin_width>

A positive number: the width of every bin. Default: C<undef>, which lets
C<bins> decide. When given, C<bins> is not used.

=item C<range>

C<[ $low, $high ]>: the ends of the first and the last bin.
Observations outside are not counted. Default: C<undef>, the smallest
and largest observation (rounded out to the bin width with automatic
bins).

=item C<measure>

C<count> (the default), C<percent> or C<density>.

=item C<cumulative>

A boolean. Default: false.

=back

=head1 METHODS

C<bins>, C<bin_width>, C<range>, C<measure> and C<cumulative> read and
set the parameters (C<range> returns a copy), and the methods of
L<Term::Fabulous::Widget::XYChart/METHODS> manage the series.

=head1 KDL PROPERTIES

	use Term::Fabulous::Widget::Histogram as Histogram

	Histogram "latency" {
		bins 20
		range 0 500
		measure "percent"
		cumulative #false
		series "eu-west" { data 120 131 98 145 }
	}

C<bins>, C<bin_width>, C<measure>, C<cumulative> as the parameters,
C<range> with the low and the high value as its arguments, and the
properties of L<Term::Fabulous::Widget::XYChart/KDL PROPERTIES>.

=head1 SEE ALSO

L<Term::Fabulous::Widget::XYChart>, L<Term::Fabulous::Widget::BarChart>,
L<Term::Fabulous::Cookbook/CHARTS>.

=cut
