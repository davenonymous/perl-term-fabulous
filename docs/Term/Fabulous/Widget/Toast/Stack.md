# NAME

Term::Fabulous::Widget::Toast::Stack - The column of toasts in one
corner of the screen

# SYNOPSIS

```perl
# Created by Term::Fabulous::Widget::Toast->show; not used directly.
my @corners = Term::Fabulous::Widget::Toast::Stack->positions;
```

# DESCRIPTION

Used internally by [Term::Fabulous::Widget::Toast](../Toast.md). When a toast is
shown, it is added to the stack of its `position`: a
[Term::Fabulous::Widget::Box](../Box.md) floating over the root widget, attached
to that corner (or edge center) of the screen, that lists its toasts
top to bottom with a row between them, newest last. The stack is
created when the first toast of a position is shown and removed when
its last toast hides. A stack neither takes the focus nor paints
anything of its own.

# CONSTRUCTOR

## new

```perl
my $stack = Term::Fabulous::Widget::Toast::Stack->new( position => 'top_right', z_index => 2000, margin => 1 );
```

All three parameters are required: the `position` (one of
["positions"](#positions)), the `z_index` of the floating box and the `margin`,
the cells between the stack and the edges of the screen.

# METHODS

## position

The stack's position.

## positions

```perl
my @names = Term::Fabulous::Widget::Toast::Stack->positions;
```

A class method: `bottom_center`, `bottom_left`, `bottom_right`,
`top_center`, `top_left` and `top_right`.

# SEE ALSO

[Term::Fabulous::Widget::Toast](../Toast.md).
