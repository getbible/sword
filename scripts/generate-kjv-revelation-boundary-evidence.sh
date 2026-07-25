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
readonly source_url='https://crosswire.org/ftpmirror/pub/sword/packages/rawzip/KJV.zip'
temporary_root="$(mktemp -d)"
readonly temporary_root
readonly module_root="$temporary_root/sword"
readonly archive="$temporary_root/KJV.zip"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

for command in curl jq php sha256sum unzip; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Required evidence command is unavailable: $command" >&2
        exit 1
    fi
done
if [[ ! -f "$extension" ]]; then
    echo "Built PHP extension not found: $extension" >&2
    exit 1
fi

mkdir -p -- "$module_root" "$output_directory"
if find "$output_directory" -mindepth 1 -maxdepth 1 -print -quit \
    | grep --quiet .; then
    echo "Evidence output directory must be empty: $output_directory" >&2
    exit 1
fi

curl \
    --fail \
    --location \
    --proto '=https' \
    --retry 3 \
    --show-error \
    --silent \
    --tlsv1.2 \
    --output "$archive" \
    "$source_url"
unzip -q "$archive" -d "$module_root"
if [[ ! -f "$module_root/mods.d/kjv.conf" ]]; then
    echo "CrossWire KJV archive does not contain mods.d/kjv.conf." >&2
    exit 1
fi

source_sha256="$(sha256sum "$archive" | cut -d' ' -f1)"
readonly source_sha256
php \
    -n \
    -d "extension=$extension" \
    "$repository_root/scripts/create-kjv-revelation-boundary-artifacts.php" \
    "$module_root" \
    "$output_directory" \
    "$source_sha256"

(
    cd "$output_directory"
    for chapter in 1 22; do
        jq --raw-output \
            '"\(.entries_sha256)  \(.entries_file)\n\(.text_sha256)  \(.text_file)"' \
            "kjv-revelation-${chapter}.manifest.json" \
            | sha256sum --check --strict
    done
)
