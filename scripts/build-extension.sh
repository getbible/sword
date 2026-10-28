#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
detected_jobs="$(
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2\n'
)"
readonly detected_jobs

cd "$repository_root"

./scripts/vendor-dependencies.sh

# Regenerate build metadata in place. phpize --clean deletes tests/*.php,
# including our integration source and local edits; make clean also removes
# the cached static SWORD archive through its recursive cleanup rules.
phpize
./configure --enable-getbiblesword
# Recompile even when only the selected PHP ABI or compiler flags changed.
make --always-make --jobs="${JOBS:-$detected_jobs}"

if ! NO_INTERACTION=1 REPORT_EXIT_STATUS=1 make test TESTS=tests/phpt; then
    find tests/phpt \
        -type f \
        -name '*.diff' \
        -print \
        -exec cat {} \;
    exit 1
fi
./scripts/test-extension.sh
