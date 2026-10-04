# NAME

Term::Fabulous::Widget::Tabs::Line - The line that joins the tabs of a
bar with the page

# SYNOPSIS

```perl
# Created by Term::Fabulous::Widget::Tabs::Bar; not used directly.
```

# DESCRIPTION

Used internally by [Term::Fabulous::Widget::Tabs::Bar](Bar.md). The line is
the bar's edge toward the page: one cell thick and as long as the bar,
drawn in the bar's `line_style` and `line_color`. Where the sides of
a tab meet it, it shows the joints of the style: a T under a closed
tab, whose bottom it is, and corners at the active tab, whose opening
it leaves free so that the tab and the page are one shape. With the
bar's `page_border`, its ends are the corners of the page's border.

The line reads where the tabs lie from the layout of the frame being
drawn (["bounding\_box, scroll\_state, scroll\_to" in Term::Fabulous](../../../../../README.md#bounding_box-scroll_state-scroll_to)), so it
follows them whatever sizes and alignment the bar gives them. It is a
[Term::Fabulous::Widget::Display](../Display.md) and paints again when a tab moved,
became active, got or lost the focus, or the bar changed its look.

# SEE ALSO

[Term::Fabulous::Widget::Tabs::Bar](Bar.md),
["junction" in Term::Fabulous::Enum::BorderStyle](../../Enum/BorderStyle.md#junction).
