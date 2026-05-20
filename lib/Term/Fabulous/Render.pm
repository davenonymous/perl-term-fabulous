package Term::Fabulous::Render;

use v5.22;

use Object::Pad 0.825;
use utf8;

use Termbox 2 qw(:all);
use Clay::UI;
use Clay::XS qw(
	CLAY_RENDER_COMMAND_TYPE_NONE
	CLAY_RENDER_COMMAND_TYPE_RECTANGLE
	CLAY_RENDER_COMMAND_TYPE_BORDER
	CLAY_RENDER_COMMAND_TYPE_TEXT
	CLAY_RENDER_COMMAND_TYPE_IMAGE
	CLAY_RENDER_COMMAND_TYPE_SCISSOR_START
	CLAY_RENDER_COMMAND_TYPE_SCISSOR_END
	CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_START
	CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_END
	CLAY_RENDER_COMMAND_TYPE_CUSTOM
);

use Term::Fabulous::Color;
use Clay::XS qw(Clay_SetMeasureTextFunction);

role Term::Fabulous::Render {
	field $term;
	field $output_mode :param = TB_OUTPUT_TRUECOLOR;
	field $buffer = [];
	field $first_draw = 1;
	field @last_commands;

	state $dispatch_table = {
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE() => \&_render_rectangle,
		CLAY_RENDER_COMMAND_TYPE_BORDER() => \&_render_border,
		CLAY_RENDER_COMMAND_TYPE_TEXT() => \&_render_text,
	};

	state $id_to_name = {
		CLAY_RENDER_COMMAND_TYPE_NONE() => 'NONE',
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE() => 'RECTANGLE',
		CLAY_RENDER_COMMAND_TYPE_BORDER() => 'BORDER',
		CLAY_RENDER_COMMAND_TYPE_TEXT() => 'TEXT',
		CLAY_RENDER_COMMAND_TYPE_IMAGE() => 'IMAGE',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_START() => 'SCISSOR_START',
		CLAY_RENDER_COMMAND_TYPE_SCISSOR_END() => 'SCISSOR_END',
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_START() => 'OVERLAY_COLOR_START',
		CLAY_RENDER_COMMAND_TYPE_OVERLAY_COLOR_END() => 'OVERLAY_COLOR_END',
		CLAY_RENDER_COMMAND_TYPE_CUSTOM() => 'CUSTOM',
	};

	state $default_bg = Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});

	ADJUST {
		$self->_initialize();
	}

	method _initialize() {
		tb_init();
		$self->width(tb_width());
		$self->height(tb_height());
		tb_set_output_mode($output_mode);
		tb_hide_cursor();
	}

	method _set_cell($x, $y, $char, $fg_color, $bg_color) {
		$buffer->[$y][$x] = $bg_color;
		tb_set_cell($x, $y, $char, $fg_color->rgb_int, $bg_color->rgb_int);
	}

	method _render_rectangle($command, $widget) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};

		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));
		my $background_color = Term::Fabulous::Color->new(color => ($data->{backgroundColor} // {r => 0, g => 0, b => 0, a => 0}));

		my $fg_int = $foreground_color->rgb_int;
		my $bg_int = $background_color->rgb_int;
		my $x0 = $bbox->{x};
		my $y0 = $bbox->{y};
		my $w  = $bbox->{width};
		return if $w <= 0;
		my $x1 = $x0 + $w;
		my $y1 = $y0 + $bbox->{height};
		my $fill = ' ' x $w;

		for (my $y = $y0; $y < $y1; $y++) {
			my $row = ($buffer->[$y] //= []);
			@{$row}[$x0 .. $x1 - 1] = ($background_color) x $w;
			tb_print($x0, $y, $fg_int, $bg_int, $fill);
		}
	}

	method _render_text($command, $widget) {
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

	method _render_border($command, $widget) {
		return unless $widget->DOES('Term::Fabulous::Role::HasBorderStyle');

		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};
		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));
		my $fg_int = $foreground_color->rgb_int;

		my $top_style    = $widget->border_style_top;
		my $right_style  = $widget->border_style_right;
		my $bottom_style = $widget->border_style_bottom;
		my $left_style   = $widget->border_style_left;

		# Glyph slot order: TL, T, TR, L, R, BL, B, BR.
		my ($topLeft, $top, $topRight)          = $top_style    ? $top_style->get_top_glyphs       : (' ', ' ', ' ');
		my ($left, $right)                      = ($left_style  ? $left_style->get_left_glyphs    : ' ',
		                                           $right_style ? $right_style->get_right_glyphs  : ' ');
		my ($bottomLeft, $bottom, $bottomRight) = $bottom_style ? $bottom_style->get_bottom_glyphs : (' ', ' ', ' ');

		my $x0 = $bbox->{x};
		my $x1 = $x0 + $bbox->{width} - 1;
		my $y0 = $bbox->{y};
		my $y1 = $y0 + $bbox->{height} - 1;

		my $top_row    = ($buffer->[$y0] //= []);
		my $bottom_row = ($buffer->[$y1] //= []);

		# Top + Bottom border (kept per-cell: borders are low-volume and
		# tb_print with UTF-8 box-drawing chars exposed a termbox crash).
		for (my $x = $x0; $x <= $x1; $x++) {
			my $top_bg = $top_row->[$x]    // $default_bg;
			my $bot_bg = $bottom_row->[$x] // $default_bg;

			my ($top_glyph, $bot_glyph) =
				  $x == $x0 ? ($topLeft,  $bottomLeft)
				: $x == $x1 ? ($topRight, $bottomRight)
				:             ($top,      $bottom);

			$top_row->[$x]    = $top_bg;
			$bottom_row->[$x] = $bot_bg;
			tb_set_cell($x, $y0, $top_glyph, $fg_int, $top_bg->rgb_int);
			tb_set_cell($x, $y1, $bot_glyph, $fg_int, $bot_bg->rgb_int);
		}

		# Left + Right border
		for (my $y = $y0 + 1; $y < $y1; $y++) {
			my $row = ($buffer->[$y] //= []);
			my $left_bg  = $row->[$x0] // $default_bg;
			my $right_bg = $row->[$x1] // $default_bg;
			$row->[$x0] = $left_bg;
			$row->[$x1] = $right_bg;
			tb_set_cell($x0, $y, $left,  $fg_int, $left_bg->rgb_int);
			tb_set_cell($x1, $y, $right, $fg_int, $right_bg->rgb_int);
		}
	}

	method get_last_commands() {
		return @last_commands;
	}

	method _command_dispatch($command) {
		my $type = $command->{commandType};
		my $widget = $self->widget_for($command->{userData});
		my $handler = $dispatch_table->{$type} // sub {
			die(sprintf("Unhandled command type: %s\n", $id_to_name->{$type} // $type));
		};
		$handler->($self, $command, $widget);
	}

	method draw() {
		if ($first_draw) {
			Clay_SetMeasureTextFunction(sub ($text, $config, $userdata) {
				return { width => length($text), height => 1 };
			});
			$first_draw = 0;
		}

		my $commands = $self->render();
		@last_commands = @$commands;
		$self->_command_dispatch($_) foreach ($commands->@*);

		tb_present();
	}
}

1;
