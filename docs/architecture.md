# Architecture

```text
PHP application
└── getbiblesword.so
    ├── PHP stream/object adapter
    ├── getBibleSword C ABI v1
    ├── getBibleSword extraction core 0.4.0
    └── PIC-static CrossWire SWORD 1.9.0

External data
└── SWORD modules
```

The PHP adapter depends only on the public C header. It passes an explicit module
root, extraction options, and a synchronous write callback. C++, STL, and SWORD
types never cross into Zend code.

## Stability boundaries

- PIE package: `getbible/sword`
- PHP extension: `getbiblesword`
- PHP namespace: `GetBible\Sword`
- native engine: getBibleSword `0.4.0`
- native ABI: `1`
- data contract: `getbiblesword.ndjson/v1`
- SWORD engine: `1.9.0`

The CLI and PHP extension compile the same getBibleSword sources. CI builds a
real SWORD fixture and requires byte-for-byte equality between CLI and PHP list
and extract streams.

## Module and text boundaries

The adapter streams all supported installed SWORD module types, including
Bibles, dictionaries/lexicons, and commentaries. It does not reinterpret generic
keys as verse coordinates or collapse duplicate entry keys. Module-aware lookup,
indexes, and domain objects belong in the consuming application.

getBibleSword `0.4.0` adds optional `normalized_raw` and `normalized_stripped`
UTF-8 byte envelopes to entry records and corrects official attribute extraction
for the current entry. The native ABI and NDJSON contract remain version 1.
Original `raw`, `rendered_default`, and `stripped` fields retain their existing
meaning; consumers must handle missing or null normalized values and retain
encoding diagnostics. The Zend adapter passes the complete stream through
unchanged.

ICU supplies strict source-encoding conversion. Its development package and
`icu-uc` pkg-config metadata are build requirements. Static linkage of SWORD and
getBibleSword does not imply static linkage of ICU or other platform libraries;
deployment hosts must provide the shared libraries recorded by `ldd`.

Persisted exports are producer-specific immutable data. After deploying an
upgraded extension, restart long-running PHP workers and explicitly regenerate
application snapshots and derived caches. An application should validate the
replacement generation before switching readers to it.

## Memory ownership

- PHP owns the Engine object and its `zend_string` module path.
- PHP owns the destination stream resource.
- getBibleSword borrows the path and module-name pointers only for the
  synchronous call.
- Callback byte spans are borrowed and written before the callback returns.
- No callback pointer or PHP stream pointer is retained by native code.

## Failure containment

getBibleSword catches all C++ exceptions at the C boundary. The PHP adapter does
not use C++ exceptions. It converts the returned status and bounded native error
message into a PHP exception after the callback stack has unwound.

Native code still shares the PHP process. A segmentation fault or other
memory-safety failure cannot be converted into a PHP exception.

## Packaging

Git stores the extension source and immutable dependency metadata. A release
pipeline creates `php_getbiblesword-vVERSION-src.tgz` containing verified
copies of getBibleSword and SWORD. The leading `v` matches the Composer pretty
version PIE uses for release-asset discovery. PIE uses that pre-packaged source
archive, builds the engine statically, and installs one PHP extension module.

This design avoids:

- selecting an arbitrary system `libsword`;
- requiring `libgetbiblesword.so` at runtime;
- a post-install module library in a nonstandard filesystem location; and
- downloading native source from an undeclared revision during `pie install`.
