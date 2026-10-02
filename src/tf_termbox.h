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
 * Width of a grapheme cluster the way tb_present() measures it. termbox2
 * keeps tb_cluster_width() static, so termbox2.c exports this wrapper
 * from the same translation unit.
 */
int tf_cluster_width(const uint32_t *codepoints, size_t count);

#endif /* TF_TERMBOX_H */
