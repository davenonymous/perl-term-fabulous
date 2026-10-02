use v5.22;
use warnings;
use utf8;

use Test2::V0;

use FindBin;
use lib "$FindBin::Bin/lib";

use Clay::UI::Events::OnRelease;
use InputTest;
use Term::Fabulous::Widget::Checkbox;

subtest 'painting and size' => sub {
	my $box = Term::Fabulous::Widget::Checkbox->new( label => 'Accept' );
	my $ui  = layout_ui($box);
	is [ $box->columns, $box->rows ], [ 10, 1 ], 'the mark, a space and the label';
	is row_text( $box, 0 ), '[ ] Accept', 'unchecked';

	$box->checked(1);
	is row_text( $box, 0 ), '[x] Accept', 'checked';
	is $box->cell( 1, 0 )->[1], $box->color_attr( $box->accent_color ), 'the checked mark has the accent color';
	$box->indeterminate(1);
	is row_text( $box, 0 ), '[-] Accept', 'indeterminate';

	my $wide = Term::Fabulous::Widget::Checkbox->new( label => 'Go', checked_mark => '[yes]', unchecked_mark => '[]', checked => 'yes' );
	layout_ui($wide);
	is [ $wide->checked, row_text( $wide, 0 ) ], [ 1, '[yes] Go' ], 'checked is stored as 1; the label follows the widest mark';
	$wide->checked(0);
	is row_text( $wide, 0 ), '[]    Go', 'the label stays in place with a narrower mark';
};

subtest 'Space, Enter and clicks toggle' => sub {
	my $box = Term::Fabulous::Widget::Checkbox->new( label => 'x', indeterminate => 1 );
	my $ui  = layout_ui($box);
	my @changes;
	$box->on( Change => sub { push @changes, $_[0]->value; return } );

	press( $box, 'Space' );
	is [ $box->checked, $box->indeterminate ], [ 1, 0 ], 'an indeterminate box becomes checked';
	press( $box, 'Enter' );
	$box->fire_event( Clay::UI::Events::OnRelease->new );
	is \@changes, [ 1, 0, 1 ], 'every toggle fires Change';

	$box->checked(0);
	is scalar @changes, 3, 'setting checked fires nothing';
	$box->disabled(1);
	press( $box, 'Space' );
	$box->fire_event( Clay::UI::Events::OnRelease->new );
	is $box->checked, 0, 'a disabled box ignores keys and clicks';
};

subtest 'invalid parameters die' => sub {
	like dies { Term::Fabulous::Widget::Checkbox->new( label => [] ) },          qr/label must be a string/, 'a non-string label';
	like dies { Term::Fabulous::Widget::Checkbox->new( text_color => 'nope' ) }, qr/unrecognized color/,     'an invalid color';
	like dies { Term::Fabulous::Widget::Checkbox->new( checkd => 1 ) },          qr/Unrecognised parameters/, 'an unknown parameter';
};

done_testing;
