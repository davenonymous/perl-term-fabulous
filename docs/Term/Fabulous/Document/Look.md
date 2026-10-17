# NAME

Term::Fabulous::Document::Look - The styles of a document's text in a theme

# SYNOPSIS

```perl
use Term::Fabulous::Document::Look;

my $look = Term::Fabulous::Document::Look->of($widget);    # the theme the widget draws with
$rich_text->stylize( $look->style('code'), 4, 12 );

my $light = Term::Fabulous::Document::Look->new( theme => Term::Fabulous::Theme->builtin('light') );

# A look with kinds of its own:
class My::Look :isa(Term::Fabulous::Document::Look) {
        method recipes :common () {
                return ( $class->SUPER::recipes, title => { words => 'bold', color => 'accent' } );
        }
}
```

# DESCRIPTION

A parser marks what a range of text _is_: bold, code, a link (see
[Term::Fabulous::Document::Mark](Mark.md)). A look says how each of these kinds
is _shown_: as a style of [Term::Fabulous::Text::Style](../Text/Style.md), the style
bits to set and clear, a text color and a background, which a
[Term::Fabulous::Widget::RichText](../Widget/RichText.md) span takes as it is. Links are not
a kind of the look: a RichText paints its links itself, in the link
looks of the theme (see ["Looks" in Term::Fabulous::Widget::RichText](../Widget/RichText.md#looks)).

Every color comes from the palette of a [Term::Fabulous::Theme](../Theme.md)
(["Tokens" in Term::Fabulous::Theme](../Theme.md#tokens)), so a document view follows the theme
the program runs with, built in or from a theme file, and a theme
switch restyles the text.

# KINDS

| Kind            | Shown as                  | Used for                        |
| --------------- | ------------------------- | ------------------------------- |
| `bold`          | bold                      | bold text                       |
| `italic`        | italic                    | italic text                     |
| `strike`        | strike                    | struck-through text             |
| `code`          | warning                   | code in a paragraph             |
| `file`          | italic, success           | a file name                     |
| `match`         | on selection              | a search match                  |
| `match_current` | text_inverse on warning   | the match the view is at        |
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

The names in the middle column are palette tokens.

A subclass adds kinds, or changes these, by overriding ["recipes"](#recipes); a
[Term::Fabulous::Widget::DocumentView](../Widget/DocumentView.md) subclass names its look class
with [look\_class](../Widget/DocumentView.md#look_class).

# CONSTRUCTORS

## new

```perl
my $look = Term::Fabulous::Document::Look->new( theme => $theme );
```

The look of a [Term::Fabulous::Theme](../Theme.md). Unknown parameters die, and so
does anything but a theme.

## of

```perl
my $look = Term::Fabulous::Document::Look->of($widget);
```

The look of the theme a widget draws with: the theme of the
[Term::Fabulous](../../../../README.md) it is part of, or the default theme while it is part
of none (the rule of [Term::Fabulous::Role::Themed](../Role/Themed.md)). The look made
last by the class is kept and returned again until the theme is another
one or a theme was switched anywhere
(["generation, bump\_generation" in Term::Fabulous::Theme](../Theme.md#generation-bump_generation)), so asking
for it in every frame costs a comparison.

# CLASS METHODS

## recipes

```perl
my %recipe = Term::Fabulous::Document::Look->recipes;
```

The kinds as `kind => { words => 'bold italic', color => TOKEN, background => TOKEN }`:
the style words of ["Style strings" in Term::Fabulous::Text::Style](../Text/Style.md#style-strings) the
kind sets, and the palette tokens of its text color and its background,
each optional. A subclass returns its parent's recipes plus its own.

## kinds

```perl
my @kinds = Term::Fabulous::Document::Look->kinds;    # bold, clipped, code, ...
```

The names of the kinds, sorted. A widget that takes kinds from a program
checks them against it.

# METHODS

## theme

```perl
my $theme = $look->theme;
```

The theme the styles come from.

## style

```perl
my $style = $look->style('code');    # { set => ..., clear => ..., color => [...], background => undef }
```

The style of a kind, as a new style hash (see
["Style hashes" in Term::Fabulous::Text::Style](../Text/Style.md#style-hashes)). An unknown kind dies
with the list of known ones.

# SEE ALSO

[Term::Fabulous::Text::Style](../Text/Style.md), [Term::Fabulous::Theme](../Theme.md),
["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes), [Term::Fabulous::Document::Mark](Mark.md).
