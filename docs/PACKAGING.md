# Packaging and Alire Metadata

This project ships an `alire.toml` manifest so the library can be consumed as an
Alire source crate.

## Crate identity

```toml
name = "messages"
version = "0.1.0"
project-files = ["messages.gpr"]
```

The crate exposes the static library project `messages.gpr`. The test and
example project files are shipped for validation and demonstration, but they are
not listed as primary project files in the Alire manifest.

## Public API package set

Alire consumers should depend only on the stable public packages:

```ada
with I18N;
with Messages.Runtime;
with Messages.Result;
with Messages.Arguments;
with I18N.Locales;
with I18N.Plurals;
with Messages.Diagnostics;
```

Implementation packages such as `Messages.Parser`, `Messages.Compiler`, `Messages.Cache`,
`Messages.Compiled`, `Messages.Errors`, and `Messages.Runtime.Compatibility` are Ada-private
implementation units and are not part of the crate's public source contract.

## Toolchain requirement

The project is written for Ada 2022 and the manifest declares:

```toml
[[depends-on]]
gnat = ">=12"
```

A release verification pass should still be run with the exact GNAT/GPRbuild
version used for publication.

## License

The package metadata declares the crate license as MIT and the release archive
includes the corresponding `LICENSE` file.

## Publication readiness audit

The `alr test` release gate runs an Alire publication readiness audit through
the project-tools-based `check_messages` guard. The audit requires the root
`alire.toml` to be pin-free, named `messages`, declare publication metadata
(`description`, `version`, authors, maintainers, maintainer logins, MIT license,
tags, `project-files = ["messages.gpr"]`, and `gnat = ">=12"`), and route the Alire
test action through `check_messages`.

The audit also verifies that `LICENSE`, `messages.gpr`, and the release packaging
documentation are present and consistent, and that the Alire manifest does not
publish the test or example project files as primary project files.

## Local consumption

From another Alire workspace, use the crate as a local dependency during testing:

```sh
alr with --use=/path/to/messages messages
```

Then import only the stable public packages listed above.

## Release verification

Before publication, run `alr test`. The manifest test action invokes the
project-tools-based `check_messages` guard described in
`docs/RELEASE_VERIFICATION.md`.
