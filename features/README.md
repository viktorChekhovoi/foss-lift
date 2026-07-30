# The feature catalogue

The catalogue tracks what the app does today as interlinked features and
concepts.

```
features/
  catalogue/NN-name.yaml   the entries, by section  <- edit these
  concepts.yaml            the concept vocabulary   <- edit this
  screens.yaml             where things are         <- edit this
  README.md                this file
  *.html                   GENERATED, gitignored    <- never edit, never commit
```


## The three pages

- **index.html** — the catalogue, one checkbox per behaviour. *Show links*
  reveals each entry's screen and concepts.
- **concepts.html** — what changes together. Answers "if I change this, what
  else has to move?"
- **walkthrough.html** — the same behaviours ordered by *screen* instead of by
  feature, so a testing pass visits each screen once instead of arriving there
  from six different sections. Mark pass/fail/skip, write a note on a failure,
  and **Report** collects them as markdown for an issue.


### Generating the pages

```bash
dart run tool/features.dart            # build the three pages
dart run tool/features.dart --check    # validate the source, write nothing
```

---

# Changing the spec

**The catalogue is written before the code.** The order is
feature → red → green → refactor: the entry is the specification the test is
written from. See the workflow in `CLAUDE.md`.

## An entry

```yaml
- id: board-marks-set-you        # stable; rewording the title must not change it
  t: The board marks the set you are on
  d: >
    the set the shade would name is marked in the accent…
  screen: session                # from screens.yaml; `none` = a rule with no surface
  defines: [session.progress-mark]
  uses: [session.warmup-ramp]
  manual: true                   # no automated test could ever cover this
```

Only `id` and `t` are required.

- **`id`** is permanent. The pages prefix it with the section number — this one
  is linked as `04.board-marks-set-you` — and that is what the walkthrough, the
  concept pages and every cross-link point at. Rewording `t` is free; changing
  `id` breaks links and drops the reader's tick. Derive it from the title when
  you first write it, then leave it alone.
- **`t`** is the behaviour, stated as a fact about the app. **`d`** is the why,
  or the detail. Both are prose, and both may contain inline HTML.
- **`screen`** is where you go to look at it. `none` means a rule with no
  surface — a solver's tie-breaking, a wire format, a policy. Those stay in the
  catalogue and are kept out of the walkthrough, because there is nothing to go
  and look at.
- **`manual: true`** means no automated test could ever cover it: whether a
  sound is audible, whether two colours are distinguishable, whether a layout
  reads well at 2× text. Marking it is the point — it tells a future test author
  not to try, and it tells the walkthrough to say so.

`screen`, `defines`, `uses` and `code` are inherited section → group → item, so
a group states a tag once instead of every item under it repeating it. An item
**adds** to what it inherits; it does not replace it.

## defines vs uses

- `defines` — this entry is where the concept lives. Change the concept and this
  entry is the one you edit.
- `uses` — this entry consumes it. Change the concept and this has to be
  re-checked.

### Example
"Add a new colour role" starts at `theme.colour-role`'s definers and cascades
to its users — the preview, the presets, the wire format.

Defining a concept subsumes using it; nothing appears in both columns.

## Adding a feature

1. **Write the entries first**, in the right `catalogue/NN-*.yaml`, phrased as
   what the app will do. This is the spec the tests come from.
2. Tag `screen`, and `defines`/`uses` against `concepts.yaml`. A new concept should get added to  `concepts.yaml`.
3. `dart run tool/features.dart --check`. Fix what it rejects.
4. Then write the tests, then the code. Regenerate the pages when you are done.

Adding a **section** means a new `catalogue/NN-name.yaml` whose `id` matches the
digits in its filename. It must carry `title`, `tagline` and `groups`; `screen`,
`defines`, `uses` and `code` are the tags every item under it inherits, `where`
is the "here is the code" footnote under the section, and `test:` lists the
files that cover it — a list, so a section split across two test files names
both, as section 04 does.

## Changing a feature that already exists

Edit the entry in place. **Do not add a second entry** saying the new
behaviour — the catalogue is what the app does now, not a changelog.

If the behaviour is gone, delete the entry. If it moved to another screen,
change `screen`. If it now leans on something new, add to `uses`.

## What --check enforces

Fails (the catalogue is now lying about the code):

- a concept or screen that is not in the vocabulary
- a duplicated item id, or a section id that disagrees with its filename
- a section's `code:` or `test:` path, or a concept's `code:` path, that has
  stopped existing. Paths on a group or an item are not checked.

Reported but never fatal:

- a concept that is used but that no entry describes
- a concept that nothing refers to at all
- a screen that no entry sits on
- pages on disk that have gone stale

## A note on scale

The catalogue is still short enough that a person can read the whole thing in
one sitting, and that is the property worth protecting — `--check` prints the
current count. If a section grows past what fits in one sitting, split it rather
than letting it become a file nobody opens.
