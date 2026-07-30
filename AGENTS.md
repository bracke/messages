# Agent instructions — messages

ICU-style message formatting over the i18n platform.

This crate pins its GNAT toolchain via Alire. Build and test with `alr`, not
system GNAT / GPRBuild / GNATprove / GNATdoc tools on `PATH` — `alr exec -- gnatls --version` must report the pinned GNAT.

```sh
alr build
```
