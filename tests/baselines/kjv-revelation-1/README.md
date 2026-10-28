# KJV Revelation 1 golden baseline

These files are the maintainer-approved historical output produced by
`getbible/sword` for KJV Revelation chapter 1:

- `kjv-revelation-1.entries.ndjson` contains the 20 exact `entry` records
  selected from the NDJSON stream emitted by
  `GetBible\Sword\Engine::streamModule('KJV', ...)`;
- `kjv-revelation-1.txt` is the human-readable projection derived from those
  same records; and
- `kjv-revelation-1.manifest.json` records the native engine, ABI, contract,
  local replay provenance, and output hashes for the approved artifact.

The committed raw entry bytes seed a locally compiled SWORD replay fixture.
The extension regenerates its normalized text, attributes, and annotations;
expected output remains the complete committed entry records and readable text.
No module download is required.

Every relevant CI and release run regenerates Revelation chapters 1 and 22 and
compares their complete canonical entries (excluding only `sequence` and
`ordinal`) and byte-identical readable text. PHP 8.4 NTS PR CI also verifies five
byte-identical runs. A failure blocks release and retains evidence for review.
See [the native 0.4.0 review](../native-0.4.0-review.md) for this upgrade's exact
semantic differences and evidence hashes.

The recovery workflow may propose a changed baseline only after five independent
extension runs produce all six boundary files byte-for-byte identically. It
opens a normal pull request; it never commits to `main`. A maintainer must
inspect and merge that pull request before the candidate becomes approved.
