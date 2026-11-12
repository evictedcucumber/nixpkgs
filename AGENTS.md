# AGENTS.md

A flake that adds packages to nixpkgs and overrides existing ones, for use in other projects.

## Layout

- `flake.nix`: outputs `overlays.default`, `legacyPackages` (nixpkgs with the overlay), `packages` and `checks` (only what this repo adds or overrides), and `formatter`. Only `x86_64-linux` is supported.
- `overlay.nix`: calls every `pkgs/<name>/package.nix` with `callPackage`, then applies `overrides.nix`.
- `pkgs/<name>/package.nix`: a package that nixpkgs lacks. The directory name is the attribute name. No registration needed.
- `overrides.nix`: changes to packages nixpkgs already has (`prev.<pkg>.override` / `overrideAttrs`).
- `.github/workflows/update.yml`: runs daily at 01:00 SAST (23:00 UTC). It runs `nix flake update`, runs `nix-update` on each package in `pkgs/`, runs `nix flake check`, then pushes one commit per change.

## Adding or overriding a package

- New package: create `pkgs/<name>/package.nix`, written like a nixpkgs `package.nix` (`{ lib, stdenv, fetchurl, ... }: ...`), with `pname`, `version`, and `meta` (`description`, `homepage`, `license`, `platforms`, `mainProgram`).
- Fetch sources so `nix-update` can bump them: a versioned URL or `fetchFromGitHub` with `rev`/`tag` built from `version`. If it can't, add `passthru.updateScript`.
- CI builds every package on a GitHub runner, so prefer upstream release binaries over source builds that would exceed runner limits (Chromium-based browsers, for example).
- Override: add an entry to `overrides.nix`. Use `final` for dependencies and `prev` for the package being overridden.
- Only add what is missing or must differ from nixpkgs. Remove an entry once nixpkgs provides it.

## Commands

- `git add -N <new files>` first: flakes only see tracked files.
- Format: `nix fmt`
- Evaluate: `nix flake check --no-build`
- Build one package: `nix build .#<name> --no-link -L`
- Build everything: `nix flake check -L`
- Bump one package: `nix run --inputs-from . nixpkgs#nix-update -- --flake <name>`
- Hashes: set `lib.fakeHash`, build, and copy the `got:` value. Never guess one.

## Conventions

- Commits follow Conventional Commits, scoped by package where it applies (`feat(helium): add package`, `fix(foo): ...`).
- Don't edit `flake.lock` by hand.
