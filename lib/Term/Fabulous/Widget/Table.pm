package Term::Fabulous::Widget::Table;

use v5.24;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Clay::UI::Role::Core::Preparable;
use Clay::UI::Role::Interaction::Focusable;
use Clay::UI::Role::Interaction::Hoverable;
use Term::Fabulous::Widget::Box;
use Term::Fabulous::Widget::ScrollBox;
use Term::Fabulous::Widget::Text;
use Term::Fabulous::Widget::TextField;
use Term::Fabulous::Widget::Table::Cell;
use Term::Fabulous::Widget::Table::ColumnChooser;
use Term::Fabulous::Widget::Table::Grid;
use Term::Fabulous::Widget::Table::HeaderView;
use Term::Fabulous::Widget::Table::Model;
use Term::Fabulous::Widget::Table::Pager;
use Term::Fabulous::Widget::Table::Scrollbar;
use Term::Fabulous::Widget::Table::Toggle;

class Term::Fabulous::Widget::Table
	:isa(Term::Fabulous::Widget::Box)
	:does(Clay::UI::Role::Interaction::Focusable)
	:does(Clay::UI::Role::Interaction::Hoverable)
	:does(Clay::UI::Role::Core::Preparable)
	:strict(params)
{
	use Clay::UI::Enum::Result;
	use Clay::XS qw(
		sizing_fit sizing_fixed sizing_grow sizing_percent CLAY_LEFT_TO_RIGHT CLAY_TOP_TO_BOTTOM
		CLAY__SIZING_TYPE_GROW CLAY__SIZING_TYPE_PERCENT
		CLAY_ALIGN_X_LEFT CLAY_ALIGN_X_CENTER CLAY_ALIGN_X_RIGHT CLAY_ALIGN_Y_TOP
		CLAY_TEXT_WRAP_WORDS CLAY_TEXT_WRAP_NEWLINES CLAY_TEXT_WRAP_NONE
		CLAY_TEXT_ALIGN_LEFT CLAY_TEXT_ALIGN_CENTER CLAY_TEXT_ALIGN_RIGHT
	);
	use List::Util qw(any first max min);
	use Scalar::Util qw(blessed refaddr weaken);
	use Time::HiRes ();
	use Term::Fabulous::Check qw(boolean color non_negative_integer string);
	use Term::Fabulous::Enum::BorderStyle;
	use Term::Fabulous::Event::CursorMove;
	use Term::Fabulous::Event::Collapse;
	use Term::Fabulous::Event::ColumnsChange;
	use Term::Fabulous::Event::Expand;
	use Term::Fabulous::Event::FilterChange;
	use Term::Fabulous::Event::PageChange;
	use Term::Fabulous::Event::RowActivate;
	use Term::Fabulous::Event::SelectionChange;
	use Term::Fabulous::Event::SortChange;
	use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_LEFT TB_KEY_MOUSE_RIGHT TB_MOD_MOTION TB_MOD_SHIFT TB_MOD_CTRL TB_MOD_ALT);
	use Term::Fabulous::Widget::Table::Borders qw(resolve_borders);
	use Term::Fabulous::Widget::Table::Filter;
	use Term::Fabulous::Widget::Table::Style qw(style_hash border_style_of merge_styles);

	use constant {
		SELECT_COLUMN  => '',                 # the column key of the selection column
		EMPTY_LINE     => "e\0",              # the key of the line an empty view shows
		MARK_CHECKED   => '[x]',
		MARK_UNCHECKED => '[ ]',
		MARK_SOME      => '[-]',
		OPEN           => "\x{25BE} ",
		CLOSED         => "\x{25B8} ",
		LEAF           => '  ',
		SORT_UP        => "\x{25B4}",
		SORT_DOWN      => "\x{25BE}",
		INDENT         => 2,
		DEFAULT_PAGE_STEP => 10,
		FALLBACK_BACKGROUND => [ 22, 25, 31, 255 ],
	};

	my $CONTINUE = Clay::UI::Enum::Result->CONTINUE;
	my $HANDLED  = Clay::UI::Enum::Result->HANDLED;

	my %IS_SELECTION = map { $_ => 1 } qw(none single multiple);
	my %ALIGN_X      = ( left => CLAY_ALIGN_X_LEFT, center => CLAY_ALIGN_X_CENTER, right => CLAY_ALIGN_X_RIGHT );
	my %TEXT_ALIGN   = ( left => CLAY_TEXT_ALIGN_LEFT, center => CLAY_TEXT_ALIGN_CENTER, right => CLAY_TEXT_ALIGN_RIGHT );
	my %WRAP         = ( words => CLAY_TEXT_WRAP_WORDS, newlines => CLAY_TEXT_WRAP_NEWLINES, none => CLAY_TEXT_WRAP_NONE );
	my @LINE_PARAMS  = qw(border_top border_right border_bottom border_left column_lines row_lines header_line);
	my @COLOR_PARAMS = qw(
		text_color header_text_color header_background_color group_text_color group_background_color
		cursor_color selected_color hover_color filter_background_color error_color muted_color line_color
	);

	# ---------------------------------------------------------------------
	# Parameters
	# ---------------------------------------------------------------------

	# What the model is made of; handed over in ADJUST and dropped there.
	field $initial_columns :param(columns)       = [];
	field $initial_rows    :param(rows)          = [];
	field $initial_sort    :param(sort)          = [];
	field $initial_group   :param(group_by)      = undef;
	field $row_id          :param                = undef;
	field $children_key    :param                = undef;
	field $tree_expanded   :param                = 0;
	field $initial_page_size :param(page_size)   = 0;

	field $selection        :param = 'none';
	field $selection_column :param = undef;
	field $_explicit_selection_column;    # selection_column as the user set it, else undef
	field $show_header      :param(header) = 1;
	field $filter_row       :param = 0;
	field $page_sizes       :param = [ 10, 25, 50, 100 ];
	field $show_pager       :param(pager) = undef;
	field $scrollbar        :param = 1;
	field $hover            :param = 1;
	field $tree_column      :param = undef;
	field $group_label      :param = undef;
	field $row_style        :param = undef;
	field $header_style     :param = undef;
	field $group_style      :param = undef;
	field $empty_text       :param = 'No rows';
	field $no_match_text    :param = 'No rows match';
	field $cell_padding     :param = 1;
	field $stripe_color     :param = undef;
	field $double_click_seconds :param = 0.4;

	field $border        :param = 'Round';
	field $border_top    :param = undef;
	field $border_right  :param = undef;
	field $border_bottom :param = undef;
	field $border_left   :param = undef;
	field $column_lines  :param = 'Solid';
	field $row_lines     :param = undef;
	field $header_line   :param = 'Solid';

	field $text_color              :param = [ 220, 223, 228, 255 ];
	field $header_text_color       :param = [ 235, 238, 243, 255 ];
	field $header_background_color :param = [ 36,  40,  50,  255 ];
	field $group_text_color        :param = [ 97,  175, 239, 255 ];
	field $group_background_color  :param = [ 28,  32,  41,  255 ];
	field $cursor_color            :param = [ 52,  58,  72,  255 ];
	field $selected_color          :param = [ 38,  62,  92,  255 ];
	field $hover_color             :param = [ 38,  42,  52,  255 ];
	field $filter_background_color :param = [ 30,  33,  40,  255 ];
	field $error_color             :param = [ 224, 108, 117, 255 ];
	field $muted_color             :param = [ 140, 146, 158, 255 ];
	field $line_color              :param = [ 88,  96,  112, 255 ];

	# ---------------------------------------------------------------------
	# State
	# ---------------------------------------------------------------------

	field $model :reader;
	field %_line_style;    # table-wide lines: border_* , column_lines, row_lines, header_line

	# The widgets of the table.
	field $_header_row;       # the header view and, with a scrollbar, a spacer as wide as it
	field $_header_view;
	field $_header_spacer;
	field $_header_grid;
	field $_body_row;
	field $_body;
	field $_body_grid;
	field $_scrollbar;
	field $_pager;
	field $_chooser;

	# The header as built: a signature of what it was built from, and per
	# grid column { cell, title, marker, mark } and { cell, field }.
	field $_header_signature = '';
	field @_header_cells;
	field @_filter_cells;
	field %_filter_text;
	field %_filter_error;

	# The body as built: the signature of its columns, the lines by key
	# (see _build_line) and the order of the grid's rows.
	field $_body_signature = '';
	field %_built;
	field @_grid_keys;

	# The grid lines as last worked out, what they were worked out from,
	# and a count that tells the lines' looks they changed. Changes of
	# styles count in _style_revision.
	field $_borders_signature  = '';
	field $_borders            = [];
	field $_borders_generation = 0;
	field $_style_revision     = 0;

	field %_row_style_of;     # row id => style hash
	field %_cell_style_of;    # "id\0key" => style hash
	field $_hover_key;
	field $_header_cursor;    # grid column index while the header has the keyboard, else undef
	field @_last_press;       # ( time, line key ) of the last left press on a line
	field $_reveal_cursor = 0;
	field $_shown_page    = 0;

	ADJUST {
		my $id = $self->id;
		die "Term::Fabulous::Widget::Table: a table needs an id (its body keeps its scroll position by it)" unless defined $id;

		$self->_check_parameters;
		$model = Term::Fabulous::Widget::Table::Model->new(
			row_id       => $row_id,
			children_key => $children_key,
			page_size    => $initial_page_size,
			expand_new   => $tree_expanded,
		);
		$model->add_column($_) foreach @$initial_columns;
		$model->set_rows($initial_rows);
		$model->set_sort( _sort_spec($initial_sort) );
		$model->group_by( ref $initial_group eq 'ARRAY' ? @$initial_group : $initial_group ) if defined $initial_group;
		( $initial_columns, $initial_rows, $initial_sort, $initial_group ) = ();

		$self->_build_frame;
		$self->_listen;
		$self->request_prepare;
	}

	method _check_parameters () {
		die "Term::Fabulous::Widget::Table: selection must be 'none', 'single' or 'multiple', got " . _describe($selection)
			unless defined $selection && $IS_SELECTION{$selection};
		$_explicit_selection_column = boolean( $self, selection_column => $selection_column ) if defined $selection_column;
		$selection_column = $_explicit_selection_column // ( $selection eq 'multiple' ? 1 : 0 );
		$show_header      = boolean( $self, header     => $show_header );
		$filter_row       = boolean( $self, filter_row => $filter_row );
		$scrollbar        = boolean( $self, scrollbar  => $scrollbar );
		$hover            = boolean( $self, hover      => $hover );
		$tree_expanded    = boolean( $self, tree_expanded => $tree_expanded );
		$show_pager       = boolean( $self, pager => $show_pager ) if defined $show_pager;
		die "Term::Fabulous::Widget::Table: page_sizes must be an array reference of positive integers, got " . _describe($page_sizes)
			unless ref $page_sizes eq 'ARRAY' && @$page_sizes && !grep { !defined || ref || !/\A[1-9][0-9]*\z/ } @$page_sizes;
		$page_sizes = [ map { $_ + 0 } @$page_sizes ];
		foreach my $code ( [ group_label => $group_label ], [ row_style => $row_style ] ) {
			die "Term::Fabulous::Widget::Table: $code->[0] must be a code reference, got " . _describe( $code->[1] )
				if defined $code->[1] && ref $code->[1] ne 'CODE';
		}
		$header_style = style_hash( $self, 'header_style', row => $header_style );
		$group_style  = style_hash( $self, 'group_style',  row => $group_style );
		$empty_text    = string( $self, empty_text    => $empty_text );
		$no_match_text = string( $self, no_match_text => $no_match_text );
		$cell_padding  = $self->_padding($cell_padding);
		$stripe_color  = color( $self, stripe_color => $stripe_color ) if defined $stripe_color;
		die "Term::Fabulous::Widget::Table: double_click_seconds must be a number of at least 0, got " . _describe($double_click_seconds)
			unless defined $double_click_seconds && !ref $double_click_seconds && $double_click_seconds =~ /\A[0-9]*\.?[0-9]+\z/;

		my $outer = defined $border ? border_style_of( $self, border => $border ) : undef;
		my %line  = (
			border_top    => $border_top,
			border_right  => $border_right,
			border_bottom => $border_bottom,
			border_left   => $border_left,
			column_lines  => $column_lines,
			row_lines     => $row_lines,
			header_line   => $header_line,
		);
		foreach my $name (@LINE_PARAMS) {
			my $value = $line{$name} // ( $name =~ /\Aborder_/ ? $outer : undef );
			$_line_style{$name} = defined $value ? border_style_of( $self, $name => $value ) : undef;
		}
		foreach my $name (@COLOR_PARAMS) {
			my $field_ref = $self->_color_field($name);
			$$field_ref = color( $self, $name => $$field_ref );
		}
		return;
	}

	sub _describe ($thing) {
		return 'undef' unless defined $thing;
		return ref($thing) . ' reference' if ref $thing;
		return "'$thing'";
	}

	sub _sort_spec ($spec) {
		die "Term::Fabulous::Widget::Table: sort must be an array reference of column keys or [ key, 'asc' or 'desc' ] pairs, got " . _describe($spec)
			unless ref $spec eq 'ARRAY';
		return @$spec;
	}

	method _padding ($padding) {
		return { left => $padding, right => $padding, top => 0, bottom => 0 } if !ref $padding && defined $padding && $padding =~ /\A[0-9]+\z/;
		die "Term::Fabulous::Widget::Table: cell_padding must be a number of cells or a hash reference of left, right, top and bottom, got " . _describe($padding)
			unless ref $padding eq 'HASH' && !grep { !/\A(?:left|right|top|bottom)\z/ } keys %$padding;
		return { map { $_ => non_negative_integer( $self, "cell_padding $_", $padding->{$_} // 0 ) } qw(left right top bottom) };
	}

	method _color_field ($name) {
		my %field = (
			text_color              => \$text_color,
			header_text_color       => \$header_text_color,
			header_background_color => \$header_background_color,
			group_text_color        => \$group_text_color,
			group_background_color  => \$group_background_color,
			cursor_color            => \$cursor_color,
			selected_color          => \$selected_color,
			hover_color             => \$hover_color,
			filter_background_color => \$filter_background_color,
			error_color             => \$error_color,
			muted_color             => \$muted_color,
			line_color              => \$line_color,
		);
		return $field{$name} // die "Term::Fabulous::Widget::Table: internal: no color '$name'";
	}

	# ---------------------------------------------------------------------
	# The frame of widgets: header, body with scrollbar, pager
	# ---------------------------------------------------------------------

	method _build_frame () {
		my $layout = $self->layout;
		$self->layout( {
			%$layout,
			layout_direction => CLAY_TOP_TO_BOTTOM,
			sizing           => { width => sizing_fit(), height => sizing_fit(), %{ $layout->{sizing} // {} } },
		} );

		my $id = $self->id;
		$_body = Term::Fabulous::Widget::ScrollBox->new(
			id         => "$id/body",
			vertical   => 1,
			horizontal => 1,
			layout     => { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_grow(), height => sizing_fit() } },
		);
		$_header_grid = Term::Fabulous::Widget::Table::Grid->new( layout => { sizing => { width => sizing_grow(), height => sizing_fit() } } );
		$_body_grid   = Term::Fabulous::Widget::Table::Grid->new( layout => { sizing => { width => sizing_grow(), height => sizing_fit() } }, share_columns_with => $_header_grid );
		$_body->add_child($_body_grid);

		$_header_view = Term::Fabulous::Widget::Table::HeaderView->new(
			follows => $_body,
			layout  => { sizing => { width => sizing_grow(), height => sizing_fit() } },
		);
		$_header_view->add_child($_header_grid);
		$_header_row    = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_LEFT_TO_RIGHT, sizing => { width => sizing_grow(), height => sizing_fit() } } );
		$_header_spacer = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_fixed(1), height => sizing_grow() } } );
		$_header_row->add_child($_header_view);

		$_body_row = Term::Fabulous::Widget::Box->new( layout => { layout_direction => CLAY_LEFT_TO_RIGHT, sizing => { width => sizing_grow(), height => sizing_fit() } } );
		$_body_row->add_child($_body);
		$_scrollbar = Term::Fabulous::Widget::Table::Scrollbar->new(
			follows     => $_body,
			thumb_color => $text_color,
			track_color => $line_color,
			layout      => { sizing => { width => sizing_fixed(1), height => sizing_grow() } },
		);

		$_pager = Term::Fabulous::Widget::Table::Pager->new( page_sizes => $page_sizes, text_color => $text_color, muted_color => $muted_color );
		$self->_wire_pager;
		$self->add_child( $_header_row, $_body_row );
		return;
	}

	# A new pager, for new page sizes or colors; prepare_layout shows it.
	method _rebuild_pager () {
		my $old = $_pager;
		$_pager = Term::Fabulous::Widget::Table::Pager->new( page_sizes => $page_sizes, text_color => $text_color, muted_color => $muted_color );
		$self->_wire_pager;
		$self->remove_children_with( sub ($child) { refaddr($child) == refaddr($old) } );
		return;
	}

	method _wire_pager () {
		weaken( my $weak = $self );
		my %step = ( first => sub { 1 }, previous => sub { $weak->page - 1 }, next => sub { $weak->page + 1 }, last => sub { $weak->page_count } );
		foreach my $name ( sort keys %step ) {
			$_pager->button($name)->on( Activate => sub ($event) { $weak->_turn_page( $step{$name}->() ); return } );
		}
		$_pager->size_list->on( Change => sub ($event) { $weak->_change_page_size( $event->value ); return } );
		return;
	}

	# The grid columns: the selection column, then the visible columns.
	method _grid_columns () {
		my @columns = map { { key => $_->key, column => $_ } } $model->visible_columns;
		unshift @columns, { key => SELECT_COLUMN, column => undef } if $selection_column && $selection ne 'none';
		return @columns;
	}

	# The column that shows the tree: tree_column, or the first visible one.
	method _tree_column_key () {
		return undef unless defined $model->children_key;
		return $tree_column if defined $tree_column && $model->has_column($tree_column) && $model->is_column_visible($tree_column);
		my ($first) = $model->visible_columns;
		return defined $first ? $first->key : undef;
	}

	# ---------------------------------------------------------------------
	# Preparing the widgets for a frame
	# ---------------------------------------------------------------------

	method _changed () {
		$self->request_prepare;
		return;
	}

	# A change of looks or lines every cell may show.
	method _restyle () {
		$_style_revision++;
		$self->request_prepare;
		return;
	}

	method prepare_layout () {
		my $focus_in_cell = $self->_focus_in_cell;
		my @grid_columns  = $self->_grid_columns;
		my @lines         = $self->_body_lines;
		$self->_prepare_width( \@grid_columns );
		$self->_prepare_header( \@grid_columns );
		$self->_prepare_body( \@grid_columns, \@lines );
		$self->_dress( \@grid_columns, \@lines );
		$self->_prepare_scrollbar;
		$self->_prepare_pager;
		$self->_prepare_scrolling;
		# A focused widget in a cell that was built again or removed takes
		# the focus with it; the table takes it back.
		$self->_focus_self if $focus_in_cell && !$self->_has_focus_within;
		return;
	}

	# Whether a widget inside one of the body's cells has the focus.
	method _focus_in_cell () {
		my $ui      = $self->ui // return 0;
		my $focused = $ui->interaction->get_focused_widget // return 0;
		return refaddr($focused) != refaddr($self) && $self->_region_of($focused) eq 'body' ? 1 : 0;
	}

	# The grids are as wide as their columns, unless a column grows (or is
	# a share of the width): then they take the width of the table.
	method _prepare_width ($grid_columns) {
		my $stretch = any {
			my $type = defined $_->{column} ? $_->{column}->width->{type} : -1;
			$type == CLAY__SIZING_TYPE_GROW || $type == CLAY__SIZING_TYPE_PERCENT;
		} @$grid_columns;
		my $width = $stretch ? sizing_grow() : sizing_fit();
		foreach my $widget ( $_header_row, $_header_view, $_header_grid, $_body_row, $_body, $_body_grid ) {
			my $layout = $widget->layout;
			next if _same( $layout->{sizing}{width}, $width );
			$widget->layout( { %$layout, sizing => { %{ $layout->{sizing} // {} }, width => $width } } );
		}
		return;
	}

	# The lines of the page, or the one line of an empty view.
	method _body_lines () {
		my @lines = $model->page_lines;
		return @lines if @lines;
		return { kind => 'empty', key => EMPTY_LINE };
	}

	method _prepare_header ($grid_columns) {
		my $signature = join "\0", $model->columns_revision, $show_header, $filter_row, $selection, map { $_->{key} } @$grid_columns;
		return if $signature eq $_header_signature;
		$_header_signature = $signature;
		$_header_grid->clear_rows;
		@_header_cells = @_filter_cells = ();
		if ($show_header) {
			@_header_cells = map { $self->_header_cell($_) } @$grid_columns;
			$_header_grid->append_row( [ map { $_->{cell} } @_header_cells ] ) if @_header_cells;
		}
		if ($filter_row) {
			@_filter_cells = map { $self->_filter_cell($_) } @$grid_columns;
			$_header_grid->append_row( [ map { $_->{cell} } @_filter_cells ] ) if @_filter_cells;
		}
		# Without header rows, a row no taller than nothing keeps the header
		# grid, and with it the body, as wide as the columns.
		$_header_grid->append_row( [ map { $self->_ruler_cell($_) } @$grid_columns ] ) unless @_header_cells || @_filter_cells;
		return;
	}

	method _ruler_cell ($grid_column) {
		my $cell = $self->_new_cell( header => undef, $grid_column->{key}, $grid_column->{column} );
		$cell->layout( { %{ $cell->layout }, sizing => { %{ $cell->layout->{sizing} }, height => sizing_fixed(0) } } );
		return $cell;
	}

	method _new_cell ( $part, $line_key, $column_key, $column ) {
		my $align = defined $column ? ( $part eq 'header' ? $column->header_align : $column->align ) : 'left';
		return Term::Fabulous::Widget::Table::Cell->new(
			part       => $part,
			line_key   => $line_key,
			column_key => $column_key,
			layout     => {
				sizing          => { width => defined $column ? $column->width : sizing_fit(), height => sizing_fit() },
				padding         => {%$cell_padding},
				child_alignment => { x => $ALIGN_X{$align}, y => CLAY_ALIGN_Y_TOP },
			},
		);
	}

	method _header_cell ($grid_column) {
		my $column = $grid_column->{column};
		my $cell   = $self->_new_cell( header => undef, $grid_column->{key}, $column );
		unless ( defined $column ) {
			my $mark = Term::Fabulous::Widget::Text->new( text => MARK_UNCHECKED );
			$cell->add_child($mark);
			return { cell => $cell, mark => $mark };
		}
		my $marker = Term::Fabulous::Widget::Text->new( text => '', wrap_mode => CLAY_TEXT_WRAP_NONE );
		my $title;
		my $content;
		if ( defined $column->header ) {
			$content = _widget_from( "column '" . $column->key . "' header", $column->header->($column) );
		}
		else {
			$content = $title = Term::Fabulous::Widget::Text->new( text => $column->title, wrap_mode => $WRAP{ $column->wrap }, text_alignment => $TEXT_ALIGN{ $column->header_align } );
		}
		my $row = Term::Fabulous::Widget::Box->new;
		$row->add_child( $content, $marker );
		$cell->add_child($row);
		return { cell => $cell, title => $title, marker => $marker };
	}

	method _filter_cell ($grid_column) {
		my $column = $grid_column->{column};
		my $cell   = $self->_new_cell( filter => undef, $grid_column->{key}, $column );
		return { cell => $cell } unless defined $column && $column->filterable;
		my $key   = $column->key;
		my $field = Term::Fabulous::Widget::TextField->new(
			value                  => $_filter_text{$key} // '',
			placeholder            => "\x{2026}",
			text_color             => $text_color,
			focus_background_color => $cursor_color,
			layout                 => { sizing => { width => sizing_grow(0) } },    # one row high, as wide as the column
		);
		weaken( my $weak = $self );
		$field->on( Change => sub ($event) { $weak->_filter_typed( $key, $event->value ); return } );
		$field->on( Submit => sub ($event) { $weak->_focus_self; return } );
		$cell->add_child($field);
		return { cell => $cell, field => $field };
	}

	sub _widget_from ( $what, $widget ) {
		die "Term::Fabulous::Widget::Table: $what must return a widget, got " . _describe($widget)
			unless blessed $widget && ( $widget->DOES('Clay::UI::Role::Core::Element') || $widget->DOES('Clay::UI::Role::Core::TextNode') );
		return $widget;
	}

	# ---------------------------------------------------------------------
	# The body: one grid row per line of the page
	# ---------------------------------------------------------------------

	method _prepare_body ( $grid_columns, $lines ) {
		my $signature = join "\0", $model->columns_revision, $selection, map { $_->{key} } @$grid_columns;
		if ( $signature ne $_body_signature ) {
			$_body_signature = $signature;
			$_body_grid->clear_rows;
			%_built     = ();
			@_grid_keys = ();
		}

		my ( %wanted, %rebuilt );
		foreach my $line (@$lines) {
			my $key   = $line->{key};
			my $built = $_built{$key};
			$wanted{$key} = 1;
			if ( !defined $built || !$self->_still_fits( $built, $line ) ) {
				$_built{$key} = $self->_build_line( $line, $grid_columns );
				$rebuilt{$key} = 1 if defined $built;
				next;
			}
			$built->{line} = $line;
			$self->_refresh_row( $built, $grid_columns ) if $line->{kind} eq 'row' && $built->{revision} != $model->row_revision( $line->{id} );
		}

		my @gone = grep { !$wanted{ $_grid_keys[$_] } || $rebuilt{ $_grid_keys[$_] } } 0 .. $#_grid_keys;
		$_body_grid->remove_row($_) foreach reverse @gone;
		my %gone_index = map { $_ => 1 } @gone;
		@_grid_keys = map { $_grid_keys[$_] } grep { !$gone_index{$_} } 0 .. $#_grid_keys;
		delete @_built{ grep { !$wanted{$_} } keys %_built };

		my %placed = map { $_ => 1 } @_grid_keys;
		foreach my $line ( grep { !$placed{ $_->{key} } } @$lines ) {
			my $built = $_built{ $line->{key} };
			$built->{spanning} ? $_body_grid->append_spanning_row( $built->{cells}[0] ) : $_body_grid->append_row( $built->{cells} );
			push @_grid_keys, $line->{key};
		}

		my %index_of = map { $_grid_keys[$_] => $_ } 0 .. $#_grid_keys;
		my @order    = map { $index_of{ $_->{key} } } @$lines;
		$_body_grid->reorder_rows( \@order ) if join( ',', @order ) ne join( ',', 0 .. $#order );
		@_grid_keys = map { $_->{key} } @$lines;
		return;
	}

	# Whether a line built earlier can show the line now (its contents are
	# refreshed separately).
	method _still_fits ( $built, $line ) {
		return 0 if $built->{kind} ne $line->{kind};
		return 1 unless $line->{kind} eq 'row';
		return $built->{depth} == $line->{depth} ? 1 : 0;
	}

	method _build_line ( $line, $grid_columns ) {
		return $self->_build_row( $line, $grid_columns ) if $line->{kind} eq 'row';
		return $self->_build_group($line) if $line->{kind} eq 'group';
		my $cell = $self->_new_cell( body => $line->{key}, undef, undef );
		my $text = Term::Fabulous::Widget::Text->new( text => $model->is_filtered && $model->row_count ? $no_match_text : $empty_text );
		$cell->add_child($text);
		$cell->layout( { %{ $cell->layout }, sizing => { width => sizing_percent(1), height => sizing_fit() } } );
		return { kind => 'empty', line => $line, spanning => 1, cells => [$cell], label => $text };
	}

	# The hash a column's cell, update_cell and cell_style get.
	method _cell_context ( $id, $column ) {
		my $key = $column->key;
		return {
			value   => $model->value_of( $id, $key ),
			display => $model->display_of( $id, $key ),
			row     => $model->data_of($id),
			id      => $id,
			column  => $column,
			table   => $self,
		};
	}

	method _build_row ( $line, $grid_columns ) {
		my $id        = $line->{id};
		my $tree_key  = $self->_tree_column_key;
		my %built     = ( kind => 'row', line => $line, id => $id, depth => $line->{depth}, revision => $model->row_revision($id), cells => [], content => {}, text => {}, holder => {} );
		foreach my $grid_column (@$grid_columns) {
			my ( $key, $column ) = @{$grid_column}{qw(key column)};
			my $cell = $self->_new_cell( body => $line->{key}, $key, $column );
			push @{ $built{cells} }, $cell;
			unless ( defined $column ) {
				$built{mark} = Term::Fabulous::Widget::Text->new( text => MARK_UNCHECKED );
				$cell->add_child( $built{mark} );
				next;
			}
			my $content = $self->_cell_content( \%built, $column );
			my $holder  = $cell;
			if ( defined $tree_key && $key eq $tree_key ) {
				$holder = Term::Fabulous::Widget::Box->new( layout => { padding => { left => INDENT * $line->{depth} } } );
				$built{toggle_box} = Term::Fabulous::Widget::Table::Toggle->new( line_key => $line->{key} );
				$built{toggle}     = Term::Fabulous::Widget::Text->new( text => LEAF, wrap_mode => CLAY_TEXT_WRAP_NONE );
				$built{toggle_box}->add_child( $built{toggle} );
				$holder->add_child( $built{toggle_box} );
				$cell->add_child($holder);
			}
			$holder->add_child($content);
			$built{holder}{$key} = $holder;
		}
		return \%built;
	}

	# The widget showing a cell: the column's cell widget, or a Text.
	method _cell_content ( $built, $column ) {
		my $key = $column->key;
		if ( defined $column->cell ) {
			my $widget = _widget_from( "the cell of column '$key'", $column->cell->( $self->_cell_context( $built->{id}, $column ) ) );
			delete $built->{text}{$key};
			return $built->{content}{$key} = $widget;
		}
		my $text = Term::Fabulous::Widget::Text->new(
			text           => $model->display_of( $built->{id}, $key ),
			wrap_mode      => $WRAP{ $column->wrap },
			text_alignment => $TEXT_ALIGN{ $column->align },
		);
		$built->{text}{$key} = $text;
		return $built->{content}{$key} = $text;
	}

	# A row whose data changed: texts are updated, cell widgets brought up
	# to date by update_cell or built again.
	method _refresh_row ( $built, $grid_columns ) {
		$built->{revision} = $model->row_revision( $built->{id} );
		foreach my $column ( map { $_->{column} } grep { defined $_->{column} } @$grid_columns ) {
			my $key = $column->key;
			if ( my $text = $built->{text}{$key} ) {
				_set( $text, text => $model->display_of( $built->{id}, $key ) );
				next;
			}
			if ( defined $column->update_cell ) {
				$column->update_cell->( $built->{content}{$key}, $self->_cell_context( $built->{id}, $column ) );
				next;
			}
			my $holder = $built->{holder}{$key};
			my $old    = $built->{content}{$key};
			$holder->remove_children_with( sub ($child) { refaddr($child) == refaddr($old) } );
			$holder->add_child( $self->_cell_content( $built, $column ) );
		}
		return;
	}

	method _build_group ($line) {
		my $cell = $self->_new_cell( body => $line->{key}, undef, undef );
		$cell->layout( { %{ $cell->layout }, sizing => { width => sizing_percent(1), height => sizing_fit() } } );
		my $holder = Term::Fabulous::Widget::Box->new( layout => { padding => { left => INDENT * $line->{depth} } } );
		my $toggle = Term::Fabulous::Widget::Table::Toggle->new( line_key => $line->{key} );
		my $glyph  = Term::Fabulous::Widget::Text->new( text => OPEN, wrap_mode => CLAY_TEXT_WRAP_NONE );
		$toggle->add_child($glyph);
		$holder->add_child($toggle);
		$cell->add_child($holder);
		my %built = ( kind => 'group', line => $line, spanning => 1, cells => [$cell], holder => $holder, toggle => $glyph, toggle_box => $toggle, label_signature => '' );
		$self->_refresh_group_label( \%built );
		return \%built;
	}

	# The label of a group header: group_label's text or widget, or
	# "Title: value (count)".
	method _refresh_group_label ($built) {
		my $line      = $built->{line};
		my $signature = join "\0", $line->{display}, $line->{count};
		return if $signature eq $built->{label_signature};
		$built->{label_signature} = $signature;
		my $label = defined $group_label ? $group_label->( $self->_group_context($line) ) : $self->_default_group_label($line);
		if ( !ref $label && defined $built->{label} && $built->{label}->isa('Term::Fabulous::Widget::Text') ) {
			_set( $built->{label}, text => $label );
			return;
		}
		my $widget = ref $label ? _widget_from( 'group_label', $label ) : Term::Fabulous::Widget::Text->new( text => $label // '', bold => 1 );
		if ( defined $built->{label} ) {
			my $old = $built->{label};
			$built->{holder}->remove_children_with( sub ($child) { refaddr($child) == refaddr($old) } );
		}
		$built->{holder}->add_child($widget);
		$built->{label} = $widget;
		return;
	}

	method _group_context ($line) {
		return {
			column  => $model->column( $line->{column} ),
			value   => $line->{value},
			display => $line->{display},
			count   => $line->{count},
			path    => [ @{ $line->{path} } ],
			depth   => $line->{depth},
			ids     => [ @{ $line->{ids} } ],
			table   => $self,
		};
	}

	method _default_group_label ($line) {
		my $title = $model->column( $line->{column} )->title;
		my $shown = length $line->{display} ? $line->{display} : '(empty)';
		return "$title: $shown ($line->{count})";
	}

	# ---------------------------------------------------------------------
	# Dressing: colors, lines and markers of every cell
	# ---------------------------------------------------------------------

	# Sets a property only when it differs, so preparing a table that did
	# not change makes no further frame due.
	sub _set ( $widget, $property, $value ) {
		my $current = $widget->$property;
		return if _same( $current, $value );
		$widget->$property($value);
		return;
	}

	sub _same ( $left, $right ) {
		return !defined $right unless defined $left;
		return 0 unless defined $right;
		return _flat($left) eq _flat($right);
	}

	sub _flat ($value) {
		return "$value" unless ref $value;
		return 'S' . refaddr($value) if blessed $value;
		return 'A' . join( "\x{1F}", map { _flat($_) } @$value ) if ref $value eq 'ARRAY';
		return 'H' . join( "\x{1F}", map { "$_=" . _flat( $value->{$_} ) } sort keys %$value );
	}

	# Whether the keyboard is in the table: the table or a widget of its
	# body has the focus.
	method _has_focus_within () {
		my $ui = $self->ui // return 0;
		for ( my $node = $ui->interaction->get_focused_widget; defined $node; $node = $node->parent ) {
			return 1 if refaddr($node) == refaddr($self);
			return 0 if refaddr($node) == refaddr($_header_view) || ( defined $_chooser && refaddr($node) == refaddr($_chooser) ) || refaddr($node) == refaddr($_pager);
		}
		return 0;
	}

	method _row_style_for ($id) {
		my $dynamic = defined $row_style ? style_hash( $self, 'row_style result', row => $row_style->( $model->data_of($id), $id ) ) : {};
		return merge_styles( $_row_style_of{$id}, $dynamic );
	}

	method _cell_style_for ( $id, $column ) {
		my $static  = $_cell_style_of{ $id . "\0" . $column->key };
		my $dynamic = defined $column->cell_style ? style_hash( $self, "column '" . $column->key . "' cell_style result", cell => $column->cell_style->( $self->_cell_context( $id, $column ) ) ) : {};
		return merge_styles( $static, $dynamic );
	}

	# Whether styles depend on the data of rows (row_style, a column's
	# cell_style): then a change of a row may change its lines and looks.
	method _styles_follow_data ($grid_columns) {
		return 1 if defined $row_style;
		return ( any { defined $_->{column} && defined $_->{column}->cell_style } @$grid_columns ) ? 1 : 0;
	}

	# Colors, lines and marks of every cell. The grid lines are worked out
	# again only when something they depend on changed; a body line is
	# dressed again only when its look or the lines changed, so moving the
	# cursor dresses two lines.
	method _dress ( $grid_columns, $lines ) {
		my $follows_data = $self->_styles_follow_data($grid_columns);
		my @header_rows  = ( ( @_header_cells ? [ \@_header_cells, 'header' ] : () ), ( @_filter_cells ? [ \@_filter_cells, 'filter' ] : () ) );
		my $signature = join "\0", $model->columns_revision, $_style_revision, scalar @header_rows, scalar @$grid_columns,
			map { $_->{key} . ( $follows_data && $_->{kind} eq 'row' ? ':' . $model->row_revision( $_->{id} ) : '' ) } @$lines;
		if ( $signature ne $_borders_signature ) {
			$_borders_signature = $signature;
			$_borders           = $self->_resolve_lines( $grid_columns, \@header_rows, $lines );
			$_borders_generation++;
		}

		foreach my $index ( 0 .. $#header_rows ) {
			my ( $cells, $part ) = @{ $header_rows[$index] };
			foreach my $column ( 0 .. $#$cells ) {
				my $look = $part eq 'header' ? $self->_header_look( $column, $grid_columns->[$column] ) : $self->_filter_look( $cells->[$column], $grid_columns->[$column] );
				$self->_dress_cell( $cells->[$column]{cell}, $look, $_borders->[$index][$column], \$cells->[$column]{dressed} );
			}
		}
		$self->_mark_header($grid_columns) if @_header_cells;

		my $focused    = $self->_has_focus_within;
		my $cursor     = $model->cursor;
		my $data_index = 0;
		foreach my $index ( 0 .. $#$lines ) {
			my $line  = $lines->[$index];
			my $built = $_built{ $line->{key} };
			my $state
				= $focused && !defined $_header_cursor && defined $cursor && $cursor eq $line->{key} ? 'cursor'
				: $line->{kind} eq 'row' && $model->is_selected( $line->{id} )                      ? 'selected'
				: $hover && defined $_hover_key && $_hover_key eq $line->{key}                       ? 'hover'
				:                                                                                      '';
			my $stripe = $line->{kind} eq 'row' && defined $stripe_color && $data_index++ % 2 ? 1 : 0;
			my $look_key = join "\0", $_borders_generation, $state, $stripe, $self->_line_look_key($line);
			next if defined $built->{look_key} && $built->{look_key} eq $look_key;
			$built->{look_key} = $look_key;
			$self->_dress_line( $built, $line, $grid_columns, $state, $stripe, $_borders->[ @header_rows + $index ] );
		}
		return;
	}

	# What else a line's look depends on.
	method _line_look_key ($line) {
		return join "\0", $model->row_revision( $line->{id} ), $line->{has_children}, $line->{expanded}, $model->is_selected( $line->{id} ) if $line->{kind} eq 'row';
		return join "\0", $line->{expanded}, $line->{count}, $line->{display} if $line->{kind} eq 'group';
		return $model->is_filtered && $model->row_count ? 'no match' : 'empty';
	}

	method _state_color ($state) {
		return $state eq 'cursor' ? $cursor_color : $state eq 'selected' ? $selected_color : $state eq 'hover' ? $hover_color : undef;
	}

	# The grid lines of the header rows and the lines.
	method _resolve_lines ( $grid_columns, $header_rows, $lines ) {
		my @border_lines = map { { style => $header_style, cells => [ map { {} } @$grid_columns ] } } @$header_rows;
		foreach my $line (@$lines) {
			if ( $line->{kind} eq 'row' ) {
				my $id = $line->{id};
				push @border_lines, {
					style => $self->_row_style_for($id),
					cells => [ map { defined $_->{column} ? $self->_cell_style_for( $id, $_->{column} ) : {} } @$grid_columns ],
				};
				next;
			}
			push @border_lines, { spanning => 1, style => $line->{kind} eq 'group' ? $group_style : {}, cells => [ {} ] };
		}
		return resolve_borders(
			columns       => scalar @$grid_columns,
			header        => scalar @$header_rows,
			table         => \%_line_style,
			column_styles => [ map { defined $_->{column} ? $_->{column}->style : {} } @$grid_columns ],
			lines         => \@border_lines,
		);
	}

	method _dress_line ( $built, $line, $grid_columns, $state, $stripe, $borders ) {
		my $state_color = $self->_state_color($state);
		if ( $line->{kind} eq 'row' ) {
			my $id    = $line->{id};
			my $row   = $self->_row_style_for($id);
			my @looks = map {
				my $cell = defined $grid_columns->[$_]{column} ? $self->_cell_style_for( $id, $grid_columns->[$_]{column} ) : {};
				$self->_body_look( $state_color // ( $stripe ? $stripe_color : undef ), $row, $cell, $grid_columns->[$_]{column}, defined $state_color );
			} 0 .. $#$grid_columns;
			$built->{dressed} //= [];
			$self->_dress_cell( $built->{cells}[$_], $looks[$_], $borders->[$_], \$built->{dressed}[$_] ) foreach 0 .. $#looks;
			$self->_mark_row( $built, $line, $grid_columns, \@looks );
			return;
		}
		my $look = $line->{kind} eq 'group' ? $self->_group_look($state_color) : $self->_empty_look;
		$self->_dress_cell( $built->{cells}[0], $look, $borders->[0], \$built->{dressed} );
		if ( $line->{kind} eq 'group' ) {
			$self->_refresh_group_label($built);
			_set( $built->{toggle}, text => $line->{expanded} ? OPEN : CLOSED );
			$self->_dress_text( $built->{toggle}, $look );
			_set( $built->{toggle_box}, background_color => $look->{background_color} );
		}
		else {
			_set( $built->{label}, text => $model->is_filtered && $model->row_count ? $no_match_text : $empty_text );
		}
		$self->_dress_text( $built->{label}, $look ) if defined $built->{label} && $built->{label}->isa('Term::Fabulous::Widget::Text');
		return;
	}

	method _header_look ( $index, $grid_column ) {
		my $column = $grid_column->{column};
		my $style  = merge_styles( defined $column ? $column->header_style : {}, $header_style );
		my $active = defined $_header_cursor && $_header_cursor == $index && $self->_has_focus_within;
		return {
			background_color => $active ? $cursor_color : $style->{background_color} // $header_background_color,
			text_color       => $style->{text_color} // $header_text_color,
			bold             => $style->{bold} // 1,
			italic           => $style->{italic} // 0,
			underline        => $style->{underline} // 0,
			border_color     => $style->{border_color} // $line_color,
		};
	}

	method _filter_look ( $cell, $grid_column ) {
		my $column = $grid_column->{column};
		if ( defined $cell->{field} ) {
			my $error = defined $_filter_error{ $column->key };
			_set( $cell->{field}, text_color => $error ? $error_color : $text_color );
		}
		return { background_color => $filter_background_color, border_color => $line_color };
	}

	method _group_look ($state_color) {
		my $style = $group_style;
		return {
			background_color => $state_color // $style->{background_color} // $group_background_color,
			text_color       => $style->{text_color} // $group_text_color,
			bold             => $style->{bold} // 1,
			italic           => $style->{italic} // 0,
			underline        => $style->{underline} // 0,
			border_color     => $style->{border_color} // $line_color,
		};
	}

	method _body_look ( $base_color, $row, $cell, $column, $state_wins ) {
		my $column_style = defined $column ? $column->style : {};
		my $look = merge_styles( $cell, $row, $column_style );
		my $background = ( $state_wins ? $base_color : $look->{background_color} // $base_color ) // $self->_base_background;
		return {
			background_color => $background,
			text_color       => $look->{text_color} // $text_color,
			bold             => $look->{bold} // 0,
			italic           => $look->{italic} // 0,
			underline        => $look->{underline} // 0,
			border_color     => $look->{border_color} // $line_color,
		};
	}

	# Gives a cell its look and lines; $memo holds what it was given last
	# time, so an unchanged cell costs one string comparison.
	method _dress_cell ( $cell, $look, $border, $memo ) {
		my $sides = $border->{sides};
		my %properties = (
			background_color   => $look->{background_color},
			border_color       => $look->{border_color},
			border_width       => { map { $_ => $sides->{$_} ? 1 : 0 } qw(top right bottom left) },
			border_corners     => %{ $border->{corners} } ? $border->{corners} : undef,
			outer_border_sides => $border->{outer},
			map { ( "border_style_$_" => $sides->{$_} ) } qw(top right bottom left),
		);
		my $signature = join "\x{1E}", map { "$_=" . ( defined $properties{$_} ? _flat( $properties{$_} ) : '' ) } sort keys %properties;
		return if defined $$memo && $$memo eq $signature;
		$$memo = $signature;
		$cell->$_( $properties{$_} ) foreach sort keys %properties;
		return;
	}

	method _dress_text ( $text, $look ) {
		_set( $text, text_color => $look->{text_color} );
		_set( $text, $_ => $look->{$_} // 0 ) foreach qw(bold italic underline);
		return;
	}

	# The marks of a data row - the selection mark, the tree marker - and
	# the look of its texts.
	method _mark_row ( $built, $line, $grid_columns, $looks ) {
		my $tree_key = $self->_tree_column_key // "\0";
		foreach my $index ( 0 .. $#$grid_columns ) {
			my ( $key, $look ) = ( $grid_columns->[$index]{key}, $looks->[$index] );
			if ( $key eq SELECT_COLUMN ) {
				_set( $built->{mark}, text => $model->is_selected( $line->{id} ) ? MARK_CHECKED : MARK_UNCHECKED );
				$self->_dress_text( $built->{mark}, $look );
				next;
			}
			$self->_dress_text( $built->{text}{$key}, $look ) if defined $built->{text}{$key};
			next unless $key eq $tree_key && defined $built->{toggle};
			_set( $built->{toggle}, text => !$line->{has_children} ? LEAF : $line->{expanded} ? OPEN : CLOSED );
			$self->_dress_text( $built->{toggle}, $look );
			_set( $built->{toggle_box}, background_color => $look->{background_color} );
		}
		return;
	}

	method _empty_look () {
		return { background_color => $self->_base_background, text_color => $muted_color, border_color => $line_color, italic => 1 };
	}

	# The color of cells that have none of their own: the table's
	# background, or that of its nearest ancestor with an opaque one, so
	# the cells blend in. Cells are always painted: only painted cells
	# receive the mouse.
	method _base_background () {
		for ( my $node = $self; defined $node; $node = $node->parent ) {
			next unless $node->can('background_color');
			my $color = $node->background_color // next;
			return $color if $color->[3] == 255;
		}
		return FALLBACK_BACKGROUND;
	}

	method _mark_header ($grid_columns) {
		my @sort = @{ $model->sort_spec };
		foreach my $index ( 0 .. $#_header_cells ) {
			my $cell   = $_header_cells[$index];
			my $look   = $self->_header_look( $index, $grid_columns->[$index] );
			if ( defined $cell->{mark} ) {
				_set( $cell->{mark}, text => $self->_select_all_mark );
				$self->_dress_text( $cell->{mark}, $look );
				next;
			}
			my $key      = $grid_columns->[$index]{key};
			my ($place)  = grep { $sort[$_][0] eq $key } 0 .. $#sort;
			my $marker   = !defined $place ? '' : ' ' . ( $sort[$place][1] eq 'asc' ? SORT_UP : SORT_DOWN ) . ( @sort > 1 ? $place + 1 : '' );
			_set( $cell->{marker}, text => $marker );
			$self->_dress_text( $cell->{marker}, $look );
			$self->_dress_text( $cell->{title}, $look ) if defined $cell->{title};
		}
		return;
	}

	method _select_all_mark () {
		my @ids = $model->filtered_row_ids;
		my $selected = grep { $model->is_selected($_) } @ids;
		return !@ids || !$selected ? MARK_UNCHECKED : $selected == @ids ? MARK_CHECKED : MARK_SOME;
	}

	# ---------------------------------------------------------------------
	# Scrollbar, pager, scrolling
	# ---------------------------------------------------------------------

	# The scrollbar right of the body, and a spacer as wide as it right of
	# the header, so that header and body are clipped at the same width.
	method _prepare_scrollbar () {
		_show_child( $_body_row,   $_scrollbar,     $scrollbar );
		_show_child( $_header_row, $_header_spacer, $scrollbar );
		return;
	}

	sub _show_child ( $parent, $child, $show ) {
		my $shown = grep { refaddr($_) == refaddr($child) } @{ $parent->children };
		$parent->add_child($child) if $show && !$shown;
		$parent->remove_children_with( sub ($node) { refaddr($node) == refaddr($child) } ) if !$show && $shown;
		return;
	}

	method _pager_shown () {
		return $show_pager // ( $model->page_size > 0 ? 1 : 0 );
	}

	method _prepare_pager () {
		my $attached = grep { refaddr($_) == refaddr($_pager) } @{ $self->children };
		if ( !$self->_pager_shown ) {
			$self->remove_children_with( sub ($child) { refaddr($child) == refaddr($_pager) } ) if $attached;
			return;
		}
		$self->add_child($_pager) unless $attached;
		my $size  = $model->page_size;
		my $total = $model->line_count;
		my $first = $size ? ( $model->page - 1 ) * $size + 1 : 1;
		my $last  = $size ? min( $total, $first + $size - 1 ) : $total;
		$_pager->show( page => $model->page, page_count => $model->page_count, page_size => $size || $total || 1, first => $first, last => $last, total => $total );
		return;
	}

	# A new page starts at the top; a cursor that moved is scrolled into
	# view once the frame that lays its line out is drawn.
	method _prepare_scrolling () {
		my $ui = $self->ui // return;
		if ( $model->page != $_shown_page ) {
			$_shown_page = $model->page;
			$ui->scroll_to( $_body, { x => 0, y => 0 } );
		}
		return unless $_reveal_cursor;
		$_reveal_cursor = 0;
		weaken( my $weak = $self );
		$ui->after_draw( sub { $weak->_scroll_cursor_into_view if $weak } ) if $ui->can('after_draw');
		return;
	}

	# The rows of the body's viewport and of a line, in the last frame.
	method _line_box ($key) {
		my $ui    = $self->ui // return undef;
		my $built = $_built{ $key // '' } // return undef;
		my $box   = $ui->bounding_box( $built->{cells}[0] ) // return undef;
		my $state = $ui->scroll_state($_body) // return undef;
		my $body  = $ui->bounding_box($_body) // return undef;
		return { top => $box->{y} - $body->{y}, height => $box->{height}, viewport => $state->{viewport}{height}, position => $state->{position}{y} };
	}

	method _scroll_cursor_into_view () {
		my $ui  = $self->ui // return;
		my $box = $self->_line_box( $model->cursor ) // return;
		my $position = $box->{position};
		if ( $box->{top} < 0 ) {
			$position -= $box->{top};
		}
		elsif ( $box->{top} + $box->{height} > $box->{viewport} ) {
			$position -= min( $box->{top}, $box->{top} + $box->{height} - $box->{viewport} );
		}
		$ui->scroll_to( $_body, { y => $position } ) if $position != $box->{position};
		return;
	}

	# How many lines of the page fit into the body's viewport, for PageUp
	# and PageDown.
	method _page_step () {
		my $ui = $self->ui // return DEFAULT_PAGE_STEP;
		my $state = $ui->scroll_state($_body) // return DEFAULT_PAGE_STEP;
		my @heights = grep { defined } map { my $built = $_built{$_}; defined $built ? ( $ui->bounding_box( $built->{cells}[0] ) // {} )->{height} : undef } @_grid_keys;
		return DEFAULT_PAGE_STEP unless @heights;
		my $average = ( List::Util::sum(@heights) / @heights ) || 1;
		return max( 1, int( $state->{viewport}{height} / $average ) - 1 );
	}

	# ---------------------------------------------------------------------
	# Input
	# ---------------------------------------------------------------------

	method _listen () {
		weaken( my $weak = $self );
		$self->on( KeyPress  => sub ($event) { return $weak ? $weak->_on_key($event) : $CONTINUE } );
		$self->on( Mouse     => sub ($event) { return $weak ? $weak->_on_mouse($event) : $CONTINUE } );
		$self->on( MouseMove => sub ($event) { $weak->_on_mouse_move($event) if $weak; return $CONTINUE } );
		foreach my $name (qw(OnFocus OnBlur)) {
			$self->on( $name => sub ($event) { $weak->_changed if $weak; return $CONTINUE } );
		}
		$self->on( OnHoverStopped => sub ($event) { $weak->_hover_line(undef) if $weak && refaddr( $event->target ) == refaddr($weak); return $CONTINUE } );
		return;
	}

	# Which part of the table a widget belongs to.
	method _region_of ($widget) {
		for ( my $node = $widget; defined $node; $node = $node->parent ) {
			my $address = refaddr $node;
			return 'body'    if $address == refaddr($_body_row);
			return 'header'  if $address == refaddr($_header_view);
			return 'pager'   if $address == refaddr($_pager);
			return 'chooser' if defined $_chooser && $address == refaddr($_chooser);
			return 'table'   if $address == refaddr($self);
		}
		return 'table';
	}

	# Whether a widget between $widget and the table takes input of its own
	# (a button or a field in a cell).
	# A widget without a background of its own is not hit by the mouse: a
	# click on such a button makes its cell the target, so the widgets of
	# the cell under the pointer count, too.
	method _inside_input ($event) {
		for ( my $node = $event->target; defined $node && refaddr($node) != refaddr($self); $node = $node->parent ) {
			return 1 if _takes_input($node);
			return $self->_input_under_pointer( $node, $event->x, $event->y ) if $node->isa('Term::Fabulous::Widget::Table::Cell');
		}
		return 0;
	}

	sub _takes_input ($widget) {
		return $widget->DOES('Clay::UI::Role::Interaction::Focusable') || $widget->DOES('Clay::UI::Role::Interaction::Pressable') ? 1 : 0;
	}

	method _input_under_pointer ( $widget, $x, $y ) {
		my $ui = $self->ui // return 0;
		return 0 unless $widget->can('children');
		foreach my $child ( @{ $widget->children } ) {
			my $box = $ui->bounding_box($child) // next;
			next unless $x >= $box->{x} && $x < $box->{x} + $box->{width} && $y >= $box->{y} && $y < $box->{y} + $box->{height};
			return 1 if _takes_input($child) || $self->_input_under_pointer( $child, $x, $y );
		}
		return 0;
	}

	method _on_key ($event) {
		my $name   = $event->key_name // return $CONTINUE;
		my $region = $self->_region_of( $event->target );
		if ( $region eq 'header' ) {
			return $self->_on_filter_key( $event, $name );
		}
		return $CONTINUE unless $region eq 'table' || $region eq 'body';
		return $self->_on_header_key($name) if defined $_header_cursor;
		my $from_cell = $region eq 'body' && refaddr( $event->target ) != refaddr($self);
		return $CONTINUE unless $self->_on_body_key( $name, $from_cell );
		$self->_focus_self if $from_cell;    # the keyboard follows the cursor out of the cell
		return $HANDLED;
	}

	method _on_filter_key ( $event, $name ) {
		if ( $name eq 'Down' ) {
			$self->_focus_self;
			return $HANDLED;
		}
		if ( $name eq 'Escape' ) {
			my ($cell) = grep { defined $_->{field} && refaddr( $_->{field} ) == refaddr( $event->target ) } @_filter_cells;
			return $CONTINUE unless defined $cell && length $cell->{field}->value;
			$cell->{field}->value('');
			$self->_filter_typed( $cell->{cell}->column_key, '' );
			return $HANDLED;
		}
		return $CONTINUE;
	}

	method _focus_self () {
		my $ui = $self->ui // return;
		$ui->interaction->set_focused_widget($self) if $self->can_focus;
		return;
	}

	# Keys on the rows. Returns whether the key was used. $from_cell: the
	# key comes from a widget inside a cell, which has used the keys it
	# wants; Space and Enter are left to it.
	method _on_body_key ( $name, $from_cell ) {
		my $cursor = $model->cursor;
		my $line   = defined $cursor ? $model->line($cursor) : undef;
		my %move = (
			Up       => -1,
			Down     => 1,
			PageUp   => -$self->_page_step,
			PageDown => $self->_page_step,
		);
		my $base = $name =~ s/\AShift\+//r;
		my $extend = $base ne $name && $selection eq 'multiple';
		if ( exists $move{$base} && ( $base eq $name || $extend ) ) {
			return $self->_enter_header if $base eq 'Up' && defined $line && $self->_is_first_on_page($cursor) && !$extend && $self->_header_usable;
			$self->_move_within_page( $move{$base}, $extend );
			return 1;
		}
		if ( ( $base eq 'Home' || $base eq 'End' ) && ( $base eq $name || $extend ) ) {
			my @lines = $model->page_lines;
			return 1 unless @lines;
			$self->_move_cursor( ( $base eq 'Home' ? $lines[0] : $lines[-1] )->{key}, extend => $extend );
			return 1;
		}
		my %jump = (
			'Ctrl+Home'     => sub { $self->_move_cursor( $model->first_line_key ) },
			'Ctrl+End'      => sub { $self->_move_cursor( $model->last_line_key ) },
			'Ctrl+PageUp'   => sub { $self->_turn_page( $model->page - 1 ) },
			'Ctrl+PageDown' => sub { $self->_turn_page( $model->page + 1 ) },
		);
		if ( exists $jump{$name} ) {
			$jump{$name}->();
			return 1;
		}
		return $self->_select_all_by_user if $name eq 'Ctrl+A' && $selection eq 'multiple';
		return 0 unless defined $line;

		if ( $line->{kind} eq 'group' ) {
			return $self->_toggle_line( $line, !$line->{expanded} ) if $name eq 'Enter' || $name eq 'Space';
			return $self->_toggle_line( $line, 1 ) if $name eq '+' || ( $name eq 'Right' && !$line->{expanded} );
			return $self->_toggle_line( $line, 0 ) if $name eq '-' || ( $name eq 'Left' && $line->{expanded} );
			if ( $name eq 'Right' ) {
				$self->_move_cursor( $self->_line_after($cursor) );
				return 1;
			}
			return $self->_move_to_parent_group($line) if $name eq 'Left';
			return 0;
		}
		return 0 unless $line->{kind} eq 'row';
		if ( $name eq 'Enter' && !$from_cell ) {
			$self->fire_event( Term::Fabulous::Event::RowActivate->new( row_id => $line->{id}, row => $model->row( $line->{id} ) ) );
			return 1;
		}
		if ( $name eq 'Space' && !$from_cell ) {
			return $self->_toggle_selection_by_user( $line->{id} ) if $selection eq 'multiple';
			return $self->_select_by_user( $line->{id} )           if $selection eq 'single';
			return 0;
		}
		return $self->_toggle_line( $line, 1 ) if ( $name eq '+' || $name eq 'Right' ) && $line->{has_children} && !$line->{expanded};
		return $self->_toggle_line( $line, 0 ) if ( $name eq '-' || $name eq 'Left' ) && $line->{has_children} && $line->{expanded};
		if ( $name eq 'Right' && $line->{has_children} ) {
			$self->_move_cursor( $self->_line_after($cursor) );
			return 1;
		}
		return $self->_move_to_parent($line) if $name eq 'Left' && ( defined $model->parent_of( $line->{id} ) || $model->group_by );
		return 0;
	}

	method _header_usable () {
		return $show_header && @_header_cells ? 1 : 0;
	}

	method _is_first_on_page ($key) {
		my ($first) = $model->page_lines;
		return defined $first && $first->{key} eq $key ? 1 : 0;
	}

	method _line_after ($key) {
		my @lines = $model->page_lines;
		my $index = first { $lines[$_]{key} eq $key } 0 .. $#lines;
		return defined $index && $index < $#lines ? $lines[ $index + 1 ]{key} : $key;
	}

	method _move_within_page ( $steps, $extend ) {
		my @lines = $model->page_lines;
		return unless @lines;
		my $cursor = $model->cursor;
		my $index  = first { $lines[$_]{key} eq $cursor } 0 .. $#lines;
		$index = max( 0, min( $#lines, ( $index // 0 ) + $steps ) );
		$self->_move_cursor( $lines[$index]{key}, extend => $extend );
		return;
	}

	method _move_to_parent ($line) {
		my $parent = $model->parent_of( $line->{id} );
		my $key    = defined $parent ? Term::Fabulous::Widget::Table::Model::row_key($parent) : undef;
		if ( defined $key && defined $model->line_index($key) ) {
			$self->_move_cursor($key);
			return 1;
		}
		return $self->_move_to_parent_group($line);
	}

	# The nearest group header above the line, of a lower level for a group.
	method _move_to_parent_group ($line) {
		my @lines = $model->lines;
		my $index = $model->line_index( $line->{key} ) // return 1;
		my $limit = $line->{kind} eq 'group' ? $line->{depth} : 9**9;
		for ( my $at = $index - 1; $at >= 0; $at-- ) {
			next unless $lines[$at]{kind} eq 'group' && $lines[$at]{depth} < $limit;
			$self->_move_cursor( $lines[$at]{key} );
			return 1;
		}
		return 1;
	}

	# Moves the cursor as the user does: fires CursorMove, selects in
	# single mode, extends the selection with extend, turns the page.
	method _move_cursor ( $key, %options ) {
		return 0 unless defined $key;
		my $page_before = $model->page;
		my $anchor      = $model->anchor // $model->cursor;
		my $moved       = $model->set_cursor($key);
		$self->_after_cursor_moved( $moved, $page_before );
		my $id = Term::Fabulous::Widget::Table::Model::id_of_key($key);
		if ( $options{extend} && defined $anchor && defined $model->line_index($anchor) ) {
			$model->set_anchor($anchor);
			my @ids = grep { defined } map { Term::Fabulous::Widget::Table::Model::id_of_key($_) } $model->line_keys_between( $anchor, $key );
			$self->_select_by_user( $options{add} ? ( $model->selected_ids, @ids ) : @ids );
		}
		else {
			$model->set_anchor($key);
			$self->_select_by_user($id) if $selection eq 'single' && defined $id && $moved;
		}
		return $moved;
	}

	method _after_cursor_moved ( $moved, $page_before ) {
		return unless $moved || $model->page != $page_before;
		$_reveal_cursor = 1;
		$self->_changed;
		if ($moved) {
			my $line = $model->line( $model->cursor );
			$self->fire_event( Term::Fabulous::Event::CursorMove->new(
				row_id     => $line->{kind} eq 'row' ? $line->{id} : undef,
				group_path => $line->{kind} eq 'group' ? $line->{path} : undef,
			) );
		}
		$self->_fire_page_change if $model->page != $page_before;
		return;
	}

	method _fire_page_change () {
		$self->fire_event( Term::Fabulous::Event::PageChange->new( page => $model->page, page_size => $model->page_size ) );
		return;
	}

	# Turns the page as the user does. The cursor goes to the page's first
	# line, as for any other move by the user: CursorMove and PageChange
	# fire, a range starts there, and in single mode the row is selected.
	method _turn_page ($page) {
		$page = max( 1, min( $page, $model->page_count ) );
		my ( $page_before, $cursor_before ) = ( $model->page, $model->cursor );
		return 0 unless $model->set_page($page);
		my $key   = $model->cursor;
		my $moved = _same( $cursor_before, $key ) ? 0 : 1;
		$self->_after_cursor_moved( $moved, $page_before );
		$model->set_anchor($key);
		my $id = Term::Fabulous::Widget::Table::Model::id_of_key($key);
		$self->_select_by_user($id) if $selection eq 'single' && defined $id && $moved;
		return 1;
	}

	method _change_page_size ($size) {
		return unless $model->set_page_size($size);
		$_reveal_cursor = 1;
		$self->_changed;
		$self->_fire_page_change;
		return;
	}

	# Selection changes the user makes fire SelectionChange.
	method _select_by_user (@ids) {
		return $self->_selection_event( $model->set_selection(@ids) );
	}

	method _toggle_selection_by_user ($id) {
		return $self->_selection_event( $model->toggle_selected($id) );
	}

	method _select_all_by_user () {
		my @ids = $model->filtered_row_ids;
		my $all = @ids && !grep { !$model->is_selected($_) } @ids;
		return $self->_selection_event( $all ? $model->deselect(@ids) : $model->select(@ids) );
	}

	method _selection_event ( $added, $removed ) {
		return 1 unless @$added || @$removed;
		$self->_changed;
		$self->fire_event( Term::Fabulous::Event::SelectionChange->new( selected_ids => [ $model->selected_ids ], added_ids => $added, removed_ids => $removed ) );
		return 1;
	}

	# Opens or closes a group or tree row as the user does.
	method _toggle_line ( $line, $open ) {
		my $changed
			= $line->{kind} eq 'group'
			? $model->set_group_collapsed( $line->{path}, $open ? 0 : 1 )
			: $model->set_expanded( $line->{id}, $open );
		return 1 unless $changed;
		$self->_changed;
		my $class = $open ? 'Term::Fabulous::Event::Expand' : 'Term::Fabulous::Event::Collapse';
		$self->fire_event( $class->new(
			row_id     => $line->{kind} eq 'row'   ? $line->{id}   : undef,
			group_path => $line->{kind} eq 'group' ? $line->{path} : undef,
		) );
		return 1;
	}

	# The header has the keyboard: the header cursor picks a column.
	method _enter_header () {
		$_header_cursor = first { defined $_header_cells[$_]{marker} || defined $_header_cells[$_]{mark} } 0 .. $#_header_cells;
		$_header_cursor //= 0;
		$self->_changed;
		return 1;
	}

	method _leave_header () {
		$_header_cursor = undef;
		$_reveal_cursor = 1;
		$self->_changed;
		return $HANDLED;
	}

	method _on_header_key ($name) {
		my $last = $#_header_cells;
		return $self->_leave_header if $name eq 'Down' || $name eq 'Escape' || $last < 0;
		my %target = ( Left => $_header_cursor - 1, Right => $_header_cursor + 1, Home => 0, End => $last );
		if ( exists $target{$name} ) {
			$_header_cursor = max( 0, min( $last, $target{$name} ) );
			$self->_changed;
			return $HANDLED;
		}
		my @grid_columns = $self->_grid_columns;
		my $key          = $grid_columns[$_header_cursor]{key} // return $CONTINUE;
		if ( $name eq 'Enter' || $name eq 'Space' ) {
			if ( $key eq SELECT_COLUMN ) {
				$self->_select_all_by_user;
				return $HANDLED;
			}
			$self->_sort_by_user( $key, $name eq 'Space' );
			return $HANDLED;
		}
		if ( $name eq 'c' ) {
			$self->open_column_chooser;
			return $HANDLED;
		}
		return $CONTINUE;
	}

	method _sort_by_user ( $key, $add ) {
		return unless $model->column($key)->sortable;
		return unless $model->cycle_sort( $key, $add );
		$_reveal_cursor = 1;
		$self->_changed;
		$self->fire_event( Term::Fabulous::Event::SortChange->new( sort => $model->sort_spec ) );
		return;
	}

	# ---------------------------------------------------------------------
	# Mouse
	# ---------------------------------------------------------------------

	# The table widget a mouse event is about: a toggle, the scrollbar or a
	# cell, and the widget it hit.
	method _hit ($target) {
		for ( my $node = $target; defined $node && refaddr($node) != refaddr($self); $node = $node->parent ) {
			return ( toggle    => $node ) if $node->isa('Term::Fabulous::Widget::Table::Toggle');
			return ( scrollbar => $node ) if $node->isa('Term::Fabulous::Widget::Table::Scrollbar');
			return ( cell      => $node ) if $node->isa('Term::Fabulous::Widget::Table::Cell');
		}
		return ();
	}

	method _on_mouse ($event) {
		my ( $kind, $widget ) = $self->_hit( $event->target );
		return $CONTINUE unless defined $kind;
		my $key    = $event->key;
		my $motion = $event->modifiers & TB_MOD_MOTION;

		if ( $kind eq 'scrollbar' ) {
			return $CONTINUE unless $key == TB_KEY_MOUSE_LEFT;
			my ( undef, $top ) = $widget->content_origin;
			my $position = defined $top ? $widget->position_at_row( $event->y - $top ) : undef;
			$self->ui->scroll_to( $_body, { y => $position } ) if defined $position && defined $self->ui;
			return $HANDLED;
		}
		return $CONTINUE if $motion;
		if ( $key == TB_KEY_MOUSE_RIGHT ) {
			return $CONTINUE unless $kind eq 'cell' && $widget->part eq 'header';
			$self->open_column_chooser;
			return $HANDLED;
		}
		return $CONTINUE unless $key == TB_KEY_MOUSE_LEFT;

		if ( $kind eq 'toggle' ) {
			my $line = $model->line( $widget->line_key ) // return $HANDLED;
			$self->_move_cursor( $line->{key} );
			$self->_toggle_line( $line, !$line->{expanded} ) if $line->{kind} eq 'group' || $line->{has_children};
			return $HANDLED;
		}
		return $self->_click_header( $widget, $event ) if $widget->part eq 'header';
		return $CONTINUE unless $widget->part eq 'body';
		return $self->_click_line( $widget, $event );
	}

	method _click_header ( $cell, $event ) {
		$_header_cursor = undef;
		my $key = $cell->column_key // return $HANDLED;
		if ( $key eq SELECT_COLUMN ) {
			$self->_select_all_by_user;
			return $HANDLED;
		}
		my $add = $event->modifiers & ( TB_MOD_SHIFT | TB_MOD_CTRL | TB_MOD_ALT ) ? 1 : 0;
		$self->_sort_by_user( $key, $add );
		return $HANDLED;
	}

	method _click_line ( $cell, $event ) {
		my $line = $model->line( $cell->line_key // '' ) // return $HANDLED;
		my $now  = Time::HiRes::time();
		my $double = @_last_press && $_last_press[1] eq $line->{key} && $now - $_last_press[0] <= $double_click_seconds;
		@_last_press = $double ? () : ( $now, $line->{key} );
		$_header_cursor = undef;

		if ( $line->{kind} eq 'group' ) {
			$self->_move_cursor( $line->{key} );
			$self->_toggle_line( $line, !$line->{expanded} );
			return $HANDLED;
		}
		my $in_input = $self->_inside_input($event);
		my $mods     = $event->modifiers;
		my $id       = $line->{id};
		if ( $in_input || $selection ne 'multiple' ) {
			$self->_move_cursor( $line->{key} );
		}
		elsif ( defined $cell->column_key && $cell->column_key eq SELECT_COLUMN || $mods & ( TB_MOD_CTRL | TB_MOD_ALT ) ) {
			$self->_move_cursor( $line->{key} );
			$self->_toggle_selection_by_user($id);
		}
		elsif ( $mods & TB_MOD_SHIFT ) {
			$self->_move_cursor( $line->{key}, extend => 1 );
		}
		else {
			$self->_move_cursor( $line->{key} );
			$self->_select_by_user($id);
		}
		$self->_select_by_user($id) if $selection eq 'single' && !$in_input;
		$self->fire_event( Term::Fabulous::Event::RowActivate->new( row_id => $id, row => $model->row($id) ) ) if $double && !$in_input;
		return $HANDLED;
	}

	method _on_mouse_move ($event) {
		return unless $hover;
		my ( $kind, $widget ) = $self->_hit( $event->target );
		my $key = defined $kind && $kind eq 'cell' && $widget->part eq 'body' ? $widget->line_key : undef;
		$self->_hover_line($key);
		return;
	}

	method _hover_line ($key) {
		return if _same( $key, $_hover_key );
		$_hover_key = $key;
		$self->_changed;
		return;
	}

	# ---------------------------------------------------------------------
	# The filter row
	# ---------------------------------------------------------------------

	method _filter_typed ( $key, $text ) {
		my $error = $self->_apply_filter_text( $key, $text );
		$self->fire_event( Term::Fabulous::Event::FilterChange->new( column => $key, text => $text, error => $error ) );
		return;
	}

	# Applies the expression of a filter field; returns the error message,
	# or undef.
	method _apply_filter_text ( $key, $text ) {
		my $column = $model->column($key);
		$_filter_text{$key} = $text;
		delete $_filter_error{$key};
		my $filter;
		my $ok = eval {
			$filter = Term::Fabulous::Widget::Table::Filter->parse( $text, column => $key, type => $column->type, on => $column->filter_on );
			1;
		};
		unless ($ok) {
			( $_filter_error{$key} = $@ ) =~ s/\ATerm::Fabulous::Widget::Table::Filter: //;
			$_filter_error{$key} =~ s/\s+\z//;
		}
		$model->set_filter( "column:$key" => $ok ? $filter : undef );
		$model->expand_to_matches;
		$_reveal_cursor = 1;
		$self->_changed;
		return $_filter_error{$key};
	}

	# =====================================================================
	# Public methods
	# =====================================================================

	# --- Rows ------------------------------------------------------------

	method rows (@new) {
		return $model->rows unless @new;
		$model->set_rows( $new[0] );
		$self->_rows_changed;
		return $self;
	}

	method _rows_changed () {
		%_row_style_of  = map { $_ => $_row_style_of{$_} } grep { $model->has_row($_) } keys %_row_style_of;
		%_cell_style_of = map { $_ => $_cell_style_of{$_} } grep { $model->has_row( ( split /\0/, $_, 2 )[0] ) } keys %_cell_style_of;
		$model->expand_to_matches;
		$self->_changed;
		return;
	}

	method add_row ( $row, %options ) {
		my ($id) = $model->add_rows( [$row], %options );
		$self->_rows_changed;
		return $id;
	}

	method add_rows ( $rows, %options ) {
		my @ids = $model->add_rows( $rows, %options );
		$self->_rows_changed;
		return @ids;
	}

	method update_row ( $id, $changes ) {
		$model->update_row( $id, $changes );
		$self->_data_changed;
		return $self;
	}

	method replace_row ( $id, $row ) {
		$model->replace_row( $id, $row );
		$self->_data_changed;
		return $self;
	}

	method set_value ( $id, $key, $value ) {
		$model->column($key);
		$model->set_value( $id, $key, $value );
		$self->_data_changed;
		return $self;
	}

	# A row's data changed: in a filtered tree, a row that matches now is
	# shown, like after any change of the filters.
	method _data_changed () {
		$model->expand_to_matches;
		$self->_changed;
		return;
	}

	method value ( $id, $key ) {
		return $model->value_of( $self->_check_row($id), $key );
	}

	method display_value ( $id, $key ) {
		return $model->display_of( $self->_check_row($id), $key );
	}

	method _check_row ($id) {
		die "Term::Fabulous::Widget::Table: there is no row with the id " . _describe($id) unless $model->has_row($id);
		return $id;
	}

	method remove_rows (@ids) {
		$model->remove_rows(@ids);
		$self->_rows_changed;
		return $self;
	}

	method remove_row ($id) {
		return $self->remove_rows($id);
	}

	method clear_rows () {
		$model->clear_rows;
		$self->_rows_changed;
		return $self;
	}

	method row ($id)         { return $model->row($id) }
	method has_row ($id)     { return $model->has_row($id) }
	method row_ids ()        { return $model->row_ids }
	method row_count ()      { return $model->row_count }
	method parent_of ($id)   { return $model->parent_of($id) }
	method children_of ($id) { return $model->children_of($id) }
	method filtered_row_ids () { return $model->filtered_row_ids }

	method page_row_ids () {
		return map { $_->{id} } grep { $_->{kind} eq 'row' } $model->page_lines;
	}

	# --- Columns ---------------------------------------------------------

	method columns ()        { return $model->columns }
	method column ($key)     { return $model->column($key) }
	method column_keys ()    { return $model->column_keys }

	method add_column ( $spec, %options ) {
		my @unknown = grep { $_ ne 'index' } sort keys %options;
		die "Term::Fabulous::Widget::Table: add_column does not accept @unknown (known: index)" if @unknown;
		my $column = $model->add_column( $spec, $options{index} );
		$self->_changed;
		return $column;
	}

	method remove_column ($key) {
		delete $_filter_text{$key};
		delete $_filter_error{$key};
		delete $_cell_style_of{$_} foreach grep { ( split /\0/, $_, 2 )[1] eq $key } keys %_cell_style_of;
		$model->remove_column($key);
		$self->_changed;
		return $self;
	}

	method move_column ( $key, $index ) {
		$model->move_column( $key, $index );
		$self->_changed;
		return $self;
	}

	method update_column ( $key, %changes ) {
		die "Term::Fabulous::Widget::Table: update_column cannot change the key of a column" if exists $changes{key};
		my $column = $model->replace_column( $model->column($key)->with(%changes) );
		$self->_changed;
		return $column;
	}

	method visible_columns () {
		return map { $_->key } $model->visible_columns;
	}

	method is_column_visible ($key) {
		return $model->is_column_visible($key);
	}

	method show_columns (@keys) {
		$model->set_column_visible( $_, 1 ) foreach @keys;
		$self->_changed;
		return $self;
	}

	method hide_columns (@keys) {
		$model->set_column_visible( $_, 0 ) foreach @keys;
		$self->_changed;
		return $self;
	}

	method set_visible_columns (@keys) {
		$model->set_visible_columns(@keys);
		$self->_changed;
		return $self;
	}

	method open_column_chooser () {
		return $self if defined $_chooser;
		weaken( my $weak = $self );
		$_chooser = Term::Fabulous::Widget::Table::ColumnChooser->new(
			columns          => [ map { [ $_->key, length $_->title ? $_->title : $_->key, $model->is_column_visible( $_->key ) ] } $model->columns ],
			text_color       => $text_color,
			background_color => $group_background_color,
			border_width     => 1,
			border_color     => $text_color,
			border_style     => Term::Fabulous::Enum::BorderStyle->Round,
			on_toggle        => sub ( $key, $visible ) { $weak->_chooser_toggled( $key, $visible ) if $weak },
			on_close         => sub () { $weak->close_column_chooser if $weak },
		);
		$self->add_child($_chooser);
		$_chooser->focus_first;
		return $self;
	}

	method close_column_chooser () {
		return $self unless defined $_chooser;
		my $closing = $_chooser;
		undef $_chooser;
		my $refocus = $self->_focus_is_inside($closing);
		$self->remove_children_with( sub ($child) { refaddr($child) == refaddr($closing) } );
		$self->_focus_self if $refocus;
		return $self;
	}

	method _focus_is_inside ($widget) {
		my $ui = $self->ui // return 0;
		for ( my $node = $ui->interaction->get_focused_widget; defined $node; $node = $node->parent ) {
			return 1 if refaddr($node) == refaddr($widget);
		}
		return 0;
	}

	method is_column_chooser_open () {
		return defined $_chooser ? 1 : 0;
	}

	method _chooser_toggled ( $key, $visible ) {
		$model->set_column_visible( $key, $visible );
		$self->_changed;
		$self->fire_event( Term::Fabulous::Event::ColumnsChange->new( visible => [ $self->visible_columns ] ) );
		return;
	}

	# --- Sorting ---------------------------------------------------------

	method sort_spec () {
		return $model->sort_spec;
	}

	method sort_by (@spec) {
		$_reveal_cursor = 1 if $model->set_sort(@spec);
		$self->_changed;
		return $self;
	}

	method clear_sort () {
		return $self->sort_by;
	}

	# --- Filtering -------------------------------------------------------

	method filter ( $name, $filter ) {
		die "Term::Fabulous::Widget::Table: filter names starting with 'column:' belong to the filter row; use filter_text"
			if defined $name && !ref $name && $name =~ /\Acolumn:/;
		$model->set_filter( $name, $filter );
		$model->expand_to_matches;
		$_reveal_cursor = 1;
		$self->_changed;
		return $self;
	}

	method remove_filter ($name) {
		$model->remove_filter($name);
		$model->expand_to_matches;
		$self->_changed;
		return $self;
	}

	method filter_names () {
		return grep { !/\Acolumn:/ } $model->filter_names;
	}

	method clear_filters () {
		%_filter_text = %_filter_error = ();
		_set( $_->{field}, value => '' ) foreach grep { defined $_->{field} } @_filter_cells;
		$model->clear_filters;
		$self->_changed;
		return $self;
	}

	method search (@new) {
		return $model->search unless @new;
		$model->search( $new[0] );
		$model->expand_to_matches;
		$_reveal_cursor = 1;
		$self->_changed;
		return $self;
	}

	method filter_text ( $key, @new ) {
		$model->column($key);
		return $_filter_text{$key} // '' unless @new;
		my $text = string( $self, filter_text => $new[0] // '' );
		my ($cell) = grep { defined $_->{field} && $_->{cell}->column_key eq $key } @_filter_cells;
		_set( $cell->{field}, value => $text ) if defined $cell;
		$self->_apply_filter_text( $key, $text );
		return $self;
	}

	method filter_error ($key) {
		$model->column($key);
		return $_filter_error{$key};
	}

	method filter_row (@new) {
		return $filter_row unless @new;
		$filter_row = boolean( $self, filter_row => $new[0] );
		$self->_changed;
		return $filter_row;
	}

	# --- Grouping --------------------------------------------------------

	method group_by (@keys) {
		return $model->group_by unless @keys;
		$model->group_by(@keys);
		$self->_changed;
		return $self;
	}

	method ungroup () {
		$model->group_by(undef);
		$self->_changed;
		return $self;
	}

	method is_group_expanded (@path) {
		return $model->is_group_collapsed(@path) ? 0 : 1;
	}

	method expand_group (@path) {
		$model->set_group_collapsed( \@path, 0 );
		$self->_changed;
		return $self;
	}

	method collapse_group (@path) {
		$model->set_group_collapsed( \@path, 1 );
		$self->_changed;
		return $self;
	}

	method expand_all_groups () {
		$model->set_all_groups_collapsed(0);
		$self->_changed;
		return $self;
	}

	method collapse_all_groups () {
		$model->set_all_groups_collapsed(1);
		$self->_changed;
		return $self;
	}

	# --- Tree ------------------------------------------------------------

	method is_expanded ($id) { return $model->is_expanded($id) }

	method expand (@ids) {
		$model->set_expanded( $_, 1 ) foreach @ids;
		$self->_changed;
		return $self;
	}

	method collapse (@ids) {
		$model->set_expanded( $_, 0 ) foreach @ids;
		$self->_changed;
		return $self;
	}

	method expand_all () {
		$model->set_all_expanded(1);
		$self->_changed;
		return $self;
	}

	method collapse_all () {
		$model->set_all_expanded(0);
		$self->_changed;
		return $self;
	}

	# --- Pages -----------------------------------------------------------

	method page (@new) {
		return $model->page unless @new;
		$model->set_page( $new[0] );
		$self->_changed;
		return $self;
	}

	method page_count () { return $model->page_count }

	method page_size (@new) {
		return $model->page_size unless @new;
		$model->set_page_size( $new[0] );
		$self->_changed;
		return $self;
	}

	method next_page ()     { return $self->page( min( $model->page + 1, $model->page_count ) ) }
	method previous_page () { return $self->page( max( $model->page - 1, 1 ) ) }

	# --- Selection -------------------------------------------------------

	# Changing the mode keeps what the new mode allows of the selection:
	# none of it for 'none', the first selected row for 'single'.
	method selection (@new) {
		return $selection unless @new;
		my ($mode) = @new;
		die "Term::Fabulous::Widget::Table: selection must be 'none', 'single' or 'multiple', got " . _describe($mode)
			unless defined $mode && !ref $mode && $IS_SELECTION{$mode};
		$selection = $mode;
		my @kept = $mode eq 'none' ? () : $model->selected_ids;
		@kept = @kept[ 0 .. 0 ] if $mode eq 'single' && @kept > 1;
		$model->set_selection(@kept);
		$selection_column = $_explicit_selection_column // ( $mode eq 'multiple' ? 1 : 0 );
		$self->_changed;
		return $selection;
	}

	method selection_column (@new) {
		return $selection_column unless @new;
		$_explicit_selection_column = $selection_column = boolean( $self, selection_column => $new[0] );
		$self->_changed;
		return $selection_column;
	}

	method row_id (@new) {
		return $model->row_id unless @new;
		return $model->set_row_id( $new[0] );
	}

	method children_key (@new) {
		return $model->children_key unless @new;
		$model->set_children_key( $new[0] );
		$_body_signature = '';
		$self->_changed;
		return $model->children_key;
	}

	method tree_expanded (@new) {
		return $model->expand_new unless @new;
		return $model->expand_new( boolean( $self, tree_expanded => $new[0] ) );
	}

	method _selectable (@ids) {
		die "Term::Fabulous::Widget::Table: the table has selection => 'none'; nothing can be selected" if @ids && $selection eq 'none';
		die "Term::Fabulous::Widget::Table: a table with selection => 'single' selects one row at most" if @ids > 1 && $selection eq 'single';
		$self->_check_row($_) foreach @ids;
		return @ids;
	}

	method selected_ids ()  { return $model->selected_ids }
	method selected_rows () { return map { $model->row($_) } $model->selected_ids }
	method is_selected ($id) { return $model->is_selected($id) }

	method set_selection (@ids) {
		$model->set_selection( $self->_selectable(@ids) );
		$self->_changed;
		return $self;
	}

	method select (@ids) {
		return $self->set_selection(@ids) if $selection eq 'single';
		$model->select( $self->_selectable(@ids) );
		$self->_changed;
		return $self;
	}

	method deselect (@ids) {
		$model->deselect( map { $self->_check_row($_) } @ids );
		$self->_changed;
		return $self;
	}

	method select_all () {
		die "Term::Fabulous::Widget::Table: select_all needs selection => 'multiple'" unless $selection eq 'multiple';
		$model->select( $model->filtered_row_ids );
		$self->_changed;
		return $self;
	}

	method clear_selection () {
		$model->set_selection;
		$self->_changed;
		return $self;
	}

	# --- Cursor ----------------------------------------------------------

	method cursor (@new) {
		unless (@new) {
			return Term::Fabulous::Widget::Table::Model::id_of_key( $model->cursor );
		}
		my $key = Term::Fabulous::Widget::Table::Model::row_key( $self->_check_row( $new[0] ) );
		die "Term::Fabulous::Widget::Table: row '$new[0]' is not shown (filtered out, or below a collapsed row or group)" unless defined $model->line_index($key);
		$model->set_cursor($key);
		$model->set_anchor($key);
		$_reveal_cursor = 1;
		$self->_changed;
		return $self;
	}

	method cursor_group () {
		my $line = $model->line( $model->cursor // return undef ) // return undef;
		return $line->{kind} eq 'group' ? [ @{ $line->{path} } ] : undef;
	}

	method scroll_to_row ($id) {
		return $self->cursor($id);
	}

	# --- Styles ----------------------------------------------------------

	method set_row_style ( $id, $style ) {
		$self->_check_row($id);
		my $checked = style_hash( $self, 'row style', row => $style );
		%$checked ? ( $_row_style_of{$id} = $checked ) : delete $_row_style_of{$id};
		$self->_restyle;
		return $self;
	}

	method row_style_of ($id) {
		return { %{ $_row_style_of{ $self->_check_row($id) } // {} } };
	}

	method set_cell_style ( $id, $key, $style ) {
		$self->_check_row($id);
		$model->column($key);
		my $checked = style_hash( $self, 'cell style', cell => $style );
		%$checked ? ( $_cell_style_of{ $id . "\0" . $key } = $checked ) : delete $_cell_style_of{ $id . "\0" . $key };
		$self->_restyle;
		return $self;
	}

	method cell_style_of ( $id, $key ) {
		$self->_check_row($id);
		$model->column($key);
		return { %{ $_cell_style_of{ $id . "\0" . $key } // {} } };
	}

	# --- Appearance ------------------------------------------------------

	method _color_property ( $name, @new ) {
		my $field_ref = $self->_color_field($name);
		return $$field_ref unless @new;
		$$field_ref = color( $self, $name => $new[0] );
		$_scrollbar->thumb_color($text_color) if $name eq 'text_color';
		$_scrollbar->track_color($line_color) if $name eq 'line_color';
		$self->_rebuild_pager if $name eq 'text_color' || $name eq 'muted_color';
		$_header_signature = '' if $name eq 'text_color' || $name eq 'cursor_color';    # the filter fields take them when built
		$self->_restyle;
		return $$field_ref;
	}

	method text_color (@new)              { return $self->_color_property( text_color              => @new ) }
	method header_text_color (@new)       { return $self->_color_property( header_text_color       => @new ) }
	method header_background_color (@new) { return $self->_color_property( header_background_color => @new ) }
	method group_text_color (@new)        { return $self->_color_property( group_text_color        => @new ) }
	method group_background_color (@new)  { return $self->_color_property( group_background_color  => @new ) }
	method cursor_color (@new)            { return $self->_color_property( cursor_color            => @new ) }
	method selected_color (@new)          { return $self->_color_property( selected_color          => @new ) }
	method hover_color (@new)             { return $self->_color_property( hover_color             => @new ) }
	method filter_background_color (@new) { return $self->_color_property( filter_background_color => @new ) }
	method error_color (@new)             { return $self->_color_property( error_color             => @new ) }
	method muted_color (@new)             { return $self->_color_property( muted_color             => @new ) }
	method line_color (@new)              { return $self->_color_property( line_color              => @new ) }

	method stripe_color (@new) {
		return $stripe_color unless @new;
		$stripe_color = defined $new[0] ? color( $self, stripe_color => $new[0] ) : undef;
		$self->_restyle;
		return $stripe_color;
	}

	# The table's own background is the color of its cells (see
	# _base_background).
	method background_color :override (@new) {
		my $color = $self->SUPER::background_color(@new);
		$self->_restyle if @new;
		return $color;
	}

	method _line_property ( $name, @new ) {
		return $_line_style{$name} unless @new;
		$_line_style{$name} = defined $new[0] ? border_style_of( $self, $name => $new[0] ) : undef;
		$self->_restyle;
		return $_line_style{$name};
	}

	method border_top (@new)    { return $self->_line_property( border_top    => @new ) }
	method border_right (@new)  { return $self->_line_property( border_right  => @new ) }
	method border_bottom (@new) { return $self->_line_property( border_bottom => @new ) }
	method border_left (@new)   { return $self->_line_property( border_left   => @new ) }
	method column_lines (@new)  { return $self->_line_property( column_lines  => @new ) }
	method row_lines (@new)     { return $self->_line_property( row_lines     => @new ) }
	method header_line (@new)   { return $self->_line_property( header_line   => @new ) }

	# Sets the four sides of the frame; reads the style they share, or
	# undef when they differ.
	method border (@new) {
		if (@new) {
			$self->_line_property( $_ => $new[0] ) foreach qw(border_top border_right border_bottom border_left);
			return $_line_style{border_top};
		}
		my %names = map { ( defined $_ ? $_->name : '' ) => 1 } @_line_style{qw(border_top border_right border_bottom border_left)};
		return keys %names == 1 ? $_line_style{border_top} : undef;
	}

	method header (@new) {
		return $show_header unless @new;
		$show_header = boolean( $self, header => $new[0] );
		$self->_changed;
		return $show_header;
	}

	method scrollbar (@new) {
		return $scrollbar unless @new;
		$scrollbar = boolean( $self, scrollbar => $new[0] );
		$self->_changed;
		return $scrollbar;
	}

	method hover (@new) {
		return $hover unless @new;
		$hover = boolean( $self, hover => $new[0] );
		$_hover_key = undef unless $hover;
		$self->_restyle;
		return $hover;
	}

	method pager (@new) {
		return $show_pager unless @new;
		$show_pager = defined $new[0] ? boolean( $self, pager => $new[0] ) : undef;
		$self->_changed;
		return $show_pager;
	}

	method empty_text (@new) {
		return $empty_text unless @new;
		$empty_text = string( $self, empty_text => $new[0] );
		$self->_restyle;
		return $empty_text;
	}

	method no_match_text (@new) {
		return $no_match_text unless @new;
		$no_match_text = string( $self, no_match_text => $new[0] );
		$self->_restyle;
		return $no_match_text;
	}

	method _callback_property ( $name, $field_ref, @new ) {
		return $$field_ref unless @new;
		die "Term::Fabulous::Widget::Table: $name must be a code reference or undef, got " . _describe( $new[0] )
			if defined $new[0] && ref $new[0] ne 'CODE';
		$$field_ref = $new[0];
		$_->{label_signature} = '' foreach grep { $_->{kind} eq 'group' } values %_built;    # labels are made again
		$self->_restyle;
		return $$field_ref;
	}

	method row_style (@new)   { return $self->_callback_property( row_style   => \$row_style,   @new ) }
	method group_label (@new) { return $self->_callback_property( group_label => \$group_label, @new ) }

	method header_style (@new) {
		return {%$header_style} unless @new;
		$header_style = style_hash( $self, 'header_style', row => $new[0] );
		$self->_restyle;
		return {%$header_style};
	}

	method group_style (@new) {
		return {%$group_style} unless @new;
		$group_style = style_hash( $self, 'group_style', row => $new[0] );
		$self->_restyle;
		return {%$group_style};
	}

	method cell_padding (@new) {
		return {%$cell_padding} unless @new;
		$cell_padding = $self->_padding( $new[0] );
		$_header_signature = $_body_signature = '';    # every cell is built again
		$self->_changed;
		return {%$cell_padding};
	}

	method tree_column (@new) {
		return $tree_column unless @new;
		die "Term::Fabulous::Widget::Table: tree_column must be a column key or undef, got " . _describe( $new[0] ) if ref $new[0];
		$model->column( $new[0] ) if defined $new[0];
		$tree_column = $new[0];
		$_body_signature = '';
		$self->_changed;
		return $tree_column;
	}

	method page_sizes (@new) {
		return [@$page_sizes] unless @new;
		die "Term::Fabulous::Widget::Table: page_sizes must be an array reference of positive integers, got " . _describe( $new[0] )
			unless ref $new[0] eq 'ARRAY' && @{ $new[0] } && !grep { !defined || ref || !/\A[1-9][0-9]*\z/ } @{ $new[0] };
		$page_sizes = [ map { $_ + 0 } @{ $new[0] } ];
		$self->_rebuild_pager;
		$self->_changed;
		return [@$page_sizes];
	}

	# --- KDL -------------------------------------------------------------

	method layout_properties :common () {
		return (
			$class->SUPER::layout_properties,
			selection        => 'scalar',
			selection_column => 'boolean',
			page_size        => 'scalar',
			pager            => 'boolean',
			filter_row       => 'boolean',
			header           => 'boolean',
			scrollbar        => 'boolean',
			hover            => 'boolean',
			row_id           => 'scalar',
			children_key     => 'scalar',
			tree_expanded    => 'boolean',
			tree_column      => 'scalar',
			empty_text       => 'scalar',
			no_match_text    => 'scalar',
			( map { $_ => 'color' } @COLOR_PARAMS, 'stripe_color' ),
			column       => \&_parse_column,
			sort         => \&_parse_sort,
			group_by     => \&_parse_group_by,
			lines        => \&_parse_lines,
			cell_padding => \&_parse_cell_padding,
			page_sizes   => \&_parse_page_sizes,
		);
	}

	# A table's cells come from its columns, not from child widgets.
	method apply_layout_node :override ($node) {
		my @widgets = grep { Term::Fabulous::Role::CanParseLayout::is_widget_node_name( $_->name ) } $node->children->@*;
		die "Term::Fabulous::Widget::Table: a table takes no child widgets (found '" . $widgets[0]->name . "'); its cells come from its columns and rows" if @widgets;
		return $self->SUPER::apply_layout_node($node);
	}

	# How rows are read comes first, then the columns, so every other
	# property can name them.
	method apply_layout_settings :override (@settings) {
		my %rank = ( row_id => 0, children_key => 0, column => 1, sort => 3, group_by => 3 );
		my @ordered = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [ $rank{ $_->[0] } // 2, $_ ] } @settings;
		return $self->SUPER::apply_layout_settings(@ordered);
	}

	my @COLUMN_PROPERTIES = qw(title type width align header_align wrap sortable filterable filter_on compare visible);
	my @STYLE_PROPERTIES  = qw(text_color background_color bold italic underline border_color border_left border_right row_lines);

	method _parse_column ($kid) {
		my @args = map { $_->as_perl } $kid->args->@*;
		die "Term::Fabulous::Widget::Table: layout property 'column' needs the column key as its one argument" unless @args == 1 && defined $args[0] && !ref $args[0];
		my %props   = map { $_->[0] => $_->[1]->as_perl } $kid->props->@*;
		my %allowed = map { $_ => 1 } @COLUMN_PROPERTIES;
		my @unknown = grep { !$allowed{$_} } sort keys %props;
		die "Term::Fabulous::Widget::Table: layout property 'column' does not accept @unknown (allowed: @COLUMN_PROPERTIES)" if @unknown;
		my %styles;
		foreach my $child ( $kid->children->@* ) {
			my $name = $child->name;
			die "Term::Fabulous::Widget::Table: a column node holds only 'style' and 'header_style' nodes, got '$name'"
				unless $name eq 'style' || $name eq 'header_style';
			$styles{$name} = $self->kdl_properties( $child, @STYLE_PROPERTIES );
		}
		$self->add_column( { key => $args[0], %props, %styles } );
		return;
	}

	method _parse_sort ($kid) {
		my @args = map { $_->as_perl } $kid->args->@*;
		die "Term::Fabulous::Widget::Table: layout property 'sort' takes a column key and optionally asc or desc"
			unless ( @args == 1 || @args == 2 ) && !$kid->props->@* && !$kid->children->@*;
		$self->sort_by( @{ $model->sort_spec }, [ $args[0], $args[1] // 'asc' ] );
		return;
	}

	method _parse_group_by ($kid) {
		my @keys = map { $_->as_perl } $kid->args->@*;
		die "Term::Fabulous::Widget::Table: layout property 'group_by' takes one or more column keys" unless @keys && !$kid->props->@* && !$kid->children->@*;
		$self->group_by(@keys);
		return;
	}

	method _parse_lines ($kid) {
		my %line_of = ( top => 'border_top', right => 'border_right', bottom => 'border_bottom', left => 'border_left', columns => 'column_lines', rows => 'row_lines', header => 'header_line' );
		my $props = $self->kdl_properties( $kid, 'frame', ( sort keys %line_of ), 'color' );
		$self->border( $props->{frame} ) if exists $props->{frame};
		$self->_line_property( $line_of{$_} => $props->{$_} ) foreach grep { exists $props->{$_} } sort keys %line_of;
		$self->line_color( $props->{color} ) if exists $props->{color};
		return;
	}

	method _parse_cell_padding ($kid) {
		my @args = $kid->args->@*;
		$self->cell_padding( @args ? $self->kdl_argument($kid)->as_perl : $self->kdl_properties( $kid, qw(left right top bottom) ) );
		return;
	}

	method _parse_page_sizes ($kid) {
		my @sizes = map { $_->as_perl } $kid->args->@*;
		die "Term::Fabulous::Widget::Table: layout property 'page_sizes' takes one or more numbers" unless @sizes && !$kid->props->@* && !$kid->children->@*;
		$self->page_sizes( \@sizes );
		return;
	}

	# --- Widgets ---------------------------------------------------------

	# The widget a cell shows (its column's cell widget or a Text), once
	# the row is on the page and the table was prepared.
	method cell_widget ( $id, $key ) {
		my $built = $_built{ Term::Fabulous::Widget::Table::Model::row_key($id) } // return undef;
		return $built->{content}{$key};
	}

	method body ()         { return $_body }
	method pager_widget () { return $_pager }
}

1;

__END__

=encoding UTF-8

=head1 NAME

Term::Fabulous::Widget::Table - Rows and columns with sorting, filtering,
grouping, trees, pages and selection

=head1 SYNOPSIS

	use Term::Fabulous::Widget::Table;
	use Term::Fabulous::Widget::Table::Mutator qw(date number);

	my $table = Term::Fabulous::Widget::Table->new(
		id        => 'staff',
		row_id    => 'id',              # the rows' 'id' entry names each row
		selection => 'multiple',        # check boxes, Space, Shift+arrows, Ctrl+A
		columns   => [
			{ key => 'name',    title => 'Name' },
			{ key => 'team',    title => 'Team' },
			{ key => 'started', title => 'Started', type => 'date',   mutator => date('%d %b %Y') },
			{ key => 'salary',  title => 'Salary',  type => 'number', mutator => number( decimals => 0 ) },
		],
		rows => [
			{ id => 1, name => 'Ada',   team => 'Core', started => '2019-03-04', salary => 81000 },
			{ id => 2, name => 'Grace', team => 'Web',  started => '2021-11-15', salary => 76500 },
			{ id => 3, name => 'Linus', team => 'Core', started => '2017-06-01', salary => 90000 },
		],
		sort       => [ [ started => 'desc' ] ],
		filter_row => 1,                # a filter field under every column title
		page_size  => 25,               # pages of 25 lines, with a pager below
	);

	$table->on( RowActivate => sub ($event) {       # Enter or a double click
		say 'open ', $event->row->{name};
		return;
	} );
	$table->on( SelectionChange => sub ($event) {
		say scalar @{ $event->selected_ids }, ' selected';
		return;
	} );

	$table->add_row( { id => 4, name => 'Ken', team => 'Web', started => '2023-01-09', salary => 70000 } );
	$table->set_value( 2, salary => 79000 );
	$table->group_by('team');
	my @chosen = $table->selected_rows;              # copies of the selected rows' data

=begin html

<p><img src="/screenshots/widget-table.svg" alt="A table of staff with a filter row, sorted by the start date, two rows selected with check boxes and a pager below"></p>

=end html

=head1 DESCRIPTION

A table shows a list of Perl hashes as rows and columns. You describe
the columns once; the table takes care of everything the user does with
the rows: moving through them with the keyboard and the mouse, sorting
by a click on a column title, filtering, opening and closing groups and
tree rows, turning pages and selecting rows. Your program reads and
changes the data at any time through the table's methods, and learns
about the user's actions through events.

Everything on this page is organized by feature. Each chapter starts
with the parameters, methods, events and KDL properties that belong to
the feature and explains how it works, with examples. The exact
contract of every name (what it takes, returns and when it dies) is in
the reference at the end of the page: L</CONSTRUCTOR>, L</METHODS>,
L</KEYS>, L</MOUSE>, L</EVENTS> and L</KDL PROPERTIES>. The L</FEATURE INDEX> lists
every feature with its chapter. To find something in a terminal, run
C<perldoc Term::Fabulous::Widget::Table> and search with C</>, for
example C</filter_row> or C</^ *GROUPING>.

Complete programs that use tables are in L<Term::Fabulous::Cookbook/TABLES>
and in L<Term::Fabulous::Examples>.

=head2 Features

=over

=item *

Any number of columns, each with its own width (fit, fixed, grow,
percent, with limits), alignment and text wrapping; rows are as high as
their tallest cell. See L</COLUMNS>.

=item *

I<Mutators> turn raw values into display text, for example epoch
seconds into a date, while sorting and filtering keep using the raw
value. See L</DISPLAY TEXT AND MUTATORS>.

=item *

Any widget as a cell: buttons, check boxes, text fields, canvases. See
L</CELL WIDGETS>.

=item *

Sorting by one or several columns, by the user or from Perl, with
built-in comparisons for text, natural text, numbers and dates, or your
own function. See L</SORTING>.

=item *

Filtering: a filter row where the user types expressions such as
C<< >=100 >> or C<2024-05>, named filters from Perl (text, number and
date comparisons, on the raw value or the display text, combined with
and, or, not), and a search over all columns. See L</FILTERING>.

=item *

Grouping rows by the values of one or more columns, under group
headers that open and close. See L</GROUPING>.

=item *

Trees: rows with child rows, opened and closed with a marker. See
L</TREES>.

=item *

Pages with a pager and a choice of page sizes. See L</PAGES>.

=item *

A cursor and no, single or multiple selection, with check boxes. See
L</SELECTION AND CURSOR>.

=item *

Choosing the visible columns, also by the user in a column chooser.
See L</Choosing the visible columns>.

=item *

Colors, striped rows, and lines (borders) per table, column, row and
cell, joined into a clean grid. See L</STYLES AND BORDERS>.

=item *

Changing the data at any time: cells, whole rows, adding and removing
rows and columns. See L</Changing the data>.

=item *

Full keyboard and mouse use (see L</KEYS> and L</MOUSE>), events for
every user action (see L</EVENTS>), and tables in KDL layout files (see
L</KDL PROPERTIES>).

=back

=head2 How a table works

The words in I<italics> are defined in L</Terms used on this page>.

You give the table I<rows>: hash references such as
C<< { id => 7, name => 'Ada', started => 1714739400 } >>. The table
copies them; changing your hashes afterwards changes nothing. Every row
has a I<row id>, which names it in all methods and events.

A I<column> picks one value out of each row, its I<raw value> (by
default the row's entry under the column's key), and turns it into the
I<display text>, the text the cell shows (with the column's
I<mutators>, or as it is). Sorting and filtering use the raw value
unless you say otherwise, so a date shown as C<3 May 2024> still sorts
as a date.

From the rows, the table computes its I<view>, the I<lines> it shows,
in five steps:

=over

=item 1.

B<Filter>: rows that do not match every filter and the search are left
out (in a tree, the parents of a matching row stay).

=item 2.

B<Group>: with C<group_by>, rows are put into groups by the values of
the group columns, each with a group header line.

=item 3.

B<Sort>: rows are sorted within their group and, in a tree, within
their parent row. Rows that compare equal keep the order you gave
them.

=item 4.

B<Flatten>: closed groups and closed tree rows hide what is inside
them.

=item 5.

B<Page>: with a C<page_size>, the lines are cut into pages, and the
table shows one page.

=back

The I<cursor> marks one line of the current page: the line the keyboard
works on. It is drawn only while the table has the keyboard focus. The
I<selection> is a separate set of rows that the user (or your program)
picked; it can contain rows that are not on the current page or are
filtered out.

Changes your program makes (methods such as C<add_row>, C<sort_by>,
C<select>) fire no events; only what the user does fires events. So a
listener never has to tell the user's actions from its own. All changes
show in the next frame: the table updates its widgets once per frame,
however many changes were made.

=head2 Terms used on this page

=over

=item row

One hash reference of your data, shown as one line of the table. The
table stores a copy.

=item row id

The name of a row: the value of its C<row_id> entry, what a C<row_id>
code reference returns, or a number the table counts up (see
L</Row ids>). Ids are strings, unique within a table, and never change.

=item row data

The hash of a row as the table stores it, without its child rows.
Methods such as C<row> return new copies of it. Your code (mutators,
C<value>, C<cell>, filters, C<compare>, C<row_style>, ...) gets one copy
per row that is shared by all of them until the row changes: read it,
but do not change it.

=item column key

The name of a column, unique within a table. It is also the hash key
the column reads from each row, unless the column has a C<value> code
reference.

=item raw value

The value a column reads from a row. Sorting uses it; filters use it
unless they say C<< on => 'display' >>.

=item display text

The text a cell shows: the raw value after the column's mutators,
or the raw value itself. C<undef> shows as nothing.

=item mutator

A code reference that turns a raw value into display text, for example
epoch seconds into C<2024-05-03>. See L</DISPLAY TEXT AND MUTATORS>.

=item view

The rows that pass the filters, grouped, sorted and flattened into
lines; see L</How a table works>.

=item line

One entry of the view: a data row or a group header. Pages count lines,
not rows.

=item group, group path

The rows that share the value of a group column. A group's I<path> is
the list of the raw values of its group and the groups around it,
outermost first: C<[ 'Sales' ]>, or C<[ 'Sales', 'Berlin' ]> with two
group columns.

=item tree row, child row

In a tree (see L</TREES>), a row can have child rows, shown indented
below it while it is I<expanded> (open).

=item open, closed (expanded, collapsed)

A tree row or a group is I<open> (expanded) while its rows are shown,
and I<closed> (collapsed) while they are hidden. The method names use
"expand" and "collapse".

=item passes the filters

A row I<passes the filters> when it matches all filters and the search,
or, in a tree, when one of its child rows (at any depth) does; see
L</Filters with groups and trees>. Rows that pass are in the view,
also when they are inside a closed group or tree row.

=item cursor

The line the keyboard works on, highlighted while the table has the
focus. Every view that has lines has exactly one cursor line.

=item selection

The set of rows that are selected, shown with the selected color and,
with a selection column, with C<[x]> marks.

=item style hash

A hash reference of looks and lines, such as
C<< { text_color => '#ff0000', bold => 1, border_bottom => 'Double' } >>,
for a column, a row or a cell. See L</Style keys>.

=item grid line, frame

The lines between the cells are grid lines; the lines around the table
are its frame. See L</Lines between and around the cells>.

=back

=head1 FEATURE INDEX

Every feature, the section that explains it, and the names to look for.
Table parameters and methods are described in L</CONSTRUCTOR> and
L</METHODS>, events in L</EVENTS>; column parameters in L</COLUMNS> and
L<Term::Fabulous::Widget::Table::Column>, filter options in
L</FILTERING> and L<Term::Fabulous::Widget::Table::Filter>, style keys
in L</Style keys>.

=over

=item Show rows of Perl hashes

L</ROWS>: C<rows>, C<row_id>.

=item Name rows by an entry of the row or by code

L</Row ids>: C<row_id>.

=item Read rows and cell values

L</Reading rows>: C<row>, C<rows>, C<row_ids>, C<value>, C<display_value>.

=item Change a cell or a row

L</Changing the data>: C<set_value>, C<update_row>, C<replace_row>.

=item Add and remove rows

L</Changing the data>: C<add_row>, C<add_rows>, C<remove_row>, C<remove_rows>, C<clear_rows>.

=item Define columns

L</COLUMNS>: C<columns>, C<key>, C<title>, C<type>.

=item Column widths: fit, fixed, growing, percent

L</Column widths>: C<width>.

=item Align the content of cells

L</Alignment>: C<align>, C<header_align>.

=item Wrap text, rows of different heights

L</Wrapping and row height>: C<wrap>, C<width>, C<cell_padding>.

=item Computed columns

L</Computed columns>: C<value>.

=item Add, remove, move and change columns

L</Changing columns>: C<add_column>, C<remove_column>, C<move_column>, C<update_column>.

=item Show and hide columns

L</Choosing the visible columns>: C<visible>, C<show_columns>, C<hide_columns>, C<set_visible_columns>.

=item Let the user pick the columns (column chooser)

L</Choosing the visible columns>: C<open_column_chooser>, C<ColumnsChange>.

=item Format values: dates, numbers, sizes, flags

L</DISPLAY TEXT AND MUTATORS>: C<mutator>, L<Term::Fabulous::Widget::Table::Mutator>.

=item Any widget as a cell (buttons, check boxes, fields)

L</CELL WIDGETS>: C<cell>, C<cell_widget>.

=item Keep input widgets in cells across data changes

L</Updating cell widgets instead of rebuilding them>: C<update_cell>.

=item Focus, keys and clicks in cell widgets

L</Keys and clicks in cell widgets>.

=item A widget as a column title

L</Widgets as column titles>: C<header>.

=item Sort by a column

L</SORTING>: C<sort>, C<sort_by>, C<clear_sort>, C<sortable>, C<SortChange>.

=item Sort by several columns

L</Sorting by several columns>: C<sort>, C<sort_by>.

=item Natural, number and date order

L</How values are compared>: C<compare>, C<type>.

=item Custom sort functions

L</Custom sort functions>: C<compare>.

=item How groups and tree rows are sorted

L</Sorting groups and trees>.

=item Filter fields under the column titles (filter row)

L</The filter row>: C<filter_row>, C<filter_text>, C<filter_error>, C<FilterChange>.

=item Filter from Perl: text, numbers, dates, combinations

L</Filters from Perl>: C<filter>, C<remove_filter>, L<Term::Fabulous::Widget::Table::Filter>.

=item Filter on the raw value or the shown text

L</Raw value or display text>: C<filter_on>, C<on>.

=item Search all columns

L</Searching all columns>: C<search>.

=item Filters with groups and trees

L</Filters with groups and trees>.

=item Texts of an empty or fully filtered table

L</What a filtered table shows>: C<empty_text>, C<no_match_text>, C<filtered_row_ids>.

=item Group rows by a column

L</GROUPING>: C<group_by>, C<ungroup>.

=item Group header labels and looks

L</Group headers>: C<group_label>, C<group_style>.

=item Open and close groups

L</Opening and closing groups>: C<expand_group>, C<collapse_group>, C<Expand>, C<Collapse>.

=item Nested rows (a tree)

L</TREES>: C<children_key>, C<tree_column>, C<tree_expanded>.

=item Open and close tree rows

L</Opening and closing tree rows>: C<expand>, C<collapse>, C<expand_all>, C<Expand>, C<Collapse>.

=item Add and remove child rows

L</Changing a tree>: C<add_row (parent)>, C<parent_of>, C<children_of>.

=item Load child rows when a row opens (lazy loading)

L</Loading child rows when a row opens>: C<Expand>.

=item Pages and a pager

L</PAGES>: C<page_size>, C<page_sizes>, C<pager>, C<page>, C<PageChange>.

=item The cursor

L</The cursor>: C<cursor>, C<cursor_group>, C<scroll_to_row>, C<CursorMove>.

=item Select rows: single or multiple selection

L</Selection>: C<selection>, C<selection_column>, C<selected_ids>, C<SelectionChange>.

=item React to Enter or a double click on a row

L</Activating a row>: C<RowActivate>.

=item Colors

L</Colors>: C<text_color>, C<cursor_color>, C<selected_color>, ....

=item Striped rows

L</Striped rows>: C<stripe_color>.

=item Where style hashes go

L</Style hashes>.

=item The keys of style hashes

L</Style keys>.

=item Which style wins (precedence)

L</Which style wins>.

=item Highlight rows or cells, also by their data

L</Styles of rows and cells>: C<row_style>, C<cell_style>, C<set_row_style>, C<set_cell_style>.

=item Lines around and between the cells

L</Lines between and around the cells>: C<border>, C<column_lines>, C<row_lines>, C<header_line>.

=item Tables with colored rows and titles (block frames)

L</Tables with colored backgrounds>: C<< border => 'Outer' >>.

=item Lines of one column, row or cell

L</Lines of columns, rows and cells>: C<border_*>, C<row_lines>, C<column_lines in style hashes>.

=item Space inside the cells

L</Cell padding>: C<cell_padding>.

=item Hide the column titles

L</Parts shown>: C<header>.

=item Size of the table, scrolling

L</SIZE AND SCROLLING>: C<layout>, C<scrollbar>, C<scroll_to_row>.

=item Keyboard

L</KEYS>.

=item Mouse

L</MOUSE>: C<hover>, C<double_click_seconds>.

=item Events

L</EVENTS>.

=item A table in a KDL layout file

L</KDL PROPERTIES>.

=item Print a table without a terminal (reports)

L</PRINTING A TABLE>: L<Term::Fabulous::Static>.

=item Many rows, speed, the widget limit

L</PERFORMANCE>: C<page_size>, C<max_element_count>.

=back

=head1 ROWS

	Parameters: rows, row_id
	Methods:    rows, row, row_ids, row_count, has_row, value, display_value,
	            filtered_row_ids, page_row_ids, add_row, add_rows, update_row,
	            replace_row, set_value, remove_row, remove_rows, clear_rows

The rows of a table are an array reference of hash references, given as
the C<rows> parameter or later with the C<rows> method. A row can hold
more entries than the table has columns; the extra entries are kept and
passed to your code (mutators, cell widgets, filters), so a row can
carry everything you need to know about it.

	my $table = Term::Fabulous::Widget::Table->new(
		id      => 'files',
		row_id  => 'path',
		columns => [ { key => 'name', title => 'Name' }, { key => 'size', title => 'Size', type => 'number' } ],
		rows    => [
			{ path => '/etc/hosts',  name => 'hosts',  size => 220,  owner => 'root' },
			{ path => '/etc/passwd', name => 'passwd', size => 2780, owner => 'root' },
		],
	);

	$table->rows( \@new_rows );    # replaces all rows

The table copies every row hash when it receives it (one level deep: a
nested array or hash inside a row is shared, not copied). Your hashes
can be changed or reused afterwards without effect on the table.

=head2 Row ids

Every row has an id, a string that names it in every method and event
(C<< $table->row($id) >>, C<< $event->row_id >>, ...). The C<row_id>
parameter says where it comes from:

=over

=item C<< row_id => 'path' >>

The id is the row's entry under that key. Every row must have a
non-empty value there, and no two rows may have the same one; otherwise
the call that adds the rows dies, and no row is added.

=item C<< row_id => sub ($row) { ... } >>

The id is what the code reference returns for a copy of the row, for
example C<< sub ($row) { "$row->{host}:$row->{port}" } >>. The same
rules apply.

=item no C<row_id> (the default)

The table numbers the rows itself: 1, 2, 3 and so on, in the order they
are added. The numbers keep counting up for the life of the table; a
number is never given to a second row, even after its row was removed
or C<rows> replaced all rows. C<add_row> and C<add_rows> return the new
ids.

=back

Use a C<row_id> whenever your data has a natural key: then a row keeps
its id when you replace all rows with C<rows>, and with it its
selection (rows that are still there stay selected). A row's id never
changes: C<update_row> and C<replace_row> die when the new data would
give the row another id. C<row_id> can only be changed while the table
has no rows.

=head2 Reading rows

	my $row   = $table->row(7);              # a copy of the row's data
	my $all   = $table->rows;                # copies of all rows, as given (children nested)
	my @ids   = $table->row_ids;             # every id, in data order
	my $count = $table->row_count;
	my $raw   = $table->value( 7, 'started' );            # 1714739400
	my $text  = $table->display_value( 7, 'started' );    # '03 May 2024'
	my @shown = $table->filtered_row_ids;    # the rows that pass the filters
	my @page  = $table->page_row_ids;        # the data rows of the current page, in view order

Everything these methods return is a copy; changing it does not change
the table. Methods that take a row id die when there is no row with
that id; check with C<has_row> first if you are not sure.

=head2 Changing the data

	my $id  = $table->add_row( { id => 8, name => 'Barbara', team => 'Core' } );
	my @ids = $table->add_rows( \@more, index => 0 );         # at the top

	$table->set_value( 8, team => 'Web' );                    # one cell
	$table->update_row( 8, { team => 'Web', salary => 70000 } );    # some entries
	$table->replace_row( 8, { id => 8, name => 'Barbara L.' } );    # all entries
	$table->remove_row(8);
	$table->remove_rows( 2, 3 );
	$table->clear_rows;
	$table->rows( \@fresh );                                  # all new rows

=over

=item *

C<add_row> and C<add_rows> append rows at the end of the data, or at
C<index> (0 is the top). In a tree, C<< parent => $id >> adds them as
child rows of that row. The position is the I<data order>; the table
still shows the rows sorted, grouped and filtered as it is set up.

=item *

C<set_value> changes one entry of a row; the key must be a column key.
C<update_row> merges a hash of changes into the row (any keys);
C<replace_row> replaces the whole row data.

=item *

C<remove_row> and C<remove_rows> remove rows and, in a tree, all their
child rows. Removed rows leave the selection, and their row and cell
styles are forgotten.

=item *

None of these fire an event. The cursor stays on its row as long as
the row is shown; when it is gone, the cursor moves to the line that
takes its place (see L</The cursor>).

=back

Changing data that a column's mutator, C<value> code, C<cell_style> or
cell widget depends on updates the cell: the table runs the code again
for the changed row only. For a cell widget, see
L</Updating cell widgets instead of rebuilding them>.

=head1 COLUMNS

	Parameters: columns
	Methods:    columns, column, column_keys, add_column, remove_column,
	            move_column, update_column, visible_columns,
	            is_column_visible, show_columns, hide_columns,
	            set_visible_columns, open_column_chooser,
	            close_column_chooser, is_column_chooser_open
	Events:     ColumnsChange
	KDL:        column "key" title=... type=... width=... ...

The C<columns> parameter is an array reference with one hash reference
per column, in the order they are shown. Only C<key> is required:

	columns => [
		{ key => 'name',    title => 'Name', width => 'grow' },
		{ key => 'size',    title => 'Size', type => 'number', mutator => bytes() },
		{ key => 'changed', title => 'Changed', type => 'date', mutator => datetime() },
		{ key => 'note',    title => 'Note', width => 'fit(0, 40)', sortable => 0 },
	],

The table turns each hash into a L<Term::Fabulous::Widget::Table::Column>
object. That page describes every column parameter in full; here is the
overview:

	key            the column's name and, by default, the row entry it shows (required)
	title          the header text (default: the key)
	type           'string' (default), 'number' or 'date': alignment, sorting, filtering
	value          sub ($row) { ... }: compute the raw value instead of reading the key
	mutator        sub ( $value, $row ) { ... } or a list of them: the display text
	align          'left', 'center' or 'right' (default: right for numbers, else left)
	header_align   the same for the header cell (default: align)
	width          'fit', 'fit(8)', 'fit(0, 30)', 'fixed(12)', 'grow', 'grow(10, 40)', 'percent(25)'
	wrap           'words' (default), 'newlines' or 'none'
	sortable       1 (default) or 0: may the user sort by it?
	compare        'string', 'natural', 'number', 'date' or sub ( $a, $b, $row_a, $row_b ) { ... }
	filterable     1 (default) or 0: does the filter row have a field for it?
	filter_on      'display' or 'value': what its filter field compares
	cell           sub ($cell) { ... }: a widget for each cell
	update_cell    sub ( $widget, $cell ) { ... }: bring that widget up to date
	header         sub ($column) { ... }: a widget for the header cell
	cell_style     sub ($cell) { ... }: a style hash per cell (conditional formatting)
	style          a style hash for all cells of the column
	header_style   a style hash for the header cell
	visible        1 (default) or 0: is the column shown at first?

Unknown keys and invalid values die when the column is made. A message
about an invalid value names the column; one about an unknown key names
the key (C<Unrecognised parameters ... 'titel'>).

=head2 Column widths

C<width> sets how wide a column is, in terminal cells (character
cells), and it counts
including the cell padding (one column left and right by default; see
L</Cell padding>):

	width => 'fit'           # as wide as the widest cell of the column (the default)
	width => 'fit(8)'        # the same, but at least 8 columns
	width => 'fit(0, 30)'    # the same, but at most 30 columns; longer text wraps
	width => 'fixed(12)'     # exactly 12 columns; longer text wraps
	width => 'grow'          # a share of the width the table has left over
	width => 'grow(10, 40)'  # the same, between 10 and 40 columns
	width => 'percent(25)'   # a quarter of the table's width

The header cell, the filter field and every cell of the column are
measured together, so a C<fit> column is as wide as the widest of them.
Only the cells that are shown count: the lines of the current page,
without the rows inside closed groups and tree rows and without the
rows the filters hide. The text typed into a filter field does not
count. So a C<fit> column can change its width when the user turns a
page, opens a group or filters; with no matching row at all, it shrinks
to its title. Give it a C<fixed> or C<grow> width, or a minimum such as
C<'fit(12)'>, to keep it steady; with a filter row, do that for every
column the user filters, so that the field stays wide enough to type
into.
The widths also take the hash that the C<sizing_*> functions of
L<Clay::XS> return, such as C<sizing_fixed(12)>.

A C<grow> or C<percent> column only has room to grow when the table is
wider than its columns need: give the table a width with its C<layout>,
for example C<< layout => { sizing => { width => sizing_grow() } } >>
(see L</SIZE AND SCROLLING>). Several C<grow> columns share the
leftover width.

=head2 Alignment

C<align> places the content of the column's cells: C<'left'>,
C<'center'> or C<'right'>. Number columns are right-aligned by default,
all others left-aligned. C<header_align> does the same for the header
cell and defaults to C<align>.

	{ key => 'qty', title => 'Quantity', type => 'number', header_align => 'left' }

=head2 Wrapping and row height

Text that is wider than its column wraps onto more lines, and the row
grows: every row is as high as its tallest cell, and rows of different
heights can follow each other. C<wrap> decides how text breaks:

	wrap => 'words'       # at spaces, and at newlines (the default)
	wrap => 'newlines'    # only at newlines in the text
	wrap => 'none'        # never; text that does not fit is cut off

Wrapping needs a limit on the column's width (C<'fit(0, 30)'>,
C<'fixed(12)'>, C<'grow'>, C<'percent(25)'>); a plain C<fit> column is
always as wide as its longest line. Text with newlines is several lines
high in every mode but C<none>. A cell widget (see L</CELL WIDGETS>)
can be any number of lines high, too.

	{ key => 'description', title => 'Description', width => 'fit(0, 36)' }    # wraps at 36 columns
	{ key => 'address',     title => 'Address',     wrap => 'newlines' }       # "Street 1\n12345 Town"

C<cell_padding> can also add empty terminal rows above and below every cell's
content; see L</Cell padding>.

=head2 Computed columns

A column does not have to show an entry of the row. With C<value>, it
computes its raw value from the whole row:

	{ key => 'total', title => 'Total', type => 'number',
	  value => sub ($row) { $row->{price} * $row->{quantity} } }

	{ key => 'items', title => 'Items', type => 'number',
	  value => sub ($row) { scalar @{ $row->{lines} } } }

The computed value is the raw value: the table sorts, filters and
groups by it like any other. The code gets a copy of the row's data and
runs once per row; the table keeps the result until the row changes.
The column's C<key> must still be unique, but needs not exist in the
rows.

=head2 Changing columns

	$table->add_column( { key => 'email', title => 'E-mail' } );               # at the end
	$table->add_column( { key => 'rank',  title => '#', type => 'number' }, index => 0 );    # first
	$table->remove_column('email');
	$table->move_column( rank => 2 );                          # now the third column
	$table->update_column( salary => title => 'Pay', mutator => number( decimals => 2 ) );

	my $column = $table->column('salary');                     # the Column object
	say $column->title, ' (', $column->type, ')';
	my @keys = $table->column_keys;                            # in order, hidden ones too

A column is never changed in place. C<update_column> makes a new column
from the old one's parameters and your changes (anything but C<key>)
and puts it in the old one's place, keeping whether it is visible.

Removing a column also removes it from the sort and the grouping, and
removes every filter that compares it. The rows keep their entries
under its key.

=head2 Choosing the visible columns

A hidden column is still part of the table: its values can be read,
sorted by and filtered on. It only takes no space on the screen, and
the search (see L</Searching all columns>) skips it.

	columns => [ ..., { key => 'note', title => 'Note', visible => 0 } ],    # hidden at first

	$table->hide_columns(qw(note email));
	$table->show_columns('note');
	$table->set_visible_columns(qw(name team salary));    # exactly these; their order stays
	my @shown = $table->visible_columns;                   # the keys, in order
	say 'hidden' unless $table->is_column_visible('email');

The order of the columns is always the one of the C<columns> list (and
C<move_column>); showing a column puts it back at its place.

The user can choose the columns, too: right-clicking a column title,
or pressing C<c> while the header has the keyboard (see L</KEYS>),
opens the I<column chooser>, a small list with a check box per column
over the table's top right corner. Checking or unchecking a box shows
or hides the column at once and fires C<ColumnsChange>. C<Escape>
closes the list, and so does moving the focus out of it. Your
program can open and close it with C<open_column_chooser> and
C<close_column_chooser>, for example from a key binding:

	$table->on( ColumnsChange => sub ($event) {
		save_setting( columns => $event->visible );    # [ 'name', 'team', ... ]
		return;
	} );
	$root->on( KeyPress => sub ($event) {
		$table->open_column_chooser if ( $event->key_name // '' ) eq 'F2';
		return;
	} );

=head1 DISPLAY TEXT AND MUTATORS

	Column parameters: mutator, type
	Methods:           display_value, value
	Module:            Term::Fabulous::Widget::Table::Mutator

A I<mutator> turns a cell's raw value into the text the cell shows. The
table keeps both: it sorts and filters by the raw value (unless a
filter says otherwise) and shows the display text. So a column of epoch
seconds can show C<03 May 2024 14:30> and still sort by time, and a
column of byte counts can show C<1.5 MiB> and still sort by size.

L<Term::Fabulous::Widget::Table::Mutator> makes the common mutators:

	use Term::Fabulous::Widget::Table::Mutator qw(datetime date number percent bytes duration boolean lookup truncate);

	{ key => 'modified', type => 'date',   mutator => datetime( '%d %b %Y %H:%M', utc => 1 ) }    # 1714739400 -> 03 May 2024 12:30
	{ key => 'born',     type => 'date',   mutator => date() }                         # '1815-12-10' -> 1815-12-10
	{ key => 'price',    type => 'number', mutator => number( decimals => 2, prefix => '$' ) }    # 1234.5 -> $1,234.50
	{ key => 'share',    type => 'number', mutator => percent( decimals => 1 ) }       # 0.153 -> 15.3%
	{ key => 'size',     type => 'number', mutator => bytes() }                        # 1536 -> 1.5 KiB
	{ key => 'uptime',   type => 'number', mutator => duration() }                     # 3725 -> 1h 02m
	{ key => 'active',                     mutator => boolean( 'yes', 'no' ) }
	{ key => 'state',                      mutator => lookup( { R => 'running', S => 'sleeping' } ) }
	{ key => 'title',                      mutator => truncate(30) }                   # cut with an ellipsis

Any code reference is a mutator. It is called with the raw value and a
copy of the row's data, and returns the text:

	{ key => 'temp', title => 'Temperature', type => 'number',
	  mutator => sub ( $value, $row ) { defined $value ? sprintf( '%.1f %s', $value, $row->{unit} ) : '' } }

Give an array reference of mutators to run them one after the other,
each on the result of the one before:

	mutator => [ number( decimals => 0 ), sub ( $text, $row ) { "$text pcs" } ]

The table runs a column's mutators once per row and keeps the result
until the row or the column changes. Read the result with
C<< $table->display_value( $id, $key ) >> and the raw value with
C<< $table->value( $id, $key ) >>.

Dates may be epoch seconds, date strings (C<2024-05-03>,
C<2024-05-03 14:30>) or objects with an C<epoch> method (L<DateTime>,
L<Time::Piece>); see L<Term::Fabulous::Widget::Table::Value/date_epoch>.
Give such a column C<< type => 'date' >>, so that it sorts and filters
as dates.

=head1 CELL WIDGETS

	Column parameters: cell, update_cell, header
	Methods:           cell_widget

By default a cell is a L<Term::Fabulous::Widget::Text> with the display
text. A column's C<cell> code reference can return any widget instead:
a L<Term::Fabulous::Widget::Button>, a
L<Term::Fabulous::Widget::Checkbox>, a
L<Term::Fabulous::Widget::TextField>, a
L<Term::Fabulous::Widget::PixelCanvas>, or a
L<Term::Fabulous::Widget::Box> with several children.

	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Text;

	{ key => 'actions', title => '', sortable => 0, filterable => 0,
	  cell => sub ($cell) {
		my $button = Term::Fabulous::Widget::Button->new;
		$button->add_child( Term::Fabulous::Widget::Text->new( text => 'Delete', text_color => '#ffffff' ) );
		my $id = $cell->{id};
		$button->on( Activate => sub ($event) { $cell->{table}->remove_row($id); return } );
		return $button;
	  } }

The code gets one hash reference, the I<cell context>, with these
keys:

	value     the raw value of the cell
	display   the display text (after the mutators)
	row       a copy of the row's data
	id        the row id
	column    the Term::Fabulous::Widget::Table::Column object
	table     the table

It must return a widget (anything else dies when the cell is built).
The table puts the widget into the cell, which gives it the cell's
background, padding and lines.

=head2 When cell widgets are built

The table builds cell widgets only for the rows of the current page,
when they are first shown. It builds a row's cell widgets again when:

=over

=item *

the row's data changed (C<set_value>, C<update_row>, ...), unless the
column has an C<update_cell> (see below);

=item *

the column changed (C<update_column>), or the columns were added,
removed, moved, shown or hidden;

=item *

the row comes back after it left the page: after a page turn, a filter
that hid it, or a closed group or tree row.

=back

So keep what matters in the row data, not in the widget: a widget can
be replaced by a new one at these moments, and then shows what the
C<cell> code makes of the row data. C<< $table->cell_widget( $id, $key ) >>
returns the widget a cell shows right now (also the default Text), or
C<undef> when the row is not on the page or the table has not been
drawn since the row was added.

=head2 Updating cell widgets instead of rebuilding them

For input widgets, building a new widget for every data change is
wrong: the user's focus and what they are typing would be lost, often
by a change the input itself made. Give the column an C<update_cell>
code reference: the table then keeps the widget when the row's data
changes and calls C<< update_cell->( $widget, $cell ) >> with the
existing widget and the new cell context instead. C<update_cell> needs a
C<cell>.

	use Term::Fabulous::Widget::Checkbox;

	{ key => 'done', title => 'Done', filterable => 0,
	  cell => sub ($cell) {
		my $box = Term::Fabulous::Widget::Checkbox->new( checked => $cell->{value} ? 1 : 0 );
		my ( $table, $id ) = @{$cell}{qw(table id)};
		$box->on( Change => sub ($event) { $table->set_value( $id, done => $event->value ? 1 : 0 ); return } );
		return $box;
	  },
	  update_cell => sub ( $box, $cell ) { $box->checked( $cell->{value} ? 1 : 0 ) },
	}

Write the input's value back into the row (here with C<set_value>), so
that sorting, filtering and the next C<cell> call see it.

=head2 Keys and clicks in cell widgets

Focusable widgets in cells are part of the focus order: C<Tab> reaches
them, and a click focuses them. While a widget in a cell has the focus,
it gets the keys first. Keys it does not use go to the table: C<Up>,
C<Down>, C<PageUp> and the other movement keys move the table's cursor
and give the focus back to the table. C<Enter> and C<Space> are left to
the widget; they do not activate or select the row.

When a cell widget that has the focus goes away, because its row was
removed, left the page or the cell was built again (see L</When cell
widgets are built>), the table takes the focus. So a button that
deletes its own row leaves the keyboard in the table.

A click on an input widget in a cell (anything focusable or pressable,
such as a button, a check box or a text field) goes to that widget. The
table moves its cursor to the row and otherwise leaves the click alone:
with C<< selection => 'multiple' >> the selection stays as it is, and a
double click does not activate the row. (With C<'single'>, the row is
selected, because there the selection follows the cursor.)

=head2 Widgets as column titles

A column's C<header> code reference returns the widget of its header
cell, instead of the title in bold. It gets the Column object. The sort
marker is still shown right of it.

	header => sub ($column) {
		my $box = Term::Fabulous::Widget::Box->new( layout => { child_gap => 1 } );
		$box->add_child(
			Term::Fabulous::Widget::Text->new( text => "\x{2605}", text_color => '#e5c07b' ),
			Term::Fabulous::Widget::Text->new( text => $column->title, bold => 1, text_color => '#ffffff' ),
		);
		return $box;
	},

The table builds it again when the column changes. The header styles'
C<background_color> and lines apply to the cell as usual; their text
color, C<bold>, C<italic> and C<underline> apply only to the default
title, so give your widget its own.

=head1 SORTING

	Parameters:        sort
	Column parameters: sortable, compare, type
	Methods:           sort_by, clear_sort, sort_spec
	Events:            SortChange
	KDL:               sort "key" "desc"

=head2 Sorting by the user

A click on a column title sorts the table by that column. Clicking the
same title again cycles through ascending, descending and unsorted. A
small marker after the title shows the order: C<▴> ascending, C<▾>
descending. With the keyboard, press C<Up> on the first line to reach
the header, move to the column with C<Left> and C<Right>, and press
C<Enter> (see L</KEYS>).

Every user change of the sort fires C<SortChange>:

	$table->on( SortChange => sub ($event) {
		say join ', ', map { "$_->[0] $_->[1]" } @{ $event->sort };    # name asc, size desc
		return;
	} );

Columns with C<< sortable => 0 >> ignore clicks and C<Enter> on their
title. Your program can still sort by them with C<sort_by>.

=head2 Sorting from Perl

	sort => [ 'team', [ started => 'desc' ] ],    # parameter: team ascending, then newest first

	$table->sort_by('name');                       # ascending
	$table->sort_by( [ size => 'desc' ] );
	$table->sort_by( 'team', [ salary => 'desc' ] );
	$table->clear_sort;                            # the data order again
	my $spec = $table->sort_spec;                  # [ [ 'team', 'asc' ], [ 'salary', 'desc' ] ]

Each entry of a sort is a column key (ascending) or an array reference
C<[ $key, 'asc' ]> or C<[ $key, 'desc' ]>. C<sort_by> replaces the
whole sort; it dies for an unknown column, a direction that is not
C<asc> or C<desc>, or a column named twice. It fires no event.

Unsorted rows show in data order: the order you gave them in, with
C<add_rows> and its C<index> placing new ones.

=head2 Sorting by several columns

When a table is sorted by several columns, the first one decides; rows
that are equal there are ordered by the second one, and so on. Rows
equal in all of them keep their data order. The markers then carry the
place of each column in the sort: C<▴1>, C<▾2>.

The user builds such a sort by holding C<Shift>, C<Ctrl> or C<Alt>
while clicking titles, or with C<Space> instead of C<Enter> in the
header: the column is added at the end of the sort, or, when it is in
the sort already, cycles from ascending to descending (keeping its
place) and then leaves the sort.

=head2 How values are compared

The C<compare> parameter of a column says how its raw values are
ordered. It defaults to the column's C<type>:

	'string'    text, without regard to case: apple, Banana, cherry (the default for string columns)
	'natural'   text, with runs of digits compared as numbers: file2, file10, File11
	'number'    numbers: 9, 10, 100 (the default for number columns)
	'date'      points in time: dates, epoch seconds, objects with an epoch method
	            (the default for date columns)

	{ key => 'file', title => 'File', compare => 'natural' }

With these, blank values (C<undef> or C<''>) and values that cannot be
read as the type (a word in a number column) sort after all others, in
both directions. Sorting always uses the raw value, never the display
text: a date column shown as C<03 May 2024> sorts by date, not
alphabetically.

=head2 Custom sort functions

C<compare> can be your own function. It is called with the two raw
values and copies of the two rows, and returns a negative number, 0 or
a positive number, like Perl's C<< <=> >> and C<cmp>, for B<ascending>
order. The table reverses the result for descending order. It sees every
value, also C<undef>.

	my %rank = ( high => 1, normal => 2, low => 3 );
	{ key => 'priority', title => 'Priority',
	  compare => sub ( $left, $right, $left_row, $right_row ) {
		( $rank{ $left // '' } // 9 ) <=> ( $rank{ $right // '' } // 9 )
	  } }

	# IPv4 addresses in numeric order
	{ key => 'ip', title => 'Address',
	  compare => sub ( $left, $right, @rows ) {
		pack( 'C4', split /\./, $left ) cmp pack( 'C4', split /\./, $right )
	  } }

	# Order by a different entry of the row than the one shown
	{ key => 'month', title => 'Month', compare => sub ( $l, $r, $lrow, $rrow ) { $lrow->{month_number} <=> $rrow->{month_number} } }

The named comparisons compute one sort key per row and are fast; a
function is called for every comparison, about I<n log n> times for
I<n> rows. For thousands of rows, prefer a C<value> code reference that
computes a number or a string to sort by, with a named comparison.

=head2 Sorting groups and trees

In a grouped table, the groups are ordered by their value, ascending,
with the group column's comparison; when the sort includes the group
column, the groups follow its direction. Rows are sorted within their
group. In a tree, child rows are sorted among their siblings, below
their parent row.

=head1 FILTERING

	Parameters:        filter_row
	Column parameters: filterable, filter_on, type
	Methods:           filter, remove_filter, filter_names, clear_filters,
	                   search, filter_text, filter_error, filter_row,
	                   filtered_row_ids
	Events:            FilterChange
	Module:            Term::Fabulous::Widget::Table::Filter
	KDL:               filter_row, no_match_text

A filtered table shows only the rows that match B<all> of its filters:
the fields of the filter row, the filters your program sets, and the
search. Filtering hides rows from the view; it does not remove them.
Hidden rows keep their data and their selection.

=head2 The filter row

With C<< filter_row => 1 >>, the table shows a row of text fields right
below the column titles, one per column (columns with
C<< filterable => 0 >> get an empty cell). An empty field shows C<…>.
What the user types filters the table as they type.

	my $table = Term::Fabulous::Widget::Table->new( id => 'orders', filter_row => 1, columns => [...] );

The text in a field is a I<filter expression>. Its notation depends on
the column's C<type>:

	Text columns (type 'string')
	  ann          the cell contains "ann" (upper and lower case do not matter)
	  !ann         the cell does not contain "ann"
	  =Ann Lee     the cell is "Ann Lee"
	  !=Ann Lee    the cell is not "Ann Lee"
	  ^An          the cell starts with "An"
	  Lee$         the cell ends with "Lee"
	  ^Ann Lee$    the cell is "Ann Lee"
	  /^a.*e$/     the cell matches the regular expression (without regard to case)

	Number columns (type 'number')
	  42  =42      is 42
	  !=42         is not 42
	  >42  >=42    greater than 42 (or equal)
	  <42  <=42    less than 42 (or equal)
	  10..20       from 10 to 20, both included

	Date columns (type 'date'), with dates in the forms 2024, 2024-05,
	2024-05-03, 2024-05-03 14:30 and 2024-05-03 14:30:15
	  2024-05-03         on that day
	  >=2024-05          from May 2024 on
	  <2024-05-03 14:30  before that minute
	  2024-01..2024-03   from January to the end of March 2024

	Every column
	  =            the cell is empty
	  !=           the cell is not empty

Spaces around an expression do not matter, and an empty field filters
nothing. A date names a span of time, as long as its last part: a day
is a whole day, a month a whole month. So C<=2024-05-03> matches every
time on that day, C<< <=2024-05 >> everything up to the end of May, and
C<< >2024-05 >> everything from June on.

When a field holds an expression that the column's type cannot read
(C<< >abc >> in a number column), its text turns to the C<error_color>,
and the column is not filtered until the text is valid again.
C<< $table->filter_error($key) >> returns the message, and so does the
C<error> of the C<FilterChange> event that every change of a field
fires:

	$table->on( FilterChange => sub ($event) {
		$status->text( $event->error // sprintf( '%d of %d rows', scalar $table->filtered_row_ids, $table->row_count ) );
		return;
	} );

Keys in a filter field: C<Tab> and C<Shift+Tab> move between the
fields (and the rest of the program); C<Enter> or C<Down> go to the
rows; C<Escape> empties a field that has text. In the C<Tab> order, the
table itself (its rows) comes before its filter fields, although the
fields are drawn above the rows. Your program reads and
sets the text of a field with C<filter_text>; setting it fires no
event and also works while the filter row is hidden:

	$table->filter_text( size => '>=1000' );
	say $table->filter_text('size');    # '>=1000'
	$table->filter_text( size => '' );  # no filter on size

What a field compares, the raw value or the display text, is the
column's C<filter_on> (see L</Raw value or display text>).

=head2 Filters from Perl

Your program sets filters by name with C<filter>. A filter is a
L<Term::Fabulous::Widget::Table::Filter> object or a code reference
that gets a copy of the row's data and returns true for the rows to
show. Setting a filter under a name that is in use replaces that
filter; C<undef> or C<remove_filter> removes it.

	use Term::Fabulous::Widget::Table::Filter;
	my $F = 'Term::Fabulous::Widget::Table::Filter';

	$table->filter( adults => $F->new( column => 'age', op => '>=', value => 18 ) );
	$table->filter( mine   => sub ($row) { $row->{owner} eq 'ada' } );
	$table->filter( adults => undef );          # removed again
	$table->remove_filter('mine');
	my @names = $table->filter_names;           # the names of your filters, in order
	$table->clear_filters;                      # your filters, the search and the filter row

A condition compares one column with a value. The ops for text are
C<contains>, C<not_contains>, C<equals>, C<not_equals>, C<starts_with>,
C<ends_with> and C<matches> (a regular expression); text comparisons
ignore case unless C<< case_sensitive => 1 >>, except that a C<qr//>
pattern for C<matches> keeps its own flags (C<qr/ann/i> ignores case,
C<qr/ann/> does not). The comparison ops
compare as the column's type says:

	# Numbers
	$F->new( column => 'price', op => '<',       value => 10 )
	$F->new( column => 'price', op => 'between', value => [ 10, 20 ] )    # both included
	$F->new( column => 'qty',   op => 'in',      value => [ 1, 2, 3 ] )

	# Dates: a date names a span of time (a day, a month, a minute)
	$F->new( column => 'placed', op => '>=',      value => '2024-05' )                     # from May 2024 on
	$F->new( column => 'placed', op => '=',       value => '2024-05-03' )                  # any time that day
	$F->new( column => 'placed', op => 'between', value => [ '2024-01', '2024-03' ] )      # January to March
	$F->new( column => 'placed', op => '<',       value => time - 7 * 86400 )              # older than a week

	# Text
	$F->new( column => 'name',  op => 'starts_with', value => 'An' )
	$F->new( column => 'name',  op => 'matches',     value => qr/^a.*e$/i )
	$F->new( column => 'state', op => 'in',          value => [ 'open', 'pending' ] )

	# Blank cells (undef or '')
	$F->new( column => 'closed', op => 'empty' )

Combine filters with C<all>, C<any> and C<not>:

	$table->filter( urgent => $F->any(
		$F->new( column => 'priority', op => '=', value => 'high' ),
		$F->all(
			$F->new( column => 'due', op => '<', value => '2024-06' ),
			$F->not( $F->new( column => 'done', op => '=', value => 1 ) ),
		),
	) );

A filter is checked when you set it: a filter that names an unknown
column, or compares with a value its column's type cannot read
(C<< op => '>', value => 'abc' >> on a number column), dies in
C<filter>, not later while the table is drawn. Filter names starting
with C<column:> belong to the filter row and die in C<filter>; use
C<filter_text> for those. L<Term::Fabulous::Widget::Table::Filter>
describes every op and option.

=head2 Raw value or display text

A filter compares either the cell's raw value or its display text:

	$F->new( column => 'size', op => '>=', value => 1048576 )                     # raw: 1 MiB or more
	$F->new( column => 'size', op => 'contains', value => 'MiB', on => 'display' )    # what the user sees

Filters from Perl compare the raw value unless they say
C<< on => 'display' >>. The fields of the filter row compare what the
column's C<filter_on> says: by default the display text for string
columns (users type what they see) and the raw value for number and
date columns (users type numbers and dates, such as C<< >=1048576 >> or
C<2024-05>). Set C<< filter_on => 'display' >> on a number column to let
users type what they see instead; the cell is then still compared as a
number, so this works for mutators that keep the text a number, such as
C<sprintf_format('%.2f')>.

=head2 Searching all columns

	$table->search('ada');      # rows where any visible cell contains "ada"
	say $table->search;         # 'ada'
	$table->search('');         # no search

C<search> keeps the rows where the display text of at least one visible
column contains the text, without regard to case. Each cell is searched
on its own: a search never matches across two cells. Hidden columns are
not searched. A typical search box is a
L<Term::Fabulous::Widget::TextField> above the table:

	my $search = Term::Fabulous::Widget::TextField->new( placeholder => 'Search' );
	$search->on( Change => sub ($event) { $table->search( $event->value ); return } );

=head2 Filters with groups and trees

In a grouped table, a group shows only its matching rows, its count
counts only those, and groups without matching rows disappear.

In a tree, a matching child row is never cut off from its parents: the
parent rows stay in the view even when they do not match, and the table
expands them so that the match is visible. They stay expanded when the
filter is removed.

=head2 What a filtered table shows

C<filtered_row_ids> returns the ids of all rows that pass the filters,
also those inside closed groups and closed tree rows. When no row
passes, the table shows C<no_match_text> (default C<'No rows match'>);
when it has no rows at all, C<empty_text> (default C<'No rows'>).
C<select_all> and C<Ctrl+A> select the rows that pass the filters.

=head1 GROUPING

	Parameters: group_by, group_label, group_style, group_text_color,
	            group_background_color
	Methods:    group_by, ungroup, is_group_expanded, expand_group,
	            collapse_group, expand_all_groups, collapse_all_groups,
	            cursor_group
	Events:     Expand, Collapse (with a group_path)
	KDL:        group_by "key" ...

C<group_by> puts the rows into groups by the value of a column. Each
group starts with a I<group header>, a line across all columns that
shows the group's value and how many rows it has, and that the user can
close to hide the group's rows.

	my $table = Term::Fabulous::Widget::Table->new(
		id       => 'staff',
		columns  => [...],
		rows     => \@staff,
		group_by => 'team',              # or [ 'team', 'city' ] for groups within groups
	);

	$table->group_by( 'team', 'city' );  # change it later
	my @keys = $table->group_by;         # ( 'team', 'city' )
	$table->ungroup;

=begin html

<p><img src="/screenshots/cookbook-table-groups.svg" alt="A table of staff grouped by team: group headers with the team name, the number of people and their total salary, one group closed"></p>

=end html

=over

=item *

Rows are grouped by the column's I<raw value>; the header shows its
display text. Rows with a blank value form a group of their own, shown
as C<(empty)>. C<undef> and C<''> are different values: they form two
groups, both labeled C<(empty)>. To merge them, give the column a
C<value> code such as C<< sub ($row) { $row->{city} // '' } >>.

=item *

With several columns, every group is divided by the next column, and
each level is indented by two more terminal cells.

=item *

The groups are ordered by their value, ascending, with the comparison
of the group column (see L</How values are compared>); when the sort
includes the group column, the groups follow its direction. Rows are
sorted within their group.

=item *

The group column stays a normal column; hide it with C<hide_columns> if
the group header says enough.

=item *

In a tree (see L</TREES>), only top-level rows are grouped; child rows
stay below their parent row.

=item *

Group headers are lines: they count for the pages (see L</PAGES>), and
the cursor can stand on them.

=back

=head2 Group headers

By default a group header shows C<Title: value (count)> in bold, for
example C<Team: Core (12)>, in the C<group_text_color> on the
C<group_background_color>. The count is the number of rows in the group
that pass the filters, child rows in a tree included. C<group_label>
replaces the text: a code reference that gets a hash reference about
the group and returns a string or a widget:

	group_label => sub ($group) {
		my $total = 0;
		$total += $group->{table}->value( $_, 'salary' ) // 0 foreach @{ $group->{ids} };
		return sprintf '%s - %d people, %s per year', $group->{display}, $group->{count}, $total;
	},

The hash has these keys:

	column    the Term::Fabulous::Widget::Table::Column object of the group column
	value     the raw value the group's rows share
	display   its display text
	count     the number of rows in the group (child rows included)
	path      the group path: the values of this group and the groups around it, outermost first
	depth     the level of the group, 0 for the outermost
	ids       the ids of the group's top-level rows
	table     the table

The label is made again when the group's value or count changes. A
returned widget is used as it is; give it its own colors. A group
header never makes the table wider: a label longer than the table is
wide wraps onto more lines.
C<group_style> is a style hash for all group headers: their looks and
lines (see L</Style keys>):

	group_style => { background_color => '#2c313c', text_color => '#e5c07b', border_bottom => 'Solid' },

=head2 Opening and closing groups

The user opens and closes a group by clicking its header, or with the
keyboard on its header line: C<Enter> or C<Space> toggle it, C<Right>
or C<+> open it, C<Left> or C<-> close it. C<Left> on a closed group
header moves the cursor to the header of the group around it (with
several group columns), and C<Left> on a top-level row moves it to the
header of the row's group; these moves fire only C<CursorMove>. The
marker in front of the label shows the state: C<▾> open, C<▸> closed.
Opening and closing fire C<Expand> or C<Collapse> with the group's
path:

	$table->on( Collapse => sub ($event) {
		my $path = $event->group_path // return;    # undef: a tree row was closed
		say 'closed ', join ' / ', @$path;
		return;
	} );

From Perl, groups are named by their path (raw values, outermost
first):

	$table->collapse_group('Sales');            # the group 'Sales'
	$table->expand_group( 'Sales', 'Berlin' );  # 'Berlin' within 'Sales'
	say 'open' if $table->is_group_expanded('Sales');
	$table->collapse_all_groups;
	$table->expand_all_groups;

These fire no events. The table remembers which groups are closed by
their path, also while a filter hides a group or the grouping is off,
so a group comes back closed. C<collapse_all_groups> closes the groups
there are right now (with the current filters); a group that appears
later, through new rows or a changed filter, starts open.
C<is_group_expanded> returns 1 for a path that names no group.

When the cursor stands on a group header, C<cursor> returns C<undef>
and C<cursor_group> returns the group's path.

=head1 TREES

	Parameters: children_key, tree_column, tree_expanded
	Methods:    expand, collapse, expand_all, collapse_all, is_expanded,
	            parent_of, children_of, add_row (parent), children_key,
	            tree_column, tree_expanded
	Events:     Expand, Collapse (with a row_id)
	KDL:        children_key, tree_column, tree_expanded

A tree table shows nested data: rows with child rows, which have child
rows of their own, and so on. Name the row entry that holds the child
rows with C<children_key>:

	my $table = Term::Fabulous::Widget::Table->new(
		id           => 'files',
		row_id       => 'path',
		children_key => 'children',
		columns      => [
			{ key => 'name', title => 'Name' },
			{ key => 'size', title => 'Size', type => 'number', mutator => bytes() },
		],
		rows => [
			{ path => '/src', name => 'src', size => 18400, children => [
				{ path => '/src/main.c', name => 'main.c', size => 12000 },
				{ path => '/src/lib', name => 'lib', size => 6400, children => [
					{ path => '/src/lib/util.c', name => 'util.c', size => 6400 },
				] },
			] },
			{ path => '/README', name => 'README', size => 900 },
		],
	);

=begin html

<p><img src="/screenshots/cookbook-table-tree.svg" alt="A file tree in a table: folders with open and closed markers, indented files, sizes and dates"></p>

=end html

=over

=item *

Every row at every level is a row of the table, with its own id; ids
must be unique in the whole tree. C<row_id> applies to all levels.

=item *

The child rows are taken out of the row data: C<< $table->row($id) >>
has no C<children> entry, while C<< $table->rows >> returns the whole
tree again with the child rows nested under C<children_key>. Rows
without the key, or with an empty array reference, have no children.

=item *

The I<tree column> shows the tree: it indents each row by two columns
per level and shows a marker in front of rows with children that pass
the filters: C<▸> closed, C<▾> open. It is the column named by C<tree_column>, or the
first visible column when C<tree_column> is not set (or names a hidden
column).

=item *

Rows with children start closed, unless C<< tree_expanded => 1 >>:
then rows with children start open. This applies to rows given to
C<new> and C<rows> and to rows added later.

=item *

Rows are sorted among their siblings, below their parent. Filters keep
the parents of matching rows (see L</Filters with groups and trees>).
Grouping groups the top-level rows only.

=item *

C<children_key> can be changed only while the table has no rows.

=back

=head2 Opening and closing tree rows

The user opens and closes a row by clicking its marker, or with the
cursor on the row: C<Right> or C<+> open it, C<Left> or C<-> close it.
C<Right> on an open row moves to its first child row; C<Left> on a row
that is closed or has no children moves to its parent row. Opening and
closing fire C<Expand> and C<Collapse> with the row's id:

	$table->on( Expand => sub ($event) {
		my $id = $event->row_id // return;    # undef: a group was opened
		say "opened $id";
		return;
	} );

From Perl:

	$table->expand('/src');                 # one or more ids
	$table->collapse( '/src', '/src/lib' );
	$table->expand_all;                     # every row that has children
	$table->collapse_all;
	say 'open' if $table->is_expanded('/src');

These fire no events. A closed row keeps the state of its child rows:
opening it again shows them as they were.

=head2 Changing a tree

	$table->add_row( { path => '/src/new.c', name => 'new.c', size => 10 }, parent => '/src' );
	$table->add_rows( \@files, parent => '/src/lib', index => 0 );    # first children
	$table->remove_row('/src/lib');                                    # with all its children
	my $parent = $table->parent_of('/src/main.c');                     # '/src'; undef at the top
	my @kids   = $table->children_of('/src');                          # child ids, in data order

C<update_row> and C<replace_row> change a row's own data only; giving
them the C<children_key> dies (for C<update_row>) or is ignored (for
C<replace_row>). Add and remove child rows instead.

=head2 Loading child rows when a row opens

A row needs at least one child row to show a marker and be opened. To
load children only when the user opens a row, give it a placeholder
child and replace it on C<Expand>:

	sub folder ($path) {
		return { path => $path, name => $path, children => [ { path => "$path/...", name => 'loading' } ] };
	}

	$table->on( Expand => sub ($event) {
		my $id = $event->row_id // return;
		return unless $table->has_row("$id/...");
		$table->remove_row("$id/...");
		$table->add_rows( [ map { folder($_) } list_folders($id) ], parent => $id );
		return;
	} );

=head1 PAGES

	Parameters: page_size, page_sizes, pager
	Methods:    page, page_count, page_size, next_page, previous_page,
	            page_sizes, pager, page_row_ids
	Events:     PageChange
	KDL:        page_size, page_sizes, pager

With a C<page_size>, the table shows its lines one page at a time, and
a I<pager> below the table:

	« ‹ Page 2 of 7 › »   Rows per page 25 ▾   26–50 of 160

	my $table = Term::Fabulous::Widget::Table->new(
		id         => 'log',
		page_size  => 25,                     # 0 (the default): no pages
		page_sizes => [ 25, 50, 100, 500 ],   # the choices in the pager (default 10, 25, 50, 100)
		columns    => [...],
	);

=over

=item *

Pages count I<lines>: data rows, the child rows of open tree rows and
group headers. A closed group is one line.

=item *

The pager shows buttons for the first, previous, next and last page
(disabled where they lead nowhere), the page number, a list of page
sizes, and which lines are shown out of how many. Its buttons take no
focus (the keys below do the same); the list of page sizes does. When
the table is narrow, the parts of the pager wrap onto more lines.

=item *

The pager shows while C<page_size> is above 0. C<< pager => 0 >> hides
it even then (turn the pages from your program); C<< pager => 1 >>
shows it even without pages, as a count of the lines and a way for the
user to choose a page size.

=item *

A page size that is not in C<page_sizes> is added to the list.

=back

The user turns pages with the pager, with C<Ctrl+PageDown> and
C<Ctrl+PageUp>, and by moving the cursor beyond the page with
C<Ctrl+Home> and C<Ctrl+End>. C<PageUp>, C<PageDown>, C<Home> and C<End>
move only within the page. These page turns and every page size change
by the user fire C<PageChange>. A page turn puts the cursor on the
first line of the new page, so it fires C<CursorMove> first (and, with
C<< selection => 'single' >>, C<SelectionChange> after it). When the
page changes because the cursor's line moved to another page (after a
sort, a filter or a closed group), no C<PageChange> fires.

	$table->on( PageChange => sub ($event) {
		say 'page ', $event->page, ' of ', $table->page_count, ', ', $event->page_size, ' per page';
		return;
	} );

From Perl:

	$table->page(3);                 # turn to page 3; dies below 1, stops at the last page
	say $table->page, ' / ', $table->page_count;
	$table->next_page;               # stops at the last page
	$table->previous_page;           # stops at the first page
	$table->page_size(50);           # 0 ends the pages
	my @ids = $table->page_row_ids;  # the data rows of the shown page

These fire no events. Turning a page puts the cursor on the first line
of the new page. In the other direction, the page follows the cursor:
after a change of the sort, the filters, the page size or the rows, the
table shows the page with the cursor's line.

=head1 SELECTION AND CURSOR

	Parameters: selection, selection_column, cursor_color, selected_color
	Methods:    selection, selection_column, selected_ids, selected_rows,
	            is_selected, set_selection, select, deselect, select_all,
	            clear_selection, cursor, cursor_group, scroll_to_row
	Events:     CursorMove, SelectionChange, RowActivate
	KDL:        selection, selection_column

The I<cursor> and the I<selection> are two different things. The
cursor is one line, the place the keyboard works on, like the cursor in
a text. The selection is a set of rows that the user marked, for
example to delete them all.

=head2 The cursor

=over

=item *

When the view has lines, the cursor is always on one line of the
current page; it starts on the first line. Only an empty view has no
cursor.

=item *

It is drawn in the C<cursor_color> while the table, or a widget in one
of its cells, has the keyboard focus, and the keyboard is not in the
column titles (see L</In the header>). Otherwise it is not shown, but
it is still there. Give the table the focus with C<Tab>, a
click, or C<< $ui->interaction->set_focused_widget($table) >>.

=item *

The user moves it with the keys (see L</KEYS>) and clicks, which fires
C<CursorMove>. The event's C<row_id> is the id of the row it is on now,
or C<undef> on a group header; then its C<group_path> is the group's
path.

=item *

When its line goes away, the cursor moves to the line that stands for
it, and that fires no event. When the row is still there but not shown
(filtered out, or inside a group or tree row that closed), that is the
nearest parent row that is shown, else the header of its group. When
the row was removed, or has no such line, it is the line that is now
at the cursor's place in the view: the next line, or the last line
when the cursor was on the last one.

=back

	my $id   = $table->cursor;         # the row id, or undef on a group header or an empty view
	my $path = $table->cursor_group;   # the group path while on a group header, else undef
	$table->cursor(42);                # put the cursor on row 42, show its page, scroll to it
	$table->scroll_to_row(42);         # the same

C<< cursor($id) >> dies when the row is not shown: when it is filtered
out or inside a closed group or tree row (open it first). It fires no
event and does not change the selection, also not with
C<< selection => 'single' >>.

=head2 Selection

C<selection> chooses whether, and how many, rows can be selected:

=over

=item C<< selection => 'none' >> (the default)

Nothing can be selected. C<set_selection> and C<select> with ids, and
C<select_all>, die; C<deselect> and C<clear_selection> do nothing.

=item C<< selection => 'single' >>

At most one row is selected, and it follows the cursor: when the user
moves the cursor onto a data row, with a key, a click or a page turn,
that row is selected. C<Space> selects the cursor's row. On a group
header, the selection stays as it is.

=item C<< selection => 'multiple' >>

Any number of rows. Moving the cursor does not change the selection.
The user changes it with:

	Space                     select or deselect the cursor's row
	Shift+Up, Shift+Down,     select the range from its start to the new cursor line
	Shift+PageUp/PageDown,
	Shift+Home, Shift+End
	Shift+click               select the range from its start to this row
	Ctrl+A                    select every row that passes the filters; when all of
	                          them are selected already, deselect them
	click                     select only this row
	Ctrl+click, Alt+click     select or deselect this row, keep the others
	click on [ ]              select or deselect this row, keep the others
	click on the [ ] title    the same as Ctrl+A

Rows hidden by the filters are never deselected by C<Ctrl+A> or the
title of the selection column; only rows that pass the filters are. In
a tree, "the rows that pass the filters" include the parent rows that
are shown because a child row matches (see L</Filters with groups and
trees>).

A range starts at the line the cursor was on before the first
C<Shift> key or C<Shift>+click, and the range replaces the selection.
Group headers inside a range are skipped.

=back

With C<< selection => 'multiple' >>, the table shows a I<selection
column> before the first column: C<[x]> for selected rows, C<[ ]> for
the others. Its header shows C<[x]> when all rows that pass the filters
are selected, C<[-]> when some are, C<[ ]> when none are.
C<< selection_column => 0 >> hides it; C<< selection_column => 1 >>
shows it in single mode, too. Selected rows are drawn in the
C<selected_color>; the cursor's line is drawn in the C<cursor_color>,
also when it is selected.

Every change of the selection by the user fires C<SelectionChange>,
after the C<CursorMove> of the same key or click:

	$table->on( SelectionChange => sub ($event) {
		my $selected = $event->selected_ids;    # all selected ids, in data order
		my $added    = $event->added_ids;       # newly selected by this change, in data order
		my $removed  = $event->removed_ids;     # no longer selected
		$status->text( @$selected . ' selected' );
		return;
	} );

From Perl (none of these fire an event):

	my @ids  = $table->selected_ids;      # in data order
	my @rows = $table->selected_rows;     # copies of their data, in the same order
	say 'yes' if $table->is_selected(7);
	$table->set_selection( 1, 2, 3 );     # exactly these
	$table->select(4);                    # add (single mode: replace)
	$table->deselect(2);
	$table->select_all;                   # every row that passes the filters (multiple only)
	$table->clear_selection;
	$table->selection('single');          # change the mode

The selection is independent of the view: rows that are filtered out,
on another page or inside a closed group stay selected. Removed rows
leave it. When C<rows> replaces all rows, rows whose id is still there
stay selected (see L</Row ids>). Changing the mode keeps what the new
mode allows: nothing for C<none>, the first selected row (in data
order) for C<single>.

=head2 Activating a row

C<Enter> on a data row and a double click on it fire C<RowActivate>,
the table's "open this" event. It carries the row's id and a copy of
its data:

	$table->on( RowActivate => sub ($event) {
		show_details( $event->row_id, $event->row );
		return;
	} );

C<Enter> on a group header opens or closes the group instead. Two
clicks on the same line count as a double click when they are at most
C<double_click_seconds> apart (default 0.4). C<Enter> in a widget inside
a cell, and double clicks on input widgets in cells, do not activate
the row.

=head1 STYLES AND BORDERS

	Parameters:        text_color, header_text_color, header_background_color,
	                   group_text_color, group_background_color, cursor_color,
	                   selected_color, hover_color, filter_background_color,
	                   error_color, muted_color, line_color, stripe_color,
	                   background_color, row_style, header_style, group_style,
	                   border, border_top, border_right, border_bottom,
	                   border_left, column_lines, row_lines, header_line,
	                   cell_padding
	Column parameters: style, header_style, cell_style
	Methods:           set_row_style, row_style_of, set_cell_style,
	                   cell_style_of, and accessors for all parameters above
	KDL:               the colors, lines, cell_padding, column { style; header_style }

=head2 Colors

The table's colors are parameters, and accessors of the same name change
them at run time. They take every format of L<Term::Fabulous::Color>
(C<'#e06c75'>, C<[ 224, 108, 117, 255 ]>, C<'rgb(224, 108, 117)'>, ...)
and return C<[ $r, $g, $b, $a ]>.

	text_color                [220, 223, 228]  text of the data cells; the scrollbar's thumb
	header_text_color         [235, 238, 243]  text of the column titles
	header_background_color   [ 36,  40,  50]  background of the column titles, also behind the
	                                           line below them
	group_text_color          [ 97, 175, 239]  text of group headers
	group_background_color    [ 28,  32,  41]  background of group headers and the column chooser
	cursor_color              [ 52,  58,  72]  background of the cursor's line (while focused), of
	                                           the column title the keyboard is on, and of a
	                                           focused filter field
	selected_color            [ 38,  62,  92]  background of selected rows
	hover_color               [ 38,  42,  52]  background of the line under the mouse pointer
	filter_background_color   [ 30,  33,  40]  background of the filter row
	error_color               [224, 108, 117]  text of a filter field with an invalid expression
	muted_color               [140, 146, 158]  the text of an empty table; the pager's count
	line_color                [ 88,  96, 112]  every line, unless a style has a border_color;
	                                           the scrollbar's track
	stripe_color              none             background of every second data row (see below)
	background_color          see below        background of the data cells

The cells always have a background of their own; that is what makes
them receive the mouse. A cell without a color from a style or a state
(cursor, selected, hover, stripe) gets the table's C<background_color>
when it has one, else the background of the nearest ancestor widget
with an opaque background, else C<[22, 25, 31]>. So a table without a
C<background_color> blends into the box it is in.

C<hover> (default 1) turns the hover highlight on or off.

=head2 Striped rows

	stripe_color => '#1c2029',

With a C<stripe_color>, every second data row of the page (the second,
the fourth, ...) gets that background, so long rows are easier to
follow. Group headers do not count. A row or cell style with a
C<background_color> covers the stripe; the cursor, selected and hover
colors cover both.

=head2 Style hashes

Looks and lines of parts of the table are given as I<style hashes>,
hash references such as C<< { text_color => '#e5c07b', bold => 1 } >>.
They go here:

	Where                                         For                      Kind
	------------------------------------------------------------------------------
	column parameter style => {...}               every cell of the column column
	column parameter header_style => {...}        the column's title       header
	column parameter cell_style => sub ($cell)    one cell, per row        cell
	table parameter header_style => {...}         every column title       row
	table parameter group_style => {...}          every group header       row
	table parameter row_style => sub ($row, $id)  one row                  row
	$table->set_row_style( $id, {...} )           one row                  row
	$table->set_cell_style( $id, $key, {...} )    one cell                 cell

C<cell_style> gets the cell context (see L</CELL WIDGETS>); C<row_style>
gets the row's data and its id. Both return a style hash, or C<undef>
for none. They run again when the row's data changes.

The table's C<header_style> is the style of the title row and of the
filter row. Its looks apply to the titles only; its lines apply to both
rows (a C<border_bottom> draws a line below each). The filter row's
background is the C<filter_background_color>, and its lines always have
the C<line_color>.

=head2 Style keys

Every kind of style hash takes these keys for the looks:

	text_color         a color
	background_color   a color
	bold               a boolean
	italic             a boolean
	underline          a boolean
	border_color       a color: of the lines this part draws

and these keys for lines, depending on the kind:

	Kind     Line keys
	-------------------------------------------------------------------------------
	cell     border_top, border_right, border_bottom, border_left
	row      border_top, border_right, border_bottom, border_left, column_lines
	column   border_left, border_right, row_lines
	header   (none)

Here C<column_lines> are the lines between the cells of a row, and
C<row_lines> the lines between the cells of a column. A line is the
name of a line style (C<'Solid'>, C<'Round'>, C<'Heavy'>, C<'Double'>,
C<'Dashed'>, C<'Ascii'> or any other of L<Term::Fabulous::Enum::BorderStyle>),
a L<Term::Fabulous::Enum::BorderStyle> object, or C<'none'> for no line.
A key with the value C<undef> is the same as a missing key: that part
does not decide it. Unknown keys and invalid values die where the style
is given, naming the style and the key.

=head2 Which style wins

For the looks of a data cell, each key is taken from the first of these
that sets it:

	1. set_cell_style           (the cell)
	2. the column's cell_style  (the cell)
	3. set_row_style            (the row)
	4. row_style                (the row)
	5. the column's style       (the column)
	6. the table's colors: text_color, line_color, not bold, not italic, not underlined

The background of a data cell is, in this order: the C<cursor_color>
on the cursor's line while the table has the focus; the
C<selected_color> for a selected row; the C<hover_color> for the line
under the mouse; the C<background_color> of the styles above; the
C<stripe_color> of a striped row; the table's background (see
L</Colors>).

A column title takes each key from the column's C<header_style>, then
the table's C<header_style>, then C<header_text_color>,
C<header_background_color> and C<line_color>; titles are bold unless a
style says C<< bold => 0 >>. A group header takes them from
C<group_style>, then C<group_text_color>, C<group_background_color> and
C<line_color>; it is bold, too, unless C<group_style> says otherwise.

=head2 Styles of rows and cells

Use C<row_style> and C<cell_style> for formatting that follows the
data, and C<set_row_style> and C<set_cell_style> for marks your program
sets on single rows and cells:

	# Overdue tasks in red, done ones in gray (by the data)
	row_style => sub ( $row, $id ) {
		return { text_color => '#808080', italic => 1 } if $row->{done};
		return { text_color => '#e06c75', bold => 1 } if $row->{due} < time;
		return undef;
	},

	# Negative amounts in red (by the cell)
	{ key => 'amount', type => 'number', mutator => number( decimals => 2 ),
	  cell_style => sub ($cell) { ( $cell->{value} // 0 ) < 0 ? { text_color => '#e06c75' } : undef } },

	# Marks set from Perl
	$table->set_row_style( $id, { background_color => '#3b3222' } );       # highlight a row
	$table->set_cell_style( $id, 'amount', { bold => 1, underline => 1 } );
	$table->set_row_style( $id, {} );                                        # remove the mark
	my $style = $table->row_style_of($id);       # what set_row_style set (a copy; {} when nothing)
	my $cell  = $table->cell_style_of( $id, 'amount' );

C<set_row_style> and C<set_cell_style> replace what was set for the row
or cell before; an empty hash removes it. They keep their styles until
the row is removed. To change the C<row_style> code later, call
C<< $table->row_style( sub { ... } ) >>; a column's C<cell_style> with
C<update_column>.

=head2 Lines between and around the cells

The table draws its lines itself, joined into one grid: where lines
meet, it uses the matching junction glyphs (C<┬ ┼ ╪ ╞ ...>), also
where lines of different styles meet. These table parameters set the
lines:

	border         [Round]   the frame around the table, all four sides
	border_top     [border]  one side of the frame, overriding border
	border_right   [border]
	border_bottom  [border]
	border_left    [border]
	column_lines   [Solid]   the lines between the columns
	row_lines      [none]    the lines between the rows
	header_line    [Solid]   the line below the column titles (and the filter row)
	line_color               the color of all lines (see Colors)

Each takes a line style name, a L<Term::Fabulous::Enum::BorderStyle>
object, C<'none'> for no line, or C<undef>. C<undef> means no line,
with two exceptions in the constructor: an C<undef> side of the frame
takes the style of C<border>, and an C<undef> C<header_line> takes the
style of C<row_lines>. Use C<'none'> to be sure there is no line. With a
filter row, C<header_line> is the line below the filter row, and
C<row_lines> (and a column's C<row_lines>) draw the line between the
titles and the filter row.

Which styles to use:

=over

=item Line styles, for every line

C<Solid>, C<Round>, C<Heavy>, C<Double>, C<Dashed> and C<Ascii> draw
thin lines and join into one grid, also with each other: a C<Heavy>
frame with C<Solid> column lines gets C<┯> and C<┿> where they meet.
Unicode has junction glyphs for light lines meeting heavy ones and for
light lines meeting double ones, but none for heavy lines meeting double
ones: there the table uses the glyph of the horizontal line's style (a
heavy vertical line crossing a double horizontal line is drawn as
C<╬>).

=item Block styles, for the frame only

C<Outer>, C<Inner> and C<Thick> draw the frame with half and full
blocks that lie on the edge of the terminal cells (see
L<Term::Fabulous::Enum::BorderStyle/STYLES>). Lines inside the table
end at such a frame, which runs on straight where they meet it. Use them
only for C<border> and the four C<border_*> sides; for inner lines,
use the line styles. They suit tables with colored cells best (see
L</Tables with colored backgrounds>).

=item Other styles

The other styles of L<Term::Fabulous::Enum::BorderStyle> (C<Panel>,
C<Tall>, C<Wide>, C<Block>, the shades, ...) are not made for tables:
they are drawn, but where they meet other lines the result is not
clean.

=back

	# A grid like a spreadsheet
	border => 'Solid', row_lines => 'Solid',

	# No lines at all, a compact list
	border => 'none', column_lines => 'none', header_line => 'none',

	# A double frame and a heavy line under the titles
	border => 'Double', header_line => 'Heavy',

Grid lines take space: every grid line is one terminal row (or one
terminal cell wide).
A line that is only drawn in some places (see the next section) still
keeps its space everywhere, drawn blank where there is no line, so that
the cells stay aligned.

The table's own C<border> is not the C<border_width> and C<border_style>
that every L<Term::Fabulous::Widget::Box> has. Those still work and draw
a second frame around the whole table, pager included; you rarely want
both.

=head2 Tables with colored backgrounds

A thin line glyph (C<│>, C<─>) sits in the middle of its terminal cell,
and the whole cell has one background color. So with colored cells
(column titles on a background, striped rows, a highlighted row), the
color of a cell next to a line also shows on the line's other side,
half a cell beyond it: a highlighted row's color runs through the
column lines, and the line under the titles sits inside the titles'
color.

For tables whose rows and titles have colors of their own, a frame in
a block style and no inner lines usually looks best. The block glyphs
of C<Outer> and C<Inner> lie on the edge of the cells, so every color
inside ends exactly at the frame, and the colors themselves separate the
titles from the rows and the rows from each other:

	my $table = Term::Fabulous::Widget::Table->new(
		id                      => 'staff',
		border                  => 'Outer',     # or 'Inner': the frame inside the table's edge
		column_lines            => 'none',
		header_line             => 'none',
		line_color              => '#4b5568',
		header_background_color => '#2c3340',
		stripe_color            => '#1c2029',
		cell_padding            => 2,           # space instead of column lines
		columns                 => [...],
	);

=begin html

<p><img src="/screenshots/cookbook-table-colors.svg" alt="A table with an Outer block frame, no inner lines, colored column titles, striped rows and a highlighted row whose color reaches the frame"></p>

=end html

Both enclose the colors. C<Outer> draws its blocks on the outer half of
the frame's cells, and the cells' colors fill the inner half up to the
blocks; C<Inner> draws on the inner half,
right next to the cells, with the background around the table on the
outer half. Column lines can still be used with a block frame (they end
at it), but they carry the cell colors as described above.
L<Term::Fabulous::Cookbook/TABLES> has the complete program.

=head2 Lines of columns, rows and cells

The style hashes of columns, rows and cells can add, change or remove
lines in their place (see L</Style keys> for which keys each kind
takes):

	# A heavy line left of the 'total' column, and lines between its cells
	{ key => 'total', style => { border_left => 'Heavy', row_lines => 'Dashed' } }

	# A double line above the totals row
	$table->set_row_style( $total_id, { border_top => 'Double', bold => 1 } );

	# A heavy box around one cell
	$table->set_cell_style( $id, 'total', { map { ( "border_$_" => 'Heavy' ) } qw(top right bottom left) } );

	# No line between the cells of one row
	$table->set_row_style( $id, { column_lines => 'none' } );

	# A line under every group header
	group_style => { border_bottom => 'Solid' },

Each piece of a line between two cells takes the first style that is
named, in this order:

	1. the cell styles of the two cells next to it   (border_*)
	2. the row styles of their rows                  (border_*, column_lines)
	3. the column styles of their columns            (border_left, border_right, row_lines)
	4. the table's lines                             (border*, column_lines, row_lines, header_line)

When the two cells (or rows, or columns) on both sides of a piece name
different styles, the one below or to the right wins. C<'none'> also
counts as named: it removes the line there, even when a less specific
level has one.

A piece of line takes the C<border_color> of the cell that draws it:
the cell to its right for a vertical line (the last cell of a row for
the right side of the frame), and the cell below it for a horizontal
line, with three exceptions: the column titles draw the line below
them, the last row draws the bottom of the frame, and the row above a
group header draws the line between them. So C<< border_color >> in a
row style colors the line above the row and the lines left of its cells.

=head2 Cell padding

	cell_padding => 1,                                         # one column left and right (the default)
	cell_padding => 0,                                         # none: text touches the lines
	cell_padding => { left => 1, right => 1, top => 1, bottom => 0 },    # an empty line above each cell

C<cell_padding> is the empty space inside every cell, header and group
cells included, around its content. A number sets the left and the
right padding; a hash sets the sides it names and 0 for the others.

=head1 SIZE AND SCROLLING

	Parameters: layout (of every Box), scrollbar
	Methods:    scroll_to_row, cursor, body

Unless told otherwise, a table is as wide as its columns and as high as
its lines, its column titles and its pager. When its parent has less
room, it gets smaller and its rows scroll: the column titles stay at
the top, the rows scroll up and down below them, and sideways together
with the titles.

To make a table fill its parent, or take part of it, give it a sizing
like any L<Term::Fabulous::Widget::Box> (see
L<Term::Fabulous::Manual/Sizing>):

	use Clay::XS qw(sizing_grow sizing_fixed);

	my $table = Term::Fabulous::Widget::Table->new(
		id      => 'log',
		columns => [ { key => 'time' }, { key => 'message', width => 'grow' } ],
		layout  => { sizing => { width => sizing_grow(), height => sizing_grow() } },
	);

A table wider than its columns lets C<grow> and C<percent> columns take
the extra width; without such columns, the columns keep their width and
the table's background shows to their right. A table higher than its
lines shows its background below the last line (or the pager).

The rows scroll with the mouse wheel over them (a horizontal wheel, or
a sideways tilt, scrolls sideways) and follow the cursor: when the
cursor moves out of sight, the rows scroll until its line is visible.
A new page starts at its top. From Perl, C<< $table->scroll_to_row($id) >>
moves the cursor to a row and scrolls it into view.

The I<scrollbar> is one column right of the frame. While the rows do
not fit, it shows a track with a thumb for the visible part; clicking
or dragging on it scrolls. C<< scrollbar => 0 >> removes it, and the
column it takes.

=head1 PRINTING A TABLE

A table works with L<Term::Fabulous::Static>, which draws a widget tree
once and prints it, to a terminal, a file or a pipe. That makes a table
a good way to print a report:

	use Term::Fabulous::Static;

	my $table = Term::Fabulous::Widget::Table->new(
		id        => 'report',
		columns   => [...],
		rows      => \@rows,
		sort      => ['name'],
		scrollbar => 0,          # nothing scrolls on paper
		hover     => 0,
	);
	Term::Fabulous::Static->new( root => $table, width => 100 )->print;

Without the focus, no cursor is drawn. Leave out C<page_size> to print
all rows (or set it and C<page> to print one page), and C<filter_row>
and C<selection>.

The cells always have an opaque background (see L</Colors>): without a
C<background_color> on the table or a widget around it, a printed table
is a dark block, also on a light terminal. Give the table (or the root
widget) a C<background_color> that suits the report. The column titles
show the sort markers of a sorted table; there is no option to hide
them. See L<Term::Fabulous::Cookbook/TABLES> for a complete
program.

=head1 CONSTRUCTOR

=head2 new

	my $table = Term::Fabulous::Widget::Table->new( id => 'orders', %parameters );

Makes a table. C<id> is required. Unknown parameters and invalid values
die, naming the parameter. The parameters of
L<Term::Fabulous::Widget::Box/CONSTRUCTOR> work too; the useful ones
are C<layout> (only its C<sizing>; see L</SIZE AND SCROLLING>) and
C<background_color> (see L</Colors>). Most parameters have an accessor
of the same name, described under L</METHODS>.

=head3 Data

=over

=item C<id>

Required. A string, unique among the widgets of the program, as for
every widget. The table also uses the id C<"$id/body"> for its
scrolling body, so that one must not be used either.

=item C<columns>

An array reference of column definitions, hash references (see
L</COLUMNS> and L<Term::Fabulous::Widget::Table::Column/PARAMETERS>) or
L<Term::Fabulous::Widget::Table::Column> objects. Default: no columns.
Two columns with the same key die.

=item C<rows>

An array reference of hash references, the rows (see L</ROWS>). They
are copied. Default: no rows.

=item C<row_id>

Where row ids come from: a key of the rows, a code reference
C<< sub ($row) { ... } >>, or C<undef> (the default) for ids the table
counts up from 1. See L</Row ids>.

=item C<children_key>

The key under which a row holds its child rows, as an array reference
of rows; this makes the table a tree (see L</TREES>). Default: C<undef>,
no tree.

=item C<tree_expanded>

A boolean. Default: 0. When true, rows with children start open.

=item C<tree_column>

The key of the column that shows the tree's indentation and markers.
Default: C<undef>, the first visible column.

=back

=head3 Sorting, filtering, grouping, pages

=over

=item C<sort>

An array reference of column keys (ascending) and C<[ $key, 'asc' ]> or
C<[ $key, 'desc' ]> pairs; the first one decides first. Default: C<[]>,
unsorted. See L</SORTING>.

=item C<filter_row>

A boolean. Default: 0. When true, a row of filter fields shows below
the column titles. See L</The filter row>.

=item C<group_by>

A column key, or an array reference of column keys (outermost first).
Default: no groups. See L</GROUPING>.

=item C<group_label>

A code reference that gets a hash about a group and returns the text or
the widget of its header. Default: C<undef>, C<Title: value (count)>.
See L</Group headers>.

=item C<page_size>

A non-negative integer, the number of lines per page. Default: 0, no
pages. See L</PAGES>.

=item C<page_sizes>

An array reference of positive integers, the page sizes the pager
offers. Default: C<[10, 25, 50, 100]>.

=item C<pager>

C<undef> (the default): show the pager while C<page_size> is above 0.
1: always show it. 0: never.

=back

=head3 Selection and input

=over

=item C<selection>

C<'none'> (the default), C<'single'> or C<'multiple'>. See
L</Selection>.

=item C<selection_column>

A boolean: whether the selection column with check boxes is shown.
Default: C<undef>, which means 1 for C<'multiple'> and 0 otherwise.
Never shown with C<'none'>.

=item C<hover>

A boolean. Default: 1. Whether the line under the mouse pointer is
highlighted with the C<hover_color>.

=item C<double_click_seconds>

A number of seconds, at least 0. Default: 0.4. Two clicks on the same
line at most this far apart are a double click. Only a parameter; there
is no accessor.

=back

=head3 Parts shown

=over

=item C<header>

A boolean. Default: 1. Whether the column titles are shown. Without
them, the user cannot sort by clicking, and C<Up> does not lead into the
header.

=item C<scrollbar>

A boolean. Default: 1. Whether the scrollbar column is shown right of
the rows.

=item C<empty_text>

A string. Default: C<'No rows'>. Shown, in the C<muted_color> and
italic, when the table has no rows.

=item C<no_match_text>

A string. Default: C<'No rows match'>. Shown instead when the table has
rows but none passes the filters.

=back

=head3 Lines and spacing

=over

=item C<border>

The line style of all four sides of the frame. Default: C<'Round'>. See
L</Lines between and around the cells> for the values of this and the
following parameters.

=item C<border_top>, C<border_right>, C<border_bottom>, C<border_left>

One side of the frame. Default: C<undef>, the style of C<border>.

=item C<column_lines>

The lines between the columns. Default: C<'Solid'>.

=item C<row_lines>

The lines between the rows. Default: C<undef>, none.

=item C<header_line>

The line below the column titles and the filter row. Default:
C<'Solid'>.

=item C<cell_padding>

A non-negative integer (the left and right padding) or a hash reference
with any of C<left>, C<right>, C<top> and C<bottom>. Default: 1. See
L</Cell padding>.

=back

=head3 Styles and colors

=over

=item C<row_style>

A code reference C<< sub ( $row, $id ) { ... } >> that returns a style
hash of the I<row> kind, or C<undef>. Default: none. See L</Styles of
rows and cells>.

=item C<header_style>

A style hash of the I<row> kind for the column titles. Default: none.

=item C<group_style>

A style hash of the I<row> kind for group headers. Default: none.

=item C<stripe_color>

A color, or C<undef> (the default) for no stripes. See L</Striped
rows>.

=item C<text_color>, C<header_text_color>, C<header_background_color>, C<group_text_color>, C<group_background_color>, C<cursor_color>, C<selected_color>, C<hover_color>, C<filter_background_color>, C<error_color>, C<muted_color>, C<line_color>

Colors in any format of L<Term::Fabulous::Color>. See L</Colors> for
what each one colors and its default.

=back

=head1 METHODS

The methods are listed by topic. Unless a method says otherwise:

=over

=item *

A method that changes the table fires B<no> event. The change shows in
the next frame.

=item *

A method that is not an accessor and changes the table returns the
table, so calls can be chained.

=item *

Accessors return the value when called without an argument, and set it
with one. Setting returns the new value, except for C<rows>, C<search>,
C<filter_text>, C<group_by>, C<page>, C<page_size> and C<cursor>, which
return the table.

=item *

Methods that take a row id die when no row has that id; methods that
take a column key die when there is no such column.

=back

=head2 Methods for rows

=head3 rows

	my $rows = $table->rows;
	$table->rows( \@rows );

Without an argument: copies of all rows as an array reference, in data
order, in the form you gave them (in a tree, with the child rows nested
under C<children_key>). With an array reference of hash references:
replaces all rows. Rows whose id stays keep their selection; all tree
rows are closed again (or open, with C<tree_expanded>). Returns the
table.

=head3 add_row

	my $id = $table->add_row( \%row );
	my $id = $table->add_row( \%row, index => 0 );
	my $id = $table->add_row( \%row, parent => $parent_id, index => 2 );

Adds one row and returns its id. C<index> is the position among its
siblings in data order (0 is the first; default: after the last);
C<parent> makes it a child row of that row, which needs a tree. Dies
for an index out of range, an id in use, or other options.

=head3 add_rows

	my @ids = $table->add_rows( \@rows, %options );

Adds several rows, at one position, with the same options as
C<add_row>. Returns their ids. If one row is invalid, none is added.

=head3 update_row

	$table->update_row( $id, { name => 'Ada L.', team => 'Web' } );

Merges the hash of changes into the row's data. The keys need not be
column keys. Dies when the changes would give the row another id, or
contain C<children_key>. Returns the table.

=head3 replace_row

	$table->replace_row( $id, \%data );

Replaces the row's data with a copy of C<\%data> (an entry under
C<children_key> is ignored; the child rows stay). Dies when the data
would give the row another id. Returns the table.

=head3 set_value

	$table->set_value( $id, $key, $value );

Sets one entry of the row's data. C<$key> must be a column key; use
C<update_row> for other entries. Returns the table.

=head3 remove_row

	$table->remove_row($id);

Removes a row and all its child rows. They leave the selection, and
their styles from C<set_row_style> and C<set_cell_style> are forgotten.
Returns the table.

=head3 remove_rows

	$table->remove_rows(@ids);

Like C<remove_row>, for several rows. Dies before removing anything
when one of the ids is unknown.

=head3 clear_rows

	$table->clear_rows;

Removes all rows. Returns the table.

=head3 row

	my $data = $table->row($id);

A copy of the row's data (without its child rows).

=head3 value

	my $raw = $table->value( $id, $key );

The raw value of a cell: what the column reads or computes from the
row.

=head3 display_value

	my $text = $table->display_value( $id, $key );

The display text of a cell: the raw value after the column's mutators,
as a string (C<''> for C<undef>).

=head3 has_row

	if ( $table->has_row($id) ) { ... }

1 when a row has the id, 0 otherwise. Never dies.

=head3 row_ids

	my @ids = $table->row_ids;

The ids of all rows, in data order (in a tree: each row, then its
children).

=head3 row_count

	my $count = $table->row_count;

The number of rows, child rows included, filtered or not.

=head3 filtered_row_ids

	my @ids = $table->filtered_row_ids;

The ids of the rows that pass the filters and the search, in view order
(sorted and grouped), including rows inside closed groups and tree
rows.

=head3 page_row_ids

	my @ids = $table->page_row_ids;

The ids of the data rows on the current page, in the order they are
shown.

=head3 parent_of

	my $parent = $table->parent_of($id);

The id of the row's parent row, or C<undef> for a top-level row.

=head3 children_of

	my @ids = $table->children_of($id);

The ids of the row's child rows, in data order (all of them, filtered
or not).

=head2 Methods for columns

=head3 columns

	my @columns = $table->columns;

The L<Term::Fabulous::Widget::Table::Column> objects, in order, hidden
ones included.

=head3 column

	my $column = $table->column('salary');

One column object. Dies for an unknown key.

=head3 column_keys

	my @keys = $table->column_keys;

The keys of all columns, in order, hidden ones included.

=head3 add_column

	my $column = $table->add_column( \%definition );
	my $column = $table->add_column( \%definition, index => 0 );

Adds a column at the end, or at C<index> (0 is the first). Returns the
new column object. Dies when a column has the key already, for an index
out of range, or other options.

=head3 remove_column

	$table->remove_column('email');

Removes a column, also from the sort and the grouping, with every filter
that compares it and its filter field text. Returns the table.

=head3 move_column

	$table->move_column( email => 0 );

Moves a column to an index (0 is the first, the highest is the number of
columns minus 1). Returns the table.

=head3 update_column

	my $column = $table->update_column( salary => title => 'Pay', align => 'center' );

Replaces a column with a new one made from its parameters and the
changes, and returns the new column object. The column keeps its place
and whether it is visible. The C<key> cannot be changed (that dies).

=head3 visible_columns

	my @keys = $table->visible_columns;

The keys of the visible columns, in order.

=head3 is_column_visible

	if ( $table->is_column_visible('email') ) { ... }

1 or 0.

=head3 show_columns

	$table->show_columns(qw(email phone));

Shows the named columns, each at its place in the order of the columns.
Returns the table.

=head3 hide_columns

	$table->hide_columns('note');

Hides the named columns. Returns the table.

=head3 set_visible_columns

	$table->set_visible_columns(qw(name team));

Shows exactly the named columns and hides all others. The order of the
columns does not change. Returns the table.

=head3 open_column_chooser

	$table->open_column_chooser;

Opens the column chooser (see L</Choosing the visible columns>) and
gives it the focus. Does nothing when it is open. Returns the table.
Changes the user makes in it fire C<ColumnsChange>.

=head3 close_column_chooser

	$table->close_column_chooser;

Closes the column chooser; when it had the focus, the table gets the
focus. Does nothing when it is closed. Returns the table.

=head3 is_column_chooser_open

1 while the column chooser is open, 0 otherwise.

=head2 Methods for sorting

=head3 sort_by

	$table->sort_by( 'team', [ salary => 'desc' ] );
	$table->sort_by;    # no sort

Sorts by the columns given, replacing the sort (see L</Sorting from
Perl>). Without arguments, the table is unsorted. Dies for an unknown
column, a direction other than C<'asc'> or C<'desc'>, or a column named
twice. Returns the table.

=head3 clear_sort

	$table->clear_sort;

The same as C<sort_by> without arguments.

=head3 sort_spec

	my $spec = $table->sort_spec;    # [ [ 'team', 'asc' ], [ 'salary', 'desc' ] ]

The sort, as an array reference of C<[ $key, $direction ]> pairs (a
copy). C<[]> when unsorted.

=head2 Methods for filtering

=head3 filter

	$table->filter( $name => $filter );
	$table->filter( $name => sub ($row) { ... } );
	$table->filter( $name => undef );    # remove it

Sets the filter of a name: a L<Term::Fabulous::Widget::Table::Filter>,
a code reference (called with a copy of each row's data; true keeps the
row), or C<undef> to remove it. A filter under the same name is
replaced. Dies for a name that is not a non-empty string or that starts
with C<column:> (those belong to the filter row), for a filter of
another kind, and for a filter that names an unknown column or compares
with a value its column's type cannot read. In a tree, opens the rows
that lead to matching rows. Returns the table.

=head3 remove_filter

	$table->remove_filter('adults');

Removes the filter of that name; does nothing when there is none.
Returns the table.

=head3 filter_names

	my @names = $table->filter_names;

The names of the filters set with C<filter>, in the order they were
first set. The filter row's filters are not listed.

=head3 clear_filters

	$table->clear_filters;

Removes all filters: those set with C<filter>, the search, and the text
of every filter field. Returns the table.

=head3 search

	$table->search('ada');
	my $text = $table->search;

Accessor for the search text (see L</Searching all columns>). C<''>
or C<undef> ends the search. Setting it returns the table. In a tree,
opens the rows that lead to matching rows.

=head3 filter_text

	$table->filter_text( size => '>=1000' );
	my $text = $table->filter_text('size');

Accessor for the filter expression of a column's filter field (see
L</The filter row>), also while the filter row is hidden. C<''> or
C<undef> removes the column's filter. An invalid expression does not
die: the column is then unfiltered, and C<filter_error> says why.
Setting it returns the table and fires no C<FilterChange>.

=head3 filter_error

	my $message = $table->filter_error('size');

Why the column's filter expression is invalid, or C<undef> when it is
valid or empty.

=head3 filter_row

	$table->filter_row(1);
	my $shown = $table->filter_row;

Accessor for the C<filter_row> parameter. Hiding the filter row keeps
the filters of its fields; use C<clear_filters> or C<filter_text> to
remove them. Setting it returns the new value.

=head2 Methods for groups

=head3 group_by

	$table->group_by( 'team', 'city' );
	$table->group_by(undef);           # no groups
	my @keys = $table->group_by;

Groups by the columns given, outermost first (see L</GROUPING>), and
returns the table. Without arguments, returns the keys of the group
columns (an empty list when not grouped). Dies for an unknown column or
a column named twice.

=head3 ungroup

	$table->ungroup;

Ends the grouping. Returns the table.

=head3 is_group_expanded

	if ( $table->is_group_expanded( 'Sales', 'Berlin' ) ) { ... }

1 when the group with that path is open, 0 when it is closed. Also 1
for a path that names no group.

=head3 expand_group

	$table->expand_group('Sales');
	$table->expand_group( 'Sales', 'Berlin' );

Opens the group with that path (the raw values of the group and the
groups around it, outermost first). Returns the table.

=head3 collapse_group

	$table->collapse_group( 'Sales', 'Berlin' );

Closes the group with that path. Returns the table.

=head3 expand_all_groups

	$table->expand_all_groups;

Opens every group, nested groups included. Returns the table.

=head3 collapse_all_groups

	$table->collapse_all_groups;

Closes every group there is now (with the current filters), nested
groups included. Groups that appear later start open. Returns the
table.

=head3 cursor_group

	my $path = $table->cursor_group;

The path of the group header the cursor is on (an array reference), or
C<undef> when the cursor is on a data row or there is no cursor.

=head2 Methods for trees

=head3 is_expanded

	if ( $table->is_expanded($id) ) { ... }

1 when the row is open, 0 otherwise.

=head3 expand

	$table->expand( '/src', '/src/lib' );

Opens the rows with these ids. Returns the table.

=head3 collapse

	$table->collapse('/src');

Closes the rows with these ids; their child rows keep their own state.
Returns the table.

=head3 expand_all

	$table->expand_all;

Opens every row that has child rows. Returns the table.

=head3 collapse_all

	$table->collapse_all;

Closes every row that has child rows. Returns the table.

=head3 children_key

	$table->children_key('children');

Accessor for the C<children_key> parameter. Setting it dies while the
table has rows; set it before adding rows. Setting returns the new
value.

=head3 tree_expanded

	$table->tree_expanded(1);

Accessor for the C<tree_expanded> parameter. Setting it affects rows
added afterwards, not the rows the table has. Setting returns the new
value.

=head3 tree_column

	$table->tree_column('name');
	$table->tree_column(undef);    # the first visible column

Accessor for the C<tree_column> parameter. Dies for an unknown column.
Setting returns the new value.

=head2 Methods for pages

=head3 page

	$table->page(3);
	my $page = $table->page;    # from 1

Accessor for the current page, counted from 1. Setting turns to that
page (a number above the last page turns to the last page) and puts the
cursor on its first line; it dies for a number that is not a whole
number from 1. Setting returns the table. Without pages, the page is
always 1.

=head3 page_count

	my $pages = $table->page_count;

The number of pages, at least 1.

=head3 page_size

	$table->page_size(50);
	my $size = $table->page_size;

Accessor for the number of lines per page, 0 for no pages. Setting
keeps the cursor on its line and shows that line's page; it returns the
table. Dies for a value that is not a non-negative integer.

=head3 next_page

	$table->next_page;

Turns one page forward; on the last page, nothing happens. Returns the
table.

=head3 previous_page

	$table->previous_page;

Turns one page back; on the first page, nothing happens. Returns the
table.

=head3 page_sizes

	$table->page_sizes( [ 20, 50 ] );

Accessor for the C<page_sizes> parameter. Setting returns a copy of the
new list.

=head3 pager

	$table->pager(0);

Accessor for the C<pager> parameter (C<undef>, 1 or 0). Setting returns
the new value.

=head2 Methods for selection and cursor

=head3 selection

	$table->selection('multiple');
	my $mode = $table->selection;

Accessor for the selection mode. Setting keeps the part of the
selection the new mode allows (see L</Selection>), shows or hides the
selection column as C<selection_column> says, and returns the new mode.

=head3 selection_column

	$table->selection_column(0);

Accessor for the C<selection_column> parameter. Once set (by parameter
or accessor), it no longer follows the selection mode. Setting returns
the new value.

=head3 selected_ids

	my @ids = $table->selected_ids;

The ids of the selected rows, in data order.

=head3 selected_rows

	my @rows = $table->selected_rows;

Copies of the data of the selected rows, in data order.

=head3 is_selected

	if ( $table->is_selected($id) ) { ... }

1 or 0. Never dies.

=head3 set_selection

	$table->set_selection(@ids);
	$table->set_selection;    # nothing selected

Selects exactly these rows. Dies with C<< selection => 'none' >> when
ids are given, and for more than one id with C<'single'>. Returns the
table.

=head3 select

	$table->select(@ids);

Adds rows to the selection; with C<'single'>, selects the row instead
of the one selected before. Dies like C<set_selection>. Returns the
table.

=head3 deselect

	$table->deselect(@ids);

Removes rows from the selection. Returns the table.

=head3 select_all

	$table->select_all;

Adds every row that passes the filters to the selection. Dies unless
the mode is C<'multiple'>. Returns the table.

=head3 clear_selection

	$table->clear_selection;

Selects nothing. Returns the table.

=head3 cursor

	my $id = $table->cursor;
	$table->cursor($id);

Without an argument: the id of the row the cursor is on, or C<undef>
when it is on a group header or the view is empty. With a row id: puts
the cursor on that row, turns to its page, scrolls it into view and
returns the table. Dies when the row is not shown (filtered out, or
inside a closed group or tree row). Does not change the selection. See
L</The cursor>.

=head3 scroll_to_row

	$table->scroll_to_row($id);

The same as C<< $table->cursor($id) >>.

=head2 Methods for styles

=head3 set_row_style

	$table->set_row_style( $id, { background_color => '#3b3222', border_top => 'Double' } );

Sets the style hash (I<row> kind) of a row, replacing what was set for
it before; C<{}> or C<undef> removes it. Dies for unknown keys or
invalid values. Returns the table.

=head3 row_style_of

	my $style = $table->row_style_of($id);

A copy of what C<set_row_style> set for the row (colors as
C<[ $r, $g, $b, $a ]>, lines as L<Term::Fabulous::Enum::BorderStyle>
objects), C<{}> when nothing.

=head3 set_cell_style

	$table->set_cell_style( $id, 'amount', { text_color => '#e06c75' } );

Sets the style hash (I<cell> kind) of one cell, like C<set_row_style>.

=head3 cell_style_of

	my $style = $table->cell_style_of( $id, 'amount' );

A copy of what C<set_cell_style> set for the cell, C<{}> when nothing.

=head3 row_style

	$table->row_style( sub ( $row, $id ) { ... } );
	$table->row_style(undef);

Accessor for the C<row_style> code reference; C<undef> removes it.
Setting returns the new value.

=head3 group_label

	$table->group_label( sub ($group) { ... } );

Accessor for the C<group_label> code reference; C<undef> brings back
the default label. Setting returns the new value.

=head3 header_style

	$table->header_style( { background_color => '#2c313c' } );

Accessor for the C<header_style> style hash. Returns a copy; setting
returns a copy of the checked style.

=head3 group_style

	$table->group_style( { text_color => '#e5c07b' } );

Accessor for the C<group_style> style hash, like C<header_style>.

=head2 Methods for lines and spacing

The line accessors below take a line style name, a
L<Term::Fabulous::Enum::BorderStyle> object, C<'none'> or C<undef> (see
L</Lines between and around the cells>). They return the style as an
object (the C<Hidden> style for C<'none'>), or C<undef> for no line.

=head3 border

	$table->border('Double');
	my $style = $table->border;

Sets all four sides of the frame and returns the style of the top side.
Reading returns the style the four sides share, or C<undef> when they
differ or none has a style.

=head3 border_top

	$table->border_top('Heavy');

Accessor for the top side of the frame.

=head3 border_right

Accessor for the right side of the frame.

=head3 border_bottom

Accessor for the bottom side of the frame.

=head3 border_left

Accessor for the left side of the frame.

=head3 column_lines

	$table->column_lines('none');

Accessor for the lines between the columns.

=head3 row_lines

	$table->row_lines('Dashed');

Accessor for the lines between the rows.

=head3 header_line

	$table->header_line('Heavy');

Accessor for the line below the column titles.

=head3 cell_padding

	$table->cell_padding( { left => 2, right => 2 } );
	my $padding = $table->cell_padding;    # { left => 2, right => 2, top => 0, bottom => 0 }

Accessor for the C<cell_padding> parameter; returns a hash with all four
sides. Setting rebuilds every cell.

=head2 Methods for colors

	$table->cursor_color('#3e4451');
	my $rgba = $table->cursor_color;    # [ 62, 68, 81, 255 ]

Every color has an accessor of its name. It takes any format of
L<Term::Fabulous::Color> and returns C<[ $r, $g, $b, $a ]>; an invalid
color dies and keeps the old one. L</Colors> describes what each color
colors.

=head3 text_color

The text of the data cells, and the scrollbar's thumb.

=head3 header_text_color

The text of the column titles.

=head3 header_background_color

The background of the column titles.

=head3 group_text_color

The text of group headers.

=head3 group_background_color

The background of group headers and of the column chooser.

=head3 cursor_color

The background of the cursor's line while the table has the focus, of
the column title the keyboard is on, and of a focused filter field.

=head3 selected_color

The background of selected rows.

=head3 hover_color

The background of the line under the mouse pointer.

=head3 filter_background_color

The background of the filter row.

=head3 error_color

The text of a filter field with an invalid expression.

=head3 muted_color

The text shown in an empty table, and the pager's count.

=head3 line_color

Every line that no style gives a C<border_color>, and the scrollbar's
track.

=head3 stripe_color

The background of every second data row; C<undef> for no stripes.

=head3 background_color

The background of cells that have no other; C<undef> for the background
of the nearest opaque ancestor.

=head2 Other accessors

Accessors for parameters with a single value. Setting returns the new
value.

=head3 header

	$table->header(0);

Whether the column titles are shown.

=head3 scrollbar

	$table->scrollbar(0);

Whether the scrollbar column is shown.

=head3 hover

	$table->hover(0);

Whether the line under the mouse pointer is highlighted.

=head3 empty_text

	$table->empty_text('Nothing here yet');

The text of a table without rows.

=head3 no_match_text

	$table->no_match_text('Nothing found');

The text of a table whose rows all are filtered out.

=head3 row_id

	$table->row_id('sku');

Where row ids come from (see L</Row ids>). Setting it dies while the
table has rows.

=head2 Widgets of the table

The table builds its widgets itself; these methods give access to them
for reading and testing. Do not add, remove or rearrange their
children.

=head3 cell_widget

	my $widget = $table->cell_widget( $id, $key );

The widget a cell shows: the widget of the column's C<cell> code, or a
L<Term::Fabulous::Widget::Text>. C<undef> when the row is not on the
current page, or the table has not been drawn since the row was added.

=head3 body

The L<Term::Fabulous::Widget::ScrollBox> that holds the rows, with the
id C<"$id/body">.

=head3 pager_widget

The L<Term::Fabulous::Widget::Table::Pager>, also while it is not
shown.

=head3 model

The L<Term::Fabulous::Widget::Table::Model> that holds the data and the
view. Read from it as you like, for example the lines of the view;
change the table only through the table's methods.

=head3 prepare_layout

Called by L<Clay::UI> once per frame, before the layout, when the table
changed (see L<Clay::UI::Role::Core::Preparable>); it brings the
widgets up to date. You do not call it.

=head3 layout_properties

The table of the KDL properties (see L</KDL PROPERTIES> and
L<Term::Fabulous::Role::CanParseLayout/layout_properties>).

=head3 apply_layout_node

Called by L<Term::Fabulous::Layout> when it builds a table from a KDL
node (see L<Term::Fabulous::Role::CanParseLayout>). Dies for child
widget nodes. You do not call it.

=head3 apply_layout_settings

Called by L</apply_layout_node> with the properties of the node. Applies
C<row_id> and C<children_key> first, then the columns, then the other
properties, and C<sort> and C<group_by> last. You do not call it.

=head1 KEYS

The table uses these keys while it has the focus. Keys it does not use
bubble to its ancestors (see L<Term::Fabulous::Manual/KEYBOARD>), among
them C<Tab>, which moves the focus on.

=head2 On the rows

	Up, Down                 the previous or next line of the page
	PageUp, PageDown         as many lines back or forward as the rows show, minus one,
	                         so that one line stays in view (within the page)
	Home, End                the first or last line of the page
	Ctrl+Home, Ctrl+End      the first or last line of all pages
	Ctrl+PageUp              the previous page (the cursor goes to its first line)
	Ctrl+PageDown            the next page
	Up on the first line     into the header (see below), when titles are shown

	Enter                    on a data row: fire RowActivate
	                         on a group header: open or close the group
	Space                    selection 'multiple': select or deselect the row
	                         selection 'single': select the row
	                         on a group header: open or close the group
	Shift+Up, Shift+Down,    selection 'multiple': select the range from the line where the
	Shift+PageUp/PageDown,   range started to the new cursor line
	Shift+Home, Shift+End
	Ctrl+A                   selection 'multiple': select every row that passes the filters,
	                         or none when all are selected

	Right, +                 open the tree row or group; on an open one, Right goes to the
	                         first line inside it
	Left, -                  close the tree row or group; on a closed one (or a row without
	                         children), Left goes to the parent row or the group header above

A moving key fires C<CursorMove> when the cursor moves, then
C<PageChange> when the page changes, then C<SelectionChange> when the
selection changes.

=head2 In the header

C<Up> on the first line of the page moves the keyboard into the row of
column titles; the title it is on is drawn in the C<cursor_color>.

	Left, Right              the previous or next column title
	Home, End                the first or last column title
	Enter                    sort by this column alone: ascending, descending, unsorted
	Space                    add this column to the sort, or cycle its direction
	Enter or Space on [ ]    the same as Ctrl+A on the rows
	c                        open the column chooser
	Down, Escape             back to the rows

=head2 In the filter row

	Enter, Down              back to the rows
	Escape                   empty the field (when it has text)

All other keys edit the text as in any L<Term::Fabulous::Widget::TextField>.
C<Tab> and C<Shift+Tab> move between the fields.

=head2 In the column chooser

	Tab, Shift+Tab           the next or previous check box; Tab after the last one
	                         leaves the chooser, which closes it
	Space, Enter             show or hide the column
	Escape                   close the chooser; the table gets the focus

=head2 In a widget inside a cell

The widget gets the keys first. Movement keys it does not use move the
table's cursor and give the focus back to the table; C<Enter> and
C<Space> are left to the widget. See L</Keys and clicks in cell
widgets>.

=head1 MOUSE

=over

=item *

B<Click on a row>: moves the cursor there (C<CursorMove>). With
C<< selection => 'single' >>, selects the row. With C<'multiple'>, a
plain click selects only that row; C<Ctrl>+click or C<Alt>+click
selects or deselects it and keeps the others; C<Shift>+click selects
the range from where the range started to that row; a click into the
selection column selects or deselects that row and keeps the others.

=item *

B<Double click on a row> (two clicks on the same line within
C<double_click_seconds>): each click does what a click does (moves the
cursor, selects), then the second one fires C<RowActivate>.

=item *

B<Click on a group header> or on the marker of a tree row: opens or
closes it (C<Expand> or C<Collapse>) and moves the cursor there.

=item *

B<Click on a column title>: sorts by it alone (ascending, descending,
unsorted). With C<Shift>, C<Ctrl> or C<Alt>: adds it to the sort, or
cycles it within the sort. A click on the title of the selection column
does what C<Ctrl+A> does on the rows (see L</Selection>).

=item *

B<Right click on a column title>: opens the column chooser.

=item *

B<Click or drag on the scrollbar>: scrolls so that the thumb is
centered where the pointer is.

=item *

B<Wheel>: scrolls the rows up and down; a horizontal wheel scrolls them
sideways, and the titles follow.

=item *

B<Pointer over a row>: with C<< hover => 1 >>, the line under the
pointer is drawn in the C<hover_color>.

=item *

B<Click on an input in a cell>: goes to the input; the table moves its
cursor to the row (with C<< selection => 'single' >>, that selects it).
See L</Keys and clicks in cell widgets>.

=back

=head1 EVENTS

The table fires these events on itself when the user acts; changes from
your program fire none. Listen with C<< $table->on( Name => sub ($event) { ... } ) >>.
Every event bubbles to the table's ancestors like all events (see
L<Term::Fabulous::Manual/Return values and bubbling>), and
C<< $event->target >> is the table. Each event's page describes it in
full.

=over

=item C<CursorMove>

L<Term::Fabulous::Event::CursorMove>: the user moved the cursor.
C<< $event->row_id >> is the row it is on now, or C<undef> on a group
header, where C<< $event->group_path >> is the group's path.

=item C<SelectionChange>

L<Term::Fabulous::Event::SelectionChange>: the user changed the
selection. C<< $event->selected_ids >>, C<< $event->added_ids >> and
C<< $event->removed_ids >> are array references of row ids.

=item C<RowActivate>

L<Term::Fabulous::Event::RowActivate>: C<Enter> on a data row or a
double click on it. C<< $event->row_id >> and C<< $event->row >> (a
copy of its data).

=item C<SortChange>

L<Term::Fabulous::Event::SortChange>: the user changed the sort with a
click or a key in the header. C<< $event->sort >> is the new sort, like
C<sort_spec>.

=item C<FilterChange>

L<Term::Fabulous::Event::FilterChange>: the user changed the text of a
filter field. C<< $event->column >>, C<< $event->text >>, and
C<< $event->error >> (the reason the text is not a valid expression,
else C<undef>).

=item C<PageChange>

L<Term::Fabulous::Event::PageChange>: the user turned the page or
changed the page size. C<< $event->page >> and
C<< $event->page_size >>.

=item C<Expand>, C<Collapse>

L<Term::Fabulous::Event::Expand> and
L<Term::Fabulous::Event::Collapse>: the user opened or closed a tree
row (C<< $event->row_id >>) or a group (C<< $event->group_path >>; the
other one is C<undef>).

=item C<ColumnsChange>

L<Term::Fabulous::Event::ColumnsChange>: the user showed or hid a
column in the column chooser. C<< $event->visible >> is the keys of the
visible columns.

=back

When one key or click causes several events, they come in this order:
C<CursorMove>, C<PageChange>, C<SelectionChange>, then C<RowActivate>,
C<Expand> or C<Collapse>.

To add keys of your own, listen for C<KeyPress> (see
L<Term::Fabulous::Manual/KEYBOARD>). A listener on the table itself
gets every key the table gets, also the ones the table uses (C<Up>,
C<Enter>, ...); it must return C<< Clay::UI::Enum::Result->CONTINUE >>
for keys it does not use, or they stop at the table (C<Tab> too, see
L<Term::Fabulous::Manual/Return values and bubbling>). A listener on an
ancestor of the table gets only the keys the table does not use,
because the table stops the others from bubbling further.

=head1 KDL PROPERTIES

A table can be part of a KDL layout (see
L<Term::Fabulous::Manual/KDL LAYOUT FILES>). The layout describes the
table: its columns, sort, grouping, lines, colors and options. The rows,
everything that is a code reference (mutators, cell widgets,
callbacks), the style hashes C<header_style> and C<group_style> of the
table, and C<double_click_seconds> come from Perl.

	use Term::Fabulous::Widget::Table as Table

	Table "inventory" {
		sizing width=grow height=grow
		selection multiple
		row_id "sku"
		page_size 25
		page_sizes 25 50 100
		filter_row #true
		stripe_color "#1c2029"
		lines frame=Round columns=Solid rows=none header=Heavy color="#5c6370"
		cell_padding left=1 right=1

		column "sku" title="SKU" width="fixed(10)"
		column "name" title="Name" width=grow compare=natural
		column "qty" title="Qty" type=number {
			style text_color="#e5c07b" border_left=Heavy
			header_style text_color="#e5c07b"
		}
		column "updated" title="Updated" type=date visible=#false
		column "category" title="Category"

		sort "qty" "desc"
		sort "name"
		group_by "category"
	}

	use Term::Fabulous::Layout;
	use Term::Fabulous::Widget::Table::Mutator qw(date);

	my $root  = Term::Fabulous::Layout->new( file => 'inventory.kdl' )->build;
	my $table = $root->find_by_id('inventory');    # here the root itself
	$table->rows( \@items );
	$table->update_column( updated => mutator => date() );

The properties:

=over

=item C<column "key" ...>

A column, with the key as its argument. Properties: C<title>, C<type>,
C<width>, C<align>, C<header_align>, C<wrap>, C<sortable>,
C<filterable>, C<filter_on>, C<compare> (not a code reference) and
C<visible>, with the values of the column parameters. Inside its block,
an optional C<style> node and an optional C<header_style> node, whose
properties are the keys of a style hash of the I<column> kind and the
I<header> kind (see L</Style keys>). Repeat C<column> for every column,
in order.

=item C<sort "key" ["asc" or "desc"]>

Adds a column to the sort; the direction defaults to C<asc>. Repeat it
for a sort by several columns, the first one first.

=item C<group_by "key" ...>

The group columns, outermost first.

=item C<lines frame=... top=... right=... bottom=... left=... columns=... rows=... header=... color=...>

The lines: C<frame> is the parameter C<border>, C<top> to C<left> are
C<border_top> to C<border_left>, C<columns> is C<column_lines>, C<rows>
is C<row_lines>, C<header> is C<header_line>, C<color> is
C<line_color>. Each takes a line style name or C<none>. Every key is
optional.

=item C<cell_padding N>, C<cell_padding left=... right=... top=... bottom=...>

The C<cell_padding> parameter.

=item C<page_sizes N N ...>

The C<page_sizes> parameter.

=item C<selection>, C<selection_column>, C<page_size>, C<pager>, C<filter_row>, C<header>, C<scrollbar>, C<hover>, C<row_id>, C<children_key>, C<tree_expanded>, C<tree_column>, C<empty_text>, C<no_match_text>

The parameters of the same names, with one value each (booleans as
C<#true> and C<#false>; C<row_id> only as a key).

=item C<text_color>, C<header_text_color>, ... , C<line_color>, C<stripe_color>

The colors.

=item the properties of a Box

C<sizing>, C<background_color> and the other properties of
L<Term::Fabulous::Widget::Box/KDL PROPERTIES>. Note that a Box's
C<border> property is the Box border around the whole widget, not the
table's frame; the frame is C<lines frame=...>.

=back

C<row_id> and C<children_key> are applied first, then the columns, then
the other properties, and C<sort> and C<group_by> last, wherever they
stand in the block. A table takes no child widget nodes; one dies.

=head1 PERFORMANCE

L<Term::Fabulous> lays out every widget of the screen in every frame
that changed, and a table makes about two widgets per cell. What costs
time is therefore the number of cells B<shown>, not the number of rows:

=over

=item *

Up to a few hundred rows, a table without pages responds at once.

=item *

For more rows, use C<page_size>. With pages, only the cells of one page
are widgets, and a table of 10,000 rows with pages of 50 lines answers a
key press in a few hundredths of a second. Sorting or filtering 10,000
rows takes a few tenths of a second the first time; the table keeps the
display texts, so later searches are fast.

=item *

A table without pages builds widgets for all its rows, about two per
cell. A L<Term::Fabulous> program fits about 8,190 widgets on the
screen by default (C<max_element_count> 8192), so a table of 5 columns
without pages reaches the limit at about 750 rows and then dies when it
is drawn. Raise C<max_element_count> (see L<Term::Fabulous/new>) or,
better, use pages: with a limit high enough, 1,000 rows of 5 columns
without pages take about half a second per key press. The same limit
applies to a large page of many columns.

=item *

Custom C<compare> functions are called for every comparison of a sort;
named comparisons compute one key per row. Mutators and C<value> code
run once per cell and row change.

=back

=head1 CAVEATS

=over

=item *

A table needs an C<id>, and uses C<"$id/body"> as the id of its body.

=item *

A table takes no child widgets: its cells come from its columns and
rows. Do not call C<add_child> on it, and do not change its C<layout>
other than its C<sizing>.

=item *

Cell widgets can be replaced by new ones at any time (see L</When cell
widgets are built>). Keep state in the row data.

=item *

The cursor is drawn only while the table has the focus.

=item *

Changes from your program fire no events. If a listener also has to
run for them, call it yourself.

=item *

Many terminals keep C<Shift>+click for selecting text on the screen and
do not report it to programs; C<Ctrl>+click and the keyboard work
there.

=back

=head1 SEE ALSO

L<Term::Fabulous::Widget::Table::Column>, L<Term::Fabulous::Widget::Table::Mutator>,
L<Term::Fabulous::Widget::Table::Filter>, L<Term::Fabulous::Widget::Table::Value>,
L<Term::Fabulous::Widget::Table::Model>, L<Term::Fabulous::Widget::Table::Style>,
L<Term::Fabulous::Widget::Table::Borders>, L<Term::Fabulous::Widget::Table::Pager>,
L<Term::Fabulous::Widget::Table::ColumnChooser>,
L<Term::Fabulous::Cookbook/TABLES>, L<Term::Fabulous::Manual/TABLES>,
L<Term::Fabulous::Examples>.

=cut
