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
use Unicode::GCString;
use Encode qw(decode);

role Term::Fabulous::Render
	:does(Term::Fabulous::Render::Rectangle)
	:does(Term::Fabulous::Render::Border)
	:does(Term::Fabulous::Render::Text)
{
	field $term;
	field $output_mode :param = TB_OUTPUT_TRUECOLOR;
	field $buffer = [];
	field $first_draw = 1;
	field @last_commands;

	state $dispatch_table = {
		CLAY_RENDER_COMMAND_TYPE_RECTANGLE() => \&Term::Fabulous::Render::Rectangle::render_rectangle,
		CLAY_RENDER_COMMAND_TYPE_BORDER() => \&Term::Fabulous::Render::Border::render_border,
		CLAY_RENDER_COMMAND_TYPE_TEXT() => \&Term::Fabulous::Render::Text::render_text,
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

	method get_last_commands() {
		return @last_commands;
	}

	method _command_dispatch($command) {
		my $type = $command->{commandType};
		my $widget = $self->widget_for($command->{userData});
		my $handler = $dispatch_table->{$type} // sub {
			die(sprintf("Unhandled command type: %s\n", $id_to_name->{$type} // $type));
		};
		$handler->($self, $command, $widget, $buffer);
	}

	method draw() {
		if ($first_draw) {
			Clay_SetMeasureTextFunction(sub ($text, $config, $userdata) {
				my $decoded = decode('UTF-8', $text, Encode::FB_DEFAULT);
				my $width = 0;
				my $height = 1;
				my $line_width = 0;
				for my $line (split /\n/, $decoded, -1) {
					my $cols = length($line) ? Unicode::GCString->new($line)->columns : 0;
					$width = $cols if $cols > $width;
				}
				$height = ($decoded =~ tr/\n//) + 1;
				return { width => $width, height => $height };
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
