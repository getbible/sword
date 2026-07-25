# KJV Revelation 1 golden baseline

These files are the maintainer-approved historical output produced by
`getbible/sword` for KJV Revelation chapter 1:

- `kjv-revelation-1.entries.ndjson` contains the 20 exact `entry` records
  selected from the NDJSON stream emitted by
  `GetBible\Sword\Engine::streamModule('KJV', ...)`;
- `kjv-revelation-1.txt` is the human-readable projection derived from those
  same records; and
- `kjv-revelation-1.manifest.json` records the native engine, ABI, contract,
  input archive, and output hashes for the approved artifact.

The public CrossWire `KJV.zip` is only the live SWORD module input. It is
downloaded, opened by the compiled extension, and passed through getBibleSword.
It is not the expected output and is not compared directly with these files.

Every relevant CI and release run regenerates the chapter through the extension
and compares the NDJSON and text files byte-for-byte with this baseline. A
failure blocks a release while retaining the newly generated workflow artifact
for inspection.

Do not refresh this directory automatically. Any future output change must be
reviewed and approved by a maintainer in a dedicated pull request.
