# NAME

Term::Fabulous::Widget::Table::EdgeView - The header and the footer of a table, scrolled sideways with its body

# DESCRIPTION

The box around the header grid and the one around the footer grid of a
[Term::Fabulous::Widget::Table](../Table.md). The body of a table scrolls up and
down between its header and its footer, which stay; sideways, both
have to move with the body. This box clips its content to its own
width and shifts it by the horizontal scroll position of the scroll
container it `follows`, in the same frame, while that container
scrolls sideways; otherwise it does not clip its content either, so
that Clay narrows the columns of the header and the footer along with
the body's. It is not a scroll container itself, so the mouse wheel
does not move it on its own.

# SEE ALSO

[Term::Fabulous::Widget::Table](../Table.md).
