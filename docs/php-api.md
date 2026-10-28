# PHP API

## `GetBible\Sword\Engine`

### Construction

```php
new Engine(?string $modulePath = null)
```

An explicit non-empty path is preserved exactly. When the argument is `null`,
the resolver uses the INI setting, environment, and effective-user rules
documented in the main README. Resolution does not require the directory to
exist; getBibleSword emits a deterministic failed NDJSON stream if the path
cannot be opened.

### Metadata

```php
Engine::abiVersion(): int
Engine::productVersion(): string
Engine::contractIdentifier(): string
```

These return native library metadata with static lifetime. Extension startup
fails if the embedded ABI version is not `1`.

This release reports product version `0.4.0`, ABI `1`, and contract identifier
`getbiblesword.ndjson/v1`. The product version identifies the embedded native
engine; it is separate from the `getbible/sword` extension package version.

### Path

```php
$engine->modulePath(): string
```

Returns the resolved module root owned by this engine object.

### Module listing

```php
$engine->streamModules(mixed $destination): int
```

`$destination` must be a writable PHP stream resource. The method calls
`gbs_list_modules_v1()` synchronously, writes each callback span completely, and
returns the number of bytes accepted by the stream.

Discovery includes Bibles, dictionaries/lexicons, commentaries, and other
supported installed SWORD modules. Read each module record's `classification`,
`sword_type`, and driver metadata before choosing an application data model.

### Module extraction

```php
$engine->streamModule(
    string $module,
    mixed $destination,
    int $artifactChunkSize = Engine::DEFAULT_ARTIFACT_CHUNK_SIZE
): int
```

The module name must be non-empty. The chunk size must be from `4096` through
`16777216` bytes. Chunk size controls getBibleSword artifact records, not the
size of PHP stream writes and not NDJSON record boundaries.

The same method exports an installed dictionary or commentary by its exact
module identifier. It emits the complete module, including configuration,
logical entries, physical artifacts, diagnostics, and footer. Entry scopes may
be `verse_key` or `sword_key`; preserve their exact keys and traversal order,
including duplicate logical keys. ABI v1 does not provide individual dictionary
key or Scripture reference lookup methods.

### Text projections in product 0.4.0

The PHP adapter forwards the native record unchanged. Entry records retain the
authoritative `raw` bytes, `rendered_default`, `stripped`, lossless annotation
segments, and ordered `official_attributes`. Product `0.4.0` also supplies:

| Member | Meaning |
|---|---|
| `normalized_raw` | Source markup decoded strictly to UTF-8 using the declared module encoding, or `null` when unavailable |
| `normalized_stripped` | SWORD's plain-text projection of `normalized_raw`, verified as UTF-8, or `null` when unavailable |

These members are optional within contract v1, so readers must also accept
their absence in earlier exports. A non-null `normalized_stripped` requires a
non-null `normalized_raw`. Each non-null value uses the usual byte envelope:
verify canonical Base64, size, SHA-256, optional `utf8` equality, and strict UTF-8.
The normalized fields are already decoded; applying the module's source encoding
again corrupts their interpretation. They do not apply Unicode normalization or
infer an undeclared encoding.

Prefer these fields for semantic parsing while preserving the legacy fields
and artifacts. Unsupported or invalid source encodings can produce
`entry.encoding.unavailable`; an embedded NUL can leave `normalized_raw` intact
but make `normalized_stripped` null with `entry.encoding.embedded_nul`. Invalid
UTF-8 produced by SWORD's stripping filter yields a null `normalized_stripped`
and `entry.normalized_stripped.invalid_utf8`. Retain these warnings with the
entry. A null projection does not mean the original entry is absent.

Consumers must validate the complete stream, including its footer and digest,
before activating downstream state. The normative semantics are documented in
the upstream [contract v1](https://github.com/getbible/getbiblesword/blob/v0.4.0/docs/contract-v1.md)
and [downstream integration guide](https://github.com/getbible/getbiblesword/blob/v0.4.0/docs/downstream-integration.md).

## Exceptions

Native failures throw `GetBible\Sword\Exception`, which extends
`RuntimeException`. Its integer code maps directly to C ABI status:

| Code | Native status | Meaning |
|---:|---|---|
| `1` | `GBS_STATUS_INVALID_ARGUMENT` | ABI or native input was invalid |
| `2` | `GBS_STATUS_EXTRACTION_FAILED` | A complete `success:false` footer was emitted |
| `3` | `GBS_STATUS_WRITE_FAILED` | The PHP destination refused output |
| `4` | `GBS_STATUS_CANCELLED` | The native callback operation was cancelled |
| `255` | `GBS_STATUS_INTERNAL_ERROR` | A contained native failure occurred |

PHP signature and range violations use normal `TypeError` or `ValueError`.

An extraction failure can still produce a complete NDJSON stream. Applications
should inspect or retain that stream for diagnostics even when the method
throws.

## Concurrency

Engine objects hold only an immutable module-path string. They are safe in NTS
and ZTS builds. getBibleSword ABI v1 serializes SWORD operations within one
process; separate PHP-FPM workers remain independent.

Do not modify, install, replace, or remove module data while any engine call is
reading the same root.
