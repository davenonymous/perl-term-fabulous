use v5.32;
use warnings;

use Test2::V0;

use Term::Fabulous::Enum::BorderStyle;
use Term::Fabulous::Theme;

my $Theme = 'Term::Fabulous::Theme';

subtest 'the vocabulary' => sub {
	my @families = Term::Fabulous::Theme::families();
	is \@families, [ sort @families ], 'families are sorted';
	ok( ( grep { $_ eq 'button' } @families ), 'button is a family' );
	is [ Term::Fabulous::Theme::states() ], [qw(normal hovered focused pressed disabled selected active)], 'the states, normal first';
	ok( ( grep { $_ eq 'accent' } Term::Fabulous::Theme::tokens() ), 'accent is a token' );
	is [ Term::Fabulous::Theme::builtin_names() ], [qw(dark light)], 'two built-in themes';

	my %states_of = Term::Fabulous::Theme::slots('button');
	is $states_of{'border.color'}, [qw(disabled focused hovered pressed)], 'a stateful slot lists its states';
	is $states_of{'border.style'}, [],                                     'a style slot has no states';
	ok exists $states_of{background}, 'button inherits the slots of box';

	ok Term::Fabulous::Theme::is_family('text'),                         'is_family';
	ok !Term::Fabulous::Theme::is_family('Button'),                      'family names are lower case';
	ok Term::Fabulous::Theme::has_slot( 'button', 'text', 'disabled' ),  'has_slot with a state';
	ok !Term::Fabulous::Theme::has_slot( 'button', 'text', 'selected' ), 'a state the slot does not have';
	ok !Term::Fabulous::Theme::has_slot( 'box', 'text' ),                'a slot the family does not have';
	ok !Term::Fabulous::Theme::has_slot( 'box', undef ),                 'undef is no slot';
	like dies { Term::Fabulous::Theme::slots('nope') }, qr/unknown family 'nope' \(known: /, 'slots of an unknown family dies';
};

subtest 'the built-in themes' => sub {
	my $dark = $Theme->default;
	is $dark->name, 'dark', 'the default theme is dark';
	ref_is $Theme->builtin('dark'), $dark, 'built-in themes are shared objects';
	is $dark->extends,          undef, 'a built-in theme extends nothing';
	is $Theme->builtin('neon'), undef, 'an unknown built-in name is undef';

	is $dark->token('accent'),                               [ 97, 175, 239, 255 ],           'the dark accent is the color the widgets always used';
	is $dark->look( 'button', 'border.color', 'focused' ),   [ 97, 175, 239, 255 ],           'a focused button border is the accent';
	is $dark->look( 'button', 'border.color' ),              [ 70, 85, 110, 255 ],            'a button border is drawn in the border token';
	is $dark->look( 'button', 'background', 'pressed' ),     'reverse',                       'a pressed button is drawn in reverse video';
	is $dark->look( 'button', 'text', 'hovered' ),           $dark->look( 'button', 'text' ), 'a state without a value of its own looks normal';
	is $dark->look( 'text_input', 'background' ),            [ 36, 40, 48, 255 ],             'a text input background';
	is $dark->look( 'text_input', 'background', 'focused' ), [ 52, 58, 72, 255 ],             'a focused text input background';
	is $dark->look( 'text_input', 'placeholder' ),           [ 120, 126, 138, 255 ],          'text_input inherits the input slots';
	ref_is $dark->look( 'dialog', 'border.style' ), Term::Fabulous::Enum::BorderStyle->Round, 'a style slot holds a BorderStyle item';
	ref_is $dark->look( 'box',    'border.style' ), Term::Fabulous::Enum::BorderStyle->Round, 'a plain box has the round border style';
	is $dark->look( 'box', 'background' ), undef, 'a plain box has no background';

	my $light = $Theme->builtin('light');
	isnt $light->token('text'), $dark->token('text'), 'the light theme has its own text color';
	ok( ( $light->token('text')->[0] < 128 && $light->token('background')->[0] > 128 ), 'dark text on a light background' );

	my $palette = $dark->palette;
	is [ sort keys %$palette ], [ Term::Fabulous::Theme::tokens() ], 'the palette has every token';
	$palette->{accent}[0] = 0;
	is $dark->token('accent')->[0],                                                                                      97,                 'the palette is a copy';
	is $Theme->new( palette => { accent => 'Tomato' }, slots => { 'button.text' => 'navy' } )->look( 'button', 'text' ), [ 0, 0, 128, 255 ], 'palettes and slots take web color names';
	like dies { $dark->token('pink') },            qr/unknown token 'pink' \(known: /,                               'an unknown token dies';
	like dies { $dark->look( 'button', 'glow' ) }, qr/the family button has no slot 'glow' with the state 'normal'/, 'an unknown slot dies';
};

subtest 'a theme derived in Perl' => sub {
	my $theme = $Theme->new(
		name    => 'red',
		palette => { accent => '#ff0000' },
		slots   => {
			'button.border.style'    => 'Round',
			'button.text'            => [ 1, 2, 3 ],
			'input.half'             => 'accent',
			'table.stripe'           => 'none',
			'accordion.border.style' => undef,
		},
	);
	is $theme->name, 'red', 'name';
	ref_is $theme->extends, $Theme->default, 'extends dark by default';
	is $theme->token('accent'),                             [ 255, 0, 0, 255 ],             'the palette override';
	is $theme->token('text'),                               $Theme->default->token('text'), 'other tokens come from the parent';
	is $theme->look( 'button', 'border.color', 'focused' ), [ 255, 0, 0, 255 ],             'slots that default to a token follow it';
	is $theme->look( 'input', 'accent' ),                   [ 255, 0, 0, 255 ],             'in every family';
	ref_is $theme->look( 'button', 'border.style' ), Term::Fabulous::Enum::BorderStyle->Round, 'a style by name';
	is $theme->look( 'button', 'text' ),             [ 1, 2, 3, 255 ],          'a literal color';
	is $theme->look( 'button', 'text', 'pressed' ),  [ 1, 2, 3, 255 ],          'a state that looks normal follows the override';
	is $theme->look( 'button', 'text', 'disabled' ), $theme->token('disabled'), 'a state with a value of its own keeps it';
	is $theme->look( 'input', 'half' ),              [ 255, 0, 0, 255 ],        'a token for a slot that had none';
	is $theme->look( 'table', 'stripe' ),            undef,                     'none';
	is $theme->look( 'accordion', 'border.style' ),  undef,                     'undef is none';

	my $child = $Theme->new( extends => $theme, slots => { 'button.text.pressed' => 'text' } );
	is $child->look( 'button', 'border.color', 'focused' ), [ 255, 0, 0, 255 ],    'a child inherits the palette';
	is $child->look( 'button', 'text' ),                    [ 1, 2, 3, 255 ],      'and the slots';
	is $child->look( 'button', 'text', 'pressed' ),         $theme->token('text'), 'and overrides one state';
	is $child->name,                                        undef,                 'no name unless given';

	is $Theme->new( extends => 'light' )->token('text'), $Theme->builtin('light')->token('text'), 'extends by built-in name';
	ref_is $Theme->new( extends => $Theme->builtin('light') )->extends, $Theme->builtin('light'), 'extends by object';
};

subtest 'variants' => sub {
	my $theme = $Theme->new(
		variants => {
			'button.primary' => { 'border.color' => 'accent', 'text.disabled' => '#000000' },
			'button.compact' => { 'border.color' => '#00ff00' },
			'input.wide'     => { 'background'   => 'surface' },
		},
	);
	my $accent = $theme->token('accent');
	ok $theme->has_variant( 'button',  'primary' ), 'has_variant';
	ok !$theme->has_variant( 'button', 'danger' ),  'an unknown variant';
	is $theme->look( 'button', 'border.color', 'normal',   ['primary'] ),              $accent,                   'a variant overrides a slot';
	is $theme->look( 'button', 'border.color', 'hovered',  ['primary'] ),              $accent,                   'a state that looks normal follows the variant';
	is $theme->look( 'button', 'border.color', 'focused',  ['primary'] ),              $accent,                   'a state with its own family value keeps it';
	is $theme->look( 'button', 'border.color', 'disabled', ['primary'] ),              $theme->token('disabled'), 'disabled keeps the family value';
	is $theme->look( 'button', 'text',         'disabled', ['primary'] ),              [ 0, 0, 0, 255 ],          'a variant overrides one state';
	is $theme->look( 'button', 'text',         'normal',   ['primary'] ),              $theme->token('text'),     'the other states stay';
	is $theme->look( 'button', 'border.color', 'normal',   ['danger'] ),               $theme->token('border'),   'a class without a variant changes nothing';
	is $theme->look( 'button', 'border.color', 'normal',   [ 'primary', 'compact' ] ), [ 0, 255, 0, 255 ],        'later classes win';
	is $theme->look( 'button', 'border.color', 'normal',   [ 'compact', 'primary' ] ), $accent,                   'in class order';
	is $theme->look( 'button', 'text',         'disabled', [ 'compact', 'primary' ] ), [ 0, 0, 0, 255 ],          'slots only one variant sets are kept';
	is $theme->look( 'input',  'background',   'normal',   ['wide'] ),                 $theme->token('surface'),  'variants of another family';
	is $theme->look( 'input',  'background',   'normal',   ['primary'] ),              undef,                     'a variant applies to its family only';

	ref_is $theme->look_table( 'button', [ 'primary', 'compact' ] ), $theme->look_table( 'button', [ 'primary', 'compact' ] ), 'look tables are cached';
	ref_is $theme->look_table( 'button', ['danger'] ),               $theme->look_table('button'),                             'classes without variants share the family table';
	is $theme->look_table('button')->{'border.color.focused'}, $accent, 'the table keys are slot.state';
	ok !exists $theme->look_table('button')->{'border.color.hovered'}, 'a state without a value of its own has no entry';
	ok exists $theme->look_table('button')->{'border.color.normal'},   'the normal state always has one';

	my $child = $Theme->new( extends => $theme, variants => { 'button.primary' => { 'text' => '#ffffff' } } );
	is $child->look( 'button', 'border.color', 'normal', ['primary'] ), $accent,                'a child inherits a variant';
	is $child->look( 'button', 'text',         'normal', ['primary'] ), [ 255, 255, 255, 255 ], 'and extends it';
	ok $child->has_variant( 'button', 'compact' ), 'has_variant sees inherited variants';
};

subtest 'invalid themes die' => sub {
	like dies { $Theme->new( extends => 'neon' ) },                        qr/extends names an unknown built-in theme 'neon' \(known: dark, light\)/,              'unknown parent name';
	like dies { $Theme->new( extends => undef ) },                         qr/extends must be a Term::Fabulous::Theme or the name of a built-in theme, got undef/, 'undef parent';
	like dies { $Theme->new( palette => { pink => '#ff00ff' } ) },         qr/palette does not know the token pink \(known: /,                                     'unknown token';
	like dies { $Theme->new( palette => { accent => 'redd' } ) },          qr/palette token accent must be a color, got 'redd'/,                                   'invalid color';
	like dies { $Theme->new( palette => [] ) },                            qr/palette must be a hash reference/,                                                   'palette not a hash';
	like dies { $Theme->new( slots   => { 'glow' => 'accent' } ) },        qr/a slot key must be 'family.slot' or 'family.slot.state', got 'glow'/,                'slot key without a family';
	like dies { $Theme->new( slots   => { 'lamp.glow' => 'accent' } ) },   qr/slot 'lamp.glow' names an unknown family 'lamp'/,                                    'unknown family';
	like dies { $Theme->new( slots   => { 'button.glow' => 'accent' } ) }, qr/the family button has no slot 'glow' \(known: background, border.color, border.style, text\)/, 'unknown slot';
	like dies { $Theme->new( slots   => { 'button.text.selected' => 'accent' } ) }, qr/the slot button.text has no state 'selected' \(its states: disabled, focused, hovered, pressed\)/,
		'a state the slot lacks';
	like dies { $Theme->new( slots    => { 'input.background'    => 'reverse' } ) }, qr/input.background cannot be 'reverse' \(only button.background can\)/, 'reverse elsewhere';
	like dies { $Theme->new( slots    => { 'button.border.style' => 'Wobbly' } ) },  qr/button.border.style must be a border style, its name or 'none', got 'Wobbly' \(known: Ascii, /, 'unknown style';
	like dies { $Theme->new( slots    => { 'button.border.style' => 'accent' } ) },  qr/button.border.style must be a border style, its name or 'none', got 'accent'/, 'a token for a style slot';
	like dies { $Theme->new( slots    => { 'button.text'         => 'redd' } ) },    qr/button.text must be a color, got 'redd'/,                                      'invalid slot color';
	like dies { $Theme->new( variants => { 'primary'             => {} } ) },        qr/a variant key must be 'family.variant', got 'primary'/,                        'variant key without a family';
	like dies { $Theme->new( variants => { 'lamp.primary'        => {} } ) },        qr/variant 'lamp.primary' names an unknown family 'lamp'/,                        'variant of an unknown family';
	like dies { $Theme->new( variants => { 'button.primary'      => [] } ) },        qr/variant 'button.primary' must be a hash reference of slots/,                   'variant not a hash';
	like dies { $Theme->new( variants => { 'button.primary'      => { glow => 'accent' } } ) }, qr/variant 'button.primary': the family button has no slot 'glow'/,    'unknown slot in a variant';
	like dies { $Theme->new( name     => [] ) }, qr/name must be a string/,                                                   'name not a string';
	like dies { $Theme->new( colour   => {} ) }, qr/Unrecognised parameters for Term::Fabulous::Theme constructor: 'colour'/, 'unknown parameter';
	like dies { $Theme->default->look_table( 'button', 'primary' ) }, qr/classes must be an array reference, got 'primary'/, 'classes not an array';
	like dies { $Theme->default->look_table('lamp') },                qr/unknown family 'lamp'/,                             'look_table of an unknown family';
};

subtest 'the generation' => sub {
	my $before = Term::Fabulous::Theme::generation();
	is Term::Fabulous::Theme::bump_generation(), $before + 1, 'bump_generation returns the new generation';
	is Term::Fabulous::Theme::generation(),      $before + 1, 'and generation reports it';
};

done_testing;
