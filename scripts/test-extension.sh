#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly extension="$repository_root/modules/getbiblesword.so"
readonly sword_prefix="$repository_root/.getbiblesword/sword-1.9.0"
temporary_root="$(mktemp -d)"
readonly temporary_root
readonly fixture_root="$temporary_root/sword"
readonly cli_build="$temporary_root/getbiblesword-cli"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

if [[ ! -f "$extension" ]]; then
    echo "Built PHP extension not found: $extension" >&2
    exit 1
fi

"$repository_root/scripts/create-fixture.sh" "$fixture_root"

php \
    -n \
    -d "extension=$extension" \
    "$repository_root/tests/integration.php" \
    "$fixture_root" \
    "$temporary_root/php-list.ndjson" \
    "$temporary_root/php-extract.ndjson"

PKG_CONFIG_PATH="$sword_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
    cmake \
        -S "$repository_root/vendor/getbiblesword" \
        -B "$cli_build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DGETBIBLESWORD_BUILD_SHARED_LIBRARY=OFF \
        -DGETBIBLESWORD_SWORD_PROVIDER=BUNDLED
cmake --build "$cli_build" --parallel

"$cli_build/getbiblesword" list \
    --sword-path "$fixture_root" \
    > "$temporary_root/cli-list.ndjson"
"$cli_build/getbiblesword" extract \
    --sword-path "$fixture_root" \
    --module PhpFixture \
    --artifact-chunk-size 4096 \
    > "$temporary_root/cli-extract.ndjson"

cmp "$temporary_root/cli-list.ndjson" "$temporary_root/php-list.ndjson"
cmp "$temporary_root/cli-extract.ndjson" "$temporary_root/php-extract.ndjson"

if ldd "$extension" | grep -E 'lib(getbible)?sword\.so' >/dev/null; then
    echo "The PHP extension unexpectedly depends on a SWORD shared library." >&2
    ldd "$extension" >&2
    exit 1
fi
if ! nm -D --defined-only "$extension" | grep -E '[[:space:]]get_module$' >/dev/null; then
    echo "The PHP module entry point is not exported." >&2
    exit 1
fi

printf 'Extension integration, CLI parity, and dependency-boundary checks passed.\n'
