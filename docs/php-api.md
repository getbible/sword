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
