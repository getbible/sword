#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly repository_root
temporary_root="$(mktemp -d)"
readonly temporary_root

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT INT TERM

new_repository() {
    local name=$1
    local release_state=${2:-released}
    local target="$temporary_root/$name"

    mkdir -p "$target/scripts"
    cp "$repository_root/scripts/prepare-release.sh" "$target/scripts/"
    printf '0.1.0\n' > "$target/VERSION"
    if [[ "$release_state" == unreleased ]]; then
        printf '# Changelog\n\n## 0.1.0 - Unreleased\n\n- Initial package.\n' \
            > "$target/CHANGELOG.md"
    else
        printf '# Changelog\n\n## 0.1.0 - 2026-07-25\n\n- Initial package.\n' \
            > "$target/CHANGELOG.md"
    fi
    git -C "$target" init --initial-branch=main --quiet
    git -C "$target" config user.name 'Release Test'
    git -C "$target" config user.email 'release-test@example.invalid'
    git -C "$target" add .
    git -C "$target" commit --quiet --message 'Initial package'
    printf '%s\n' "$target"
}

assert_equal() {
    local expected=$1
    local actual=$2
    local message=$3

    if [[ "$expected" != "$actual" ]]; then
        printf '%s: expected %s, received %s\n' \
            "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

test_initial_release() (
    local target output version tag bump tag_exists changed

    target="$(new_repository initial unreleased)"
    output="$target/output"
    cd "$target"
    RELEASE_PUBLISHED=false ./scripts/prepare-release.sh auto "$output" >/dev/null
    # shellcheck disable=SC1090
    source "$output"

    assert_equal 0.1.0 "$version" 'initial version'
    assert_equal v0.1.0 "$tag" 'initial tag'
    assert_equal initial "$bump" 'initial mode'
    assert_equal false "$tag_exists" 'initial tag existence'
    assert_equal true "$changed" 'initial changelog update'
    if grep -Fq '## 0.1.0 - Unreleased' CHANGELOG.md; then
        echo 'Initial changelog was not dated.' >&2
        exit 1
    fi
)

test_increment() (
    local subject=$1
    local requested=$2
    local expected_version=$3
    local expected_bump=$4
    local name=$5
    local target output version tag bump changed

    target="$(new_repository "$name")"
    output="$target/output"
    git -C "$target" tag --annotate v0.1.0 --message '0.1.0'
    printf '%s\n' "$subject" > "$target/change.txt"
    git -C "$target" add change.txt
    git -C "$target" commit --quiet --message "$subject"

    cd "$target"
    RELEASE_PUBLISHED=true \
        ./scripts/prepare-release.sh "$requested" "$output" >/dev/null
    # shellcheck disable=SC1090
    source "$output"

    assert_equal "$expected_version" "$version" "$name version"
    assert_equal "v$expected_version" "$tag" "$name tag"
    assert_equal "$expected_bump" "$bump" "$name bump"
    assert_equal true "$changed" "$name metadata update"
    assert_equal "$expected_version" "$(tr -d '\r\n' < VERSION)" \
        "$name VERSION file"
)

test_recovery() (
    local target output version bump tag_exists changed

    target="$(new_repository recovery)"
    output="$target/output"
    git -C "$target" tag --annotate v0.1.0 --message '0.1.0'

    cd "$target"
    RELEASE_PUBLISHED=false ./scripts/prepare-release.sh auto "$output" >/dev/null
    # shellcheck disable=SC1090
    source "$output"

    assert_equal 0.1.0 "$version" 'recovery version'
    assert_equal recovery "$bump" 'recovery mode'
    assert_equal true "$tag_exists" 'recovery tag existence'
    assert_equal false "$changed" 'recovery metadata state'
)

test_no_changes_refused() (
    target="$(new_repository no-changes)"
    git -C "$target" tag --annotate v0.1.0 --message '0.1.0'

    cd "$target"
    if RELEASE_PUBLISHED=true \
        ./scripts/prepare-release.sh auto >/dev/null 2>&1; then
        echo 'Released tag without new commits was not refused.' >&2
        exit 1
    fi
)

test_initial_release
test_increment 'fix: correct packaging' auto 0.1.1 patch patch
test_increment 'feat: add query API' auto 0.2.0 minor minor
test_increment 'feat!: replace public API' auto 1.0.0 major major
test_increment 'fix: correct packaging' minor 0.2.0 minor explicit-minor
test_recovery
test_no_changes_refused

echo 'Release versioning tests passed.'
