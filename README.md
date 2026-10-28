# getBible SWORD for PHP

[![CI](https://github.com/getbible/sword/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/getbible/sword/actions/workflows/ci.yml)
[![Golden](https://github.com/getbible/sword/actions/workflows/golden-baseline.yml/badge.svg?branch=main)](https://github.com/getbible/sword/actions/workflows/golden-baseline.yml)
[![CodeQL](https://github.com/getbible/sword/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/getbible/sword/actions/workflows/codeql.yml)
[![Release](https://github.com/getbible/sword/actions/workflows/release.yml/badge.svg)](https://github.com/getbible/sword/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/getbible/sword?display_name=tag&sort=semver&label=version)](https://github.com/getbible/sword/releases/latest)
[![License](https://img.shields.io/badge/license-GPL--2.0--only-blue.svg)](LICENSE)

`getbible/sword` is the native PHP extension for
[getBibleSword](https://github.com/getbible/getbiblesword). It exposes the
released getBibleSword `0.4.0` C ABI to PHP without starting a subprocess and
without requiring a system installation of `libsword`, `diatheke`, or the
`getbiblesword` executable.

The package is designed for installation through the official
[PHP Installer for Extensions (PIE)](https://github.com/php/pie):

```bash
pie install getbible/sword
```

PIE installs the published source package and builds the extension for the local
PHP runtime. See [Packagist setup](docs/packagist.md) for package registration and
release synchronization.

## Runtime model

The extension embeds:

- getBibleSword `0.4.0`;
- getBibleSword C ABI version `1`;
- CrossWire SWORD `1.9.0`; and
- the `getbiblesword.ndjson/v1` output contract.

The resulting `getbiblesword.so` PHP module does not dynamically depend on
`libsword.so` or `libgetbiblesword.so`. Bible translations, commentaries,
dictionaries, and other SWORD modules remain external data.

Version `0.4.0` adds strict UTF-8 `normalized_raw` and `normalized_stripped`
entry projections and corrects current-entry official attribute extraction.
The original raw bytes, rendered views, lexical annotations, and artifacts
remain available. These improvements use the existing ABI and stream contract;
the PHP method signatures are unchanged.

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
getBibleSword `0.4.0` CLI. They return the accepted byte count and throw
`GetBible\Sword\Exception` when the C ABI reports an extraction, write,
cancellation, argument, or internal error. The exception code is the underlying
`gbs_status` value.

Metadata is available without constructing an engine:

```php
Engine::abiVersion();         // 1
Engine::productVersion();     // "0.4.0"
Engine::contractIdentifier(); // "getbiblesword.ndjson/v1"
```

See [docs/php-api.md](docs/php-api.md) for the complete interface and error
contract.

### Dictionaries and commentaries

`streamModules()` lists installed modules of every supported SWORD type.
`streamModule()` accepts an installed Bible, dictionary/lexicon, or commentary
module identifier and exports its complete data through the same streaming API.
Use the module record's `classification`, authoritative `sword_type`, and driver
metadata to identify its kind. Preserve entry keys, scopes, traversal order,
and duplicate logical keys; dictionary entries do not have to be Bible verses.

For text processing, prefer the optional normalized projections when present
and non-null. They already contain strict UTF-8 and must not be decoded again
using the module's source encoding. Retain original bytes and diagnostics when
a normalized projection is unavailable. Direct key or reference lookup and
application-level dictionary/commentary objects belong above this export API.

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
C ABI functions and remain outside the released native library's capabilities.

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
    libtool pkg-config python3 zlib1g-dev
```

PIE can detect many missing build tools, but not every native SWORD dependency.
ICU development headers and libraries are required for getBibleSword's strict
encoding conversion; `pkg-config` must resolve `icu-uc`. The extension statically
embeds SWORD and getBibleSword, but may dynamically link ICU and other platform
libraries. Keep the linked runtime libraries installed on deployment hosts.

## Upgrading an existing installation

Install the new extension for each PHP runtime used by the application, then
restart PHP-FPM and other long-running PHP workers so they load the new native
code. Verify `Engine::productVersion()` reports `0.4.0` in the serving runtime.

Force a server-side refresh of persisted module exports, snapshots, and any
derived application caches using that application's supported refresh operation.
Existing immutable exports retain their previous producer's data until they are
regenerated; replacing the extension alone does not add normalized projections
or corrected attributes to those files. Preserve the previous active snapshot
until its replacement has passed complete stream validation.

## Source layout

The extension source is not missing: PHP extensions traditionally keep
`config.m4`, their primary C file, public header, stub, and generated arginfo in
the repository root. In this repository:

| Path | Purpose |
|---|---|
| `getbiblesword.c` | Zend/PHP stream and object adapter |
| `php_getbiblesword.h` | Extension identity and module declaration |
| `getbiblesword.stub.php` | Canonical PHP API signatures |
| `getbiblesword_arginfo.h` | Generated Zend argument metadata |
| `config.m4` | phpize/PIE native build definition |
| `vendor/getbiblesword/` | Verified native engine source, created while packaging |
| `vendor/sword-1.9.0.tar.gz` | Verified SWORD source, created while packaging |

The large native dependencies are deliberately not duplicated in Git. The
release source archive vendors and verifies them before PIE receives the
package. The complete map is in
[docs/repository-layout.md](docs/repository-layout.md).

## Dependency integrity

Release source packages vendor, rather than dynamically select:

| Dependency | Pin | Verification |
|---|---|---|
| getBibleSword | `v0.4.0` / `f5115c5a3a3162471af3f7341b0a4265bdfecae0` | Exact Git commit |
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
5. creates real Bible, commentary, and dictionary fixtures, including repeated
   keys and valid and malformed non-ASCII source text;
6. independently validates streams and compares CLI and PHP output byte-for-byte; and
7. verifies that the extension has no SWORD shared-library dependency.

To build the current branch through PIE before a release:

```bash
pie repository:add vcs https://github.com/getbible/sword
pie build 'getbible/sword:dev-main'
```

## Golden release evidence

Every pull request builds the extension and validates deterministic local
Public Domain SWORD fixtures. PHP 8.4 NTS CI, the scheduled golden-baseline
workflow, and every release also rebuild a local KJV module from approved raw
entry bytes. They stream it through `GetBible\Sword\Engine` and select all 20
verses of Revelation 1 and all 21 verses of Revelation 22. This evidence path
requires no module downloads.

The workflow compares both chapters' newly generated entry records and readable
text with the maintainer-approved historical output committed
under `tests/baselines/kjv-revelation-1/` and
`tests/baselines/kjv-revelation-22/`. It fails before publication on any output
change except full-stream position fields `sequence` and `ordinal`, prints
every verse, and publishes:

- two exact selected NDJSON entry-record files;
- two human-readable chapter-text files; and
- two manifests containing engine, ABI, contract, local replay provenance, and
  artifact hashes.

The PHP 8.4 NTS PR job also requires five byte-identical extraction runs and
retains their reproducibility report with the golden evidence.

PR artifacts remain downloadable even when the comparison fails, making an
unexpected result inspectable without weakening the golden baselines.

The separate **Golden Baseline** workflow runs after each `main` update, daily,
and on demand. If its strict comparison fails, **Golden Baseline Recovery**
performs five independent local fixture builds and extension extractions. It proceeds
only when all six generated files match byte-for-byte across all five runs. A
stable changed result is proposed on an `automation/kjv-golden-*` branch in a
normal pull request. It is never written directly to `main`; a maintainer must
inspect and merge the PR before the candidate becomes the approved baseline.
Unstable output, build failures, and results that still match the current
baseline create no PR.

## Releasing

Running the **Release** workflow is sufficient. Its default `auto` mode releases
an untagged `VERSION`, or derives the next semantic version from changes since
the latest release:

- `BREAKING CHANGE:` or a conventional `!` commit selects `major`;
- `feat:` selects `minor`;
- all other changes select `patch`.

The workflow updates `VERSION` and `CHANGELOG.md`, commits when necessary,
creates the annotated version tag, builds and verifies the PIE source package,
creates the KJV evidence artifact, and publishes the GitHub release. A manually
pushed matching `vX.Y.Z` tag follows the same build, evidence, and publication
path. See [docs/releasing.md](docs/releasing.md).

## Documentation

| Document | Purpose |
|---|---|
| [PHP API](docs/php-api.md) | Complete public PHP interface and errors |
| [Architecture](docs/architecture.md) | Native, Zend, trust, and packaging boundaries |
| [Repository layout](docs/repository-layout.md) | Location and origin of every source layer |
| [Packagist setup](docs/packagist.md) | One-time package registration and synchronization |
| [Releasing](docs/releasing.md) | Automated and tag-driven release operations |
| [AI summary](llms.txt) | Compact machine-oriented capability map |

## Security

SWORD parsing occurs in the PHP process. A native memory-safety defect can
terminate the PHP CLI or FPM worker, unlike the existing standalone-CLI
subprocess boundary. Treat module data as untrusted, validate completed NDJSON
before committing downstream state, and review [SECURITY.md](SECURITY.md) and
[docs/architecture.md](docs/architecture.md) before production deployment.

## License

GPL-2.0-only. The extension statically links GPL-2.0-only getBibleSword and
CrossWire SWORD code.
