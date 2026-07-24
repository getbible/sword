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

if [[ -x ./configure ]]; then
    phpize --clean >/dev/null
fi

phpize
./configure --enable-getbiblesword
make --jobs="${JOBS:-$detected_jobs}"

if ! NO_INTERACTION=1 REPORT_EXIT_STATUS=1 make test TESTS=tests/phpt; then
    find tests/phpt \
        -type f \
        -name '*.diff' \
        -print \
        -exec cat {} \;
    exit 1
fi
./scripts/test-extension.sh
