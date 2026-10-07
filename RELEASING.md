# Releasing Term::Fabulous to CPAN

This dist uses plain `ExtUtils::MakeMaker` plus
[`cpan-upload`](https://metacpan.org/pod/cpan-upload) (from
`CPAN::Uploader`). No Dist::Zilla, no Minilla, no surprises.

## Per-release checklist

1. Make sure the working tree is clean and on `master`:

   ```sh
   git status
   git pull --ff-only
   ```

2. Bump `$VERSION` in `lib/Term/Fabulous.pm` and in every other module under `lib/` (see "Notes on dependencies").

3. Update `Changes`: replace the date on the new version's heading and
   add bullet points describing the changes since the last release.

4. Bring the documentation up to date and commit what changed: the code
   blocks copied from the example programs, the screenshot URLs in the
   POD, the screenshots in `screenshots/`, `README.md` and the Markdown
   pages in `docs/`. See `tools/README.md`.

   ```sh
   make docs
   ```

   `make release` refuses to run while `make docs-check` finds anything
   out of date.

   The POD shows the screenshots with
   `<img src="https://raw.githubusercontent.com/davenonymous/perl-term-fabulous/vVERSION/screenshots/NAME.svg">`,
   because MetaCPAN shows images with relative paths as gray
   placeholders. `make docs` sets `vVERSION` to the tag of the current
   `$VERSION`, so each release on MetaCPAN shows its own screenshots
   once its tag is pushed (step 8). The Markdown files point to the
   same files in the `master` branch instead. Keep `screenshots/` in
   `MANIFEST`: the POD names the files in the dist for readers without
   HTML.

   `tools/pod2markdown` writes `README.md` from `lib/Term/Fabulous.pm`
   and `docs/NAME.md` from every other `lib/NAME.pm` and `lib/NAME.pod`.
   Only `README.md` is shipped; its links to the pages in `docs/` point
   to GitHub, so they work on MetaCPAN too. Code blocks are fenced with
   the language set by the last `=for highlighter language=NAME`
   paragraph in the POD (`perl` before the first one); MetaCPAN uses the
   same marker. Put such a paragraph before every code block that is
   not Perl (`kdl`, `sh`, `text`), and one with `perl` before the next
   Perl block. In `text` blocks, tables (a header line, a line of dashes
   per column, then the rows) become Markdown tables; see
   `perldoc tools/pod2markdown`. Never edit the Markdown files by hand.

5. Sanity-build from a clean slate:

   ```sh
   make distclean 2>/dev/null || true
   perl Makefile.PL
   make
   make test
   ```

6. Commit the release, push it and wait for CI to pass on that commit.
   `make release` refuses to run on a dirty tree, so this has to happen
   first anyway:

   ```sh
   git commit -am "Release v$(perl -Ilib -MTerm::Fabulous -e 'print $Term::Fabulous::VERSION')"
   git push
   gh run watch --exit-status \
       "$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')"
   ```

   If `gh run list` finds no run yet, wait a few seconds: GitHub
   creates it shortly after the push. Upload only when every job is
   green, on every Perl and in the distribution check; `make release`
   refuses to upload otherwise. If one fails, fix the cause, commit,
   push and watch again.

7. Cut and upload the release:

   ```sh
   make release
   ```

   The `release` target:

   - Runs `make disttest` (builds the dist directory, configures it,
     and runs its tests - this is what catches missing `MANIFEST`
     entries before they reach CPAN).
   - Runs `make dist` to build the tarball (`disttest` alone does not
     create one) and refuses to upload if it is missing.
   - Refuses to proceed if the git working tree is dirty.
   - Refuses to proceed if a tag `v$(VERSION)` already exists.
   - Refuses to proceed unless the GitHub CI run of `HEAD` has passed
     (`make ci-check`, which needs an authenticated `gh`).
   - Refuses to proceed if the code blocks, screenshot URLs,
     screenshots, `README.md` or `docs/` are out of date
     (`make docs-check`).
   - Runs `cpan-upload` on the freshly built tarball.

8. Tag and push:

   ```sh
   git tag -a "v$(perl -Ilib -MTerm::Fabulous -e 'print $Term::Fabulous::VERSION')" \
          -m "Release v$(perl -Ilib -MTerm::Fabulous -e 'print $Term::Fabulous::VERSION')"
   git push --follow-tags
   ```

   The tag must be annotated (`-a`): `git push --follow-tags` only
   pushes annotated tags, so a lightweight tag would silently stay
   local.

9. Wait ~1 hour, then verify on
   [MetaCPAN](https://metacpan.org/dist/Term-Fabulous).

## Recovery

- **Upload failed mid-way.** `cpan-upload` is idempotent against PAUSE
  re-uploads of the *same* tarball; just run `make release` again.
- **Uploaded a broken release.** You have 72 hours to delete it from
  PAUSE via the web UI (`https://pause.perl.org/` -> "Delete
  Files"). After that it's permanent in the BackPAN archive. Either
  way, **never reuse a version number** - bump and re-release.
- **Forgot to bump `$VERSION`.** The `release` target's "tag already
  exists" guard will catch this on the second run, but the tarball
  will already exist locally. Delete it (`rm Term-Fabulous-*.tar.gz`),
  bump the version, and start over.

## Notes on dependencies

- Every module under `lib/` carries its own `our $VERSION`, and the
  `version-check` target refuses to release when any of them differs
  from `lib/Term/Fabulous.pm`. Bump them all together, for example:

  ```sh
  perl -pi -e "s/^our \\\$VERSION = '[^']*';/our \\\$VERSION = '0.02';/" $(find lib -name '*.pm')
  ```

- `Clay::XS` (which provides `Clay::UI`) is a hard runtime dependency
  and is not on CPAN yet. Until it is released, `cpanm --installdeps .`
  cannot resolve it and the dist cannot be indexed by PAUSE with a
  satisfiable prereq list. Release `Clay::XS` first.
- `cpanfile` and `Makefile.PL` both declare the dependencies. Keep them
  in sync when adding or bumping a prerequisite.
