package Term::Fabulous::Render::Text;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.800;

role Term::Fabulous::Render::Text {
	use Term::Fabulous::Color;
	use Termbox 2 qw(:all);

	state $default_bg = Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});

	method render_text($command, $widget, $buffer) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};

		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{textColor} // {r => 255, g => 255, b => 255, a => 255}));
		my $background_color = defined($data->{backgroundColor})
			? Term::Fabulous::Color->new(color => $data->{backgroundColor})
			: undef;

		my $fg_int = $foreground_color->rgb_int;
		my $bg_int_const = defined($background_color) ? $background_color->rgb_int : undef;

		my $text = $data->{stringContents} // '';
		my $y = $bbox->{y} + 1;
		my $row = ($buffer->[$y] //= []);
		my $x0 = $bbox->{x} + 1;

		for my $i (0 .. length($text) - 1) {
			my $char = substr($text, $i, 1);
			my $x = $x0 + $i;
			my $bg_color = $background_color // $row->[$x] // $default_bg;
			my $bg_int = $bg_int_const // $bg_color->rgb_int;
			$row->[$x] = $bg_color;
			tb_set_cell($x, $y, $char, $fg_int, $bg_int);
		}
	}
}
