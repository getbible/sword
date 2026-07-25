#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
temporary_root="$(mktemp -d)"
readonly temporary_root

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

for chapter in 1 22; do
    cp \
        "$repository_root/tests/baselines/kjv-revelation-${chapter}"/* \
        "$temporary_root/"
done
bash "$repository_root/scripts/verify-kjv-revelation-boundary-baselines.sh" \
    "$temporary_root" >/dev/null

printf '\n' >> "$temporary_root/kjv-revelation-22.entries.ndjson"
changed_sha="$(
    sha256sum "$temporary_root/kjv-revelation-22.entries.ndjson" \
        | cut -d' ' -f1
)"
readonly changed_sha
jq \
    --arg changed_sha "$changed_sha" \
    '.entries_sha256 = $changed_sha' \
    "$temporary_root/kjv-revelation-22.manifest.json" \
    > "$temporary_root/manifest.updated.json"
mv \
    "$temporary_root/manifest.updated.json" \
    "$temporary_root/kjv-revelation-22.manifest.json"

if bash "$repository_root/scripts/verify-kjv-revelation-boundary-baselines.sh" \
    "$temporary_root" >/dev/null 2>&1; then
    echo 'The baseline verifier accepted changed NDJSON output.' >&2
    exit 1
fi

echo 'KJV Revelation boundary baseline-verifier tests passed.'
