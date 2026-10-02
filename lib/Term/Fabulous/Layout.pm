package Term::Fabulous::Layout;

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

class Term::Fabulous::Layout :strict(params) {
	use Encode qw(encode);
	use Feature::Compat::Try;
	use Text::KDL::XS qw(parse_kdl);

	my $MODULE_NAME = qr/\A[A-Za-z_]\w*(?:::\w+)*\z/a;
	my $ALIAS       = qr/\A[A-Z]\w*\z/a;
	my $LAYOUT_ROLE = 'Term::Fabulous::Role::CanParseLayout';

	field $raw :reader;
	field $root_widget :reader;
	field $required_modules :reader = {};
	field $_root_node;

	ADJUST :params ( :$string = undef, :$file = undef ) {
		die "Term::Fabulous::Layout: provide either 'string' or 'file'" if !defined $string && !defined $file;
		die "Term::Fabulous::Layout: provide 'string' or 'file', not both" if defined $string && defined $file;

		my $source = defined $string ? encode( 'UTF-8', $string ) : _read_file($file);
		try {
			$raw = parse_kdl($source);
		}
		catch ($error) {
			die "Term::Fabulous::Layout: failed to parse KDL: $error";
		}

		$required_modules = _use_instructions($raw);
		_load_widget_class( $_, $required_modules->{$_} ) foreach sort keys %$required_modules;
		$_root_node = _root_node( $raw, $required_modules );
	}

	sub _read_file ($path) {
		open my $handle, '<:raw', $path or die "Term::Fabulous::Layout: cannot open '$path': $!";
		local $/;
		my $content = <$handle>;
		close $handle;
		return $content;
	}

	# Maps every alias declared by a top-level 'use' node to its module.
	sub _use_instructions ($document) {
		my %module_by_alias;
		foreach my $node ( $document->nodes->@* ) {
			next unless $node->name eq 'use';
			my ( $alias, $module ) = _parse_use($node);
			die "Term::Fabulous::Layout: widget alias '$alias' is declared twice" if exists $module_by_alias{$alias};
			$module_by_alias{$alias} = $module;
		}
		return \%module_by_alias;
	}

	sub _parse_use ($node) {
		my @args = map { $_->is_string ? $_->value : undef } $node->args->@*;
		my $well_formed = !$node->props->@* && !$node->children->@* && !grep { !defined } @args;

		if ( $well_formed && @args == 1 ) {
			my ($module) = @args;
			_check_module_name($module);
			die "Term::Fabulous::Layout: 'use $module' without 'as' needs a module name starting with an uppercase letter, because the name is also the widget node name"
				unless $module =~ /\A[A-Z]/;
			return ( $module, $module );
		}
		if ( $well_formed && @args == 3 && $args[1] eq 'as' ) {
			my ( $module, undef, $alias ) = @args;
			_check_module_name($module);
			die "Term::Fabulous::Layout: invalid widget alias '$alias'; it must start with an uppercase letter and contain only letters, digits and '_'"
				unless $alias =~ $ALIAS;
			return ( $alias, $module );
		}
		die "Term::Fabulous::Layout: invalid 'use' instruction; expected 'use Module::Name' or 'use Module::Name as Alias'";
	}

	sub _check_module_name ($module) {
		die "Term::Fabulous::Layout: invalid module name '$module' in 'use'" unless $module =~ $MODULE_NAME;
		return;
	}

	sub _load_widget_class ( $alias, $module ) {
		( my $path = "$module.pm" ) =~ s{::}{/}g;
		try {
			require $path;
		}
		catch ($error) {
			die "Term::Fabulous::Layout: cannot load '$module' for widget alias '$alias': $error";
		}
		die "Term::Fabulous::Layout: '$module' (widget alias '$alias') does not compose $LAYOUT_ROLE, so it cannot be built from a layout"
			unless $module->DOES($LAYOUT_ROLE);
		return;
	}

	sub _root_node ( $document, $module_by_alias ) {
		my @widget_nodes;
		foreach my $node ( $document->nodes->@* ) {
			my $name = $node->name;
			next if $name eq 'use';
			die "Term::Fabulous::Layout: unexpected top-level node '$name'; only 'use' instructions and one root widget are allowed"
				unless exists $module_by_alias->{$name};
			push @widget_nodes, $node;
		}
		die "Term::Fabulous::Layout: no root widget found in the layout" unless @widget_nodes;
		die "Term::Fabulous::Layout: multiple root widgets found in the layout (" . join( ', ', map { $_->name } @widget_nodes ) . ")"
			if @widget_nodes > 1;
		return $widget_nodes[0];
	}

	sub _widget_id ($node) {
		my $name = $node->name;
		die "Term::Fabulous::Layout: widget '$name' does not accept key=value properties (got: " . join( ', ', map { $_->[0] } $node->props->@* ) . ")"
			if $node->props->@*;

		my @args = $node->args->@*;
		return undef unless @args;
		die "Term::Fabulous::Layout: widget '$name' takes at most one argument, a string id" unless @args == 1 && $args[0]->is_string;
		return $args[0]->value;
	}

	method _build_widget ($node) {
		my $name  = $node->name;
		my $class = $required_modules->{$name}
			// die "Term::Fabulous::Layout: unknown widget '$name'; declare it with 'use Module::Name as $name'";
		my $id = _widget_id($node);

		my $widget;
		try {
			$widget = $class->new( id => $id, kdl_node => $node );
		}
		catch ($error) {
			die "Term::Fabulous::Layout: cannot build widget '$name'" . ( defined $id ? " \"$id\"" : '' ) . ": $error";
		}

		foreach my $child ( $node->children->@* ) {
			next unless Term::Fabulous::Role::CanParseLayout::is_widget_node_name( $child->name );    # properties are parsed by the widget itself
			die "Term::Fabulous::Layout: widget '$name' cannot contain child widgets (found '" . $child->name . "')"
				unless $widget->can('add_child');
			$widget->add_child( $self->_build_widget($child) );
		}
		return $widget;
	}

	method build () {
		$root_widget //= $self->_build_widget($_root_node);
		return $root_widget;
	}

	method walk_nodes ($code) {
		my @nodes = ( $raw->nodes->@* );
		while (@nodes) {
			my $node = shift @nodes;
			$code->($node);
			push @nodes, $node->children->@* if $node->children;
		}
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::Layout - Build a widget tree from a KDL layout description

=head1 SYNOPSIS

	use Term::Fabulous;
	use Term::Fabulous::Layout;

	my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::Text as Text

	Box "root" {
		layout direction=down gap=1
		sizing width=grow height=grow
		padding left=1 right=1
		border style=Round color="rgb(20, 140, 56)"
		border_width 1
		background_color "#141937"

		Text "greeting" {
			text "Hello!"
			text_color "rgba(220, 34, 220, 1.0)"
		}
	}
	KDL

	my $root = $layout->build;
	Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;

	# Or read the layout from a file:
	my $from_file = Term::Fabulous::Layout->new( file => 'screens/main.kdl' );

=head1 DESCRIPTION

Instead of building a widget tree in Perl, you can describe it in a
layout file written in KDL, a small document language similar to
nested function calls (see L<https://kdl.dev>). Term::Fabulous::Layout
parses such a description with L<Text::KDL::XS>, loads the widget
classes it names and builds the widget tree. You then hand the root
widget to L<Term::Fabulous> or L<Term::Fabulous::Static> as usual, and
attach event listeners in Perl.

A layout file describes the static part of a user interface: which
widgets there are, how they are nested, sized, colored and bordered,
and the initial values of input widgets. Behavior (listeners, timers)
stays in Perl. Everything a layout can do, Perl can do as well; a few
options are available only in Perl (see L</LIMITATIONS>).

=head1 CONSTRUCTOR

=head2 new

	my $layout = Term::Fabulous::Layout->new( string => $kdl_text );
	my $layout = Term::Fabulous::Layout->new( file   => $path );

Parses the document, checks its C<use> instructions, loads the widget
classes and finds the root widget node. The widgets themselves are
built later, by L</build>. Every problem dies with a message that starts
with C<Term::Fabulous::Layout:> (see L</ERRORS>). Unknown parameters
die.

Give exactly one of these parameters; giving none or both dies.

=over

=item C<string>

The layout as a Perl character string (decoded text). A here-document
in a source file with C<use utf8> is such a string.

=item C<file>

The path of a layout file. The file is read as UTF-8 encoded bytes.
Dies if it cannot be opened.

=back

=head1 METHODS

=head2 build

	my $root = $layout->build;

Builds the widget tree and returns its root widget. The tree is built
only once: later calls return the same root widget. Since a widget can
be part of only one tree, build a new Term::Fabulous::Layout object if
you need a second copy of the same widgets.

Each widget is built with C<< $class->new( id => $id, kdl_node => $node ) >>
and parses its own property nodes (see
L<Term::Fabulous::Role::CanParseLayout>). Invalid properties die here,
not in L</new>.

=head2 root_widget

	my $root = $layout->root_widget;

The root widget built by L</build>, or C<undef> before the first call
of L</build>.

=head2 required_modules

	my %module_by_alias = %{ $layout->required_modules };    # ( Box => 'Term::Fabulous::Widget::Box', ... )

A hash reference that maps every widget name declared with C<use> to
its Perl module.

=head2 raw

	my $document = $layout->raw;

The parsed L<Text::KDL::XS::Document>, for programs that want to read
custom data from the layout file.

=head2 walk_nodes

	$layout->walk_nodes( sub ($node) {
		say $node->name;
	} );

Calls the code reference once for every node of the document
(L<Text::KDL::XS::Node> objects), including C<use> instructions and
property nodes, breadth first: all top-level nodes, then their
children, and so on.

=head1 THE KDL FORMAT

=head2 A short introduction to KDL

A KDL document is a list of nodes. A node has a name, followed by
optional arguments, optional C<key=value> properties and an optional
block of child nodes in braces:

	name argument1 argument2 key=value other="value" {
		child-node
		another-child 42
	}

Nodes end at a line break or a semicolon, so short nodes can share a
line: C<RadioButton { label "Small"; value "s"; }>.

Values are written like this:

	Value                          Example                Perl value
	-----------------------------  ---------------------  -----------------
	string in double quotes        "Hello, world"         'Hello, world'
	bare word                      grow, Round, down      'grow', ...
	integer or decimal number      40, 2.5, 0x1f          40, 2.5, 31
	boolean                        #true, #false          1, 0
	no value                       #null                  undef

Strings that contain spaces, parentheses, C<#>, C<=> or other special
characters must be quoted: C<"#141937">, C<"fixed(10)">,
C<"rgb(1, 2, 3)">. Boolean properties must be written C<#true> and
C<#false> (C<1> and C<0> are accepted too); any other value, such as
C<"no"> or C<"false"> in quotes, dies.

Comments are C<// to the end of the line>, C</* blocks */>, and C</->
in front of a node, which comments out the whole node with its
children:

	/- Text { text "not shown"; }

=head2 Top level: use instructions and one root widget

The top level of a layout contains C<use> instructions, which declare
the widget classes, and exactly one widget node, the root widget.
Nothing else is allowed at the top level.

	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::TextField as TextField
	use My::App::Widget::Clock as Clock

	Box "root" { ... }

C<use Module::Name as Alias> declares that nodes named C<Alias> build
C<Module::Name> widgets. C<Module::Name> must be a plain Perl package
name (letters, digits, C<_> and C<::>). C<Alias> must start with an
uppercase letter and contain only letters, digits and C<_>. Each alias
can be declared only once. The module is loaded with C<require> and
must compose L<Term::Fabulous::Role::CanParseLayout>, which all
Term::Fabulous widgets do; your own widgets can too (see
L<Term::Fabulous::Manual/WRITING YOUR OWN WIDGETS>).

The short form C<use Module::Name> uses the full module name as the
widget node name:

	use Term::Fabulous::Widget::Box

	Term::Fabulous::Widget::Box "root" { ... }

C<use> takes no C<key=value> properties and no children.

=head2 Widget nodes

	Alias "id" {
		property-node ...
		ChildAlias "child-id" { ... }
	}

A node whose name is a declared alias builds one widget. It takes at
most one argument, a string, which becomes the widget's C<id>, and no
C<key=value> properties. Inside its braces:

=over

=item *

Nodes whose names start with an B<uppercase> letter are child widgets.
Their names must be declared aliases, and only containers (widgets with
an C<add_child> method, such as Box, ScrollBox and RadioGroup) accept
children.

=item *

Every other node is a property of the widget, such as C<sizing> or
C<text>. They are listed per widget in L</PROPERTIES>; an unknown one
dies.

=back

Properties are applied in the order they appear, with the same checks
as the Perl method of the same name. When one value depends on another,
give it later: a dropdown's options before its C<value>, a slider's
C<min> and C<max> before its C<value>, a text field's C<max_length>
before its C<value>.

Ids are optional. They are used by Clay to keep track of widgets between
frames, they are required for a ScrollBox, and they are how you find
widgets after L</build> (see L</EXAMPLES>). Ids must be unique within
the tree. L</build> does not check this; the first frame drawn with
duplicate ids dies with
C<Clay error: An element with this ID was already previously declared during this layout.>

=head2 Kinds of property nodes

A property node has one of two shapes:

=over

=item *

One argument: C<text "Hello">, C<border_width 1>, C<checked #true>.

=item *

Only C<key=value> properties: C<padding left=1 right=1>,
C<border_width left=1 right=2>.

=back

A property node never has children. A property whose name ends in
C<_color> takes any color string L<Term::Fabulous::Color> understands
(C<"#61afef">, C<"rgb(97, 175, 239)">, C<"hsl(207, 82%, 66%)">, ...).

=head1 PROPERTIES

The property nodes each widget accepts, with the value they take. A
name in the form C<name> without further explanation sets the Perl
accessor of the same name; follow the link to the widget's
documentation for the meaning. An unknown property name dies with the
list of the names the widget knows.

=head2 Box properties

Accepted by L<Term::Fabulous::Widget::Box> and every widget built on it:
L<Button|Term::Fabulous::Widget::Button>,
L<ScrollBox|Term::Fabulous::Widget::ScrollBox>,
L<Canvas|Term::Fabulous::Widget::Canvas>,
L<PixelCanvas|Term::Fabulous::Widget::PixelCanvas>,
L<RadioGroup|Term::Fabulous::Widget::RadioGroup> and all input widgets.

	Property node                              Value
	-----------------------------------------  -----------------------------------------
	layout direction=... gap=N                 direction: down, ttb, top_to_bottom
	                                           (children top to bottom) or right, ltr,
	                                           left_to_right (left to right);
	                                           gap (alias child_gap): cells between
	                                           children, an integer >= 0
	sizing width=... height=...                each: grow, fit, "percent(N)" with N in
	                                           0..100 (decimals allowed), or "fixed(N)"
	                                           with N an integer >= 0
	padding left=N right=N top=N bottom=N      any subset; integers >= 0
	border style=... style-top=...             style: a border style name (Round, Solid,
	       style-right=... style-bottom=...    Heavy, ...) for all four sides; the
	       style-left=... color=...            style-SIDE keys override it for one side;
	                                           color: a color string
	border_width N                             all four sides, an integer 0..65535
	border_width left=N right=N top=N bottom=N per side; missing sides are 0
	background_color "..."                     a color string
	glyphs_show_through #true                  #true or #false (the default): whether text
	                                           and borders below a translucent background
	                                           stay visible (see Term::Fabulous::Widget)
	border_color "..."                         a color string (same as border color=)
	width_group N                              an integer 0..1048575; 0 means no group
	height_group N                             an integer 0..1048575; 0 means no group

C<layout>, C<sizing>, C<padding> and C<border> take only the keys
shown, and at least one of them. The border style names are those of
L<Term::Fabulous::Enum::BorderStyle> and are case sensitive. A border
is only drawn on sides with a positive C<border_width>.

C<width_group> and C<height_group> give widgets in different parts of
the tree the same width or height; see
L<Term::Fabulous::Manual/Equal sizes across the tree>.

A property node may appear more than once. A second C<padding>,
C<sizing> or C<layout> node changes only the keys it names and keeps
the others.

	Box "panel" {
		layout direction=down gap=1
		sizing width="percent(50)" height=fit
		padding left=1 right=1
		border style=Round style-top=Heavy color="#61afef"
		border_width 1
		background_color "rgb(28, 33, 45)"
	}

=head2 Text properties

L<Term::Fabulous::Widget::Text>:

	Property node        Value
	-------------------  -----------------------------------------------
	text "..."           the text, exactly one string argument
	text_color "..."     a color string
	line_height N        rows per line of text (0 means 1)
	font_id N            no visible effect in a terminal
	font_size N          no visible effect in a terminal
	letter_spacing N     do not use; see Term::Fabulous::Widget::Text

Text in a layout is a character string like everything else in the
layout; the Text widget receives it UTF-8 encoded, as it requires.

=head2 Button properties

L<Term::Fabulous::Widget::Button>: the L</Box properties> plus
C<can_focus #true> or C<can_focus #false>.

=head2 ScrollBox properties

L<Term::Fabulous::Widget::ScrollBox>: the L</Box properties> plus
C<horizontal> and C<vertical> (booleans; defaults C<#false> and
C<#true>). A ScrollBox node needs an id:

	ScrollBox "log" {
		sizing width=grow height="fixed(10)"
		vertical #true
	}

=head2 Canvas and PixelCanvas properties

L<Term::Fabulous::Widget::Canvas> and
L<Term::Fabulous::Widget::PixelCanvas>: the L</Box properties>. What is
drawn on a canvas is drawn from Perl.

=head2 Properties of all input widgets

L<Term::Fabulous::Widget::TextField>, L<Term::Fabulous::Widget::TextArea>,
L<Term::Fabulous::Widget::Checkbox>, L<Term::Fabulous::Widget::RadioButton>,
L<Term::Fabulous::Widget::Dropdown> and L<Term::Fabulous::Widget::Slider>
accept the L</Box properties> plus:

	Property node                    Value
	-------------------------------  ----------------------------------
	disabled #true                   boolean
	can_focus #false                 boolean (see CAVEATS)
	text_color "..."                 color string
	disabled_color "..."             color string
	accent_color "..."               color string
	focus_background_color "..."     color string

See L<Term::Fabulous::Widget::Input> for their meaning.

=head2 TextField properties

L<Term::Fabulous::Widget::TextField>: the input widget properties plus
C<value>, C<placeholder> and C<mask> (strings), C<max_length> (an
integer, or C<#null> for no limit), C<read_only> (boolean),
C<preferred_columns> (a positive integer), C<placeholder_color> and
C<selection_color> (color strings).

	TextField "email" {
		placeholder "name@example.com"
		preferred_columns 30
		max_length 80
	}

=head2 TextArea properties

L<Term::Fabulous::Widget::TextArea>: the input widget properties plus
C<value>, C<placeholder> (strings), C<max_length>, C<read_only>,
C<placeholder_color>, C<selection_color> as for TextField, and
C<preferred_columns>, C<preferred_rows> (positive integers), C<wrap> and
C<scrollbar> (booleans).

=head2 Checkbox properties

L<Term::Fabulous::Widget::Checkbox>: the input widget properties plus
C<label>, C<checked_mark>, C<unchecked_mark>, C<indeterminate_mark>
(strings), C<checked> and C<indeterminate> (booleans).

	Checkbox "newsletter" {
		label "Send me the newsletter"
		checked #true
	}

=head2 RadioGroup and RadioButton properties

L<Term::Fabulous::Widget::RadioGroup>: the L</Box properties> plus
C<value> (the value of the selected button), C<disabled> and
C<can_focus> (booleans; for C<can_focus> see L</CAVEATS>). Without a
C<layout direction=...>, its children are stacked from top to bottom.

L<Term::Fabulous::Widget::RadioButton>: the input widget properties plus
C<label>, C<value>, C<selected_mark> and C<unselected_mark> (strings).

	RadioGroup "size" {
		layout direction=right gap=2
		value "m"
		RadioButton { label "Small"; value "s"; }
		RadioButton { label "Medium"; value "m"; }
		RadioButton { label "Large"; value "l"; }
	}

=head2 Dropdown properties

L<Term::Fabulous::Widget::Dropdown>: the input widget properties plus:

	Property node                  Value
	-----------------------------  --------------------------------------------
	options "A" "B" ...            adds options whose labels are their values
	option "Label" value="v"       adds one option with its own value;
	                               without value= the label is the value
	value "v"                      selects the option with this value
	selected_index N               selects the option at this index (from 0)
	placeholder "..."              string
	max_visible_options N          positive integer
	placeholder_color "..."        color string
	list_background_color "..."    color string
	highlight_text_color "..."     color string

C<options> and C<option> may be repeated; each adds to the end of the
list. Give the options before C<value> or C<selected_index>.

	Dropdown "color" {
		placeholder "Pick a color"
		options "Red" "Green"
		option "Dark blue" value="navy"
		value "navy"
	}

=head2 Slider properties

L<Term::Fabulous::Widget::Slider>: the input widget properties plus
C<min>, C<max>, C<step>, C<page_step>, C<value> (numbers),
C<show_value> (boolean), C<value_format> (a C<sprintf> format string;
a code reference is possible only from Perl), C<preferred_columns> (a
positive integer), C<fill_glyph>, C<track_glyph>, C<thumb_glyph> (single
characters) and C<track_color> (a color string). Give C<min>, C<max>
and C<step> before C<value>; and since C<min> must stay below C<max> at
every step, raise C<max> before C<min> when both grow beyond the
defaults (0 and 100).

	Slider "volume" {
		max 11
		value 5
		value_format "%d dB"
	}

=head1 EXAMPLES

=head2 A form, built from a layout

	use v5.24;
	use warnings;
	use feature 'signatures';
	no warnings 'experimental::signatures';

	use Term::Fabulous;
	use Term::Fabulous::Layout;

	my $layout = Term::Fabulous::Layout->new( string => <<'KDL' );
	use Term::Fabulous::Widget::Box as Box
	use Term::Fabulous::Widget::Text as Text
	use Term::Fabulous::Widget::TextField as TextField
	use Term::Fabulous::Widget::Checkbox as Checkbox
	use Term::Fabulous::Widget::RadioGroup as RadioGroup
	use Term::Fabulous::Widget::RadioButton as RadioButton
	use Term::Fabulous::Widget::Dropdown as Dropdown
	use Term::Fabulous::Widget::Slider as Slider

	Box "form" {
		layout direction=down gap=1
		sizing width=grow height=grow
		padding left=1 right=1
		border style=Round color="#61afef"
		border_width 1

		Text "title" {
			text "Sign up"
			text_color "rgb(255, 200, 80)"
		}
		TextField "name" {
			placeholder "Your name"
			max_length 40
		}
		TextField "password" {
			mask "*"
		}
		RadioGroup "plan" {
			layout direction=right gap=2
			value "pro"
			RadioButton { label "Free"; value "free"; }
			RadioButton { label "Pro"; value "pro"; }
		}
		Dropdown "country" {
			placeholder "Country"
			options "Austria" "Germany"
			option "Switzerland" value="CH"
			value "CH"
		}
		Slider "age" {
			min 18
			max 99
			value 30
			value_format "%d years"
		}
		Checkbox "news" {
			label "Send me news"
			checked #true
		}
	}
	KDL

	my $root = $layout->build;

	# Every Change event bubbles up to the form box.
	$root->on( Change => sub ($event) {
		my $status = $root->children->[0];    # the Text "title"
		$status->text( 'Changed: ' . $event->target->id );
		return;
	} );

	Term::Fabulous->new( root => $root, width => 80, height => 24 )->run;

=head2 Finding widgets by id

L</build> returns only the root widget. To get at the other widgets,
walk the tree from the root with this helper, which returns the first
widget (in depth-first order) whose id is C<$id>, or C<undef> when there
is none. The same helper is used in
L<Term::Fabulous::Cookbook/Find widgets by id>.

	# The first widget at or below $node whose id is $id, or undef.
	sub find_widget ( $node, $id ) {
		return $node if defined $node->id && $node->id eq $id;
		return undef unless $node->can('children');
		foreach my $child ( @{ $node->children } ) {
			my $found = find_widget( $child, $id );
			return $found if defined $found;
		}
		return undef;
	}

	my $country = find_widget( $root, 'country' );
	say $country->value;    # CH

=head2 Adding what a layout cannot express

Build first, then set the remaining options in Perl:

	use Clay::XS qw(CLAY_ALIGN_X_CENTER CLAY_ALIGN_Y_CENTER);

	my $panel = find_widget( $root, 'panel' );
	$panel->layout( {
		%{ $panel->layout },
		child_alignment => { x => CLAY_ALIGN_X_CENTER, y => CLAY_ALIGN_Y_CENTER },
	} );

=head1 LIMITATIONS

These options exist in Perl but cannot be written in a layout:

=over

=item *

minimum and maximum sizes, as in C<< sizing_grow(10, 40) >> or
C<< sizing_fit(0, 60) >> (a layout knows only C<grow>, C<fit>,
C<percent(N)> and C<fixed(N)>);

=item *

C<child_alignment> of a Box (see L<Term::Fabulous::Manual/Aligning and centering children>);

=item *

C<wrap_mode> and C<text_alignment> of a Text widget;

=item *

the C<classes> of a widget, and event listeners;

=item *

a code reference for a Slider's C<value_format>;

=item *

the C<child_offset> of a ScrollBox.

=back

=head1 ERRORS

Everything that is wrong with a layout dies, either in L</new> or in
L</build>. Messages start with C<Term::Fabulous::Layout:>; errors in a
widget's properties also name the widget and its id, followed by the
widget class's own message:

	Term::Fabulous::Layout: cannot build widget 'Box' "panel": Term::Fabulous::Widget::Box: unknown layout property 'colour' (known: background_color, border, border_color, border_width, glyphs_show_through, height_group, layout, padding, sizing, width_group)

L</new> dies for:

=over

=item * neither or both of C<string> and C<file>, or a file that cannot be opened;

=item * KDL syntax errors (C<failed to parse KDL: ...>; the parser does not report a line number);

=item * a malformed C<use>, an invalid module name or alias, or an alias declared twice;

=item * a module that cannot be loaded, or that does not compose L<Term::Fabulous::Role::CanParseLayout>;

=item * a top-level node that is neither C<use> nor a declared widget, no root widget, or more than one.

=back

L</build> dies for:

=over

=item * an undeclared widget name (C<unknown widget 'Foo'; declare it with 'use Module::Name as Foo'>);

=item * a widget node with C<key=value> properties, more than one argument, or a non-string id;

=item * child widgets inside a widget that cannot hold children;

=item * unknown property names, property nodes of the wrong shape, unknown keys, and invalid values.

=back

=head1 SECURITY

A layout names the Perl modules it loads, and loading a module runs its
code. Only syntactically valid package names are accepted (no paths),
and a module that does not compose L<Term::Fabulous::Role::CanParseLayout>
is rejected, but only after it has been loaded, so its top-level code
has already run. A layout can therefore load and run any module
installed on the system. Treat layout files like program code: do not
load layouts from untrusted sources.

Properties can only call the accessors a widget class lists in its
C<layout_properties> (see L<Term::Fabulous::Role::CanParseLayout>), so a
layout cannot call arbitrary methods.

=head1 CAVEATS

C<can_focus #false> currently has no effect on input widgets and on
RadioGroup: they set C<can_focus> again while they are constructed. Call
C<< $widget->can_focus(0) >> from Perl after L</build> instead.

=head1 SEE ALSO

L<Term::Fabulous::Manual/KDL LAYOUT FILES>,
L<Term::Fabulous::Role::CanParseLayout>, L<Term::Fabulous::Widget::Box>,
L<Text::KDL::XS>, L<https://kdl.dev>.

=cut
