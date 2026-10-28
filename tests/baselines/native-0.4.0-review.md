# Native 0.4.0 baseline review

The 0.2.0 extension upgrades the pinned engine from native 0.3.0 to the released
0.4.0 commit `f5115c5a3a3162471af3f7341b0a4265bdfecae0`. Five independent local
fixture builds and extension extractions produced byte-identical evidence.
The PHP 8.4 NTS CI job repeats this reproducibility check before merge.

All 20 Revelation 1 entries and all 21 Revelation 22 entries were compared with
the previous approved baselines. The complete set of changed entry fields is:

- `normalized_raw`: added and byte-identical to `raw` for these UTF-8 fixtures;
- `normalized_stripped`: added and byte-identical to `stripped`;
- `official_attributes`: previously empty, now containing the current entry's
  SWORD word attributes, including lexical and morphology information already
  present in its unchanged OSIS source; and
- `sequence`: full-stream position, already excluded by the existing canonical
  comparison because upstream adds additional records elsewhere in the stream.

Every other entry field is unchanged, including raw markup, rendered and
stripped text, verse identity, parsed annotations, and diagnostics. The two
readable chapter files are byte-identical to the previous approved files.
Manifests record engine 0.4.0 and the updated entry hashes. This is the expected
effect of upstream's strict text projections and current-entry attribute fix;
no comparison rule was weakened.

| Chapter | Entry SHA-256 | Unchanged readable-text SHA-256 |
| --- | --- | --- |
| Revelation 1 | `3889341d95cf11c739abaf9da430d821efcc350ea6b5e3e976ad9a0b74cb41ce` | `c483a304bc662fb3748de91f36c5c14ad34f8efffa94abcbd85f9c3cecf88924` |
| Revelation 22 | `47ffa0784053280c89205f981f22dc82b2a3118cfd33ea9aa28f097873419cff` | `9fd9ea09e2c3ece5dd44e4b9aa0f8d886522e076c8293ca751bc6c7b6605a398` |

The PR's golden-evidence artifact contains the regenerated entries, manifests,
readable text, and five-run reproducibility report. These baselines are proposed
through the reviewed upgrade PR, never written directly to the default branch.
