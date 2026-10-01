use v5.22;
use warnings;

use Test2::V0;

use Clay::XS qw(sizing_fixed sizing_grow);
use Termbox 2 qw(TB_EVENT_KEY TB_EVENT_MOUSE TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RELEASE);
use Term::Fabulous;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::Button;
use Term::Fabulous::Widget::Text;

{
	no warnings 'redefine';
	*Term::Fabulous::Render::Target::Termbox::tb_clear            = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_present          = sub {return};
	*Term::Fabulous::Render::Target::Termbox::tb_print = sub {0};
}

my $root = Term::Fabulous::Widget::Box->new(
	background_color => [ 1, 1, 1, 255 ],
	layout           => { sizing => { width => sizing_grow(), height => sizing_grow() } },
);
my $button = Term::Fabulous::Widget::Button->new(
	background_color => [ 2, 2, 2, 255 ],
	layout           => { sizing => { width => sizing_fixed(4), height => sizing_fixed(2) } },
);
$root->add_child($button);

my $ui = Term::Fabulous->new( width => 20, height => 5, root => $root );

# Handlers on the root see every event through bubbling; record the widget
# each event was fired on.
my %targets;
foreach my $name (qw(KeyPress Mouse OnPress)) {
	$root->on( $name => sub { push @{ $targets{$name} }, $_[0]->target; return } );
}

sub dispatch {
	my (%fields) = @_;
	$ui->_dispatch_termbox_event( Termbox::Event->new(%fields) );
	return;
}

subtest 'KeyPress targets the focused widget' => sub {
	%targets = ();
	dispatch( type => TB_EVENT_KEY, ch => ord 'a' );
	ref_is $targets{KeyPress}[0], $root, 'nothing focused: the root';

	$ui->interaction->set_focused_widget($button);
	dispatch( type => TB_EVENT_KEY, ch => ord 'a' );
	ref_is $targets{KeyPress}[1], $button, 'the focused button';
	$ui->interaction->set_focused_widget(undef);
};

subtest 'Mouse targets the widget under the pointer' => sub {
	$ui->draw;
	%targets = ();
	dispatch( type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_LEFT, x => 1, y => 1 );
	ref_is $targets{Mouse}[0], $button, 'inside the button';
	is $ui->pointer_state, { x => 1, y => 1, down => 1 }, 'left press sets the pointer down';

	$ui->draw;
	ref_is $targets{OnPress}[0], $button, 'draw hands the pointer to Clay: the button is pressed';

	dispatch( type => TB_EVENT_MOUSE, key => TB_KEY_MOUSE_RELEASE, x => 10, y => 3 );
	ref_is $targets{Mouse}[1], $root, 'outside the button: the root';
	is $ui->pointer_state->{down}, 0, 'release clears the pointer';
};

subtest 'root must be an event emitter' => sub {
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Text->new ) },
		qr/root must consume Clay::UI::Role::Events::Emitter/, 'a Text root is rejected';
	like dies { Term::Fabulous->new( width => 20, height => 5, root => Term::Fabulous::Widget::Box->new, use_termbox => 1 ) },
		qr/Unrecognised parameters.*use_termbox/, 'unknown constructor parameters are rejected';
};

done_testing;
