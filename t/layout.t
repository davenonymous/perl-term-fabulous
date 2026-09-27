use v5.22;
use warnings;
use utf8;

use Test2::V0;

use Encode qw(encode);
use Term::Fabulous::Layout;

sub layout {
	my ($kdl) = @_;
	return Term::Fabulous::Layout->new( string => $kdl );
}

sub build {
	my ($kdl) = @_;
	return layout($kdl)->build;
}

subtest 'widget classes load on their own' => sub {
	my $code = <<'PERL';
use Term::Fabulous::Layout;
my $root = Term::Fabulous::Layout->new( string => <<'KDL' )->build;
use Term::Fabulous::Widget::Box as Box
Box "root" {
	border style=Round color="#ffffff"
	background_color "rgb(1, 2, 3)"
}
KDL
die "Term::Fabulous was loaded\n" if exists $INC{'Term/Fabulous.pm'};
print ref($root), "\n";
PERL
	open my $child, '-|', $^X, ( map {"-I$_"} @INC ), '-e', $code or die "cannot run $^X: $!";
	my $output = do { local $/; <$child> };
	ok close($child), 'child process succeeded';
	is $output, "Term::Fabulous::Widget::Box\n", 'a Box builds with only Term::Fabulous::Layout loaded';
};

subtest 'use instructions' => sub {
	foreach my $module ( '../../tmp/x', '/abs/path', 'Foo/Bar', 'Foo::Bar.pm', 'Foo::', '::Foo' ) {
		like dies { layout(qq{use "$module" as Box\nBox}) }, qr/invalid module name '\Q$module\E'/, "path-like module '$module' is rejected";
	}
	like dies { layout("use Term::Fabulous::Widget::Box as box\nbox") }, qr/invalid widget alias 'box'/, 'lowercase alias is rejected';
	like dies { layout("use Term::Fabulous::Widget::Box as Box\nuse Term::Fabulous::Widget::Text as Box\nBox") },
		qr/alias 'Box' is declared twice/, 'duplicate alias is rejected';
	like dies { layout("use Term::Fabulous::Widget::Box Box\nBox") }, qr/invalid 'use' instruction/, 'malformed use is rejected';
	like dies { layout("use Term::Fabulous::Color as Color\nColor") },
		qr/'Term::Fabulous::Color' \(widget alias 'Color'\) does not compose Term::Fabulous::Role::CanParseLayout/,
		'a class without CanParseLayout is rejected';
};

subtest 'document structure' => sub {
	like dies { layout("use Term::Fabulous::Widget::Box as Box\nBox\nstray 1") }, qr/unexpected top-level node 'stray'/, 'stray top-level node';
	like dies { layout("use Term::Fabulous::Widget::Box as Box\nBox\nBox") }, qr/multiple root widgets/, 'two roots';
	like dies { build("use Term::Fabulous::Widget::Box as Box\nBox {\n\tButton\n}") }, qr/unknown widget 'Button'/, 'undeclared child widget';
	like dies { build(qq{use Term::Fabulous::Widget::Box as Box\nBox "a" "b"}) }, qr/at most one argument, a string id/, 'two ids';
};

subtest 'properties' => sub {
	my $box = "use Term::Fabulous::Widget::Box as Box\nBox {\n%s\n}";
	like dies { build( sprintf $box, 'backgroud_color "#000000"' ) }, qr/unknown layout property 'backgroud_color'/, 'misspelled property dies';
	like dies { build( sprintf $box, 'clear_children' ) }, qr/unknown layout property 'clear_children'/, 'method names cannot be called';
	like dies { build( sprintf $box, 'layout gap=1 child_gap=2' ) }, qr/not both/, 'gap and child_gap together';
	like dies { build( sprintf $box, 'padding 1' ) }, qr/takes key=value properties only/, 'padding needs properties';
	like dies { build( sprintf $box, 'padding middle=1' ) }, qr/does not accept middle/, 'unknown padding key';
	like dies { build( sprintf $box, 'sizing width="percent(150)"' ) }, qr/percentage must be in 0\.\.100/, 'percent above 100';

	my $root = build( sprintf $box, qq{sizing width="percent(50)" height="fixed(3)"\nborder_width left=1 top=2\nlayout direction=down gap=0} );
	is $root->layout->{sizing}{width}{percent}, 0.5, 'percent(50) becomes 0.5';
	is $root->layout->{sizing}{height}{min},    3,   'fixed(3)';
	is $root->layout->{child_gap},              0,   'gap 0 is kept';
	is $root->border_width, { left => 1, top => 2 }, 'properties form a hash';
};

subtest 'text' => sub {
	my $root = build( <<'KDL' );
use Term::Fabulous::Widget::Box as Box
use Term::Fabulous::Widget::Text as Text
Box "root" {
	Text "greeting" {
		text "Grüße 🎉"
		text_color "rgba(1, 2, 3, 1.0)"
	}
}
KDL
	my ($text) = $root->children->@*;
	is $text->id, 'greeting', 'Text keeps its id';
	is $text->text, encode( 'UTF-8', "Grüße 🎉" ), 'text is stored as UTF-8 bytes';
	ok !utf8::is_utf8( $text->text ), 'text is a byte string';
	is $text->text_color, [ 1, 2, 3, 255 ], 'text_color';

	like dies { build("use Term::Fabulous::Widget::Text as Text\nText {\n\ttext\n}") },   qr/'text' needs exactly one argument/, 'text without argument';
	like dies { build("use Term::Fabulous::Widget::Text as Text\nText {\n\ttext 5\n}") }, qr/'text' needs a string argument/,     'text with a number';
};

done_testing;
