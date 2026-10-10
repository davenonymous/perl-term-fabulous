package Term::Fabulous::ThemeEditor::FileDialog;

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

our $VERSION = '0.01';

use Object::Pad 0.825;

use Term::Fabulous::Widget::Dialog;

# The dialog that picks a theme file to open, or the file to save a theme
# to: the folders and theme files of a directory, and a field for a name
# or a path.
class Term::Fabulous::ThemeEditor::FileDialog :isa(Term::Fabulous::Widget::Dialog) :strict(params) {
	use Clay::UI::Enum::Result;
	use Clay::XS qw(sizing_fixed sizing_grow CLAY_TOP_TO_BOTTOM);
	use Cwd qw(abs_path);
	use File::Basename qw(basename dirname);
	use File::Spec;
	use POSIX qw(strftime);
	use Scalar::Util qw(weaken);
	use Term::Fabulous::Widget::Box;
	use Term::Fabulous::Widget::Button;
	use Term::Fabulous::Widget::Checkbox;
	use Term::Fabulous::Widget::Table;
	use Term::Fabulous::Widget::Text;
	use Term::Fabulous::Widget::TextField;
	use Term::Fabulous::Unicode qw(string_columns);
	use Term::Fabulous::ThemeEditor::ValueDialog;

	use constant LIST_ID => 'theme-editor-files';

	field $mode      :param :reader;    # open or save
	field $directory :param :reader;
	field $name      :param = '';    # the file name a save starts with
	field $on_done   :param;    # code: ( $path ) or ( undef ) when cancelled
	field $list_rows :param = 10;    # how many entries the list shows

	field $folder;
	field $list;
	field $field;
	field $all_files;
	field $message;
	field $done = 0;

	ADJUST {
		die "Term::Fabulous::ThemeEditor::FileDialog: mode must be 'open' or 'save'" unless $mode eq 'open' || $mode eq 'save';
		$directory = abs_path($directory) // $directory;
		$self->layout( { layout_direction => CLAY_TOP_TO_BOTTOM, sizing => { width => sizing_fixed(70) }, padding => { left => 2, right => 2, top => 1, bottom => 1 }, child_gap => 1 } );
		$self->add_child( Term::Fabulous::Widget::Text->new( text => $mode eq 'open' ? 'Open a theme' : 'Save the theme as', bold => 1 ) );
		$folder = Term::Fabulous::Widget::Text->new( text => '' );
		$self->add_child($folder);

		weaken( my $weak_self = $self );
		$list = Term::Fabulous::Widget::Table->new(
			id           => LIST_ID,
			row_id       => 'name',
			selection    => 'single',
			border       => 'none',
			column_lines => 'none',
			header_line  => 'Solid',
			columns      => [
				{ key => 'name',     title => 'Name',     width => 'grow', sortable => 0 },
				{ key => 'size',     title => 'Size',     width => 'fit',  sortable => 0, align => 'right' },
				{ key => 'modified', title => 'Modified', width => 'fit',  sortable => 0 },
			],
			layout => { sizing => { width => sizing_grow(), height => sizing_grow() } },
		);
		$list->on( RowActivate => sub ($event) { $weak_self->_enter( $event->row_id );   return } );
		$list->on( CursorMove  => sub ($event) { $weak_self->_pointed( $event->row_id ); return Clay::UI::Enum::Result->CONTINUE } );
		$list->on( KeyPress    => sub ($event) { return ( $event->main_key_name // '' ) eq 'Backspace' && $weak_self->_up ? Clay::UI::Enum::Result->HANDLED : Clay::UI::Enum::Result->CONTINUE } );

		$field = Term::Fabulous::Widget::TextField->new( value => $name, placeholder => $mode eq 'open' ? 'A file name or a path' : 'theme.kdl', layout => { sizing => { width => sizing_grow() } } );
		$field->on( Submit => sub ($event) { $weak_self->choose( $event->value ); return } );
		my $line = Term::Fabulous::Widget::Box->new( layout => { sizing => { width => sizing_grow() }, child_gap => 1 } );
		$line->add_child( Term::Fabulous::Widget::Text->new( text => 'File' ), $field );

		$all_files = Term::Fabulous::Widget::Checkbox->new( label => 'Show all files, not only *.kdl' );
		$all_files->on( Change => sub ($event) { $weak_self->_list_directory; return Clay::UI::Enum::Result->CONTINUE } );
		$message = Term::Fabulous::Widget::Text->new( text => '' );

		my $buttons = Term::Fabulous::Widget::Box->new( layout => { child_gap => 2 } );
		foreach my $definition ( [ $mode eq 'open' ? 'Open' : 'Save', ['primary'], sub { $weak_self->choose( $weak_self->typed ) } ], [ 'Cancel', [], sub { $weak_self->close } ] ) {
			my ( $label, $classes, $action ) = @$definition;
			my $button = Term::Fabulous::Widget::Button->new( bordered => 1, classes => $classes, layout => { padding => { left => 1, right => 1 } } );
			$button->add_child( Term::Fabulous::Widget::Text->new( text => $label ) );
			$button->on( Activate => sub ($event) { $action->(); return } );
			$buttons->add_child($button);
		}
		$self->add_child( Term::Fabulous::ThemeEditor::ValueDialog::_framed( $list, $list_rows + 2 ), $line, $all_files, $buttons );
		$self->on( Close => sub ($event) { $weak_self->_closed; return Clay::UI::Enum::Result->CONTINUE } );
		$self->_list_directory;
	}

	# A line above the buttons, shown only while it has something to say.
	method _say ($text) {
		$message->text($text);
		if ( length $text ) {
			$self->insert_children( scalar( @{ $self->children } ) - 1, $message ) unless $self->has_child($message);
		}
		elsif ( $self->has_child($message) ) {
			$self->remove_child($message);
		}
		return;
	}

	method typed () {
		return $field->value;
	}

	method list () {
		return $list;
	}

	# ---------------------------------------------------------------------
	# The directory
	# ---------------------------------------------------------------------

	method _list_directory () {
		$folder->text( 'Folder: ' . _shortened( $directory, 56 ) );
		my @rows;
		push @rows, { name => '../', kind => 'up', size => '', modified => '' } if $directory ne File::Spec->rootdir;
		if ( opendir my $handle, $directory ) {
			my @names = grep { !/\A\./ } readdir $handle;
			closedir $handle;
			my ( @folders, @files );
			foreach my $entry ( sort { fc $a cmp fc $b } @names ) {
				my $path = File::Spec->catfile( $directory, $entry );
				if ( -d $path ) {
					push @folders, { name => "$entry/", kind => 'folder', size => '', modified => _when($path) };
					next;
				}
				next unless $all_files->checked || $entry =~ /\.kdl\z/i;
				push @files, { name => $entry, kind => 'file', size => _size($path), modified => _when($path) };
			}
			push @rows, @folders, @files;
			$self->_say('');
		}
		else {
			$self->_say("Cannot read the folder: $!");
		}
		$list->rows( \@rows );
		return;
	}

	# A path that fits a number of columns: its end, after "...".
	sub _shortened ( $path, $columns ) {
		return $path if string_columns($path) <= $columns;
		my $end = $path;
		$end = substr( $end, 1 ) while string_columns($end) > $columns - 3;
		return "...$end";
	}

	sub _size ($path) {
		my $bytes = -s $path // 0;
		return $bytes < 1024 ? "$bytes B" : $bytes < 1024 * 1024 ? sprintf( '%.1f KiB', $bytes / 1024 ) : sprintf( '%.1f MiB', $bytes / 1024 / 1024 );
	}

	sub _when ($path) {
		my $time = ( stat $path )[9] // return '';
		return strftime( '%Y-%m-%d %H:%M', localtime $time );
	}

	method _go ($path) {
		$directory = abs_path($path) // $path;
		$self->_list_directory;
		return 1;
	}

	method _up () {
		return 0 if $directory eq File::Spec->rootdir;
		return $self->_go( dirname($directory) );
	}

	# Enter on an entry: a folder opens, a file is chosen.
	method _enter ($row_name) {
		return unless defined $row_name;
		my $row = $list->row($row_name);
		return $self->_up if $row->{kind} eq 'up';
		return $self->_go( File::Spec->catdir( $directory, $row_name =~ s{/\z}{}r ) ) if $row->{kind} eq 'folder';
		$self->choose($row_name);
		return;
	}

	# The cursor on a file puts its name into the field.
	method _pointed ($row_name) {
		return unless defined $row_name;
		my $row = $list->row($row_name);
		$field->value($row_name) if $row->{kind} eq 'file';
		return;
	}

	# ---------------------------------------------------------------------
	# Choosing
	# ---------------------------------------------------------------------

	# A name or a path, relative to the directory shown: a folder is opened,
	# a file is the answer (for open it must exist; for save the name gets
	# .kdl when it has no extension).
	method choose ($typed) {
		$typed =~ s/\A\s+|\s+\z//g;
		$typed =~ s{\A~(?=/|\z)}{$ENV{HOME} // '~'}e;
		if ( !length $typed ) {
			$self->_say( $mode eq 'open' ? 'Choose a file, or type its name.' : 'Type a file name.' );
			return $self;
		}
		my $path = File::Spec->file_name_is_absolute($typed) ? $typed : File::Spec->catfile( $directory, $typed );
		if ( -d $path ) {
			$field->value('');
			return $self->_go($path) && $self;
		}
		if ( $mode eq 'open' && !-f $path ) {
			$self->_say("There is no file $path.");
			return $self;
		}
		$path .= '.kdl' if $mode eq 'save' && basename($path) !~ /\./;
		if ( $mode eq 'save' && !-d dirname($path) ) {
			$self->_say( 'There is no folder ' . dirname($path) . '.' );
			return $self;
		}
		$done = 1;
		$self->close;
		$on_done->($path);
		return $self;
	}

	method _closed () {
		return if $done;
		$done = 1;
		$on_done->(undef);
		return;
	}
}

1;

__END__

=head1 NAME

Term::Fabulous::ThemeEditor::FileDialog - The open and save dialog of
the theme editor

=head1 DESCRIPTION

Part of L<Term::Fabulous::ThemeEditor>; not meant to be used on its
own. A L<Term::Fabulous::Widget::Dialog> that lists the folders and the
theme files (C<*.kdl>, or all files when C<Show all files> is checked)
of a directory, with their sizes and modification times, and a field
for a file name or a path.

The list has its frame in the accent color while it has the keyboard
focus. In the list, C<Enter> or a double click opens a folder (C<../> is the
parent folder) or chooses a file, C<Backspace> goes to the parent
folder, and the cursor on a file puts its name into the field. In the
field, C<Enter> takes the name or path: relative to the folder shown,
absolute, or starting with C<~> for the home directory; a folder opens
it. To save, a name without an extension gets C<.kdl>. C<Escape> or
C<Cancel> closes the dialog without a choice.

=head1 CONSTRUCTOR

=head2 new

	Term::Fabulous::ThemeEditor::FileDialog->new(
		mode      => 'save',          # or 'open'
		directory => '.',
		name      => 'ocean.kdl',     # what the field starts with
		on_done   => sub ($path) { ... },    # undef when cancelled
		list_rows => 10,                     # the entries the list shows
	)->open($ui);

=head1 METHODS

=head2 mode, directory

The mode, and the folder the dialog shows.

=head2 choose

Takes a name or a path as the field does.

=head2 typed, list

The text of the field and the list of the folder.

=head1 SEE ALSO

L<Term::Fabulous::ThemeEditor>.

=cut
