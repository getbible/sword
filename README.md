# getBible SWORD for PHP

`getbible/sword` is the native PHP extension for
[getBibleSword](https://github.com/getbible/getbiblesword). It exposes the
released getBibleSword `0.3.0` C ABI to PHP without starting a subprocess and
without requiring a system installation of `libsword`, `diatheke`, or the
`getbiblesword` executable.

The package is designed for installation through the official
[PHP Installer for Extensions (PIE)](https://github.com/php/pie):

```bash
pie install getbible/sword
```

This repository is currently preparing its first release. Until `v0.1.0` is
tagged and registered on Packagist, build the implementation branch directly as
described in [Development](#development).

## Runtime model

The extension embeds:

- getBibleSword `0.3.0`;
- getBibleSword C ABI version `1`;
- CrossWire SWORD `1.9.0`; and
- the `getbiblesword.ndjson/v1` output contract.

The resulting `getbiblesword.so` PHP module does not dynamically depend on
`libsword.so` or `libgetbiblesword.so`. Bible translations, commentaries,
dictionaries, and other SWORD modules remain external data.

## PHP API

The API is intentionally streamed. A full Bible is never concatenated into one
PHP string.

```php
<?php

declare(strict_types=1);

use GetBible\Sword\Engine;

$engine = new Engine('/var/lib/getbiblesword/sword');

$list = fopen('/tmp/modules.ndjson', 'wb');
$listBytes = $engine->streamModules($list);
fclose($list);

$output = fopen('/tmp/kjv.ndjson', 'wb');
$extractBytes = $engine->streamModule(
    module: 'KJV',
    destination: $output,
    artifactChunkSize: Engine::DEFAULT_ARTIFACT_CHUNK_SIZE
);
fclose($output);
```

Both methods write the exact NDJSON bytes emitted by the standalone
getBibleSword `0.3.0` CLI. They return the accepted byte count and throw
`GetBible\Sword\Exception` when the C ABI reports an extraction, write,
cancellation, argument, or internal error. The exception code is the underlying
`gbs_status` value.

Metadata is available without constructing an engine:

```php
Engine::abiVersion();         // 1
Engine::productVersion();     // "0.3.0"
Engine::contractIdentifier(); // "getbiblesword.ndjson/v1"
```

See [docs/php-api.md](docs/php-api.md) for the complete interface and error
contract.

## Module-path resolution

`new Engine()` resolves its module root in this order:

1. the path passed to the constructor;
2. the `getbiblesword.module_path` PHP INI setting;
3. the `SWORD_PATH` environment variable;
4. `$HOME/.sword`; or
5. the effective operating-system user's home directory plus `/.sword`.

For PHP-FPM, configure a stable application-owned path:

```ini
getbiblesword.module_path=/var/lib/getbiblesword/sword
```

The executing user needs read access to installed module data. ABI v1 does not
install missing modules or perform network operations. Automatic repository
installation and direct verse/reference queries require additive getBibleSword
C ABI functions and are tracked as follow-up work; this initial package does not
claim behavior the released native library does not provide.

## Supported platforms

- Linux on `x86_64` and `arm64`
- PHP `8.2`, `8.3`, `8.4`, and `8.5`
- non-thread-safe and Zend thread-safe PHP builds

PIE source packages include the exact native sources. A source build requires a
C/C++ build toolchain, PHP development tools, `pkg-config`, Autotools, CMake,
and the development packages used by SWORD. On Debian or Ubuntu:

```bash
sudo apt-get install \
    autoconf automake binutils build-essential cmake curl git \
    libbz2-dev libcurl4-openssl-dev libicu-dev liblzma-dev \
    libtool pkg-config zlib1g-dev
```

PIE can detect many missing build tools, but not every native SWORD dependency.

## Dependency integrity

Release source packages vendor, rather than dynamically select:

| Dependency | Pin | Verification |
|---|---|---|
| getBibleSword | `v0.3.0` / `c52003438dc7e3d5bab0d6680372b1de8a0077ce` | Exact Git commit |
| CrossWire SWORD | `1.9.0` | SHA-256 `42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a` |

Official builds never fall back to an ambient `libsword`.

## Development

Install the dependencies shown above, clone the repository, and run:

```bash
./scripts/build-extension.sh
```

The script:

1. verifies and vendors the two pinned sources;
2. builds SWORD as a PIC static library;
3. builds the PHP extension with `phpize`;
4. runs PHPT tests;
5. creates a real SWORD module fixture;
6. compares CLI and PHP output byte-for-byte; and
7. verifies that the extension has no SWORD shared-library dependency.

To exercise the branch through PIE before the first release:

```bash
pie repository:add vcs https://github.com/getbible/sword
pie build 'getbible/sword:dev-agent/pie-extension'
```

The repository is private at the time of initial implementation. It must be
made public, or published through a private Composer repository, before normal
Packagist installation can work.

## Security

SWORD parsing occurs in the PHP process. A native memory-safety defect can
terminate the PHP CLI or FPM worker, unlike the existing standalone-CLI
subprocess boundary. Treat module data as untrusted, validate completed NDJSON
before committing downstream state, and review [SECURITY.md](SECURITY.md) and
[docs/architecture.md](docs/architecture.md) before production deployment.

## License

GPL-2.0-only. The extension statically links GPL-2.0-only getBibleSword and
CrossWire SWORD code.
