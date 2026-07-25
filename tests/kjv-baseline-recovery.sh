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

run_directories=()
for run_number in 1 2 3 4 5; do
    run_directory="$temporary_root/run-$run_number"
    mkdir -p -- "$run_directory"
    for chapter in 1 22; do
        cp \
            "$repository_root/tests/baselines/kjv-revelation-${chapter}"/* \
            "$run_directory/"
    done
    run_directories+=("$run_directory")
done

bash \
    "$repository_root/scripts/verify-kjv-revelation-boundary-reproducibility.sh" \
    "${run_directories[@]}" >/dev/null

changed_run="${run_directories[4]}"
printf '\n' >> "$changed_run/kjv-revelation-22.entries.ndjson"
changed_sha="$(
    sha256sum "$changed_run/kjv-revelation-22.entries.ndjson" \
        | cut -d' ' -f1
)"
jq \
    --arg changed_sha "$changed_sha" \
    '.entries_sha256 = $changed_sha' \
    "$changed_run/kjv-revelation-22.manifest.json" \
    > "$changed_run/manifest.updated.json"
mv \
    "$changed_run/manifest.updated.json" \
    "$changed_run/kjv-revelation-22.manifest.json"

if bash \
    "$repository_root/scripts/verify-kjv-revelation-boundary-reproducibility.sh" \
    "${run_directories[@]}" >/dev/null 2>&1; then
    echo 'Five-run verification accepted inconsistent generated output.' >&2
    exit 1
fi

echo 'KJV Revelation boundary recovery tests passed.'
