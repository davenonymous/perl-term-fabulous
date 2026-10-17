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
	use Term::Fabulous::Widget::RichText;

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
	# list shows, text => the RichText or CodeBlock the overlays restyle
	# (or undef), marker => the RichText of an item's marker, quotes =>
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
	# kind: the RichText paints links itself).
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
		die ref($self) . ": $builder must return a Term::Fabulous::Widget::RichText, a Term::Fabulous::Widget::CodeBlock or undef as text, got " . describe($text)
			unless !defined $text || ( blessed $text && ( $text->isa('Term::Fabulous::Widget::RichText') || _is_code($text) ) );
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
		return Term::Fabulous::Widget::RichText->new(
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
		my $marker = Term::Fabulous::Widget::RichText->new( text => $block->marker, can_focus => 0 );
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

	# Links are no spans: the RichText paints its links over the spans, in
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

Term::Fabulous::Widget::DocumentView - A scrolling, searchable view of a document of blocks

=head1 SYNOPSIS

	use Clay::XS qw(sizing_grow);
	use Term::Fabulous::Widget::DocumentView;

	my $view = Term::Fabulous::Widget::DocumentView->new(
		id       => 'document',
		document => $document,    # a Term::Fabulous::Document, from a parser
		layout   => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

	$view->on( LinkActivate => sub ($event) { open_page( $event->link ); return } );
	$view->on( ViewChange   => sub ($event) { show_position( $event->percent ); return } );

	$view->search('frobnicate');
	$view->show_block( $view->document->find_section('METHODS') );

=begin html

<p><img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/v0.03/screenshots/widget-document-view.svg" alt="A framed document view: a first-level heading with a rule under it, indented paragraphs with bold and code spans, a bulleted list, a quoted paragraph with a bar on its left, a code block on a darker background, a selected link in inverse colors, and search matches highlighted"></p>

=end html

The program is F<examples/widgets/document-view.pl>.

=head1 DESCRIPTION

The view shows a L<Term::Fabulous::Document>: every block in the look
of its kind, wrapped to the view's width, scrolled with the keys, the
mouse wheel and the scrollbar, its links selected and followed, its
text searched. It is the main pane of a reader, whatever the format the
document was parsed from: L<Pod::Fabulous> shows POD with it,
L<Term::Fabulous::Widget::Markdown> shows Markdown.

It is a L<Term::Fabulous::Widget::VirtualList>: it builds widgets only
for the blocks near the viewport, so a document of thousands of
paragraphs (L<perlfunc> has about 2000 blocks) opens and scrolls as
fast as a short one, and stays below Clay's limits on elements and
words per frame (see L<Term::Fabulous/LIMITATIONS>). It also composes
L<Clay::UI::Role::Interaction::Focusable>, so it takes the keyboard
focus. Frame it with a Box around it rather than giving it a border of
its own: content scrolled under the border of a scroll container shows
its background in the border's cells.

=head2 How blocks are shown

=over

=item *

Paragraphs, terms and headings are L<Term::Fabulous::Widget::RichText>
widgets: Clay wraps them, and their marks become spans in the styles of
the view's look (L<Term::Fabulous::Document::Look>). Link marks become
links of the RichText instead, with the mark's link as their target; the
RichText paints them over the spans in the link looks of the theme
(see L<Term::Fabulous::Widget::RichText/Looks>), so that a link looks
like a link even when it is code. The RichTexts are created with
C<< can_focus => 0 >>: they are no Tab stops, the view selects the
links of all blocks itself (see L</KEYS>). Headings are drawn in the
style of their level, a first-level heading with a rule under it
(L<Term::Fabulous::Widget::Divider>); terms in the C<term> style.

=item *

An item is a row of two columns: its marker, and its text, which wraps
within its own column, so that every line starts after the marker.

=item *

Verbatim blocks are L<Term::Fabulous::Widget::CodeBlock> widgets, which
do not wrap; the view scrolls them all sideways together.

=item *

A block inside a block quote (L<Term::Fabulous::Document::Block/quote>)
has a bar on its left for every quote it is in, in the C<quote> style,
and a space after the bar.

=item *

Every block but a heading is indented by the view's L</indent> plus
its own (L<Term::Fabulous::Document::Block/indent>). A blank row
separates the blocks, except the items of one list (and the first item
of a list nested in an item from that item) and a term from the
paragraphs that define it. The view spaces the blocks itself: give its
layout no C<child_gap>, or the gap is added to every block.

=back

L<Term::Fabulous::Document::Geometry> holds these rules, and wraps the
text of a block as Clay does: the view asks it for the height of a
block it has not laid out yet, and for the line a search match is on.

=head2 Overlays

Two things are drawn over the blocks' own styles, without building
anything again: the I<selected link>, the one C<Enter> follows, and the
matches of a I<search>, the current one in a style of its own. The view
keeps one selection across all blocks and shows it through the RichText
of the link's block, with
L<select_link|Term::Fabulous::Widget::RichText/select_link>, also when
the block's view is built again. A theme switch restyles every block in
the new theme's colors. L<Term::Fabulous::Document::Overlays> holds both
and their rules, and tells the view which blocks to restyle.

=head1 CONSTRUCTOR

=head2 new

	my $view = Term::Fabulous::Widget::DocumentView->new( id => 'document', %parameters );

All parameters of L<Term::Fabulous::Widget::VirtualList> except
C<build>, C<estimate> and C<count>, which the view takes from its
document (giving them dies); an C<id> is required. Plus:

=over

=item C<document>

The L<Term::Fabulous::Document> to show, or C<undef> (the default) for
an empty view. A document with a mark whose kind the view's look does
not know dies (see L<Term::Fabulous::Document::Look/KINDS>).

=item C<highlighter>

C<undef> (the default), or a code reference that every code block of
the view uses to highlight its code; see
L<Term::Fabulous::Widget::CodeBlock/highlighter>.

=item C<indent>

A non-negative integer, default 2: the columns every block but a
heading is indented by.

=back

=head1 METHODS

The methods of L<Term::Fabulous::Widget::VirtualList>, plus the
following. The methods that scroll or select return 1 when they
changed something and 0 when there was nothing to change, so a key
binding can tell.

=head2 document

	$view->document($document);

Accessor. Setting shows the new document from its top, with its code
not scrolled sideways, drops the selected link and the search, and
makes the next frame fire a C<ViewChange>.

=head2 highlighter

	$view->highlighter( \&highlight );

Accessor; setting hands the new highlighter to every code block.

=head2 indent

	$view->indent(4);

Accessor; setting builds the views of the blocks again.

=head2 geometry

	my $geometry = $view->geometry;

The L<Term::Fabulous::Document::Geometry> of the document shown, or
C<undef> without a document.

=head2 document_look

	my $look = $view->document_look;

The L<Term::Fabulous::Document::Look> the view draws with at the
moment: that of the theme of its UI (see
L<Term::Fabulous::Document::Look/of>).

=head2 scroll_lines

	$view->scroll_lines(3);     # down
	$view->scroll_lines(-1);    # up

Scrolls by rows, stopping at the top and the end. The number of rows,
and of pages below, must be an integer; anything else dies.

=head2 scroll_pages

	$view->scroll_pages(1);

Scrolls by pages; a page is the rows the view shows inside its border
and padding, less one row, which stays in view (see
L<Term::Fabulous::Scrolling>).

=head2 scroll_to_top, scroll_to_bottom

	$view->scroll_to_bottom;

Scrolls to the first or the last block.

=head2 show_block

	$view->show_block($index);

Scrolls so that the block starts at the top of the view (or as near as
the end of the document allows), in the next frame. Returns the view.

=head2 top_block

	my $index = $view->top_block;

The index of the first block in view in the last frame, or C<undef>.

=head2 scroll_code

	$view->scroll_code(8);     # to the right
	$view->scroll_code(-8);

Scrolls every code block sideways by columns: one offset for all of
them, as C<less -S> scrolls long lines. It reaches as far as the widest
code block in view allows; the blocks out of view take the same offset,
so that they match when they come into view. Returns 1 when the offset
changed, 0 when there is nothing in view to scroll.

=head2 code_offset

	my $columns = $view->code_offset;

How far the code blocks are scrolled sideways by L</scroll_code>.

=head2 select_next_link, select_previous_link

	$view->select_next_link;

Selects the next or previous link: from the selected one while its
block is in view, otherwise from the first link in view (the last,
going back). The selection stops at the first and the last link of the
document. The line of the selected link is scrolled into view, with as
little movement as possible.

=head2 selected_link

	my $link = $view->selected_link;    # the mark's link, or undef

The destination of the selected link: the one
L<select_next_link or select_previous_link|/"select_next_link, select_previous_link">
selected last, or the one clicked last.

=head2 follow_link

	$view->follow_link;

Fires L<LinkActivate|Term::Fabulous::Event::LinkActivate> on the view
for the selected link: its C<link> is the mark's link, its C<index>
the place of the link among the links of its block, and its C<start>
and C<end> the link's offsets in the block's text. Returns 0 when no
link is selected.

=head2 search

	my $count = $view->search('hash');

Marks every occurrence of the text in the document (see
L<Term::Fabulous::Document/find_text> for the rules), makes the first
one at or after the top of the view current and scrolls its line into
view. Returns the number of matches. An empty text ends the search.

=head2 next_match, previous_match

	$view->next_match;

Makes the next or previous match current, around from the last to the
first, and scrolls it into view.

=head2 query, match_count, current_match

	printf "%s: %d of %d\n", $view->query, $view->current_match, $view->match_count;

The text searched for (or C<undef>), the number of matches, and the
number of the current match, from 1 (or C<undef>).

=head2 clear_marks

	$view->clear_marks;

Ends the search and drops the selected link.

=head2 view_state

	my $state = $view->view_state;

What the last frame showed, as the hash of the parameters of a
L<Term::Fabulous::Event::ViewChange>.

=head2 build, estimate, count

The list's own accessors return what the view gave them; setting them
dies.

=head1 KEYS

While the view has the focus:

=for highlighter language=text

	Down, j / Up, k          a row down or up
	PageDown, Space          a page down
	PageUp, b                a page up
	Home, g / End, G         the top or the end of the document
	Left / Right             the code blocks eight columns sideways
	l / L                    select the next or previous link
	Enter                    follow the selected link
	n / N                    the next or previous search match
	Escape                   end the search and drop the selected link

C<Enter> without a selected link and C<Escape> without anything to
drop go on to the widgets around, and so does every other key (see
L<Term::Fabulous::Manual::Events/KEYBOARD>).

=head1 MOUSE

The wheel and the scrollbar scroll the view, as in every
L<Term::Fabulous::Widget::ScrollBox>. Each notch of the horizontal
wheel (or a sideways tilt of the wheel) anywhere over the view scrolls
the code blocks three columns sideways while they can move, as
L</scroll_code> does; at the end, the notch goes on to the widgets
around. A click focuses the view.

A left click on a link selects it and follows it: the RichText of its
block fires L<LinkActivate|Term::Fabulous::Event::LinkActivate>, with
the mark's link as its C<link>, and the event bubbles up through the
view, which makes the clicked link its selected link and lets the event
go on. The link under the mouse pointer looks hovered.

=head1 EVENTS

=over

=item C<LinkActivate> (L<Term::Fabulous::Event::LinkActivate>)

When the user presses C<Enter> on the selected link, or the program
calls L</follow_link>: fired on the view. When the user clicks a link:
fired on the RichText of its block, and on its way up through the view
(see L</MOUSE>). Either way, C<< $event->link >> is the link of the
mark, whatever the parser put there.

=item C<ViewChange> (L<Term::Fabulous::Event::ViewChange>)

After a frame whose view differs from the one reported last.

=item The events of L<Term::Fabulous::Widget::VirtualList>

C<OnScroll> and C<Mouse>, and C<OnFocus> and C<OnBlur> from
L<Clay::UI::Role::Interaction::Focusable>.

=back

=head1 BLOCK KINDS

A viewer for a format whose documents have blocks the five built-in
kinds do not cover (a table, a horizontal rule, a picture) subclasses
the view and the look:

=over

=item *

A new kind of block is a subclass of L<Term::Fabulous::Document::Block>
whose C<kind> is a word of its own, say C<rule>, and which answers
L<body_rows|Term::Fabulous::Document::Block/body_rows> for a body that
is not wrapped text.

=item *

The view builds a block of kind C<KIND> with its method
C<view_of_KIND>, called as C<< $view->view_of_KIND( $block, $padding ) >>,
where C<$padding> is C<< { left => $columns, top => $rows } >>, the
indent of the block and the blank row above it. It returns a hash
reference C<< { widget => $widget, text => $text } >>: the widget the
list shows, which takes the padding (L</boxed> makes such a box), and
the L<Term::Fabulous::Widget::RichText> or
L<Term::Fabulous::Widget::CodeBlock> that shows the block's text, whose
spans the view sets from the marks and the overlays, or C<undef> for a
block without such a text. A view method of a name the base class does
not have dies when the block is built, and so does a C<text> that is
none of these.

=item *

New kinds of marks need styles: a subclass of
L<Term::Fabulous::Document::Look> with more L<recipes|Term::Fabulous::Document::Look/recipes>,
named by the view's L</look_class>.

=back

The methods a subclass builds with:

=head2 look_class

	method look_class :common () { return 'My::Look' }

Class method. The L<Term::Fabulous::Document::Look> class the view
draws with; default C<Term::Fabulous::Document::Look>. A subclass
returns a subclass of it.

=head2 view_of_heading, view_of_paragraph, view_of_item, view_of_term, view_of_verbatim

The builders of the built-in kinds, as described above; a subclass may
replace one.

=head2 rich_text_of

	my $text = $view->rich_text_of($block);

A RichText of the block's text with the block's links, and
C<< can_focus => 0 >>: what the built-in builders show the text with.

=head2 boxed

	my $box = $view->boxed( $padding, @children );

A Box with the children in a column, the given padding and the width
of the view.

=head2 spans_of

	my $spans = $view->spans_of( $index, $look );

The spans of a block's text in a look, as C<[ $start, $end, $style ]>:
the style of a heading or a term over the whole text, the marks, then
the overlays. A subclass that styles blocks of its own kinds extends
it.

=head1 KDL PROPERTIES

The properties of L<Term::Fabulous::Widget::ScrollBox/KDL PROPERTIES>,
plus C<indent>. The document comes from the program:

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

=head1 SEE ALSO

L<Term::Fabulous::Document>, L<Term::Fabulous::Widget::CodeBlock>,
L<Term::Fabulous::Document::Look>, L<Term::Fabulous::Document::Overlays>,
L<Term::Fabulous::Document::Geometry>, L<Term::Fabulous::Scrolling>,
L<Term::Fabulous::Widget::VirtualList>, L<Pod::Fabulous>.

=cut
