#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# != 1)); then
    echo "Usage: $0 OUTPUT_SWORD_ROOT" >&2
    exit 2
fi

readonly output_root=$1
readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly imp2vs="$repository_root/.getbiblesword/sword-1.9.0/bin/imp2vs"
readonly data_root="$output_root/modules/texts/rawtext/phpfixture"

if [[ -e "$output_root" ]]; then
    echo "Fixture output already exists: $output_root" >&2
    exit 2
fi
if [[ ! -x "$imp2vs" ]]; then
    echo "SWORD imp2vs utility is unavailable: $imp2vs" >&2
    exit 2
fi

mkdir -p -- "$output_root/mods.d" "$data_root"
"$imp2vs" "$repository_root/tests/fixtures/verse.imp" \
    -o "$data_root" >/dev/null

printf '%s\n' \
    '[PhpFixture]' \
    'DataPath=./modules/texts/rawtext/phpfixture/' \
    'ModDrv=RawText' \
    'SourceType=OSIS' \
    'Encoding=UTF-8' \
    'Lang=en' \
    'Description=PHP extension integration fixture' \
    'DistributionLicense=Public Domain' \
    > "$output_root/mods.d/phpfixture.conf"
