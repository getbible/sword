#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# != 1)); then
    echo "Usage: $0 OUTPUT_DIRECTORY" >&2
    exit 2
fi

readonly output_directory=$1
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly extension="$repository_root/modules/getbiblesword.so"
readonly imp2vs="$repository_root/.getbiblesword/sword-1.9.0/bin/imp2vs"
readonly chapters=(1 22)
temporary_root="$(mktemp -d)"
readonly temporary_root
readonly module_root="$temporary_root/sword"
readonly data_root="$module_root/modules/texts/rawtext/kjv"
readonly fixture_imp="$temporary_root/kjv-revelation-boundaries.imp"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

for command in jq php sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required evidence command is unavailable: $command" >&2
        exit 1
    fi
done
if [[ ! -f "$extension" ]]; then
    echo "Built PHP extension not found: $extension" >&2
    exit 1
fi
if [[ ! -x "$imp2vs" ]]; then
    echo "Bundled SWORD imp2vs utility not found: $imp2vs" >&2
    exit 1
fi

mkdir -p -- "$module_root/mods.d" "$data_root" "$output_directory"
if find "$output_directory" -mindepth 1 -maxdepth 1 -print -quit \
    | grep --quiet .; then
    echo "Evidence output directory must be empty: $output_directory" >&2
    exit 1
fi

: > "$fixture_imp"
for chapter in "${chapters[@]}"; do
    case "$chapter" in
        1)
            expected_verses=20
            ;;
        22)
            expected_verses=21
            ;;
        *)
            echo "Unsupported Revelation boundary chapter: $chapter" >&2
            exit 1
            ;;
    esac

    baseline_directory="$repository_root/tests/baselines/kjv-revelation-${chapter}"
    entries_file="$baseline_directory/kjv-revelation-${chapter}.entries.ndjson"
    text_file="$baseline_directory/kjv-revelation-${chapter}.txt"
    manifest_file="$baseline_directory/kjv-revelation-${chapter}.manifest.json"

    for file in "$entries_file" "$text_file" "$manifest_file"; do
        if [[ ! -f "$file" ]]; then
            echo "Approved replay fixture is missing: $file" >&2
            exit 1
        fi
    done

    (
        cd "$baseline_directory"
        jq --raw-output \
            '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
            "$(basename "$manifest_file")" \
            | sha256sum --check --strict
    )

    if ! jq \
        --slurp \
        --exit-status \
        --argjson chapter "$chapter" \
        --argjson verses "$expected_verses" \
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
                and .scope.osis_reference.utf8
                    == ("Rev." + ($chapter | tostring) + "."
                        + (.scope.verse | tostring))
                and (.raw.utf8 | type == "string" and length > 0)
            )
        ' \
        "$entries_file" >/dev/null; then
        echo "Approved Revelation $chapter entries cannot seed the replay fixture." >&2
        exit 1
    fi

    jq --raw-output \
        '"$$$\(.scope.osis_reference.utf8)\n\(.raw.utf8)"' \
        "$entries_file" >> "$fixture_imp"
done

"$imp2vs" "$fixture_imp" -o "$data_root" >/dev/null
cat > "$module_root/mods.d/kjv.conf" <<'EOF_CONFIG'
[KJV]
DataPath=./modules/texts/rawtext/kjv/
ModDrv=RawText
SourceType=OSIS
Encoding=UTF-8
Versification=KJV
Lang=en
Direction=LtoR
GlobalOptionFilter=OSISFootnotes
GlobalOptionFilter=OSISHeadings
GlobalOptionFilter=OSISRedLetterWords
GlobalOptionFilter=OSISLemma
GlobalOptionFilter=OSISStrongs
GlobalOptionFilter=OSISMorph
Feature=NoParagraphs
Feature=StrongsNumbers
Description=Approved getbible/sword KJV Revelation replay fixture
DistributionLicense=Public Domain
EOF_CONFIG

php \
    -n \
    -d "extension=$extension" \
    "$repository_root/scripts/create-kjv-revelation-boundary-artifacts.php" \
    "$module_root" \
    "$output_directory"

(
    cd "$output_directory"
    for chapter in "${chapters[@]}"; do
        jq --raw-output \
            '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
            "kjv-revelation-${chapter}.manifest.json" \
            | sha256sum --check --strict
    done
)
