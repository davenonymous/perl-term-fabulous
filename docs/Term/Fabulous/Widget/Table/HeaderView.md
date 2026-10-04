# NAME

Term::Fabulous::Widget::Table::HeaderView - The header of a table, scrolled sideways with its body

# DESCRIPTION

The box around the header grid of a [Term::Fabulous::Widget::Table](../Table.md).
The body of a table scrolls up and down below the header, which stays;
sideways, the header has to move with the body. This box clips its
content to its own width and shifts it by the horizontal scroll position
of the scroll container it `follows`, in the same frame. It is not a
scroll container itself, so the mouse wheel does not move it on its own.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md).
