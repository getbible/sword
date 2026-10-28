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
readonly php_output="$temporary_root/php"
readonly validator="$repository_root/vendor/getbiblesword/tools/getbiblesword_v1.py"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

if [[ ! -f "$extension" ]]; then
    echo "Built PHP extension not found: $extension" >&2
    exit 1
fi

"$repository_root/scripts/create-fixture.sh" "$fixture_root"
mkdir -p -- "$php_output"

php \
    -n \
    -d "extension=$extension" \
    "$repository_root/tests/integration.php" \
    "$fixture_root" \
    "$php_output"

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
cmp "$temporary_root/cli-list.ndjson" "$php_output/list-1.ndjson"
cmp "$php_output/list-1.ndjson" "$php_output/list-2.ndjson"
python3 "$validator" validate "$php_output/list-1.ndjson" >/dev/null

for module in PhpFixture PhpCommentary PhpDictionary PhpLatin1 PhpInvalidUTF8; do
    "$cli_build/getbiblesword" extract \
        --sword-path "$fixture_root" \
        --module "$module" \
        --artifact-chunk-size 4096 \
        > "$temporary_root/cli-$module.ndjson"
    cmp "$temporary_root/cli-$module.ndjson" "$php_output/$module-1.ndjson"
    cmp "$php_output/$module-1.ndjson" "$php_output/$module-2.ndjson"
    python3 "$validator" validate "$php_output/$module-1.ndjson" >/dev/null
done

if ldd "$extension" \
    | grep -E 'lib(getbible)?sword[^[:space:]]*\.so' >/dev/null; then
    echo "The PHP extension unexpectedly depends on a SWORD shared library." >&2
    ldd "$extension" >&2
    exit 1
fi
if ! nm -D --defined-only "$extension" | grep -E '[[:space:]]get_module$' >/dev/null; then
    echo "The PHP module entry point is not exported." >&2
    exit 1
fi

printf 'Bible, commentary and dictionary integration, validation, CLI parity, and dependency-boundary checks passed.\n'
