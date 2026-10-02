/*
 * termbox2.c - the single translation unit that compiles termbox2 in.
 *
 * perl.h stays out of this file on purpose: termbox2's implementation
 * defines feature-test macros and hundreds of static helpers that have
 * no business meeting Perl's macros.
 *
 * Besides the library this file holds the two readers termbox2 lacks.
 * They run as termbox2's TB_FUNC_EXTRACT_PRE hook, before its own
 * parsers, and read the raw input buffer, which is static to this
 * translation unit. It also holds inline mode (tf_init_inline and its
 * helpers), which reaches into termbox2's internals the same way.
 */
#define TB_IMPL
#include "tf_termbox.h"

int tf_cluster_width(const uint32_t *codepoints, size_t count) {
	return tb_cluster_width((uint32_t *)codepoints, count);
}

/* Any larger coordinate or button number is not a mouse report. */
#define TF_MOUSE_NUMBER_LIMIT 65535

/*
 * ESC followed by one key, both in the buffer at once: Alt plus that key.
 * Alt+letter, Alt+Enter and Alt+umlaut arrive this way; ESC ESC, ESC [
 * and ESC O begin other sequences and are left to termbox2, which
 * then also delivers a lone ESC as the Escape key.
 */
static int tf_extract_alt_key(struct tb_event *event, size_t *consumed) {
	const unsigned char *buf = (const unsigned char *)global.in.buf;
	size_t len               = global.in.len;
	unsigned char key_byte;
	size_t key_len;

	if (len < 2) return TB_ERR;
	key_byte = buf[1];
	if (key_byte == 0x1b || key_byte == '[' || key_byte == 'O') return TB_ERR;
	if (key_byte >= 0x80 && key_byte < 0xc0) return TB_ERR; /* a stray UTF-8 continuation byte */

	key_len = key_byte < 0x80 ? 1 : (size_t)tb_utf8_char_length((char)key_byte);
	if (len < 1 + key_len) return TB_ERR_NEED_MORE;

	event->type = TB_EVENT_KEY;
	event->mod  = TB_MOD_ALT;
	if (key_byte < 0x20 || key_byte == 0x7f) {
		/* A control byte is its own key code, with Ctrl set, as termbox2 reports it. */
		event->key = key_byte;
		event->ch  = 0;
		event->mod |= TB_MOD_CTRL;
	} else {
		event->key = 0;
		tb_utf8_char_to_unicode(&event->ch, (const char *)buf + 1);
	}
	*consumed = 1 + key_len;
	return TB_OK;
}

/* The key code of an SGR button number, after its modifier and motion bits are masked off. */
static uint16_t tf_mouse_key(int button, int moving, int released) {
	int low = button & 3;

	if (button & 64) {
		if (low == 0) return TB_KEY_MOUSE_WHEEL_UP;
		if (low == 1) return TB_KEY_MOUSE_WHEEL_DOWN;
		if (low == 2) return TF_KEY_MOUSE_WHEEL_LEFT;
		return TF_KEY_MOUSE_WHEEL_RIGHT;
	}
	if (released) return TB_KEY_MOUSE_RELEASE;
	if (low == 0) return TB_KEY_MOUSE_LEFT;
	if (low == 1) return TB_KEY_MOUSE_MIDDLE;
	if (low == 2) return TB_KEY_MOUSE_RIGHT;
	return moving ? TF_KEY_MOUSE_MOVE : TB_KEY_MOUSE_RELEASE;
}

/* The press key of the button an SGR release ("m") names. Button number
 * 3 is the older "some button was released" form: 0, unknown. */
static uint32_t tf_released_button(int button) {
	int low = button & 3;

	if (button & 64) return 0;
	if (low == 0) return TB_KEY_MOUSE_LEFT;
	if (low == 1) return TB_KEY_MOUSE_MIDDLE;
	if (low == 2) return TB_KEY_MOUSE_RIGHT;
	return 0;
}

/*
 * An SGR mouse report: ESC [ < button ; column ; row M, or m for a
 * release. Bits 2, 3 and 4 of the button number are Shift, Alt and
 * Ctrl, bit 5 is motion, bit 6 marks the wheel (0 up, 1 down, 2 left,
 * 3 right); a button number of 3 with the motion bit is the pointer
 * moving with no button held. A release keeps the button it names in
 * the event's ch (see tf_released_button). Buttons 8 to 11 (bit 7) are left to
 * termbox2. Other encodings (X10, urxvt) are left to it as well.
 */
static int tf_extract_sgr_mouse(struct tb_event *event, size_t *consumed) {
	const char *buf = global.in.buf;
	size_t len      = global.in.len;
	int numbers[3]  = {-1, -1, -1};
	int count       = 0;
	char trail      = 0;
	size_t i;

	if (len < 3) return TB_ERR;
	if (buf[2] != '<') return TB_ERR;

	for (i = 3; i < len && trail == 0; i++) {
		char c = buf[i];
		if (c >= '0' && c <= '9') {
			if (numbers[count] < 0) numbers[count] = 0;
			numbers[count] = numbers[count] * 10 + (c - '0');
			if (numbers[count] > TF_MOUSE_NUMBER_LIMIT) return TB_ERR;
		} else if (c == ';' && count < 2 && numbers[count] >= 0) {
			count++;
		} else if ((c == 'M' || c == 'm') && count == 2 && numbers[2] >= 0) {
			trail = c;
		} else {
			return TB_ERR;
		}
	}
	if (trail == 0) return TB_ERR_NEED_MORE;
	if (numbers[0] & 128) return TB_ERR;

	event->type = TB_EVENT_MOUSE;
	event->key  = tf_mouse_key(numbers[0], numbers[0] & 32, trail == 'm');
	event->ch   = trail == 'm' ? tf_released_button(numbers[0]) : 0;
	event->mod  = 0;
	if (numbers[0] & 4) event->mod |= TB_MOD_SHIFT;
	if (numbers[0] & 8) event->mod |= TB_MOD_ALT;
	if (numbers[0] & 16) event->mod |= TB_MOD_CTRL;
	if (numbers[0] & 32) event->mod |= TB_MOD_MOTION;
	event->x = numbers[1] > 0 ? numbers[1] - 1 : 0;
	event->y = numbers[2] > 0 ? numbers[2] - 1 : 0;
	*consumed = i;
	return TB_OK;
}

static int tf_extract_input(struct tb_event *event, size_t *consumed) {
	const char *buf = global.in.buf;

	if (global.in.len < 2 || buf[0] != '\x1b') return TB_ERR;
	if (buf[1] == '[') return tf_extract_sgr_mouse(event, consumed);
	return tf_extract_alt_key(event, consumed);
}

int tf_install_input_parser(void) {
	return tb_set_func(TB_FUNC_EXTRACT_PRE, tf_extract_input);
}

/*
 * Inline mode. termbox2 has no switch for it, so tf_init_inline_rwfd()
 * runs the steps of tb_init_rwfd() itself and empties the capabilities
 * that take over the screen before anything is sent: the alternate
 * screen, entered at the start and left at tb_shutdown(), and the clear
 * that tb_init_rwfd(), every resize and tb_shutdown() send.
 */
static void tf_drop_screen_takeover(void) {
	global.caps[TB_CAP_ENTER_CA]     = "";
	global.caps[TB_CAP_EXIT_CA]      = "";
	global.caps[TB_CAP_CLEAR_SCREEN] = "";
}

int tf_init_inline(void) {
	int ttyfd;

	if (global.initialized) return TB_ERR_INIT_ALREADY;
	ttyfd = open("/dev/tty", O_RDWR);
	if (ttyfd < 0) {
		global.last_errno = errno;
		return TB_ERR_INIT_OPEN;
	}
	global.ttyfd_open = 1;
	return tf_init_inline_rwfd(ttyfd, ttyfd);
}

int tf_init_inline_rwfd(int rfd, int wfd) {
	int rv;

	if (global.initialized) return TB_ERR_INIT_ALREADY;
	tb_reset();
	global.ttyfd = isatty(rfd) ? rfd : (wfd != rfd && isatty(wfd) ? wfd : -1);
	global.rfd   = rfd;
	global.wfd   = wfd;

	do {
		if_err_break(rv, init_term_attrs());
		if_err_break(rv, init_term_caps());
		tf_drop_screen_takeover();
		if_err_break(rv, init_cap_trie());
		if_err_break(rv, init_resize_handler());
		if_err_break(rv, send_init_escape_codes());
		if_err_break(rv, bytebuf_flush(&global.out, global.wfd));
		if_err_break(rv, update_term_size());
		if_err_break(rv, init_cellbuf());
		global.initialized = 1;
	} while (0);

	if (rv != TB_OK) tb_deinit();
	return rv;
}

/* Any larger row or column is not a cursor position report. */
#define TF_CURSOR_NUMBER_LIMIT 65535

/*
 * Finds a cursor position report, ESC [ row ; column R, in the input
 * buffer from offset `from` on: TB_OK with its offset, length and
 * numbers, or TB_ERR while there is no complete one.
 */
static int tf_find_cursor_report(size_t from, size_t *at, size_t *length, int *row, int *column) {
	const char *buf = global.in.buf;
	size_t len      = global.in.len;
	size_t start, i;

	for (start = from; start + 1 < len; start++) {
		int numbers[2] = {0, 0};
		int count      = 0;
		int digits     = 0;

		if (buf[start] != '\x1b' || buf[start + 1] != '[') continue;
		for (i = start + 2; i < len; i++) {
			char c = buf[i];
			if (c >= '0' && c <= '9') {
				numbers[count] = numbers[count] * 10 + (c - '0');
				if (numbers[count] > TF_CURSOR_NUMBER_LIMIT) break;
				digits++;
			} else if (c == ';' && count == 0 && digits > 0) {
				count  = 1;
				digits = 0;
			} else if (c == 'R' && count == 1 && digits > 0) {
				*at     = start;
				*length = i + 1 - start;
				*row    = numbers[0];
				*column = numbers[1];
				return TB_OK;
			} else {
				break;
			}
		}
	}
	return TB_ERR;
}

/*
 * Appends what the terminal sent to the input buffer, waiting for it no
 * later than the deadline: TB_ERR_NO_EVENT once the deadline has
 * passed. A wait a signal interrupted reads nothing and returns TB_OK.
 */
static int tf_read_input_before(const struct timeval *deadline) {
	char buf[TB_OPT_READ_BUF];
	struct timeval now, left;
	fd_set fds;
	ssize_t count;
	int ready;

	gettimeofday(&now, NULL);
	if (!timercmp(&now, deadline, <)) return TB_ERR_NO_EVENT;
	timersub(deadline, &now, &left);

	FD_ZERO(&fds);
	FD_SET(global.rfd, &fds);
	ready = select(global.rfd + 1, &fds, NULL, NULL, &left);
	if (ready < 0 && errno == EINTR) return TB_OK;
	if (ready < 0) {
		global.last_errno = errno;
		return TB_ERR_POLL;
	}
	if (ready == 0) return TB_ERR_NO_EVENT;

	count = read(global.rfd, buf, sizeof(buf));
	if (count <= 0) {
		global.last_errno = count < 0 ? errno : 0;
		return TB_ERR_READ;
	}
	return bytebuf_nputs(&global.in, buf, (size_t)count);
}

int tf_cursor_position(int timeout_ms, int *x, int *y) {
	struct timeval deadline, timeout;
	size_t from, at, length;
	int rv, row, column;

	if_not_init_return();
	from = global.in.len; /* input from before the question cannot hold the answer */
	if_err_return(rv, bytebuf_puts(&global.out, "\x1b[6n"));
	if_err_return(rv, bytebuf_flush(&global.out, global.wfd));

	gettimeofday(&deadline, NULL);
	timeout.tv_sec  = timeout_ms / 1000;
	timeout.tv_usec = (timeout_ms % 1000) * 1000;
	timeradd(&deadline, &timeout, &deadline);

	while (tf_find_cursor_report(from, &at, &length, &row, &column) != TB_OK) {
		if_err_return(rv, tf_read_input_before(&deadline));
	}

	memmove(global.in.buf + at, global.in.buf + at + length, global.in.len - at - length);
	global.in.len -= length;
	global.in.buf[global.in.len] = '\0';

	*x = column > 0 ? column - 1 : 0;
	*y = row > 0 ? row - 1 : 0;
	return TB_OK;
}

int tf_reset_attrs(void) {
	if_not_init_return();
	global.last_fg = ~global.fg;
	global.last_bg = ~global.bg;
	return bytebuf_puts(&global.out, global.caps[TB_CAP_SGR0]);
}

int tf_flush(void) {
	if_not_init_return();
	return bytebuf_flush(&global.out, global.wfd);
}
