# NAME

Term::Fabulous::Widget::FocusableText - The focus role behind
Term::Fabulous::Widget::RichText

# DESCRIPTION

An abstract [Term::Fabulous::Widget::Text](Text.md) that composes
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable) and nothing else.
[Term::Fabulous::Widget::RichText](RichText.md) inherits from it instead of
composing the role directly, because an [Object::Pad](https://metacpan.org/pod/Object%3A%3APad) class cannot
override a method of a role it composes, while a subclass can override
an inherited method. This lets a RichText take the focus only while it
has links (["accepts\_focus" in Term::Fabulous::Widget::RichText](RichText.md#accepts_focus)).

Do not subclass this class; subclass [Term::Fabulous::Widget::RichText](RichText.md).

# SEE ALSO

[Term::Fabulous::Widget::RichText](RichText.md), [Term::Fabulous::Widget::TextNode](TextNode.md),
[Clay::UI::Role::Interaction::Focusable](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AFocusable).
