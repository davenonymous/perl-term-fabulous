# NAME

Term::Fabulous::Event::TabClose - The user asked to close a document tab

# SYNOPSIS

```perl
$tabs->on( TabClose => sub ($event) {
        my $document = $documents[ $event->index ];
        return ask_save_first($document) if $document->is_modified;
        splice @documents, $event->index, 1;
        return;
} );
```

# DESCRIPTION

A [Term::Fabulous::Widget::DocumentTabs](../Widget/DocumentTabs.md) fires `TabClose` on itself
when the user asks to close one of its tabs: with a click on the
tab's close mark, or with a middle click anywhere on the tab. A tab
whose `closable` is 0 has no close mark and fires nothing.

The tabs do not remove the tab themselves. The program decides: it
may close the document at once, ask whether to save it first, or keep
it open. To close it, it removes the tab from the list it gave the
tabs (or from what its code reference returns) and sets
`active` to the tab that should be shown now.

It is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `TabClose`. It
bubbles to the widget's ancestors like every event (see
["Return values and bubbling" in Term::Fabulous::Manual::Events](../Manual/Events.md#return-values-and-bubbling)), and
`$event->target` is the DocumentTabs.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::TabClose->new( item => $tab, index => 2 );
```

The widget builds these events itself; build one yourself only to test
your listeners. Both parameters are required, and unknown parameters
die, and so do an `item` that is not a hash reference and an
`index` that is not a non-negative integer. The `name` and
`bubble_mode` parameters of [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

# METHODS

## item

The tab, a hash reference as the DocumentTabs shows it (see
["tabs" in Term::Fabulous::Widget::DocumentTabs](../Widget/DocumentTabs.md#tabs)).

## index

Its position among the tabs, from 0.

# SEE ALSO

[Term::Fabulous::Widget::DocumentTabs](../Widget/DocumentTabs.md), [Term::Fabulous::Event::TabAdd](TabAdd.md),
[Term::Fabulous::Event::Select](Select.md), [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent).
