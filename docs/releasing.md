# Releasing

## One-time prerequisites

1. Register `https://github.com/getbible/sword` on Packagist by following
   [packagist.md](packagist.md).
2. In GitHub repository settings, allow GitHub Actions read/write workflow
   permissions.
3. If `main` is protected, permit the Release workflow or GitHub Actions bot to
   bypass the protection for the automated `VERSION` and `CHANGELOG.md` release
   commit.
4. Require CI and CodeQL before normal changes reach `main`.
5. Confirm the getBibleSword and SWORD pins in
   `scripts/vendor-dependencies.sh` remain intentional.

The workflow needs no Packagist secret when Packagist's GitHub application or
push webhook is active.

## Preferred release: run the workflow

Open **Actions** → **Release** → **Run workflow**, leave `auto` selected, and run
it from `main`.

The workflow behaves as follows:

1. If the semantic version in `VERSION` has no tag, it releases that version.
   This is how the initial `0.1.0` release is created.
2. If that version is already published, it inspects commits after the tag:
   - `BREAKING CHANGE:` or a conventional commit with `!` selects `major`;
   - `feat:` selects `minor`;
   - all other commits select `patch`.
3. A manually selected `patch`, `minor`, or `major` overrides inference.
4. It updates `VERSION` and prepends a dated changelog section when a new version
   is required.
5. It commits the release metadata, creates an annotated `vX.Y.Z` tag, and pushes
   both.
6. It builds the deterministic pre-packaged PIE source archive.
7. It builds that archive through PIE on PHP 8.4.
8. It builds the extension and runs all normal integration and parity checks.
9. It downloads the public CrossWire KJV module and emits all 20 verses of
   Revelation 1.
10. It uploads the Revelation 1 NDJSON, text, and manifest as workflow and
    GitHub-release assets.
11. It publishes the immutable GitHub release with generated release notes.

The workflow is serialized. Two releases cannot calculate or publish versions
at the same time.

## Supported alternative: push a tag

Maintainers may prepare `VERSION` and `CHANGELOG.md` in a normal pull request,
merge it, and push the matching annotated tag:

```bash
version="$(tr -d '\r\n' < VERSION)"
git tag -a "v${version}" -m "getbible/sword ${version}"
git push origin "v${version}"
```

The tag-driven workflow validates that the tag exactly matches `VERSION`, then
uses the same source, PIE, KJV evidence, and publication jobs as the manual
workflow.

## Failure recovery

The manual workflow creates the tag before expensive builds begin so every
asset is built from an immutable commit.

If a build fails after the tag is created but before the GitHub release exists,
run the Release workflow again. When the unpublished tag still points to `HEAD`,
the workflow reuses that tag instead of incrementing again.

The workflow stops for manual intervention when:

- an unpublished tag no longer points to `HEAD`;
- the current tag is published and there are no new commits;
- the calculated next tag already exists;
- a pushed tag does not match `VERSION`; or
- branch protection refuses the automated release commit.

Never move a published tag.

## Assets

For version `X.Y.Z`, the release contains:

```text
php_getbiblesword-X.Y.Z-src.tgz
php_getbiblesword-X.Y.Z-src.tgz.sha256
kjv-revelation-1.entries.ndjson
kjv-revelation-1.txt
kjv-revelation-1.manifest.json
```

The Revelation evidence is a selected set of exact `entry` records, not a
complete `getbiblesword.ndjson/v1` stream. Its manifest sets
`whole_contract_stream` to `false` and records hashes for the source KJV archive
and both evidence files.

After the first artifact is reviewed, commit the approved files as a golden
fixture and add a comparison job without removing the live extraction.

## Post-release

```bash
pie info getbible/sword
pie install getbible/sword
php --ri getbiblesword
```

Test on both CLI and PHP-FPM. Confirm that `ldd` on the installed extension does
not list `libsword.so` or `libgetbiblesword.so`.
