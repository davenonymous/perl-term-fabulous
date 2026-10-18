# NAME

Term::Fabulous::Role::SearchContainer - A widget that answers a search
for the searchable widgets inside it

# SYNOPSIS

```perl
use Object::Pad 0.825;
use Term::Fabulous::Role::SearchContainer;
use Term::Fabulous::Widget::Box;

class My::Drawer
        :isa(Term::Fabulous::Widget::Box)
        :does(Term::Fabulous::Role::SearchContainer)
{
        use Term::Fabulous::Role::Searchable qw(searchables_in);

        field $content = Term::Fabulous::Widget::Box->new;

        method searchable_parts () { return searchables_in($content) }
        method reveal_part ($part) { $self->add_child($content) unless $self->has_child($content); return }
}
```

# DESCRIPTION

A container such as a [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md) or a
[Term::Fabulous::Widget::Accordion::Item](../Widget/Accordion/Item.md) holds widgets that can be
searched, and some of them may be out of the tree right now (an inactive
page, a closed body). Composing this role makes the container
[searchable](Searchable.md) for all of them: it lists
its _parts_, and the role provides every method of
[Term::Fabulous::Role::Searchable](Searchable.md), with keys of two parts, the index
of a part and that part's own key (see
["nested\_search\_texts" in Term::Fabulous::Role::Searchable](Searchable.md#nested_search_texts)).

The revision of a key names the part at the index as well, so a key
that leads to another part after the parts changed reads as changed
(see ["nested\_search\_revision" in Term::Fabulous::Role::Searchable](Searchable.md#nested_search_revision)).

# REQUIRED METHODS

## searchable\_parts

```perl
method searchable_parts () { return map { searchables_in($_) } @pages }
```

The searchable widgets the container answers for, in the order their
texts appear, also those that are not in the tree now. Called for every
search request, so it lists the parts as they are at that moment.

# OPTIONAL METHODS

## reveal\_part

```perl
method reveal_part ($part) { $self->open(1); return }
```

Called by ["reveal\_text"](#reveal_text) with the part that holds the text, before the
part reveals the text itself: the container makes the part visible (a
Tabs activates the page that holds it, an accordion item opens). A
container without the method shows its parts all the time.

# PROVIDED METHODS

## search\_texts, search\_revision, highlight\_text, clear\_text\_highlights

The methods of [Term::Fabulous::Role::Searchable](Searchable.md), answered for the
parts with keys `[ $index, $key ]`. A key whose index is past the parts
gives the revision `'gone'` and highlights nothing.

## reveal\_text

```perl
my ( $shown, $row ) = @{ $container->reveal_text( $key, $offset ) };
```

Calls ["reveal\_part"](#reveal_part) with the part the key names (when the container
has the method), then the part's own `reveal_text`, and returns what
the part returns. A key whose index is past the parts reveals nothing
and returns `[ undef, undef ]`.

# SEE ALSO

[Term::Fabulous::Role::Searchable](Searchable.md), [Term::Fabulous::Widget::Tabs](../Widget/Tabs.md),
[Term::Fabulous::Widget::Accordion::Item](../Widget/Accordion/Item.md),
[Term::Fabulous::Manual::CustomWidgets](../Manual/CustomWidgets.md).
