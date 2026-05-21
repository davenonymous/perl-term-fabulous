package Term::Fabulous::Render::Rectangle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

role Term::Fabulous::Render::Rectangle {
	use Term::Fabulous::Color;
	use Termbox 2 qw(:all);

	method render_rectangle($command, $widget, $buffer) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};

		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));
		my $background_color = Term::Fabulous::Color->new(color => ($data->{backgroundColor} // {r => 0, g => 0, b => 0, a => 0}));

		my $fg_int = $foreground_color->rgb_int;
		my $bg_int = $background_color->rgb_int;
		my $x0 = int $bbox->{x};
		my $y0 = int $bbox->{y};
		my $x1 = int($bbox->{x} + $bbox->{width});
		my $y1 = int($bbox->{y} + $bbox->{height});
		my $w  = $x1 - $x0;
		return if $w <= 0;
		my $fill = ' ' x $w;

		for (my $y = $y0; $y < $y1; $y++) {
			my $row = ($buffer->[$y] //= []);
			@{$row}[$x0 .. $x1 - 1] = ($background_color) x $w;
			tb_print($x0, $y, $fg_int, $bg_int, $fill);
		}
	}
}
