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
            .artifact_format == "getbible/sword-release-evidence/v2"
            and .module == "KJV"
            and .reference == $reference
            and .canonical_book == 66
            and .testament == 2
            and .testament_book == 27
            and .chapter == $chapter
            and .verses == $verses
            and (.engine_version | type == "string" and length > 0)
            and .abi_version == 1
            and .contract == "getbiblesword.ndjson/v1"
            and .whole_contract_stream == false
            and .entries_file == $entries_file
            and (.entries_sha256 | test("^[0-9a-f]{64}$"))
            and .text_file == $text_file
            and (.text_sha256 | test("^[0-9a-f]{64}$"))
            and .fixture == {
                "kind": "approved-baseline-replay",
                "paths": [
                    "tests/baselines/kjv-revelation-1/kjv-revelation-1.entries.ndjson",
                    "tests/baselines/kjv-revelation-22/kjv-revelation-22.entries.ndjson"
                ]
            }
        ' \
        "$manifest" >/dev/null; then
        echo "$label manifest does not describe the local KJV $reference replay." >&2
        return 1
    fi

    if [[ "$(wc -l < "$directory/$entries_file")" -ne "$verses" ]] \
        || grep --quiet '^$' "$directory/$entries_file"; then
        echo "$label entries are not exactly $verses non-empty NDJSON lines." >&2
        return 1
    fi
    if ! jq \
        --slurp \
        --exit-status \
        --argjson chapter "$chapter" \
        --argjson verses "$verses" \
        '
            length == $verses
            and ([.[].scope.verse] == [range(1; $verses + 1)])
            and all(.[];
                .type == "entry"
                and .scope.type == "verse_key"
                and .scope.intro_scope == "verse"
                and .scope.testament == 2
                and .scope.book == 27
                and .scope.chapter == $chapter
            )
        ' \
        "$directory/$entries_file" >/dev/null; then
        echo "$label entries do not contain the complete Revelation $chapter scope." >&2
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
        engine_version,
        abi_version,
        contract,
        whole_contract_stream,
        entries_file,
        text_file,
        fixture
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

    if [[ "$file" == *.entries.ndjson ]]; then
        if cmp --silent \
            <(jq --compact-output --sort-keys 'del(.sequence, .ordinal)' "$expected") \
            <(jq --compact-output --sort-keys 'del(.sequence, .ordinal)' "$actual"); then
            printf 'Golden canonical match: %s (%s)\n' \
                "$file" \
                "$(
                    jq --compact-output --sort-keys \
                        'del(.sequence, .ordinal)' "$actual" \
                        | sha256sum | cut -d' ' -f1
                )"
            return 0
        fi

        expected_sha="$(
            jq --compact-output --sort-keys \
                'del(.sequence, .ordinal)' "$expected" \
                | sha256sum | cut -d' ' -f1
        )"
        actual_sha="$(
            jq --compact-output --sort-keys \
                'del(.sequence, .ordinal)' "$actual" \
                | sha256sum | cut -d' ' -f1
        )"
        difference='canonicalized NDJSON differs; see the unified diff below'
        {
            printf 'Golden baseline mismatch: %s\n' "$file"
            printf '  expected canonical SHA-256: %s\n' "$expected_sha"
            printf '  generated canonical SHA-256: %s\n' "$actual_sha"
            printf '  difference: %s\n' "$difference"
        } >&2
        diff --unified \
            <(jq --compact-output --sort-keys \
                'del(.sequence, .ordinal)' "$expected") \
            <(jq --compact-output --sort-keys \
                'del(.sequence, .ordinal)' "$actual") >&2 || true
        return 1
    fi

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
    diff --unified "$expected" "$actual" >&2 || true
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
done

echo 'KJV Revelation 1 and 22 match the approved self-replay baselines.'
