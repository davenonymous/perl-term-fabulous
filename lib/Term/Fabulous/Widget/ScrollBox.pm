package Term::Fabulous::Widget::ScrollBox;

use v5.22;
use warnings;

use Object::Pad 0.825;

use Clay::UI::Role::Layout::HasScroll;
use Term::Fabulous::Widget::Box;

our $VERSION = '0.01';

class Term::Fabulous::Widget::ScrollBox
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Layout::HasScroll)
	:strict(params)
{
	method layout_properties :override () {
		return ( $self->SUPER::layout_properties, qw(horizontal vertical) );
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Widget::ScrollBox - Box whose content scrolls

=head1 SYNOPSIS

	use Term::Fabulous::Widget::ScrollBox;
	use Clay::XS qw(sizing_grow sizing_fixed CLAY_TOP_TO_BOTTOM);

	my $log = Term::Fabulous::Widget::ScrollBox->new(
		id     => 'log',
		layout => {
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_grow(), height => sizing_fixed(10) },
		},
		border_width => 1,
		border_style => Term::Fabulous::Enum::BorderStyle->Round,
	);
	$log->add_child($_) foreach @lines;

=head1 DESCRIPTION

A L<Term::Fabulous::Widget::Box> that composes
L<Clay::UI::Role::Layout::HasScroll>: content larger than the box is
clipped to it and scrolls. The C<id> constructor parameter is required,
because Clay keeps the scroll position by element id.

Under L<Term::Fabulous>, the mouse wheel scrolls the scroll box under
the pointer by three rows per notch. The box receives
L<Clay::UI::Events::OnScroll> when its position changes. Scrolled
content is clipped to the whole box, so it passes under the border,
which is drawn over it.

C<horizontal> (default 0) and C<vertical> (default 1) choose the axes
that scroll; see L<Clay::UI::Role::Layout::HasScroll> for them and for
C<child_offset>. Unknown constructor parameters die.

=head1 KDL PROPERTIES

The L<Term::Fabulous::Widget::Box/KDL PROPERTIES> plus C<horizontal>
and C<vertical> (C<#true> / C<#false>). The node needs an id argument:

	ScrollBox "log" {
		sizing width=grow height="fixed(10)"
		vertical #true
	}

=cut
