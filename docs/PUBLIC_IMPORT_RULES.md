# Public Import Rules

The release enforces the API boundary with Ada visibility, not only with documentation.

## Allowed application imports

Application code may import these stable public packages:

```ada
with I18N;
with Messages.Runtime;
with Messages.Result;
with Messages.Arguments;
with I18N.Locales;
with I18N.Plurals;
with Messages.Diagnostics;
```

`I18N.Plurals` provides CLDR plural-category classification. `Messages.Diagnostics` is optional and observational.

## Forbidden downstream imports — do not write this

The following units are Ada private child packages and are not legal ordinary application imports. They are shown only as a negative example for humans and AI tools:

```ada
with Messages.AST;
with Messages.Buffer;
with Messages.Cache;
with I18N.CLDR_Data;
with Messages.Compiled;
with Messages.Compiler;
with I18N.Currency;
with I18N.Date_Time_Format;
with Messages.Errors;
with Messages.Extra_Format;
with Messages.Fast_Render;
with I18N.Number_Format;
with Messages.Observability;
with Messages.Parser;
with Messages.Render;
with Messages.Runtime.Compatibility;
with Messages.Validation;
```

These units exist for implementation internals and in-tree descendant regression tests. Their declarations may change without breaking the v0.1.0 public compatibility contract.

## Regression tests

The AUnit regression suites are declared under the `Messages.Runtime.Tests.*` namespace. This is intentional: those units are descendants of both `I18N` and `Messages.Runtime`, so they may legally import `I18N` private child packages and the private child `Messages.Runtime.Compatibility`. That exception does not apply to downstream application code.

## Public example gate

`examples/public_api_sealed.adb` intentionally imports only stable public packages. It is the reference import pattern for downstream consumers and AI tools.


## Verification

These import rules are intended to be compiler-enforced. Run the commands in `docs/RELEASE_VERIFICATION.md` before tagging v0.1.0 so GNAT confirms both public-example imports and private-child regression-test access.
