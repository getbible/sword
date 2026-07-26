# Changelog

## Unreleased

- Remove all CrossWire FTP and module-mirror downloads from golden evidence.
- Rebuild the KJV Revelation 1 and 22 test module locally from the last
  maintainer-approved extension output committed in `tests/baselines/`.
- Restore deterministic golden evidence to the PHP 8.4 NTS pull-request build.
- Compare complete canonical entry records while excluding only full-stream
  position fields `sequence` and `ordinal`; continue comparing readable chapter
  text byte-for-byte.
- Record local replay provenance in evidence manifest format v2 and remove the
  obsolete remote archive URL and checksum fields.
- Keep five-run recovery and maintainer-reviewed baseline promotion entirely
  self-contained and network-independent from Bible-module providers.

## 0.1.0 - 2026-07-25

- Add the `getbiblesword` PHP extension for PIE.
- Embed getBibleSword 0.3.0 and CrossWire SWORD 1.9.0.
- Add streamed list and extract operations with exact NDJSON v1 parity.
- Add explicit, INI, environment, and effective-user module-path resolution.
- Add NTS, ZTS, PHP 8.2-8.5, CLI-parity, dependency, and release-source checks.
- Add automatic semantic version resolution, version commits, annotated tags,
  PIE verification, and GitHub release publication.
- Add live KJV Revelation 1 release evidence with exact NDJSON, text, manifest,
  source checksum, and artifact checksums to both CI and release runs.
- Commit the maintainer-approved Revelation 1 output and require every CI and
  release extraction to match its NDJSON and readable text byte-for-byte.
- Add Revelation 22 to the golden evidence and monitor both boundary chapters
  after every `main` update, daily, and on demand.
- Add five-run baseline recovery that opens a maintainer-review pull request
  only for byte-identical, reproducible changed output.
- Document the PHP-extension source layout, Packagist registration, release
  recovery, and both supported release entry points.
