# myblog

![mit license](https://img.shields.io/github/license/RyosukeDTomita/myblog)

## INDEX

- [ABOUT](#about)
- [ENVIRONMENT](#environment)
- [HOW TO USE](#how-to-use)
- [For Developers](#for-developers)

## ABOUT

my blog site built with [Haskell](https://www.haskell.org/) library [Hakyll](https://jaspervdj.be/hakyll/).

---

## ENVIRONMENT

- Nix Flake
  - treefmt
- Haskell
  - Hakyll
  - Stack
  - Ormolu
- mdformat

---

## HOW TO USE

1. Fork this repository.
2. Go to `Settings` -> `Pages` and set **Source** to `main` branch.
3. Write articles in `posts/` directory.

    ```markdown
    ---
    title: My post
    date: 2026-03-03
    ---

    Hello, world.
    ```

4. Push to `main` branch and wait for GitHub Actions to build and deploy.
5. Your blog will be available at `https://<username>.github.io/`.

---

## For Developers

### Development server on localhost

```bash
cd /home/sigma/myblog
nix develop
stack build
stack exec site watch
```

Go to [http://127.0.0.1:8000](http://127.0.0.1:8000)

`stack.yaml` is configured to use GHC from `nix develop` (`system-ghc: true`), so Stack does not install its own GHC.

### Formatting

```bash
nix fmt
```

This runs `treefmt` with:

- `ormolu` for `*.hs`
- `mdformat` for `*.md`

---
