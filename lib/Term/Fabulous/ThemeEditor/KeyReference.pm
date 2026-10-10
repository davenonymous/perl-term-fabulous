package Term::Fabulous::ThemeEditor::KeyReference;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Dialog;

# The key reference of the theme editor: every key and what it does,
# grouped by where it works, with a search field.
class Term::Fabulous::ThemeEditor::KeyReference :isa(Term::Fabulous::Widget::Dialog) :strict(params) {
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM);
	use List::Util qw(max);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Table;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Widget::TextField;

	use constant TABLE_ID => 'theme-editor-keys';

	field $keys   :param;    # [ [ context, keys, action ] ]
	field $height :param = 30;
	field $width  :param = 78;

	field $search :reader;
	field $table  :reader;

	ADJUST {
		$self->layout(
			{
				layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed( max( 60, $width ) ), height => sizing_fixed( max( 12, $height ) ) },
				padding          => { left => 2, right => 2, top => 1, bottom => 1 }, child_gap => 1
			}
		);
		$self->add_child( Term::Fabulous::Widget::Text->new( text => 'Keys of the theme editor', bold => 1 ) );
		$search = Term::Fabulous::Widget::TextField->new( placeholder => 'Search keys and actions', layout => { sizing => { width => sizing_grow() } } );

		# Groups are ordered by their value: the value starts with the rank of
		# the context, which the label leaves out.
		my ( $number, $contexts, %rank ) = ( 0, 0 );
		foreach my $entry (@$keys) {
			$rank{ $entry->[0] } = sprintf( '%02d', $contexts++ ) unless exists $rank{ $entry->[0] };
		}
		$table = Term::Fabulous::Widget::Table->new(
			id           => TABLE_ID,
			row_id       => 'id',
			group_by     => 'context',
			group_label  => sub ($group) { return $group->{value} =~ s/\A\d+ //r },
			sort         => [ [ order => 'asc' ] ],
			border       => 'none',
			column_lines => 'none',
			header_line  => 'Solid',
			columns      => [
				{ key => 'order',   title => '',       type    => 'number', visible => 0 },
				{ key => 'context', title => 'Where',  visible => 0 },
				{ key => 'keys',    title => 'Keys',   width   => 'fit(0, 26)', sortable => 0 },
				{ key => 'action',  title => 'Action', width   => 'grow',       sortable => 0 },
			],
			rows   => [ map { { id => ++$number, order => $number, context => "$rank{ $_->[0] } $_->[0]", keys => $_->[1], action => $_->[2] } } @$keys ],
			layout => { sizing => { width => sizing_grow(), height => sizing_grow() } },
		);
		weaken( my $weak_table = $table );
		$search->on( Change => sub ($event) { $weak_table->search( $event->value ); return Clay::UI::Enum::Result->CONTINUE } );

		my $close = Term::Fabulous::Widget::Button->new( bordered => 1, classes => ['primary'], layout => { padding => { left => 1, right => 1 } } );
		$close->add_child( Term::Fabulous::Widget::Text->new( text => 'Close' ) );
		weaken( my $weak_self = $self );
		$close->on( Activate => sub ($event) { $weak_self->close; return } );
		$self->add_child( $search, $table, $close );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::KeyReference - The key reference of the
theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. A L<Term::Fabulous::Widget::Dialog> with every key of the editor
and what it does, in a table grouped by where the key works, and a
search field that filters the table by any text in it. C<Escape> or
C<Close> closes it.

=head1 CONSTRUCTOR

=head2 new

	Term::Fabulous::ThemeEditor::KeyReference->new(
		keys   => [ [ 'Everywhere', 'Ctrl+S', 'Save the theme' ], ... ],
		height => $ui->height - 4,
		width  => $ui->width - 4,
	)->open($ui);

The keys are given as C<[ where, keys, action ]>, in the order they
are listed; C<height> and C<width> are the dialog's size (at least 12
rows and 60 columns; default 30 by 78).

=head1 METHODS

=head2 search, table

The search field and the table.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
