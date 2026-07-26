#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly operational_files=(
    '.github/workflows/ci.yml'
    '.github/workflows/golden-baseline.yml'
    '.github/workflows/golden-baseline-recovery.yml'
    '.github/workflows/release.yml'
    'scripts/build-kjv-revelation-boundary-evidence.sh'
    'scripts/create-kjv-revelation-boundary-artifacts.php'
    'scripts/generate-kjv-revelation-boundary-evidence.sh'
    'scripts/verify-kjv-revelation-boundary-baselines.sh'
    'scripts/verify-kjv-revelation-boundary-reproducibility.sh'
)
readonly generator_files=(
    'scripts/build-kjv-revelation-boundary-evidence.sh'
    'scripts/create-kjv-revelation-boundary-artifacts.php'
    'scripts/generate-kjv-revelation-boundary-evidence.sh'
)

cd "$repository_root"

if grep --line-number --extended-regexp \
    'ftp\.crosswire\.org|crosswire\.org/ftpmirror|rawzip/KJV\.zip' \
    "${operational_files[@]}"; then
    echo 'Golden evidence contains a forbidden CrossWire module endpoint.' >&2
    exit 1
fi

if grep --line-number --extended-regexp \
    '(^|[[:space:]])(curl|wget|ftp|lftp)([[:space:]]|$)|[a-z]+://[^[:space:]]+' \
    "${generator_files[@]}"; then
    echo 'Golden evidence generation must remain local and network-free.' >&2
    exit 1
fi

printf 'KJV golden evidence network-isolation checks passed.\n'
