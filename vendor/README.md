# Vendored release inputs

The Git repository intentionally does not store generated dependency copies.

Run:

```bash
./scripts/vendor-dependencies.sh
```

The script pins and verifies:

- getBibleSword `v0.4.0` at commit
  `f5115c5a3a3162471af3f7341b0a4265bdfecae0`; and
- the official CrossWire SWORD `1.9.0` source archive with SHA-256
  `42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a`.

Release source archives contain both dependencies so `pie install
getbible/sword` never downloads or substitutes native source during the build.

The getBibleSword copy includes its source-encoding decoder and ICU license.
The extension requires the system ICU development package (`icu-uc` through
`pkg-config`) at build time and links the ICU runtime for normalized UTF-8
projections. SWORD and getBibleSword remain embedded; the extension does not
link a system `libsword.so` or `libgetbiblesword.so`.
