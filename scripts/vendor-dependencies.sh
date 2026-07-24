#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

readonly GETBIBLESWORD_VERSION='0.3.0'
readonly GETBIBLESWORD_TAG="v${GETBIBLESWORD_VERSION}"
readonly GETBIBLESWORD_COMMIT='c52003438dc7e3d5bab0d6680372b1de8a0077ce'
readonly SWORD_VERSION='1.9.0'
readonly SWORD_SHA256='42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a'
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
readonly vendor_root="$repository_root/vendor"
readonly getbiblesword_target="$vendor_root/getbiblesword"
readonly sword_target="$vendor_root/sword-${SWORD_VERSION}.tar.gz"
readonly sword_url="https://github.com/getbible/getbiblesword/releases/download/${GETBIBLESWORD_TAG}/sword-${SWORD_VERSION}.tar.gz"
temporary_root="$(mktemp -d)"
readonly temporary_root

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

mkdir -p -- "$vendor_root"

if [[ -d "$getbiblesword_target" ]]; then
    if [[ ! -f "$getbiblesword_target/.getbiblesword-vendor-version" ]] \
        || [[ "$(<"$getbiblesword_target/.getbiblesword-vendor-version")" != "$GETBIBLESWORD_COMMIT" ]]; then
        echo "Refusing to replace an unrecognized vendor/getbiblesword directory." >&2
        exit 1
    fi
else
    git clone \
        --branch "$GETBIBLESWORD_TAG" \
        --depth 1 \
        --no-tags \
        https://github.com/getbible/getbiblesword.git \
        "$temporary_root/getbiblesword"

    resolved_commit="$(
        git -C "$temporary_root/getbiblesword" rev-parse 'HEAD^{commit}'
    )"
    readonly resolved_commit
    if [[ "$resolved_commit" != "$GETBIBLESWORD_COMMIT" ]]; then
        printf 'getBibleSword %s resolved to %s, expected %s.\n' \
            "$GETBIBLESWORD_TAG" \
            "$resolved_commit" \
            "$GETBIBLESWORD_COMMIT" >&2
        exit 1
    fi

    rm -rf -- "$temporary_root/getbiblesword/.git"
    mkdir -p -- "$temporary_root/getbiblesword/generated/getbiblesword"
    printf '%s\n' \
        '// SPDX-License-Identifier: GPL-2.0-only' \
        '#pragma once' \
        '' \
        "#define GETBIBLESWORD_VERSION \"${GETBIBLESWORD_VERSION}\"" \
        '#define GETBIBLESWORD_CONTRACT "getbiblesword.ndjson/v1"' \
        > "$temporary_root/getbiblesword/generated/getbiblesword/version.hpp"
    printf '%s\n' "$GETBIBLESWORD_COMMIT" \
        > "$temporary_root/getbiblesword/.getbiblesword-vendor-version"
    mv -- "$temporary_root/getbiblesword" "$getbiblesword_target"
fi

if [[ -f "$sword_target" ]]; then
    printf '%s  %s\n' "$SWORD_SHA256" "$sword_target" \
        | sha256sum --check --strict
else
    readonly temporary_sword="$temporary_root/sword-${SWORD_VERSION}.tar.gz"
    curl \
        --fail \
        --location \
        --proto '=https' \
        --retry 3 \
        --show-error \
        --silent \
        --tlsv1.2 \
        --output "$temporary_sword" \
        "$sword_url"
    printf '%s  %s\n' "$SWORD_SHA256" "$temporary_sword" \
        | sha256sum --check --strict
    mv -- "$temporary_sword" "$sword_target"
fi

printf 'Vendored getBibleSword %s (%s) and SWORD %s.\n' \
    "$GETBIBLESWORD_VERSION" \
    "$GETBIBLESWORD_COMMIT" \
    "$SWORD_VERSION"
