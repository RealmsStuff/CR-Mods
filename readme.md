# Captivity Reloaded Mods

Official catalog and source-pack repository for Captivity Reloaded mods.

- `catalog-v1.json` is the catalog consumed by the in-game browser.
- `packs/` contains inspectable loose sources.
- `release-assets/` contains installable `.capmod` archives served directly through GitHub's raw-content host.
- `scripts/` contains catalog/source validation helpers.

Run `scripts/validate-release-assets.ps1` before publishing catalog changes.

Catalog downloads use `https://raw.githubusercontent.com/RealmsStuff/CR-Mods/main/release-assets/...`.
No separate GitHub Release upload is required. Keep an older version under a distinct filename before adding
a newer catalog version so update rollback remains available.
