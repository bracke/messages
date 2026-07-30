# messages

`messages` is an Ada 2022 library for strict, deterministic **ICU-style message
formatting**. It is built on the [`i18n`](../i18n) Unicode/CLDR platform, which
it depends on for locale identity, plural classification, and all
locale-sensitive value formatting — numbers, dates, currency, units and
measures, durations, byte sizes, relative time, and lists.

The application-facing contract is catalog-based:

```text
catalog file -> initialization -> deterministic catalog validation -> locale/key lookup -> structured render result
```

## Public packages

* `Messages` — root
* `Messages.Runtime` — catalog loading and rendering
* `Messages.Result` — structured render result and status
* `Messages.Arguments` — message argument maps
* `Messages.Diagnostics` — optional non-interfering diagnostics

`messages` also uses two packages directly from the `i18n` platform:
`I18N.Locales` (locale canonicalization and fallback) and `I18N.Plurals`
(CLDR plural categories). Both are re-exported concepts of the platform, not of
this crate.

Applications should not depend on the parser, validator, compiler, AST,
compiled IR, cache, buffer, or lower-level renderer packages (`Messages.Parser`,
`Messages.Compiler`, `Messages.Cache`, `Messages.AST`, …). They are declared as
private children for implementation and regression testing and are outside the
source-compatibility guarantee.

## Minimal example

```ada
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;

procedure Example is
   Runtime : Messages.Runtime.Instance;
   Args    : Messages.Arguments.Arguments;
begin
   Messages.Runtime.Initialize (Runtime, "messages.catalog");
   Messages.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant Messages.Result.Render_Result :=
        Messages.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "welcome",
           Arguments => Args);
   begin
      if Result.Status = Messages.Result.Success then
         null; --  Messages.Result.Output_Text (Result.Text) holds the message.
      end if;
   end;
end Example;
```

Public `Render` never raises for normal message failures; it returns a
`Messages.Result.Render_Result` with a stable `Render_Status`.

## Catalog format

The canonical catalog format is line-oriented text:

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
```

Entries use `locale.key = ICU message`. `default_locale` may appear at most once
and must not be empty. Duplicate `locale.key` entries, empty locale names, empty
keys, malformed lines, and unbalanced message braces make initialization invalid
deterministically. See `docs/CATALOG_FORMAT.md`.

## Supported ICU message subset

Literal text; `{name}` variables; `plural`, `select`, and `selectordinal`
blocks (with exact `=N` branches, `offset:N`, full CLDR category branches, and a
required `other`); `#` substitution; nesting; and ICU apostrophe escaping. The
embedded number/currency/date skeletons (`{n, number, ::percent}`,
`{amt, currency, USD}`, `{d, date, ::yMMMd}`, …) are evaluated by the `i18n`
platform formatters. Full syntax is documented in `docs/ICU_SUBSET.md`.

## Loading, shards, and validation

A single runtime can layer catalog shards (`Load_File` / `Load_Text`), each load
transactional and non-destructive, with `Reject_Duplicates` /
`Keep_First` / `Override_Previous` policies reported through `Load_Result`.
`Validate_Catalog_File` / `Validate_Catalog_Text` check a catalog without
touching any runtime, and `Resolve` reports key reachability through the locale
fallback chain without rendering. Locale fallback (`de-AT -> de -> default`) and
canonicalization are provided by `I18N.Locales`; plural/selectordinal branch
selection by `I18N.Plurals`.

## Translation consistency

`Validate_Catalog_File` answers whether a catalog is well-formed.
`Messages.Consistency` answers something a well-formed catalog can still get
wrong: a locale that has drifted from the messages it was translated from. None
of it judges a translation -- that needs a speaker of the language. It catches
what does not:

| Finding | What it means |
| --- | --- |
| `Missing_Original` | A translated key the default locale does not have, so nothing can ask for it. |
| `Argument_Dropped` | The original takes an argument the translation does not: "file not found", without the filename. |
| `Argument_Added` | The translation takes an argument no caller supplies. |
| `Token_Dropped` | A caller-named token -- an option, a command, a product name -- is in the original and not in the translation, so a user who types what they were shown gets an error. |
| `Partly_Original` | A run of the original's own words left standing inside a translation written in another script. |
| `Escape_Hazard` | An apostrophe ICU reads as opening a quoted literal, which swallows the argument after it. |

Text identical to the original is counted rather than listed, and does not fail:
short strings coincide between languages often enough that failing on it would
teach people to ignore the check.

`Partly_Original` catches word substitution -- the English sentence with a
couple of nouns swapped -- which passes every other rule here because the key
exists and the arguments are all present. It reports only a run of three of the
original's words, and only in locales it can see are not written in the Latin
script, because one borrowed word is how a language normally names a thing it
borrowed. So it finds less than it misses: a Latin-script locale left in English
is invisible to it. What it reports, it is right about.

`tools/catalog_check` is the same rules on a command line, so a project needs no
Ada of its own to have them. It exits 1 on anything that would reach a user:

```sh
catalog_check share/app/messages.catalog \
  --verbatim=--help,--version,install,appname \
  --locale-only=meta.
```

`--verbatim` names the tokens that must survive translation. `--locale-only`
names key prefixes a locale may carry without the default locale having them,
for catalogs that mark a translation's own state.

## Bounded rendering

`Render_Into` renders a compiled message directly into caller-owned fixed
storage with no intermediate dynamic allocation:

```ada
Buffer : String (1 .. 256);
Last   : Natural;
Status : Messages.Result.Render_Status;
...
Messages.Runtime.Render_Into (Runtime, "en", "welcome", Args, Buffer, Last, Status);
```

## Build and tests

```sh
alr test
```

`alr test` builds and runs the AUnit suite (`messages/tests`, 152 tests) and the
ICU/CLDR message-rendering conformance harness (`messages/conformance`). Worked
examples live in `messages/examples` (run from the crate root, e.g.
`./examples/bin/basic_render`) and render benchmarks in `messages/benchmarks`.

## Dependency

`messages` pins the sibling `i18n` platform crate (`../i18n`). A checkout needs
that directory present next to this one. See `docs/` for the detailed API,
architecture, error model, and compatibility policy.
