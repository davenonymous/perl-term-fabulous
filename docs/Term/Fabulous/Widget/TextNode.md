# NAME

Term::Fabulous::Widget::TextNode - The Clay::UI text role behind
Term::Fabulous::Widget::Text

# DESCRIPTION

An abstract class that composes [Clay::UI::Text](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AText) and nothing else.
[Term::Fabulous::Widget::Text](Text.md) inherits from it instead of composing
the role directly, because an [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) class cannot override a
method of a role it composes, while a subclass can override an
inherited method. This lets Term::Fabulous::Widget::Text accept every
[Term::Fabulous::Color](../Color.md) format in `text_color`.

Do not subclass this class; subclass [Term::Fabulous::Widget::Text](Text.md).

# SEE ALSO

[Term::Fabulous::Widget::Text](Text.md), [Clay::UI::Text](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AText).
