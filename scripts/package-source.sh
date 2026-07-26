#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# != 2)); then
    echo "Usage: $0 VERSION OUTPUT_DIRECTORY" >&2
    exit 2
fi

readonly requested_version=$1
readonly output_directory=$2
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
project_version="$(tr -d '\r\n' < "$repository_root/VERSION")"
readonly project_version
source_date_epoch="$(
    git -C "$repository_root" show -s --format=%ct HEAD
)"
readonly source_date_epoch
readonly package_name="php_getbiblesword-${requested_version}"
readonly archive_name="php_getbiblesword-v${requested_version}-src.tgz"
temporary_root="$(mktemp -d)"
readonly temporary_root
readonly package_root="$temporary_root/$package_name"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

if [[ "$requested_version" != "$project_version" ]]; then
    printf 'Requested version %s does not match VERSION (%s).\n' \
        "$requested_version" \
        "$project_version" >&2
    exit 2
fi
if [[ ! "$requested_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid package version: $requested_version" >&2
    exit 2
fi

mkdir -p -- "$package_root" "$output_directory"
git -C "$repository_root" archive --format=tar HEAD \
    | tar --extract --file=- --directory="$package_root"

"$package_root/scripts/vendor-dependencies.sh"

readonly required_files=(
    "$package_root/composer.json"
    "$package_root/config.m4"
    "$package_root/getbiblesword.c"
    "$package_root/vendor/getbiblesword/src/c_api.cpp"
    "$package_root/vendor/getbiblesword/include/getbiblesword/c_api.h"
    "$package_root/vendor/sword-1.9.0.tar.gz"
)
for required_file in "${required_files[@]}"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Source package input is missing: $required_file" >&2
        exit 1
    fi
done

tar \
    --create \
    --gzip \
    --sort=name \
    --mtime="@$source_date_epoch" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --file "$output_directory/$archive_name" \
    --directory "$temporary_root" \
    "$package_name"

(
    cd "$output_directory"
    sha256sum "$archive_name" > "$archive_name.sha256"
    sha256sum --check --strict "$archive_name.sha256"
)

printf 'Created PIE source package %s.\n' \
    "$output_directory/$archive_name"
