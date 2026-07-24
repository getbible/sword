# Vendored release inputs

The Git repository intentionally does not store generated dependency copies.

Run:

```bash
./scripts/vendor-dependencies.sh
```

The script pins and verifies:

- getBibleSword `v0.3.0` at commit
  `c52003438dc7e3d5bab0d6680372b1de8a0077ce`; and
- the official CrossWire SWORD `1.9.0` source archive with SHA-256
  `42409cf3de2faf1108523e2c5ac0745d21f9ed2a5c78ed878ee9dcc303426b8a`.

Release source archives contain both dependencies so `pie install
getbible/sword` never downloads or substitutes native source during the build.
