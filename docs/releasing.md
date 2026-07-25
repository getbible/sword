# Releasing

## One-time prerequisites

1. Register `https://github.com/getbible/sword` on Packagist by following
   [packagist.md](packagist.md).
2. In GitHub repository settings, allow GitHub Actions read/write workflow
   permissions.
3. Enable **Allow GitHub Actions to create and approve pull requests** so the
   recovery workflow can open a baseline proposal. It never approves or merges
   that proposal.
4. If `main` is protected, permit the Release workflow or GitHub Actions bot to
   bypass the protection for the automated `VERSION` and `CHANGELOG.md` release
   commit.
5. Require CI and CodeQL before normal changes reach `main`.
6. Confirm the getBibleSword and SWORD pins in
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
9. It repeats the CI-tested live download of the public CrossWire KJV module as
   test input and passes that module through the built PHP extension once.
10. It selects all 20 Revelation 1 entries and all 21 Revelation 22 entries
    from getBibleSword's own NDJSON output and compares each chapter's NDJSON
    and readable text byte-for-byte with its approved repository baseline.
11. It uploads both chapters' generated NDJSON, text, and manifest files as
    workflow and GitHub-release assets.
12. It publishes the immutable GitHub release with generated release notes only
    when the golden-baseline comparison succeeds.

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

## Golden-baseline recovery

The **Golden Baseline** workflow is independent of releases. It runs:

- after every push to `main`;
- daily at 03:17 UTC; and
- whenever a maintainer dispatches it manually.

It builds and tests the extension, downloads the current public CrossWire KJV
module as input, streams it through `GetBible\Sword\Engine`, and compares
Revelation 1 and 22 with the approved repository files. Its generated artifact
is retained even on failure.

A failed default-branch golden run automatically starts **Golden Baseline
Recovery**. Recovery:

1. checks out the exact failed `main` commit;
2. builds and tests the extension once;
3. independently downloads KJV and runs the extension five times;
4. validates all 20 Revelation 1 verses and all 21 Revelation 22 verses;
5. requires the two NDJSON files, two text files, and two manifests to match
   byte-for-byte across all five runs;
6. uploads all five complete candidate sets for maintainer inspection;
7. creates no PR when the candidate is unstable or still matches the approved
   baseline; and
8. for a stable changed candidate, creates an
   `automation/kjv-golden-FINGERPRINT` branch and opens a normal pull request.

The workflow also dispatches CI and CodeQL for the candidate branch because
GitHub suppresses ordinary workflow recursion from its built-in token. It never
approves or merges the PR and never writes a baseline directly to `main`.

The maintainer reviews the baseline diff and the downloadable five-run artifact.
Merging the PR promotes the candidate. Closing the PR rejects it. After a merge,
the normal `main` CI and golden workflows regenerate both chapters against the
new approved files; releases remain blocked until those checks pass.

## Release failure recovery

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
kjv-revelation-22.entries.ndjson
kjv-revelation-22.txt
kjv-revelation-22.manifest.json
```

Each Revelation evidence set is a selected group of exact `entry` records, not
a complete `getbiblesword.ndjson/v1` stream. Each manifest sets
`whole_contract_stream` to `false` and records hashes for the source KJV archive
and its two evidence files.

The approved historical output is committed in
`tests/baselines/kjv-revelation-1/` and
`tests/baselines/kjv-revelation-22/`. CrossWire's downloaded module is live test
input; it is not used as the expected output. The extension must regenerate
both chapters, and all four generated payload files must match the committed
output exactly.

If the comparison fails, the workflow fails and no GitHub release is published.
The generated files are still uploaded as a workflow artifact when they exist,
so the difference can be investigated. Never replace a baseline merely to make
CI green. The five-run recovery may prepare the intentional pull request, but a
maintainer must confirm that the changed getBibleSword output is correct and
merge it before any release can continue.

## Post-release

```bash
pie info getbible/sword
pie install getbible/sword
php --ri getbiblesword
```

Test on both CLI and PHP-FPM. Confirm that `ldd` on the installed extension does
not list `libsword.so` or `libgetbiblesword.so`.
