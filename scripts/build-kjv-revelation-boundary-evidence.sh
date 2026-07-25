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

bash "$repository_root/scripts/generate-kjv-revelation-boundary-evidence.sh" \
    "$output_directory"
bash "$repository_root/scripts/verify-kjv-revelation-boundary-baselines.sh" \
    "$output_directory"
