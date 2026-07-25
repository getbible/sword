# Agent guidance

## Compatibility

- Package name: `getbible/sword`
- Extension name: `getbiblesword`
- Namespace: `GetBible\Sword`
- Native engine: getBibleSword `0.3.0`
- C ABI: version `1`
- NDJSON contract: `getbiblesword.ndjson/v1`
- SWORD: `1.9.0`

Treat these as release contracts. Changes to the native pins require complete
CLI/PHP parity and dependency-boundary verification.

## Engineering rules

- Keep extraction streamed into PHP resources.
- Never return an entire module as one PHP string.
- Do not expose C++, STL, or SWORD types through Zend.
- Do not use ambient system `libsword` in official builds.
- Do not add automatic module downloads until the native ABI defines repository,
  disclaimer, TLS, locking, and atomic-install behavior.
- Keep runtime network-free for ABI v1.
- Preserve NTS and ZTS support.

## Verification

Run `./scripts/build-extension.sh`. CI must prove real-module extraction,
byte-for-byte standalone CLI parity, no `libsword.so` or
`libgetbiblesword.so` dependency, successful PHPT tests, and exact KJV
Revelation 1 parity with the maintainer-approved baseline. Never update a golden
baseline automatically.
