package Term::Fabulous::Lite::Params;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.03';

use Exporter 'import';
our @EXPORT_OK = qw(split_arguments widget_params);

use Object::Pad::MOP::Class qw( :experimental(mop) );
use Scalar::Util qw(blessed);
use Term::Fabulous::Check qw(align_x align_y border_style boolean describe direction line_sizing non_negative_integer one_of sizing);

use constant OWNER => 'Term::Fabulous::Lite';

my $WIDGET_ROLE = 'Clay::UI::Role::Layout::HasParent';

# The widgets among the arguments of a helper are its children, in
# order; the rest is the option list. With a main parameter, an option
# list of odd length starts with the main value. Returns the main value
# (or undef), the options and the children.
sub split_arguments ( $what, $main_parameter, @arguments ) {
	my ( @children, @rest );
	push @{ blessed $_ && $_->DOES($WIDGET_ROLE) ? \@children : \@rest }, $_ foreach @arguments;

	my $main = @rest % 2 ? shift @rest : undef;
	die OWNER . ": $what takes key => value options, got an odd number of them starting with " . describe($main) . " ($what has no main value)"
		if defined $main && !defined $main_parameter;
	my %options = @rest;
	die OWNER . ": $what options need string keys, got " . describe( ( grep { !defined || ref } keys %options )[0] ) if grep { !defined || ref } keys %options;
	return ( $main, \%options, \@children );
}

# Each Lite option: the full parameter it stands for, as a path into the
# parameters of new (a key, or a key and the keys below it), and how
# its value is parsed. A Lite option given together with its full form
# dies, so a program never says the same thing twice.
my %LITE_OPTION = (
	width       => { path => [qw(layout sizing width)],     parse => sub ( $what, $value ) { sizing( OWNER, "$what width",  $value ) } },
	height      => { path => [qw(layout sizing height)],    parse => sub ( $what, $value ) { sizing( OWNER, "$what height", $value ) } },
	direction   => { path => [qw(layout layout_direction)], parse => sub ( $what, $value ) { direction( OWNER, "$what direction", $value ) } },
	gap         => { path => [qw(layout child_gap)],        parse => sub ( $what, $value ) { non_negative_integer( OWNER, "$what gap",      $value ) } },
	line_gap    => { path => [qw(layout line_gap)],         parse => sub ( $what, $value ) { non_negative_integer( OWNER, "$what line_gap", $value ) } },
	line_sizing => { path => [qw(layout line_sizing)],      parse => sub ( $what, $value ) { line_sizing( OWNER, "$what line_sizing", $value ) } },
	padding     => { path => [qw(layout padding)],          parse => \&_padding },
	align       => { path => [qw(layout child_alignment)],  parse => \&_alignment },
	bg          => { path => ['background_color'],          parse => sub ( $what, $value ) { $value } },
	fg          => { path => ['text_color'],                parse => sub ( $what, $value ) { $value } },
	columns     => { path => ['preferred_columns'],         parse => sub ( $what, $value ) { $value } },
);

my @SIDES = qw(top right bottom left);

# N for every side, [ vertical, horizontal ], [ top, right, bottom, left ]
# or a hash of sides.
sub _padding ( $what, $value ) {
	my $name = "$what padding";
	if ( ref $value eq 'ARRAY' ) {
		my @cells = map { non_negative_integer( OWNER, $name, $_ ) } @$value;
		return { top => $cells[0], bottom => $cells[0], left   => $cells[1], right => $cells[1] } if @cells == 2;
		return { top => $cells[0], right  => $cells[1], bottom => $cells[2], left  => $cells[3] } if @cells == 4;
		die OWNER . ": $name as an array takes [ vertical, horizontal ] or [ top, right, bottom, left ], got " . scalar(@cells) . ' values';
	}
	if ( ref $value eq 'HASH' ) {
		one_of( OWNER, "$name side", $_, @SIDES ) foreach sort keys %$value;
		return { map { $_ => non_negative_integer( OWNER, "$name $_", $value->{$_} ) } keys %$value };
	}
	my $cells = non_negative_integer( OWNER, $name, $value );
	return { map { $_ => $cells } @SIDES };
}

my %ALIGNMENT_AXIS = ( left => 'x', right => 'x', top => 'y', bottom => 'y' );

# center (both axes), a name of one axis, [ x, y ] or { x =>, y => }.
sub _alignment ( $what, $value ) {
	my $name          = "$what align";
	my %check_by_axis = ( x => \&align_x, y => \&align_y );
	if ( ref $value eq 'ARRAY' ) {
		die OWNER . ": $name as an array takes [ x, y ], got " . scalar(@$value) . ' values' unless @$value == 2;
		return { x => align_x( OWNER, "$name x", $value->[0] ), y => align_y( OWNER, "$name y", $value->[1] ) };
	}
	if ( ref $value eq 'HASH' ) {
		one_of( OWNER, "$name axis", $_, qw(x y) ) foreach sort keys %$value;
		return { map { $_ => $check_by_axis{$_}->( OWNER, "$name $_", $value->{$_} ) } keys %$value };
	}
	return { x => align_x( OWNER, "$name x", 'center' ), y => align_y( OWNER, "$name y", 'center' ) } if ( $value // '' ) eq 'center';
	my $axis = $ALIGNMENT_AXIS{ $value // '' } // one_of( OWNER, $name, $value, 'center', keys %ALIGNMENT_AXIS );
	return { $axis => $check_by_axis{$axis}->( OWNER, "$name $axis", $value ) };
}

# A border: a boolean, a style name (the border on every side), or a
# hash of sides with an optional style. Returns the bordered and
# border_style parameters.
sub _border ( $what, $value ) {
	my $name = "$what border";
	return ( bordered => boolean( OWNER, $name, $value ) ) if !defined $value || !length $value || $value =~ /\A[01]\z/;
	return ( bordered => 1, border_style => border_style( OWNER, $name, $value ) ) unless ref $value;
	die OWNER . ": $name must be a boolean, a border style name or a hash of sides, got " . describe($value) unless ref $value eq 'HASH';

	my %sides = %$value;
	my $style = delete $sides{style};
	one_of( OWNER, "$name side", $_, @SIDES ) foreach sort keys %sides;
	return ( bordered => { map { $_ => boolean( OWNER, "$name $_", $sides{$_} ) } keys %sides }, defined $style ? ( border_style => border_style( OWNER, "$name style", $style ) ) : () );
}

sub _listeners ( $what, $value ) {
	die OWNER . ": $what on must be a hash of event name => code reference, got " . describe($value) unless ref $value eq 'HASH';
	foreach my $event ( sort keys %$value ) {
		die OWNER . ": $what on $event must be a code reference, got " . describe( $value->{$event} ) unless ref $value->{$event} eq 'CODE';
	}
	return {%$value};
}

# The constructor parameters a class declares, with those of the
# classes and roles above it; a Table takes its frame as border and its
# column specs as columns, which the Lite options of those names must
# leave alone.
my %OWN_PARAMS_OF;

sub _is_own_param ( $module, $name ) {
	return $OWN_PARAMS_OF{$module}{$name} // 0 if exists $OWN_PARAMS_OF{$module};
	my %is_own;
	my @classes = ( Object::Pad::MOP::Class->for_class($module) );
	while ( my $meta = shift @classes ) {
		foreach my $field ( $meta->fields ) {
			next unless $field->has_attribute('param');
			my $param = $field->get_attribute_value('param');
			$param = $field->name =~ s/\A[\$\@%]//r unless defined $param && length $param;
			$is_own{$param} = 1;
		}
		push @classes, $meta->superclasses, $meta->direct_roles;
	}
	$OWN_PARAMS_OF{$module} = \%is_own;
	return $is_own{$name} // 0;
}

sub _has_path ( $params, @path ) {
	my $node = $params;
	foreach my $key (@path) {
		return 0 unless ref $node eq 'HASH' && exists $node->{$key};
		$node = $node->{$key};
	}
	return 1;
}

# Stores the value at the path, copying the hashes on the way so the
# caller's layout hash stays untouched.
sub _store ( $params, $value, @path ) {
	my $last = pop @path;
	my $node = $params;
	foreach my $key (@path) {
		$node->{$key} = { %{ $node->{$key} // {} } };
		$node = $node->{$key};
	}
	$node->{$last} = $value;
	return;
}

my $LAYOUT_ROLE = 'Clay::UI::Role::Layout::HasLayout';

# The parameters of new for the options of a helper, and the listeners
# its on option names: every Lite option is translated, everything else
# passes through. A layout option on a widget without a layout (a
# Text) dies here, with a hint instead of the widget's complaint
# about an unknown parameter.
sub widget_params ( $what, $module, $options ) {
	my %params    = %$options;
	my $listeners = {};

	my @layout_options = sort grep { exists $params{$_} && $LITE_OPTION{$_}{path}[0] eq 'layout' } keys %LITE_OPTION;
	die OWNER . ": $what has no layout, so " . join( ', ', @layout_options ) . " cannot apply ($module takes no layout; a Text is as wide as its text, put it in a box to size it)"
		if @layout_options && !$module->DOES($LAYOUT_ROLE);

	if ( exists $params{on} ) {
		$listeners = _listeners( $what, delete $params{on} );
	}
	if ( exists $params{border} && !_is_own_param( $module, 'border' ) ) {
		my $value = delete $params{border};
		die OWNER . ": $what has both border and " . join( ', ', grep { exists $params{$_} } qw(bordered border_style) ) . '; give one of them'
			if exists $params{bordered} || exists $params{border_style};
		%params = ( %params, _border( $what, $value ) );
	}
	foreach my $option ( sort grep { exists $LITE_OPTION{$_} && !_is_own_param( $module, $_ ) } keys %params ) {
		my $spec  = $LITE_OPTION{$option};
		my $value = delete $params{$option};
		die OWNER . ": $what has both $option and " . join( '.', @{ $spec->{path} } ) . '; give one of them' if _has_path( \%params, @{ $spec->{path} } );
		_store( \%params, $spec->{parse}->( $what, $value ), @{ $spec->{path} } );
	}
	return ( \%params, $listeners );
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Lite::Params - the option vocabulary of Term::Fabulous::Lite

=head1 SYNOPSIS

	use Term::Fabulous::Lite::Params qw(split_arguments widget_params);

	my ( $main, $options, $children ) = split_arguments( text => 'text', 'Hello', bold => 1 );
	my ( $params, $listeners ) = widget_params( box => 'Term::Fabulous::Widget::Box', { width => 'grow', gap => 1, on => { Activate => sub { ... } } } );

=head1 DESCRIPTION

The functions behind L<Term::Fabulous::Lite>: they split the arguments
of a helper into the main value, the options and the children, and
translate the Lite options into the parameters of a widget's C<new>.
Used internally; the vocabulary is documented in
L<Term::Fabulous::Lite/THE OPTIONS>.

=head1 FUNCTIONS

=head2 split_arguments

	my ( $main, $options, $children ) = split_arguments( $what, $main_parameter, @arguments );

Every argument that is a widget (anything that consumes
C<Clay::UI::Role::Layout::HasParent>) is a child; the rest is the
option list. With a C<$main_parameter>, an option list of odd length
starts with the main value, which is returned first; without one, an
odd list dies. C<$what> names the helper in the messages.

=head2 widget_params

	my ( $params, $listeners ) = widget_params( $what, $module, \%options );

Returns the parameters for the C<new> of the widget class C<$module>
and the hash of the C<on> option. The Lite options C<width>, C<height>, C<direction>,
C<gap>, C<line_gap>, C<line_sizing>, C<padding>, C<align>, C<border>,
C<bg>, C<fg> and C<columns> are translated as
L<Term::Fabulous::Lite/THE OPTIONS> says; the others pass through
unchanged. A Lite option given together with the full parameter it
stands for dies, and so does a layout option (C<width>, C<height>,
C<direction>, C<gap>, C<line_gap>, C<line_sizing>, C<padding>,
C<align>) for a class without a layout, such as
L<Term::Fabulous::Widget::Text>. A Lite option that is also a
constructor parameter of the class (C<border> and C<columns> of a
L<Term::Fabulous::Widget::Table>) passes through untouched.

=head1 SEE ALSO

L<Term::Fabulous::Lite>, L<Term::Fabulous::Check>.

=cut
