# Contributing

Changes must preserve the public PHP API, C ABI status mapping, streaming
behavior, and byte parity with the pinned getBibleSword CLI.

Before opening a pull request:

```bash
./scripts/build-extension.sh
```

Update tests and documentation with every observable behavior change. Do not
silently change dependency revisions, enable ambient system SWORD discovery, or
add network behavior to runtime calls.

Commit generated dependency directories only inside release source archives,
not to Git.
