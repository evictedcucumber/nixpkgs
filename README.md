# nixpkgs

My own custom nixpkgs: packages nixpkgs lacks, and overrides of ones it has. It tracks `nixos-unstable`, and CI updates nixpkgs and the packages daily at 01:00 SAST.

Only `x86_64-linux` is supported.

## Outputs

| Output | What it is |
| --- | --- |
| `legacyPackages.x86_64-linux` | All of nixpkgs, with this repo's packages and overrides applied |
| `overlays.default` | The same additions and overrides, as an overlay for your own nixpkgs |
| `overlays.stable` | Adds `pkgs.stable`: plain `nixos-26.05`, for when unstable breaks. Already applied in `legacyPackages` |
| `packages.x86_64-linux` | Only the packages this repo adds or overrides |
| `nixosModules.helium` | System-wide Helium policies and force-installed extensions |
| `homeModules.helium` | Installs Helium for a user, with launch flags, native messaging hosts, and dictionaries |

## Usage

Add it as a flake input:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  my-nixpkgs.url = "github:evictedcucumber/nixpkgs";
};
```

Then pick one of the two ways below.

### Use it in place of nixpkgs

Take the package set straight from `legacyPackages`. You get this repo's nixpkgs pin, updated daily, so you don't need your own `nixpkgs` input.

```nix
{
  inputs.my-nixpkgs.url = "github:evictedcucumber/nixpkgs";

  outputs =
    { my-nixpkgs, ... }:
    let
      pkgs = my-nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.hello ];
      };
    };
}
```

This instance has no `config` (such as `allowUnfree`). If you need one, use the overlay instead.

### Apply the overlay to your own nixpkgs

Keep your own nixpkgs pin and config, and add this repo's packages on top.

In a project:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-nixpkgs = {
      url = "github:evictedcucumber/nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

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

`inputs.nixpkgs.follows = "nixpkgs"` stops a second copy of nixpkgs from being fetched.

### Fall back to stable

When a package is broken on unstable, take it from `pkgs.stable` instead, for example `pkgs.stable.hello`. It is plain stable nixpkgs, without this repo's packages or overrides. `legacyPackages` already has it; with the overlay, add `my-nixpkgs.overlays.stable` next to `overlays.default`. It inherits `allowUnfree`, `allowUnfreePredicate`, `permittedInsecurePackages`, and `allowInsecurePredicate` from your config.

### Run a package directly

```bash
nix run github:evictedcucumber/nixpkgs#<package>
```

```bash
nix shell github:evictedcucumber/nixpkgs#<package>
```

### Helium modules

The two modules split the work, so each setting lives in one place:

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

```bash
nix flake update my-nixpkgs
```

## Contributing

See [AGENTS.md](AGENTS.md) for the layout and how to add or override packages.
