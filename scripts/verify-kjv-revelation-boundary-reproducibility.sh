#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

readonly required_runs=5
if (($# != required_runs)); then
    echo "Usage: $0 RUN_1_DIRECTORY ... RUN_5_DIRECTORY" >&2
    exit 2
fi

readonly chapters=(1 22)
readonly reference_directory=$1
artifact_files=()
for chapter in "${chapters[@]}"; do
    artifact_files+=(
        "kjv-revelation-${chapter}.entries.ndjson"
        "kjv-revelation-${chapter}.txt"
        "kjv-revelation-${chapter}.manifest.json"
    )
done
readonly artifact_files

for command in cmp jq sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required reproducibility command is unavailable: $command" >&2
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

validate_run() {
    local directory=$1
    local run_number=$2
    local chapter verses artifact_prefix entries_file text_file manifest_file
    local manifest reference

    for file in "${artifact_files[@]}"; do
        if [[ ! -f "$directory/$file" ]]; then
            echo "Reproducibility run $run_number is missing $file." >&2
            return 1
        fi
    done

    for chapter in "${chapters[@]}"; do
        verses="$(expected_verses "$chapter")"
        artifact_prefix="kjv-revelation-${chapter}"
        entries_file="${artifact_prefix}.entries.ndjson"
        text_file="${artifact_prefix}.txt"
        manifest_file="${artifact_prefix}.manifest.json"
        manifest="$directory/$manifest_file"
        reference="Revelation ${chapter}"

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
            echo "Run $run_number has an invalid $reference manifest." >&2
            return 1
        fi

        (
            cd "$directory"
            jq --raw-output \
                '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
                "$manifest_file" \
                | sha256sum --check --strict
        )
    done
}

compare_run() {
    local directory=$1
    local run_number=$2
    local file expected_sha actual_sha difference

    for file in "${artifact_files[@]}"; do
        if cmp --silent \
            "$reference_directory/$file" \
            "$directory/$file"; then
            continue
        fi

        expected_sha="$(
            sha256sum "$reference_directory/$file" | cut -d' ' -f1
        )"
        actual_sha="$(sha256sum "$directory/$file" | cut -d' ' -f1)"
        difference="$(
            cmp "$reference_directory/$file" "$directory/$file" 2>&1 || true
        )"
        {
            printf 'Reproducibility run %d differs: %s\n' \
                "$run_number" \
                "$file"
            printf '  run 1 SHA-256: %s\n' "$expected_sha"
            printf '  run %d SHA-256: %s\n' "$run_number" "$actual_sha"
            printf '  first difference: %s\n' "$difference"
        } >&2
        return 1
    done
}

run_number=0
for directory in "$@"; do
    ((run_number += 1))
    validate_run "$directory" "$run_number"
    if ((run_number > 1)); then
        compare_run "$directory" "$run_number"
    fi
done

printf 'Five-run KJV Revelation self-replay reproducibility confirmed.\n'
for chapter in "${chapters[@]}"; do
    artifact_prefix="kjv-revelation-${chapter}"
    entries_sha256="$(
        sha256sum "$reference_directory/${artifact_prefix}.entries.ndjson" \
            | cut -d' ' -f1
    )"
    text_sha256="$(
        sha256sum "$reference_directory/${artifact_prefix}.txt" \
            | cut -d' ' -f1
    )"
    printf '  Revelation %d entries SHA-256: %s\n' \
        "$chapter" \
        "$entries_sha256"
    printf '  Revelation %d text SHA-256:    %s\n' \
        "$chapter" \
        "$text_sha256"
done
printf '  Fixture: approved committed baseline replay (network-free)\n'
