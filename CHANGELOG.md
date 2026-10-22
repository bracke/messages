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
- **Catalog entries under `und` are locale-neutral**: found last, after the
  default locale, they render in the requested locale rather than in the
  one they were found under. One `und` entry written in CLDR-backed
  arguments serves every locale.

### Added

- A catalogue check a project can run **without writing Ada**, so a consumer
  keeps its catalogue honest without building a tool of its own first.
- A translation is checked against the message it translates, including the
  case that reads as finished and is not: the original's words left inside a
  translation.
- A caller may say which keys belong to a locale.

### Fixed

- Byte-exact conformance and example data are written with LF on every host,
  and worked-example output is compared with CRLF normalised — two halves of
  the same Windows failure.
- Bytes are printed as they were read.
- A failing test fails the build.

## Releasing

No procedure yet. The open question is the same one the sibling crates have:
what a version means while every consumer resolves this one by path.
