package Term::Fabulous::Chart::Transform;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(parse_transforms apply_transforms transform_names);

use Carp qw(croak);
use List::Util qw(max min sum0 first);
use POSIX qw(floor);
use Scalar::Util qw(looks_like_number);
use Term::Fabulous::Check qw(describe);

sub _is_number ($value) {
	return defined $value && !ref $value && looks_like_number($value) && $value == $value && $value - $value == 0;
}

sub _defined_ys ($ys) {
	return grep { defined } @$ys;
}

# Each transform: the arguments it takes [ least, most, defaults ], a
# check of them, and a function from (xs, ys, args) to new (xs, ys).
my %TRANSFORM = (
	normalize => {
		arguments => [ 0, 2, [ 0, 1 ] ],
		apply     => sub ( $xs, $ys, $low, $high ) {
			my @values = _defined_ys($ys) or return ( $xs, $ys );
			my ( $least, $most ) = ( min(@values), max(@values) );
			my $range = $most - $least;
			return ( $xs, [ map { defined ? ( $range ? $low + ( $_ - $least ) / $range * ( $high - $low ) : $low ) : undef } @$ys ] );
		},
	},
	share => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my $total = sum0( map { abs } _defined_ys($ys) );
			return ( $xs, [ map { defined && $total ? $_ / $total : defined ? 0 : undef } @$ys ] );
		},
	},
	zscore => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my @values = _defined_ys($ys) or return ( $xs, $ys );
			my $mean      = sum0(@values) / @values;
			my $deviation = sqrt( sum0( map { ( $_ - $mean )**2 } @values ) / @values );
			return ( $xs, [ map { defined ? ( $deviation ? ( $_ - $mean ) / $deviation : 0 ) : undef } @$ys ] );
		},
	},
	index => {
		arguments => [ 0, 1, [100] ],
		apply     => sub ( $xs, $ys, $base ) {
			my $start = first { defined && $_ != 0 } @$ys;
			return ( $xs, [ map { defined && defined $start ? $_ / $start * $base : undef } @$ys ] );
		},
	},
	cumulative => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my $total = 0;
			return ( $xs, [ map { defined ? ( $total += $_ ) : undef } @$ys ] );
		},
	},
	difference => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my $previous;
			return ( $xs, [ map { my $change = defined $_ && defined $previous ? $_ - $previous : undef; $previous = $_ if defined; $change } @$ys ] );
		},
	},
	rate => {
		arguments => [ 0, 1, [1] ],
		apply     => sub ( $xs, $ys, $per ) {
			my ( @rates, $before );
			foreach my $index ( 0 .. $#$ys ) {
				my $y = $ys->[$index];
				push @rates, defined $y && defined $before && $xs->[$index] != $before->[0] ? ( $y - $before->[1] ) / ( $xs->[$index] - $before->[0] ) * $per : undef;
				$before = [ $xs->[$index], $y ] if defined $y;
			}
			return ( $xs, \@rates );
		},
	},
	moving_average => {
		arguments => [ 1, 2, [ undef, 'trailing' ] ],
		check     => sub ( $window, $align ) {
			return "a window of at least 1 point" unless defined $window && $window =~ /\A[1-9][0-9]*\z/;
			return "an alignment of 'trailing' or 'center'" unless $align eq 'trailing' || $align eq 'center';
			return undef;
		},
		apply => sub ( $xs, $ys, $window, $align ) {
			my ( $before, $after ) = $align eq 'center' ? ( int( ( $window - 1 ) / 2 ), $window - 1 - int( ( $window - 1 ) / 2 ) ) : ( $window - 1, 0 );
			return ( $xs, [ map { _window_mean( $ys, $_, $before, $after ) } 0 .. $#$ys ] );
		},
	},
	exponential => {
		arguments => [ 1, 1, [] ],
		check     => sub ($alpha) { _is_number($alpha) && $alpha > 0 && $alpha <= 1 ? undef : "a smoothing factor greater than 0 and at most 1" },
		apply     => sub ( $xs, $ys, $alpha ) {
			my $smooth;
			return ( $xs, [ map { defined ? ( $smooth = defined $smooth ? $alpha * $_ + ( 1 - $alpha ) * $smooth : $_ ) : undef } @$ys ] );
		},
	},
	median => {
		arguments => [ 1, 1, [] ],
		check     => sub ($window) { defined $window && $window =~ /\A[1-9][0-9]*\z/ ? undef : "a window of at least 1 point" },
		apply     => sub ( $xs, $ys, $window ) {
			my ( $before, $after ) = ( int( ( $window - 1 ) / 2 ), $window - 1 - int( ( $window - 1 ) / 2 ) );
			my @medians = map {
				my $index = $_;
				!defined $ys->[$index] ? undef : do {
					my @near = sort { $a <=> $b } grep { defined } @$ys[ max( 0, $index - $before ) .. min( $#$ys, $index + $after ) ];
					@near % 2 ? $near[ $#near / 2 ] : ( $near[ @near / 2 - 1 ] + $near[ @near / 2 ] ) / 2;
				}
			} 0 .. $#$ys;
			return ( $xs, \@medians );
		},
	},
	gaussian => {
		arguments => [ 1, 1, [] ],
		check     => sub ($sigma) { _is_number($sigma) && $sigma > 0 ? undef : "a positive standard deviation (in points)" },
		apply     => sub ( $xs, $ys, $sigma ) {
			my $reach   = int( 3 * $sigma + 0.5 );
			my @weights = map { exp( -( $_**2 ) / ( 2 * $sigma**2 ) ) } -$reach .. $reach;
			my @smooth;
			foreach my $index ( 0 .. $#$ys ) {
				if ( !defined $ys->[$index] ) { push @smooth, undef; next }
				my ( $total, $weight ) = ( 0, 0 );
				foreach my $offset ( -$reach .. $reach ) {
					next if $index + $offset < 0;
					my $y = $ys->[ $index + $offset ] // next;
					$total  += $y * $weights[ $offset + $reach ];
					$weight += $weights[ $offset + $reach ];
				}
				push @smooth, $total / $weight;
			}
			return ( $xs, \@smooth );
		},
	},
	scale => {
		arguments => [ 1, 1, [] ],
		check     => sub ($factor) { _is_number($factor) ? undef : "a number to multiply by" },
		apply     => sub ( $xs, $ys, $factor ) { ( $xs, [ map { defined ? $_ * $factor : undef } @$ys ] ) },
	},
	offset => {
		arguments => [ 1, 1, [] ],
		check     => sub ($amount) { _is_number($amount) ? undef : "a number to add" },
		apply     => sub ( $xs, $ys, $amount ) { ( $xs, [ map { defined ? $_ + $amount : undef } @$ys ] ) },
	},
	clip => {
		arguments => [ 2, 2, [] ],
		check     => sub ( $low, $high ) { ( !defined $low || _is_number($low) ) && ( !defined $high || _is_number($high) ) && ( !defined $low || !defined $high || $low <= $high ) ? undef : "a lowest and a highest value (undef for none)" },
		apply     => sub ( $xs, $ys, $low, $high ) {
			return ( $xs, [ map { !defined ? undef : defined $low && $_ < $low ? $low : defined $high && $_ > $high ? $high : $_ } @$ys ] );
		},
	},
	abs => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) { ( $xs, [ map { defined ? abs : undef } @$ys ] ) },
	},
	sort => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my @order = sort { $xs->[$a] <=> $xs->[$b] } 0 .. $#$xs;
			return ( [ @$xs[@order] ], [ @$ys[@order] ] );
		},
	},
	resample => {
		arguments => [ 1, 2, [ undef, 'mean' ] ],
		check     => sub ( $interval, $aggregate ) {
			return "a positive interval" unless _is_number($interval) && $interval > 0;
			return "an aggregate of mean, sum, min, max, first, last or count" unless $aggregate =~ /\A(?:mean|sum|min|max|first|last|count)\z/;
			return undef;
		},
		apply => sub ( $xs, $ys, $interval, $aggregate ) {
			my ( %bucket, @starts );
			foreach my $index ( 0 .. $#$xs ) {
				my $start = floor( $xs->[$index] / $interval ) * $interval;
				push @starts, $start unless $bucket{$start};
				push @{ $bucket{$start} }, $ys->[$index] if defined $ys->[$index];
				$bucket{$start} //= [];
			}
			@starts = sort { $a <=> $b } @starts;
			return ( \@starts, [ map { _aggregate( $aggregate, $bucket{$_} ) } @starts ] );
		},
	},
	downsample => {
		arguments => [ 1, 1, [] ],
		check     => sub ($count) { defined $count && $count =~ /\A[0-9]+\z/ && $count >= 3 ? undef : "a number of points of at least 3" },
		apply     => \&_largest_triangles,
	},
	regression => {
		arguments => [ 0, 0, [] ],
		apply     => sub ( $xs, $ys ) {
			my @pairs = map { [ $xs->[$_], $ys->[$_] ] } grep { defined $ys->[$_] } 0 .. $#$xs;
			return ( $xs, [ (undef) x @$ys ] ) if @pairs < 2;
			my ( $mean_x, $mean_y ) = ( sum0( map { $_->[0] } @pairs ) / @pairs, sum0( map { $_->[1] } @pairs ) / @pairs );
			my $spread = sum0( map { ( $_->[0] - $mean_x )**2 } @pairs );
			my $slope  = $spread ? sum0( map { ( $_->[0] - $mean_x ) * ( $_->[1] - $mean_y ) } @pairs ) / $spread : 0;
			return ( $xs, [ map { $mean_y + $slope * ( $_ - $mean_x ) } @$xs ] );
		},
	},
);

sub _window_mean ( $ys, $index, $before, $after ) {
	return undef unless defined $ys->[$index];
	my @near = grep { defined } @$ys[ max( 0, $index - $before ) .. min( $#$ys, $index + $after ) ];
	return sum0(@near) / @near;
}

sub _aggregate ( $aggregate, $values ) {
	return scalar @$values if $aggregate eq 'count';
	return undef unless @$values;
	return sum0(@$values) / @$values if $aggregate eq 'mean';
	return sum0(@$values) if $aggregate eq 'sum';
	return min(@$values) if $aggregate eq 'min';
	return max(@$values) if $aggregate eq 'max';
	return $values->[0] if $aggregate eq 'first';
	return $values->[-1];
}

# Largest-Triangle-Three-Buckets: keeps the points that shape the line,
# so peaks and dips survive. Points without a value are dropped.
sub _largest_triangles ( $xs, $ys, $count ) {
	my @points = map { [ $xs->[$_], $ys->[$_] ] } grep { defined $ys->[$_] } 0 .. $#$xs;
	return ( [ map { $_->[0] } @points ], [ map { $_->[1] } @points ] ) if @points <= $count;
	my @kept = ( $points[0] );
	my $size = ( @points - 2 ) / ( $count - 2 );
	my $chosen = 0;
	foreach my $bucket ( 0 .. $count - 3 ) {
		my ( $from, $to ) = ( int( $bucket * $size ) + 1, int( ( $bucket + 1 ) * $size ) + 1 );
		my ( $next_from, $next_to ) = ( $to, min( int( ( $bucket + 2 ) * $size ) + 1, scalar @points ) );
		my @next = @points[ $next_from .. $next_to - 1 ];
		my ( $average_x, $average_y ) = ( sum0( map { $_->[0] } @next ) / @next, sum0( map { $_->[1] } @next ) / @next );
		my ( $best, $largest ) = ( $from, -1 );
		foreach my $index ( $from .. $to - 1 ) {
			my $area = abs( ( $points[$chosen][0] - $average_x ) * ( $points[$index][1] - $points[$chosen][1] ) - ( $points[$chosen][0] - $points[$index][0] ) * ( $average_y - $points[$chosen][1] ) );
			( $best, $largest ) = ( $index, $area ) if $area > $largest;
		}
		push @kept, $points[$best];
		$chosen = $best;
	}
	push @kept, $points[-1];
	return ( [ map { $_->[0] } @kept ], [ map { $_->[1] } @kept ] );
}

sub transform_names () {
	return sort keys %TRANSFORM;
}

# One step: a name, [ name, arguments ], or a code reference.
sub _step ( $owner, $name, $step ) {
	return [ 'code', sub ( $xs, $ys ) { _checked_result( $owner, $name, $step->( [@$xs], [@$ys] ) ) } ] if ref $step eq 'CODE';
	my ( $transform, @arguments ) = ref $step eq 'ARRAY' ? @$step : ($step);
	croak "$owner: every step of $name must be a transform name (" . join( ', ', transform_names() ) . "), [ name, arguments ] or a code reference, got " . describe($transform)
		unless defined $transform && !ref $transform && $TRANSFORM{$transform};
	my $spec = $TRANSFORM{$transform};
	my ( $least, $most, $defaults ) = $spec->{arguments}->@*;
	croak "$owner: the $name step '$transform' takes " . ( $least == $most ? $least : "$least to $most" ) . " argument" . ( $most == 1 ? '' : 's' ) . ", got " . scalar(@arguments)
		if @arguments < $least || @arguments > $most;
	my @values = map { $_ < @arguments ? $arguments[$_] : $defaults->[$_] } 0 .. $most - 1;
	if ( $spec->{check} ) {
		my $problem = $spec->{check}->(@values);
		croak "$owner: the $name step '$transform' needs $problem, got " . join( ', ', map { describe($_) } @arguments ) if defined $problem;
	}
	foreach my $value ( grep { defined } @values ) {
		croak "$owner: the arguments of the $name step '$transform' must be plain values, got " . describe($value) if ref $value;
	}
	return [ $transform, sub ( $xs, $ys ) { $spec->{apply}->( $xs, $ys, @values ) } ];
}

sub _checked_result ( $owner, $name, @result ) {
	croak "$owner: a $name code reference must return two array references of the same length (xs, ys)"
		unless @result == 2 && ref $result[0] eq 'ARRAY' && ref $result[1] eq 'ARRAY' && $result[0]->@* == $result[1]->@*;
	return @result;
}

# A transform specification as a list of steps: a name, a code
# reference, or an array of steps.
sub parse_transforms ( $owner, $name, $spec ) {
	return [] unless defined $spec;
	my @steps = ref $spec eq 'ARRAY' ? @$spec : ($spec);
	croak "$owner: $name is a list of steps; write [ [ '$steps[0]', ... ] ] for one step with arguments"
		if @steps > 1 && defined $steps[0] && !ref $steps[0] && $TRANSFORM{ $steps[0] } && grep { defined && !ref && looks_like_number($_) } @steps[ 1 .. $#steps ];
	return [ map { _step( $owner, $name, $_ ) } @steps ];
}

sub apply_transforms ( $steps, $xs, $ys ) {
	( $xs, $ys ) = $_->[1]->( $xs, $ys ) foreach @$steps;
	return ( $xs, $ys );
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Chart::Transform - Prepare the data of a chart series:
normalize, smooth, accumulate, resample

=head1 SYNOPSIS

	# In a chart, as the transform of a series (or of all series):
	my $chart = Term::Fabulous::Widget::LineChart->new(
		series => [
			{ name => 'Raw',      data => \@samples },
			{ name => 'Smoothed', data => \@samples, transform => [ [ 'moving_average', 7, 'center' ] ] },
			{ name => 'Indexed',  data => \@prices,  transform => [ 'sort', [ 'index', 100 ] ] },
		],
	);

	# On its own:
	use Term::Fabulous::Chart::Transform qw(parse_transforms apply_transforms);

	my $steps = parse_transforms( 'my program', 'transform', [ [ 'resample', 3600, 'sum' ], 'cumulative' ] );
	my ( $xs, $ys ) = apply_transforms( $steps, \@epochs, \@values );

=head1 DESCRIPTION

A series can be prepared before it is drawn: smoothed, normalized,
summed up, resampled to an interval, thinned out. The C<transform> of a
series (or of the whole chart) lists the steps, which run in order on the
series' points. The data you give the chart is kept as it is: the steps
run again whenever it changes, so live data stays prepared the same way.

A step is a name, an array of a name and its arguments, or a code
reference. Write the list of steps as an array, even for one step with
arguments: C<< transform =E<gt> [ [ 'moving_average', 5 ] ] >>. A single
step without arguments can stand alone: C<< transform =E<gt> 'cumulative' >>.

Points without a value (C<undef>, gaps in a line) stay gaps; windows skip
them.

=head2 Steps

=over

=item C<normalize>, C<[ 'normalize', $low, $high ]>

Scales the values linearly so the smallest becomes C<$low> and the
largest C<$high> (default 0 and 1). Use it to compare the shapes of
series of different sizes on one axis.

=item C<share>

Each value as a fraction of the total of the series (0 to 1); with the
axis C<< format =E<gt> 'percent' >> the axis shows percentages.

=item C<zscore>

The number of standard deviations each value lies from the series mean.

=item C<index>, C<[ 'index', $base ]>

Each value relative to the first non-zero value, which becomes C<$base>
(default 100). Use it instead of a second axis to compare the growth of
series of different sizes: all start at 100.

=item C<cumulative>

The running total.

=item C<difference>

The change from the previous value (the first point gets none).

=item C<rate>, C<[ 'rate', $per ]>

The change per unit of x from the previous point, times C<$per>
(default 1): a counter sampled with epoch seconds becomes a rate per
second, with C<< [ 'rate', 60 ] >> per minute.

=item C<[ 'moving_average', $window ]>, C<[ 'moving_average', $window, 'center' ]>

The mean of the last C<$window> values (C<trailing>, the default), or of
the C<$window> values around each point (C<center>), which does not lag
behind.

=item C<[ 'exponential', $alpha ]>

Exponential smoothing: each value moves C<$alpha> (greater than 0, at
most 1) of the way from the smoothed value before it. Small values smooth
more.

=item C<[ 'median', $window ]>

The median of the C<$window> values around each point: removes single
spikes but keeps steps.

=item C<[ 'gaussian', $sigma ]>

A Gaussian blur with a standard deviation of C<$sigma> points: the
smoothest of the smoothing steps.

=item C<[ 'scale', $factor ]>, C<[ 'offset', $amount ]>

Multiply or add, for example to convert units.

=item C<[ 'clip', $low, $high ]>

Limits the values to a range; either end may be C<undef>.

=item C<abs>

The absolute values.

=item C<sort>

Sorts the points by x.

=item C<[ 'resample', $interval ]>, C<[ 'resample', $interval, $aggregate ]>

Groups the points into intervals of x (C<3600> for hours of epoch
seconds) and replaces each group by one point at the start of its
interval: the C<mean> (default), C<sum>, C<min>, C<max>, C<first>, C<last>
value or the C<count> of points.

=item C<[ 'downsample', $count ]>

Thins a long series out to C<$count> points with the
Largest-Triangle-Three-Buckets method, which keeps peaks and dips. Charts
draw any number of points; this only makes drawing faster.

=item C<regression>

The least-squares straight line through the points (a trend line).

=item a code reference

Called with copies of the x and y values as two array references; returns
two array references of equal length, the new x and y values.

=back

=head1 FUNCTIONS

=head2 parse_transforms

	my $steps = parse_transforms( $owner, $name, $spec );

Checks a specification and returns its steps. Dies with C<$owner> and
C<$name> in the message for unknown names and wrong arguments.

=head2 apply_transforms

	my ( $xs, $ys ) = apply_transforms( $steps, \@xs, \@ys );

Runs the steps on the values and returns new arrays.

=head2 transform_names

The names of all steps, sorted.

=head1 SEE ALSO

L<Term::Fabulous::Widget::XYChart/Preparing data>.

=cut
