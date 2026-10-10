# NAME

Term::Fabulous::Theme::Document - A theme file you can read, check and
change, keeping its comments and layout

# SYNOPSIS

```perl
use Term::Fabulous::Theme::Document;

my $document = Term::Fabulous::Theme::Document->read_file('themes/ocean.kdl');

# Is it a theme Term::Fabulous can load?
foreach my $error ( $document->errors ) {
        printf "line %d: %s\n", $error->{line}, $error->{message};
}
my $theme = $document->theme;    # a Term::Fabulous::Theme, or undef

# What it sets, and what a key is worth when it sets nothing.
say $document->setting('palette.accent');                       # #5fd3c0
say $document->effective_setting('button.border.color.focused')->{spec};    # accent

# Changes return a new document; the old one stays as it was.
my $warmer = $document
        ->with_setting( 'palette.accent', '#ff9e64' )
        ->with_setting( 'button[primary].text', 'accent' )
        ->without_setting('divider.line.style');
$warmer->write_file('themes/ocean-warm.kdl');
```

# DESCRIPTION

A theme file (see ["THEME FILES" in Term::Fabulous::Theme](../Theme.md#theme-files)) is a KDL
document. This class reads one as text, checks it the way
[Term::Fabulous::Theme](../Theme.md) does, and tells for every mistake the line it
is on, which `Term::Fabulous::Theme->from_file` cannot. It also
changes settings in the text: a change rewrites only the lines that
hold the changed setting and adds new settings where they belong (a
slot in its family's block, a state in its state block), so comments,
blank lines, indentation, line ends and the order of everything else
stay as they were. A setting removed with ["without\_setting"](#without_setting) takes the
comment right above it along, and a block that becomes empty goes too.

[Term::Fabulous::ThemeEditor](../ThemeEditor.md) works on this class: its form changes
the text with ["with\_setting"](#with_setting), and its text mode shows the
["errors"](#errors) at their lines. Use it on its own to check theme files in a
test or to change them from a script.

A document never changes. ["with\_setting"](#with_setting), ["without\_setting"](#without_setting),
["with\_settings"](#with_settings) and ["without\_variant"](#without_variant) return a new document with
the new text; reading it again with ["parse"](#parse) gives the same document.

## Setting keys

A setting is named by a key:

```text
theme.name                          the name in the theme node
theme.extends                       the built-in theme it starts from
palette.TOKEN                       a palette token: palette.accent
FAMILY.SLOT                         a slot in the normal state: button.border.color
FAMILY.SLOT.STATE                   a slot in a state: button.border.color.focused
FAMILY[VARIANT].SLOT[.STATE]        a slot of a variant: button[primary].text
```

The families, slots, states and tokens are those of
["VOCABULARY" in Term::Fabulous::Theme](../Theme.md#vocabulary); an unknown name dies, naming the
known ones. `FAMILY.SLOT.normal` is the same key as `FAMILY.SLOT`.
A key names one setting, wherever it is in the file: `border
style=Round color="border"` in the `button` block holds the keys
`button.border.style` and `button.border.color`, and
`focused { text "accent" }` in it holds `button.text.focused`.

## Values

Values are strings as the file holds them: a token name (`accent`), a
color in a format [Term::Fabulous::Color](../Color.md) reads (`#5fd3c0`), a
border style name (`Round`), `none` (also for `#null` in the file),
`reverse`, or `true` or `false` for `border.enabled`, which the file
holds as `#true` or `#false` (`true` or `false` in a KDL 1 file).
["with\_setting"](#with_setting) checks a value as the theme does before it writes it,
so a document never gets a value its slot cannot take from this class.

# CONSTRUCTORS

## parse

```text
my $document = Term::Fabulous::Theme::Document->parse($kdl);
```

A document of a character string. It never dies for what the text
holds: mistakes become ["errors"](#errors). Dies only when the text is not a
string. An empty string is an empty theme (one that changes nothing in
the built-in `dark`).

## read\_file

```text
my $document = Term::Fabulous::Theme::Document->read_file($path);
```

A document of a file, read as UTF-8; a byte order mark at its start is
dropped. Dies when the file cannot be read or is not UTF-8 text.

# METHODS

## text

The text of the document, a character string.

## errors

```text
foreach my $error ( $document->errors ) {
        warn "theme.kdl line $error->{line}: $error->{message}\n";
}
```

Every mistake in the text, sorted by line, each a hash reference with
`line` (counted from 1) and `message`. A text that is not valid KDL
has a single error, at the line where the KDL parser stopped, with a
message that starts with `KDL syntax:`. Otherwise every mistake of
the theme is listed: an unknown node, token, family, slot or state, a
value its slot cannot take, a setting given twice. Empty for a valid
theme.

## is\_valid

1 when ["errors"](#errors) is empty, else 0.

## has\_syntax\_error

1 when the text is not valid KDL, else 0. Such a document cannot be
changed: the change methods die.

## theme

```text
my $theme = $document->theme;
```

The [Term::Fabulous::Theme](../Theme.md) the text describes, built by
["from\_string" in Term::Fabulous::Theme](../Theme.md#from_string) when first asked for, or `undef`
when the text has errors.

## name

The theme's name (`theme.name`), or `undef`.

## extends

The built-in theme it starts from: `theme.extends`, or `dark` when
the text does not say.

## kdl\_version

2, or 1 for a text that only KDL 1 reads. Changes to a KDL 1 text are
written in KDL 1.

## setting

```text
my $value = $document->setting('button.border.color.focused');
```

The value the text gives a key (see ["Values"](#values)), or `undef` when it
gives none. Dies for a key that is not one (see ["Setting keys"](#setting-keys)).

## setting\_keys

The keys the text sets, in the order they appear in it.

## variants

```text
foreach my $variant ( $document->variants ) {
        my ( $family, $name ) = @$variant;
}
```

The variants the text defines with at least one setting, as
`[ family, name ]` pairs in the order they appear in it.

## line\_of

```text
my $line = $document->line_of('palette.accent');
my $line = $document->line_of('button[primary]');
```

The line a key is set on, or the line of a variant's first block given
as `FAMILY[VARIANT]`; `undef` when the text does not set it.

## effective\_setting

```text
my $effective = $document->effective_setting('button.text.hovered');
# { spec => 'text', origin => 'normal' }
```

What a key is worth in the theme, as a hash reference with `spec`
(the value, see ["Values"](#values)) and `origin`, which says where it comes
from:

- `set`

    the text sets it;

- `dark` or `light`

    a palette token the text does not set: the base theme's color, as
    `#rrggbb` (or `#rrggbbaa` for a translucent one);

- `default`

    a slot the text does not set: the vocabulary's default
    (["slot\_info" in Term::Fabulous::Theme](../Theme.md#slot_info)), the same in both base themes;

- `normal`

    a state that looks like the slot's normal state, unless a theme sets
    it: `spec` is the normal state's value;

- `family`

    a slot of a variant that the variant does not set: the family's value.

`theme.name` without a name has the `spec` `undef`; `theme.extends`
without one is `dark` (`default`).

## with\_setting

```text
my $changed = $document->with_setting( 'button.border.color.focused', 'danger' );
```

A new document in which the key has the value. The value is checked as
the theme checks it and dies with the reason when the slot cannot take
it (`Term::Fabulous::Theme::Document: tabs.line.style cannot be
'none'`); `undef` dies, see ["without\_setting"](#without_setting). A key the text sets
gets the new value in its place; the line holding it is written anew,
the rest of the text stays. A value for `border.enabled` may also be `1` or
`0`; the file gets `#true` or `#false`. A new key is added: to the
family's first block (made at the end of the text when there is none),
in its state block or variant block (made as needed), next to a node
with the same head (`border color="accent"` gets `style=Round`
added); a token to
the palette block, the name and the base to the theme node. Dies when
the text is not valid KDL (["has\_syntax\_error"](#has_syntax_error)); other errors do not
stop changes.

## without\_setting

```text
my $changed = $document->without_setting('palette.accent');
```

A new document without the key's setting, so the key falls back to
what ["effective\_setting"](#effective_setting) then says. The node holding it goes (or the
property, when the node holds others), with the comment right above
it; a palette, family, state or variant block left without settings
goes too. A key the text does not set returns the document itself.

## with\_settings

```text
my $changed = $document->with_settings( [
        [ 'palette.accent',     '#ff9e64' ],
        [ 'button.text.hovered', undef ],      # removed
] );
```

Several changes in order, each as ["with\_setting"](#with_setting), or as
["without\_setting"](#without_setting) for `undef`.

## without\_variant

```text
my $changed = $document->without_variant( 'button', 'primary' );
```

A new document without the variant's blocks and everything in them; the
document itself when it has none. Dies for an unknown family.

## write\_file

```text
$document->write_file('themes/ocean.kdl');
```

Writes the text to a file as UTF-8 and returns the document. The text
goes to a temporary file in the same directory first, which is then
renamed over the target, so the target is never half written; an
existing target keeps its permissions. Dies when the file cannot be
written.

# FUNCTIONS

## parse\_key

```text
my $parsed = Term::Fabulous::Theme::Document::parse_key('button[primary].text.focused');
# { section => 'slot', family => 'button', variant => 'primary', slot => 'text', state => 'focused' }
```

A key taken apart: `section` is `theme` (with `field`), `palette`
(with `token`) or `slot` (with `family`, `variant` or `undef`,
`slot` and `state`). Dies for a key that is not one.

## key\_for

```text
my $key = Term::Fabulous::Theme::Document::key_for( family => 'button', slot => 'text', state => 'focused' );
```

The key of the parts ["parse\_key"](#parse_key) returns; a `normal` state is left
out.

# SEE ALSO

[Term::Fabulous::Theme](../Theme.md), [Term::Fabulous::ThemeEditor](../ThemeEditor.md),
["THEMES" in Term::Fabulous::Manual::Looks](../Manual/Looks.md#themes), [Text::KDL::XS](https://metacpan.org/pod/Text%3A%3AKDL%3A%3AXS).
