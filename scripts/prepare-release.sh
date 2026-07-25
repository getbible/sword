#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only

set -euo pipefail
IFS=$'\n\t'

if (($# < 1 || $# > 2)); then
    echo "Usage: $0 auto|patch|minor|major [GITHUB_OUTPUT_FILE]" >&2
    exit 2
fi

readonly requested_bump=$1
readonly github_output_file=${2:-}
repository_root="$(git rev-parse --show-toplevel)"
readonly repository_root
readonly version_file="$repository_root/VERSION"
readonly changelog_file="$repository_root/CHANGELOG.md"

case "$requested_bump" in
    auto|patch|minor|major) ;;
    *)
        echo "Unsupported release increment: $requested_bump" >&2
        exit 2
        ;;
esac

if [[ ! -f "$version_file" || ! -f "$changelog_file" ]]; then
    echo "VERSION and CHANGELOG.md must exist at the repository root." >&2
    exit 1
fi
if ! git -C "$repository_root" diff --quiet -- VERSION CHANGELOG.md \
    || ! git -C "$repository_root" diff --cached --quiet -- VERSION CHANGELOG.md; then
    echo "VERSION or CHANGELOG.md already contains uncommitted changes." >&2
    exit 1
fi

current_version="$(tr -d '\r\n' < "$version_file")"
readonly current_version
if [[ ! "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION is not a stable semantic version: $current_version" >&2
    exit 1
fi

current_tag="v$current_version"
readonly current_tag
latest_tag="$(
    git -C "$repository_root" tag \
        --list 'v*' \
        --sort=-version:refname \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | head -n 1 \
        || true
)"
readonly latest_tag
release_published=${RELEASE_PUBLISHED:-false}
case "$release_published" in
    true|false) ;;
    *)
        echo "RELEASE_PUBLISHED must be true or false." >&2
        exit 2
        ;;
esac

version=$current_version
tag=$current_tag
resolved_bump=initial
base_tag=
tag_exists=false
release_date="$(date -u +%Y-%m-%d)"
readonly release_date

increment_version() {
    local source_version=$1
    local increment=$2
    local major minor patch

    IFS=. read -r major minor patch <<< "$source_version"
    case "$increment" in
        major)
            printf '%d.0.0\n' "$((major + 1))"
            ;;
        minor)
            printf '%d.%d.0\n' "$major" "$((minor + 1))"
            ;;
        patch)
            printf '%d.%d.%d\n' "$major" "$minor" "$((patch + 1))"
            ;;
        *)
            echo "Unsupported increment: $increment" >&2
            return 2
            ;;
    esac
}

infer_increment() {
    local range=$1
    local messages

    messages="$(git -C "$repository_root" log --format='%s%n%b' "$range")"
    if grep -Eq \
        '(^|[[:space:]])BREAKING[ -]CHANGE:|^[[:alpha:]][[:alnum:]_-]*(\([^)]*\))?!:' \
        <<< "$messages"; then
        printf 'major\n'
    elif grep -Eq '^feat(\([^)]*\))?:' <<< "$messages"; then
        printf 'minor\n'
    else
        printf 'patch\n'
    fi
}

update_initial_changelog() {
    local heading="## $current_version - Unreleased"
    local replacement="## $current_version - $release_date"
    local temporary_file

    if ! grep -Fqx "$heading" "$changelog_file"; then
        return
    fi
    temporary_file="$(mktemp)"
    awk \
        -v heading="$heading" \
        -v replacement="$replacement" \
        '{ print $0 == heading ? replacement : $0 }' \
        "$changelog_file" > "$temporary_file"
    mv -- "$temporary_file" "$changelog_file"
}

prepend_changelog_release() {
    local release_version=$1
    local range=$2
    local temporary_file
    local notes_file

    temporary_file="$(mktemp)"
    notes_file="$(mktemp)"
    git -C "$repository_root" log \
        --reverse \
        --format='%s' \
        "$range" \
        | sed -E '/^(Release|Merge pull request) /d; s/^/- /' \
        > "$notes_file"
    if [[ ! -s "$notes_file" ]]; then
        printf '%s\n' '- Internal maintenance and release preparation.' > "$notes_file"
    fi

    {
        printf '# Changelog\n\n'
        printf '## %s - %s\n\n' "$release_version" "$release_date"
        cat "$notes_file"
        printf '\n\n'
        sed '1{/^# Changelog$/d;}' "$changelog_file" | sed '1{/^$/d;}'
    } > "$temporary_file"

    mv -- "$temporary_file" "$changelog_file"
    rm -f -- "$notes_file"
}

if git -C "$repository_root" show-ref --verify --quiet "refs/tags/$current_tag"; then
    if [[ -n "$latest_tag" && "$latest_tag" != "$current_tag" ]]; then
        printf 'VERSION %s does not match latest stable tag %s.\n' \
            "$current_version" "$latest_tag" >&2
        exit 1
    fi
    tag_exists=true
    tag_commit="$(git -C "$repository_root" rev-list -n 1 "$current_tag")"
    head_commit="$(git -C "$repository_root" rev-parse HEAD)"
    readonly tag_commit head_commit

    if [[ "$release_published" == false ]]; then
        if [[ "$tag_commit" != "$head_commit" ]]; then
            echo "Unpublished tag $current_tag does not point to HEAD." >&2
            echo "Publish or remove that failed tag before preparing another release." >&2
            exit 1
        fi
        resolved_bump=recovery
    else
        if [[ "$tag_commit" == "$head_commit" ]]; then
            echo "$current_tag is already released and there are no new commits." >&2
            exit 1
        fi
        if ! git -C "$repository_root" merge-base --is-ancestor "$current_tag" HEAD; then
            echo "$current_tag is not an ancestor of HEAD." >&2
            exit 1
        fi

        base_tag=$current_tag
        range="$current_tag..HEAD"
        resolved_bump=$requested_bump
        if [[ "$resolved_bump" == auto ]]; then
            resolved_bump="$(infer_increment "$range")"
        fi
        version="$(increment_version "$current_version" "$resolved_bump")"
        tag="v$version"
        tag_exists=false

        if git -C "$repository_root" show-ref --verify --quiet "refs/tags/$tag"; then
            echo "Computed release tag already exists: $tag" >&2
            exit 1
        fi

        printf '%s\n' "$version" > "$version_file"
        prepend_changelog_release "$version" "$range"
    fi
else
    if [[ -n "$latest_tag" ]]; then
        latest_version=${latest_tag#v}
        highest_version="$(
            printf '%s\n%s\n' "$latest_version" "$current_version" \
                | sort --version-sort \
                | tail -n 1
        )"
        if [[ "$highest_version" != "$current_version" \
            || "$current_version" == "$latest_version" ]]; then
            printf 'Untagged VERSION %s must be newer than latest tag %s.\n' \
                "$current_version" "$latest_tag" >&2
            exit 1
        fi
    fi
    update_initial_changelog
fi

changed=false
if ! git -C "$repository_root" diff --quiet -- VERSION CHANGELOG.md; then
    changed=true
fi

write_output() {
    local name=$1
    local value=$2

    printf '%s=%s\n' "$name" "$value"
    if [[ -n "$github_output_file" ]]; then
        printf '%s=%s\n' "$name" "$value" >> "$github_output_file"
    fi
}

write_output version "$version"
write_output tag "$tag"
write_output bump "$resolved_bump"
write_output base_tag "$base_tag"
write_output tag_exists "$tag_exists"
write_output changed "$changed"
