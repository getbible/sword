#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly detected_jobs="$(
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2\n'
)"

cd "$repository_root"

./scripts/vendor-dependencies.sh

if [[ -x ./configure ]]; then
    phpize --clean >/dev/null
fi

phpize
./configure --enable-getbiblesword
make --jobs="${JOBS:-$detected_jobs}"

NO_INTERACTION=1 REPORT_EXIT_STATUS=1 make test TESTS=tests/phpt
./scripts/test-extension.sh
