# NAME

Term::Fabulous::Widget::Element - The Clay::UI roles behind
Term::Fabulous::Widget

# DESCRIPTION

An abstract class that composes the [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI) roles every container
widget needs: `Clay::UI::Role::Core::Container`, the event roles, the
layout roles and the background and border styles. It has no methods of
its own.

[Term::Fabulous::Widget](../Widget.md) inherits from it instead of composing the
roles directly, because an [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) class cannot override a
method of a role it composes, while a subclass can override an
inherited method. This lets Term::Fabulous::Widget accept every
[Term::Fabulous::Color](../Color.md) format in `background_color` and
`border_color`.

Do not subclass this class; subclass [Term::Fabulous::Widget](../Widget.md) or one
of its subclasses.

# SEE ALSO

[Term::Fabulous::Widget](../Widget.md), [Clay::UI](https://metacpan.org/pod/Clay%3A%3AUI).
