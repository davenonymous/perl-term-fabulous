#!/usr/bin/env perl

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Enum::Result;
use Clay::XS qw(sizing_grow);
use Term::Fabulous;
use Term::Fabulous::Document;
use Term::Fabulous::Document::Block::Heading;
use Term::Fabulous::Document::Block::Paragraph;
use Term::Fabulous::Document::Look;
use Term::Fabulous::Document::Mark;
use Term::Fabulous::Widget::DocumentView;

# The styles of the view: two built-in kinds changed, three kinds added.
# Colors are palette tokens of the theme, so the styles follow a theme
# switch.
class My::ManualLook :isa(Term::Fabulous::Document::Look) {

	method recipes :common () {
		return (
			$class->SUPER::recipes,
			heading1  => { words => 'bold', color => 'success' },
			code      => { color => 'accent' },
			key       => { words => 'bold', color => 'text_bright', background => 'surface_raised' },
			underline => { words => 'underline' },
			highlight => { color => 'text_inverse', background => 'warning' },
		);
	}
}

# A view that draws with that look. It accepts documents with marks of
# the new kinds, which the built-in view refuses.
class My::ManualView :isa(Term::Fabulous::Widget::DocumentView) {

	method look_class :common () {
		return 'My::ManualLook';
	}
}

# A piece is a plain string or [ KIND => 'text' ].
sub paragraph (@pieces) {
	my ( $text, @marks ) = ('');
	foreach my $piece (@pieces) {
		my ( $kind, $words ) = ref $piece ? @$piece : ( undef, $piece );
		my $start = length $text;
		$text .= $words;
		push @marks, Term::Fabulous::Document::Mark->new( start => $start, end => length $text, kind => $kind ) if defined $kind;
	}
	return Term::Fabulous::Document::Block::Paragraph->new( text => $text, marks => \@marks );
}

my $document = Term::Fabulous::Document->new(
	blocks => [
		Term::Fabulous::Document::Block::Heading->new( level => 1, text => 'Keys of the editor' ),
		paragraph( 'Press ', [ key => 'Ctrl+S' ], ' to save the file and ',  [ key => 'Ctrl+Q' ], ' to quit. Unsaved changes are ', [ underline => 'never' ], ' lost: the editor asks first.' ),
		paragraph( 'The settings live in ', [ code => '~/.editorrc' ], '. ', [ highlight => 'New in version 3:' ], ' ', [ key => 'F2' ], ' switches between the dark and the light theme.' ),
		Term::Fabulous::Document::Block::Heading->new( level => 2, text => 'Moving around' ),
		paragraph( [ key => 'Home' ], ' and ', [ key => 'End' ], ' go to the start and the end of a line, ', [ bold => 'Ctrl' ], ' with them to the start and the end of the file.' ),
	],
);

my $view = My::ManualView->new(
	id       => 'manual',
	document => $document,
	indent   => 4,
	layout   => { sizing => { width => sizing_grow(), height => sizing_grow() }, padding => { left => 1, right => 1, top => 1 } },
);

my $ui = Term::Fabulous->new( root => $view, width => 80, height => 24 );

$view->on(
	KeyPress => sub ($event) {
		return Clay::UI::Enum::Result->CONTINUE unless ( $event->key_name // '' ) eq 'F2';
		$ui->theme( $ui->theme->name eq 'dark' ? 'light' : 'dark' );
		return;
	}
);

$ui->interaction->set_focused_widget($view);
$ui->run;
