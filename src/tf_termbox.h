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
 *
 * It relies on tb_set_func(TB_FUNC_EXTRACT_PRE) and on termbox2's
 * input buffer (global.in), which upstream removes in version 3.x; see
 * README.termbox2 before updating termbox2.h.
 */
int tf_install_input_parser(void);

/*
 * Inline mode: tb_init_rwfd without taking over the screen. termbox2
 * neither switches to the alternate screen nor clears it, not at the
 * start, not on a resize and not at tb_shutdown(); its cell buffers
 * still cover the whole terminal, and the caller paints only the rows
 * it owns. tf_init_inline() opens /dev/tty like tb_init(). Both return
 * a termbox2 status code.
 *
 * They call termbox2's internal init steps and replace entries of its
 * capability table (global.caps); see README.termbox2 before updating
 * termbox2.h.
 */
int tf_init_inline(void);
int tf_init_inline_rwfd(int rfd, int wfd);

/*
 * Asks the terminal where the cursor is (ESC [ 6 n) and waits up to
 * timeout_ms milliseconds for its report. x and y count from 0. Input
 * that arrives meanwhile stays queued for tb_peek_event. Returns
 * TB_ERR_NO_EVENT when no report arrived in time, else a termbox2
 * status code.
 */
int tf_cursor_position(int timeout_ms, int *x, int *y);

/*
 * Queues the reset of all colors and styles (SGR 0), and makes the next
 * cell tb_present() draws set its colors again: termbox2 otherwise
 * skips colors it believes the terminal still has.
 */
int tf_reset_attrs(void);

/* Writes what tb_send() and the other output calls queued. */
int tf_flush(void);

#endif /* TF_TERMBOX_H */
