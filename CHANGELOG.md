# Changelog

Notable changes to messages. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`alire.toml` says `0.1.0` and no tag exists. Adash pins this crate **by path**,
so the commit is the version until that changes, and a consumer's release
records which commit it was verified against.

This file starts where it was written rather than reconstructing fifty-six
commits; each of those says in its own message what changed and why.

## [Unreleased]

### Changed

- **`{offset, relative, unit}` uses CLDR's names for the offsets it has
  them for**: `yesterday` / `gestern` / `í gær` for -1 day, `übermorgen` for
  +2, `last week`, rather than `1 day ago` and `in 2 days` (ICU's and
  ECMAScript's `numeric: auto`). A locale's runtime relative patterns still
  win over the names.
- `{offset, relative, mon}` .. `{offset, relative, sun}` give CLDR's weekday
  names for -1, 0 and +1 ("last Monday", "letzten Montag", "先週の月曜日");
  other offsets are invalid, as CLDR has no pattern counting weekdays.
- **Catalog entries under `und` are locale-neutral**: found last, after the
  default locale, they render in the requested locale rather than in the
  one they were found under. One `und` entry written in CLDR-backed
  arguments serves every locale.

### Added

- `{items, list, unit-narrow}`: CLDR's narrow unit list, as a compact
  duration joins its parts ("1 h, 30 min und 5 s"; Japanese with nothing).

- A catalogue check a project can run **without writing Ada**, so a consumer
  keeps its catalogue honest without building a tool of its own first.
- A translation is checked against the message it translates, including the
  case that reads as finished and is not: the original's words left inside a
  translation.
- A caller may say which keys belong to a locale.

### Fixed

- A catalog with `unit` entries loads when i18n's data directory is missing:
  the unit identifier's shape decides validity there, instead of every unit
  counting as unknown and the whole catalog being rejected. Rendering such a
  unit, or a list of several items, then fails instead of printing a bare
  number or items run together, so a caller can fall back.

- Currency, grouping and Thai-digit expectations follow i18n's CLDR
  formatting, each checked against ICU or the CLDR 48 data: no-break
  spaces at the symbol, per-locale symbols, bidi marks, half-even rounding
  of extra fraction digits, "1234" where minimum grouping is 2.

- Ordinal words follow CLDR's rules (33 expectations, verified with ICU):
  Greek "εικοστός πρώτος", Hungarian "huszonegyedik", Portuguese "dois
  milésimo...", and soft hyphens in German, Dutch and Finnish compounds.

- A plural's `#` shows the count as the locale writes numbers, as ICU
  does: Arabic "٢١", French "1,5", grouping included. A negative number
  spelled out reads "minus forty-two" (CLDR's rule), not "- forty-two".

- A rate CLDR has no name for (megabit per second) puts the numerator into
  the denominator's own `perUnitPattern`, as ICU does: "1.5 Mb/s", not
  "1.5 Mb/sec"; Japanese "Mb/秒". Spell-out goes through CLDR's RBNF rules
  (48 expectations follow ICU).

- Byte-exact conformance and example data are written with LF on every host,
  and worked-example output is compared with CRLF normalised — two halves of
  the same Windows failure.
- Bytes are printed as they were read.
- A failing test fails the build.

## Releasing

No procedure yet. The open question is the same one the sibling crates have:
what a version means while every consumer resolves this one by path.
