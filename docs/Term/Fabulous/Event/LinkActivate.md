# NAME

Term::Fabulous::Event::LinkActivate - The user followed a link of a
RichText

# SYNOPSIS

```perl
$help->on( LinkActivate => sub ($event) {
        open_page( $event->link );    # the link's target
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::RichText](../Widget/RichText.md) fires `LinkActivate` on itself
when the user follows one of its links, whichever way: a left click on
the link, or `Enter` while the RichText has the focus and a link is
selected. `$rich_text->activate_link` fires it from code. The
widget does not go anywhere itself: what a link means is the program's
business, and `link` is the target the program gave it.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `LinkActivate`, and it
bubbles from the RichText to its ancestors, so a container can follow
the links of every text inside it. `$event->target` is the
RichText (`target` is the widget, as for every event; the link's
target is `link`).

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::LinkActivate->new(
        link  => 'https://perl.org',
        index => 0,
        start => 4,
        end   => 12,
);
```

The RichText builds these events itself; build one yourself to test
your listeners, or to fire it from a widget of your own that shows
links some other way. All four parameters are required; `link` may be
anything but `undef`, the others are non-negative integers with
`start <= end`. Unknown parameters die. The `name` and
`bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# METHODS

## link

```perl
my $target = $event->link;
```

The target of the link: a string from markup, or whatever the program
gave [add\_link](../Widget/RichText.md#add_link).

## index

```perl
my $index = $event->index;
```

The index of the link among the RichText's links.

## start

```perl
my $start = $event->start;
```

The offset of the link's first character in the text.

## end

```perl
my $end = $event->end;
```

The offset after the link's last character.

# SEE ALSO

["LINKS" in Term::Fabulous::Widget::RichText](../Widget/RichText.md#links),
[Term::Fabulous::Event::TextClick](TextClick.md),
[Term::Fabulous::Manual::Events](../Manual/Events.md).
