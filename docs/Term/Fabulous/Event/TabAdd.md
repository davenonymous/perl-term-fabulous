# NAME

Term::Fabulous::Event::TabAdd - The user asked for a new document tab

# SYNOPSIS

```perl
$tabs->on( TabAdd => sub ($event) {
        push @documents, new_document();
        $tabs->active($#documents);
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::DocumentTabs](../Widget/DocumentTabs.md) fires `TabAdd` on itself
when the user clicks the `+` button at the end of its tabs. The tabs
add nothing themselves: the program makes the new document, adds its
tab to the list it gave the tabs (or to what its code reference
returns) and usually makes it the active one.

The event has no fields of its own; `$event->target` is the
DocumentTabs. It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is
`TabAdd`, and it bubbles to the widget's ancestors like every event.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::TabAdd->new;
```

Unknown parameters die. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# SEE ALSO

[Term::Fabulous::Widget::DocumentTabs](../Widget/DocumentTabs.md), [Term::Fabulous::Event::TabClose](TabClose.md),
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).
