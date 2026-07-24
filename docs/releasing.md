# Releasing

## Preconditions

1. Make the GitHub repository public, or configure a private Composer
   repository that PIE can access.
2. Register `getbible/sword` on Packagist as an extension package.
3. Protect `main` and require the CI and CodeQL checks.
4. Confirm `VERSION` contains the intended semantic version.
5. Confirm the getBibleSword and SWORD pins in
   `scripts/vendor-dependencies.sh` are intentional.

## Release

Merge the release commit to `main`, then create and push the matching annotated
tag:

```bash
git tag -a v0.1.0 -m 'getbible/sword 0.1.0'
git push origin v0.1.0
```

The release workflow:

1. verifies that the tag matches `VERSION`;
2. builds a deterministic pre-packaged PIE source archive;
3. includes and verifies both native dependencies;
4. builds the archive through PIE on PHP 8.4;
5. verifies checksums; and
6. publishes the source archive and checksum to a GitHub release.

The expected asset name is:

```text
php_getbiblesword-0.1.0-src.tgz
```

PIE recognizes this name because the extension name is `getbiblesword`.

## Post-release

```bash
pie info getbible/sword
pie install getbible/sword
php --ri getbiblesword
```

Test on both CLI and PHP-FPM. Confirm that `ldd` on the installed extension does
not list `libsword.so` or `libgetbiblesword.so`.
