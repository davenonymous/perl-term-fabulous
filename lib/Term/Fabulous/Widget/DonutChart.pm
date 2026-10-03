package Term::Fabulous::Widget::DonutChart;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::PieChart;

class Term::Fabulous::Widget::DonutChart :isa(Term::Fabulous::Widget::PieChart) :strict(params) {
	method default_hole :override () { return 0.6 }
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::DonutChart - A pie chart with a hole

=head1 SYNOPSIS

	use Term::Fabulous::Widget::DonutChart;

	my $chart = Term::Fabulous::Widget::DonutChart->new(
		title         => 'Sales by region',
		legend_values => 'value',
		format        => 'si',
		data          => [ [ Europe => 412_000 ], [ 'North America' => 365_000 ], [ Asia => 290_000 ] ],
	);

	$chart->center_text("1.07M\norders");    # instead of the total
	$chart->hole(0.5);

=begin html

<p><img src="/screenshots/widget-donut-chart.svg" alt="A donut of sales by region with the total in the middle and the values in the legend"></p>

=end html

=head1 DESCRIPTION

A donut is a L<Term::Fabulous::Widget::PieChart> whose C<hole> is 0.6
of the radius by default. The hole shows the total of the slices in bold
with the word C<Total> below it; while the pointer is on a slice, the
slice's share and label; or C<center_text>, when given (an empty string
for nothing). The text appears when the hole is at least three cell
widths across.

Everything else, the data forms, the parameters, methods, events and KDL
properties, is on L<Term::Fabulous::Widget::PieChart>.

=head1 CONSTRUCTOR

=head2 new

	my $chart = Term::Fabulous::Widget::DonutChart->new(%parameters);

The parameters of L<Term::Fabulous::Widget::PieChart/CONSTRUCTOR>, with
C<hole> defaulting to 0.6.

=head1 KDL PROPERTIES

	use Term::Fabulous::Widget::DonutChart as DonutChart

	DonutChart "sales" {
		center_text "Orders"
		slice "Europe" 412000
		slice "Asia" 290000
	}

See L<Term::Fabulous::Widget::PieChart/KDL PROPERTIES>.

=head1 SEE ALSO

L<Term::Fabulous::Widget::PieChart>, L<Term::Fabulous::Cookbook/CHARTS>.

=cut
