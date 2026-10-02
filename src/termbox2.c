/*
 * termbox2.c - the single translation unit that compiles termbox2 in.
 *
 * perl.h stays out of this file on purpose: termbox2's implementation
 * defines feature-test macros and hundreds of static helpers that have
 * no business meeting Perl's macros.
 */
#define TB_IMPL
#include "tf_termbox.h"

int tf_cluster_width(const uint32_t *codepoints, size_t count) {
	return tb_cluster_width((uint32_t *)codepoints, count);
}
