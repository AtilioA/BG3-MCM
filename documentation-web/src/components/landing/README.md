# TODO: Landing Components

This directory is reserved for custom landing components if we decide to move away from the Starlight content-based homepage.

## Current status

- Homepage is driven by `src/content/docs/index.mdx` (rich splash/hero page).
- This keeps Starlight docs flow, SEO metadata, and nav behavior aligned with the reference template.

## If custom landing is reintroduced

1. Recreate landing components in this directory.
2. Add `src/pages/index.astro` to render them.
3. Keep SEO metadata consistent with `astro.config.mjs` and MCM docs content.
