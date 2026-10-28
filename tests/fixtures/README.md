# Native integration fixtures

The original text and module configurations in this directory are dedicated to
the public domain. They contain no third-party Bible, commentary or dictionary
content.

`scripts/create-fixture.sh` uses the pinned SWORD 1.9.0 `imp2vs` and `imp2ld`
utilities to create real modules for the PHP/CLI parity checks:

- `PhpFixture`: Bible verse traversal.
- `PhpCommentary`: Old and New Testament references and actual SWORD heading,
  footnote and lexical attributes.
- `PhpDictionary`: repeated dictionary keys, ordered definitions, attributes
  and UTF-8 source text.
- `PhpLatin1`: strict conversion of Latin-1 bytes to UTF-8 without changing raw
  source bytes. The checked-in source is UTF-8 and is explicitly converted before
  importing it.
- `PhpInvalidUTF8`: malformed bytes, unavailable normalized projections and
  preserved diagnostics, followed by a clean entry.

The tests stream every module through the extension twice, compare both runs
with the independently built CLI, and validate the completed NDJSON with the
upstream reference validator. PHP assertions also check the content, so matching
CLI and PHP output alone cannot hide a missing definition or attribute.
