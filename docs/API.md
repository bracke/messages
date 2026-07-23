# Public API

For the i18n Unicode/CLDR platform API (locale identity, plural classification,
text algorithms, CLDR formatters, and the generated data layer), see the `i18n`
crate's docs/API.md.

This document describes the 0.1.0 application-facing API. Packages not listed here are implementation details or regression-test support and are outside the 0.1.0 source-compatibility promise.

## Public packages

Stable public packages:

* `Messages`
* `Messages.Runtime`
* `Messages.Result`
* `Messages.Diagnostics`
* `Messages.Arguments`

The message engine also uses two i18n platform packages directly, and their
public types appear in this API:

* `I18N.Locales` — locale identity, canonicalization, and fallback (`Locale_Id`)
* `I18N.Plurals` — CLDR cardinal/ordinal plural categories used for message selection

Parser, validation, compiler, AST, compiled IR, cache, buffer, fast-render,
lower-level renderer, internal error, observability, formatter implementation,
generated CLDR data, and compatibility packages are Ada private child packages.
Ordinary application code cannot legally `with` those packages.

## `Messages.Runtime`

`Messages.Runtime.Instance` is the stable runtime handle. Initialize it once, then call the catalog-oriented render API.

### Initialization

```ada
procedure Initialize
  (Item         : in out Messages.Runtime.Instance;
   Catalog_Path : String);
procedure Initialize_Binary_File
  (Item         : in out Messages.Runtime.Instance;
   Catalog_Path : String);
```

Behavior:

* opens the catalog file when `Catalog_Path` names an existing ordinary file;
* reads the entire catalog deterministically;
* accepts blank lines and comment lines beginning with `#`;
* accepts one `default_locale = locale` directive anywhere in the file;
* validates duplicate entries, empty locale names, empty keys, empty default locale, duplicate default locale, malformed lines, and unbalanced catalog message braces;
* performs deterministic catalog validation during initialization;
* leaves the runtime invalid when any catalog error is found.
* `Initialize_Binary_File` first validates the versioned binary envelope, then
  initializes from its canonical text payload.

Failure behavior:

* initialization records failure state instead of exposing parser/compiler internals;
* `Is_Valid` returns `False` after invalid initialization;
* public catalog `Render` returns `Execution_Error` when the runtime is invalid.

Compatibility note: the source contains single-message helper entry points for in-tree regression tests. Those entry points live behind Ada private-child visibility and are not importable application API.

### Render

```ada
function Render
  (Item      : Messages.Runtime.Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : Messages.Arguments.Arguments)
   return Messages.Result.Render_Result;
```

Render behavior:

* does not mutate the runtime catalog;
* resolves locale by deterministic fallback;
* returns `Missing_Key` after fallback if no entry exists;
* returns `Missing_Argument` when a variable or selector argument is absent;
* returns `Invalid_Argument` when a numeric selector argument is not a strict decimal integer;
* applies ICU-style apostrophe escaping for literal syntax characters in catalog messages;
* returns `Formatting_Error` for deterministic branch-selection failures;
* returns `Buffer_Overflow` when output exceeds the supported render buffer;
* returns `Internal_Error` only for unexpected implementation failures contained by the facade;
* does not raise for normal ICU/render failures.

### Catalog shard loading

```ada
type Duplicate_Policy is (Reject_Duplicates, Keep_First, Override_Previous);
type Load_Status is
  (Loaded, Source_Not_Found, Invalid_Catalog, Duplicate_Rejected, Runtime_Invalid);
type Load_Result is record
   Status           : Load_Status;
   Entries_Added    : Natural;   --  new locale/key pairs inserted
   Entries_Replaced : Natural;   --  existing pairs overwritten (Override_Previous)
   Entries_Ignored  : Natural;   --  duplicate pairs skipped (Keep_First)
   Diagnostics      : Messages.Diagnostics.Diagnostic_List;
end record;

procedure Load_File
  (Item   : in out Instance; Path : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Binary_File
  (Item   : in out Instance; Path : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Text
  (Item   : in out Instance; Source_Name : String; Text : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
```

`Load_File`/`Load_Text` layer additional catalog shards into a runtime. `Load_Binary_File` layers a versioned binary catalog shard after decoding its envelope. These load APIs are transactional and non-destructive: a failed load (`Source_Not_Found`, `Invalid_Catalog`, `Duplicate_Rejected`, `Runtime_Invalid`) leaves the runtime exactly as it was. The legacy `Load` procedure is retained and, like `Initialize`/`Initialize_Binary_File`, marks the runtime invalid on failure.

### Catalog validation

```ada
type Catalog_Validation_Result is record
   Valid       : Boolean;
   Entry_Count : Natural;
   Diagnostics : Messages.Diagnostics.Diagnostic_List;
end record;

function Validate_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Binary_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Catalog_Text
  (Source_Name : String; Text : String) return Catalog_Validation_Result;
function Validate_Binary_Catalog_Text
  (Source_Name : String; Text : String) return Catalog_Validation_Result;
```

Validation never mutates any runtime. If validation fails, existing runtimes remain usable.

### Runtime data overrides

```ada
type Data_Load_Status is (Data_Loaded, Data_Source_Not_Found, Invalid_Data);
type Data_Load_Result is record
   Status      : Data_Load_Status;
   Diagnostics : Messages.Diagnostics.Diagnostic_List;
end record;

function Load_Data_Text
  (Source_Name : String; Text : String) return Data_Load_Result;
function Load_Data_File (Path : String) return Data_Load_Result;
procedure Clear_Runtime_Data;
```

`Load_Data_Text`/`Load_Data_File` install process-wide deterministic runtime-data
overrides before the generated CLDR/tzdb fallback data used by the i18n platform
formatters. They are a thin facade over the platform data layer
(`I18N.Runtime_Data`): locale symbols, digits, grouping, currency metadata,
time-zone offsets, day-period rules, plural-category and RBNF overrides, and the
full normalized LDML/tzdb import row grammar are documented with the platform in
the `i18n` crate's docs/API.md and docs/ICU_SUBSET.md. Loads are transactional:
malformed data returns `Invalid_Data` and leaves the previous override set
intact. `Clear_Runtime_Data` removes all loaded overrides.

### Key resolution

```ada
type Resolve_Status is (Found, Missing_Key, Runtime_Invalid);
type Resolve_Result is record
   Status : Resolve_Status; ...
end record;
function Resolved_Locale (Item : Resolve_Result) return I18N.Locales.Locale_Id;
function Resolve
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String)
   return Resolve_Result;
```

`Resolve` answers whether a key is reachable through locale fallback without rendering it and without arguments.

### Bounded rendering

```ada
procedure Render_Into
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String;
   Arguments : Messages.Arguments.Arguments;
   Target : in out String; Last : out Natural;
   Status : out Messages.Result.Render_Status);
```

Renders the compiled AST **directly into** caller-owned storage without materializing an intermediate dynamic buffer. On `Success`, `Target (Target'First .. Last)` holds the output. On `Buffer_Overflow`, `Target` holds the prefix that fits and `Last` is the last written index. On any other failure, `Last = 0`.

### Allocation note

Public `Render` returns a structured result containing materialized text and is not specified as a zero-allocation API. `Render_Into` is the public allocation-free path: it writes each rendered fragment straight into the caller's `String` and never builds an `Unbounded_String`. The no-allocation release gate also covers the private fixed-buffer compatibility path used by in-tree regression tests.

### Runtime inspection and cleanup

```ada
function Is_Valid (Item : Messages.Runtime.Runtime) return Boolean;
procedure Finalize (Item : in out Messages.Runtime.Runtime);
```

`Is_Valid` is useful after initialization. `Initialize_Binary_File` accepts the versioned binary catalog envelope:

```text
I18N-CATALOG-BINARY
format_version=1
ir_version=1
payload=text

```

The blank line after the header is followed by the canonical text catalog payload. Unsupported magic, format versions, IR versions, and payload kinds are rejected deterministically. `Finalize` clears runtime-owned catalog/message references and does not clear the process-global cache.

`payload=hex-text` is also accepted in the same envelope; the payload body is ASCII hex bytes for the canonical text catalog payload and is decoded before the normal catalog validation/compile path. Malformed hex payloads are rejected deterministically.

The single-message/fixed-buffer APIs are isolated in private child package `Messages.Runtime.Compatibility` for in-tree regression tests only. They are not part of the 0.1.0 application contract and are not directly importable by ordinary downstream units. This private path is where strict fixed-buffer no-allocation checks are performed.

## `Messages.Result`

Frozen status set:

```ada
type Render_Status is
  (Success,
   Missing_Key,
   Missing_Argument,
   Invalid_Argument,
   Formatting_Error,
   Execution_Error,
   Buffer_Overflow,
   Internal_Error);
```

`Messages.Result.Output_Text (Result.Text)` is meaningful only when `Status = Success`. `Render_Result.Diagnostics` may contain additional detail. Public callers do not receive parser nodes, compiler objects, cache internals, IR arrays, or internal error records through this result type.

## `Messages.Arguments`

Public argument map API:

```ada
procedure Set (Args : in out Arguments; Key : String; Value : String);
procedure Set_Integer (Args : in out Arguments; Key : String; Value : Long_Long_Integer);
procedure Set_Natural (Args : in out Arguments; Key : String; Value : Natural);
procedure Set_Boolean (Args : in out Arguments; Key : String; Value : Boolean);
procedure Clear (Args : in out Arguments);
procedure Copy (Source : Arguments; Destination : in out Arguments);
function Has (Args : Arguments; Key : String) return Boolean;
function Get (Args : Arguments; Key : String) return String;
procedure Copy_Value
  (Args     : Arguments;
   Key      : String;
   Target   : out String;
   Last     : out Natural;
   Found    : out Boolean;
   Overflow : out Boolean);
```

Arguments are string-valued and intentionally noncopyable at the Ada type level; pass them by reference, mutate them with `Set`/`Clear`, use `Copy` when an explicit duplicate is needed, and do not rely on whole-object assignment. `Copy_Value` copies a stored value into caller-owned fixed storage and reports missing keys or truncation without allocating. `Set_Integer`/`Set_Natural` write strict decimal text with no `'Image` leading space; `Set_Boolean` writes `true`/`false`. These helpers are deterministic and not locale-aware. Plural and selectordinal selectors are parsed strictly during render; non-offset `plural` accepts strict integer or decimal text and uses CLDR fractional operands `i`, `v`, and `f` for decimal cardinal-category selection, while `selectordinal` and offset plurals require integer selectors. Exact integer branches such as `=0` and `=11` are normalized for duplicate detection and selected before category branches; plural messages may use `offset:N`, which makes category selection and `#` substitution use `selector - N`. Number and currency arguments are supplied as strict decimal text for messages such as `{value, number}`, `{value, number, ::percent}`, `{value, number, ::compact-short}`, `{amount, currency, USD}`, and `{amount, number, ::currency/USD}` and separate-token forms such as `{amount, number, ::currency/CHF precision-currency/cash sign/accounting unit-width/full-name}`. Number formatting applies deterministic locale grouping, decimal separators including comma decimals for `ro`, `lt`, and `sl`, Indian grouping for `hi`, `bn`, and `*-IN`, Arabic-Indic digits for `ar`, Persian digits for `fa`, Thai digits for `th`, Bengali digits for `bn`, and explicit `-u-nu-*` digits for all generated CLDR numeric numbering systems including `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`, supported skeletons for percent, permille, compact/scientific/engineering notation including ICU-style `notation-*`, `notation/*`, and slash-expanded compact aliases such as `::compact/short` and `::notation/compact/short`, with CJK compact 10,000 and 100,000,000 scaling for `ja`, `zh`, and `ko`, precision including `::precision-unlimited`, fraction precision ranges such as `::precision-fraction/0-2`, and significant precision ranges such as `::precision-significant/1-3`, padding, integer-width padding with required-zero stems such as `+000`, `000`, or `*000` and optional-`#` stems such as `+##0`, `##0`, or `*##0`, expanded rounding modes, precision-increment skeletons, and rounding-increment aliases including half-even/half-down/half-ceiling/half-floor/ceiling/floor, sign-display skeletons including `::sign-auto`, `::sign-negative`, `::sign/accounting`, and `::sign-accounting` variants, grouping controls including `::group-min2` plus deterministic `::group-on-aligned` and `::group-thousands` aliases, decimal-display controls, trailing-zero-display controls, and positive integer/decimal scale controls, compound skeleton token lists such as `::percent precision-integer`, and deterministic English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Japanese, Chinese, Korean, Turkish, Swedish, Danish, Norwegian, Finnish, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Catalan, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, and Hebrew `::spellout`/`::spellout-cardinal`/`::spellout-cardinal-verbose`/`::spellout-numbering`/`::spellout-year` and deterministic gendered cardinal aliases for signed whole numbers and strict decimals whose absolute integer part is up to 999,999,999, plus `::ordinal-words`/`::spellout-ordinal`/`::spellout-ordinal-verbose` and deterministic gendered ordinal aliases for signed whole numbers whose absolute value is up to 999,999,999; cardinal decimal spellout preserves visible fraction digits after a localized decimal separator word, negative spellout values render the locale minus sign followed by the localized words, and explicit plus signs are accepted without rendering a plus sign. Currency formatting emits symbols, narrow symbols, generated CLDR 46.1 display names with CLDR plural-category selection for all imported currency-name locales with exact, parent, and default fallback, English display names, standard symbols, narrow symbols, minor-unit metadata, and cash-rounding metadata for the 307-code generated CLDR 46.1 currency table including `ADP`, `AFN`, `XCG`, `VED`, `ZWG`, `ZWL`, `JPY`, `KWD`, and `CLF`, ISO-code unit-width output, accounting negatives, cash rounding, grouping, locale digits/separators, and separate-token currency number skeletons including `standard`, `full-name`, `unit-width-long`, `unit-width/long`, `iso-code`, `unit-width/iso-code`, `precision-currency-standard`, `precision-currency/standard`, `precision-currency-cash`, `precision-currency/cash`, and `sign/accounting`, plus common minor-unit metadata such as zero-minor-unit `JPY`, three-minor-unit `KWD`, and four-minor-unit `CLF`; currency options are written as suffixes such as `{amount, currency, USD/name}`, `{amount, currency, USD/full-name}`, `{amount, currency, CAD/narrow}`, `{amount, currency, USD/unit-width-iso-code}`, `{amount, currency, USD/iso-code}`, `{amount, currency, USD/precision-currency-standard}`, `{amount, currency, USD/accounting}`, `{amount, currency, CHF/cash}`, or `{amount, number, ::currency/USD/accounting}`. Date arguments use strict `YYYY-MM-DD` text or ISO instant text for `{day, date}` with optional `short`, `medium`, `long`, `full`, or `::` skeleton style; supported date skeletons allow apostrophe-quoted literals and fields are `G`, `y`, `Y`, `u`, `U`, `r`, `Q`, `q`, `M`, `L`, `l`, `w`, `W`, `d`, `D`, `F`, `g`, `E`, `e`, and `c`, with common CLDR `availableFormats` skeletons resolved through generated locale data before direct field rendering, numeric local weekday output for `e`/`c` widths 1-2, localized full and abbreviated month/weekday names plus wide and abbreviated quarter names for all 725 imported CLDR 46.1 date locales with exact and parent-locale fallback, runtime/imported narrow month and weekday names for `MMMMM`/`LLLLL` and `EEEEE`/`ccccc` with UTF-8-safe fallback, runtime/imported narrow quarter names for `QQQQQ`/`qqqqq` with numeric fallback, and localized Gregorian era labels. Buddhist calendar year display, Japanese calendar era-year display with localized `ja` era names for Reiwa, Heisei, Showa, Taisho, Meiji, and Keio, ROC/Minguo year display with localized `zh` era names, Julian calendar date conversion, Coptic calendar date conversion, Ethiopic calendar date conversion, Ethiopic Amete Alem calendar year display, tabular Islamic civil, tabular astronomical Islamic, Indian national, arithmetic Persian, and deterministic Hebrew lunisolar calendar date conversion are selected from `-u-ca-buddhist`, `-u-ca-japanese`, `-u-ca-roc`, `-u-ca-julian`, `-u-ca-coptic`, `-u-ca-ethiopic`, `-u-ca-ethioaa`, `-u-ca-islamic-civil`, `-u-ca-islamic`, `-u-ca-islamicc`, `-u-ca-islamic-tbla`, `-u-ca-indian`, `-u-ca-persian`, and `-u-ca-hebrew` locale extensions or supported runtime-data `default_calendar` preferences; `-u-ca-gregory`/`-u-ca-gregorian` explicitly select Gregorian behavior and override runtime defaults, `-u-ca-iso8601` selects Gregorian date conversion with ISO week data, and unsupported calendar extensions are rejected deterministically. Time arguments use strict `HH:MM`, `HH:MM:SS`, or `HH:MM:SS.fraction` local time text or ISO instant text for `{clock, time}` with optional style or `::` skeleton; supported time skeletons allow apostrophe-quoted literals and fields are `a`, `b`, `B`, `h`, `H`, `K`, `k`, `j`, `J`, `C`, `m`, `s`, `S`, `A`, `n`, `N`, `z`, `Z`, `O`, `v`, `V`, `X`, and `x`, including skeleton-selected 12-hour output, source-backed localized AM/PM text for all 725 imported CLDR 46.1 date locales and flexible day periods using source-backed midnight/noon labels where CLDR supplies them, fractional-second and nanosecond fields from parsed fractional seconds, milliseconds and nanoseconds in day, and source-backed zone offset/name forms including short `z` specific abbreviations and short `v` generic labels for built-in DST families, built-in localized generic zone names with English fallback, long GMT offsets, ISO extended offsets, numeric zero `x` offsets, and V-width zone identifiers and location labels. `{instant, datetime, style, zone}` combines date and time output after converting `YYYY-MM-DDTHH:MM[:SS[.fraction]]Z`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HHMM`, or `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM` input, with matching negative offset forms, to a deterministic target zone, and datetime skeletons may combine the supported date and time fields. Supported target zones include `UTC`, `utc`, `Z`, `z`, `GMT`, `gmt`, `Etc/UTC`, `Etc/GMT`, `Zulu`, and UTC aliases, numeric offsets such as `+02`, `+0230`, and `+02:00`, checked IANA tzdb 2026a primary zones, and checked tzdb links such as `US/Eastern`, `Canada/Eastern`, `Mexico/General`, and `Brazil/East`. Instant conversion uses generated seconds-based tzdb transition offsets for 447 primary zones over 1900 through 2050; runtime ingestion of broader external tzdb sources is part of the completion scope, while the current runtime accepts only the deterministic runtime-data formats documented with the platform. Zone-name skeleton output uses generated source-backed fixed-zone, generic-family, and short-family display rows where present, then deterministic built-in display names and GMT-offset fallbacks. Additional deterministic formatters accept `{seconds, duration}`, `{size, bytes}`, `{distance, unit, kilometer}`, `{distance, number, ::measure-unit/length-kilometer unit-width-short per-measure-unit/duration-hour}`, `{offset, relative, day}`, and `{items, list}` where numeric output honors locale signs, digits, and explicit `-u-nu-*` numbering-system extensions for all generated CLDR numeric systems, byte sizes render deterministic B/KiB/MiB/GiB/TiB/PiB units, unit quantities are strict integer or decimal text, and direct unit, relative-time, and measure-unit skeleton aliases are localized where source-backed. Missing values produce `Missing_Argument`; syntactically invalid numeric, number, currency, date, time, date-time, duration, byte-size, unit, relative-time, or list arguments produce `Invalid_Argument`.

The full set of supported number skeletons, currency options, date/time skeleton
fields, calendars, target zones, units, list styles, and their exact rendering
rules is documented with the platform formatters in the `i18n` crate's
docs/ICU_SUBSET.md; this section covers only how those formatters are reached
through message arguments.

## `Messages.Diagnostics`

Diagnostics are fixed-storage structures used to report optional detail without affecting correctness. They are safe to ignore. The callback and diagnostic list APIs are observational; rendering correctness must not depend on them.

```ada
procedure Set_Trace_Callback
  (CB : Messages.Diagnostics.Trace_Callback);
```

Passing `null` disables tracing. Callback exceptions are caught by the diagnostics layer and do not escape into render.

## Public example imports

A valid 0.1.0 application example should need only:

```ada
with Messages.Arguments;
with Messages.Result;
with Messages.Runtime;
```

It may additionally `with Messages.Diagnostics` or `I18N.Locales` when it needs those names explicitly.

See also `docs/PUBLIC_IMPORT_RULES.md` for the exact Ada import boundary.
