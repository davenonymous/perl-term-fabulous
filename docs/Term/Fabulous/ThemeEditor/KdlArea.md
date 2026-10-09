# NAME

Term::Fabulous::ThemeEditor::KdlArea - The text area of the theme
editor's text mode

# DESCRIPTION

Part of [Term::Fabulous::ThemeEditor](../ThemeEditor.md); not meant to be used on its
own. A [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md) for editing a theme file,
which keeps `Tab` and `Shift+Tab` (see
["Keys Term::Fabulous handles itself" in Term::Fabulous::Manual::Events](../Manual/Events.md#keys-term-fabulous-handles-itself))
and adds these keys to those of the text area:

- `Tab`, `Shift+Tab`

    Indent or outdent the selected lines, or the cursor's line; `Tab`
    without a selection inserts one level of indentation at the cursor.

- `Enter`

    Starts a new line with the indentation of the cursor's line, one level
    more after an opening brace.

- `}`

    Typed into the indentation of a line, takes the line back one level.

- `Ctrl+C`

    Copies the selection (`Ctrl+Insert` does too).

- `Alt+Backspace`

    Deletes the word before the cursor. `Ctrl+W`, which does that in a
    text area, closes the tab in the editor.

One level of indentation is the first indentation found in the text, or
a tab. A tab is shown as a blank two columns wide.

# METHODS

## captures\_tab

Returns 1 (0 while the area is read-only): Term::Fabulous leaves `Tab`
and `Shift+Tab` to the area.

## indent\_unit

The indentation of one level.

## display\_cluster

Shows a tab as an ideographic space (U+3000), a blank two columns wide;
the text keeps the tab.

## handle\_key

The keys above, then those of [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md).

# SEE ALSO

[Term::Fabulous::ThemeEditor](../ThemeEditor.md), [Term::Fabulous::Widget::TextArea](../Widget/TextArea.md).
