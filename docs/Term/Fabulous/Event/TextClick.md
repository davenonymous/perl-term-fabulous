# NAME

Term::Fabulous::Event::TextClick - A mouse button pressed on a character
of a text

# SYNOPSIS

```perl
use Term::Fabulous::Termbox qw(TB_KEY_MOUSE_RIGHT);

$panel->on( TextClick => sub ($event) {
        my $word = $event->word // return;    # undef on a blank
        show_definition($word) if $event->button == TB_KEY_MOUSE_RIGHT;
        return;
} );
```

# DESCRIPTION

[Term::Fabulous](../../../../README.md) fires `TextClick` on a [Term::Fabulous::Widget::Text](../Widget/Text.md)
(a [Term::Fabulous::Widget::RichText](../Widget/RichText.md) too) when a mouse button is
pressed on one of its characters: the topmost thing painted in the
cell under the pointer in the last frame is a line of the text, and
the cell holds a character (not the empty rest of the line). Drags,
releases and the wheel fire none.

It comes after the `Mouse` event of the same press, which goes to the
widget around the text as always (see
["MOUSE" in Term::Fabulous::Manual::Events](../Manual/Events.md#mouse)), and it bubbles from the text
to its ancestors, so a container can listen for clicks on any text
inside it: `$event->target` is the text widget. A left press on a
link of a RichText fires [LinkActivate](LinkActivate.md)
after it.

The event is a [Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) whose name is `TextClick`.

# CONSTRUCTOR

## new

```perl
my $event = Term::Fabulous::Event::TextClick->new(
        button => TB_KEY_MOUSE_LEFT,
        x      => 12,
        y      => 3,
        offset => 4,
);
```

The text widget builds these events (see
["click\_at" in Term::Fabulous::Widget::Text](../Widget/Text.md#click_at)); build one yourself only to
test your listeners. Unknown parameters die, as do the values named
below. The `name` and `bubble_mode` parameters of
[Clay::UI::Events::Event](https://metacpan.org/pod/Clay%3A%3AUI%3A%3AEvents%3A%3AEvent) are accepted.

- `button`

    Required. `TB_KEY_MOUSE_LEFT`, `TB_KEY_MOUSE_MIDDLE` or
    `TB_KEY_MOUSE_RIGHT`.

- `x`, `y`

    Required. The cell of the pointer, counted from 0 at the top left
    corner of the terminal.

- `offset`

    Required. Where the clicked character is in the widget's text, in
    characters from 0. For a character made of several code points (a
    letter with a combining accent) it is the offset of the first one.

- `word`, `word_start`, `word_end`

    The word the character belongs to, the run of non-blank characters
    around it, with its offset and the offset after its last character.
    Given together or not at all; `undef` when the clicked character is
    blank.

- `spans`

    The spans of a RichText that cover the character, as
    ["spans" in Term::Fabulous::Widget::RichText](../Widget/RichText.md#spans) gives them. Default: `[]`.

- `link`, `link_index`

    The target of the RichText's link the character lies in, and the
    link's index among the widget's links (see
    ["links" in Term::Fabulous::Widget::RichText](../Widget/RichText.md#links)). Given together or not at
    all; default `undef`.

# METHODS

## button

```perl
my $button = $event->button;
```

The button that was pressed: `TB_KEY_MOUSE_LEFT`,
`TB_KEY_MOUSE_MIDDLE` or `TB_KEY_MOUSE_RIGHT`.

## x

```perl
my $column = $event->x;
```

The column of the pointer.

## y

```perl
my $row = $event->y;
```

The row of the pointer.

## offset

```perl
my $offset = $event->offset;
```

The offset of the clicked character in the text.

## word

```perl
my $word = $event->word;    # or undef
```

The word under the pointer: the run of non-blank characters the
clicked character belongs to, with any punctuation in it (`"Foo::Bar,"`).
`undef` on a blank.

## word\_start

```perl
my $start = $event->word_start;    # or undef
```

The offset of the word's first character.

## word\_end

```perl
my $end = $event->word_end;    # or undef
```

The offset after the word's last character.

## spans

```perl
foreach my $span ( @{ $event->spans } ) {
        my ( $start, $end, $style ) = @$span;
        ...
}
```

The spans of a RichText that cover the clicked character, in the order
they apply: `[ $start, $end, $style ]` with the normalized style hash.
Empty for a plain Text. The result is a copy.

## link

```perl
my $target = $event->link;    # or undef
```

The target of the link under the pointer: whatever the program gave
the link (a string from markup). `undef` when the character lies in no
link.

## link\_index

```perl
my $index = $event->link_index;    # or undef
```

The index of that link among the widget's links, or `undef`.

# SEE ALSO

["click\_at" in Term::Fabulous::Widget::Text](../Widget/Text.md#click_at),
[Term::Fabulous::Event::LinkActivate](LinkActivate.md), [Term::Fabulous::Event::Mouse](Mouse.md),
[Term::Fabulous::Manual::Events](../Manual/Events.md).
