package My::Odt::Styles;

# The styles of an OpenDocument text, as far as the reader of
# Term::Fabulous::Cookbook::Documents needs them: which marks the text of
# a style gets (bold, italic, underline, strike), which paragraph styles
# make a title, and the marker of a list item at each level of a list
# style. Styles come from styles.xml (the named styles a user picks) and
# content.xml (the automatic styles a word processor makes for direct
# formatting), and inherit from their parent style.

use v5.32;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

use Object::Pad 0.825;

class My::Odt::Styles :strict(params) {
	use constant BULLET => "\x{2022}";

	# Style name => the name of the style it inherits from; style name =>
	# its own text properties as { attribute => value }; list style name =>
	# { level => { numbered, bullet, prefix, suffix } }.
	field %parent_of;
	field %properties_of;
	field %levels_of_list;

	# The root elements of styles.xml and content.xml, read with the
	# namespace prefixes office, style, text and fo.
	ADJUST :params ( :$roots ) {
		foreach my $root (@$roots) {
			$self->_read_style($_)      foreach $root->descendants('style:style');
			$self->_read_list_style($_) foreach $root->descendants('text:list-style');
		}
	}

	method _read_style ($style) {
		my $name   = $style->att('style:name');
		my $parent = $style->att('style:parent-style-name');
		$parent_of{$name} = $parent if defined $parent;
		my $properties = $style->first_child('style:text-properties') or return;
		$properties_of{$name} = { map { $_ => $properties->att($_) } grep { defined $properties->att($_) } qw(fo:font-weight fo:font-style style:text-underline-style style:text-line-through-style) };
		return;
	}

	method _read_list_style ($list_style) {
		my $name = $list_style->att('style:name');
		foreach my $level ( $list_style->children ) {
			my $number = $level->att('text:level') // next;
			$levels_of_list{$name}{$number}
				= $level->tag eq 'text:list-level-style-number'
				? { numbered => 1, prefix => $level->att('style:num-prefix') // '', suffix => $level->att('style:num-suffix') // '' }
				: { numbered => 0, bullet => $level->att('text:bullet-char') // BULLET };
		}
		return;
	}

	# The style and the styles it inherits from, the style itself first.
	method _lineage ($name) {
		my @lineage;
		while ( defined $name ) {
			die "My::Odt::Styles: the style $name inherits from itself\n" if grep { $_ eq $name } @lineage;
			push @lineage, $name;
			$name = $parent_of{$name};
		}
		return @lineage;
	}

	# The mark kinds of the text of a style. Each property comes from the
	# nearest style that sets it, so a style can switch off what its
	# parent switches on.
	method kinds_of ($name) {
		my %property;
		foreach my $style ( $self->_lineage($name) ) {
			my $own = $properties_of{$style} // next;
			$property{$_} //= $own->{$_} foreach keys %$own;
		}
		my $weight = $property{'fo:font-weight'} // 'normal';
		my @kinds;
		push @kinds, 'bold' if $weight eq 'bold' || ( $weight =~ /\A[0-9]+\z/ && $weight >= 600 );
		push @kinds, 'italic' if ( $property{'fo:font-style'} // 'normal' ) ne 'normal';
		push @kinds, 'underline' if ( $property{'style:text-underline-style'} // 'none' ) ne 'none';
		push @kinds, 'strike' if ( $property{'style:text-line-through-style'} // 'none' ) ne 'none';
		return @kinds;
	}

	# A paragraph is a title when its style is "Title" or inherits from it.
	method is_title ($name) {
		return ( grep { $_ eq 'Title' } $self->_lineage($name) ) ? 1 : 0;
	}

	# The marker of the item at $position (from 1) in a list of the style
	# at $level (from 1): a bullet, or the number with the prefix and the
	# suffix of the style ("1."). Lists without a style get bullets.
	method marker_of ( $list_style, $level, $position ) {
		my $format = defined $list_style ? $levels_of_list{$list_style}{$level} : undef;
		return BULLET unless $format;
		return $format->{numbered} ? "$format->{prefix}$position$format->{suffix}" : $format->{bullet};
	}
}

1;
