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
readonly chapters=(1 22)

for command in cmp diff jq sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required baseline command is unavailable: $command" >&2
        exit 1
    fi
done

expected_verses() {
    local chapter=$1
    case "$chapter" in
        1)
            printf '20\n'
            ;;
        22)
            printf '21\n'
            ;;
        *)
            echo "Unsupported Revelation boundary chapter: $chapter" >&2
            return 1
            ;;
    esac
}

verify_artifact() {
    local directory=$1
    local label=$2
    local chapter=$3
    local verses=$4
    local artifact_prefix="kjv-revelation-${chapter}"
    local entries_file="${artifact_prefix}.entries.ndjson"
    local text_file="${artifact_prefix}.txt"
    local manifest_file="${artifact_prefix}.manifest.json"
    local manifest="$directory/$manifest_file"
    local reference="Revelation ${chapter}"

    for file in "$entries_file" "$text_file" "$manifest_file"; do
        if [[ ! -f "$directory/$file" ]]; then
            echo "$label artifact is missing $file." >&2
            return 1
        fi
    done

    if ! jq \
        --exit-status \
        --arg entries_file "$entries_file" \
        --arg reference "$reference" \
        --arg text_file "$text_file" \
        --argjson chapter "$chapter" \
        --argjson verses "$verses" \
        '
            .artifact_format == "getbible/sword-release-evidence/v1"
            and .module == "KJV"
            and .reference == $reference
            and .canonical_book == 66
            and .testament == 2
            and .testament_book == 27
            and .chapter == $chapter
            and .verses == $verses
            and .contract == "getbiblesword.ndjson/v1"
            and .whole_contract_stream == false
            and .entries_file == $entries_file
            and .text_file == $text_file
        ' \
        "$manifest" >/dev/null; then
        echo "$label manifest does not describe KJV $reference." >&2
        return 1
    fi

    (
        cd "$directory"
        jq --raw-output \
            '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
            "$manifest_file" \
            | sha256sum --check --strict
    )
}

compare_metadata() {
    local baseline_directory=$1
    local chapter=$2
    local artifact_prefix="kjv-revelation-${chapter}"
    local manifest_file="${artifact_prefix}.manifest.json"
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
        echo "Generated Revelation $chapter metadata differs from the baseline." \
            >&2
        return 1
    fi
}

compare_file() {
    local baseline_directory=$1
    local file=$2
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

    if [[ "$file" == *.txt ]]; then
        diff --unified "$expected" "$actual" >&2 || true
    fi
    return 1
}

for chapter in "${chapters[@]}"; do
    verses="$(expected_verses "$chapter")"
    baseline_directory="$(
        printf '%s/tests/baselines/kjv-revelation-%s' \
            "$repository_root" \
            "$chapter"
    )"
    artifact_prefix="kjv-revelation-${chapter}"
    entries_file="${artifact_prefix}.entries.ndjson"
    text_file="${artifact_prefix}.txt"
    manifest_file="${artifact_prefix}.manifest.json"

    verify_artifact \
        "$baseline_directory" \
        "Approved Revelation $chapter baseline" \
        "$chapter" \
        "$verses"
    verify_artifact \
        "$generated_directory" \
        "Generated Revelation $chapter" \
        "$chapter" \
        "$verses"
    compare_metadata "$baseline_directory" "$chapter"
    compare_file "$baseline_directory" "$entries_file"
    compare_file "$baseline_directory" "$text_file"

    baseline_source_sha="$(
        jq --raw-output '.source_sha256' \
            "$baseline_directory/$manifest_file"
    )"
    generated_source_sha="$(
        jq --raw-output '.source_sha256' \
            "$generated_directory/$manifest_file"
    )"
    if [[ "$baseline_source_sha" != "$generated_source_sha" ]]; then
        {
            printf 'NOTICE: CrossWire repackaged or changed KJV.zip, but\n'
            printf 'the generated Revelation %d output still matches.\n' \
                "$chapter"
            printf '  baseline source SHA-256: %s\n' "$baseline_source_sha"
            printf '  current source SHA-256:  %s\n' "$generated_source_sha"
        } >&2
    fi
done

echo 'KJV Revelation 1 and 22 match the approved getbible/sword baselines.'
