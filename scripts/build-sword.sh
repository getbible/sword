#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

readonly SWORD_VERSION='1.9.0'
readonly SWORD_SHA256='42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a'

if (($# != 2)); then
    echo "Usage: $0 INSTALL_PREFIX SWORD_SOURCE_ARCHIVE" >&2
    exit 2
fi

readonly install_prefix=$1
readonly source_archive=$2
readonly marker="$install_prefix/.getbible-sword-build"

if [[ -z "$install_prefix" || "$install_prefix" == '/' || "$install_prefix" == '.' ]]; then
    echo "Refusing unsafe SWORD installation prefix: $install_prefix" >&2
    exit 2
fi
if [[ ! -f "$source_archive" ]]; then
    echo "SWORD source archive not found: $source_archive" >&2
    exit 2
fi

printf '%s  %s\n' "$SWORD_SHA256" "$source_archive" \
    | sha256sum --check --strict

if [[ -f "$marker" ]] \
    && [[ "$(<"$marker")" == "${SWORD_VERSION}:${SWORD_SHA256}" ]] \
    && [[ -f "$install_prefix/lib/libsword.a" ]] \
    && [[ -f "$install_prefix/lib/pkgconfig/sword.pc" ]]; then
    printf 'Reusing pinned SWORD %s from %s.\n' "$SWORD_VERSION" "$install_prefix"
    exit 0
fi
if [[ -e "$install_prefix" ]]; then
    echo "Refusing to replace an incomplete or unrecognized SWORD prefix: $install_prefix" >&2
    exit 1
fi

temporary_root="$(mktemp -d)"
readonly temporary_root
readonly temporary_prefix="$temporary_root/install"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

tar \
    --extract \
    --gzip \
    --no-same-owner \
    --file "$source_archive" \
    --directory "$temporary_root"

readonly source_root="$temporary_root/sword-${SWORD_VERSION}"
if [[ ! -x "$source_root/configure" ]]; then
    echo "Verified archive does not contain sword-${SWORD_VERSION}/configure." >&2
    exit 1
fi

detected_jobs="$(
    getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2\n'
)"
readonly detected_jobs

pushd "$source_root" >/dev/null
./configure \
    --prefix="$temporary_prefix" \
    --disable-shared \
    --enable-static \
    --disable-tests \
    --with-pic \
    --without-clucene
make --jobs="${JOBS:-$detected_jobs}"
make install
popd >/dev/null

if [[ ! -f "$temporary_prefix/lib/libsword.a" ]] \
    || [[ ! -f "$temporary_prefix/lib/pkgconfig/sword.pc" ]]; then
    echo "Pinned SWORD build did not produce the required static SDK." >&2
    exit 1
fi

printf '%s\n' "${SWORD_VERSION}:${SWORD_SHA256}" \
    > "$temporary_prefix/.getbible-sword-build"
mkdir -p -- "$(dirname "$install_prefix")"
mv -- "$temporary_prefix" "$install_prefix"

printf 'Built pinned PIC-static SWORD %s in %s.\n' \
    "$SWORD_VERSION" \
    "$install_prefix"
