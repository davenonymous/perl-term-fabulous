# Documentation tools

Maintainer tools that keep the documentation in step with the code.
They are shipped with the distribution but not installed.

## The workflow

```sh
perl Makefile.PL && make
make docs          # after changing an example program or a scenario
make docs-check    # fails when anything is out of date; part of `make release`
```

`make docs` runs `tools/update-docs`, which

1. copies every program shown in the POD into its code block: a code
   block marked with `=for code-from FILE` is replaced by the file
   (without its `#!` line), so the POD always shows the shipped code;
2. checks that every screenshot the POD shows
   (`<img src="/screenshots/NAME.svg">` in a `=begin html` block) is
   defined in `screenshots/screenshots.kdl`, and that every defined
   screenshot is shown somewhere;
3. takes every screenshot again and writes `screenshots/NAME.svg` when it
   changed;

and then regenerates `README.md` (`make readme`).

`make docs-check` does the same without writing anything and lists what
is out of date.

## How a screenshot is taken

`screenshots/screenshots.kdl` describes each screenshot: the program,
the terminal size and the input (keys, text, mouse) to give it first.
The syntax is documented in `tools/lib/Term/Fabulous/Screenshot/Scenario.pm`.

The program runs as its own process in a new pseudo terminal, with
`Term::Fabulous::Screenshot::Harness` loaded first. Nothing in the
program changes: Term::Fabulous opens the pseudo terminal with
termbox2 as it would a real one. The harness

- replaces the clock (`time`, `localtime`, `Time::HiRes`) with a virtual
  one that starts at a fixed time and advances only as the event loop
  needs, so timers, animations and displayed times are the same on every
  run and the screenshot of ten seconds of animation takes a fraction of
  a second;
- writes the scenario's input into the terminal as an xterm would send it,
  and waits until the program has received it;
- reads what the terminal shows from termbox2's front buffer.

The runner itself answers the cursor position query (`ESC [ 6 n`) that
inline mode (`inline => ROWS`) sends when it starts, as a terminal
would. A scenario's `shell` lines stand for what a shell printed before
the program started: the cursor starts below them, and the screenshot
shows them above the program's inline region, so an inline program
looks as it does in a real terminal.

A program that prints a report and ends (`Term::Fabulous::Static`) is
captured from its colored output instead.

The environment is fixed (`TERM=xterm-256color`, `LC_ALL=C.UTF-8`,
`TZ=UTC`, a fixed hash seed), so the same code always gives the same
image, byte for byte. Child processes a program starts run in real time
while the virtual clock waits for them.

The cells are then drawn as an SVG image in a window frame. Box drawing
and block characters are drawn as shapes, like terminals do, so borders
join without gaps and half-block pixels are square; text is placed cell
by cell, so the columns line up with any monospace font. The SVG uses
the viewer's fonts and needs no other files, which is what MetaCPAN and
GitHub require of images in documentation.

## Screenshots of any program

`tools/screenshot` takes one screenshot of any Term::Fabulous program,
as SVG or PNG:

```sh
perl -Mblib tools/screenshot --output form.svg examples/form.pl
perl -Mblib tools/screenshot --size 100x30 --steps 'type "Ada"; key "Tab"' \
    --output form.png examples/form.pl
perl -Mblib tools/screenshot --size 80x7 --shell '$ perl inline-prompt.pl' \
    --output prompt.png examples-cookbook/inline-prompt.pl
perl -Mblib tools/screenshot --help
```

PNG output needs Imager with PNG and FreeType support and fontconfig
(`fc-match`, `fc-list`) to find fonts. Characters the main monospace font
lacks are drawn with any installed font that has them; when none has
one, the tool stops and names the character instead of drawing a gap.
Emoji need a monochrome emoji font, because Imager cannot draw color
fonts.

## The modules

All under `tools/lib/Term/Fabulous/Screenshot/`:

| Module | Purpose |
|---|---|
| `Scenario` | parses `screenshots.kdl` |
| `Input` | key names, text and mouse actions as terminal bytes |
| `Runner` | runs a program in a pseudo terminal, answers its cursor position queries and returns its screen |
| `Harness`, `Clock`, `VirtualLoop` | run inside the program: input, virtual time, capture |
| `Screen` | the captured cells |
| `Scene`, `BoxDrawing`, `Theme` | what the image shows, independent of the format |
| `Render::SVG`, `Render::PNG` | draw a scene |
| `PodSync` | the code blocks marked with `=for code-from` |
