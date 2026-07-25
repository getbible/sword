# Repository and source layout

## Why there is no top-level `src/` directory

This is a native PHP extension, not a PHP application or Composer library.
Established phpize extensions commonly keep their build definition and primary
Zend source files at the repository root. The source is therefore visible even
though it is not nested under `src/`.

## Committed source

| Path | Ownership | Purpose |
|---|---|---|
| `getbiblesword.c` | This repository | Zend objects, streams, path resolution, error conversion, module lifecycle |
| `php_getbiblesword.h` | This repository | Extension name, version macro, Zend module declaration |
| `getbiblesword.stub.php` | This repository | Canonical PHP signatures used to define the public API |
| `getbiblesword_arginfo.h` | Generated from the stub | Zend argument and method metadata |
| `config.m4` | This repository | phpize and PIE configure/build definition |
| `scripts/` | This repository | Dependency verification, build, test, package, evidence, and release preparation |
| `tests/` | This repository | PHPT tests, real-module fixture, PHP integration, and CLI parity |

`VERSION` is the single product-version authority. `config.m4` reads it during
configuration and defines `PHP_GETBIBLESWORD_VERSION`; the public header contains
only a development fallback. Packagist obtains published versions from Git tags.

## Generated or vendored source

The Git tree intentionally excludes two much larger upstream inputs:

| Generated path | Source authority | Integrity rule |
|---|---|---|
| `vendor/getbiblesword/` | `getbible/getbiblesword` tag `v0.3.0` | Must resolve to commit `c52003438dc7e3d5bab0d6680372b1de8a0077ce` |
| `vendor/sword-1.9.0.tar.gz` | CrossWire SWORD 1.9.0 source published with getBibleSword | Must match SHA-256 `42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a` |

`scripts/vendor-dependencies.sh` creates these paths for a development build.
`scripts/package-source.sh` runs the same verification inside a clean Git
archive and produces:

```text
php_getbiblesword-VERSION-src.tgz
```

That release archive contains all source required by PIE. It never selects an
ambient system SWORD library and does not download native source during the PIE
build.

## Built outputs

The local build creates:

```text
modules/getbiblesword.so
```

The module contains:

1. the root-level Zend adapter;
2. getBibleSword C ABI v1 and extraction core 0.3.0; and
3. PIC-static CrossWire SWORD 1.9.0.

`ldd modules/getbiblesword.so` must not report either `libsword.so` or
`libgetbiblesword.so`.
