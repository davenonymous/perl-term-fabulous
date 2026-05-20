package Term::Fabulous::Render;

use v5.22;

use Object::Pad 0.825;
use utf8;

use Termbox 2 qw(:all);
use Data::Printer;
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

	ADJUST {
		$self->_initialize();
	}

	method _set_cell($x, $y, $char, $fg_color, $bg_color) {
		$buffer->[$y][$x] = {
			char => $char,
			fg_color => $fg_color,
			bg_color => $bg_color,
		};

		tb_set_cell($x, $y, $char, $fg_color->rgb_int, $bg_color->rgb_int);
	}

	method _initialize() {
		tb_init();
		$self->width(tb_width());
		$self->height(tb_height());
		tb_set_output_mode($output_mode);
		tb_hide_cursor();
	}

	method _render_text($command, $widget) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};

		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{textColor} // {r => 255, g => 255, b => 255, a => 255}));
		my $background_color = defined($data->{backgroundColor})
			? Term::Fabulous::Color->new(color => $data->{backgroundColor})
			: undef;

		my $text = $data->{stringContents} // '';

		for my $i (0 .. length($text) - 1) {
			my $char = substr($text, $i, 1);
			my $old_background = $buffer->[$bbox->{y} + 1][$bbox->{x} + $i + 1]{bg_color} // Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});
			$self->_set_cell($bbox->{x} + $i +1, $bbox->{y} + 1, $char, $foreground_color, $background_color // $old_background);
			#tb_set_cell_ex($bbox->{x} + $i, $bbox->{y}, $char, 1, $foreground_color, $background_color);
		}
	}

	method _render_rectangle($command, $widget) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};

		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));
		my $background_color = Term::Fabulous::Color->new(color => ($data->{backgroundColor} // {r => 0, g => 0, b => 0, a => 0}));

		for(my $x = $bbox->{x}; $x < $bbox->{x} + $bbox->{width}; $x++) {
			for(my $y = $bbox->{y}; $y < $bbox->{y} + $bbox->{height}; $y++) {
				$self->_set_cell($x, $y, ' ', $foreground_color, $background_color);
			}
		}
	}

	method _render_border($command, $widget) {
		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};
		my $foreground_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));



		if(!$widget->DOES('Term::Fabulous::Role::HasBorderStyle')) {
			return;
		}

		my $top_style = $widget->border_style_top;
		my $right_style = $widget->border_style_right;
		my $bottom_style = $widget->border_style_bottom;
		my $left_style = $widget->border_style_left;

		# Glyph slot order: TL, T, TR, L, R, BL, B, BR.
		my ($topLeft, $top, $topRight) = $top_style ? $top_style->get_top_glyphs : (' ', ' ', ' ');
		my ($left, $right) = ($left_style ? $left_style->get_left_glyphs : ' ', $right_style ? $right_style->get_right_glyphs : ' ');
		my ($bottomLeft, $bottom, $bottomRight) = ($bottom_style ? $bottom_style->get_bottom_glyphs : (' ', ' ', ' '));

		# Top + Bottom border
		for(my $x = $bbox->{x}; $x < $bbox->{x} + $bbox->{width}; $x++) {
			my $top_background_color = $buffer->[$bbox->{y}][$x]{bg_color} // Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});
			my $bottom_background_color = $buffer->[$bbox->{y} + $bbox->{height} - 1][$x]{bg_color} // Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});

			if($x == $bbox->{x}) {
				$self->_set_cell($x, $bbox->{y}, $topLeft, $foreground_color, $top_background_color);
				$self->_set_cell($x, $bbox->{y} + $bbox->{height} - 1, $bottomLeft, $foreground_color, $bottom_background_color);
			} elsif($x == $bbox->{x} + $bbox->{width} - 1) {
				$self->_set_cell($x, $bbox->{y}, $topRight, $foreground_color, $top_background_color);
				$self->_set_cell($x, $bbox->{y} + $bbox->{height} - 1, $bottomRight, $foreground_color, $bottom_background_color);
			} else {
				$self->_set_cell($x, $bbox->{y}, $top, $foreground_color, $top_background_color);
				$self->_set_cell($x, $bbox->{y} + $bbox->{height} - 1, $bottom, $foreground_color, $bottom_background_color);
			}
		}

		# Left + Right border
		for(my $y = $bbox->{y}+1; $y < $bbox->{y} + $bbox->{height} - 1; $y++) {
			my $background_color = $buffer->[$y][$bbox->{x}]{bg_color} // Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});
			$self->_set_cell($bbox->{x}, $y, $left, $foreground_color, $background_color);
			$background_color = $buffer->[$y][$bbox->{x} + $bbox->{width} - 1]{bg_color} // Term::Fabulous::Color->new(color => {r => 0, g => 0, b => 0, a => 0});
			$self->_set_cell($bbox->{x} + $bbox->{width} - 1, $y, $right, $foreground_color, $background_color);
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
		if($first_draw) {
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
