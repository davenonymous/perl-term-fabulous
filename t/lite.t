use v5.32;
use warnings;
use utf8;
use feature 'signatures';
no warnings 'experimental::signatures';

use Test2::V0;

use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM CLAY_LEFT_TO_RIGHT CLAY_ALIGN_X_CENTER CLAY_ALIGN_Y_CENTER CLAY_ALIGN_Y_BOTTOM);
use Term::Fabulous::Lite;
use Term::Fabulous::Terminal::Memory;
use Term::Fabulous::Theme;

subtest 'the import' => sub {
	is TF, 'Term::Fabulous::Lite', 'TF is the package name';
	ok !main->can('box'), 'nothing else is exported';
};

subtest 'widgets and children' => sub {
	my $column = TF->column( gap => 1, TF->text('first'), TF->text( 'second', bold => 1 ), TF->row() );
	isa_ok $column, 'Term::Fabulous::Widget::Box';
	is [ map { ref } $column->children->@* ], [ 'Term::Fabulous::Widget::Text', 'Term::Fabulous::Widget::Text', 'Term::Fabulous::Widget::Box' ],
		'the widgets among the arguments are the children, in order';
	is [ map { $_->text } $column->children->@[ 0, 1 ] ], [ 'first', 'second' ], 'the main value of a text is its text';
	ok( $column->children->[1]->bold, 'the options follow the main value' );
	is $column->layout->{layout_direction}, CLAY_TOP_TO_BOTTOM, 'a column is a box from top to bottom';
	is $column->layout->{child_gap},        1,                  'gap is the child gap';

	my $row = TF->row( direction => 'wrap' );
	is $row->layout->{layout_direction}, Clay::XS::CLAY_LEFT_TO_RIGHT_WRAP(), 'the option of the call replaces the preset';
	is TF->screen->layout->{sizing}, { width => sizing_grow(), height => sizing_grow() }, 'a screen grows both ways';

	my $button = TF->button( 'Save', id => 'save' );
	isa_ok $button, 'Term::Fabulous::Widget::Button';
	is( $button->children->[0]->text, 'Save', 'the label of a button is a text child' );
	is TF->checkbox('Agree')->label,     'Agree', 'a checkbox takes its label first';
	is TF->status_bar('Ready')->message, 'Ready', 'a status bar takes its message first';
	is TF->page('Files')->title,         'Files', 'a page takes its title first';

	like dies { TF->text( 'one', TF->box ) }, qr/\ATerm::Fabulous::Lite: text widgets take no children \(Term::Fabulous::Widget::Text has no add_child\), got Term::Fabulous::Widget::Box/,
		'a widget without add_child refuses children';
	like dies { TF->box( 'stray', gap => 1 ) }, qr/\ATerm::Fabulous::Lite: box takes key => value options, got an odd number of them starting with 'stray' \(box has no main value\)/,
		'an odd option list without a main value dies';
	like dies { TF->text( 'one', text => 'two' ) }, qr/\ATerm::Fabulous::Lite: text has both a main value and text; give one of them/, 'the main value and its parameter together die';
	like dies { TF->box( nonsense => 1 ) },         qr/nonsense/,                                                                      'an unknown option reaches the widget, which dies';
	like dies { TF->text( 'x', width => 'grow', gap => 1 ) }, qr/\ATerm::Fabulous::Lite: text has no layout, so gap, width cannot apply \(Term::Fabulous::Widget::Text takes no layout; /,
		'a layout option on a text dies with a hint';
};

subtest 'the option vocabulary' => sub {
	my $box = TF->box( width => 'grow', height => 'fixed(4)', padding => [ 1, 2 ], align => 'center', border => 'Double', bg => '#102030', line_gap => 2, line_sizing => 'fit' );
	is $box->layout->{sizing},          { width => sizing_grow(), height => sizing_fixed(4) },  'width and height are sizing strings';
	is $box->layout->{padding},         { top => 1, bottom => 1, left => 2, right => 2 },       'padding [ vertical, horizontal ]';
	is $box->layout->{child_alignment}, { x => CLAY_ALIGN_X_CENTER, y => CLAY_ALIGN_Y_CENTER }, 'align center is both axes';
	is $box->layout->{line_gap},                                         2,                                'line_gap';
	is $box->layout->{line_sizing},                                      Clay::XS::CLAY_LINE_SIZING_FIT(), 'line_sizing by name';
	is $box->border_style_top->name,                                     'Double',                         'border is a style name';
	is $box->bordered, { top => 1, right => 1, bottom => 1, left => 1 }, 'and the box is bordered on every side';
	is $box->background_color,                                           [ 0x10, 0x20, 0x30, 255 ], 'bg is the background color';

	is TF->box( padding => 3 )->layout->{padding},                            { top => 3, right => 3, bottom => 3, left => 3 },       'padding N is every side';
	is TF->box( padding => [ 1, 2, 3, 4 ] )->layout->{padding},               { top => 1, right => 2, bottom => 3, left => 4 },       'padding [ top, right, bottom, left ]';
	is TF->box( padding => { left => 2 } )->layout->{padding},                { left => 2 },                                          'padding as a hash of sides';
	is TF->box( align => 'bottom' )->layout->{child_alignment},               { y => CLAY_ALIGN_Y_BOTTOM },                           'align with a name of one axis';
	is TF->box( align => [ 'center', 'bottom' ] )->layout->{child_alignment}, { x => CLAY_ALIGN_X_CENTER, y => CLAY_ALIGN_Y_BOTTOM }, 'align [ x, y ]';
	is TF->box( border => 1 )->bordered,                                      { top => 1, right => 1, bottom => 1, left => 1 },       'border 1 is a border on every side';
	is TF->box( border => 0 )->bordered,                                      { top => 0, right => 0, bottom => 0, left => 0 },       'border 0 is no border';
	my $sides = TF->box( border => { top => 1, bottom => 1, style => 'Heavy' } );
	is $sides->bordered, { top => 1, right => 0, bottom => 1, left => 0 },                                    'border as a hash of sides';
	is $sides->border_style_top->name,                                                                        'Heavy',            'with its style';
	is TF->table( id => 't', border => 'Double', columns => [ { key => 'a', title => 'A' } ] )->border->name, 'Double',           'a table keeps border and columns as its own parameters';
	is TF->text( 'x', fg => '#ff0000' )->text_color,                                                          [ 255, 0, 0, 255 ], 'fg is the text color';
	is TF->text_field( columns => 12 )->preferred_columns,                                                    12,                 'columns is preferred_columns';

	my $box_with_layout = TF->box( gap => 2, layout => { padding => { left => 1 } } );
	is $box_with_layout->layout, { child_gap => 2, padding => { left => 1 } }, 'a Lite option merges into a given layout hash';

	like dies { TF->box( width     => 'huge' ) },   qr/\ATerm::Fabulous::Lite: invalid box width 'huge' \(expected grow, fit/,                           'a bad sizing names the helper and the option';
	like dies { TF->box( direction => 'up' ) },     qr/\ATerm::Fabulous::Lite: box direction must be one of back_to_front, btf, down/,                   'a bad direction lists the names';
	like dies { TF->box( align     => 'middle' ) }, qr/\ATerm::Fabulous::Lite: box align must be one of bottom, center, left, right, top, got 'middle'/, 'a bad alignment lists the names';
	like dies { TF->box( padding   => [1] ) }, qr/box padding as an array takes \[ vertical, horizontal \] or \[ top, right, bottom, left \], got 1 values/, 'a padding array of the wrong length dies';
	like dies { TF->box( padding   => { middle => 1 } ) }, qr/box padding side must be one of bottom, left, right, top, got 'middle'/,                       'a bad padding side dies';
	like dies { TF->box( border    => 'Fancy' ) },         qr/\ATerm::Fabulous::Lite: box border must be a border style or its name, got 'Fancy'/,           'a bad border style dies';
	like dies { TF->box( width     => 'grow', layout => { sizing => { width => sizing_grow() } } ) }, qr/\ATerm::Fabulous::Lite: box has both width and layout\.sizing\.width; give one of them/,
		'a Lite option and its full form together die';
	like dies { TF->box( bg     => '#000', background_color => '#000' ) }, qr/box has both bg and background_color/,               'bg and background_color together die';
	like dies { TF->box( border => 1,      bordered         => 1 ) },      qr/box has both border and bordered; give one of them/, 'border and bordered together die';
	like dies { TF->box( on => { Activate => 'nope' } ) }, qr/box on Activate must be a code reference, got 'nope'/, 'a listener that is not code dies';
};

subtest 'listeners' => sub {
	my @seen;
	my $button = TF->button( 'Go', on => { Activate => sub ($event) { push @seen, $event->name; return } } );
	$button->activate;
	is \@seen, ['Activate'], 'on registers the handlers';
};

subtest 'widget' => sub {
	isa_ok TF->widget( 'Spinner',                         width => 'fit' ), 'Term::Fabulous::Widget::Spinner';
	isa_ok TF->widget( 'Term::Fabulous::Widget::Divider', text  => 'x' ),   'Term::Fabulous::Widget::Divider';
	like dies { TF->widget('Nope') },           qr/\ATerm::Fabulous::Lite: cannot load the widget class Term::Fabulous::Widget::Nope: /,                           'an unknown class dies';
	like dies { TF->widget( 'Divider', 'x' ) }, qr/Divider takes key => value options, got an odd number of them starting with 'x' \(Divider has no main value\)/, 'widget has no main value';
	is [ TF->helper_names ],
		[ sort qw(box column row screen text rich_text button text_field text_area checkbox radio_group radio_button dropdown slider scroll_box divider progress_bar status_bar table tabs page) ],
		'helper_names';
};

subtest 'app and run' => sub {
	my $field    = TF->text_field( id => 'name' );
	my $root     = TF->screen($field);
	my $terminal = Term::Fabulous::Terminal::Memory->new( width => 40, height => 10 );
	my $ui       = TF->app( $root, terminal => $terminal, focus => $field, quit_keys => ['Escape'], theme => 'light' );
	isa_ok $ui, 'Term::Fabulous';
	is [ $ui->width, $ui->height ], [ 80, 24 ], 'the size defaults to 80 by 24';
	ref_is $ui->interaction->get_focused_widget, $field, 'focus sets the focused widget';
	is $ui->theme->name, 'light', 'theme by name';

	$terminal->type_text('Ada');
	$terminal->press_key('Escape');
	$ui->run;
	is $field->value, 'Ada', 'the keys reached the field before the quit key';

	# Inline mode draws the final state before run returns.
	my $second = Term::Fabulous::Terminal::Memory->new( width => 40, height => 10 );
	$second->press_key('q');
	my $ran = TF->run( TF->screen( TF->text('bye') ), terminal => $second, quit_keys => ['q'], inline => 2 );
	isa_ok $ran, 'Term::Fabulous';
	like( ( $second->lines )[0], qr/\Abye/, 'run drew the tree before q ended it' );

	like dies { TF->app( TF->box, quit_keys => 'q' ) },           qr/\ATerm::Fabulous::Lite: quit_keys must be an array reference of key names, got 'q'/, 'quit_keys must be an array';
	like dies { TF->app( TF->box, quit_keys => ['Ctrl+Nope'] ) }, qr/Nope/,                                                                               'an unknown key name dies at once';
	like dies { TF->app('root') }, qr/\ATerm::Fabulous::Lite: app needs a root widget, got 'root'/, 'app needs a widget';
};

subtest 'print and render' => sub {
	my $root = TF->column( border => 'Round', padding => [ 0, 1 ], TF->text('Report'), TF->text('ok') );
	my $text = TF->render( $root, width => 12, colors => 0 );
	my $line = "\x{2500}" x 8;
	is $text, "\x{256D}$line\x{256E}\n\x{2502} Report \x{2502}\n\x{2502} ok     \x{2502}\n\x{2570}$line\x{256F}\n", 'render returns the text, the box as wide as its content';

	my $printed = '';
	open my $fh, '>', \$printed or die $!;
	TF->print( $root, width => 12, fh => $fh, colors => 0 );
	close $fh;
	utf8::decode($printed);
	is $printed, $text, 'print writes the same to the handle';
	like dies { TF->render( 'x', width => 12 ) }, qr/print and render need a root widget, got 'x'/, 'render needs a widget';
};

subtest 'load and theme' => sub {
	my $root = TF->load( \qq{use "Term::Fabulous::Widget::Box" as "Box"\nuse "Term::Fabulous::Widget::Text" as "Text"\nBox "root" {\n\tText "hello" { text "Hello" }\n}\n} );
	isa_ok $root, 'Term::Fabulous::Widget::Box';
	is $root->find_by_id('hello')->text, 'Hello', 'load builds the tree of a KDL string';
	like dies { TF->load('/nonexistent/layout.kdl') }, qr/cannot open/,                                                                                       'a missing file dies';
	like dies { TF->load( ['x'] ) }, qr/\ATerm::Fabulous::Lite: load needs the path of a layout file or a reference to a KDL string, got an ARRAY reference/, 'load takes a path or a string reference';

	my $dark = Term::Fabulous::Theme->builtin('dark');
	ref_is TF->theme($dark), $dark, 'a theme object passes through';
	is TF->theme('light')->name, 'light', 'a built-in theme by name';
	like dies { TF->theme('neon') }, qr/\ATerm::Fabulous::Lite: unknown built-in theme 'neon' \(known: dark, light\); a theme file ends in \.kdl/, 'an unknown name dies';
	like dies { TF->theme( ['x'] ) },
		qr/\ATerm::Fabulous::Lite: theme must be a Term::Fabulous::Theme, the name of a built-in theme \(dark, light\) or the path of a \.kdl theme file, got an ARRAY reference/, 'a reference dies';
	like dies { TF->theme('/nonexistent/ocean.kdl') }, qr/ocean\.kdl/, 'a missing theme file dies';
};

subtest 'prompts and inline' => sub {
	is TF->inline, 'Term::Fabulous::Lite::Inline', 'inline is the package of the synchronous questions';
	ok TF->can($_), "$_ proxies the prompt" foreach qw(alert confirm ask);
};

done_testing;
