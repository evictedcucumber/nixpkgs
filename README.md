# nixpkgs

My own custom nixpkgs: packages nixpkgs lacks, and overrides of ones it has. It tracks `nixos-unstable`, and CI updates nixpkgs and the packages daily at 01:00 SAST.

Packages are built and tested on `x86_64-linux` only.

## Outputs

| Output | What it is |
| --- | --- |
| `legacyPackages.<system>` | All of nixpkgs, with this repo's packages and overrides applied |
| `overlays.default` | The same additions and overrides, as an overlay for your own nixpkgs |
| `overlays.stable` | Adds `pkgs.stable`: plain `nixos-26.05`, for when unstable breaks. Already applied in `legacyPackages` |
| `packages.x86_64-linux` | Only the packages this repo adds or overrides |
| `lib` | nixpkgs' `lib`, unchanged |
| `nixosModules.helium` | System-wide Helium policies and force-installed extensions |
| `nixosModules.notDetected`, `nixosModules.readOnlyPkgs` | nixpkgs' own modules, unchanged |
| `homeModules.helium` | Installs Helium for a user, with launch flags, native messaging hosts, and dictionaries |

## Usage

Add it as a flake input in one of the two ways below.

### Use it in place of nixpkgs

Point your `nixpkgs` input here and drop `NixOS/nixpkgs`. Other inputs that follow it get this repo's packages too. You get this repo's nixpkgs pin, updated daily.

```nix
{
  inputs = {
    nixpkgs.url = "github:evictedcucumber/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ pkgs.helium ];
      };
    };
}
```

It provides what the nixpkgs flake does: `lib`, `legacyPackages`, `nixosModules`, and `import nixpkgs { … }` (with this repo's overlays applied before yours). `legacyPackages` has no `config` (such as `allowUnfree`); use `import nixpkgs { … }` if you need one.

Two things still come from plain nixpkgs:

- `nixpkgs.lib.nixosSystem` doesn't apply the overlay. Add `nixpkgs.overlays = [ inputs.nixpkgs.overlays.default ];` to your host.
- Files inside the nixpkgs source, such as `"${nixpkgs}/nixos/..."` or `<nixpkgs/nixos>`, don't exist here. Use `modulesPath` in NixOS modules instead.

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

If you have your own stable input, make this repo use it so a second copy isn't fetched:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
  my-nixpkgs = {
    url = "github:evictedcucumber/nixpkgs";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.nixpkgs-stable.follows = "nixpkgs-stable";
  };
};
```

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
