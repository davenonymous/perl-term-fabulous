/*
 * tf_termbox.h - termbox2 as Term::Fabulous compiles it.
 *
 * Every translation unit that touches termbox2 includes this header, so
 * the options below are the same in the library (termbox2.c) and in the
 * XS layer (lib/Term/Fabulous/Termbox.xs). uintattr_t is then uint64_t.
 */
#ifndef TF_TERMBOX_H
#define TF_TERMBOX_H

/* 64-bit attributes: 24-bit color plus every style bit, including
 * TB_STRIKEOUT, TB_UNDERLINE_2, TB_OVERLINE and TB_INVISIBLE. */
#define TB_OPT_ATTR_W 64

/* Grapheme clusters per cell (tb_extend_cell, tb_set_cell_ex). */
#define TB_OPT_EGC

#include "termbox2.h"

/*
 * Mouse keys termbox2 has no code for, numbered below its own
 * TB_KEY_MOUSE_* codes. tf_install_input_parser() makes tb_peek_event
 * report them.
 */
#define TF_KEY_MOUSE_MOVE        (0xffff - 29)
#define TF_KEY_MOUSE_WHEEL_LEFT  (0xffff - 30)
#define TF_KEY_MOUSE_WHEEL_RIGHT (0xffff - 31)

/*
 * Width of a grapheme cluster the way tb_present() measures it. termbox2
 * keeps tb_cluster_width() static, so termbox2.c exports this wrapper
 * from the same translation unit.
 */
int tf_cluster_width(const uint32_t *codepoints, size_t count);

/*
 * Reads the input termbox2 gets wrong before termbox2 sees it: Alt plus
 * a key, and SGR mouse reports with their motion, modifier and
 * horizontal wheel bits. Call it after every tb_init(); tb_shutdown()
 * forgets it. Returns a termbox2 status code.
 */
int tf_install_input_parser(void);

#endif /* TF_TERMBOX_H */
