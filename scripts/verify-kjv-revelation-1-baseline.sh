#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# != 1)); then
    echo "Usage: $0 GENERATED_DIRECTORY" >&2
    exit 2
fi

readonly generated_directory=$1
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly baseline_directory="$repository_root/tests/baselines/kjv-revelation-1"
readonly artifact_prefix='kjv-revelation-1'
readonly entries_file="${artifact_prefix}.entries.ndjson"
readonly text_file="${artifact_prefix}.txt"
readonly manifest_file="${artifact_prefix}.manifest.json"

for command in cmp diff jq sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required baseline command is unavailable: $command" >&2
        exit 1
    fi
done

verify_artifact() {
    local directory=$1
    local label=$2
    local manifest="$directory/$manifest_file"

    for file in "$entries_file" "$text_file" "$manifest_file"; do
        if [[ ! -f "$directory/$file" ]]; then
            echo "$label artifact is missing $file." >&2
            return 1
        fi
    done

    if ! jq --exit-status '
        .artifact_format == "getbible/sword-release-evidence/v1"
        and .module == "KJV"
        and .reference == "Revelation 1"
        and .canonical_book == 66
        and .testament == 2
        and .testament_book == 27
        and .chapter == 1
        and .verses == 20
        and .contract == "getbiblesword.ndjson/v1"
        and .whole_contract_stream == false
        and .entries_file == "kjv-revelation-1.entries.ndjson"
        and .text_file == "kjv-revelation-1.txt"
    ' "$manifest" >/dev/null; then
        echo "$label manifest does not describe KJV Revelation 1." >&2
        return 1
    fi

    (
        cd "$directory"
        sha256sum --check --strict <(
            jq --raw-output \
                '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
                "$manifest_file"
        )
    )
}

compare_metadata() {
    local baseline_manifest="$baseline_directory/$manifest_file"
    local generated_manifest="$generated_directory/$manifest_file"
    local metadata_filter='{
        artifact_format,
        module,
        reference,
        canonical_book,
        testament,
        testament_book,
        chapter,
        verses,
        abi_version,
        contract,
        whole_contract_stream,
        entries_file,
        text_file,
        source_url
    }'

    if ! diff --unified \
        <(jq --sort-keys "$metadata_filter" "$baseline_manifest") \
        <(jq --sort-keys "$metadata_filter" "$generated_manifest"); then
        echo 'Generated evidence metadata differs from the approved baseline.' >&2
        return 1
    fi
}

compare_file() {
    local file=$1
    local expected="$baseline_directory/$file"
    local actual="$generated_directory/$file"
    local expected_sha actual_sha difference

    if cmp --silent "$expected" "$actual"; then
        printf 'Golden baseline match: %s (%s)\n' \
            "$file" \
            "$(sha256sum "$actual" | cut -d' ' -f1)"
        return 0
    fi

    expected_sha="$(sha256sum "$expected" | cut -d' ' -f1)"
    actual_sha="$(sha256sum "$actual" | cut -d' ' -f1)"
    difference="$(cmp "$expected" "$actual" 2>&1 || true)"
    {
        printf 'Golden baseline mismatch: %s\n' "$file"
        printf '  expected SHA-256: %s\n' "$expected_sha"
        printf '  generated SHA-256: %s\n' "$actual_sha"
        printf '  first difference: %s\n' "$difference"
    } >&2

    if [[ "$file" == "$text_file" ]]; then
        diff --unified "$expected" "$actual" >&2 || true
    fi
    return 1
}

verify_artifact "$baseline_directory" 'Approved baseline'
verify_artifact "$generated_directory" 'Generated'
compare_metadata
compare_file "$entries_file"
compare_file "$text_file"

baseline_source_sha="$(
    jq --raw-output '.source_sha256' "$baseline_directory/$manifest_file"
)"
generated_source_sha="$(
    jq --raw-output '.source_sha256' "$generated_directory/$manifest_file"
)"
if [[ "$baseline_source_sha" != "$generated_source_sha" ]]; then
    {
        echo 'NOTICE: CrossWire repackaged or changed KJV.zip, but the'
        echo 'generated Revelation 1 output still matches the golden baseline.'
        printf '  baseline source SHA-256: %s\n' "$baseline_source_sha"
        printf '  current source SHA-256:  %s\n' "$generated_source_sha"
    } >&2
fi

echo 'KJV Revelation 1 matches the approved getbible/sword golden baseline.'
