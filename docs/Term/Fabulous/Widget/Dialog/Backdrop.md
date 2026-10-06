# NAME

Term::Fabulous::Widget::Dialog::Backdrop - The screen-filling layer
behind an open dialog

# DESCRIPTION

This class is internal to [Term::Fabulous::Widget::Dialog](../Dialog.md). When a
dialog opens, it creates one Backdrop, puts itself inside it and adds
the Backdrop to the root widget. The Backdrop

- floats over the whole screen (attached to the root, grown to its size,
with the dialog's `z_index`), painted in the dialog's
`backdrop_color` with the glyphs below showing through, and centers
the dialog in itself;
- catches every mouse event outside the dialog, whatever its color,
since it covers every cell of the screen: the `Mouse` and `MouseMove`
events are fired on the Backdrop and bubble to the root widget, its
parent, not to the widgets behind it. Clay treats it as a floating
element that captures the pointer, so nothing below it is hovered or
pressed;
- can take the keyboard focus, so a click outside the dialog focuses the
Backdrop instead of a widget behind it;
- decides the Tab order while the focus is inside the dialog
([Clay::UI::Role::Interaction::HasFocusOrder](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AHasFocusOrder)): Tab and Shift+Tab
cycle through the focusable widgets inside the dialog, and through the
Backdrop alone when there are none;
- stops every key that the widgets inside the dialog let bubble, so the
widgets and key bindings behind the dialog see none; it closes the
dialog on `Escape`, when the dialog's `close_on_escape` is set;
- takes the focus itself when the focused widget inside the dialog loses
it without another widget getting it (it is disabled or removed, or
the program focuses nothing), so keys and Tab stay inside the dialog.
It learns about that from the `OnBlur` event bubbling up from the
widget, so an `OnBlur` listener inside the dialog must let it bubble
(return `Clay::UI::Enum::Result->CONTINUE`).

# METHODS

## dialog

The [Term::Fabulous::Widget::Dialog](../Dialog.md) this Backdrop belongs to.

## get\_next\_focus, get\_previous\_focus

The [Clay::UI::Role::Interaction::HasFocusOrder](https://metacpan.org/pod/Clay%3A%3AUI%3A%3ARole%3A%3AInteraction%3A%3AHasFocusOrder) methods: the widget
after or before the focused one among the widgets inside the dialog
that can take the focus now, in tree order (also those a widget keeps
below an internal child, such as the items of a
[Term::Fabulous::Widget::VirtualList](../VirtualList.md)), wrapping around. They are the
tracker's default order limited to the dialog
(`default_next_focus( within => $dialog )`, see
["default\_next\_focus" in Clay::UI::Interaction](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AInteraction#default_next_focus)). From the Backdrop itself,
Tab goes to the first widget and Shift+Tab to the last; with no
focusable widget inside, both return the Backdrop.

# SEE ALSO

[Term::Fabulous::Widget::Dialog](../Dialog.md).
