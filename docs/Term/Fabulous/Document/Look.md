# NAME

Term::Fabulous::Document::Look - Styles for each kind of document text, taken from a theme

# SYNOPSIS

```perl
use Term::Fabulous::Document::Look;

# The look of the theme a widget draws with:
my $look = Term::Fabulous::Document::Look->of($widget);
$rich_text->stylize( $look->style('code'), 4, 12 );

# The look of a particular theme:
my $light = Term::Fabulous::Document::Look->new( theme => Term::Fabulous::Theme->builtin('light') );

# A look with a kind of its own and a different style for code:
class My::Look :isa(Term::Fabulous::Document::Look) {
        method recipes :common () {
                return (
                        $class->SUPER::recipes,
                        title => { words => 'bold', color => 'accent' },
                        code  => { color => 'success', background => 'surface_low' },
                );
        }
}
```

# DESCRIPTION

A parser records what a range of text _is_, such as bold text, code or
a heading, as a _mark_ of a certain _kind_ (see
["FACTORIES" in Term::Fabulous::Document](../Document.md#factories)). A look decides how each kind is
_shown_. For every kind it holds a style in the sense of
[Term::Fabulous::Text::Style](../Text/Style.md): the style bits to set and clear, a text
color and a background. A [Term::Fabulous::Widget::Text](../Widget/Text.md) span
takes such a style unchanged.

Links are not a kind of the look. A Text draws its links itself, in
the link looks of the theme (see
["Looks" in Term::Fabulous::Widget::Text](../Widget/Text.md#looks)).

A look takes every color from the palette of a [Term::Fabulous::Theme](../Theme.md)
(see ["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens)), never from fixed values. A
document view therefore follows the theme the program runs with,
whether it is built in or read from a theme file, and switching the
theme restyles the text.

## Recipes

The styles are defined by _recipes_, one per kind. A recipe is a hash
reference with up to three keys, all optional:

- `words`

    A style string of ["Style strings" in Term::Fabulous::Text::Style](../Text/Style.md#style-strings), usually
    one or more style words such as `'bold'` or `'bold italic'`. Without
    it, the kind sets and clears no style bits.

- `color`

    The name of a palette token for the text color, such as `'accent'`.
    Without it, the style leaves the text color alone.

- `background`

    The name of a palette token for the background, such as
    `'surface_low'`. Without it, the style leaves the background alone.

The style string could name colors of its own, but these would not
change with the theme; use the token keys instead. A color from a token
key replaces any text color or background the style string names.

When a look is created, it turns every recipe into a style: it parses
`words` and looks up both tokens in its theme with
["token" in Term::Fabulous::Theme](../Theme.md#token).

# KINDS

The base class defines these kinds. In the middle column, `bold`,
`italic` and `strike` are style words and every other name is a
palette token. A token on its own or after a comma is the text color;
`X on Y` means text color X on background Y, and `on Y` alone sets
only the background.

| Kind            | Shown as                  | Used for                        |
| --------------- | ------------------------- | ------------------------------- |
| `bold`          | bold                      | bold text                       |
| `italic`        | italic                    | italic text                     |
| `strike`        | strike                    | struck-through text             |
| `code`          | warning                   | code in a paragraph             |
| `file`          | italic, success           | a file name                     |
| `match`         | on selection              | a search match                  |
| `match_current` | text_inverse on warning   | the current search match        |
| heading1        | bold, accent              | a first-level heading           |
| heading2        | bold, text_bright         | a second-level heading          |
| heading3        | bold, text                | a third-level heading           |
| heading4        | bold italic, text         | a fourth-level heading          |
| heading5        | italic, text_bright       | a fifth-level heading           |
| heading6        | italic, text_muted        | a sixth-level heading           |
| `term`          | bold, text_bright         | the term of a definition list   |
| `marker`        | accent                    | bullets and numbers of items    |
| `quote`         | text_muted                | the bar beside a block quote    |
| `code_block`    | text on surface_low       | verbatim blocks                 |
| `clipped`       | text_muted on surface_low | the marks of clipped code lines |

## Changing and adding kinds

To restyle documents or to support mark kinds of a new format, write a
subclass that overrides ["recipes"](#recipes). It returns the recipes of its
parent followed by its own; a recipe with the name of an existing kind
replaces that kind's recipe. Keep all kinds of the base class: the
document view and [Term::Fabulous::Widget::CodeBlock](../Widget/CodeBlock.md) ask for several
of them by name, and ["style"](#style) dies for a kind the look does not have.

A document names the look class its factories style marks with:

```perl
my $document = Term::Fabulous::Document->new( look => 'My::Look' );
```

The view accepts only documents whose marks are links or have a kind
that the look class lists in ["kinds"](#kinds), and its code blocks paint with
the same class. [Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md)
has a worked example that changes the styles of a document and adds
mark kinds this way.

# CONSTRUCTORS

## new

```perl
my $look = Term::Fabulous::Document::Look->new( theme => $theme );
```

Creates the look of a [Term::Fabulous::Theme](../Theme.md), with a style for every
kind of ["recipes"](#recipes). The `theme` parameter is required. The
constructor dies when `theme` is not a Term::Fabulous::Theme, when it
gets an unknown parameter, and when a recipe names a palette token the
theme does not know or contains a style string that does not parse.

## of

```perl
my $look = Term::Fabulous::Document::Look->of($widget);
```

Returns the look of the theme a widget draws with. That is the theme of
the [Term::Fabulous](../../../../README.md) UI the widget is part of, or the default theme
(["default" in Term::Fabulous::Theme](../Theme.md#default)) while it is part of none, the same
rule [Term::Fabulous::Role::Themed](../Role/Themed.md) applies. Call `of` on the look
class you want; the look is an instance of that class.

Each look class caches the look it made last and returns it again as
long as the theme is the same object and no theme has been switched
anywhere in the process since (see
["generation, bump\_generation" in Term::Fabulous::Theme](../Theme.md#generation-bump_generation)). Calling `of`
in every frame is therefore cheap. There is one cached look per look
class, so views that use the same look class but draw with different
themes make a new look whenever the theme differs from the previous
call.

# CLASS METHODS

## recipes

```perl
my %recipe = Term::Fabulous::Document::Look->recipes;
```

Returns the recipes of all kinds as a list of pairs, in the form
`kind => { words => 'bold italic', color => TOKEN, background => TOKEN }`
(see ["Recipes"](#recipes)). A subclass overrides this method to change or add
kinds, as described in ["Changing and adding kinds"](#changing-and-adding-kinds).

## kinds

```perl
my @kinds = Term::Fabulous::Document::Look->kinds;    # bold, clipped, code, ...
```

Returns the names of all kinds of the class, sorted. The document view
checks the mark kinds of every document it is given against this list
and dies for a kind that is missing.

## token\_style

```perl
my $style = Term::Fabulous::Document::Look->token_style('code');    # { set => 0, clear => 0, color => 'warning', background => undef }
```

Class method. The style of a kind as a style hash whose colors are
still the palette tokens of its recipe, not colors: what the factories
of [Term::Fabulous::Document](../Document.md) give their texts, which look the tokens
up in their own theme when they paint (see
["Palette tokens" in Term::Fabulous::Text::Style](../Text/Style.md#palette-tokens)). A new hash on every
call. An unknown or undefined kind dies with the known kinds.

# METHODS

## theme

```perl
my $theme = $look->theme;
```

Returns the [Term::Fabulous::Theme](../Theme.md) the styles were made from.

## style

```perl
my $style = $look->style('code');    # { set => 0, clear => 0, color => [...], background => undef }
```

Returns the style of a kind as a style hash (see
["Style hashes" in Term::Fabulous::Text::Style](../Text/Style.md#style-hashes)). The hash and its color
arrays are new copies on every call, so the caller may change them
without affecting the look. An unknown or undefined kind dies with a
message that lists the known kinds.

# SEE ALSO

[Term::Fabulous::Cookbook::Documents](../Cookbook/Documents.md), [Term::Fabulous::Text::Style](../Text/Style.md),
[Term::Fabulous::Theme](../Theme.md), ["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes),
[Term::Fabulous::Document](../Document.md), [Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md).
