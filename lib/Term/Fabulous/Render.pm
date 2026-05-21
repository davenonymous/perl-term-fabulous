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

	# Resolve (fg_int, bg_int) for a border cell from its location code (0..3).
	# Location semantics mirror Textual's BORDER_LOCATIONS:
	#   0 = fg on widget's own bg
	#   1 = fg on parent's bg
	#   2 = swap of 1   (parent_bg painted as fg, widget_fg as bg)
	#   3 = parent_fg painted as bg, widget_bg as fg
	method _resolve_border_colors($loc, $widget_fg_int, $parent_fg_int, $widget_bg, $parent_bg) {
		return ($widget_fg_int, $widget_bg->rgb_int) if $loc == 0;
		return ($widget_fg_int, $parent_bg->rgb_int) if $loc == 1;
		return ($parent_bg->rgb_int, $widget_fg_int) if $loc == 2;
		return ($widget_bg->rgb_int, $parent_fg_int) if $loc == 3;
		die "Invalid border location code: $loc";
	}

	method _render_border($command, $widget) {
		return unless $widget->DOES('Term::Fabulous::Role::HasBorderStyle');

		my $bbox = $command->{boundingBox};
		my $data = $command->{renderData};
		my $widget_fg_color = Term::Fabulous::Color->new(color => ($data->{color} // {r => 255, g => 255, b => 255, a => 255}));
		my $widget_fg_int   = $widget_fg_color->rgb_int;

		my $parent = $widget->parent;
		my $parent_fg_int = ($parent && $parent->border_color)
			? Term::Fabulous::Color->new(color => $parent->border_color)->rgb_int
			: $widget_fg_int;

		my $top_style    = $widget->border_style_top;
		my $right_style  = $widget->border_style_right;
		my $bottom_style = $widget->border_style_bottom;
		my $left_style   = $widget->border_style_left;

		# Glyph + location slot order: TL, T, TR, L, R, BL, B, BR.
		my ($topLeft, $top, $topRight)          = $top_style    ? $top_style->get_top_glyphs       : (' ', ' ', ' ');
		my ($tlLoc,   $tLoc, $trLoc)            = $top_style    ? $top_style->get_top_locations    : (0, 0, 0);
		my $left  = $left_style  ? $left_style->get_left_glyphs    : ' ';
		my $right = $right_style ? $right_style->get_right_glyphs  : ' ';
		my $lLoc  = $left_style  ? $left_style->get_left_locations : 0;
		my $rLoc  = $right_style ? $right_style->get_right_locations : 0;
		my ($bottomLeft, $bottom, $bottomRight) = $bottom_style ? $bottom_style->get_bottom_glyphs    : (' ', ' ', ' ');
		my ($blLoc, $bLoc, $brLoc)              = $bottom_style ? $bottom_style->get_bottom_locations : (0, 0, 0);

		my $x0 = $bbox->{x};
		my $x1 = $x0 + $bbox->{width} - 1;
		my $y0 = $bbox->{y};
		my $y1 = $y0 + $bbox->{height} - 1;

		my $top_row    = ($buffer->[$y0] //= []);
		my $bottom_row = ($buffer->[$y1] //= []);
		my $above_row  = ($y0 > 0) ? ($buffer->[$y0 - 1] // []) : [];
		my $below_row  = ($buffer->[$y1 + 1] // []);

		# Top + Bottom border (kept per-cell: borders are low-volume and
		# tb_print with UTF-8 box-drawing chars exposed a termbox crash).
		for (my $x = $x0; $x <= $x1; $x++) {
			my ($top_glyph, $top_loc, $bot_glyph, $bot_loc) =
				  $x == $x0 ? ($topLeft,  $tlLoc, $bottomLeft,  $blLoc)
				: $x == $x1 ? ($topRight, $trLoc, $bottomRight, $brLoc)
				:             ($top,      $tLoc,  $bottom,      $bLoc);

			my $top_widget_bg = $top_row->[$x]    // $default_bg;
			my $bot_widget_bg = $bottom_row->[$x] // $default_bg;
			my $top_parent_bg = $above_row->[$x]  // $default_bg;
			my $bot_parent_bg = $below_row->[$x]  // $default_bg;

			my ($t_fg, $t_bg) = $self->_resolve_border_colors($top_loc, $widget_fg_int, $parent_fg_int, $top_widget_bg, $top_parent_bg);
			my ($b_fg, $b_bg) = $self->_resolve_border_colors($bot_loc, $widget_fg_int, $parent_fg_int, $bot_widget_bg, $bot_parent_bg);

			$top_row->[$x]    = $top_widget_bg;
			$bottom_row->[$x] = $bot_widget_bg;
			tb_set_cell($x, $y0, $top_glyph, $t_fg, $t_bg);
			tb_set_cell($x, $y1, $bot_glyph, $b_fg, $b_bg);
		}

		# Left + Right border
		my $left_parent_x  = $x0 - 1;
		my $right_parent_x = $x1 + 1;
		for (my $y = $y0 + 1; $y < $y1; $y++) {
			my $row = ($buffer->[$y] //= []);
			my $left_widget_bg  = $row->[$x0] // $default_bg;
			my $right_widget_bg = $row->[$x1] // $default_bg;
			my $left_parent_bg  = ($left_parent_x >= 0 ? $row->[$left_parent_x] : undef) // $default_bg;
			my $right_parent_bg = $row->[$right_parent_x] // $default_bg;

			my ($l_fg, $l_bg) = $self->_resolve_border_colors($lLoc, $widget_fg_int, $parent_fg_int, $left_widget_bg,  $left_parent_bg);
			my ($r_fg, $r_bg) = $self->_resolve_border_colors($rLoc, $widget_fg_int, $parent_fg_int, $right_widget_bg, $right_parent_bg);

			$row->[$x0] = $left_widget_bg;
			$row->[$x1] = $right_widget_bg;
			tb_set_cell($x0, $y, $left,  $l_fg, $l_bg);
			tb_set_cell($x1, $y, $right, $r_fg, $r_bg);
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
