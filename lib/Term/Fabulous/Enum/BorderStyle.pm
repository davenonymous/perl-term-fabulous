package Term::Fabulous::Enum::BorderStyle;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::PadX::Enum;

enum Term::Fabulous::Enum::BorderStyle {
	state $solid_joints = [
		"\x{2500}",    # h_line  ─
		"\x{2502}",    # v_line  │
		"\x{253C}",    # cross   ┼
		"\x{252C}",    # t_down  ┬
		"\x{2534}",    # t_up    ┴
		"\x{251C}",    # t_right ├
		"\x{2524}",    # t_left  ┤
	];

	item Ascii (
		glyphs => [ '+',        '-',        '+',        '|',        '|',        '+',        '-',        '+' ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => [ '-', '|', '+', '+', '+', '+', '+' ],
	);
	item Blank (
		glyphs => [ ' ',        ' ',        ' ',        ' ',        ' ',        ' ',        ' ',        ' ' ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Block (
		glyphs => [ "\x{2584}", "\x{2584}", "\x{2584}", "\x{2588}", "\x{2588}", "\x{2580}", "\x{2580}", "\x{2580}" ],
		locations => [ 1, 1, 1, 0, 0, 1, 1, 1 ],
	);
	item DarkShade (
		glyphs => [ "\x{2593}", "\x{2593}", "\x{2593}", "\x{2593}", "\x{2593}", "\x{2593}", "\x{2593}", "\x{2593}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Dashed (
		glyphs => [ "\x{250F}", "\x{254D}", "\x{2513}", "\x{254F}", "\x{254F}", "\x{2517}", "\x{254D}", "\x{251B}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => $solid_joints,
	);
	item Double (
		glyphs => [ "\x{2554}", "\x{2550}", "\x{2557}", "\x{2551}", "\x{2551}", "\x{255A}", "\x{2550}", "\x{255D}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => [
			"\x{2550}",    # h_line  ═
			"\x{2551}",    # v_line  ║
			"\x{256C}",    # cross   ╬
			"\x{2566}",    # t_down  ╦
			"\x{2569}",    # t_up    ╩
			"\x{2560}",    # t_right ╠
			"\x{2563}",    # t_left  ╣
		],
		mixed_joints => sub {
			Term::Fabulous::Enum::BorderStyle->Solid, [
				"\x{256A}",    # cross   ╪  horizontal double, vertical single
				"\x{2564}",    # t_down  ╤  down single, horizontal double
				"\x{2567}",    # t_up    ╧  up single, horizontal double
				"\x{255E}",    # t_right ╞  vertical single, right double
				"\x{2561}",    # t_left  ╡  vertical single, left double
			],
		},
	);
	item Heavy (
		glyphs => [ "\x{250F}", "\x{2501}", "\x{2513}", "\x{2503}", "\x{2503}", "\x{2517}", "\x{2501}", "\x{251B}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => [
			"\x{2501}",    # h_line  ━
			"\x{2503}",    # v_line  ┃
			"\x{254B}",    # cross   ╋
			"\x{2533}",    # t_down  ┳
			"\x{253B}",    # t_up    ┻
			"\x{2523}",    # t_right ┣
			"\x{252B}",    # t_left  ┫
		],
		mixed_joints => sub {
			Term::Fabulous::Enum::BorderStyle->Solid, [
				"\x{253F}",    # cross   ┿  horizontal heavy, vertical light
				"\x{252F}",    # t_down  ┯  down light, horizontal heavy
				"\x{2537}",    # t_up    ┷  up light, horizontal heavy
				"\x{251D}",    # t_right ┝  vertical light, right heavy
				"\x{2525}",    # t_left  ┥  vertical light, left heavy
			],
		},
	);
	item Hidden (
		glyphs => [ ' ',        ' ',        ' ',        ' ',        ' ',        ' ',        ' ',        ' ' ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Hkey (
		glyphs => [ "\x{2594}", "\x{2594}", "\x{2594}", ' ',        ' ',        "\x{2581}", "\x{2581}", "\x{2581}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Inner (
		glyphs => [ "\x{2597}", "\x{2584}", "\x{2596}", "\x{2590}", "\x{258C}", "\x{259D}", "\x{2580}", "\x{2598}" ],
		locations => [ 1, 1, 1, 1, 1, 1, 1, 1 ],
	);
	item LightShade (
		glyphs => [ "\x{2591}", "\x{2591}", "\x{2591}", "\x{2591}", "\x{2591}", "\x{2591}", "\x{2591}", "\x{2591}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item MediumShade (
		glyphs => [ "\x{2592}", "\x{2592}", "\x{2592}", "\x{2592}", "\x{2592}", "\x{2592}", "\x{2592}", "\x{2592}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Outer (
		glyphs => [ "\x{259B}", "\x{2580}", "\x{259C}", "\x{258C}", "\x{2590}", "\x{2599}", "\x{2584}", "\x{259F}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Panel (
		glyphs => [ "\x{258A}", "\x{2588}", "\x{258E}", "\x{258A}", "\x{258E}", "\x{258A}", "\x{2581}", "\x{258E}" ],
		locations => [ 2, 0, 1, 2, 1, 2, 0, 1 ],
	);
	item Round (
		glyphs => [ "\x{256D}", "\x{2500}", "\x{256E}", "\x{2502}", "\x{2502}", "\x{2570}", "\x{2500}", "\x{256F}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => $solid_joints,
	);

	item Solid (
		glyphs => [ "\x{250C}", "\x{2500}", "\x{2510}", "\x{2502}", "\x{2502}", "\x{2514}", "\x{2500}", "\x{2518}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
		joints => $solid_joints,
		mixed_joints => sub {
			Term::Fabulous::Enum::BorderStyle->Heavy, [
				"\x{2542}",    # cross   ╂  vertical heavy, horizontal light
				"\x{2530}",    # t_down  ┰  down heavy, horizontal light
				"\x{2538}",    # t_up    ┸  up heavy, horizontal light
				"\x{2520}",    # t_right ┠  vertical heavy, right light
				"\x{2528}",    # t_left  ┨  vertical heavy, left light
			],
			Term::Fabulous::Enum::BorderStyle->Double, [
				"\x{256B}",    # cross   ╫  vertical double, horizontal single
				"\x{2565}",    # t_down  ╥  down double, horizontal single
				"\x{2568}",    # t_up    ╨  up double, horizontal single
				"\x{255F}",    # t_right ╟  vertical double, right single
				"\x{2562}",    # t_left  ╢  vertical double, left single
			],
		}
	);

	item Tab (
		glyphs => [ "\x{2581}", "\x{2581}", "\x{2581}", "\x{258E}", "\x{258A}", "\x{2594}", "\x{2594}", "\x{2594}" ],
		locations => [ 1, 1, 1, 0, 3, 1, 1, 1 ],
	);
	item Tall (
		glyphs => [ "\x{258A}", "\x{2594}", "\x{258E}", "\x{258A}", "\x{258E}", "\x{258A}", "\x{2581}", "\x{258E}" ],
		locations => [ 2, 0, 1, 2, 1, 2, 0, 1 ],
	);
	item Thick (
		glyphs => [ "\x{2588}", "\x{2580}", "\x{2588}", "\x{2588}", "\x{2588}", "\x{2588}", "\x{2584}", "\x{2588}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Vkey (
		glyphs => [ "\x{258F}", ' ',        "\x{2595}", "\x{258F}", "\x{2595}", "\x{258F}", ' ',        "\x{2595}" ],
		locations => [ 0, 0, 0, 0, 0, 0, 0, 0 ],
	);
	item Wide (
		glyphs => [ "\x{2581}", "\x{2581}", "\x{2581}", "\x{258E}", "\x{258A}", "\x{2594}", "\x{2594}", "\x{2594}" ],
		locations => [ 1, 1, 1, 0, 3, 1, 1, 1 ],
	);


	# Renderer-side glyph tables for each `Term::Fabulous::Border` style.
	# Sourced from Textualize/textual's `_border.py`:
	#   https://raw.githubusercontent.com/Textualize/textual/refs/heads/main/src/textual/_border.py
	#
	# Textual's BORDER_CHARS / BORDER_LOCATIONS are 3x3 tables:
	#
	#     row 0 (top):     (TL, T,  TR )
	#     row 1 (middle):  (L,  mid, R )
	#     row 2 (bottom):  (BL, B,  BR )
	#
	# The middle-middle cell is always a space pad; we drop it. The remaining
	# 8 cells are flattened in a fixed order and stored as 8-element arrayrefs:
	#
	#     index:  0    1    2    3    4    5    6    7
	#     glyph:  TL   T    TR   L    R    BL   B    BR
	#     source: r0c0 r0c1 r0c2 r1c0 r1c2 r2c0 r2c1 r2c2
	#
	# `glyphs` carries the visible glyph (or a space for invisible / blank styles).
	# 8-element arrayref of glyphs in `[TL, T, TR, L, R, BL, B, BR]` order.
	field $glyphs :param :reader;

	# `locations` carries one of {0,1,2,3} per Textual's location matrix:
	#   0 = widget-side bg   (inner)
	#   1 = parent-side bg   (outer)
	#   2 = reverse(parent_bg, widget_fg)  — Textual's styles[2]
	#   3 = reverse(widget_bg, parent_fg)  — Textual's styles[3]
	# 8-element arrayref of LOCATIONS indices in the same order as `glyphs`.
	field $locations :param :reader;

	# Joint glyph tables for grid-line rendering. Each entry is a
	# 7-element arrayref in fixed order:
	#
	#     index:  0       1       2       3       4       5       6
	#     glyph:  h_line  v_line  cross   t_down  t_up    t_right t_left
	#
	field $joints :param :reader = undef;

	# Mixed-style joint table for grid lines whose horizontal axis
	# style differs from the vertical axis style (or whose perimeter
	# style differs from the meeting interior axis style — same
	# resolution rule).
	#
	#     index:  0      1       2     3        4
	#     glyph:  cross  t_down  t_up  t_right  t_left
	#
	# (h_line / v_line are not in this table — those are
	# axis-uniform and live in `$joints`.)
	#
	# 5-element arrayref `[cross, t_down, t_up, t_right, t_left]` for h_style/v_style intersection.
	field $mixed_joints :param :reader = undef;

	# Helper method to get the subset of styles that support grid joints.
	method get_grid_styles :common () {
		return grep { $_->joints } Term::Fabulous::Enum::BorderStyle->values;
	}

	# Accessor to get the mixed joint glyph for a given vertical style.
	method get_mixed_joint ( $vertical_style ) {
		return unless $self->mixed_joints && $self->mixed_joints->{$vertical_style};
		return $self->mixed_joints->{$vertical_style}
	}

	# Static helper to get the mixed joint glyph for a given horizontal to vertical style.
	method get_mixed_joints :common ( $horizontal_style, $vertical_style ) {
		return $horizontal_style->get_mixed_joint( $vertical_style );
	}

	method get_top_glyphs () {
		return @{$glyphs}[0, 1, 2];
	}

	method get_right_glyphs () {
		return @{$self->glyphs}[4];
	}

	method get_bottom_glyphs () {
		return @{$self->glyphs}[5, 6, 7];
	}

	method get_left_glyphs () {
		return @{$self->glyphs}[3];
	}
}

1;
