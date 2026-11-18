# nixpkgs

My own custom nixpkgs: packages nixpkgs lacks, and overrides of ones it has. It tracks `nixos-unstable`, and CI updates nixpkgs and the packages daily at 01:00 SAST.

Only `x86_64-linux` is supported.

## Outputs

| Output | What it is |
| --- | --- |
| `legacyPackages.x86_64-linux` | All of nixpkgs, with this repo's packages and overrides applied |
| `overlays.default` | The same additions and overrides, as an overlay for your own nixpkgs. Includes [rust-overlay](https://github.com/oxalica/rust-overlay)'s `pkgs.rust-bin` and `pkgs.rustToolchainFor` |
| `overlays.stable` | Adds `pkgs.stable`: plain `nixos-26.05`, for when unstable breaks. Already applied in `legacyPackages` |
| `packages.x86_64-linux` | Only the packages this repo adds or overrides |
| `nixosModules.helium` | System-wide Helium policies and force-installed extensions |
| `homeModules.helium` | Installs Helium for a user, with launch flags, native messaging hosts, and dictionaries |

## Usage

Take nixpkgs and home-manager from this repo, so you get the versions CI checked the packages and modules against and update them all with one input:

```nix
inputs = {
  my-nixpkgs.url = "github:evictedcucumber/nixpkgs";
  nixpkgs.follows = "my-nixpkgs/nixpkgs";
  home-manager.follows = "my-nixpkgs/home-manager";
};
```

Other inputs can keep `inputs.nixpkgs.follows = "nixpkgs"`, and `"${nixpkgs}/nixos/..."` paths work as usual.

To pick your own versions instead, make this repo follow your inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  my-nixpkgs = {
    url = "github:evictedcucumber/nixpkgs";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
};
```

Either way, add the overlay for `pkgs.<package>`, and import the [Helium modules](#helium-modules) for `programs.helium`.

### Apply the overlay

In a project:

```nix
{
  outputs =
    { nixpkgs, my-nixpkgs, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ my-nixpkgs.overlays.default ];
        config.allowUnfree = true;
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
```

In a NixOS module, with `inputs` passed through `specialArgs`:

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.my-nixpkgs.overlays.default ];
  environment.systemPackages = [ pkgs.hello ];
}
```

### Rust toolchains

`pkgs.rustToolchainFor ./.` returns the toolchain pinned by the project's `rust-toolchain.toml` (or `rust-toolchain`) file, or the latest stable Rust if there is none:

```nix
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = [ (pkgs.rustToolchainFor ./.) ];
};
```

The rest of rust-overlay's `pkgs.rust-bin` works as usual, for example `pkgs.rust-bin.stable.latest.default.override { targets = [ "wasm32-unknown-unknown" ]; }`. CI updates rust-overlay daily with the other inputs, so "latest stable" is as of your `my-nixpkgs` lock.

### Fall back to stable

When a package is broken on unstable, take it from `pkgs.stable` instead, for example `pkgs.stable.hello`. It is plain stable nixpkgs, without this repo's packages or overrides. Add `my-nixpkgs.overlays.stable` next to `overlays.default` to get it. It inherits `allowUnfree`, `allowUnfreePredicate`, `permittedInsecurePackages`, and `allowInsecurePredicate` from your config.

If you need stable nixpkgs elsewhere, take it from this repo too, so a second copy isn't fetched:

```nix
nixpkgs-stable.follows = "my-nixpkgs/nixpkgs-stable";
```

If you pin your own nixpkgs, add your stable input the same way: `my-nixpkgs.inputs.nixpkgs-stable.follows = "nixpkgs-stable"`.

### Run a package directly

```bash
nix run github:evictedcucumber/nixpkgs#<package>
```

```bash
nix shell github:evictedcucumber/nixpkgs#<package>
```

### Helium modules

Import these where you need them. They don't need the overlay: each builds Helium from this repo's own package. The two modules split the work, so each setting lives in one place:

- `nixosModules.helium` writes policies to `/etc/chromium/policies/managed/helium.json`. Chromium reads that directory too. It doesn't install the browser.
- `homeModules.helium` installs the browser for your user, with its flags and per-user files.

```nix
# NixOS configuration
{ inputs, ... }:
{
  imports = [ inputs.my-nixpkgs.nixosModules.helium ];
  programs.helium = {
    enable = true;
    extensions = [ "nngceckbapebfimnlniiiahkandclblb" ]; # Bitwarden
    policies.PasswordManagerEnabled = false;
  };
}
```

```nix
# home-manager configuration
{ inputs, pkgs, ... }:
{
  imports = [ inputs.my-nixpkgs.homeModules.helium ];
  programs.helium = {
    enable = true;
    commandLineArgs = [
      "--enable-wayland-ime"
      "--wayland-text-input-version=3"
    ];
    nativeMessagingHosts = [ pkgs.keepassxc ];
    dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
  };
}
```

Helium uses native Wayland on its own when `XDG_SESSION_TYPE=wayland`, as on Hyprland. Force-installed extensions download through Helium's services, so they only install after you enable those services during onboarding.

### Get the latest updates

This updates the packages, and the nixpkgs and home-manager that follow this repo:

```bash
nix flake update my-nixpkgs
```

If you pin your own, update them too with `nix flake update my-nixpkgs nixpkgs home-manager`.

## Contributing

See [AGENTS.md](AGENTS.md) for the layout and how to add or override packages.
