# Packagist setup

Packagist registration is a one-time operation. It should be completed before
the first Release workflow is run so the newly pushed tag is synchronized
immediately.

## Register the package

1. Sign in to [Packagist](https://packagist.org/) with the GitHub account that
   can administer the `getbible` organization.
2. Ensure the Packagist GitHub application can access the `getbible`
   organization and the public `getbible/sword` repository.
3. Open [Submit Package](https://packagist.org/packages/submit).
4. Enter:

   ```text
   https://github.com/getbible/sword
   ```

5. Submit the repository.
6. Confirm that Packagist identifies the package as:

   ```text
   getbible/sword
   ```

The name and extension metadata come from the committed `composer.json`. Do not
create a second package under another name.

Before the first tag exists, Packagist may show only `dev-main`. The first stable
version appears after the release workflow creates `v0.1.0`.

## Automatic synchronization

When the Packagist GitHub application has organization access, Packagist normally
creates the required hook automatically. On the Packagist package page, verify
that there is no warning that automatic synchronization is disabled.

If synchronization is not enabled:

1. reconnect or resynchronize the GitHub account from the Packagist profile; or
2. add a webhook in GitHub under
   `getbible/sword` → **Settings** → **Webhooks** → **Add webhook**.

Use:

| Field | Value |
|---|---|
| Payload URL | `https://packagist.org/api/github?username=YOUR_PACKAGIST_USERNAME` |
| Content type | `application/json` |
| Secret | the API token from the Packagist profile |
| Events | **Just the push event** |
| Active | enabled |

No Packagist token is required in GitHub Actions when the GitHub application or
webhook is configured. A release tag is a push event, so Packagist will refresh
the package automatically.

## Verification after release

After the GitHub release succeeds:

```bash
pie info getbible/sword
pie install getbible/sword
php --ri getbiblesword
```

Also confirm that the Packagist package page lists the same stable version as the
GitHub tag and release.
