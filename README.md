# myblog

Hakyll blog powered by Nix + Stack and deployed with GitHub Actions to GitHub Pages.

## Requirements

- Nix with flakes enabled

## Local development

```bash
nix develop
stack build
stack exec site watch
```

Open http://127.0.0.1:8000.

## Formatting

```bash
nix fmt
```

This runs `treefmt` with:

- `ormolu` for `*.hs`
- `mdformat` for `*.md`

## Build once

```bash
nix develop --command stack exec site build
```

Generated files are placed under `_site/`.

## Publishing

1. Push to `main`.
1. GitHub Actions workflow builds and deploys to GitHub Pages.
1. In repository settings, set **Pages -> Source** to **GitHub Actions**.

For a user site, use a repository named `<username>.github.io`.

## Writing posts

Add a markdown file under `posts/`:

```markdown
---
title: My post
date: 2026-03-03
---

Hello, world.
```
