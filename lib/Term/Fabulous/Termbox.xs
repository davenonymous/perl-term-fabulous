/*
 * Termbox.xs - the XS surface of Term::Fabulous::Termbox.
 *
 * A thin layer over termbox2 (compiled in src/termbox2.c): every function
 * keeps its C name and status code. Characters cross the boundary as Perl
 * strings, which this file decodes into codepoints; events come back as a
 * list the Perl side copies into a Term::Fabulous::Termbox::Event.
 */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "tf_termbox.h"

/*
 * The first codepoint of a one-character string. An integer that was
 * never a string is taken as the codepoint itself, so the C form of the
 * call stays reachable.
 */
static uint32_t first_codepoint(pTHX_ SV *glyph, const char *function) {
	STRLEN length;
	const U8 *bytes;

	if (SvIOK(glyph) && !SvPOK(glyph)) return (uint32_t)SvUV(glyph);

	bytes = (const U8 *)SvPVutf8(glyph, length);
	if (length == 0) croak("Term::Fabulous::Termbox: %s needs a non-empty character", function);
	return (uint32_t)utf8_to_uvchr_buf(bytes, bytes + length, NULL);
}

/*
 * Every codepoint of a string, in an array the caller releases with
 * Safefree. Returns the number of codepoints.
 */
static size_t decode_codepoints(pTHX_ SV *text, const char *function, uint32_t **codepoints) {
	STRLEN length;
	const U8 *bytes = (const U8 *)SvPVutf8(text, length);
	const U8 *end   = bytes + length;
	size_t count    = 0;

	if (length == 0) croak("Term::Fabulous::Termbox: %s needs a non-empty string", function);

	Newx(*codepoints, utf8_length(bytes, end), uint32_t);
	while (bytes < end) {
		STRLEN consumed;
		(*codepoints)[count++] = (uint32_t)utf8_to_uvchr_buf(bytes, end, &consumed);
		bytes += consumed;
	}
	return count;
}

/* The text of a cell: its grapheme cluster when it has one, else its codepoint. */
static SV *cell_text(pTHX_ const struct tb_cell *cell) {
	const uint32_t *codepoints = cell->nech > 0 ? cell->ech : &cell->ch;
	size_t count               = cell->nech > 0 ? cell->nech : 1;
	SV *text                   = newSVpvs("");
	U8 buffer[UTF8_MAXBYTES + 1];
	size_t i;

	SvUTF8_on(text);
	for (i = 0; i < count; i++) {
		U8 *end = uvchr_to_utf8(buffer, codepoints[i]);
		sv_catpvn(text, (const char *)buffer, end - buffer);
	}
	return text;
}

static void scalar_ref_or_croak(pTHX_ SV *ref, const char *what) {
	if (SvROK(ref) && SvTYPE(SvRV(ref)) < SVt_PVAV) return;
	croak("Term::Fabulous::Termbox: tb_get_fds needs a scalar reference for the %s descriptor", what);
}

/* Installs a constant sub and records its name under an export tag. */
static void export_constant(pTHX_ HV *stash, HV *tags, const char *tag, const char *name, SV *value) {
	SV **members = hv_fetch(tags, tag, (I32)strlen(tag), 1);
	if (!SvROK(*members)) sv_setsv(*members, sv_2mortal(newRV_noinc((SV *)newAV())));
	newCONSTSUB(stash, name, value);
	av_push((AV *)SvRV(*members), newSVpv(name, 0));
}

/* (status, name => value, ...) for one filled struct tb_event. */
#define PUSH_EVENT_FIELD(field) STMT_START { \
	mPUSHp(#field, sizeof(#field) - 1);      \
	mPUSHi(event.field);                     \
} STMT_END

#define PUSH_EVENT(status)         \
	STMT_START {                   \
		EXTEND(SP, 17);            \
		mPUSHi(status);            \
		if ((status) == TB_OK) {   \
			PUSH_EVENT_FIELD(type); \
			PUSH_EVENT_FIELD(mod);  \
			PUSH_EVENT_FIELD(key);  \
			PUSH_EVENT_FIELD(ch);   \
			PUSH_EVENT_FIELD(w);    \
			PUSH_EVENT_FIELD(h);    \
			PUSH_EVENT_FIELD(x);    \
			PUSH_EVENT_FIELD(y);    \
		}                          \
	} STMT_END

MODULE = Term::Fabulous::Termbox    PACKAGE = Term::Fabulous::Termbox

PROTOTYPES: DISABLE

# --- Lifecycle --------------------------------------------------------

int
tb_init()

int
tb_init_file(const char *path)

int
tb_init_fd(int ttyfd)

int
tb_init_rwfd(int rfd, int wfd)

int
tb_shutdown()

int
tb_width()

int
tb_height()

int
tb_set_input_mode(int mode)

int
tb_set_output_mode(int mode)

# --- Drawing ----------------------------------------------------------

int
tb_clear()

int
tb_set_clear_attrs(uintattr_t fg, uintattr_t bg)

int
tb_present()

int
tb_invalidate()

int
tb_set_cursor(int cx, int cy)

int
tb_hide_cursor()

int
tb_set_cell(int x, int y, SV *glyph, uintattr_t fg, uintattr_t bg)
	CODE:
		RETVAL = tb_set_cell(x, y, first_codepoint(aTHX_ glyph, "tb_set_cell"), fg, bg);
	OUTPUT:
		RETVAL

int
tb_set_cell_ex(int x, int y, SV *cluster, uintattr_t fg, uintattr_t bg)
	PREINIT:
		uint32_t *codepoints;
		size_t count;
	CODE:
		count  = decode_codepoints(aTHX_ cluster, "tb_set_cell_ex", &codepoints);
		RETVAL = tb_set_cell_ex(x, y, codepoints, count, fg, bg);
		Safefree(codepoints);
	OUTPUT:
		RETVAL

int
tb_extend_cell(int x, int y, SV *glyph)
	CODE:
		RETVAL = tb_extend_cell(x, y, first_codepoint(aTHX_ glyph, "tb_extend_cell"));
	OUTPUT:
		RETVAL

void
tb_get_cell(int x, int y, int back)
	PREINIT:
		struct tb_cell *cell;
		int status;
	PPCODE:
		status = tb_get_cell(x, y, back, &cell);
		EXTEND(SP, 4);
		mPUSHi(status);
		if (status == TB_OK) {
			mPUSHs(cell_text(aTHX_ cell));
			mPUSHu(cell->fg);
			mPUSHu(cell->bg);
		}

int
tb_print(int x, int y, uintattr_t fg, uintattr_t bg, SV *text)
	CODE:
		RETVAL = tb_print(x, y, fg, bg, SvPVutf8_nolen(text));
	OUTPUT:
		RETVAL

int
tb_send(SV *bytes)
	PREINIT:
		STRLEN length;
		const char *buffer;
	CODE:
		buffer = SvPVutf8(bytes, length);
		RETVAL = tb_send(buffer, length);
	OUTPUT:
		RETVAL

# --- Events -----------------------------------------------------------

void
_peek_event(int timeout_ms)
	PREINIT:
		struct tb_event event;
		int status;
	PPCODE:
		Zero(&event, 1, struct tb_event);
		status = tb_peek_event(&event, timeout_ms);
		PUSH_EVENT(status);

void
_poll_event()
	PREINIT:
		struct tb_event event;
		int status;
	PPCODE:
		Zero(&event, 1, struct tb_event);
		status = tb_poll_event(&event);
		PUSH_EVENT(status);

int
tb_get_fds(SV *tty_ref, SV *resize_ref)
	PREINIT:
		int ttyfd    = -1;
		int resizefd = -1;
	CODE:
		scalar_ref_or_croak(aTHX_ tty_ref, "tty");
		scalar_ref_or_croak(aTHX_ resize_ref, "resize");
		RETVAL = tb_get_fds(&ttyfd, &resizefd);
		sv_setiv(SvRV(tty_ref), ttyfd);
		sv_setiv(SvRV(resize_ref), resizefd);
	OUTPUT:
		RETVAL

# --- Widths -----------------------------------------------------------

int
tb_iswprint(uint32_t ch)

int
tb_wcwidth(uint32_t ch)

int
tb_cluster_width(SV *cluster)
	PREINIT:
		uint32_t *codepoints;
		size_t count;
	CODE:
		count  = decode_codepoints(aTHX_ cluster, "tb_cluster_width", &codepoints);
		RETVAL = tf_cluster_width(codepoints, count);
		Safefree(codepoints);
	OUTPUT:
		RETVAL

# --- Diagnostics ------------------------------------------------------

int
tb_last_errno()

const char *
tb_strerror(int err)

int
tb_has_truecolor()

int
tb_has_egc()

int
tb_attr_width()

const char *
tb_version()

BOOT:
{
	HV *stash = gv_stashpvs("Term::Fabulous::Termbox", GV_ADD);
	HV *tags  = get_hv("Term::Fabulous::Termbox::EXPORT_TAGS", GV_ADD);
#define EXPORT_IV(tag, name) export_constant(aTHX_ stash, tags, tag, #name, newSViv((IV)(name)))
#define EXPORT_UV(tag, name) export_constant(aTHX_ stash, tags, tag, #name, newSVuv((UV)(name)))
	/* Keys of the ASCII control range, with their aliases. */
	EXPORT_IV("keys", TB_KEY_CTRL_TILDE);
	EXPORT_IV("keys", TB_KEY_CTRL_2);
	EXPORT_IV("keys", TB_KEY_CTRL_A);
	EXPORT_IV("keys", TB_KEY_CTRL_B);
	EXPORT_IV("keys", TB_KEY_CTRL_C);
	EXPORT_IV("keys", TB_KEY_CTRL_D);
	EXPORT_IV("keys", TB_KEY_CTRL_E);
	EXPORT_IV("keys", TB_KEY_CTRL_F);
	EXPORT_IV("keys", TB_KEY_CTRL_G);
	EXPORT_IV("keys", TB_KEY_BACKSPACE);
	EXPORT_IV("keys", TB_KEY_CTRL_H);
	EXPORT_IV("keys", TB_KEY_TAB);
	EXPORT_IV("keys", TB_KEY_CTRL_I);
	EXPORT_IV("keys", TB_KEY_CTRL_J);
	EXPORT_IV("keys", TB_KEY_CTRL_K);
	EXPORT_IV("keys", TB_KEY_CTRL_L);
	EXPORT_IV("keys", TB_KEY_ENTER);
	EXPORT_IV("keys", TB_KEY_CTRL_M);
	EXPORT_IV("keys", TB_KEY_CTRL_N);
	EXPORT_IV("keys", TB_KEY_CTRL_O);
	EXPORT_IV("keys", TB_KEY_CTRL_P);
	EXPORT_IV("keys", TB_KEY_CTRL_Q);
	EXPORT_IV("keys", TB_KEY_CTRL_R);
	EXPORT_IV("keys", TB_KEY_CTRL_S);
	EXPORT_IV("keys", TB_KEY_CTRL_T);
	EXPORT_IV("keys", TB_KEY_CTRL_U);
	EXPORT_IV("keys", TB_KEY_CTRL_V);
	EXPORT_IV("keys", TB_KEY_CTRL_W);
	EXPORT_IV("keys", TB_KEY_CTRL_X);
	EXPORT_IV("keys", TB_KEY_CTRL_Y);
	EXPORT_IV("keys", TB_KEY_CTRL_Z);
	EXPORT_IV("keys", TB_KEY_ESC);
	EXPORT_IV("keys", TB_KEY_CTRL_LSQ_BRACKET);
	EXPORT_IV("keys", TB_KEY_CTRL_3);
	EXPORT_IV("keys", TB_KEY_CTRL_4);
	EXPORT_IV("keys", TB_KEY_CTRL_BACKSLASH);
	EXPORT_IV("keys", TB_KEY_CTRL_5);
	EXPORT_IV("keys", TB_KEY_CTRL_RSQ_BRACKET);
	EXPORT_IV("keys", TB_KEY_CTRL_6);
	EXPORT_IV("keys", TB_KEY_CTRL_7);
	EXPORT_IV("keys", TB_KEY_CTRL_SLASH);
	EXPORT_IV("keys", TB_KEY_CTRL_UNDERSCORE);
	EXPORT_IV("keys", TB_KEY_SPACE);
	EXPORT_IV("keys", TB_KEY_BACKSPACE2);
	EXPORT_IV("keys", TB_KEY_CTRL_8);
	/* Terminal-dependent keys. */
	EXPORT_IV("keys", TB_KEY_F1);
	EXPORT_IV("keys", TB_KEY_F2);
	EXPORT_IV("keys", TB_KEY_F3);
	EXPORT_IV("keys", TB_KEY_F4);
	EXPORT_IV("keys", TB_KEY_F5);
	EXPORT_IV("keys", TB_KEY_F6);
	EXPORT_IV("keys", TB_KEY_F7);
	EXPORT_IV("keys", TB_KEY_F8);
	EXPORT_IV("keys", TB_KEY_F9);
	EXPORT_IV("keys", TB_KEY_F10);
	EXPORT_IV("keys", TB_KEY_F11);
	EXPORT_IV("keys", TB_KEY_F12);
	EXPORT_IV("keys", TB_KEY_INSERT);
	EXPORT_IV("keys", TB_KEY_DELETE);
	EXPORT_IV("keys", TB_KEY_HOME);
	EXPORT_IV("keys", TB_KEY_END);
	EXPORT_IV("keys", TB_KEY_PGUP);
	EXPORT_IV("keys", TB_KEY_PGDN);
	EXPORT_IV("keys", TB_KEY_ARROW_UP);
	EXPORT_IV("keys", TB_KEY_ARROW_DOWN);
	EXPORT_IV("keys", TB_KEY_ARROW_LEFT);
	EXPORT_IV("keys", TB_KEY_ARROW_RIGHT);
	EXPORT_IV("keys", TB_KEY_BACK_TAB);
	EXPORT_IV("keys", TB_KEY_MOUSE_LEFT);
	EXPORT_IV("keys", TB_KEY_MOUSE_RIGHT);
	EXPORT_IV("keys", TB_KEY_MOUSE_MIDDLE);
	EXPORT_IV("keys", TB_KEY_MOUSE_RELEASE);
	EXPORT_IV("keys", TB_KEY_MOUSE_WHEEL_UP);
	EXPORT_IV("keys", TB_KEY_MOUSE_WHEEL_DOWN);
	/* Colors and style bits. */
	EXPORT_UV("colors", TB_DEFAULT);
	EXPORT_UV("colors", TB_BLACK);
	EXPORT_UV("colors", TB_RED);
	EXPORT_UV("colors", TB_GREEN);
	EXPORT_UV("colors", TB_YELLOW);
	EXPORT_UV("colors", TB_BLUE);
	EXPORT_UV("colors", TB_MAGENTA);
	EXPORT_UV("colors", TB_CYAN);
	EXPORT_UV("colors", TB_WHITE);
	EXPORT_UV("colors", TB_BOLD);
	EXPORT_UV("colors", TB_UNDERLINE);
	EXPORT_UV("colors", TB_REVERSE);
	EXPORT_UV("colors", TB_ITALIC);
	EXPORT_UV("colors", TB_BLINK);
	EXPORT_UV("colors", TB_HI_BLACK);
	EXPORT_UV("colors", TB_BRIGHT);
	EXPORT_UV("colors", TB_DIM);
	EXPORT_UV("colors", TB_STRIKEOUT);
	EXPORT_UV("colors", TB_UNDERLINE_2);
	EXPORT_UV("colors", TB_OVERLINE);
	EXPORT_UV("colors", TB_INVISIBLE);
	/* Deprecated upstream aliases, kept for code written against Termbox.pm. */
	EXPORT_UV("colors", TB_TRUECOLOR_BOLD);
	EXPORT_UV("colors", TB_TRUECOLOR_UNDERLINE);
	EXPORT_UV("colors", TB_TRUECOLOR_REVERSE);
	EXPORT_UV("colors", TB_TRUECOLOR_ITALIC);
	EXPORT_UV("colors", TB_TRUECOLOR_BLINK);
	EXPORT_UV("colors", TB_TRUECOLOR_BLACK);
	/* Event types, modifiers, input and output modes. */
	EXPORT_IV("event", TB_EVENT_KEY);
	EXPORT_IV("event", TB_EVENT_RESIZE);
	EXPORT_IV("event", TB_EVENT_MOUSE);
	EXPORT_IV("event", TB_MOD_ALT);
	EXPORT_IV("event", TB_MOD_CTRL);
	EXPORT_IV("event", TB_MOD_SHIFT);
	EXPORT_IV("event", TB_MOD_MOTION);
	EXPORT_IV("event", TB_INPUT_CURRENT);
	EXPORT_IV("event", TB_INPUT_ESC);
	EXPORT_IV("event", TB_INPUT_ALT);
	EXPORT_IV("event", TB_INPUT_MOUSE);
	EXPORT_IV("event", TB_OUTPUT_CURRENT);
	EXPORT_IV("event", TB_OUTPUT_NORMAL);
	EXPORT_IV("event", TB_OUTPUT_256);
	EXPORT_IV("event", TB_OUTPUT_216);
	EXPORT_IV("event", TB_OUTPUT_GRAYSCALE);
	EXPORT_IV("event", TB_OUTPUT_TRUECOLOR);
	/* Status codes. */
	EXPORT_IV("return", TB_OK);
	EXPORT_IV("return", TB_ERR);
	EXPORT_IV("return", TB_ERR_NEED_MORE);
	EXPORT_IV("return", TB_ERR_INIT_ALREADY);
	EXPORT_IV("return", TB_ERR_INIT_OPEN);
	EXPORT_IV("return", TB_ERR_MEM);
	EXPORT_IV("return", TB_ERR_NO_EVENT);
	EXPORT_IV("return", TB_ERR_NO_TERM);
	EXPORT_IV("return", TB_ERR_NOT_INIT);
	EXPORT_IV("return", TB_ERR_OUT_OF_BOUNDS);
	EXPORT_IV("return", TB_ERR_READ);
	EXPORT_IV("return", TB_ERR_RESIZE_IOCTL);
	EXPORT_IV("return", TB_ERR_RESIZE_PIPE);
	EXPORT_IV("return", TB_ERR_RESIZE_SIGACTION);
	EXPORT_IV("return", TB_ERR_POLL);
	EXPORT_IV("return", TB_ERR_TCGETATTR);
	EXPORT_IV("return", TB_ERR_TCSETATTR);
	EXPORT_IV("return", TB_ERR_UNSUPPORTED_TERM);
	EXPORT_IV("return", TB_ERR_RESIZE_WRITE);
	EXPORT_IV("return", TB_ERR_RESIZE_POLL);
	EXPORT_IV("return", TB_ERR_RESIZE_READ);
	EXPORT_IV("return", TB_ERR_RESIZE_SSCANF);
	EXPORT_IV("return", TB_ERR_CAP_COLLISION);
	EXPORT_IV("return", TB_ERR_SELECT);
	EXPORT_IV("return", TB_ERR_RESIZE_SELECT);
#undef EXPORT_IV
#undef EXPORT_UV
}
