#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# != 1)); then
    echo "Usage: $0 OUTPUT_SWORD_ROOT" >&2
    exit 2
fi

readonly output_root=$1
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly imp2vs="$repository_root/.getbiblesword/sword-1.9.0/bin/imp2vs"
readonly imp2ld="$repository_root/.getbiblesword/sword-1.9.0/bin/imp2ld"
readonly fixture_source="$repository_root/tests/fixtures"

if [[ -e "$output_root" ]]; then
    echo "Fixture output already exists: $output_root" >&2
    exit 2
fi
for utility in "$imp2vs" "$imp2ld"; do
    if [[ ! -x "$utility" ]]; then
        echo "SWORD fixture utility is unavailable: $utility" >&2
        exit 2
    fi
done

temporary_root="$(mktemp -d)"
readonly temporary_root
cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

mkdir -p -- \
    "$output_root/mods.d" \
    "$output_root/modules/texts/rawtext/phpfixture" \
    "$output_root/modules/comments/rawcom/phpcommentary" \
    "$output_root/modules/lexdict/rawld/phpdictionary" \
    "$output_root/modules/lexdict/rawld/phplatin1" \
    "$output_root/modules/lexdict/rawld/phpinvalidutf8"

"$imp2vs" "$fixture_source/verse.imp" \
    -o "$output_root/modules/texts/rawtext/phpfixture" >/dev/null
# RawCom and RawText use the same verse storage format. As in the upstream
# conformance corpus, imp2vs creates the bytes read by the RawCom driver.
"$imp2vs" "$fixture_source/commentary.imp" \
    -o "$output_root/modules/comments/rawcom/phpcommentary" >/dev/null
"$imp2ld" "$fixture_source/dictionary.imp" \
    -o "$output_root/modules/lexdict/rawld/phpdictionary/data" >/dev/null

# Keep reviewable UTF-8 fixture sources in Git, then encode the actual SWORD
# input explicitly so the test exercises real legacy and malformed bytes.
python3 - "$fixture_source/latin1.imp" "$temporary_root" <<'PY'
from pathlib import Path
import sys

source, destination = map(Path, sys.argv[1:])
(destination / "latin1.imp").write_bytes(source.read_text(encoding="utf-8").encode("latin-1"))
(destination / "invalid-utf8.imp").write_bytes(
    b"$$$ALPHA\nInvalid UTF-8: \xff.\n$$$BETA\nA clean second entry.\n"
)
PY
"$imp2ld" "$temporary_root/latin1.imp" \
    -o "$output_root/modules/lexdict/rawld/phplatin1/data" >/dev/null
"$imp2ld" "$temporary_root/invalid-utf8.imp" \
    -o "$output_root/modules/lexdict/rawld/phpinvalidutf8/data" >/dev/null
cp -- "$fixture_source/modules.conf" "$output_root/mods.d/phpfixtures.conf"
