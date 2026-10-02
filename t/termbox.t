use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
use utf8;

use Test2::V0;

use Term::Fabulous::Termbox qw(:all);
use Term::Fabulous::Termbox::Event;

subtest 'compile-time options' => sub {
	is tb_version(),       '2.7.0-dev', 'the vendored termbox2 version';
	is tb_attr_width(),    64,          '64-bit attributes';
	ok tb_has_truecolor(), 'truecolor';
	ok tb_has_egc(),       'grapheme clusters';
};

subtest 'constants' => sub {
	is TB_KEY_CTRL_C,     0x03,            'ASCII control keys are exported';
	is TB_KEY_TAB,        0x09,            'TB_KEY_TAB';
	is TB_KEY_ARROW_LEFT, 0xFFFF - 20,     'terminal-dependent keys';
	is TB_HI_BLACK,       0x20000000,      'style bits above the 24-bit color';
	is TB_STRIKEOUT,      1 << 32,         '64-bit-only style bits';
	is TB_TRUECOLOR_BLACK, TB_HI_BLACK,    'deprecated aliases still name the same bit';
	is TB_ERR_NO_EVENT,   -6,              'status codes';
	is TB_OUTPUT_TRUECOLOR, 5,             'output modes';
	is [ sort keys %Term::Fabulous::Termbox::EXPORT_TAGS ], [qw(all api colors event keys return width)], 'export tags';
	ok( ( grep { $_ eq 'TB_KEY_MOUSE_WHEEL_DOWN' } @{ $Term::Fabulous::Termbox::EXPORT_TAGS{keys} } ), 'constants are listed under their tag' );
	is [ TF_KEY_MOUSE_MOVE, TF_KEY_MOUSE_WHEEL_LEFT, TF_KEY_MOUSE_WHEEL_RIGHT ], [ 0xFFFF - 29, 0xFFFF - 30, 0xFFFF - 31 ], 'the Term::Fabulous mouse keys sit below the termbox2 ones';
};

subtest 'widths' => sub {
	is tb_wcwidth( ord 'a' ),                1,  'narrow';
	is tb_wcwidth(0x4E00),                   2,  'wide';
	is tb_wcwidth(0x301),                    0,  'combining mark';
	is tb_wcwidth(0x1B),                     -1, 'not printable';
	ok tb_iswprint( ord 'a' ),               'printable';
	ok !tb_iswprint(0x1B),                   'control character';
	is tb_cluster_width("\x{2764}\x{FE0F}"), 2,  'VS16 cluster';
	is tb_cluster_width("\x{2764}\x{FE0E}"), 1,  'VS15 cluster';
	is tb_cluster_width("e\x{301}"),         1,  'combining sequence';
	like dies { tb_cluster_width('') }, qr/tb_cluster_width needs a non-empty string/, 'empty cluster dies';
};

subtest 'before tb_init' => sub {
	is tb_width(), TB_ERR_NOT_INIT, 'tb_width reports the status';
	is tb_strerror(TB_ERR_NOT_INIT), 'Termbox not initialized', 'tb_strerror names it';
	is tb_set_cell( 0, 0, 'a', TB_DEFAULT, TB_DEFAULT ), TB_ERR_NOT_INIT, 'a character string';
	is tb_set_cell( 0, 0, ord 'a', TB_DEFAULT, TB_DEFAULT ), TB_ERR_NOT_INIT, 'an integer codepoint';
	like dies { tb_set_cell( 0, 0, '', TB_DEFAULT, TB_DEFAULT ) }, qr/tb_set_cell needs a non-empty character/, 'an empty string dies';
	like dies { tb_get_fds( 1, 2 ) }, qr/tb_get_fds needs a scalar reference/, 'tb_get_fds wants references';

	my $event = Term::Fabulous::Termbox::Event->new;
	is tb_peek_event( $event, 0 ), TB_ERR_NOT_INIT, 'tb_peek_event reports the status';
	is $event->type, 0, 'and leaves the event untouched';
};

subtest 'event object' => sub {
	my $event = Term::Fabulous::Termbox::Event->new( type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 3, y => 1 );
	is [ $event->type, $event->key, $event->x, $event->y, $event->mod, $event->ch, $event->w, $event->h ], [ TB_EVENT_MOUSE, TB_KEY_MOUSE_LEFT, 3, 1, 0, 0, 0, 0 ], 'fields from the constructor, the rest 0';
	$event->key(TB_KEY_MOUSE_RELEASE);
	is $event->key, TB_KEY_MOUSE_RELEASE, 'accessors also set';
	like dies { Term::Fabulous::Termbox::Event->new( button => 1 ) }, qr/button/, 'unknown fields die';
};

subtest 'input parser' => sub {
	pipe my $read, my $write or die "pipe: $!";
	open my $sink, '>', '/dev/null' or die "/dev/null: $!";
	my $rc = tb_init_rwfd( fileno $read, fileno $sink );
	skip_all "termbox2 cannot start on a pipe here: " . tb_strerror($rc) unless $rc == TB_OK;
	tb_set_input_mode( TB_INPUT_ESC | TB_INPUT_MOUSE );
	is tf_install_input_parser(), TB_OK, 'the parser installs';

	# Writes the bytes and returns every event they produce as [type, key, ch, mod, x, y].
	my $feed = sub ($bytes) {
		syswrite $write, $bytes;
		my @events;
		while (1) {
			my $event = Term::Fabulous::Termbox::Event->new;
			last unless tb_peek_event( $event, 100 ) == TB_OK;
			push @events, [ map { $event->$_ } qw(type key ch mod x y) ];
		}
		return \@events;
	};

	is $feed->("\x1bx"),        [ [ TB_EVENT_KEY, 0, ord('x'), TB_MOD_ALT, 0, 0 ] ],                      'Alt+x';
	is $feed->("\x1b\xc3\xa9"), [ [ TB_EVENT_KEY, 0, 0xE9, TB_MOD_ALT, 0, 0 ] ],                              'Alt plus a two-byte character';
	is $feed->("\x1b\r"),       [ [ TB_EVENT_KEY, TB_KEY_ENTER, 0, TB_MOD_ALT | TB_MOD_CTRL, 0, 0 ] ],         'Alt+Enter keeps the control byte as its key';
	is $feed->("\x1b"),          [ [ TB_EVENT_KEY, TB_KEY_ESC, 0, 0, 0, 0 ] ],                                 'a lone Escape is still Escape';
	is $feed->("\x1b[A")->[0][1], TB_KEY_ARROW_UP, 'CSI sequences are left to termbox2';
	is $feed->("\x1b[<35;10;5M"), [ [ TB_EVENT_MOUSE, TF_KEY_MOUSE_MOVE, 0, TB_MOD_MOTION, 9, 4 ] ],            'plain motion';
	is $feed->("\x1b[<32;2;1M"),  [ [ TB_EVENT_MOUSE, TB_KEY_MOUSE_LEFT, 0, TB_MOD_MOTION, 1, 0 ] ],            'a drag with the left button';
	is $feed->("\x1b[<0;2;1m"),   [ [ TB_EVENT_MOUSE, TB_KEY_MOUSE_RELEASE, 0, 0, 1, 0 ] ],                      'a release';
	is [ map { $_->[1] } @{ $feed->("\x1b[<64;3;3M\x1b[<65;3;3M\x1b[<66;3;3M\x1b[<67;3;3M") } ],
		[ TB_KEY_MOUSE_WHEEL_UP, TB_KEY_MOUSE_WHEEL_DOWN, TF_KEY_MOUSE_WHEEL_LEFT, TF_KEY_MOUSE_WHEEL_RIGHT ], 'four wheel directions, queued in one write';
	is $feed->("\x1b[<20;300;40M"), [ [ TB_EVENT_MOUSE, TB_KEY_MOUSE_LEFT, 0, TB_MOD_SHIFT | TB_MOD_CTRL, 299, 39 ] ], 'modifier bits and coordinates beyond 255';
	is $feed->("\x1b[<0;1"), [], 'a partial report waits';
	is $feed->(";1M"), [ [ TB_EVENT_MOUSE, TB_KEY_MOUSE_LEFT, 0, 0, 0, 0 ] ], 'until the rest arrives';
	tb_shutdown();
};

done_testing;
