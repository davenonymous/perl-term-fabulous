package Term::Fabulous::Widget::DocumentView;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

use Clay::UI::Role::Interaction::Focusable;
use Term::Fabulous::Widget::VirtualList;

our $VERSION = '0.03';

class Term::Fabulous::Widget::DocumentView
	:isa(Term::Fabulous::Widget::VirtualList)
	:does(Clay::UI::Role::Interaction::Focusable)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed sizing_grow CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM);
	use List::Util qw(first max min);
	use Scalar::Util qw(blessed refaddr weaken);
	use Term::Fabulous::Check qw(describe non_negative_integer);
	use Term::Fabulous::Document::Geometry;
	use Term::Fabulous::Document::Look;
	use Term::Fabulous::Document::Overlays;
	use Term::Fabulous::Event::LinkActivate;
	use Term::Fabulous::Event::ViewChange;
	use Term::Fabulous::Scrolling qw(inner_rows reveal_rows scroll_by_pages scroll_by_rows scrolled_percent);
	use Term::Fabulous::Termbox qw(TF_KEY_MOUSE_WHEEL_LEFT TF_KEY_MOUSE_WHEEL_RIGHT);
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::CodeBlock;
	use Term::Fabulous::Widget::Divider;
	use Term::Fabulous::Widget::Text;

	use constant {
		CODE_STEP          => 8,    # columns the code moves per Left or Right
		CODE_WHEEL_COLUMNS => 3,    # and per notch of the horizontal wheel
		REVEAL_FRAMES      => 3,    # frames a reveal may take until its line is in view
	};

	# The columns of a quote, as the geometry counts them, are the bar (a
	# left border of one cell) and the padding between it and the blocks.
	use constant QUOTE_PADDING => Term::Fabulous::Document::Geometry::QUOTE_COLUMNS - 1;

	field $document    :param = undef;
	field $highlighter :param = undef;
	field $indent      :param = 2;

	# The views built for blocks, by block index: { widget => what the
	# list shows, text => the Text or CodeBlock the overlays restyle
	# (or undef), marker => the Text of an item's marker, quotes =>
	# the boxes whose left border is a quote bar }.
	field %view_of;

	# How far the code blocks are scrolled sideways, together.
	field $code_offset = 0;

	# The rows and columns of the document's blocks (undef without a
	# document), and the selected link and the search drawn over them.
	field $geometry;
	field $overlays;

	# What the last ViewChange said, whether a frame is watched, and the
	# line of a block to bring into view once the block is laid out:
	# { index, offset, frames }.
	field $reported = '';
	field $watching = 0;
	field $pending_reveal;

	# The list's build and estimate are the document's: a placeholder
	# satisfies VirtualList's constructor until ADJUST, where $self
	# exists, installs the real ones.
	sub BUILDARGS ( $class, %params ) {
		foreach my $name (qw(build estimate count)) {
			die "$class: $name cannot be given; the view builds its items from its document" if exists $params{$name};
		}
		return $class->SUPER::BUILDARGS( %params, build => sub ($index) { die "$class: the builder is installed in ADJUST" } );
	}

	ADJUST {
		$document    = $self->_checked_document($document);
		$highlighter = _checked_highlighter( $self, $highlighter );
		$indent      = non_negative_integer( $self, indent => $indent );

		weaken( my $weak_self = $self );
		$self->SUPER::build( sub ($index) { return $weak_self->_build_view($index) } );
		$self->SUPER::estimate( sub ( $index, $columns ) { return $weak_self->_rows_estimate( $index, $columns ) } );
		$self->on( KeyPress     => sub ($event) { return $weak_self->_key($event) } );
		$self->on( Mouse        => sub ($event) { return $weak_self->_wheel($event) } );
		$self->on( LinkActivate => sub ($event) { return $weak_self->_link_clicked($event) } );
		$self->_show_document;
	}

	# A document, whose marks name kinds the look knows (a link is no
	# kind: the Text paints links itself).
	method _checked_document ($value) {
		return undef unless defined $value;
		die ref($self) . ": document must be a Term::Fabulous::Document or undef, got " . describe($value) unless blessed $value && $value->isa('Term::Fabulous::Document');
		my %known   = map                                               { $_ => 1 } __CLASS__->look_class->kinds;
		my $unknown = first { !$_->is_link && !$known{ $_->kind } } map { $_->marks } $value->blocks;
		die ref($self) . ": the document has a mark of kind '" . $unknown->kind . "', which " . __CLASS__->look_class . " does not know; the kinds are " . join( ', ', sort keys %known )
			if defined $unknown;
		return $value;
	}

	sub _checked_highlighter ( $owner, $value ) {
		die ref($owner) . ": highlighter must be a code reference or undef, got " . describe($value) if defined $value && ref $value ne 'CODE';
		return $value;
	}

	# The class whose styles the blocks are drawn in; a subclass with
	# kinds of its own names a subclass of the base look.
	method look_class :common () {
		return 'Term::Fabulous::Document::Look';
	}

	method document_look () {
		return __CLASS__->look_class->of($self);
	}

	# ---------------------------------------------------------------------
	# Parameters
	# ---------------------------------------------------------------------

	method document (@new) {
		return $document unless @new;
		$document = $self->_checked_document( $new[0] );
		$self->_show_document;
		return $document;
	}

	method highlighter (@new) {
		return $highlighter unless @new;
		$highlighter = _checked_highlighter( $self, $new[0] );
		$_->{text}->highlighter($highlighter) foreach grep { _is_code( $_->{text} ) } values %view_of;
		return $highlighter;
	}

	method indent (@new) {
		return $indent unless @new;
		$indent   = non_negative_integer( $self, indent => $new[0] );
		$geometry = _geometry_of( $document, $indent );
		$self->rebuild;
		return $indent;
	}

	# The list's own parameters are the document's business.
	method build :override (@new) {
		die ref($self) . ": build cannot be set; the view builds its items from its document" if @new;
		return $self->SUPER::build;
	}

	method estimate :override (@new) {
		die ref($self) . ": estimate cannot be set; the view estimates its items from its document" if @new;
		return $self->SUPER::estimate;
	}

	method count :override (@new) {
		die ref($self) . ": count cannot be set; it is the number of blocks of the document" if @new;
		return $self->SUPER::count;
	}

	method rebuild :override () {
		%view_of = ();
		return $self->SUPER::rebuild;
	}

	# A new document starts at its top, with no overlays, its code not
	# scrolled sideways, and a ViewChange for its first frame.
	method _show_document () {
		$geometry       = _geometry_of( $document, $indent );
		$overlays       = Term::Fabulous::Document::Overlays->new( document => $document );
		$pending_reveal = undef;
		( $code_offset, $reported ) = ( 0, '' );
		$self->rebuild;
		$self->SUPER::count( defined $document ? $document->count : 0 );
		$self->scroll_to_item(0) if $self->SUPER::count;
		return;
	}

	sub _geometry_of ( $document, $indent ) {
		return defined $document ? Term::Fabulous::Document::Geometry->new( document => $document, indent => $indent ) : undef;
	}

	method geometry () {
		return $geometry;
	}

	sub _is_code ($widget) {
		return defined $widget && $widget->isa('Term::Fabulous::Widget::CodeBlock') ? 1 : 0;
	}

	# ---------------------------------------------------------------------
	# Building the views of blocks
	# ---------------------------------------------------------------------

	method _build_view ($index) {
		my $block   = $document->block($index);
		my $builder = 'view_of_' . $block->kind;
		die ref($self) . ": no $builder method for a block of kind '" . $block->kind . "'" unless $self->can($builder);
		my $view = $self->$builder( $block, { left => $geometry->left_of($index) - $block->quote * Term::Fabulous::Document::Geometry::QUOTE_COLUMNS, top => $geometry->space_before($index) } );
		die ref($self) . ": $builder must return { widget => ..., text => ... }, got " . describe($view) unless ref $view eq 'HASH' && blessed $view->{widget};
		my $text = $view->{text};
		die ref($self) . ": $builder must return a Term::Fabulous::Widget::Text, a Term::Fabulous::Widget::CodeBlock or undef as text, got " . describe($text)
			unless !defined $text || ( blessed $text && ( $text->isa('Term::Fabulous::Widget::Text') || _is_code($text) ) );
		$view_of{$index} = $self->_quoted( $block, $view );
		$self->_restyle($index);
		return $view_of{$index}{widget};
	}

	method boxed ( $padding, @children ) {
		my $box = Term::Fabulous::Widget::Box->new(
			layout => {
				layout_direction => CLAY_TOP_TO_BOTTOM,
				sizing           => { width => sizing_grow() },
				padding          => $padding,
			}
		);
		$box->add_child(@children);
		return $box;
	}

	# A block inside quotes gets a bar on its left for each one: a box
	# with a left border in the quote look, which the view recolors on a
	# theme switch. The blank row above the block stays inside the
	# innermost bar, so the bars of one quote join.
	method _quoted ( $block, $view ) {
		my @quotes;
		my $widget = $view->{widget};
		foreach ( 1 .. $block->quote ) {
			my $quote = Term::Fabulous::Widget::Box->new(
				bordered => { left             => 1 },
				layout   => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow() }, padding => { left => QUOTE_PADDING } },
			);
			$quote->add_child($widget);
			push @quotes, $quote;
			$widget = $quote;
		}
		return { %$view, widget => $widget, quotes => \@quotes };
	}

	# The text of a block, with its link marks as links whose target is
	# the mark's link. It is no Tab stop: the view selects the links of
	# all blocks with l and L, and shows the selection through the text's
	# own (see _restyle).
	method rich_text_of ($block) {
		return Term::Fabulous::Widget::Text->new(
			text      => $block->text,
			links     => [ map { [ $_->start, $_->end, $_->link ] } $block->links ],
			can_focus => 0,
		);
	}

	method view_of_heading ( $block, $padding ) {
		my $text = $self->rich_text_of($block);
		my @rule = $block->level == 1 ? ( Term::Fabulous::Widget::Divider->new ) : ();
		return { widget => $self->boxed( $padding, $text, @rule ), text => $text };
	}

	method view_of_paragraph ( $block, $padding ) {
		my $text = $self->rich_text_of($block);
		return { widget => $self->boxed( $padding, $text ), text => $text };
	}

	method view_of_term ( $block, $padding ) {
		return $self->view_of_paragraph( $block, $padding );
	}

	# The marker in a column of its own, so that the text's lines start
	# after it: a hanging indent, done by the layout.
	method view_of_item ( $block, $padding ) {
		my $marker = Term::Fabulous::Widget::Text->new( text => $block->marker, can_focus => 0 );
		$marker->stylize( $self->document_look->style('marker') );
		my $column = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed( $block->marker_width ) } } );
		$column->add_child($marker);

		my $text = $self->rich_text_of($block);
		my $row  = Term::Fabulous::Widget::Box->new(
			layout => {
				layout_direction => CLAY_LEFT_TO_RIGHT,
				sizing           => { width => sizing_grow() },
				padding          => $padding,
			}
		);
		$row->add_child( $column, $text );
		return { widget => $row, text => $text, marker => $marker };
	}

	method view_of_verbatim ( $block, $padding ) {
		my $code = Term::Fabulous::Widget::CodeBlock->new(
			code        => $block->text,
			language    => $block->language,
			highlighter => $highlighter,
			offset      => $code_offset,
			look_class  => __CLASS__->look_class,
			layout      => { sizing => { width => sizing_grow() }, padding => $padding },
		);
		return { widget => $code, text => $code };
	}

	# Rows a block takes before it was laid out, as the geometry wraps it.
	method _rows_estimate ( $index, $columns ) {
		return $geometry->estimated_rows( $index, $columns );
	}

	# ---------------------------------------------------------------------
	# Styles: the block's own marks, then the overlays
	# ---------------------------------------------------------------------

	# Links are no spans: the Text paints its links over the spans, in
	# the looks of the theme, so a link in code looks like a link.
	method spans_of ( $index, $look ) {
		my $block  = $document->block($index);
		my $length = length $block->text;
		my @spans;
		push @spans, [ 0, $length, $look->style( 'heading' . $block->level ) ] if $block->kind eq 'heading';
		push @spans, [ 0, $length, $look->style('term') ] if $block->kind eq 'term';
		push @spans, map { [ $_->start, $_->end, $look->style( $_->kind ) ] } grep { !$_->is_link } $block->marks;
		push @spans, map { [ $_->[0], $_->[1], $look->style( $_->[2] ) ] } $overlays->spans_of($index);
		return \@spans;
	}

	method _restyle ($index) {
		my $view = $view_of{$index} // return;
		my $look = $self->document_look;
		$_->border_color( $look->style('quote')->{color} ) foreach @{ $view->{quotes} };
		my $text = $view->{text} // return;
		if ( _is_code($text) ) {
			$text->spans( $self->spans_of( $index, $look ) );
			return;
		}
		$text->clear_spans;
		$text->stylize( $_->[2], $_->[0], $_->[1] ) foreach @{ $self->spans_of( $index, $look ) };
		$text->select_link( $overlays->selected_in_block($index) );
		return;
	}

	method _restyle_blocks (@indexes) {
		$self->_restyle($_) foreach @indexes;
		return;
	}

	# A theme switch changes every style; the views stay, only their spans
	# are made again (Term::Fabulous::Role::Themed). The ScrollBox pads
	# its gutter for the border first.
	method looks_changed :override (@names) {
		$self->SUPER::looks_changed(@names);
		my $marker_style = $self->document_look->style('marker');
		foreach my $index ( keys %view_of ) {
			$self->_restyle($index);
			my $marker = $view_of{$index}{marker} // next;
			$marker->clear_spans;
			$marker->stylize($marker_style);
		}
		return;
	}

	# ---------------------------------------------------------------------
	# Scrolling
	# ---------------------------------------------------------------------

	method scroll_lines ($lines) {
		my $ui = $self->ui // return 0;
		return scroll_by_rows( $ui, $self, $lines );
	}

	# A page is the rows the content shows less one (see
	# Term::Fabulous::Scrolling).
	method scroll_pages ($pages) {
		my $ui = $self->ui // return 0;
		return scroll_by_pages( $ui, $self, $pages );
	}

	method scroll_to_top () {
		return 0 unless $self->SUPER::count;
		$self->scroll_to_item(0);
		return 1;
	}

	method scroll_to_bottom () {
		return 0 unless $self->SUPER::count;
		$self->scroll_to_item( $self->SUPER::count - 1 );
		return 1;
	}

	method show_block ($index) {
		$self->scroll_to_item($index);
		return $self;
	}

	method top_block () {
		my $visible = $self->visible_items // return undef;
		return $visible->{first};
	}

	# Brings the line of a block that holds a character into view, with
	# as little movement as possible. A block that is not laid out goes
	# to the top first, and its line follows once it is. The list may
	# move the block to the top once more in the next frame (it repeats
	# scroll_to_item until it has measured the item), so the reveal is
	# checked again after each of a few frames, until the line is in view
	# (see _frame_done).
	method _reveal ( $index, $offset ) {
		$pending_reveal = { index => $index, offset => $offset, frames => REVEAL_FRAMES };
		$pending_reveal = undef unless $self->_reveal_now;
		return 1;
	}

	# One attempt: 1 when the view had to move, 0 when the line is in view.
	# The geometry tells the row of the character in its block's box.
	method _reveal_now () {
		my ( $index, $offset ) = @{$pending_reveal}{qw(index offset)};
		my $ui  = $self->ui;
		my $box = defined $ui && $view_of{$index} ? $ui->bounding_box( $view_of{$index}{widget} ) : undef;
		my ( $top, $bottom ) = defined $box ? inner_rows( $ui, $self ) : ();
		unless ( defined $top ) {
			$self->show_block($index);
			return 1;
		}
		my $row = $box->{y} + $geometry->row_of_character( $index, $offset, int( $box->{width} + 0.5 ) );
		return 0 if $row >= $top && $row < $bottom;
		reveal_rows( $ui, $self, $row, $row + 1 );
		return 1;
	}

	method code_offset () {
		return $code_offset;
	}

	# Scrolls every code block sideways, as far as the widest one in view
	# allows; blocks out of view move along, so that they match when they
	# come back. Only blocks in view that were painted know how much of
	# them shows.
	method scroll_code ($columns) {
		my $visible = $self->visible_items;
		my @code    = grep                    { _is_code($_) } map                    { $_->{text} } values %view_of;
		my @in_view = defined $visible ? grep { _is_code($_) && $_->columns > 0 } map { $view_of{$_} ? $view_of{$_}{text} : () } $visible->{first} .. $visible->{last} : ();
		my $limit   = max 0, map { $_->max_offset } @in_view;
		my $from    = min( $code_offset,               $limit );
		my $wanted  = min( max( 0, $from + $columns ), $limit );
		return 0 if $wanted == $from;
		$code_offset = $wanted;
		$_->offset($code_offset) foreach @code;
		return 1;
	}

	# A notch of the horizontal wheel anywhere over the view scrolls the
	# code, while it can move; at the end, the notch goes on.
	method _wheel ($event) {
		my $key       = $event->key;
		my $direction = $key == TF_KEY_MOUSE_WHEEL_LEFT ? -1 : $key == TF_KEY_MOUSE_WHEEL_RIGHT ? 1 : 0;
		return Clay::UI::Enum::Result->CONTINUE unless $direction && $self->scroll_code( $direction * CODE_WHEEL_COLUMNS );
		$event->use_wheel;
		return;
	}

	# ---------------------------------------------------------------------
	# Links
	# ---------------------------------------------------------------------

	method selected_link () {
		return $overlays->selected_link;
	}

	method select_next_link () {
		return $self->_select_link(1);
	}

	method select_previous_link () {
		return $self->_select_link(-1);
	}

	# The overlays choose the link, from the blocks in view; the view
	# shows it and scrolls its line into view.
	method _select_link ($direction) {
		my @touched = $overlays->select_link( $direction, $self->visible_items ) or return 0;
		$self->_restyle_blocks(@touched);
		my ( $index, $mark ) = $overlays->selected_mark;
		$self->_reveal( $index, $mark->start );
		return 1;
	}

	method follow_link () {
		my ( $index, $mark ) = $overlays->selected_mark or return 0;
		$self->fire_event(
			Term::Fabulous::Event::LinkActivate->new(
				link  => $mark->link,
				index => $overlays->selected_in_block($index),
				start => $mark->start,
				end   => $mark->end,
			)
		);
		return 1;
	}

	# A link clicked in the text of a block becomes the selected link,
	# and the event goes on to the program. The view's own LinkActivate
	# (see follow_link) comes from no block and passes untouched.
	method _link_clicked ($event) {
		my $continue = Clay::UI::Enum::Result->CONTINUE;
		my $text     = $event->target;
		my $index    = first { defined $view_of{$_}{text} && refaddr( $view_of{$_}{text} ) == refaddr($text) } keys %view_of;
		return $continue unless defined $index;
		$self->_restyle_blocks( $overlays->select_link_at( $index, $event->start, $event->end ) );
		return $continue;
	}

	# ---------------------------------------------------------------------
	# Searching
	# ---------------------------------------------------------------------

	method query () {
		return $overlays->query;
	}

	method match_count () {
		return $overlays->match_count;
	}

	method current_match () {
		return $overlays->current_match;
	}

	# Marks every occurrence and moves to the first one at or after the
	# top of the view. Returns the number of matches.
	method search ($text) {
		die ref($self) . ": search needs a string, got " . describe($text) unless defined $text && !ref $text;
		$self->_restyle_blocks( $overlays->search( $text, $self->top_block // 0 ) );
		my @start = $overlays->current_match_start;
		$self->_reveal(@start) if @start;
		return $overlays->match_count;
	}

	method next_match () {
		return $self->_step_match(1);
	}

	method previous_match () {
		return $self->_step_match(-1);
	}

	# Steps through the matches, around from the last to the first.
	method _step_match ($direction) {
		my @touched = $overlays->step_match($direction) or return 0;
		$self->_restyle_blocks(@touched);
		$self->_reveal( $overlays->current_match_start );
		return 1;
	}

	# Drops the search and the selected link. Returns 1 when there was
	# anything to drop: a search without matches restyles no block, but
	# it ends.
	method clear_marks () {
		return 0 if $overlays->is_empty;
		$pending_reveal = undef;
		$self->_restyle_blocks( $overlays->clear );
		return 1;
	}

	# ---------------------------------------------------------------------
	# Keys
	# ---------------------------------------------------------------------

	my %ACTION_OF_KEY = (
		Down     => sub ($self) { $self->scroll_lines(1) },
		j        => sub ($self) { $self->scroll_lines(1) },
		Up       => sub ($self) { $self->scroll_lines(-1) },
		k        => sub ($self) { $self->scroll_lines(-1) },
		PageDown => sub ($self) { $self->scroll_pages(1) },
		Space    => sub ($self) { $self->scroll_pages(1) },
		PageUp   => sub ($self) { $self->scroll_pages(-1) },
		b        => sub ($self) { $self->scroll_pages(-1) },
		Home     => sub ($self) { $self->scroll_to_top },
		g        => sub ($self) { $self->scroll_to_top },
		End      => sub ($self) { $self->scroll_to_bottom },
		G        => sub ($self) { $self->scroll_to_bottom },
		Left     => sub ($self) { $self->scroll_code( -CODE_STEP ) },
		Right    => sub ($self) { $self->scroll_code(CODE_STEP) },
		l        => sub ($self) { $self->select_next_link },
		L        => sub ($self) { $self->select_previous_link },
		Enter    => sub ($self) { $self->follow_link },
		n        => sub ($self) { $self->next_match },
		N        => sub ($self) { $self->previous_match },
		Escape   => sub ($self) { $self->clear_marks },
	);

	# A key with an action is used, whether or not the action could move
	# anything (at the end of the document, Down still belongs to the
	# document); Enter without a selected link and Escape without marks
	# go on to the widgets around.
	my %PASSES_WHEN_IDLE = map { $_ => 1 } qw(Enter Escape);

	method _key ($event) {
		my $name   = $event->main_key_name // return Clay::UI::Enum::Result->CONTINUE;
		my $action = $ACTION_OF_KEY{$name} // return Clay::UI::Enum::Result->CONTINUE;
		my $acted  = $action->($self);
		return Clay::UI::Enum::Result->CONTINUE if !$acted && $PASSES_WHEN_IDLE{$name};
		return;
	}

	# ---------------------------------------------------------------------
	# Reporting what the view shows
	# ---------------------------------------------------------------------

	method prepare_layout :override () {
		$self->SUPER::prepare_layout;
		$self->_watch_frames;
		return;
	}

	method _watch_frames () {
		my $ui = $self->ui;
		return if $watching || !defined $ui || !$ui->can('after_draw');
		weaken( my $weak_self = $self );
		$ui->after_draw( sub { $weak_self->_frame_done if defined $weak_self; return } );
		$watching = 1;
		return;
	}

	method _frame_done () {
		$watching = 0;
		return unless defined $self->ui;
		$self->_continue_reveal if defined $pending_reveal;
		$self->_report;
		$self->_watch_frames;
		return;
	}

	method _continue_reveal () {
		my $moved = $self->_reveal_now;
		$pending_reveal = undef unless $moved && --$pending_reveal->{frames} > 0;
		return;
	}

	method view_state () {
		my $visible = defined $document ? $self->visible_items : undef;
		my $ui      = $self->ui;
		my $section = $visible ? $document->section_at( $visible->{first} ) : undef;
		return {
			top           => $visible ? $visible->{first} : undef,
			bottom        => $visible ? $visible->{last}  : undef,
			section       => $section,
			section_title => defined $section ? $document->heading_of_section($section)->text : undef,
			percent       => ( defined $ui ? scrolled_percent( $ui, $self ) : undef ) // 100,
			link          => $overlays->selected_link,
			query         => $overlays->query,
			match         => $overlays->current_match,
			matches       => $overlays->match_count,
		};
	}

	# A frame is reported when anything of the state differs from the last
	# report; a link that is a reference counts by its identity.
	method _report () {
		my $state = $self->view_state;
		my $key   = join "\x1F", map { my $value = $state->{$_}; !defined $value ? '' : ref $value ? refaddr($value) : $value } sort keys %$state;
		return if $key eq $reported;
		$reported = $key;
		$self->fire_event( Term::Fabulous::Event::ViewChange->new(%$state) );
		return;
	}

	# ---------------------------------------------------------------------
	# KDL
	# ---------------------------------------------------------------------

	method layout_properties :common () {
		return ( $class->SUPER::layout_properties, indent => 'scalar' );
	}
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::DocumentView - A scrollable, searchable view of a structured document

=head1 SYNOPSIS

	use Clay::XS qw(sizing_grow);
	use Term::Fabulous::Widget::DocumentView;

	my $view = Term::Fabulous::Widget::DocumentView->new(
		id       => 'document',
		document => $document,    # a Term::Fabulous::Document, usually from a parser
		layout   => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	# Follow links, and keep a status line up to date.
	$view->on( LinkActivate => sub ($event) { open_page( $event->link ); return } );
	$view->on( ViewChange   => sub ($event) { show_position( $event->percent ); return } );

	# Search the text, and jump to a section.
	$view->search('frobnicate');
	my $methods = $view->document->find_section('METHODS');
	$view->show_block($methods) if defined $methods;

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.03/screenshots/widget-document-view.svg" alt="A framed document view: a first-level heading with a rule under it, indented paragraphs with bold and code spans, a bulleted list, a quoted paragraph with a bar on its left, a code block on a darker background, a selected link in inverse colors, and search matches highlighted"></p>

=end html

The program is F<examples/widgets/document-view.pl>.

=head1 DESCRIPTION

A document view is the main pane of a document reader. It shows a
L<Term::Fabulous::Document>, which is a list of I<blocks> (headings,
paragraphs, list items, code and so on) as a parser produced them, and
lets the user read it: the view wraps the text to its width, scrolls
with the keyboard, the mouse wheel and the scrollbar, selects and
follows links, and searches the text.

The view does not know the format the document was parsed from.
L<Pod::Fabulous> uses it to show POD, and
L<Term::Fabulous::Widget::Markdown> (part of Term::Fabulous::Extras)
uses it to show Markdown. Worked examples for showing documents,
following links, searching, building a table of contents and writing a
reader for a new format are in L<Term::Fabulous::Cookbook::Documents>.

A few terms are used throughout this page:

=over

=item *

Every block has a I<kind>: C<heading>, C<paragraph>, C<item>, C<term>
or C<verbatim> for the blocks Term::Fabulous ships (see
L<Term::Fabulous::Document::Block>), or a kind of its own for a block
class a reader adds (see L</BLOCK KINDS>).

=item *

I<Marks> label ranges of a block's text as bold, code, a link and so
on (see L<Term::Fabulous::Document::Mark>). Each mark has a kind as
well.

=item *

The I<look> (L<Term::Fabulous::Document::Look>) turns each kind of mark
into a style in the colors of the current theme.

=back

The view is a L<Term::Fabulous::Widget::VirtualList>: it builds widgets
only for the blocks near the visible area. A document with thousands of
blocks (L<perlfunc> has about 2000) therefore opens and scrolls as fast
as a short one, and every frame stays within Clay's limits on elements
and words (see L<Term::Fabulous/LIMITATIONS>). The view also composes
L<Clay::UI::Role::Interaction::Focusable>, so it can take the keyboard
focus.

To draw a frame around the view, place it inside a bordered Box rather
than giving the view a border of its own. A scroll container's own
border is drawn over its content, so content scrolled under it shows
its background in the border cells; a Box around the view avoids
that.

=head2 How blocks are shown

The view builds a widget, or a small tree of widgets, for each block,
depending on the block's kind:

=over

=item *

Headings, paragraphs and terms are L<Term::Fabulous::Widget::Text>
widgets, which Clay wraps to the width of the view. Every mark of the
block becomes a span in the style the look gives its kind. A heading is
drawn in the style of its level (C<heading1> to C<heading6>), and a
first-level heading has a horizontal rule
(L<Term::Fabulous::Widget::Divider>) under it. A term is drawn in the
C<term> style.

=item *

Link marks do not become spans. They become links of the Text, with
the mark's link as the target, and the Text paints them on top of
the spans in the link looks of the theme (see
L<Term::Fabulous::Widget::Text/Looks>). A link therefore looks like
a link even when it is also marked as code. The Text widgets are
created with C<< can_focus => 0 >>, so they are not Tab stops; the view
selects the links of all blocks itself (see L</KEYS>).

=item *

A list item is a row of two columns: the marker (a bullet or a number)
in the C<marker> style, and the text. The text wraps within its own
column, so every line of it starts after the marker.

=item *

Verbatim blocks are L<Term::Fabulous::Widget::CodeBlock> widgets. They
do not wrap; instead, the view scrolls all code blocks sideways
together (see L</scroll_code>).

=item *

A block inside a block quote (L<Term::Fabulous::Document::Block/quote>)
gets a vertical bar on its left for each quote it is in, drawn in the
C<quote> style and followed by one column of space. The blank row above
a quoted block lies inside its bars, so the bars of the blocks of one
quote join up.

=item *

Every block except a heading is indented by the view's L</indent> plus
the block's own indent (L<Term::Fabulous::Document::Block/indent>), in
columns.

=item *

One blank row separates consecutive blocks, with two exceptions. There
is none between the items of one list, nor between an item and the
first item of a list nested in it. There is also none between a term
and the block that follows it, if that block is not a term and is
indented deeper than the term. The view adds these blank rows itself, so do not give its
layout a C<child_gap>: the gap would be added between all blocks, on
top of the blank rows.

=back

L<Term::Fabulous::Document::Geometry> implements these layout rules and
wraps text the same way Clay does. The view asks it for the height of a
block that has not been laid out yet, and for the row of a character
within a block when it scrolls a link or a search match into view.

=head2 Overlays

Two kinds of highlighting, the I<overlays>, are drawn on top of the
blocks' own styles without rebuilding any widget:

=over

=item *

The I<selected link> is the link that C<Enter> follows. The view keeps
one selection for the whole document and shows it through the Text
of the link's block, with
L<select_link|Term::Fabulous::Widget::Text/select_link>. The
selection is shown again when the block's widgets are rebuilt.

=item *

The I<search matches> are the occurrences of the text of the last
L</search>, drawn in the C<match> style. One of them, the I<current
match>, is drawn in the C<match_current> style instead;
L<next_match and previous_match|/"next_match, previous_match"> move it.

=back

L<Term::Fabulous::Document::Overlays> holds both overlays and their
rules, and tells the view which blocks to restyle after each change.
When the theme changes, the view restyles every block it has built in
the colors of the new theme.

=head1 CONSTRUCTOR

=head2 new

	my $view = Term::Fabulous::Widget::DocumentView->new( id => 'document', %parameters );

Creates a document view. It takes all parameters of
L<Term::Fabulous::Widget::VirtualList> except C<build>, C<estimate> and
C<count>, which the view derives from its document; passing any of them
dies. As for every scroll container, an C<id> is required. Unknown
parameters and invalid values die. The additional parameters are:

=over

=item C<document>

The L<Term::Fabulous::Document> to show, or C<undef> (the default) for
an empty view. The constructor dies if a mark of the document has a
kind that the view's look does not know (see
L<Term::Fabulous::Document::Look/KINDS> and L</look_class>). Link marks
are exempt from this check, because the Text widgets draw links
themselves.

=item C<highlighter>

C<undef> (the default), or a code reference that all code blocks of the
view use to highlight their code, called with the code and the language
of the verbatim block; see
L<Term::Fabulous::Widget::CodeBlock/highlighter>.

=item C<indent>

A non-negative integer, default 2: the number of columns by which every
block except a heading is indented.

=back

=head1 METHODS

The view has all methods of L<Term::Fabulous::Widget::VirtualList>,
plus the following. Unless stated otherwise, the methods that scroll,
select or search return 1 when they changed something and 0 when there
was nothing to change, so a key binding can tell whether the key had an
effect.

=head2 document

	my $document = $view->document;
	$view->document($new_document);

Gets or sets the document. Setting it checks the new document as
L</new> does and shows it from the top: the code blocks are scrolled
back to their left edge, the selected link and the search are dropped,
and a C<ViewChange> event fires after the next frame. Setting C<undef>
empties the view. Returns the document.

=head2 highlighter

	$view->highlighter( \&highlight );

Gets or sets the highlighter. Setting it passes the new highlighter to
every code block the view has built, and the view hands it to the code
blocks it builds later; each code block highlights its code again the
next time it is painted. Dies for anything but a code reference or
C<undef>.

=head2 indent

	$view->indent(4);

Gets or sets the indent, in columns. Setting it rebuilds the widgets of
all blocks, so the new indent takes effect in the next frame. Dies for
anything but a non-negative integer.

=head2 geometry

	my $geometry = $view->geometry;

Returns the L<Term::Fabulous::Document::Geometry> of the document shown,
or C<undef> when the view has no document. The view creates a new
geometry whenever the document or the indent changes.

=head2 document_look

	my $look = $view->document_look;

Returns the L<Term::Fabulous::Document::Look> the view currently draws
with: an object of the class that L</look_class> names, for the theme
of the view's UI, or for the default theme while the view is not part
of a UI (see L<Term::Fabulous::Document::Look/of>).

=head2 scroll_lines

	$view->scroll_lines(3);     # down
	$view->scroll_lines(-1);    # up

Scrolls by the given number of rows: down for a positive number, up for
a negative one. Scrolling stops at the top and at the end of the
document. Returns 1 if the view moved and 0 if it could not. Before the
view is part of a UI, the method does nothing and returns 0; after
that, a number that is not an integer dies.

=head2 scroll_pages

	$view->scroll_pages(1);     # down
	$view->scroll_pages(-1);    # up

Scrolls by the given number of pages. A page is the number of rows the
view shows inside its border and padding, less one, so that one row of
the previous page stays in view (see L<Term::Fabulous::Scrolling>).
Return value and errors are as for L</scroll_lines>.

=head2 scroll_to_top, scroll_to_bottom

	$view->scroll_to_top;
	$view->scroll_to_bottom;

Scrolls so that the first or the last block starts at the top of the
view, or as close to the top as the end of the document allows. The
scroll takes effect in the next frame. Unlike the other scrolling
methods, these return 1 whenever the view has blocks, even if it is
already at the top or the end, and 0 when the view is empty.

=head2 show_block

	$view->show_block($index);

Scrolls so that the block with the given index starts at the top of the
view, or as close to the top as the end of the document allows. The
scroll takes effect in the next frame. Returns the view. Dies if the
document has no block with that index.

=head2 top_block

	my $index = $view->top_block;

Returns the index of the block at the top of the view in the last
frame, or C<undef> if the view has not been laid out yet or shows no
blocks.

=head2 scroll_code

	$view->scroll_code(8);     # show columns further right
	$view->scroll_code(-8);    # back towards the start of the lines

Scrolls all code blocks sideways by the given number of columns. A
positive number moves the view to the right along the lines, so the
code shifts to the left and later columns come into view; a negative
number moves back. All code
blocks share one horizontal offset, the way C<less -S> scrolls long
lines. The offset grows only as far as the widest code block that was
in view in the last frame requires to show the end of its longest line.
Code blocks out of view take the same offset, so that they line up when
they come into view.

Returns 1 if the offset changed, and 0 if it did not, for example
because no code block in view is wider than the view.

=head2 code_offset

	my $columns = $view->code_offset;

Returns the number of columns by which the code blocks are currently
scrolled sideways (see L</scroll_code>). The offset is 0 after a new
document is set.

=head2 select_next_link, select_previous_link

	$view->select_next_link;

Selects the next or the previous link of the document, and scrolls the
line it starts on into view, with as little movement as possible.

If the block of the selected link is in view, the selection moves on
from that link. Otherwise, select_next_link starts at the first link in
or below the view, and select_previous_link at the last link in or
above it. The selection does not wrap around: at the last link of the
document, select_next_link returns 0 and the selection stays where it
is, and the same applies to select_previous_link at the first link.
Both return 0 as well when the document has no links.

The scrolling may take a few frames: a block that has not been laid
out yet is first scrolled to the top of the view, and the view then
adjusts until the line is visible.

=head2 selected_link

	my $link = $view->selected_link;    # the mark's link, or undef

Returns the target of the selected link, as the parser stored it in the
link mark (L<Term::Fabulous::Document::Mark/link>), or C<undef> if no
link is selected. The selected link is the one last chosen with
L<select_next_link or select_previous_link|/"select_next_link, select_previous_link">,
or the one the user clicked last.

=head2 follow_link

	$view->follow_link;

Fires a L<LinkActivate|Term::Fabulous::Event::LinkActivate> event on
the view for the selected link. In the event, C<link> is the target of
the link mark, C<index> is the position of the link among the links of
its block, counted from 0, and C<start> and C<end> are the character
offsets of the link in the block's text. The view does not navigate
anywhere itself; a listener decides what following the link means.
Returns 1 when it fired the event, and 0 when no link is selected.

=head2 search

	my $count = $view->search('hash');

Searches the document for the text and marks every occurrence as a
search match. L<Term::Fabulous::Document/find_text> defines the
matching rules; in short, a text without capital letters matches
regardless of case. The current match becomes the first match in or
after the block at the top of the view, or the first match of the
document if there is none from there on. Its line is scrolled into
view as described for L<select_next_link|/"select_next_link, select_previous_link">.

Returns the number of matches. A new search replaces the previous one;
the selected link is not affected. An empty text ends the search and
returns 0. Dies if the argument is not a string.

=head2 next_match, previous_match

	$view->next_match;

Makes the next or the previous match current and scrolls its line into
view. The current match wraps around from the last match to the first,
and from the first to the last. Returns 0 when there are no matches,
and 1 otherwise.

=head2 query, match_count, current_match

	printf "%s: %d of %d\n", $view->query, $view->current_match, $view->match_count if $view->match_count;

Return the text of the current search (C<undef> without a search), the
number of matches (0 without a search), and the number of the current
match, counted from 1 (C<undef> when there are no matches).

=head2 clear_marks

	$view->clear_marks;

Ends the search and drops the selected link in one step. Returns 1 when
there was a search or a selected link to drop, even a search without
matches, and 0 otherwise.

=head2 view_state

	my $state = $view->view_state;

Returns a summary of what the view shows, as a hash reference with the
keys of the parameters of L<Term::Fabulous::Event::ViewChange>:
C<top>, C<bottom>, C<section>, C<section_title>, C<percent>, C<link>,
C<query>, C<match> and C<matches>. The positions describe the last
frame; the link and the search are the current ones. After every frame,
the view compares this summary with the last one it reported and fires
C<ViewChange> when they differ.

=head2 build, estimate, count

	my $blocks = $view->count;

Without an argument, these accessors of
L<Term::Fabulous::Widget::VirtualList> return the values the view
installed: its builder, its height estimate, and the number of blocks
of the document (0 without a document). Passing an argument dies,
because the view derives all three from its document.

=head1 KEYS

While the view has the focus, it handles these keys:

=for highlighter language=text

	Down, j            scroll down one row
	Up, k              scroll up one row
	PageDown, Space    scroll down one page
	PageUp, b          scroll up one page
	Home, g            go to the top of the document
	End, G             go to the end of the document
	Left, Right        scroll the code blocks eight columns sideways
	l, L               select the next or the previous link
	Enter              follow the selected link
	n, N               go to the next or the previous search match
	Escape             end the search and drop the selected link

The view consumes every key in this table, even when the key has
nothing to do: at the end of the document, C<Down> still belongs to the
view and does not reach the enclosing widgets. There are two
exceptions. When no link is selected, the view does not consume
C<Enter>; the key bubbles up to the enclosing widgets. The same applies
to C<Escape> when there is neither a search nor a selected link. All
other keys bubble up as well (see
L<Term::Fabulous::Manual::Events/KEYBOARD>).

=head1 MOUSE

The mouse wheel and the scrollbar scroll the view vertically, as in
every L<Term::Fabulous::Widget::ScrollBox>. The horizontal wheel (or
tilting the wheel sideways) scrolls the code blocks three columns per
notch, as L</scroll_code> does, while the pointer is over a code block.
(When the view is the root widget of the UI, anywhere over the view
works: mouse events go to the widget whose painted cells are under the
pointer, and the blank rows and the text of other blocks belong to no
painted widget.) Once the code cannot scroll further in that
direction, the event is passed on to the enclosing widgets. A click on
the text of a block or on a code block focuses the view.

A left click on a link selects the link and follows it. The Text of
the link's block fires
L<LinkActivate|Term::Fabulous::Event::LinkActivate>, with the target of
the link mark as its C<link>. As the event bubbles up through the view,
the view makes the clicked link its selected link and lets the event
continue, so listeners on the view and on the widgets around it receive
it. The link under the mouse pointer is drawn as hovered.

=head1 EVENTS

=over

=item C<LinkActivate> (L<Term::Fabulous::Event::LinkActivate>)

Fired on the view when the user presses C<Enter> while a link is
selected, or when the program calls L</follow_link>. When the user
clicks a link, the Text of the link's block fires the event, and it
bubbles up through the view (see L</MOUSE>). In both cases,
C<< $event->link >> is the target of the link mark, exactly as the
parser stored it.

=item C<ViewChange> (L<Term::Fabulous::Event::ViewChange>)

Fired on the view after a frame in which the summary that
L</view_state> returns differs from the one the view reported last, for
example because the user scrolled, selected a link or searched. It also
fires after the first frame of a new document. A link target that is a
reference counts as changed only when it is a different reference.

=item The events of L<Term::Fabulous::Widget::VirtualList>

C<OnScroll> and C<Mouse>, as well as C<OnFocus> and C<OnBlur> from
L<Clay::UI::Role::Interaction::Focusable>.

=back

=head1 BLOCK KINDS

The view shows the five block kinds Term::Fabulous ships: C<heading>,
C<paragraph>, C<item>, C<term> and C<verbatim>. A reader for a format
with other kinds of blocks, such as tables, horizontal rules or images,
adds them by subclassing the view, and the look if the new blocks need
styles of their own. A complete example is in
L<Term::Fabulous::Cookbook::Documents/Add a block kind and a mark kind of your own (view_of_KIND, look_class)>.
In outline:

=over

=item *

Define the block. A new kind of block is a subclass of
L<Term::Fabulous::Document::Block> whose C<kind> method returns a word
of its own, for example C<rule>. If the body of the block is not
wrapped text, the subclass also overrides
L<body_rows|Term::Fabulous::Document::Block/body_rows> and
L<row_of_character|Term::Fabulous::Document::Block/row_of_character>,
so that the view can estimate the height of the block and scroll to a
character in it.

=item *

Build its widgets. The view builds a block of kind C<KIND> by calling
its method C<view_of_KIND> as
C<< $view->view_of_KIND( $block, $padding ) >>. C<$padding> is a hash
reference C<< { left => $columns, top => $rows } >>: the indent of the
block and the blank row above it, which the returned widget must apply
as its padding (L</boxed> creates such a box). The quote bars of a
quoted block are not part of the padding; the view adds them around
the returned widget itself.

The method returns a hash reference C<< { widget => $widget, text => $text } >>.
C<widget> is a new widget without a parent, which the list shows for
the block. C<text> is the L<Term::Fabulous::Widget::Text> or
L<Term::Fabulous::Widget::CodeBlock> inside it that shows the block's
text, or C<undef> if there is none. The view sets the spans of this
widget from the block's marks and the overlays (see L</spans_of>).

The view dies when it builds a block whose kind has no C<view_of_KIND>
method, when the method does not return a hash reference with a
widget, and when its C<text> is neither of the widget types above nor
C<undef>.

=item *

Style new kinds of marks. If the format has marks of kinds the base
look does not know, subclass L<Term::Fabulous::Document::Look>, add
L<recipes|Term::Fabulous::Document::Look/recipes> for the new kinds,
and return the subclass from the view's L</look_class>. The view
refuses documents with marks of unknown kinds (see L</new>).

=back

A horizontal rule, for example, needs a block class and a builder:

=for highlighter language=perl

	use Object::Pad;
	use Term::Fabulous::Widget::Divider;

	class My::Block::Rule :isa(Term::Fabulous::Document::Block) {
		method kind () { return 'rule' }
		method body_rows ($columns) { return 1 }
		method row_of_character ( $offset, $columns ) { return 0 }
	}

	class My::DocumentView :isa(Term::Fabulous::Widget::DocumentView) {
		method view_of_rule ( $block, $padding ) {
			return { widget => $self->boxed( $padding, Term::Fabulous::Widget::Divider->new ), text => undef };
		}
	}

The parser then creates the block as C<< My::Block::Rule->new( text => '' ) >>.

The methods below are the building blocks for such subclasses.

=head2 look_class

	method look_class :common () { return 'My::Look' }

Class method that returns the name of the
L<Term::Fabulous::Document::Look> class the view draws with. The
default is C<Term::Fabulous::Document::Look>. A subclass that adds
kinds of marks overrides it to return a subclass of that class. The
view uses the class to check the marks of a document and, through
L</document_look>, to style the blocks, and hands it to every code
block it builds (see L<Term::Fabulous::Widget::CodeBlock/look_class>).

=head2 view_of_heading, view_of_paragraph, view_of_item, view_of_term, view_of_verbatim

	my $view_of_block = $view->view_of_paragraph( $block, $padding );

The builders of the built-in kinds, which produce the widgets described
in L</How blocks are shown>. They follow the contract described above,
so a subclass may override any of them to show a built-in kind
differently.

=head2 rich_text_of

	my $text = $view->rich_text_of($block);

Returns a new L<Term::Fabulous::Widget::Text> with the block's text
and the block's link marks as links, each with the mark's link as its
target. The Text is created with C<< can_focus => 0 >>, so that the
view handles the links (see L</Overlays>). The built-in builders show
their text with it, and a builder of a new kind can use it too.

=head2 boxed

	my $box = $view->boxed( $padding, @children );

Returns a new L<Term::Fabulous::Widget::Box> that stacks the children
from top to bottom, grows to the full width available, and applies the
given padding, a hash reference as passed to a C<view_of_KIND> method.

=head2 spans_of

	my $spans = $view->spans_of( $index, $look );

Returns the spans of the text of the block with the given index, in the
given look, as an array reference of C<[ $start, $end, $style ]>, where
C<$style> is a style hash of the look. The spans come in this order:
the style of a heading's level or of a term over the whole text, the
styles of the block's marks except links, and the overlays (C<match> and
C<match_current>). Later spans are applied on top of earlier ones. The
view calls this method whenever it restyles a block.

A subclass that styles blocks of its own kinds overrides it. Putting
its own spans first keeps the overlays on top. This example assumes a
C<caption> recipe in the view's L</look_class>:

	method spans_of :override ( $index, $look ) {
		my $spans = $self->SUPER::spans_of( $index, $look );
		my $block = $self->document->block($index);
		unshift @$spans, [ 0, length $block->text, $look->style('caption') ] if $block->kind eq 'caption';
		return $spans;
	}

=head1 KDL PROPERTIES

The view accepts the properties of
L<Term::Fabulous::Widget::ScrollBox/KDL PROPERTIES>, plus C<indent>.
A layout file cannot give the document; the program sets it with
L</document> after loading the layout:

=for highlighter language=kdl

	use Term::Fabulous::Widget::DocumentView as DocumentView

	Box "page-pane" {
		sizing width=grow height=grow
		bordered #true
		DocumentView "document" {
			sizing width=grow height=grow
			padding left=1 right=1
			indent 2
		}
	}

=for highlighter language=perl

	$ui->find_by_id('document')->document($document);

=head1 SEE ALSO

L<Term::Fabulous::Cookbook::Documents>, L<Term::Fabulous::Document>,
L<Term::Fabulous::Widget::CodeBlock>, L<Term::Fabulous::Document::Look>,
L<Term::Fabulous::Document::Overlays>,
L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Scrolling>,
L<Term::Fabulous::Widget::VirtualList>, L<Pod::Fabulous>.

=cut
